"""User-authorized invented display names, never historical membership claims."""
import json
import re
import hashlib
from pathlib import Path
from collections import defaultdict, Counter
from shapely.geometry import Polygon, LineString
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')


def apply_names(dest):
    original=read(ROOT/'data/work/districts/stage_f/index.json')
    records={r['key']:r for r in original['regions']}
    ledger=read(ROOT/'data/editorial/districts/districts.json')['districts']
    external={r['external_ids']['district_id']:r for r in ledger if r['external_ids']}
    sources=read(ROOT/'data/editorial/districts/sources.json')['sources']
    kai_source=next(s for s in sources if s['source_id']=='kai-four')
    index=read(dest/'index.json');decisions=[]
    general=dict(title='CODH 旧国・旧郡境界データセット（江戸時代末期の国境・郡境を抽出した資料）',
        url='https://geoshape.ex.nii.ac.jp/kg/',locator='概要・利用したデータ。地名参照のみ。未確定領域の所属は証明しない。')
    for parent in original['parents']:
        pid=parent['id'];data=read(ROOT/f'data/work/districts/stage_f/{pid}/geometry.json')
        shapes={r['key']:unary_union([Polygon(p[0],p[1:]) for p in r['polygons']]) for r in data['regions']}
        anchors={};edges=defaultdict(lambda:defaultdict(float))
        for key in shapes:
            r=records[key]
            refs=[]
            for source in r['sources']:
                match=re.search(r'(G\d+)\.geojson',source['url'])
                if match and match[1] in external:refs.append(external[match[1]])
            if refs:
                item=refs[0];name=item['candidate_display_name'];cites=list(r['sources'])+[general]
                if pid=='kai':
                    for old in ['山梨郡','八代郡','巨摩郡','都留郡']:
                        if name.endswith(old):name=old;break
                    cites.append(dict(title=kai_source['title'],url=kai_source['url'],locator=kai_source['locator']+'。旧四郡の名称のみ参照。'))
                anchors[key]=dict(name=name,sources=cites,external_id=item['external_ids']['district_id'])
        for line in data['lines']:
            if len(line['owners'])!=2:continue
            a,b=line['owners'];length=LineString(line['points']).length
            edges[a][b]+=length;edges[b][a]+=length
        targets=[r for r in index['regions'] if r['parent']==pid and r['kind']=='unresolved']
        for r in targets:
            key=r['key'];near=[k for k in anchors if k!=key and edges[key].get(k,0)>1e-6]
            if key in anchors:
                donor=key;method='元の未確定面に結び付いた後世資料の郡名を借用'
            elif near:
                donor=min(near,key=lambda k:(-edges[key][k],k));method='同じ表示国で共有境界が最も長い資料区画の郡名を借用'
            elif anchors:
                donor=min(anchors,key=lambda k:(shapes[key].distance(shapes[k]),k));method='同じ表示国の最も近い資料区画の郡名を借用（所属・陸路接続は推定しない）'
            else:raise ValueError('No documented geographic name for '+key)
            anchor=anchors[donor];name=anchor['name']+'周辺（仮）'
            decision=dict(key=key,country=r['parent_name'],name=name,borrowed_name=anchor['name'],donor_key=donor,
                donor_external_id=anchor['external_id'],method=method,sources=anchor['sources'],
                status='invented_game_label_not_historical_membership',geometry_changed=False)
            r['name']=name;r['provisional_name']=decision
            r['search_aliases']='郡未確定 '+anchor['name']
            r['sources']=anchor['sources']
            r['confidence']='名称は便宜的な仮称・境界と所属は未確定'
            r['remaining']='近隣・後世の郡名をゲーム用に便宜的に借用。史料がこの領域の名称・所属を示すという意味ではありません。\n'+r['remaining']
            decisions.append(decision)
        counts=Counter(r['name'] for r in targets);seen=Counter()
        for r in sorted(targets,key=lambda r:r['key']):
            if counts[r['name']]>1:
                base=r['name'];seen[base]+=1;r['name']=base.replace('（仮）',f'（仮{seen[base]}）')
                r['provisional_name']['name']=r['name']
    assert len(decisions)==75
    write(dest/'index.json',index)
    write(dest/'provisional_names.json',dict(status='invented_game_labels',count=75,decisions=decisions,
        naming_authorization='User requested assigning similar nearby historic geographic names even where uncertain',
        general_source_url=general['url'],geometry_changed=False))
    manifest=read(dest/'manifest.json')
    for n in ['index.json','provisional_names.json']:
        manifest['files'][n]=hashlib.sha256((dest/n).read_bytes()).hexdigest()
    manifest['provisional_names']=75;write(dest/'manifest.json',manifest)
    print('PROVISIONAL NAMES: 75; original unknown geometries and membership status retained')
