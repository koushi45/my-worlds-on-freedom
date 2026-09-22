"""Independent checks of pending regional candidates, not approval."""
import json
import geopandas as gpd
import numpy as np
from shapely.geometry import Point
from shapely.ops import unary_union, substring
import build_chugoku_shikoku_registration as reg

def verify(name):
    path=reg.WORK/name
    report=json.loads((path/'registration_report.json').read_text(encoding='utf-8'))
    data=json.loads((path/'review_layer.json').read_text(encoding='utf-8'))
    assert report['status']==data['status']=='pending_user_review'
    assert report['spec_sha256']==reg.core.digest(reg.SPEC)
    assert report['generator_sha256']==reg.core.digest(reg.ROOT/'tools/build_chugoku_shikoku_registration.py')
    for p,h in report['immutable_before'].items():assert reg.core.digest(reg.ROOT/p)==h,p
    assert report['immutable_before']==report['immutable_after']
    for p,h in report['outputs_sha256'].items():assert reg.core.digest(path/p)==h,p
    gpkg=path/'political_candidate.gpkg'
    regions=gpd.read_file(gpkg,layer='political_regions_8192')
    borders=gpd.read_file(gpkg,layer='shared_boundaries_8192')
    scope=gpd.read_file(gpkg,layer='scope_land_8192').geometry.iloc[0]
    assert len(regions)==(4 if name=='shikoku' else 11)
    assert regions.is_valid.all() and not regions.is_empty.any()
    assert borders.is_valid.all() and borders.is_simple.all()
    union=unary_union(regions.geometry)
    assert union.symmetric_difference(scope).area<1e-6
    assert abs(regions.area.sum()-union.area)<1e-6
    lookup=regions.set_index('region_id').geometry
    for row in borders.itertuples():
        for pt in reg.core.resample(row.geometry.coords,2):
            assert scope.distance(Point(pt))<1e-7
            for id in [row.region_a,row.region_b]:
                if id in lookup:assert lookup[id].boundary.distance(Point(pt))<1e-7,(row.boundary_id,id)
    canonical=gpd.read_file(reg.core.p2.COAST_GPKG,layer='coastline_8192').set_index('coastline_id').geometry
    for id,coords in data['coastlines'].items():assert coords==[list(p) for p in canonical[id].coords]
    arcs=gpd.read_file(gpkg,layer='coastline_references_8192')
    for row in arcs.itertuples():
        coast=canonical[row.coastline_id]
        reference=unary_union([substring(coast,row.start_distance,coast.length),substring(coast,0,row.end_distance)]) if row.wrap else substring(coast,row.start_distance,row.end_distance)
        assert row.geometry.hausdorff_distance(reference)<1e-7
    src=gpd.read_file(gpkg,layer='warp_mesh_source')
    dst=gpd.read_file(gpkg,layer='warp_mesh_target')
    assert abs(dst.area.sum()-unary_union(dst.geometry).area)<1e-5
    max_error=0.
    for s,t in zip(src.geometry,dst.geometry):
        a=np.array(s.exterior.coords)[:3];b=np.array(t.exterior.coords)[:3]
        f=np.linalg.solve(np.c_[a,np.ones(3)],b);inv=np.linalg.solve(np.c_[b,np.ones(3)],a)
        assert np.linalg.det(f[:2])>0
        p=np.mean(a,axis=0);q=np.r_[p,1]@f
        max_error=max(max_error,float(np.linalg.norm(np.r_[q,1]@inv-p)))
    assert max_error<1e-6
    result={'status':'passed','approval':'pending','scope':name,'regions':len(regions),'border_parts':len(borders),
            'max_roundtrip_source_px':max_error,'checks':['immutable_source_and_base_hashes','valid_regions','gap_and_overlap_below_1e-6_game_px2','shared_lines_match_adjacent_regions','canonical_coast_points_and_arc_references','no_mesh_folds_or_overlaps','forward_inverse_roundtrip'],
            'not_certified':['historical_accuracy','coastal_registration_visual_acceptance','offshore_island_ownership']}
    reg.core.save_json(path/'validation_report.json',result)
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__':
    for name in ['shikoku','chugoku']:verify(name)
