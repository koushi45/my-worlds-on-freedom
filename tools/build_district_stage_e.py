"""Read-only site/road overlay; no routing, nearest assignment or game rules."""
from pathlib import Path
from collections import Counter
import json, math, hashlib
from shapely.geometry import Point, LineString, shape
from shapely.strtree import STRtree
from build_district_stage_c import ROOT, read, write, sha, transforms

WORK=ROOT/'data/work/districts/stage_e'
EDITOR=ROOT/'data/editorial/districts/stage_e'
SITES=ROOT/'data/derived/settlements/settlements_1582.json'
ROADS=ROOT/'data/derived/road_connections/connections_1582.json'
NEAR_M=500  # review window, not an inferred historical accuracy radius
EPS=1e-8   # intersection/chainage arithmetic tolerance, world units

def digest(obj): return hashlib.sha256(json.dumps(obj,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()

class Atlas:
    def __init__(self,partitions):
        self.regions=[];self.polygons=[];self.edges=[];self.lines=[];self.candidates={}
        for d in partitions:
            pid=d['parent_region_id']
            for c in d['candidates']: self.candidates[c['candidate_id']]=c
            for r in d['regions']:
                self.regions.append(dict(parent_region_id=pid,region_id=r['region_id'],kind=r['kind'],
                    reason=r['reason'],candidate_refs=r['candidate_refs'],key=pid+'/'+r['region_id']))
                self.polygons.append(shape(r['polygon_geometry']))
            for a in d['boundaries']:
                self.edges.append(dict(key=pid+'/'+a['boundary_id'],parent_region_id=pid,boundary_id=a['boundary_id'],
                    boundary_kind=a['boundary_kind'],owner_keys=[pid+'/'+r for r in a['owners']]))
                self.lines.append(LineString(a['points']))
        self.ptree=STRtree(self.polygons);self.etree=STRtree(self.lines)
        self.region_index={r['key']:i for i,r in enumerate(self.regions)}

    def covering(self,p):
        return sorted(int(i) for i in self.ptree.query(p) if self.polygons[int(i)].covers(p))

    def near_edges(self,p,radius):
        return sorted(int(i) for i in self.etree.query(p.buffer(max(radius,EPS)).envelope) if self.lines[int(i)].distance(p)<=radius)

    def road_membership(self,p):
        on=self.near_edges(p,EPS)
        ids=set(self.covering(p))
        for i in on:
            ids.update(self.region_index[k] for k in self.edges[i]['owner_keys'])
        keys=sorted(self.regions[i]['key'] for i in ids)
        status='boundary_run' if on else 'unresolved' if not ids or any(self.regions[i]['kind']=='unresolved' for i in ids) else 'ambiguous' if len(ids)>1 else 'candidate'
        return dict(region_keys=keys,status=status,boundary_keys=[self.edges[i]['key'] for i in on])

def site_overlay(site,atlas,scale,xy,evidence):
    coords=site.get('lonlat');reasons=[]
    if coords is None:
        return dict(site_id=site['id'],assignment_status='unresolved',reasons=['registered_lonlat_missing'],historical_comparison='not_comparable')
    x,y=xy(*coords);point=[float(x),float(y)];p=Point(point)
    inside=atlas.covering(p);radius=max(NEAR_M,site.get('uncertainty_m') or 0)*scale
    edges=atlas.near_edges(p,radius);near=sorted({atlas.region_index[k] for e in edges for k in atlas.edges[e]['owner_keys']})
    on=[i for i in edges if atlas.lines[i].distance(p)<=EPS]
    if not inside: status='unresolved';reasons.append('outside_current_parent_or_simplified_coast')
    elif any(atlas.regions[i]['kind']=='unresolved' for i in inside): status='unresolved';reasons.append('inside_unresolved_partition')
    elif on or len(inside)>1: status='ambiguous';reasons.append('on_boundary_or_multiple_regions')
    elif edges: status='ambiguous';reasons.append('within_boundary_review_window')
    else: status='candidate';reasons.append('registered_coordinate_inside_comparison_candidate')
    if site.get('location_status') in ['unresolved','unknown','unlocated']:
        status='unresolved';reasons.append('site_location_unresolved')
    elif site.get('location_status')=='area_estimate' and site.get('uncertainty_m') is None:
        if status=='candidate': status='ambiguous'
        reasons.append('area_representative_coordinate_accuracy_unquantified')
    refs=sorted({c for i in inside for c in atlas.regions[i]['candidate_refs']})
    supported=[e for e in evidence if e['status'] in ['supported_retrospective_affiliation','supported_later_map_affiliation']]
    comparison='unverified_no_adopted_district_evidence'
    if supported:
        expected={e['candidate_id'] for e in supported}
        comparison='consistent_with_comparison_geometry' if expected.intersection(refs) else 'not_comparable_unresolved_geometry' if not inside or any(atlas.regions[i]['kind']=='unresolved' for i in inside) else 'conflict_requires_individual_review'
    return dict(site_id=site['id'],display_name=site['display_name'],registered_lonlat=coords,registered_world=point,
        coordinate_basis='lonlat transformed by existing game_transform; never display_point or connection anchor',
        registered_point_difference_world=math.dist(point,site['point']) if site.get('point') else None,
        location_status=site.get('location_status'),location_note=site.get('location_note'),uncertainty_m=site.get('uncertainty_m'),
        location_evidence=site.get('claims',{}).get('location',[]),assignment_status=status,reasons=reasons,
        containing_regions=[atlas.regions[i] for i in inside],nearby_review_regions=[atlas.regions[i] for i in near],
        candidate_district_ids=refs,near_boundary_details=[dict(boundary_key=atlas.edges[i]['key'],distance_m=atlas.lines[i].distance(p)/scale) for i in edges],
        review_window_m=radius/scale,review_window_is_not_accuracy=True,nearest_assignment=False,
        historical_evidence=evidence,historical_comparison=comparison,
        historical_lead_comparisons=[dict(evidence_id=e['evidence_id'],candidate_id=e['candidate_id'],
            overlaps_containing_candidate=e['candidate_id'] in refs,not_adopted_as_affiliation=True)
            for e in evidence if e['status']=='indirect_village_affiliation_lead'],
        adopted_historical_district_id=None,decision='retain_registered_coordinate_and_comparison; no automatic historical assignment')

def intersection_events(g):
    if g.is_empty: return []
    if g.geom_type=='Point': return [g]
    if g.geom_type in ['LineString','LinearRing']: return [Point(g.coords[0]),Point(g.coords[-1])]
    return [p for child in g.geoms for p in intersection_events(child)]

def route_overlay(route,atlas):
    intervals=[];events=[];station=0.0;zero=[]
    for segment,(a,b) in enumerate(zip(route['points'],route['points'][1:])):
        line=LineString([a,b]);length=line.length
        if length==0: zero.append(segment);continue
        cuts=[0.0,length];hits=[]
        for ix in atlas.etree.query(line):
            i=int(ix);intersection=line.intersection(atlas.lines[i])
            for p in intersection_events(intersection):
                t=max(0.0,min(length,line.project(p)));cuts.append(t)
                hits.append(dict(station_world=station+t,point=list(p.coords[0]),boundary_key=atlas.edges[i]['key'],segment_index=segment,
                    segment_fraction=t/length,intersection_kind='linear_overlap_endpoint' if intersection.length>0 else 'point'))
        cuts=sorted(set(cuts))
        for start,end in zip(cuts,cuts[1:]):
            if end<=start: continue
            state=atlas.road_membership(line.interpolate((start+end)/2))
            if end-start<=EPS:
                state['status']='numeric_contact_interval'
            item=dict(start_world=station+start,end_world=station+end,start_segment=segment,end_segment=segment,
                start_fraction=start/length,end_fraction=end/length,**state)
            if intervals and all(intervals[-1][k]==item[k] for k in ['region_keys','status','boundary_keys']):
                intervals[-1].update(end_world=item['end_world'],end_segment=segment,end_fraction=item['end_fraction'])
            else: intervals.append(item)
        events.extend(hits);station+=length
    grouped=[]
    for e in sorted(events,key=lambda e:(e['station_world'],e['boundary_key'])):
        if grouped and abs(grouped[-1]['station_world']-e['station_world'])<=EPS:
            grouped[-1]['boundary_keys']=sorted(set(grouped[-1]['boundary_keys']+[e['boundary_key']]))
        else: grouped.append(dict(station_world=e['station_world'],point=e['point'],boundary_keys=[e['boundary_key']],segment_index=e['segment_index'],segment_fraction=e['segment_fraction']))
    for e in grouped:
        before=next((i for i in reversed(intervals) if i['start_world']<e['station_world']-EPS and i['end_world']>=e['station_world']-EPS),None)
        after=next((i for i in intervals if i['end_world']>e['station_world']+EPS and i['start_world']<=e['station_world']+EPS),None)
        e['before_region_keys']=before['region_keys'] if before else []
        e['after_region_keys']=after['region_keys'] if after else []
        e['kind']='endpoint_contact' if not before or not after else 'boundary_run_transition' if before['status']=='boundary_run' or after['status']=='boundary_run' else 'crossing' if before['region_keys']!=after['region_keys'] else 'touch'
    return dict(route_id=route['id'],name=route['name'],from_site=route['from_site'],to_site=route['to_site'],
        geometry_sha256=digest(route['points']),source_geometry_locator=f'routes[id={route["id"]}].points',
        traversal_direction='stored points order, from_site to to_site',length_world=station,intervals=intervals,
        boundary_events=grouped,zero_length_input_segments=zero,geometry_modified=False,
        traffic_semantics_added=False,uncovered_intervals_are_not_new_connections=True)

def build():
    paths=sorted((ROOT/'data/work/districts/stage_d').glob('*/partition.json'))
    m,xy,_=transforms();atlas=Atlas([read(p) for p in paths]);sites=read(SITES)['sites'];roads=read(ROADS)
    evidence_path=EDITOR/'affiliation_evidence.json';evidence=read(evidence_path)['evidence'] if evidence_path.exists() else []
    target={s['site_id'] for s in roads['site_connections']};assert len(target)==254 and len(roads['routes'])==285
    assert target<={s['id'] for s in sites}
    records=[]
    sources=read(SITES)['sources'];sources={s['id']:s for s in sources}
    for s in sites:
        row=site_overlay(s,atlas,m['uniform_scale_px_per_m'],xy,[e for e in evidence if e['site_id']==s['id']])
        row['scope']='requested_254' if s['id'] in target else 'additional_current_record'
        # Existing location/chronology references are leads, not district evidence.
        row['existing_sources_review']=[dict(source_id=ref,url=sources.get(ref,{}).get('url'),locator=sources.get(ref,{}).get('locator'),
            district_claim_status='not_established_by_existing_structured_claims') for ref in s.get('source_refs',[])]
        records.append(row)
    write(WORK/'site_assignments.json',dict(sites=records,export_allowed=False))
    for n,r in enumerate(roads['routes']):
        write(WORK/'routes'/f'{r["id"]}.json',route_overlay(r,atlas))
        if n%50==0: print('Routes',n+1,flush=True)
    decisions=[dict(site_id=s['site_id'],status=s['assignment_status'],reasons=s['reasons'],
        geometry_candidates=s.get('candidate_district_ids',[]),historical_comparison=s['historical_comparison'],
        action='hold_no_coordinate_or_boundary_change') for s in records]
    write(EDITOR/'review_decisions.json',dict(decisions=decisions,automatic_adoption=False))
    inputs=[SITES,ROADS,ROOT/'data/base/japan_land_manifest.json',*paths]
    if evidence_path.exists(): inputs.append(evidence_path)
    inputs += [ROOT/e['source_file'] for e in evidence if e.get('source_file')]
    write(EDITOR/'input_manifest.json',dict(files=[dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)) for p in inputs],generator_sha256=sha(Path(__file__))))
    write(EDITOR/'summary.json',dict(requested_sites=len(target),actual_site_records=len(sites),additional_sites=len(sites)-len(target),routes=len(roads['routes']),
        requested_status_counts=dict(Counter(s['assignment_status'] for s in records if s['scope']=='requested_254')),
        historical_comparison_counts=dict(Counter(s['historical_comparison'] for s in records if s['scope']=='requested_254')),
        no_traffic_graph_created=True,export_allowed=False))
    print('Finished site and road overlays')

if __name__=='__main__': build()
