"""Merge user-designated region 02 into the existing northern Mutsu region."""
import copy
import shutil
from datetime import datetime, timezone
import geopandas as gpd
from shapely.geometry import Polygon
from shapely.ops import unary_union
from finalize_honshu_edits import ROOT, read, save, digest

def run():
    old = ROOT/'data/master/political/honshu/1.0.2'
    target = old.parent/'1.0.3'
    assert not target.exists(), 'Version already frozen'
    data = read(old/'political_registry_master.json')
    original = copy.deepcopy(data)
    source_id, destination_id = 'honshu-area-02', 'honshu-area-01'
    source = next(r for r in data['regions'] if r['region_id']==source_id)
    destination = next(r for r in data['regions'] if r['region_id']==destination_id)
    assert destination['name_ja']=='陸奥国'
    shapes = [Polygon(r['polygons'][0]) for r in [source,destination]]
    merged = unary_union(shapes)
    assert merged.geom_type=='Polygon' and merged.is_valid and not merged.interiors
    assert abs(merged.area-sum(p.area for p in shapes))<1e-7
    samples = [list(p.representative_point().coords)[0] for p in shapes]
    destination.update(polygons=[list(merged.exterior.coords)],name_status='user_confirmed')
    data['regions'].remove(source)
    removed=[]
    borders=[]
    for border in data['boundaries']:
        if {border['region_a'],border['region_b']}=={source_id,destination_id}:
            removed.append(border['boundary_id'])
            continue
        for field in ['region_a','region_b']:
            if border[field]==source_id:border[field]=destination_id
        assert border['region_a']!=border['region_b']
        borders.append(border)
    assert removed
    data['boundaries']=borders
    for field in ['coastline_references','boundary_references']:
        for reference in data[field]:
            if reference['region_id']==source_id:reference['region_id']=destination_id
    for region in original['regions']:
        if region['region_id'] not in [source_id,destination_id]:assert region in data['regions']
    assert data['coastlines']==original['coastlines']
    shutil.copytree(old,target)
    data['version']='1.0.3'
    save(target/'political_registry_master.json',data)
    save(target/'name_review.json',[r for r in read(old/'name_review.json') if r['region_id']!=source_id])
    save(target/'merge_report.json',{'source_region_id':source_id,'destination_region_id':destination_id,'removed_boundary_ids':removed,'selection_samples':samples,'unchanged_union':True,'other_regions_unchanged':True})
    gpd.GeoDataFrame([{'region_id':r['region_id'],'geometry':Polygon(r['polygons'][0])} for r in data['regions']]).to_file(target/'political_regions_master.gpkg',layer='political_regions_8192',driver='GPKG')
    manifest=read(old/'political_master_manifest.json')
    manifest.update(version='1.0.3',name_status='Region 02 merged into Mutsu; 1 unresolved name remains')
    manifest['approval']={'approved_by':'user','recorded_at_utc':datetime.now(timezone.utc).isoformat(),'instruction':'領域02は陸奥国に統合して下さい。ビルドもお願いします。'}
    manifest['files']={p.name:digest(p) for p in target.iterdir() if p.is_file() and p.name!='political_master_manifest.json'}
    save(target/'political_master_manifest.json',manifest)
    save(target.parent/'status.json',{'status':'approved','current_version':'1.0.3'})
    print('Honshu regions:',len(data['regions']),'boundaries:',len(borders),'removed:',removed,'samples:',samples)

if __name__=='__main__':run()
