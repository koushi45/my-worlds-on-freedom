"""Build the independent settlement layer from reviewed editorial JSON."""
import hashlib
from itertools import combinations
import json
from pathlib import Path
from collections import Counter
from pyproj import Transformer, Geod
from shapely.geometry import Point, Polygon, shape
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[1]
REGIONS={'south_kyushu':'日向・大隅・薩摩','kyushu':'九州北部・中部','chugoku':'中国','shikoku':'四国','kinki':'近畿','tokai':'東海','koshin':'甲信','kanto':'関東','hokuriku':'北陸','tohoku':'東北','hokkaido':'北海道'}
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d):
    p=ROOT/p;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def build():
    paths=['data/editorial/settlements/settlements_1582.json','data/editorial/settlements/sources.json','data/base/japan_land_manifest.json','data/base/japan_land.gpkg','data/derived/hydrography/water_registry.json','data/derived/political/approved_western/political_registry.json']
    master=read(paths[0]);sources=read(paths[1]);m=read(paths[2])['game_transform']
    proj=Transformer.from_crs('EPSG:4326',m['projection'],always_xy=True)
    def xy(ll):
        x,y=proj.transform(*ll)
        return [m['offset_x_px']+(x-m['projected_scope_bounds_m'][0])*m['uniform_scale_px_per_m'],m['offset_y_px']+m['content_height_px']-(y-m['projected_scope_bounds_m'][1])*m['uniform_scale_px_per_m']]
    geod=Geod(ellps='WGS84')
    land=unary_union([shape(f['geometry']) for f in read('data/base/japan_land.geojson')['features']])
    water=read(paths[4]);areas=[(w['id'],Polygon(w['rings'][0],w['rings'][1:])) for w in water['lakes']]
    political=read(paths[5])
    provinces={r['region_id']:r['name_ja'] for r in political['regions']}
    provinces.update(mutsu='陸奥国',dewa='出羽国',ezo='蝦夷地',awa_boso='安房国')
    province_shapes=[(r['region_id'],Polygon(poly)) for r in political['regions'] for poly in r['polygons']]
    known={s['id'] for s in sources};ids=set();sites=[];reviews=[]
    for s in master['sites']:
        assert s['id'] not in ids,s['id'];ids.add(s['id'])
        assert set(s['source_refs']) <= known
        assert s['adoption_status']!='accepted' or s['temporal_status']!='out_of_period'
        r=dict(s);ll=s['lonlat'];r['point']=xy(ll) if ll else None
        r['province_name']=provinces.get(s['province_id'],s['province_id'])
        r['display_point']=xy(s['display_anchor']) if s['display_anchor'] else r['point']
        sites.append(r)
        issues=[]
        if ll:
            assert 128 <= ll[0] <= 146 and 30<=ll[1]<=46
            if not land.covers(Point(ll)):issues.append('outside_simplified_base_land')
            for i,g in areas:
                if g.covers(Point(r['point'])):issues.append('inside_modern_water:'+i)
            containing=[i for i,g in province_shapes if g.covers(Point(r['point']))]
            if containing and s['province_id'] not in containing:
                issues.append('province_comparison:'+','.join(containing))
            for i,g in province_shapes:
                if g.boundary.distance(Point(r['point'])) < 1000*m['uniform_scale_px_per_m']:
                    issues.append('within_1km_of_approximate_border:'+i)
        else:issues.append('unlocated')
        decision=master.get('spatial_decisions',{}).get(s['id'],'原座標を保持。基礎地図の簡略化・時代差・比定位置を別途確認。' if issues else '基礎地図上の陸地・水面照合済み。歴史的位置の精密検証とは別。')
        reviews.append(dict(site_id=s['id'],issues=issues,decision=decision))
    accepted=[s for s in sites if s['adoption_status']=='accepted']
    allocation=master.get('allocation_policy',{})
    proximity=[]
    decisions=master.get('proximity_decisions',{})
    for a,b in combinations(accepted,2):
        distance=geod.inv(*a['lonlat'],*b['lonlat'])[2]
        assert distance>1,('duplicate_coordinate',a['id'],b['id'])
        if distance<3500:
            key='|'.join(sorted([a['id'],b['id']]))
            assert key in decisions,('unreviewed_nearby_sites',key,round(distance))
            proximity.append(dict(site_ids=key.split('|'),distance_m=round(distance,1),decision=decisions[key]))
    if allocation:
        assert len(accepted)==allocation['total']
        assert len({s['site_group_id'] for s in accepted})==len(accepted)
        assert dict(Counter('kyushu' if s['region_id']=='south_kyushu' else s['region_id'] for s in accepted))==allocation['targets']
    regions=[]
    for i,name in REGIONS.items():
        chosen=[s for s in sites if s['region_id']==i]
        points=[s['point'] for s in chosen if s['point'] and s['adoption_status']=='accepted']
        regions.append(dict(id=i,name=name,counts=dict(Counter(s['adoption_status'] for s in chosen)),survey_status='regional_allocation_with_historical_uncertainty',
            bounds=[min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)] if points else None))
    result=dict(schema_version=1,target_year=1582,temporal_scope=master['temporal_scope'],coverage=master['coverage'],sites=sites,sources=sources,regions=regions,review=reviews,
        allocation_policy=allocation,proximity_review=proximity,input_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths})
    write('data/derived/settlements/settlements_1582.json',result)
    report=[f'# 1582年 拠点配置・全国{len(accepted)}拠点版\n',master['coverage'],'\n全地点は地域代表点。原図の位置合わせ・曲輪・岸壁の精密比定は未実施。推定の印と詳細欄に確認状況を表示する。',
        '\n「拠点一覧」で地域・種類・名称を絞り、選択した地点へ移動。「保留も表示」で調査候補を確認する。城・集落・港は別々に切替可能。',
        '\n## 地域別の進捗\n\n|地域|採用|保留|除外|\n|---|---:|---:|---:|']
    for r in regions:report.append(f"|{r['name']}|{r['counts'].get('accepted',0)}|{r['counts'].get('deferred',0)}|{r['counts'].get('excluded',0)}|")
    report+=['\nユーザー指定の地方比率に基づくゲーム用の選定。全国の全旧国・全候補を網羅した史料調査ではない。離島や北海道の集落などは今後の調査課題。既存道路にない地点も採用したが、この工程では連絡路を生成しない。',
        '\n## 台帳\n\n|ID|表示名|種類|採否|対象時点|根拠|\n|---|---|---|---|---|---|']
    for s in sites:report.append(f"|{s['id']}|{s['display_name']}|{' / '.join(s['roles'])}|{s['adoption_status']}|{s['temporal_status']}|{s['selection_reason']}|")
    report+=['\n## 出典\n']
    for s in sources:report.append(f"- **{s['id']}** [{s['title']}]({s['url']})：{s['locator']}。{s['observation']} 閲覧範囲：{s['read_status']}。")
    report+=['\n座標データの帰属：『日本歴史地名大系』施設・地点項目データセット（CODH作成） doi:10.20676/00000456、CC BY 4.0。名称・住所・座標を照合し、代表点として利用。史料本文・原図は配布しない。', '\n## 近接拠点の確認（3.5km未満）\n']
    for r in proximity:report.append(f"- {' / '.join(r['site_ids'])}：{r['distance_m']}m。{r['decision']}")
    report+=['\n## 位置確認で残る事項\n']
    for r in reviews:
        if r['issues']:report.append(f"- {r['site_id']}：{', '.join(r['issues'])}。{r['decision']}")
    report+=['\n既存道路176地点すべてに照合結果を記録。未照合は未照合のまま保持。同じ地域の対応があっても道路座標は移動せず、接続位置は次工程で選ぶ。',
        '\n## 再生成\n\n編集は `data/editorial/settlements/settlements_1582.json` と `sources.json` に行う。`python tools/build_settlements.py` で派生データ・対応表・本書を再生成。`seed_settlements.py` は初期転記の記録であり再実行しない。']
    p=ROOT/'docs/settlements/PLACEMENT_1582.md';p.parent.mkdir(parents=True,exist_ok=True);p.write_text('\n'.join(report)+'\n',encoding='utf-8')
    print(dict(Counter(s['adoption_status'] for s in sites)),len(sites),'candidates;',sum(bool(r['issues']) for r in reviews),'spatial flags')
if __name__=='__main__':build()
