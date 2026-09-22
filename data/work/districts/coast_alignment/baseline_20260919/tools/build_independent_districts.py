"""Restore comparison district shapes without intersecting political polygons."""
import json
import hashlib
from pathlib import Path
from shapely.geometry import shape, Polygon, Point, mapping
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def parts(g):
    if g.geom_type=='Polygon': return [g]
    return [p for c in getattr(g,'geoms',[]) for p in parts(c)]

def build():
    index=read('data/derived/districts/unconfirmed/index.json')
    merged=read('data/derived/districts/unconfirmed/merge_report.json')['source_to_display']
    output={};report={};inputs={}
    for parent in index['parents']:
        pid=parent['id'];path=f'data/work/districts/stage_c/{pid}/network.json'
        data=read(path);inputs[path]=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
        grouped={}
        for c in data['candidates']:
            original=pid+'/candidate-'+c['candidate_id']
            key=merged.get(original,original)
            if c['target_adoption_status']=='excluded': continue
            grouped.setdefault(key,[]).append(shape(c['polygon_geometry']))
        old=read(parent['file'].removeprefix('res://'))
        for r in old['regions']:
            key=r['key'];reference=unary_union([Polygon(p[0],p[1:]) for p in r['polygons']])
            restored=unary_union(grouped[key]) if key in grouped else reference
            assert restored.is_valid and not restored.is_empty
            # Display tolerance only; no snapping or clipping against a country.
            g=restored.simplify(.15,preserve_topology=True)
            polygons=[[list(p.exterior.coords)]+[list(h.coords) for h in p.interiors] for p in parts(g)]
            meta=next(m for m in index['regions'] if m['key']==key)
            label=meta['label'] if g.contains(Point(meta['label'])) else list(g.representative_point().coords)[0]
            output[key]={'polygons':polygons,'bounds':g.bounds,'label':label,'parent':pid}
            report[key]={'basis':'unclipped_comparison' if key in grouped else 'existing_unresolved_shape',
                         'restored_outside_previous_shape_world2':restored.difference(reference).area}
    from merge_district_enclaves import merge
    data=merge({'version':1,'regions':output,'sources':inputs,'review':report})
    from remove_provisional_overlaps import clean
    data=clean(data)
    from resolve_district_overlaps import resolve
    data=resolve(data)
    from curate_island_districts import curate
    data=curate(data)
    dest=ROOT/'data/derived/scenarios/independent_districts_1546.json'
    dest.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    (dest.parent/'district_connectivity_1546.json').write_text(json.dumps(data['connectivity'],ensure_ascii=False,separators=(',',':')),encoding='utf8')
    print(data['connectivity']['stats'])
    print(f'{len(output)} districts; {sum(r["basis"]=="unclipped_comparison" for r in report.values())} restored from unclipped sources')
    return output,report

if __name__=='__main__': build()
