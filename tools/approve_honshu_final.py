"""Publish user-approved Honshu geometry; uncertain names stay explicit."""
from datetime import datetime,timezone
import json
import itertools
import geopandas as gpd
from shapely.geometry import Polygon,LineString,Point
from shapely.ops import unary_union,linemerge,substring
from finalize_honshu_edits import ROOT,OUT,read,save,parts,digest
import build_phase_p3_political_regions as p3

def run():
    target=ROOT/'data/master/political/honshu/1.0.0'
    assert not target.exists(), 'Version already frozen'
    source=read(OUT/'faces.json')['faces']
    input_data=read(OUT/'input_edits.json')
    seed=read(ROOT/'data/derived/editor/honshu/editor_draft.json')
    locked=read(ROOT/'data/derived/political/approved_western/political_registry.json')
    labels=p3.transform_labels()
    faces={};regions=[];name_review=[]
    for row in source:
        face=Polygon(row['polygons'][0]) # eliminate only sub-nanopixel numerical holes
        assert sum(Polygon(h).area for h in row['holes'])<1e-6
        hits=[r for r in labels.itertuples() if r.geometry is not None and face.covers(r.geometry)]
        # The supplied drawing subdivides northern historical labels. A label
        # point alone cannot certify a new subdivision's name.
        confirmed=len(hits)==1 and row['index'] not in [0,1,2,3,4,5,7,8]
        key=hits[0].region_id.split('-',3)[-1] if confirmed else f'honshu-area-{row["index"]+1:02d}'
        name=hits[0].name_ja if confirmed else f'名称未確定（領域{row["index"]+1:02d}）'
        assert key not in faces
        faces[key]=face
        regions.append({'region_id':key,'name_ja':name,'name_status':'reference_matched' if confirmed else 'unconfirmed',
                        'polygons':[list(face.exterior.coords)],'review_status':'accepted'})
        if not confirmed:name_review.append({'region_id':key,'reference_labels':[r.name_ja for r in hits]})
    boundaries=[]
    for (a,pa),(b,pb) in itertools.combinations(faces.items(),2):
        shared=parts(pa.boundary.intersection(pb.boundary))
        if not shared:continue
        for i,line in enumerate(parts(linemerge(shared))):
            if line.length<1e-4:continue
            boundaries.append({'boundary_id':f'honshu:{a}:{b}:{i}','region_a':a,'region_b':b,
                'points':list(line.coords),'review_status':'accepted','trace_method':'user_edited_shared_face_edge'})
    refs=[];ref_geometries={}
    shared_ids={r['boundary_id'] for r in input_data['shared_boundary_references']}
    for old in locked['boundaries']:
        if old['boundary_id'] not in shared_ids:continue
        line=LineString(old['points'])
        for key,face in faces.items():
            intervals=[]
            for a,b in zip(face.exterior.coords,list(face.exterior.coords)[1:]):
                edge=LineString([a,b])
                if edge.difference(line.buffer(1e-4)).length<1e-5:
                    start,end=sorted([line.project(Point(a)),line.project(Point(b))])
                    if end-start>1e-5:intervals.append([start,end])
            merged=[]
            for start,end in sorted(intervals):
                if merged and start-merged[-1][1]<1e-4:merged[-1][1]=max(merged[-1][1],end)
                else:merged.append([start,end])
            for start,end in merged:
                ref={'arc_id':f'honshu:shared:{len(refs)}','boundary_id':old['boundary_id'],'region_id':key,
                     'start_distance':start,'end_distance':end,'wrap':False}
                refs.append(ref);ref_geometries[ref['arc_id']]=substring(line,start,end)
    coasts=[]
    for coast_id,points in seed['coastlines'].items():
        coast=LineString(points)
        endpoints=[p for b in boundaries for p in [b['points'][0],b['points'][-1]]]
        endpoints += [p for b in locked['boundaries'] if b['boundary_id'] in shared_ids for p in [b['points'][0],b['points'][-1]]]
        cuts=[]
        for d in sorted(coast.project(Point(p)) for p in endpoints if coast.distance(Point(p))<1e-4):
            if not cuts or d-cuts[-1]>1e-4:cuts.append(d)
        for i,start in enumerate(cuts):
            end=cuts[(i+1)%len(cuts)];wrap=end<start
            arc=unary_union([substring(coast,start,coast.length),substring(coast,0,end)]) if wrap else substring(coast,start,end)
            owners=[key for key,f in faces.items() if arc.difference(f.boundary.buffer(1e-4)).length<1e-3]
            assert len(owners)<=1
            if owners:
                ref={'arc_id':f'coast:{i:03d}','coastline_id':coast_id,'region_id':owners[0],
                     'start_distance':start,'end_distance':end,'wrap':wrap}
                coasts.append(ref);ref_geometries[ref['arc_id']]=arc
    for key,face in faces.items():
        lines=[LineString(b['points']) for b in boundaries if key in [b['region_a'],b['region_b']]]
        lines += [ref_geometries[r['arc_id']] for r in refs+coasts if r['region_id']==key]
        drawn=unary_union(lines)
        missing=face.boundary.difference(drawn.buffer(1e-4)).length
        extra=drawn.difference(face.boundary.buffer(1e-4)).length
        assert missing<.001 and extra<.001,(key,missing,extra)
    registry={'status':'approved','version':'1.0.0','scope':'honshu','bounds':seed['bounds'],'license':'CC-BY-SA-4.0',
        'coordinate_system':seed['coordinate_system'],'coastlines':seed['coastlines'],'regions':regions,
        'boundaries':boundaries,'boundary_references':refs,'coastline_references':coasts}
    target.mkdir(parents=True)
    save(target/'political_registry_master.json',registry)
    save(target/'name_review.json',name_review)
    save(target/'cleanup_report.json',read(OUT/'cleanup_report.json'))
    (target/'approved_input_edits.json').write_bytes((OUT/'input_edits.json').read_bytes())
    gpd.GeoDataFrame([{'region_id':key,'geometry':face} for key,face in faces.items()]).to_file(target/'political_regions_master.gpkg',layer='political_regions_8192',driver='GPKG')
    manifest={'status':'approved','version':'1.0.0','scope':'honshu','approval':{'approved_by':'user',
      'recorded_at_utc':datetime.now(timezone.utc).isoformat(),'instruction':'近畿以東を編集しました。これでほぼ同じ位置にある描画点を1つにまとめるなど、細部を修正した後で国境線を確定させて下さい。その後で本番ビルドをお願いします。'},
      'candidate_sha256':digest(OUT/'input_edits.json'),'name_status':'Geometry approved; unresolved names retained explicitly',
      'canonical_hashes':{p:digest(ROOT/p) for p in ['data/base/japan_land.gpkg','data/derived/coastline/coastline_master.gpkg']},
      'files':{p.name:digest(p) for p in target.iterdir() if p.is_file()}}
    save(target/'political_master_manifest.json',manifest)
    save(target.parent/'status.json',{'status':'approved','current_version':'1.0.0'})
    print('Approved',len(regions),'regions;',len(boundaries),'borders;',len(refs),'shared references;',len(coasts),'coast arcs;',len(name_review),'unresolved names')

if __name__=='__main__':run()
