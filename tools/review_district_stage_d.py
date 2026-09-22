"""Review SVGs of closed candidates, unresolved land and preserved differences."""
from html import escape
from pathlib import Path
from shapely.geometry import shape
from PIL import Image, ImageDraw, ImageFont
from build_district_stage_c import ROOT, read
from build_district_stage_d import WORK, EDITOR, parts

def main():
    names={r['region_id']:r.get('display_name',r.get('name',r['region_id'])) for r in read('data/derived/political/approved_western/political_registry.json')['regions']}
    # Use the locked display names from A rather than guessing registry name keys.
    names.update({p['parent_region_id']:p['display_name'] for p in read('data/editorial/districts/scope.json')['parents']})
    rows=['# 工程D・閉区画の確認一覧','','黄：未確定領域、青緑：後世資料の郡候補。候補も1582年の採用は保留。右図は赤：資料側だけにある面、黄：現行国側だけにある面。面積の割合は現行親領域に対する割合。','','|現行親領域|閉区画数|未確定面積率|確認資料|','|---|---:|---:|---|']
    for item in read(EDITOR/'inventory.json')['parents']:
        rid=item['parent_region_id'];d=read(WORK/rid/'partition.json');diff=read(WORK/rid/'differences.json')
        parent=shape(d['parent_geometry']);outside=shape(diff['source_minus_parent'])
        bounds=parent.union(outside).bounds;x0,y0,x1,y1=bounds;s=min(600/(x1-x0),690/(y1-y0))
        def pt(p,offset): return (offset+(p[0]-x0)*s,120+(p[1]-y0)*s)
        def path(g,offset):
            seq=[]
            for p in parts(g):
                for ring in [p.exterior,*p.interiors]:
                    coords=[pt(c,offset) for c in ring.coords]
                    seq.append('M'+' L'.join(f'{x:.5f},{y:.5f}' for x,y in coords)+' Z')
            return ' '.join(seq)
        svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="900" viewBox="0 0 1400 900">','<rect width="1400" height="900" fill="#f5f3ed"/>',f'<text x="35" y="38" font-family="sans-serif" font-size="24">{escape(names[rid])} — 工程D・閉区画の比較案</text>','<text x="35" y="72" font-family="sans-serif" font-size="17">左：候補と未確定領域（黄）　右：現行国と資料の差分（赤＝資料側のみ、黄＝現行国側のみ）</text>']
        for r in d['regions']:
            color='#eabc55' if r['kind']=='unresolved' else '#bddbd5'
            svg.append(f'<path d="{path(shape(r["polygon_geometry"]),35)}" fill="{color}" fill-rule="evenodd"><title>{escape(r["region_id"])} / {r["reason"]}</title></path>')
        for a in d['boundaries']:
            coords=' '.join(f'{x:.5f},{y:.5f}' for x,y in [pt(p,35) for p in a['points']])
            color='#263c40' if a['boundary_kind']=='parent_outer' else '#40867f'
            svg.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="0.85"/>')
        for field,color in [('source_minus_parent','#d77870'),('parent_minus_source','#eabc55')]:
            svg.append(f'<path d="{path(shape(diff[field]),740)}" fill="{color}" fill-rule="evenodd"/>')
        svg.append(f'<path d="{path(parent,740)}" fill="none" stroke="#263c40" stroke-width="0.85"/>')
        svg+=['<text x="35" y="855" font-family="sans-serif" font-size="15">1582年の歴史的境界は未確定。現行国の外周を保持し、資料のない面を郡へ拡張していません。</text>','<text x="35" y="880" font-family="sans-serif" font-size="12">CODH / NIHU, doi:10.20676/00000454, CC BY-NC 4.0. Research comparison.</text>','</svg>']
        (WORK/rid/'review.svg').write_text('\n'.join(svg),encoding='utf-8')
        ratio=100*d['qa']['unresolved_area_world2']/parent.area;base=f'../../data/work/districts/stage_d/{rid}'
        rows.append(f'|{names[rid]} (`{rid}`)|{len(d["regions"])}|{ratio:.2f}%|[確認図]({base}/review.svg)・[面／共有辺／隣接]({base}/partition.json)・[差分と理由]({base}/differences.json)|')
        if rid=='izumi':
            im=Image.new('RGB',(1400,900),'#f5f3ed');draw=ImageDraw.Draw(im)
            font=ImageFont.truetype('C:/Windows/Fonts/meiryo.ttc',20)
            draw.text((35,25),'和泉国：閉区画の比較案 ／ 右：現行国との差分',fill='#263c40',font=font)
            for r in d['regions']:
                for p in parts(shape(r['polygon_geometry'])):
                    draw.polygon([pt(c,35) for c in p.exterior.coords],fill='#eabc55' if r['kind']=='unresolved' else '#bddbd5')
                    for ring in p.interiors: draw.polygon([pt(c,35) for c in ring.coords],fill='#f5f3ed')
            for a in d['boundaries']: draw.line([pt(c,35) for c in a['points']],fill='#40867f',width=1)
            for field,color in [('source_minus_parent','#d77870'),('parent_minus_source','#eabc55')]:
                for p in parts(shape(diff[field])):
                    draw.polygon([pt(c,740) for c in p.exterior.coords],fill=color)
                    for ring in p.interiors: draw.polygon([pt(c,740) for c in ring.coords],fill='#f5f3ed')
            for p in parts(parent): draw.line([pt(c,740) for c in p.exterior.coords],fill='#263c40',width=2)
            draw.text((35,845),'黄：未確定領域　赤：親領域外の資料形状　青緑：後世の郡候補（採用保留）',fill='#263c40',font=font)
            im.save(WORK/rid/'review.png')
    (ROOT/'docs/districts/STAGE_D_INDEX.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')
    print('66 SVG reviews, index, Izumi PNG generated')

if __name__=='__main__': main()
