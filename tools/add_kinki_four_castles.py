"""One-time user-requested additions. Subsequent edits belong in editorial JSON."""
import copy
import csv
import json
from pathlib import Path
from pyproj import Geod

ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d): (ROOT/p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    master=read('data/editorial/settlements/settlements_1582.json')
    assert not any(s['id']=='kishiwada_castle' for s in master['sites']), 'Already applied; edit the master directly.'
    sources=read('data/editorial/settlements/sources.json')
    rows={r['id']:r for r in csv.DictReader((ROOT/'data/sources/settlements/nrct-poi-20250515.csv').open(encoding='utf-8-sig'))}
    additions=[
        ('kishiwada_castle','岸和田城','izumi','280000448100','https://www.city.kishiwada.lg.jp/page/36-kishiwadajyo.html',
         '岸和田市・岸和田城','戦国期の城として採用。1585年以後の近世整備・後世の天守形状は表さない。','inferred'),
        ('ishiyama_honganji','石山本願寺','settsu','280000098900','https://www.city.osaka.lg.jp/chuo/page/0000641506.html',
         '大阪市・石山（大坂）本願寺推定地','1580年に退去・焼失した寺院城郭。1582年に本願寺が活動中だったという設定ではない。ユーザー指定により旧寺域を城としてゲームに採用。','scenario_override'),
        ('takaya_castle','高屋城','kawachi','280000334800','https://www.city.habikino.lg.jp/soshiki/shougaigakushu/bunka-sekai/bunkazainikansurukoto/bunkazai_shokai/muromachi_sengoku/2427.html',
         '羽曳野市・高屋城跡','1575年に焼き討ちされ廃城。ユーザー指定により旧城域を城としてゲームに採用し、1582年の現役城郭とは断定しない。','scenario_override'),
        ('tsutsui_castle','筒井城','yamato','300000219800','https://www.pref.nara.lg.jp/site/aruku/1166.html',
         '奈良県・城下町大和郡山を歩く','筒井順慶は1580年に筒井城から郡山城へ移転。ユーザー指定により旧城域を城としてゲームに採用。1582年の城主居城とは断定しない。','scenario_override')]
    for sid,name,province,poi,url,title,note,status in additions:
        row=rows[poi];ref='addition:'+sid
        location='CODHの城跡項目による地域代表点。曲輪・門の精密位置ではない。'
        if sid=='ishiyama_honganji': location='大阪市が大阪城内を推定地とする説明に基づき、CODHの大坂城跡代表点を概略位置として使用。後世の大阪城と地形が異なり、石山本願寺の正確な寺域・本堂位置を示さない。'
        sources.append(dict(id=ref,title=title,url=url,locator='自治体による沿革・所在地の本文',observation=note,read_status='read',accessed='2026-09-12'))
        claim=dict(source_ref=ref,locator='沿革・所在地',assessment='reference_or_inference')
        coord=dict(source_ref='nrct_poi_20250515',locator='POI '+poi,assessment='modern_reference_coordinate_only')
        master['sites'].append(dict(id=sid,name_1582=None,display_name=name,aliases=[name,row['名称']],roles=['castle'],site_group_id=sid,
            province_id=province,region_id='kinki',temporal_status=status,temporal_note=note,name_status='reference_name',
            name_note='ユーザー指定名称。1582年当年の呼称・機能の復元とは別。',validity_evidence=[dict(source_ref=ref,locator='沿革',note=note)],
            lonlat=[float(row['経度']),float(row['緯度'])],location_status='area_estimate',location_note=location,location_poi_id=poi,
            uncertainty_m=None,display_anchor=None,importance=1,selection_reason='ユーザー指定の城を追加。'+note,adoption_status='accepted',
            adoption_reason='ユーザー指定によるゲーム用城拠点。年代上の相違は詳細に保持。',source_refs=[ref,'nrct_poi_20250515'],
            claims=dict(name=[claim],temporal=[claim],location=[coord,claim],function=[claim]),connection_anchors=[],
            review_notes=['2026-09-12追加。城分類はユーザー指定。'],port_type=None,user_requested_addition=True))
    allocation=master['allocation_policy']
    allocation['base_targets']=copy.deepcopy(allocation['targets'])
    allocation['user_additions']={'kinki':4};allocation['total']=254;allocation['targets']['kinki']+=4
    allocation['method']='largest_remainder_base_plus_user_additions'
    master['coverage']='全国254拠点。従来250拠点にユーザー指定の近畿4城を追加。年代・位置の例外は各拠点の詳細に明記。'
    geod=Geod(ellps='WGS84');newids={r[0] for r in additions}
    for a in master['sites']:
        if a['id'] not in newids: continue
        for b in master['sites']:
            if a['id']==b['id'] or b['adoption_status']!='accepted': continue
            if geod.inv(*a['lonlat'],*b['lonlat'])[2]<3500:
                master['proximity_decisions']['|'.join(sorted([a['id'],b['id']]))]='筒井城と郡山城は異なる城域。1580年の居城移転先・移転元として区別し、ユーザー指定により両拠点を保持。'
    write('data/editorial/settlements/settlements_1582.json',master)
    write('data/editorial/settlements/sources.json',sources)
    plan=read('data/editorial/road_connections/plan.json');lookup={s['id']:s for s in master['sites']}
    chains={'link_117':['site_1582_settsu_129','ishiyama_honganji','sakai_town'],
            'link_118':['sakai_town','takaya_castle','tsutsui_castle','site_1582_yamato_145'],
            'link_121':['sakai_town','kishiwada_castle','saika_town']}
    result=[];next_id=max(int(r['id'].split('_')[1]) for r in plan['plans'])+1
    for route in plan['plans']:
        if route['id'] not in chains: result.append(route);continue
        ids=chains[route['id']]
        for i,(a,b) in enumerate(zip(ids,ids[1:])):
            r=copy.deepcopy(route)
            if i: r['id']=f'link_{next_id:03}';next_id+=1
            r.update(from_site=a,to_site=b,name=lookup[a]['display_name']+'―'+lookup[b]['display_name'],via=[],
                purpose='追加城を経由する摂津・和泉・河内・大和の推定連絡',note='ユーザー指定の追加城を地域網に組み込む。年代上の採用例外を含むゲーム用推定路であり、史実の道路ではない。')
            result.append(r)
    plan['plans']=result;plan['target_sites']=sorted(plan['target_sites']+list(newids))
    write('data/editorial/road_connections/plan.json',plan)

if __name__=='__main__': main()
