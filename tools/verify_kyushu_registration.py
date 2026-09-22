"""Independent QA for the Kyushu registration candidate; never grants approval."""
import json
import sys
from pathlib import Path
import cv2
import geopandas as gpd
import numpy as np
from PIL import Image
from shapely.geometry import Point, Polygon, LineString
from shapely.ops import unary_union, substring, polygonize

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_kyushu_registration as reg

def verify():
    work=reg.WORK
    report=json.loads((work/'registration_report.json').read_text(encoding='utf-8'))
    spec=json.loads(reg.SPEC.read_text(encoding='utf-8'))
    review=json.loads((work/'review_layer.json').read_text(encoding='utf-8'))
    gpkg=work/'kyushu_candidate.gpkg'
    for p,expected in report['immutable_hashes_before'].items():assert reg.digest(ROOT/p)==expected,p
    for p,expected in report['outputs_sha256'].items():assert reg.digest(work/p)==expected,p
    assert report['spec_sha256']==reg.digest(reg.SPEC)
    assert report['generator_sha256']==reg.digest(ROOT/'tools/build_kyushu_registration.py')
    coast_frame=gpd.read_file(reg.p2.COAST_GPKG,layer='coastline_8192')
    coast=coast_frame.set_index('coastline_id').loc[spec['coastline_id']].geometry
    assert review['coastlines'][spec['coastline_id']]==[list(p) for p in coast.coords]
    _,canonical_union=reg.p3.canonical_land_8192()
    land=next(p for p in reg.p3.polygon_parts(canonical_union) if p.contains(reg.p2.game_point(131,32.5)))
    assert land.exterior.hausdorff_distance(coast)<1e-8
    borders=gpd.read_file(gpkg,layer='shared_boundaries_8192')
    regions=gpd.read_file(gpkg,layer='political_regions_8192')
    arcs=gpd.read_file(gpkg,layer='coastline_references_8192')
    source=gpd.read_file(gpkg,layer='source_boundaries_px')
    assert len(borders)==15 and len(regions)==9 and len(arcs)==9
    assert set(regions.region_id)==set(reg.NAMES)
    assert all(regions.geometry.is_valid) and all(borders.geometry.is_simple)
    u=unary_union(regions.geometry)
    assert u.symmetric_difference(land).area<1e-6
    assert abs(regions.geometry.area.sum()-u.area)<1e-6
    assert len(list(polygonize(unary_union(list(borders.geometry)+list(arcs.geometry)))))==9
    region_lookup=regions.set_index('region_id').geometry
    # Both adjacent countries must share every sampled border point.
    for b in borders.itertuples():
        assert b.geometry.difference(land).length<1e-6
        for p in reg.resample(b.geometry.coords,2):
            for key in (b.region_a,b.region_b):assert region_lookup[key].boundary.distance(Point(p))<1e-7
    for row in arcs.itertuples():
        assert row.coastline_id==spec['coastline_id']
        parts=[substring(coast,row.start_distance,coast.length),substring(coast,0,row.end_distance)] if row.wrap else [substring(coast,row.start_distance,row.end_distance)]
        reference=unary_union(parts)
        assert row.geometry.hausdorff_distance(reference)<1e-7
    assert abs(sum(r['end_distance']-r['start_distance']+(coast.length if r['wrap'] else 0) for r in review['coastline_references'])-coast.length)<1e-7
    # Reverse mesh mapping must use the same triangles, not a second fit.
    src=gpd.read_file(gpkg,layer='warp_mesh_source').sort_values('triangle_id')
    dst=gpd.read_file(gpkg,layer='warp_mesh_target').sort_values('triangle_id')
    shapes=list(dst.geometry);assert abs(sum(p.area for p in shapes)-unary_union(shapes).area)<1e-5
    max_roundtrip=0.
    raster=np.array(Image.open(work/'warped_raster.png'))[:,:,3]
    alpha=np.array(Image.open(ROOT/spec['source']).getchannel('A'))
    geo=json.loads((work/'raster_georeference.json').read_text(encoding='utf-8'))
    raster_errors=[]
    for s,t in zip(src.geometry,dst.geometry):
        a=np.asarray(s.exterior.coords)[:3];b=np.asarray(t.exterior.coords)[:3]
        f=np.linalg.solve(np.c_[a,np.ones(3)],b);inv=np.linalg.solve(np.c_[b,np.ones(3)],a)
        assert np.linalg.det(f[:2])>0
        p=np.array([.21,.33,.46])@a;q=np.r_[p,1.]@f;back=np.r_[q,1.]@inv
        max_roundtrip=max(max_roundtrip,float(np.linalg.norm(p-back)))
        px=np.round((q-np.array(geo['bounds_8192'][:2]))*geo['pixels_per_game_unit']).astype(int)
        if 0<=px[0]<raster.shape[1] and 0<=px[1]<raster.shape[0]:
            game=px/geo['pixels_per_game_unit']+np.array(geo['bounds_8192'][:2])
            image_point=np.r_[game,1.]@inv
            expected=cv2.remap(alpha,np.array([[image_point[0]]],np.float32),np.array([[image_point[1]]],np.float32),cv2.INTER_LINEAR)[0,0]
            raster_errors.append(abs(int(expected)-int(raster[px[1],px[0]])))
    assert max_roundtrip<1e-6
    assert max(raster_errors)<=1,(max(raster_errors),raster_errors)
    # Non-authoritative preview must not change main scene or become accepted.
    assert report['status']==review['status']=='pending_user_review'
    assert all(regions.review_status=='pending')
    assert all(source.geometry.is_simple)
    result={'status':'passed','approval':'pending','tests':['immutable_hashes','nine_valid_regions','no_gaps_or_overlaps',
              'shared_boundaries_match_both_regions','canonical_coast_points_identical','coast_reference_full_coverage',
              'no_extra_loops','no_folded_or_overlapping_warp_triangles','inverse_roundtrip','actual_raster_inverse_resampling'],
            'max_roundtrip_source_px':max_roundtrip,'raster_resampling_max_alpha_difference':max(raster_errors)}
    reg.save_json(work/'validation_report.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':verify()
