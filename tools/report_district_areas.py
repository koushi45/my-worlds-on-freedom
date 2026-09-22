"""Measure the exact display polygons shipped in the unconfirmed edition."""
from pathlib import Path
import json
import hashlib
import statistics
from html import escape
from shapely.geometry import Polygon, shape
from shapely.geometry.polygon import orient
from shapely.ops import unary_union, transform
from pyproj import Geod
from build_district_stage_c import transforms

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/derived/districts/unconfirmed'
OUT = ROOT / 'docs/districts/areas'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def area_measure():
    m, _, ll = transforms()
    geod = Geod(ellps='WGS84')
    def area_km2(g):
        # Densify the projected straight edges before inversion. Hole orientation
        # is normalized in geographic coordinates, after the world y-axis flip.
        geographic = transform(ll, g.segmentize(2.0))
        parts = [geographic] if geographic.geom_type == 'Polygon' else geographic.geoms
        return sum(abs(geod.geometry_area_perimeter(orient(p, sign=1.0))[0]) for p in parts) / 1e6
    return m, area_km2


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    index = read(SOURCE / 'index.json')
    m, area_km2 = area_measure()
    records = {r['key']: r for r in index['regions']}
    rows, countries = [], []
    hashes = {'index.json': hashlib.sha256((SOURCE/'index.json').read_bytes()).hexdigest()}
    for parent in index['parents']:
        pid = parent['id']
        path = SOURCE / pid / 'geometry.json'
        hashes[pid+'/geometry.json'] = hashlib.sha256(path.read_bytes()).hexdigest()
        data = read(path)
        shapes = {r['key']: unary_union([Polygon(p[0], p[1:]) for p in r['polygons']]) for r in data['regions']}
        whole = unary_union(list(shapes.values()))
        original_parent = shape(read(ROOT/f'data/work/districts/stage_d/{pid}/partition.json')['parent_geometry'])
        assert whole.symmetric_difference(original_parent).area < 1e-6
        assert abs(sum(g.area for g in shapes.values())-whole.area) < 1e-6
        parent_area = area_km2(whole)
        local = []
        for key, g in shapes.items():
            r = records[key]
            assert g.is_valid and g.area > 0
            area = area_km2(g)
            row = dict(key=key, parent=pid, country=r['parent_name'], name=r['name'],
                kind=r['kind'], category='郡候補' if r['kind']=='candidate' else ('仮称・所属未確定' if r.get('provisional_name') else '未確定領域'),
                area_km2=area, world_area=g.area, projected_area_km2=g.area/m['uniform_scale_px_per_m']**2/1e6,
                country_share_pct=100*area/parent_area, world_share_pct=100*g.area/whole.area,
                parts=len(g.geoms) if g.geom_type=='MultiPolygon' else 1,
                target_year=r['target_year'], adoption=r['adoption'], sources=r['sources'],
                merged_from=r.get('merge_members',[]),provisional_name=r.get('provisional_name'))
            rows.append(row); local.append(row)
        discrepancy = abs(sum(r['area_km2'] for r in local)-parent_area)
        assert discrepancy < .01, (pid, discrepancy)
        countries.append(dict(parent=pid, country=local[0]['country'], area_km2=parent_area,
            candidates=sum(r['kind']=='candidate' for r in local), unresolved=sum(r['kind']=='unresolved' for r in local),
            unresolved_area_km2=sum(r['area_km2'] for r in local if r['kind']=='unresolved'),
            sum_error_km2=discrepancy))
    assert len(rows)==len(records) and len(countries)==66
    rows.sort(key=lambda r: (-r['area_km2'],r['key']))
    for rank, row in enumerate(rows,1): row['rank']=rank
    candidates=[r for r in rows if r['kind']=='candidate']
    summary=dict(parents=66, regions=len(rows), candidates=len(candidates), unresolved=len(rows)-len(candidates),
        candidate_total_km2=sum(r['area_km2'] for r in candidates),
        unresolved_total_km2=sum(r['area_km2'] for r in rows if r['kind']=='unresolved'),
        candidate_median_km2=statistics.median(r['area_km2'] for r in candidates),
        candidate_mean_km2=statistics.mean(r['area_km2'] for r in candidates),
        maximum=candidates[0], minimum=candidates[-1])
    payload=dict(date='2026-09-12', edition='unconfirmed', method='WGS84 ellipsoidal area after inverse game LCC transform; segmentized at 2 world units; holes subtracted',
        game_transform=m, summary=summary, source_sha256=hashes, countries=countries, rows=rows,
        qa=dict(status='passed', all_display_records_measured=True, all_parent_coverage_unchanged=True,
            maximum_parent_sum_error_km2=max(c['sum_error_km2'] for c in countries)))
    (OUT/'district_areas.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    intro=f'未確定版の表示形状を計測。郡候補{len(candidates)}件と未確定領域{len(rows)-len(candidates)}件を区別しています。km²は既存座標を緯度経度へ逆変換して求めたWGS84楕円体上の換算面積で、1582年の確定面積ではありません。'
    lines=['# 郡の面積一覧（未確定版）','',intro,'',
        '[検索・並べ替え付き一覧](district_areas.html) ／ [数値・出典・検査記録](district_areas.json)','',
        f'66親領域・{len(rows)}表示区画。郡候補の中央値 {summary["candidate_median_km2"]:,.3f} km²、平均 {summary["candidate_mean_km2"]:,.3f} km²。','',
        '「国比」は同じ表示親領域の地表換算面積に対する割合。「地図面積」は8192×8192座標系の単位²で、画面のズームでは変わりません。面の穴を除き、飛び地は同じ区画として合計しています。未確定領域は郡の面積に加算していません。','',
        '元の表示面は現行国・簡略海岸で閉じた候補です。近代の郡や史料に記載された面積とは一致するとは限りません。同名でも国・区画IDが異なる行を統合していません。小さい断片も省略していません。小数3桁は区画の大きさを比較するためで、史料の精度を表すものではありません。','',
        '## 国別集計','', '|国|郡候補数|未確定数|表示国面積 km²|未確定面積 km²|','|---|---:|---:|---:|---:|']
    for c in sorted(countries,key=lambda c:c['parent']):
        lines.append(f'|{c["country"]}|{c["candidates"]}|{c["unresolved"]}|{c["area_km2"]:,.3f}|{c["unresolved_area_km2"]:,.3f}|')
    lines+=['','## 全区画（面積の大きい順）','','|順位|国|郡・領域名|区分|面積 km²|国比 %|地図面積 単位²|区画ID|','|---:|---|---|---|---:|---:|---:|---|']
    for r in rows:
        lines.append(f'|{r["rank"]}|{r["country"]}|{r["name"]}|{r["category"]}|{r["area_km2"]:,.3f}|{r["country_share_pct"]:.3f}|{r["world_area"]:,.3f}|{r["key"]}|')
    lines+=['','出典：CODH／人間文化研究機構（CC BY-NC 4.0）等を加工した既存表示形状。行別の史料参照はJSONのsourcesに保存。国境・海岸線・ゲーム座標変換は既存プロジェクトのものを使用。','']
    (OUT/'DISTRICT_AREAS.md').write_text('\n'.join(lines),encoding='utf-8')
    html='''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>郡の面積一覧・未確定版</title>
<style>body{font:15px/1.65 system-ui,sans-serif;margin:24px;color:#203335;background:#f7f8f4}h1{font-size:26px;margin-bottom:4px}p{max-width:1100px}input,select{font:inherit;padding:8px;margin:4px;border:1px solid #a5b2af;border-radius:5px}table{border-collapse:collapse;width:100%;background:white}th,td{padding:8px 12px;border-bottom:1px solid #dce2df;text-align:left}th{position:sticky;top:0;background:#244c45;color:white;cursor:pointer}td.num{text-align:right;font-variant-numeric:tabular-nums}.pending{background:#fff8e8}small{color:#64746b}#count{padding:12px 0}.scroll{max-height:70vh;overflow:auto;border:1px solid #c5d0ca}.stats{padding:12px;background:#e5eee9;border-radius:6px}</style>
<h1>郡の面積一覧 <small>未確定版</small></h1><p>INTRO</p>
<div class="stats">SUMMARY</div><p>国比は同じ表示国に占める地表換算面積の割合。地図面積は8192×8192座標の単位²です。穴は除外し、飛び地は同じ区画に合計。3桁表示は比較用で、史料精度を意味しません。</p>
<label>検索 <input id="query" placeholder="国名・郡名・区画ID"></label><label>国 <select id="country"><option value="">すべての国</option></select></label><label>区分 <select id="kind"><option value="">すべて</option><option value="candidate">郡候補のみ</option><option value="unresolved">未確定領域のみ</option></select></label>
<div id="count" aria-live="polite"></div><div class="scroll"><table><thead><tr><th data-k="rank">全体順位</th><th data-k="country">国</th><th data-k="name">郡・領域名</th><th data-k="category">区分</th><th data-k="area_km2">面積 km² ↕</th><th data-k="country_share_pct">国比 % ↕</th><th data-k="world_area">地図面積 単位² ↕</th><th data-k="key">区画ID</th></tr></thead><tbody id="body"></tbody></table></div>
<p><a href="DISTRICT_AREAS.md">全文一覧</a> ／ <a href="district_areas.json">数値・出典・検査記録</a></p>
<script>const rows=DATA;const $=id=>document.getElementById(id);const fmt=x=>x.toLocaleString('ja-JP',{minimumFractionDigits:3,maximumFractionDigits:3});let sort='area_km2',dir=-1;
for(const name of [...new Set(rows.map(r=>r.country))].sort((a,b)=>a.localeCompare(b,'ja'))){const o=document.createElement('option');o.value=o.textContent=name;$('country').append(o);}
function render(){let a=rows.filter(r=>(!$('country').value||r.country===$('country').value)&&(!$('kind').value||r.kind===$('kind').value)&&(`${r.country} ${r.name} ${r.key}`.toLowerCase().includes($('query').value.trim().toLowerCase())));a.sort((a,b)=>dir*(typeof a[sort]==='number'?a[sort]-b[sort]:a[sort].localeCompare(b[sort],'ja')));$('body').replaceChildren();for(const r of a){const tr=document.createElement('tr');if(r.kind==='unresolved')tr.className='pending';for(const k of ['rank','country','name','category','area_km2','country_share_pct','world_area','key']){const td=document.createElement('td');td.textContent=typeof r[k]==='number'&&k!=='rank'?fmt(r[k]):r[k];if(typeof r[k]==='number')td.className='num';tr.append(td);}$('body').append(tr);}$('count').textContent=`表示 ${a.length} / 748件　選択範囲の面積合計 ${fmt(a.reduce((s,r)=>s+r.area_km2,0))} km²（未確定領域を含む選択時は別区分も合計）`;}
for(const id of ['query','country','kind'])$(id).addEventListener('input',render);for(const th of document.querySelectorAll('[data-k]'))th.addEventListener('click',()=>{dir=sort===th.dataset.k?-dir:(['area_km2','country_share_pct','world_area'].includes(th.dataset.k)?-1:1);sort=th.dataset.k;render();});render();</script></html>'''
    html=html.replace('INTRO',escape(intro)).replace('SUMMARY',f'66領域 ／ 郡候補{len(candidates)}件・未確定領域{len(rows)-len(candidates)}件 ／ 郡候補の中央値 {summary["candidate_median_km2"]:,.3f} km²')
    html=html.replace('/ 748件','/ ${rows.length}件')
    html=html.replace('DATA',json.dumps(rows,ensure_ascii=False).replace('<','\\u003c'))
    (OUT/'district_areas.html').write_text(html,encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False,indent=2))


if __name__=='__main__': main()
