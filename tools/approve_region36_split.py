"""Apply the user's Settsu/Izumi dividing line to the approved geometry."""
import copy
import shutil
from datetime import datetime, timezone
import geopandas as gpd
from shapely.geometry import Polygon, LineString, Point
from shapely.ops import split, substring, unary_union
from finalize_honshu_edits import ROOT, read, save, digest

def run():
    old=ROOT/'data/master/political/honshu/1.0.3'
    target=old.parent/'1.0.4'
    assert not target.exists()
    source=__import__('pathlib').Path('C:/Users/nanoa/Documents/region36_border_edits.json')
    edits=read(source)
    assert edits['schema']=='my-worlds-region36-border-edits' and edits['scope']=='region36'
    assert edits['source_draft_sha256']==digest(ROOT/'data/derived/political/approved_western/political_registry.json')
    data=read(old/'political_registry_master.json'); before=copy.deepcopy(data)
    region=next(r for r in data['regions'] if r['region_id']=='honshu-area-36')
    polygon=Polygon(region['polygons'][0])
    assert len(edits['boundaries'])==1
    raw=edits['boundaries'][0]['points'];assert len(raw)==2
    assert all(polygon.boundary.distance(Point(p))<.001 for p in raw)
    a,b=raw;dx=b[0]-a[0];dy=b[1]-a[1]
    cutter=LineString([(a[0]-dx*.05,a[1]-dy*.05),(b[0]+dx*.05,b[1]+dy*.05)])
    halves=sorted(split(polygon,cutter).geoms,key=lambda p:p.centroid.y)
    assert len(halves)==2 and all(p.is_valid and not p.interiors for p in halves)
    assert unary_union(halves).symmetric_difference(polygon).area<1e-7
    faces=dict(zip(['settsu','izumi'],halves))
    seam=halves[0].boundary.intersection(halves[1].boundary)
    assert seam.geom_type=='LineString'
    def owner(line):
        hits=[k for k,p in faces.items() if line.difference(p.boundary.buffer(1e-5)).length<1e-4]
        assert len(hits)==1,(line.wkt,hits)
        return hits[0]
    data['regions'].remove(region)
    for key,name in [('settsu','摂津国'),('izumi','和泉国')]:
        data['regions'].append({'region_id':key,'name_ja':name,'name_status':'user_confirmed','polygons':[list(faces[key].exterior.coords)],'review_status':'accepted'})
    borders=[]
    for border in data['boundaries']:
        if 'honshu-area-36' not in [border['region_a'],border['region_b']]:borders.append(border);continue
        line=LineString(border['points'])
        cuts=[0,line.length]+[line.project(Point(p)) for p in seam.coords if line.distance(Point(p))<1e-5]
        cuts=sorted(set(cuts))
        for i,(start,end) in enumerate(zip(cuts,cuts[1:])):
            if end-start<1e-6:continue
            part=substring(line,start,end);key=owner(part);new=copy.deepcopy(border)
            for field in ['region_a','region_b']:
                if new[field]=='honshu-area-36':new[field]=key
            new.update(boundary_id=border['boundary_id']+f':region36-split-{i}',points=list(part.coords))
            borders.append(new)
    borders.append({'boundary_id':'honshu:settsu:izumi:0','region_a':'settsu','region_b':'izumi','points':list(seam.coords),'review_status':'accepted','trace_method':'user_region36_edits'})
    data['boundaries']=borders
    refs=[]
    for ref in data['coastline_references']:
        if ref['region_id']!='honshu-area-36':refs.append(ref);continue
        assert not ref['wrap']
        coast=LineString(data['coastlines'][ref['coastline_id']])
        cuts=[ref['start_distance'],ref['end_distance']]+[coast.project(Point(p)) for p in seam.coords if coast.distance(Point(p))<1e-5]
        cuts=sorted(set(cuts))
        for i,(start,end) in enumerate(zip(cuts,cuts[1:])):
            assert ref['start_distance']<=start<end<=ref['end_distance']
            key=owner(substring(coast,start,end))
            refs.append({**ref,'arc_id':ref['arc_id']+f':split-{i}','region_id':key,'start_distance':start,'end_distance':end})
    data['coastline_references']=refs
    assert not any(r['region_id']=='honshu-area-36' for r in data['boundary_references'])
    for r in before['regions']:
        if r['region_id']!='honshu-area-36':assert r in data['regions']
    assert before['coastlines']==data['coastlines']
    shutil.copytree(old,target);data['version']='1.0.4'
    save(target/'political_registry_master.json',data)
    save(target/'name_review.json',[])
    shutil.copyfile(source,target/'approved_region36_edits.json')
    save(target/'region36_split_report.json',{'input_sha256':digest(source),'seam':list(seam.coords),'maximum_endpoint_adjustment':max(min(Point(p).distance(Point(q)) for q in seam.coords) for p in raw),'unchanged_union':True,'other_regions_unchanged':True,'selection_samples':{k:list(p.representative_point().coords)[0] for k,p in faces.items()}})
    gpd.GeoDataFrame([{'region_id':r['region_id'],'geometry':Polygon(r['polygons'][0])} for r in data['regions']]).to_file(target/'political_regions_master.gpkg',layer='political_regions_8192',driver='GPKG')
    manifest=read(old/'political_master_manifest.json')
    manifest.update(version='1.0.4',name_status='All names resolved; Settsu and Izumi split by user line')
    manifest['approval']={'approved_by':'user','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'instruction':'region36_border_edits.json: これでお願いします。'}
    manifest['files']={p.name:digest(p) for p in target.iterdir() if p.is_file() and p.name!='political_master_manifest.json'}
    save(target/'political_master_manifest.json',manifest)
    save(target.parent/'status.json',{'status':'approved','current_version':'1.0.4'})
    print('Regions',len(data['regions']),'boundaries',len(borders))

if __name__=='__main__':run()
