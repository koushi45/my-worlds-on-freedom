"""Verify display cache polygons, interior labels, ownership and terrain cells."""
import numpy as np
import shapely
from shapely.geometry import shape, Point, Polygon
from build_district_stage_c import ROOT, read, sha, write, transforms
from shapely.ops import unary_union, transform
from build_district_stage_f import OUT

def main():
    manifest=read(OUT/'input_manifest.json')
    for f in manifest['files']: assert sha(ROOT/f['path'])==f['sha256'],f['path']
    assert sha(ROOT/'tools/build_district_stage_f.py')==manifest['generator_sha256']
    index=read(OUT/'index.json');assert len(index['regions'])==748
    _,xy,_=transforms()
    land_path=ROOT/'data/base/japan_land.geojson'
    land=transform(xy,unary_union([shape(f['geometry']) for f in read(land_path)['features']]))
    assert all(land.covers(Point(r['label'])) for r in index['regions'])
    lookup={r['key']:r for r in index['regions']};triangles=0;lines=0
    site_ids={s['site_id'] for s in read('data/work/districts/stage_e/site_assignments.json')['sites'] if s['scope']=='requested_254'}
    assert all(s['id'] in site_ids for r in index['regions'] for s in r['sites'])
    for parent in index['parents']:
        pid=parent['id'];source=read(ROOT/f'data/work/districts/stage_d/{pid}/partition.json')
        runtime=read(OUT/pid/'geometry.json')
        assert len(runtime['lines'])==sum(a['boundary_kind']=='internal_shared' for a in source['boundaries'])
        expected={pid+'/'+a['boundary_id']:a for a in source['boundaries'] if a['boundary_kind']=='internal_shared'}
        for line in runtime['lines']:
            assert line['points']==expected[line['id']]['points']
            assert len(line['owners'])==2
            lines+=1
        for r in source['regions']:
            key=pid+'/'+r['region_id'];meta=lookup[key];g=shape(r['polygon_geometry'])
            assert g.contains(Point(meta['label']))
            assert meta['adoption']=='保留'
            raw=np.fromfile(OUT/pid/(r['region_id']+'.bin'),dtype='<f4').astype(float).reshape((-1,3,2))
            assert np.isfinite(raw).all()
            center=raw.mean(axis=1)
            # Float32 transport has <= 0.0005 world-unit quantization, not movement of editorial geometry.
            assert shapely.covers(g.buffer(.001),shapely.points(center)).all()
            lo=raw.min(axis=1);hi=raw.max(axis=1)
            assert ((hi-lo)<=16.001).all()
            cell=np.floor((center+1e-9)/16)*16
            assert ((lo>=cell-.001)&(hi<=cell+16.001)).all()
            diagonal=raw[:,:,0]+raw[:,:,1]-(cell[:,0]+cell[:,1]+16)[:,None]
            assert ((diagonal.max(axis=1)<=.001)|(diagonal.min(axis=1)>=-.001)).all()
            a=raw[:,1]-raw[:,0];b=raw[:,2]-raw[:,0]
            areas=np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])/2
            assert abs(areas.sum()-g.area)<max(.001,g.length*.001)
            triangles+=len(raw)
    result=dict(status='passed',regions=len(lookup),internal_lines=lines,terrain_triangles=triangles,
        input_files=len(manifest['files']),base_land_sha256=sha(land_path),checks=['all labels inside own polygon, outside holes','all labels on base land','no parent outer lines',
            'shared line coordinates unchanged','terrain cell and diagonal conformity','fill area incl holes','input hashes'],
        transport='float32 fill vertices only; original shared polygons retained in JSON')
    write(OUT/'qa.json',result);print(result)

if __name__=='__main__': main()
