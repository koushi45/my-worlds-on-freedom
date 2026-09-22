"""Local review display cache: per-parent geometry, indexed metadata and terrain fills."""
from pathlib import Path
import math, json, argparse
import numpy as np
import shapely
from shapely.geometry import shape, Polygon, box, mapping
from build_district_stage_c import ROOT, read, write, sha

OUT=ROOT/'data/work/districts/stage_f'

def parts(g):
    if g.geom_type=='Polygon': return [g]
    return [p for c in getattr(g,'geoms',[]) for p in parts(c)]

def terrain_triangles(g):
    x0,y0,x1,y1=g.bounds; cells=[]
    for y in range(math.floor(y0/16)*16,math.ceil(y1/16)*16,16):
        for x in range(math.floor(x0/16)*16,math.ceil(x1/16)*16,16):
            cells.extend([Polygon([(x,y),(x+16,y),(x,y+16)]),Polygon([(x+16,y),(x+16,y+16),(x,y+16)])])
    if not cells: return np.empty((0,2),dtype='<f4')
    cells=np.array(cells,dtype=object)
    clipped=shapely.intersection(cells[shapely.intersects(cells,g)],g)
    tris=shapely.get_parts(shapely.constrained_delaunay_triangles(clipped))
    coords=[]
    for t in tris:
        if t.area>0: coords.extend(list(t.exterior.coords)[:3])
    return np.asarray(coords,dtype='<f4').reshape((-1,2))

def main(only_parent=None):
    names={p['parent_region_id']:p['display_name'] for p in read('data/editorial/districts/scope.json')['parents']}
    sites=[s for s in read('data/work/districts/stage_e/site_assignments.json')['sites'] if s['scope']=='requested_254']
    index=[];parents=[];inputs=[];tri_count=0
    if only_parent:
        assert only_parent in names, 'Unknown parent'
        if (OUT/'index.json').exists():
            old=read(OUT/'index.json')
            index=[r for r in old['regions'] if r['parent']!=only_parent]
            parents=[p for p in old['parents'] if p['id']!=only_parent]
            inputs=[f for f in read(OUT/'input_manifest.json')['files'] if f['path'].replace('\\','/').startswith('data/work/districts/stage_d/') and f['path'].replace('\\','/')!=f'data/work/districts/stage_d/{only_parent}/partition.json']
    for path in sorted((ROOT/'data/work/districts/stage_d').glob('*/partition.json')):
        if only_parent and path.parent.name!=only_parent: continue
        d=read(path);pid=d['parent_region_id'];cs={c['candidate_id']:c for c in d['candidates']}
        payload=dict(regions=[],lines=[])
        for r in d['regions']:
            key=pid+'/'+r['region_id'];g=shape(r['polygon_geometry']);p=max(parts(g),key=lambda p:p.area).representative_point()
            name='郡未確定' if r['kind']=='unresolved' else '・'.join(cs[c]['candidate_name'] for c in r['candidate_refs'])
            affiliated=[]
            for s in sites:
                direct=any(a['key']==key for a in s.get('containing_regions',[]))
                near=any(a['key']==key for a in s.get('nearby_review_regions',[]))
                if direct or near:
                    affiliated.append(dict(name=s['display_name'],id=s['site_id'],status=s['assignment_status'],
                        basis='登録座標の包含候補' if direct else '境界付近の候補',history=s['historical_comparison']))
            sources=[dict(title='CODH 旧国・旧郡境界データセット',locator=cs[c]['source_locator'],
                url='https://geoshape.ex.nii.ac.jp/kg/geojson/'+cs[c]['external_id']+'.geojson') for c in r['candidate_refs']]
            meta=dict(key=key,parent=pid,parent_name=names[pid],name=name,kind=r['kind'],bounds=g.bounds,
                label=list(p.coords[0]),target_year=1582,source_epoch='幕末・明治等の後世比較',adoption='保留',
                confidence='位置・年代未確定',sources=sources,sites=affiliated,
                remaining='史料所属・1582年への継続・位置精度を確認。未確定領域は近隣郡へ拡張していません。',
                mesh_file=f'res://data/work/districts/stage_f/{pid}/{r["region_id"]}.bin')
            index.append(meta)
            payload['regions'].append(dict(key=key,polygons=[[list(q.exterior.coords)]+[list(h.coords) for h in q.interiors] for q in parts(g)]))
            triangles=terrain_triangles(g);tri_count+=len(triangles)//3
            dest=OUT/pid/(r['region_id']+'.bin');dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(triangles.tobytes())
            assert g.contains(p)
        for a in d['boundaries']:
            if a['boundary_kind']=='parent_outer': continue
            line=shapely.LineString(a['points'])
            payload['lines'].append(dict(id=pid+'/'+a['boundary_id'],points=a['points'],bounds=line.bounds,
                owners=[pid+'/'+v for v in a['owners']]))
        write(OUT/pid/'geometry.json',payload)
        parents.append(dict(id=pid,bounds=shape(d['parent_geometry']).bounds,file=f'res://data/work/districts/stage_f/{pid}/geometry.json'))
        inputs.append(dict(path=str(path.relative_to(ROOT)),sha256=sha(path)))
        print(pid,flush=True)
    tri_count=sum((ROOT/r['mesh_file'].removeprefix('res://')).stat().st_size//24 for r in index)
    write(OUT/'index.json',dict(regions=sorted(index,key=lambda r:r['key']),parents=sorted(parents,key=lambda p:p['id']),world_size=[8192,8192],terrain_step=16,
        status='research_comparison_not_historical_adoption',export_allowed=False,
        credit='CODH / 人間文化研究機構 doi:10.20676/00000454 CC BY-NC 4.0',triangles=tri_count))
    for p in [ROOT/'data/work/districts/stage_e/site_assignments.json',ROOT/'data/editorial/districts/scope.json']:
        inputs.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p)))
    write(OUT/'input_manifest.json',dict(files=inputs,generator_sha256=sha(Path(__file__))))
    print('regions',len(index),'triangles',tri_count)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--parent');args=parser.parse_args();main(args.parent)
