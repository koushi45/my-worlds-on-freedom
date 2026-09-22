"""Generate research comparison SVGs; never add vertices for display zoom."""
from html import escape
from build_district_stage_c import ROOT, WORK, EDITOR, read

def main():
    registry=read('data/derived/political/approved_western/political_registry.json')
    parents={r['region_id']:r for r in registry['regions']}
    inventory=read(EDITOR/'national_inventory.json')['parents']
    rows=['# 工程C・全国比較図', '', '後世の比較候補。1582年の確定境界ではありません。青：資料由来の境界（共有線は一度だけ描画）、黒破線：現行親領域。表示用に頂点を追加していません。名称は工程Bの候補表記です。', '', '|親領域|候補数|共有区間|比較図・編集正本|', '|---|---:|---:|---|']
    for item in inventory:
        rid=item['parent_region_id']; d=read(WORK/rid/'network.json')
        coords=[p for a in d['boundaries'] for p in a['points']]
        coords += [p for ring in parents[rid]['polygons'] for p in ring]
        xmin=min(p[0] for p in coords);ymin=min(p[1] for p in coords)
        xmax=max(p[0] for p in coords);ymax=max(p[1] for p in coords)
        scale=900/max(xmax-xmin,ymax-ymin)
        def pt(p): return f'{50+(p[0]-xmin)*scale:.3f},{100+(p[1]-ymin)*scale:.3f}'
        svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1070" viewBox="0 0 1000 1070">', '<rect width="1000" height="1070" fill="#f4f2eb"/>', '<g font-family="Yu Gothic, sans-serif" fill="#203039">',f'<text x="30" y="35" font-size="24">{escape(item["name"])} — 後世の郡境比較</text>', '<text x="30" y="66" font-size="14">青：比較資料　黒破線：現行親領域　位置精度不明・1582年採用未判定</text>','</g>']
        for a in d['boundaries']:
            svg.append(f'<polyline points="{" ".join(pt(p) for p in a["points"])}" fill="none" stroke="#147f8a" stroke-width="1.3"><title>{escape(a["boundary_id"])} / {escape(", ".join(a["owners"]))}</title></polyline>')
        for ring in parents[rid]['polygons']:
            svg.append(f'<polygon points="{" ".join(pt(p) for p in ring)}" fill="none" stroke="#343b40" stroke-dasharray="6 4" stroke-width="1.4"/>')
        for c in d['candidates']:
            x,y=pt(c['label_point']).split(',')
            svg.append(f'<text x="{x}" y="{y}" font-family="Yu Gothic, sans-serif" font-size="12" text-anchor="middle" fill="#18323d" stroke="#f4f2eb" stroke-width="3" paint-order="stroke">{escape(c["candidate_name"])}</text>')
        svg += ['<text x="30" y="1040" font-family="sans-serif" font-size="11">CODH / NIHU, doi:10.20676/00000454, CC BY-NC 4.0. Research comparison.</text>','</svg>']
        (WORK/rid/'comparison.svg').write_text('\n'.join(svg),encoding='utf-8')
        base=f'../../data/work/districts/stage_c/{rid}'
        rows.append(f'|{item["name"]} (`{rid}`)|{item["geometry_candidates"]}|{item["shared_arcs"]}|[比較図]({base}/comparison.svg)・[共有境界網]({base}/network.json)|')
    (ROOT/'docs/districts/STAGE_C_INDEX.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')
    print('Generated',len(inventory),'SVG comparisons and index')

if __name__=='__main__': main()
