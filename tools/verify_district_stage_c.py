"""Integrity and geometry checks for research-only stage C outputs."""
import numpy as np
from PIL import Image
from shapely.geometry import shape, LineString
from shapely.ops import polygonize, unary_union
from build_district_stage_c import ROOT, RAW, WORK, EDITOR, read, sha, key, transforms, write

def main():
    manifest=read(EDITOR/'input_manifest.json')
    for item in manifest['files']: assert sha(ROOT/item['path'])==item['sha256'], item['path']
    assert sha(ROOT/'tools/build_district_stage_c.py')==manifest['generator_sha256']
    assert sha(RAW/'geometry_sources.json')==manifest['source_manifest_sha256']
    sources=read(RAW/'geometry_sources.json')['sources']
    assert len(sources)==697
    for s in sources: assert sha(ROOT/s['file'])==s['sha256'] and s['export_allowed'] is False
    inventory=read(EDITOR/'national_inventory.json')['parents']
    scope=read('data/editorial/districts/scope.json')['parents']
    assert {p['parent_region_id'] for p in scope}=={p['parent_region_id'] for p in inventory}
    count=arcs=shared=0
    for item in inventory:
        d=read(WORK/item['parent_region_id']/'network.json')
        assert d['export_allowed'] is False and d['world_size']==[8192,8192]
        assert not d['qa']['issues'] and not d['qa']['target_geometry_accepted']
        byid={a['boundary_id']:a for a in d['boundaries']}
        assert len(byid)==len(d['boundaries'])
        gids={c['external_id'] for c in d['candidates']}; seen=set()
        for a in byid.values():
            assert set(a['owners'])<=gids
            assert len(a['points'])==len(a['source_lonlat'])
            for u,v in zip(a['source_lonlat'],a['source_lonlat'][1:]):
                edge=key(tuple(u),tuple(v));assert edge not in seen;seen.add(edge)
        for c in d['candidates']:
            expected={a['boundary_id'] for a in byid.values() if c['external_id'] in a['owners']}
            assert expected==set(c['boundary_refs'])
            g=shape(c['polygon_geometry']);assert g.is_valid and not g.is_empty
            faces=polygonize([LineString(byid[i]['points']) for i in c['boundary_refs']])
            rebuilt=unary_union([p for p in faces if g.covers(p.representative_point())])
            assert rebuilt.symmetric_difference(g).area<1e-4
        count+=len(gids);arcs+=len(byid);shared+=sum(len(a['owners'])==2 for a in byid.values())
    image_meta=read(RAW/'izumi/image_sources.json')
    assert sha(ROOT/image_meta['manifest_file'])==image_meta['manifest_sha256']
    for s in image_meta['images']:
        assert sha(ROOT/s['file'])==s['sha256']
        assert list(Image.open(ROOT/s['file']).size)==s['actual_size']
    r=read(EDITOR/'izumi_registration.json');m,xy,ll=transforms()
    x=np.array([c['source_pixel']+[1] for c in r['controls']]);y=np.array([c['target_world'] for c in r['controls']])
    fit=np.linalg.lstsq(x,y,rcond=None)[0]
    assert np.allclose(fit,r['matrix_pixel_row_to_world'])
    errors=np.linalg.norm(x@fit-y,axis=1)/m['uniform_scale_px_per_m']
    assert np.allclose(errors,[c['residual_m'] for c in r['controls']])
    loo=[]
    for i in range(len(x)):
        keep=np.arange(len(x))!=i
        loo.append(float(np.linalg.norm(x[i]@np.linalg.lstsq(x[keep],y[keep],rcond=None)[0]-y[i])/m['uniform_scale_px_per_m']))
    assert np.allclose(loo,[c['leave_one_out_m'] for c in r['controls']])
    assert np.isclose(np.sqrt(np.mean(errors**2)),r['fit_rmse_m'])
    assert r['status']=='held_registration_accuracy_insufficient'
    result=dict(status='passed',parents=len(inventory),geometry_candidates=count,arcs=arcs,shared_arcs=shared,
        original_geometry_hashes_checked=len(sources),original_image_hashes_checked=len(image_meta['images']),
        checks=['frozen stage C inputs','original hashes','no duplicate exact source edges within parent',
            'owner/reference consistency','valid derived polygons','polygon reconstruction from shared arcs','affine residual and leave-one-out recomputation'],
        limits=['No historical accuracy certification','No parent clipping or full coverage assertion',
            'No arbitrary source intersection noding; only identical input segments are shared','No 1582 geometry accepted'])
    write(EDITOR/'qa.json',result);print(result)

if __name__=='__main__': main()
