"""Verify partial review geometry without misrepresenting it as an approved map."""
import json
import geopandas as gpd
import numpy as np
from shapely.geometry import Point
from shapely.ops import unary_union
import build_kinki_chubu_border_review as reg

def verify(name):
    path=reg.WORK/name
    report=json.loads((path/'registration_report.json').read_text(encoding='utf-8'))
    data=json.loads((path/'review_layer.json').read_text(encoding='utf-8'))
    assert report['status']==data['status']=='pending_user_review'
    assert not data['regions'] and not data['coastline_references']
    for p,h in report['input_hashes_unchanged'].items():assert reg.core.digest(reg.ROOT/p)==h,p
    for p,h in report['outputs_sha256'].items():assert reg.core.digest(path/p)==h,p
    canonical=gpd.read_file(reg.core.p2.COAST_GPKG,layer='coastline_8192').set_index('coastline_id').geometry
    for id,coords in data['coastlines'].items():assert coords==[list(p) for p in canonical[id].coords]
    gpkg=path/'border_review_candidate.gpkg'
    source=gpd.read_file(gpkg,layer='warp_mesh_source')
    target=gpd.read_file(gpkg,layer='warp_mesh_target')
    max_error=0.
    for s,t in zip(source.geometry,target.geometry):
        a=np.array(s.exterior.coords)[:3];b=np.array(t.exterior.coords)[:3]
        f=np.linalg.solve(np.c_[a,np.ones(3)],b);inv=np.linalg.solve(np.c_[b,np.ones(3)],a)
        assert np.linalg.det(f[:2])>0
        p=a.mean(axis=0);q=np.r_[p,1]@f
        max_error=max(max_error,float(np.linalg.norm(np.r_[q,1]@inv-p)))
    assert max_error<1e-6
    assert abs(target.area.sum()-unary_union(target.geometry).area)<1e-5
    borders=gpd.read_file(gpkg,layer='display_boundaries_8192')
    assert borders.is_valid.all() and not borders.is_empty.any()
    _,land=reg.core.p3.canonical_land_8192()
    for line in borders.geometry:
        for p in reg.core.resample(line.coords,5):assert land.distance(Point(p))<1e-6
    result={'scope':name,'partial_candidate_integrity':'passed','completion':'incomplete',
            'approval':'pending','max_roundtrip_input_px':max_error,
            'unconfirmed_endpoint_records':len(report['unconfirmed_endpoints']),
            'unsupported_trace_records':len(report['unsupported_trace_intervals']),
            'not_validated':['complete political topology','province ownership','cross-region seam','coast alignment visual precision']}
    reg.core.save_json(path/'validation_report.json',result)
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__':
    for name in ['kinki','chubu']:verify(name)
