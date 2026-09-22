"""Validate coordinate semantics and segment-ordered road boundary overlays."""
from collections import Counter
from copy import deepcopy
from pathlib import Path
import math
from shapely.geometry import box, Point, LineString, mapping
from build_district_stage_c import ROOT, read, write, sha
from build_district_stage_d import partition
from build_district_stage_e import Atlas, site_overlay, route_overlay, digest, WORK, EDITOR, SITES, ROADS, EPS

def fixtures():
    cs=[dict(candidate_id=n,polygon_geometry=mapping(g),target_adoption_status='held') for n,g in [('a',box(0,0,1,2)),('b',box(1,0,2,2))]]
    d,_=partition(box(0,0,3,2),cs);d.update(parent_region_id='test',candidates=cs)
    atlas=Atlas([d]);r=dict(id='r',name='r',from_site='a',to_site='b',points=[[.5,.5],[1.5,.5],[.5,.5],[1.5,.5]])
    out=route_overlay(r,atlas)
    assert [round(e['station_world'],5) for e in out['boundary_events']]==[.5,1.5,2.5]
    assert [i['region_keys'] for i in out['intervals']]==[['test/candidate-a'],['test/candidate-b'],['test/candidate-a'],['test/candidate-b']]
    r['points']=[[1,0],[1,0],[1,1]];out=route_overlay(r,atlas)
    assert out['zero_length_input_segments']==[0] and all(i['status']=='boundary_run' for i in out['intervals'])
    r['points']=[[.5,.5],[1,1],[.5,1.5]];out=route_overlay(r,atlas)
    assert len(out['boundary_events'])==1 and out['boundary_events'][0]['kind']=='touch'
    r['points']=[[-1,1],[4,1]];out=route_overlay(r,atlas)
    assert out['intervals'][0]['status']=='unresolved' and out['intervals'][-1]['status']=='unresolved'
    s=dict(id='s',display_name='s',lonlat=[.5,.5],point=[.5,.5],location_status='surveyed',uncertainty_m=1)
    original=site_overlay(s,atlas,0.0001,lambda x,y:(x,y),[])
    s.update(display_point=[100,100],display_anchor=[200,200],connection_anchors=[[1.5,1.5]])
    assert site_overlay(s,atlas,0.0001,lambda x,y:(x,y),[])==original
    s['lonlat']=[1,.5];assert site_overlay(s,atlas,.0001,lambda x,y:(x,y),[])['assignment_status']=='ambiguous'
    s['lonlat']=[2.5,.5];assert site_overlay(s,atlas,.0001,lambda x,y:(x,y),[])['assignment_status']=='unresolved'
    s['lonlat']=[-1,.5];assert site_overlay(s,atlas,.0001,lambda x,y:(x,y),[])['assignment_status']=='unresolved'
    s['lonlat']=[.5,.5]
    e=[dict(status='supported_retrospective_affiliation',candidate_id='b')]
    assert site_overlay(s,atlas,.0001,lambda x,y:(x,y),e)['historical_comparison']=='conflict_requires_individual_review'
    return ['backtracking route preserves repeated crossings','boundary-running and zero segments','tangent touch','outside intervals',
        'display/entrance coordinates ignored','on-boundary site','unresolved land','no nearest assignment','historical conflict retained']

def main():
    tests=fixtures();manifest=read(EDITOR/'input_manifest.json')
    for f in manifest['files']: assert sha(ROOT/f['path'])==f['sha256'],f['path']
    assert sha(ROOT/'tools/build_district_stage_e.py')==manifest['generator_sha256']
    roads=read(ROADS);original={s['id']:s for s in read(SITES)['sites']}
    atlas=Atlas([read(p) for p in sorted((ROOT/'data/work/districts/stage_d').glob('*/partition.json'))])
    site_data=read(WORK/'site_assignments.json')['sites']
    assert {s['site_id'] for s in site_data}==set(original)
    assert sum(s['scope']=='requested_254' for s in site_data)==254
    for s in site_data:
        if not s.get('registered_world'): continue
        assert s['registered_lonlat']==original[s['site_id']]['lonlat']
        exact={atlas.regions[i]['key'] for i in atlas.covering(Point(s['registered_world']))}
        assert exact=={r['key'] for r in s['containing_regions']}
        assert not s['nearest_assignment'] and s['adopted_historical_district_id'] is None
    events=Counter();statuses=Counter();max_error=0
    for r in roads['routes']:
        d=read(WORK/'routes'/f'{r["id"]}.json');line=LineString(r['points'])
        assert d['geometry_sha256']==digest(r['points']) and not d['geometry_modified']
        assert not d['traffic_semantics_added']
        assert abs(d['length_world']-line.length)<EPS
        prev=0.0
        for i in d['intervals']:
            assert abs(i['start_world']-prev)<EPS and i['end_world']>i['start_world']
            prev=i['end_world'];state=atlas.road_membership(line.interpolate((i['start_world']+i['end_world'])/2))
            assert state['region_keys']==i['region_keys'],(r['id'],i,state)
            statuses[i['status']]+=1
        assert abs(prev-line.length)<EPS
        last=-1
        edge_map={a['key']:i for i,a in enumerate(atlas.edges)}
        for e in d['boundary_events']:
            assert e['station_world']>=last;last=e['station_world']
            p=Point(e['point']);err=p.distance(line.interpolate(e['station_world']));max_error=max(err,max_error)
            assert err<EPS
            assert all(atlas.lines[edge_map[k]].distance(p)<EPS for k in e['boundary_keys'])
            events[e['kind']]+=1
    result=dict(status='passed',requested_sites=254,all_site_records=len(site_data),routes=len(roads['routes']),
        boundary_event_counts=dict(events),interval_status_counts=dict(statuses),max_event_position_error_world=max_error,
        fixtures=tests,frozen_input_count=len(manifest['files']),historical_research_complete=False)
    write(EDITOR/'qa.json',result);print(result)

if __name__=='__main__': main()
