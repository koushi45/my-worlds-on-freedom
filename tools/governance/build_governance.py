"""Build a separate, reproducible 1546 government registry without changing officers.

Priority: individual game affiliations > house placement pools > researched regional
exceptions. Regional coverage and newly appointed deputies are always scenario estimates.
"""
from __future__ import annotations
import collections
import hashlib
import html
import json
import re
from pathlib import Path

from rules_1546 import SOURCES, REGIONAL, PARTITIONS, USER_OWNERSHIP_OVERRIDES, EXTRA_HOUSES, SITE_HOUSES, OFFICE_OVERRIDES, FUTURE, ALIASES_1546, SEATS, SITE_RESEARCH

ROOT = Path(__file__).resolve().parents[2]
INPUTS = {
    'officers': 'data/derived/officers/officers_1546.json',
    'houses': 'data/master/officers/house_placement_pools_1546.json',
    'districts': 'data/derived/districts/unconfirmed/index.json',
    'sites': 'data/derived/settlements/settlements_1582.json',
}


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def write(path, data):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build():
    raw = {key: read(path) for key, path in INPUTS.items()}
    officers = raw['officers']['officers']
    by_name = {o['display_name']: o for o in officers}
    by_id = {o['id']: o for o in officers}
    districts = {r['key']: r for r in raw['districts']['regions']}
    houses = {h['id']: dict(h) for h in raw['houses']['houses']}
    evidence_sources = {key: dict(id=key, title=v[0], url=v[1], scope=v[2], accessed='2026-09-13') for key, v in SOURCES.items()}

    def present(o):
        a = o['affiliation_1546']
        b = a.get('birth_reference') or o.get('birth_year_range')
        d = a.get('death_reference') or o.get('death_year_range')
        return not ((b and min(b) > 1546) or (d and max(d) < 1546) or a.get('availability') in ('not_born', 'deceased'))

    def eligible(o):
        a = o['affiliation_1546']
        return (present(o) and a.get('availability') == 'available'
                and a.get('role') in ('大名', '大名家一門', '武将'))

    members = collections.defaultdict(list)
    placed = collections.defaultdict(list)
    for o in officers:
        a = o['affiliation_1546']
        if a.get('house_id') and present(o):
            members[a['house_id']].append(o)
            if eligible(o):
                placed[a.get('district_key')].append(o)

    for key, (label, head, source) in EXTRA_HOUSES.items():
        houses[key] = dict(id=key, display_name=label, head_reference=head, pool=[],
                           source_urls=[SOURCES[source][1]] if source else [], note='地域調査による補完。単独支配・担当者名の未詳を保持。')

    def person(o):
        return dict(officer_id=o['id'], name=o['display_name'], basis='existing_officer',
                    source_urls=o['affiliation_1546'].get('source_urls', []))

    def score(o):
        s = o['assessment']['scores']
        return (int(s.get('politics') or 0), int(s.get('command') or 0), o['id'])

    # A named leader in a newer individual affiliation outranks the older house pool.
    for fid, h in houses.items():
        candidates = [o for o in members[fid] if o['affiliation_1546']['role'] == '大名']
        h['leader_candidates'] = [person(o) for o in candidates]
        reference = h.get('head_reference') or ''
        exact = [o for o in candidates if o['display_name'] == reference or reference.startswith(o['display_name'] + ' (')]
        choice = exact[0] if exact else (sorted(candidates, key=lambda o: (o['affiliation_1546'].get('status') == 'reviewed', eligible(o), score(o)), reverse=True)[0] if candidates else None)
        if choice:
            h['ruler'] = person(choice)
        else:
            known = by_name.get(reference)
            if known and present(known) and known['affiliation_1546'].get('house_id') == fid:
                h['ruler'] = person(known)
            elif reference and not (known and not present(known)):
                h['ruler'] = dict(officer_id=None, name=reference, basis='research_reference' if fid in EXTRA_HOUSES else 'existing_house_reference', source_urls=h.get('source_urls', []))
            else:
                h['ruler'] = None
        h['head_note'] = '武将の現行設定を優先。年内継承・幼少当主・当主候補の競合は史実確定を意味しない。'
        h['eligible_officer_ids'] = [o['id'] for o in members[fid] if eligible(o)]
        h['governance_type'] = 'collective' if fid in ('iga_sokoku','sakai_council','kuwana_council','jingu','koyasan','negoro','saika') else ('unknown' if fid.startswith('local_') else 'house')

    # A dead reference must not silently become a ruler, even if the old pool contains it.
    if houses['hatakeyama_kawachi']['ruler'] and houses['hatakeyama_kawachi']['ruler']['name'] == '畠山稙長':
        houses['hatakeyama_kawachi']['ruler'] = person(by_name['畠山政国'])
        houses['hatakeyama_kawachi']['head_note'] = '旧本拠圏台帳の稙長は1545年没。現行所属の政国をゲーム当主に採用。継承説の相違は富田林市史参照。'

    pool_claims = collections.defaultdict(list)
    for fid, h in houses.items():
        for key in h.get('pool', []):
            if key in districts:
                pool_claims[key].append(fid)

    assignments = {}

    def appoint(fid, district_key, direct=False):
        h = houses[fid]
        if direct and h['ruler'] and (h['ruler']['officer_id'] is None or eligible(by_id[h['ruler']['officer_id']])):
            return dict(h['ruler'], appointment='scenario_direct', note='大名・領主の直轄としてゲーム設定。現地代官の実名は確定していない。')
        local = [o for o in placed[district_key] if o['affiliation_1546']['house_id'] == fid]
        candidates = local or [o for o in members[fid] if eligible(o)]
        if candidates:
            chosen = sorted(candidates, key=score, reverse=True)[0]
            return dict(person(chosen), appointment='scenario_appointment',
                        note='既存の同家・同郡武将から統治担当に任命（ゲーム設定）。' if local else '同家の活動可能な武将から統治担当に任命（ゲーム設定・広域兼任）。')
        if h['ruler'] and h['ruler']['officer_id'] is None:
            return dict(h['ruler'], appointment='reference_direct', note='家台帳・調査資料の当主参考情報から直轄としてゲーム設定。武将名簿には未登録。')
        return None

    for key, r in sorted(districts.items()):
        active = placed[key]
        claims = sorted(set(o['affiliation_1546']['house_id'] for o in active) | set(pool_claims[key]))
        local_heads = [o for o in active if o['affiliation_1546']['role'] == '大名']
        region, source = REGIONAL[r['parent']]
        regional_candidates = region.split('|')
        partition = next((fid for pattern, fid in PARTITIONS.get(r['parent'], []) if re.search(pattern, r['name'])), None)
        if local_heads:
            owner = sorted(local_heads, key=lambda o: (o['affiliation_1546'].get('status') == 'reviewed', score(o)), reverse=True)[0]['affiliation_1546']['house_id']
            basis, reason = 'existing_daimyo_placement', '配置済み大名の家を優先してゲーム支配家に設定。'
        elif active:
            counts = collections.Counter(o['affiliation_1546']['house_id'] for o in active)
            owner = sorted(counts, key=lambda fid: (-counts[fid], fid))[0]
            basis, reason = 'existing_officer_placement', '配置済み武将の所属家を採用。複数家は人数順・同数は家ID順でゲーム上の代表を選択。'
        elif len(claims) == 1:
            owner = claims[0]
            basis, reason = 'existing_house_pool', '既存の家別配置候補をゲーム支配家へ適用。'
        elif claims:
            owner = partition if partition in claims else next((fid for fid in regional_candidates if fid in claims), claims[0])
            basis, reason = 'competing_game_claims', '既存家の候補が競合。地域資料を参照し代表をゲーム設定、競合候補を併記。'
        else:
            owner = partition or regional_candidates[0]
            claims = [partition] if partition else regional_candidates
            basis, reason = 'regional_scenario_estimate', '既存武将の配置だけでは判別不可。家の活動圏・地域資料から暫定のゲーム支配家を設定。郡全域の排他的領有・現地官職は未確定。'
        if key in USER_OWNERSHIP_OVERRIDES:
            owner = USER_OWNERSHIP_OVERRIDES[key]
            claims = [owner]
            basis, reason = 'user_direction', 'ユーザー指定によりゲーム上の支配家を設定。'
        if owner not in claims:
            claims.append(owner)
        assert owner in houses, owner
        note = reason + ' 元の配置は居住・領有の史実証明ではない。'
        if owner == 'date':
            note += ' 天文の乱の最中。稙宗・晴宗両派の対立を留保し既存の単一家設定を維持。'
        h = houses[owner]
        urls = list(dict.fromkeys(h.get('source_urls', []) + ([SOURCES[source][1]] if source else [])))
        assignments[key] = dict(id=key, kind='district', name=r['name'], province=r['parent_name'],
                                parent=r['parent'], point=r['label'], year=1546, house_id=owner,
                                ruler=h['ruler'], governor=appoint(owner,key),
                                basis=basis, confidence='game_scenario_provisional', candidate_house_ids=claims,
                                source_urls=urls, research_source_ids=[source] if source else [],
                                note=note, geometry_note='現在の郡区画は後世比較・仮称・合併を含む。1546年の確定郡境ではない。',
                                existing_officer_ids=[o['id'] for o in active], site_ids=[])

    site_candidates = collections.defaultdict(list)
    for key, d in districts.items():
        for s in d.get('sites', []):
            site_candidates[s['id']].append(key)
    explicit = {}
    for fid, names in SITE_HOUSES.items():
        for name in names.split('|'):
            assert name not in explicit
            explicit[name] = fid
    site_assignments = {}
    for s in raw['sites']['sites']:
        if s['adoption_status'] == 'excluded':
            continue
        name = s['display_name']
        keys = sorted(set(site_candidates[s['id']]))
        # Do not snap an offshore/unmatched site to an unrelated province or district.
        key = keys[0] if keys else None
        owner = explicit.get(name+'@'+s['province_id'], explicit.get(name))
        if not owner and key:
            owner = assignments[key]['house_id']
        if not owner:
            fallback = REGIONAL.get(s['province_id'])
            owner = fallback[0].split('|')[0] if fallback else None
        h = houses.get(owner, {})
        ruler = h.get('ruler')
        is_seat = name in SEATS
        governor = appoint(owner,key,is_seat) if owner else None
        basis = 'existing_house_scenario' if name in explicit or name+'@'+s['province_id'] in explicit else 'district_scenario_inheritance'
        note = '家の現行設定・本拠圏から支配家をゲーム設定。現地城主の史実確定とは区別。'
        refs = list(h.get('source_urls', []))
        source_ids = []
        if name in SITE_RESEARCH:
            source = SITE_RESEARCH[name]
            source_ids.append(source)
            refs.append(SOURCES[source][1])
            note += ' '+SOURCES[source][2]
            basis = 'historical_research_scenario'
        if name in OFFICE_OVERRIDES:
            officer_name, office_basis, note, source = OFFICE_OVERRIDES[name]
            o = by_name[officer_name]
            assert o['affiliation_1546']['house_id'] == owner
            governor = dict(person(o), appointment=office_basis, note=note)
            refs += o['affiliation_1546'].get('source_urls', [])
            if source:
                source_ids.append(source)
                refs.append(SOURCES[source][1])
        temporal = 'scenario_site_1546_unverified'
        if name in FUTURE:
            built, source = FUTURE[name]
            governor = None
            temporal = 'not_yet_established'
            note = f'{built}年の築城・開港。1546年は未成立のため城主・港の担当者は任命しない。支配家は周辺地域のゲーム設定。'
            if source:
                source_ids.append(source)
                refs.append(SOURCES[source][1])
            else:
                for ref in s.get('source_refs', []):
                    refs += [src['url'] for src in raw['sites']['sources'] if src['id'] == ref]
        if name == '金沢城':
            temporal = 'established_during_start_year'
            governor = None
            note += ' 金沢御堂は1546年創建だが月日不詳。1月1日に完成済みとは扱わない。'
            source_ids.append('kanazawa'); refs.append(SOURCES['kanazawa'][1])
        if owner in ('sakai_council','iga_sokoku','jingu','koyasan','saika'):
            governor = None
            note += ' 合議・寺社運営。大名任命の城主を架空に設定しない。'
        row = dict(id=s['id'], kind='site', name=ALIASES_1546.get(name,name), map_name=name,
                   province=s['province_name'], parent=s['province_id'], point=s['point'], roles=s['roles'],
                   year=1546, house_id=owner, ruler=ruler, governor=governor, basis=basis,
                   confidence='game_scenario_provisional', district_key=key, district_candidates=keys,
                   district_link_status='candidate' if len(keys)==1 else ('ambiguous' if keys else 'unresolved'),
                   temporal_status=temporal, note=note, source_urls=list(dict.fromkeys(refs)),
                   research_source_ids=source_ids, candidate_house_ids=[owner] if owner else [])
        row['adoption_status'] = s['adoption_status']
        if key and assignments[key]['house_id'] != owner:
            row['note'] += ' 所在郡の代表支配家とは異なる拠点（飛地・競合を含むゲーム設定）。'
        site_assignments[s['id']] = row
        for candidate in keys:
            assignments[candidate]['site_ids'].append(s['id'])

    all_rows = list(assignments.values()) + list(site_assignments.values())
    duties = collections.Counter(r['governor']['officer_id'] for r in all_rows if r['governor'] and r['governor']['officer_id'])
    for r in all_rows:
        if r['governor']:
            r['governor']['assignment_count'] = duties[r['governor']['officer_id']] if r['governor']['officer_id'] else 0
    stats = dict(districts=len(assignments), sites=len(site_assignments),
                 accepted_sites=sum(r['adoption_status']=='accepted' for r in site_assignments.values()),
                 deferred_sites=sum(r['adoption_status']=='deferred' for r in site_assignments.values()),
                 district_bases=dict(collections.Counter(r['basis'] for r in assignments.values())),
                 named_district_governors=sum(bool(r['governor']) for r in assignments.values()),
                 named_site_governors=sum(bool(r['governor']) for r in site_assignments.values()),
                 future_sites=sum(r['temporal_status']=='not_yet_established' for r in site_assignments.values()),
                 uncertain_site_district_links=sum(r['district_link_status']!='candidate' for r in site_assignments.values()))
    data = dict(schema_version=1, scenario_id='nobunaga_genpuku_1546', year=1546,
                policy='現行武将設定優先。新規領有・任命はゲーム暫定。参考当主・未詳・自治・未築城を区別。',
                input_hashes={path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in INPUTS.values()},
                rules_sha256=hashlib.sha256(Path(__file__).with_name('rules_1546.py').read_bytes()).hexdigest(),
                stats=stats, houses=houses, districts=assignments, sites=site_assignments, sources=evidence_sources)
    write('data/derived/governance/governance_1546.json', data)
    write('data/master/governance/review_1546.json', dict(stats=stats, unresolved=[dict(id=r['id'],name=r['name'],note=r['note']) for r in all_rows if not r['governor']],
                                                       conflicts=[dict(id=r['id'],name=r['name'],house_ids=r['candidate_house_ids']) for r in all_rows if len(r['candidate_house_ids'])>1]))
    report(data)
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    return data


def report(data):
    rows = list(data['districts'].values())+list(data['sites'].values())
    lines = ['# 1546年の郡・拠点統治台帳', '', '全件はゲーム設定。史料上の排他的領有・城主を一律に確定した台帳ではありません。', '', '|種別|国・名称|支配家|大名・領主|統治担当|根拠|', '|---|---|---|---|---|---|']
    html_rows = []
    for r in rows:
        h=data['houses'].get(r['house_id'],{})
        cells=['郡' if r['kind']=='district' else '拠点',r['province']+' / '+r['name'],h.get('display_name','未詳'),(r['ruler'] or {}).get('name','当主未詳・合議'),(r['governor'] or {}).get('name','未任命・自治・未成立'),r['basis']]
        lines.append('|'+ '|'.join(x.replace('|','・') for x in cells)+'|')
        details=r['note']+' '+(r['governor'] or {}).get('note','')
        links=' '.join('<a href="'+html.escape(url,quote=True)+'">出典</a>' for url in r['source_urls'])
        html_rows.append('<tr>'+''.join('<td>'+html.escape(x)+'</td>' for x in cells[:-1])+'<td>'+html.escape(details)+'<br>'+links+'</td></tr>')
    dest=ROOT/'docs/governance';dest.mkdir(parents=True,exist_ok=True)
    (dest/'REGISTER_1546.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    page='''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>1546年 統治台帳</title><style>body{background:#172e38;color:#f7efd8;font:16px system-ui;margin:32px}input{padding:12px;width:min(600px,90%);font:inherit}table{border-collapse:collapse;width:100%;margin-top:24px}td,th{padding:12px;border-bottom:1px solid #52646a;text-align:left;vertical-align:top}th{position:sticky;top:0;background:#172e38}td:last-child{max-width:500px;font-size:13px}a{color:#91d8e9}h1{font-size:28px}</style><h1>1546年の郡・拠点統治台帳</h1><p>既存武将設定を優先。新規の領有・担当任命はゲーム用の暫定設定です。自治・未成立・担当未詳を区別しています。</p><input id="q" placeholder="国・郡・拠点・支配家・武将名で検索" aria-label="統治台帳を検索"><p id="count"></p><table><thead><tr><th>種別</th><th>国・名称</th><th>支配家</th><th>大名・領主</th><th>統治担当</th><th>判断・出典</th></tr></thead><tbody>'''+''.join(html_rows)+'''</tbody></table><script>const rows=[...document.querySelectorAll('tbody tr')],q=document.querySelector('#q'),c=document.querySelector('#count');function filter(){let n=0;for(const r of rows){r.hidden=!r.textContent.toLowerCase().includes(q.value.toLowerCase());if(!r.hidden)n++}c.textContent=n+'件 / '+rows.length+'件'}q.addEventListener('input',filter);filter();</script></html>'''
    (dest/'register_1546.html').write_text(page,encoding='utf-8')


if __name__=='__main__':
    build()
