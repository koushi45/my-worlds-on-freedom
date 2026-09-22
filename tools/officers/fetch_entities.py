"""Archive date precision and provenance for possible 1546 roster candidates (CC0)."""
import json, re, time, urllib.parse, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'data/sources/officers'

def candidate_rows():
    rows = {}
    for filename in ['wikidata_candidates.json', 'wikidata_japan.json', 'wikidata_commanders.json']:
        for r in json.loads((OUT / filename).read_text(encoding='utf-8'))['results']['bindings']:
            q = r['person']['value'].split('/')[-1]
            d = r.get('personDescription', {}).get('value', '')
            if filename.endswith('commanders.json') and not re.search(r'日本|Japanese|samurai|Sengoku|daimy|戦国時代|安土桃山', d, re.I):
                continue
            if '中国戦国' in d:
                continue
            b, e = [r.get(k, {}).get('value', '') for k in ['birth', 'death']]
            # Century-level dates can be returned as 1600-01-01. Fetch their precision
            # before excluding them (e.g. Oda Nobuhiro is not a 1600 birth).
            coarse_candidate=b.startswith('1600-01-01')
            if re.match(r'^\d{4}-', b) and int(b[:4]) > 1546 and not coarse_candidate:
                continue
            if re.match(r'^\d{4}-', e) and int(e[:4]) < 1546:
                continue
            entry = rows.setdefault(q, {'id': q, 'name': r['personLabel']['value'], 'description': d, 'discovery': [], 'rows': []})
            if filename not in entry['discovery']:
                entry['discovery'].append(filename)
            entry['rows'].append(r)
    return rows

def main():
    candidates = candidate_rows()
    supplement = OUT / 'supplemental_index.json'
    if supplement.exists():
        candidates.update(json.loads(supplement.read_text(encoding='utf-8')))
    (OUT / 'candidate_index.json').write_text(json.dumps(candidates, ensure_ascii=False, indent=2), encoding='utf-8')
    folder = OUT / 'entities'; folder.mkdir(exist_ok=True)
    pending = [q for q in sorted(candidates) if not (folder / f'{q}.json').exists()]
    for offset in range(0, len(pending), 50):
        ids = pending[offset:offset+50]
        url = 'https://www.wikidata.org/w/api.php?' + urllib.parse.urlencode({'action': 'wbgetentities', 'ids': '|'.join(ids), 'props': 'info|labels|descriptions|aliases|claims|sitelinks', 'languages': 'ja|en', 'format': 'json'})
        request = urllib.request.Request(url, headers={'User-Agent': 'MyWorldsOnFreedom-HistoricalRoster/0.1'})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    data = json.load(response)
                break
            except urllib.error.HTTPError as error:
                if error.code not in (429, 503) or attempt == 3:
                    raise
                delay = max(65, int(error.headers.get('Retry-After', '65')))
                print(f'Rate limit: waiting {delay}s', flush=True)
                time.sleep(delay)
        for q, entity in data['entities'].items():
            (folder / f'{q}.json').write_text(json.dumps({'retrieved_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'license': 'CC0-1.0', 'entity': entity}, ensure_ascii=False, indent=2), encoding='utf-8')
        print(f'{min(offset+50, len(pending))}/{len(pending)} entities archived', flush=True)
        time.sleep(7)
    print('candidate count:', len(candidates))

if __name__ == '__main__':
    main()
