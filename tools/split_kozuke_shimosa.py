"""Split region 15 at its narrow neck, preserving every exterior vertex."""
import copy
import shutil
from datetime import datetime, timezone
import geopandas as gpd
from shapely.geometry import Polygon, LineString
from shapely.ops import unary_union
from finalize_honshu_edits import ROOT, read, save, digest

def run():
    old = ROOT/'data/master/political/honshu/1.0.1'
    target = old.parent/'1.0.2'
    assert not target.exists()
    data = read(old/'political_registry_master.json')
    original = copy.deepcopy(data)
    region = next(r for r in data['regions'] if r['region_id']=='honshu-area-15')
    ring = region['polygons'][0][:-1]
    a = ring.index([5148.24407,5023.85672])
    b = ring.index([5148.24407,5019.61761])
    halves = sorted([Polygon(ring[a:b+1]), Polygon(ring[b:]+ring[:a+1])], key=lambda p:p.centroid.x)
    faces = dict(zip(['kozuke','shimosa'], halves))
    assert all(p.is_valid and p.area>1000 for p in halves)
    assert unary_union(halves).symmetric_difference(Polygon(region['polygons'][0])).area<1e-7
    assert halves[0].intersection(halves[1]).area == 0
    data['regions'].remove(region)
    for key,name in [('kozuke','上野国'),('shimosa','下総国')]:
        data['regions'].append({'region_id':key,'name_ja':name,'name_status':'user_confirmed', 'polygons':[list(faces[key].exterior.coords)], 'review_status':'accepted'})
    boundaries=[]
    for border in data['boundaries']:
        if 'honshu-area-15' not in [border['region_a'],border['region_b']]:
            boundaries.append(border)
            continue
        groups=[]
        for p,q in zip(border['points'],border['points'][1:]):
            segment=LineString([p,q])
            owners=[key for key,face in faces.items() if segment.difference(face.boundary.buffer(1e-7)).length<1e-6]
            assert len(owners)==1, (border['boundary_id'],p,q,owners)
            owner=owners[0]
            if groups and groups[-1][0]==owner: groups[-1][1].append(q)
            else: groups.append([owner,[p,q]])
        for i,(owner,points) in enumerate(groups):
            updated=copy.deepcopy(border)
            for field in ['region_a','region_b']:
                if updated[field]=='honshu-area-15':updated[field]=owner
            updated['points']=points
            updated['boundary_id']=border['boundary_id'].replace('honshu-area-15',owner)+f':split-{i}'
            boundaries.append(updated)
    boundaries.append({'boundary_id':'honshu:kozuke:shimosa:0','region_a':'kozuke','region_b':'shimosa','points':[ring[a],ring[b]],'review_status':'accepted','trace_method':'user_requested_narrow_neck_split'})
    data['boundaries']=boundaries
    for ref in data['coastline_references']:
        if ref['region_id']=='honshu-area-15': ref['region_id']='shimosa'
    assert not any(r['region_id']=='honshu-area-15' for r in data['boundary_references'])
    for r in original['regions']:
        if r['region_id']!='honshu-area-15':assert r in data['regions']
    assert data['coastlines']==original['coastlines']
    shutil.copytree(old,target)
    data['version']='1.0.2'
    save(target/'political_registry_master.json',data)
    save(target/'name_review.json',[r for r in read(old/'name_review.json') if r['region_id']!='honshu-area-15'])
    save(target/'split_report.json',{'previous_region_id':'honshu-area-15','new_region_ids':list(faces),'split_points':[ring[a],ring[b]],'split_length':LineString([ring[a],ring[b]]).length,'unchanged_union':True,'other_regions_unchanged':True,'selection_samples':{key:list(p.representative_point().coords)[0] for key,p in faces.items()}})
    gpd.GeoDataFrame([{'region_id':r['region_id'],'geometry':Polygon(r['polygons'][0])} for r in data['regions']]).to_file(target/'political_regions_master.gpkg',layer='political_regions_8192',driver='GPKG')
    manifest=read(old/'political_master_manifest.json')
    manifest.update(version='1.0.2',name_status='Region 15 split into user-confirmed Kozuke and Shimosa; 2 unresolved names remain')
    manifest['approval']={'approved_by':'user','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'instruction':'同じ国になってしまう、画像の国(領域15)を二つに分けて下さい。左側が上野国、右側は下総国です。'}
    manifest['files']={p.name:digest(p) for p in target.iterdir() if p.is_file() and p.name!='political_master_manifest.json'}
    save(target/'political_master_manifest.json',manifest)
    save(target.parent/'status.json',{'status':'approved','current_version':'1.0.2'})
    print('Honshu regions:',len(data['regions']),'boundaries:',len(boundaries))

if __name__=='__main__':run()
