"""Apply the explicitly reviewed castle map discrepancies to the editorial master."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,v):(ROOT/p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def reconcile():
    master=read('data/editorial/settlements/settlements_1582.json');sources=read('data/editorial/settlements/sources.json')
    sites={s['id']:s for s in master['sites']};additions=read('data/editorial/settlements/expansion_250/adopted_additions.json')
    results=read('data/editorial/settlements/expansion_250/coordinate_audit_results.json')
    chosen={5,13,36,44,69,86,88,141,142,154,168,169,170,184}
    for r in results:
        i=r['index'];a=additions[i];s=sites[f'site_1582_{a["province"]}_{i:03}']
        if i not in chosen:
            r['decision']='現代参照地図間の差が600m以内。地域代表点として元座標を保持。';continue
        ref=f'location_review_250_{i:03}'
        assert ref not in {x['id'] for x in sources},'Already reconciled; edit master instead.'
        r['decision']='所在地・旧国・城名を照合し、城域を中心とした参照地図の代表点へ修正。歴史的位置の精密比定とはしない。'
        old=s['lonlat'];s['lonlat']=[round(v,6) for v in r['reference_lonlat']]
        s['coordinate_revision']=dict(previous_lonlat=old,source_ref=ref,reason=r['decision'])
        s['source_refs'].append(ref)
        s['claims']['location']=[dict(source_ref=ref,locator='対象城の地図中心（近隣施設の地図リンクではない）',assessment='secondary_map_area_estimate')]
        s['location_note']+=' 所在地を再照合し、城郭放浪記の対象城地図中心へ代表点を修正。以前の点との差は約'+str(round(r['difference_m']))+'m。歴史的な曲輪・岸線の精密比定ではない。'
        sources.append(dict(id=ref,title='城郭放浪記・'+r['name']+'（位置照合）',url=r['url'],publisher='城郭放浪記',publication_year=None,accessed='2026-09-11',locator='対象城の地図中心・所在地説明',observation=r['decision'],read_status='map_metadata',scope='対象城の参照地図中心座標を確認。歴史の一次史料としては用いない。',redistribute_original=False))
    master['spatial_decisions']={'site_1582_ise_103':'三重県文化施設案内の桑名宗社座標とも照合。旧町の陸上地点だが、既存の簡略化された揖斐川水面ポリゴンと重なる。神社を港そのものとせず旧町代表点として保持し、水面データの形状調整は別課題とする。','site_1582_bingo_161':'鞆の旧港町代表点。簡略化された海岸線との不一致として保持。','site_1582_iyo_189':'川之江城の城山代表点。簡略化された海岸線との不一致として保持。','site_1582_sanuki_195':'引田城の岬上代表点。簡略化された海岸線との不一致として保持。'}
    write('data/editorial/settlements/settlements_1582.json',master);write('data/editorial/settlements/sources.json',sources)
    write('data/editorial/settlements/expansion_250/coordinate_audit_results.json',results)
    print('Reviewed coordinate corrections:',len(chosen))
if __name__=='__main__':reconcile()
