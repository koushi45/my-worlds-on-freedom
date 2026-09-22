"""Build attributed parent/child references; never infer kinship from surnames."""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'
CACHE = ROOT / 'data/sources/officers/relationship_labels'
PROPS = {'P22': 'father', 'P25': 'mother', 'P40': 'children'}


def read(p):
    return json.loads(p.read_text(encoding='utf-8'))


def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def entity_id(snak):
    v = snak.get('datavalue', {}).get('value', {})
    return v.get('id') if isinstance(v, dict) else None


def fetch(batch):
    url = 'https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode({
        'action': 'wbgetentities', 'ids': '|'.join(batch), 'props': 'labels',
        'languages': 'ja|en', 'format': 'json'})
    request = urllib.request.Request(url, headers={'User-Agent': 'HistoricalOfficerRoster/1.0 (local research)'})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = json.load(response)
            break
        except urllib.error.HTTPError as exc:
            if exc.code not in (429, 503) or attempt == 3:
                raise
            time.sleep(min(30, 10 * (attempt + 1)))
    if 'entities' not in data:
        raise RuntimeError(data)
    for q, entity in data['entities'].items():
        write(CACHE / (q + '.json'), {'entity': entity, 'url': url,
              'accessed': datetime.date.today().isoformat(), 'license': 'CC0'})
    time.sleep(1)
    return len(batch)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    roster = read(ROOT / 'data/derived/officers/officers_1546.json')['officers']
    byid = {r['external_id']: r for r in roster}
    entities = {p.stem: read(p)['entity'] for p in (ROOT / 'data/sources/officers/entities').glob('Q*.json')}
    targets = set()
    for q in byid:
        for prop in PROPS:
            for claim in entities[q].get('claims', {}).get(prop, []):
                if claim.get('rank') == 'deprecated':
                    continue
                target = entity_id(claim['mainsnak'])
                if target:
                    targets.add(target)
                for values in claim.get('qualifiers', {}).values():
                    targets.update(entity_id(v) for v in values if entity_id(v))
    cached = {p.stem: read(p)['entity'] for p in CACHE.glob('Q*.json')}
    missing = sorted(targets - entities.keys() - cached.keys())
    if args.fetch and missing:
        batches = [missing[i:i+50] for i in range(0, len(missing), 50)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for count in pool.map(fetch, batches):
                print('Fetched labels:', count, flush=True)
        cached = {p.stem: read(p)['entity'] for p in CACHE.glob('Q*.json')}
    entities.update({q: e for q, e in cached.items() if q not in entities})

    def label(q):
        if q in byid:
            return byid[q]['display_name']
        labels = entities.get(q, {}).get('labels', {})
        return labels.get('ja', labels.get('en', {})).get('value', '名称未確認（' + q + '）')

    edges = {}
    ignored = []
    for q in byid:
        for prop, role in PROPS.items():
            for claim in entities[q].get('claims', {}).get(prop, []):
                target = entity_id(claim['mainsnak'])
                if claim.get('rank') == 'deprecated' or not target or target == q:
                    ignored.append({'subject': q, 'property': prop, 'claim': claim})
                    continue
                parent, child = (q, target) if prop == 'P40' else (target, q)
                edge = edges.setdefault((parent, child), {'parent': parent, 'child': child, 'roles': [], 'evidence': []})
                if prop != 'P40' and role not in edge['roles']:
                    edge['roles'].append(role)
                edge['evidence'].append({'subject': q, 'property': prop, 'statement_id': claim.get('id'),
                    'rank': claim.get('rank'), 'qualifiers': claim.get('qualifiers', {}),
                    'references': claim.get('references', []), 'url': 'https://www.wikidata.org/wiki/' + q})
    profiles = {q: {'father': [], 'mother': [], 'parents_unspecified': [], 'children': [],
        'note': '生涯の親子関係。外部台帳の記載を収録し、史料照合待ち。複数の父母は異説・養親等を含む可能性があります。未確認は不存在を意味せず、子の一覧は全子女の網羅ではありません。'} for q in byid}
    for edge in edges.values():
        parent, child = edge['parent'], edge['child']
        qualifiers = [label(entity_id(v)) for e in edge['evidence'] for vs in e['qualifiers'].values() for v in vs if entity_id(v)]
        qualifiers = sorted(set(qualifiers))
        adoption = any('養' in x or 'adopt' in x.lower() for x in qualifiers)
        kind = '養親子' if adoption else '実養未確認'
        edge.update(kind=kind, qualifier_labels=qualifiers)
        # A P40 claim alone does not tell us whether the parent is father or mother.
        roles = edge['roles']
        if not roles:
            sexes = {entity_id(c['mainsnak']) for c in entities.get(parent, {}).get('claims', {}).get('P21', []) if c.get('rank') != 'deprecated'}
            if sexes == {'Q6581097'}: roles = ['father']
            elif sexes == {'Q6581072'}: roles = ['mother']
            else: roles = ['parents_unspecified']
        edge['display_roles'] = roles

        def ref(q):
            return {'external_id': q, 'officer_id': byid[q]['id'] if q in byid else None,
                'display_name': label(q), 'kind': kind, 'qualifier_labels': qualifiers,
                'status': 'source_catalog', 'source_urls': sorted({e['url'] for e in edge['evidence']})}
        if parent in profiles:
            profiles[parent]['children'].append(ref(child))
        if child in profiles:
            for role in roles:
                profiles[child][role].append(ref(parent))
    for p in profiles.values():
        for key in ['father', 'mother', 'children', 'parents_unspecified']:
            p[key].sort(key=lambda v: (v['display_name'], v['external_id']))
    stats = {'total': len(profiles), 'edges': len(edges),
             **{k: sum(bool(p[k]) for p in profiles.values()) for k in ['father', 'mother', 'children']}}
    write(MASTER / 'relationships.json', {'schema_version': 1, 'stats': stats, 'officers': profiles})
    write(MASTER / 'relationship_evidence.json', {'edges': list(edges.values()), 'ignored': ignored,
          'source_entity_hashes': {q: hashlib.sha256(json.dumps(entities[q], sort_keys=True).encode()).hexdigest() for q in byid}})
    lines = ['# 武将の父・母・子', '', '外部台帳由来・史料照合待ち。生涯の関係で、開始時に未誕生の子も含む。実養が不明な関係は断定しない。', '', '|武将|父|母|子（収録分）|', '|---|---|---|---|']
    for r in roster:
        p = profiles[r['external_id']]
        lines.append('|' + '|'.join([r['display_name']] + ['、'.join(x['display_name'] + '（' + x['kind'] + '）' for x in p[k]) or '未確認' for k in ['father', 'mother', 'children']]) + '|')
    (ROOT / 'docs/officers/RELATIONSHIPS.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(stats, ensure_ascii=False))


if __name__ == '__main__':
    main()
