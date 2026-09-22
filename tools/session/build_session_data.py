"""Build small title metadata and simplified district outlines, without changing sources."""
import collections
import json
from pathlib import Path
from shapely.geometry import LineString

ROOT = Path(__file__).resolve().parents[2]
def read(path): return json.loads((ROOT/path).read_text(encoding='utf8'))
def write(path, value):
    dest=ROOT/path
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':')),encoding='utf8')

g=read('data/derived/governance/governance_1546.json')
topology=read('data/derived/scenarios/district_connectivity_1546.json')
legacy_houses={d['house_id'] for d in g['districts'].values()}
for key,r in topology['extra_districts'].items():
    district=dict(g['districts'][r['source_id']],id=key,name=r['name'],province=r.get('province',g['districts'][r['source_id']]['province']))
    house_id=r.get('house_id',district['house_id'])
    if house_id!=district['house_id']:
        district['house_id']=house_id
        district['ruler']=g['houses'][house_id]['ruler']
        district['governor']=dict(district['ruler'],appointment='scenario_direct',note='島郡の統治担当として当主を置くゲーム設定です。')
        district['candidate_house_ids']=[house_id]
    g['districts'][key]=district
g['districts']={k:v for k,v in g['districts'].items() if k in topology['active_district_ids']}
counts=collections.Counter(d['house_id'] for d in g['districts'].values())
houses={k:{'name':v['display_name'],'ruler':(v['ruler'] or {}).get('name','当主未詳'),'district_count':counts[k],
           'loadable':v['governance_type']=='house' and k in legacy_houses,
           'playable':v['governance_type']=='house' and counts[k]>0} for k,v in g['houses'].items()}
write('data/derived/scenarios/house_selection_1546.json',{'houses':houses,
      'officer_ids':[o['id'] for o in read('data/derived/officers/officers_1546.json')['officers']],
      'district_ids':list(g['districts']),'site_ids':list(g['sites']),
      'original_district_ids':topology['original_ids'],
      'previous_layout_ids':topology['previous_layout_ids'],
      'overlap_layout_ids':topology['overlap_layout_ids'],
      'district_origins':{k:r['source_id'] for k,r in topology['extra_districts'].items()},
      'district_defaults':{k:{field:g['districts'][k][field] for field in ['house_id','governor','ruler']} for k in topology['extra_districts']}})
outlines={key:[ring for polygon in r['polygons'] for ring in polygon]
          for key,r in read('data/derived/scenarios/independent_districts_1546.json')['regions'].items()}
write('data/derived/scenarios/district_outlines_1546.json',outlines)
print(f'{sum(h["playable"] for h in houses.values())} playable houses, {len(outlines)} outlines')
