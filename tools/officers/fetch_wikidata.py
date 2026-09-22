"""Snapshot public CC0 identity/date candidates; never treat this as a complete historical census."""
import hashlib
import json
import time
import urllib.parse
import urllib.request
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data/sources/officers"
QUERY = '''SELECT DISTINCT ?person ?personLabel ?personDescription ?birth ?death WHERE {
  VALUES ?occupation { wd:Q38142 wd:Q61982 wd:Q5384684 }
  ?person wdt:P31 wd:Q5; wdt:P106 ?occupation .
  OPTIONAL { ?person wdt:P569 ?birth }
  OPTIONAL { ?person wdt:P570 ?death }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en". }
}'''
JAPAN_QUERY = '''SELECT DISTINCT ?person ?personLabel ?personDescription ?birth ?death WHERE {
  ?person wdt:P31 wd:Q5; wdt:P569 ?birth; wdt:P570 ?death .
  FILTER(?birth < "1547-01-01T00:00:00Z"^^xsd:dateTime && ?death >= "1546-01-01T00:00:00Z"^^xsd:dateTime)
  { ?person wdt:P27 wd:Q17 } UNION { ?person wdt:P19/wdt:P17 wd:Q17 }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en". }
}'''
COMMANDER_QUERY = '''SELECT DISTINCT ?person ?personLabel ?personDescription ?birth ?death WHERE {
  VALUES ?occupation { wd:Q11545923 wd:Q1402561 }
  ?person wdt:P31 wd:Q5; wdt:P106 ?occupation .
  OPTIONAL { ?person wdt:P569 ?birth }
  OPTIONAL { ?person wdt:P570 ?death }
  FILTER((!BOUND(?birth) || ?birth < "1547-01-01T00:00:00Z"^^xsd:dateTime) && (!BOUND(?death) || ?death >= "1546-01-01T00:00:00Z"^^xsd:dateTime))
  SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en". }
}'''

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--query',choices=['occupations','japan','commanders'],default='occupations')
    kind=parser.parse_args().query
    query={'occupations':QUERY,'japan':JAPAN_QUERY,'commanders':COMMANDER_QUERY}[kind]
    OUT.mkdir(parents=True, exist_ok=True)
    url = 'https://query.wikidata.org/sparql?' + urllib.parse.urlencode({'query': query, 'format': 'json'})
    request = urllib.request.Request(url, headers={'User-Agent': 'MyWorldsOnFreedom-HistoricalRoster/0.1', 'Accept': 'application/sparql-results+json'})
    with urllib.request.urlopen(request, timeout=60) as response:
        raw = response.read()
    data = json.loads(raw)
    (OUT / f'wikidata_{kind}.json').write_bytes(raw)
    manifest = {'retrieved_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'query': query,
        'endpoint': 'https://query.wikidata.org/sparql', 'license': 'CC0-1.0',
        'sha256': hashlib.sha256(raw).hexdigest(), 'rows': len(data['results']['bindings']),
        'scope': {'occupations':'Humans directly described as samurai, daimyo, or Sengoku daimyo.',
            'japan':'Humans linked to Japan by citizenship or birthplace, with date values overlapping 1546; occupations are not filtered.',
            'commanders':'Worldwide military commanders/leaders, with missing dates or date values overlapping 1546. Includes non-Japanese and other eras.'}[kind] + ' Incomplete discovery only. Inspect original date precision before adopting.'}
    (OUT / f'manifest_{kind}.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(manifest, ensure_ascii=False))

if __name__ == '__main__':
    main()
