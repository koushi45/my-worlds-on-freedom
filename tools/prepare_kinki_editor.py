"""Package an explicitly requested EDITOR draft, never approved game regions."""
import json,shutil
from pathlib import Path
import hashlib
from shapely.geometry import LineString, Point
from shapely.ops import nearest_points, unary_union
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'data/work/political/kinki_uploaded_crop/kinki'
OUT=ROOT/'data/derived/editor/kinki'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
    OUT.mkdir(parents=True,exist_ok=True)
    handdrawn=ROOT/'data/work/political/kinki_handdrawn/editor_draft.json'
    if handdrawn.exists():
        data=json.loads(handdrawn.read_text(encoding='utf-8'))
        assert data['status']=='editor_draft_only'
        (OUT/'editor_draft.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        shutil.copyfile(handdrawn.parent/'source.png',OUT/'reference.png')
        print('Packaged user hand-drawn Kinki boundaries:',OUT)
        return
    data=json.loads((WORK/'review_layer.json').read_text(encoding='utf-8'))
    previous=json.loads((OUT/'editor_draft.json').read_text(encoding='utf-8')) if (OUT/'editor_draft.json').exists() else {}
    registry=json.loads((ROOT/'data/derived/political/approved_western/political_registry.json').read_text(encoding='utf-8'))
    shared=[b for b in registry['boundaries'] if b['boundary_id'].startswith('chugoku:') and b['region_b']=='outside_chugoku']
    assert len(shared)==3
    shared_geometry=unary_union([LineString(b['points']) for b in shared])
    removed=[b for b in data['boundaries'] if b.get('region_b') in ['inaba','mimasaka','bizen']]
    data['boundaries']=[b for b in data['boundaries'] if b not in removed]
    endpoints={tuple(p) for b in removed for p in [b['points'][0],b['points'][-1]]}
    remaps=[]
    for b in data['boundaries']:
        for end in [0,-1]:
            old=b['points'][end]
            if tuple(old) in endpoints:
                new=list(nearest_points(Point(old),shared_geometry)[1].coords[0])
                remaps.append({'from':old,'to':new})
                b['points'][end]=new
    data['shared_boundary_references']=[{'boundary_id':b['boundary_id'],'source':'approved_western','read_only':True} for b in shared]
    data['shared_boundary_migration']={'removed_ids':[b['boundary_id'] for b in removed],'endpoint_remaps':remaps}
    data['legacy_reference_hashes']=previous.get('legacy_reference_hashes',[])
    if previous.get('reference_hashes') and previous['reference_hashes'] not in data['legacy_reference_hashes']:
        data['legacy_reference_hashes'].append(previous['reference_hashes'])
    data['status']='editor_draft_only'
    data['schema_version']=1
    data['reference_hashes']={p:digest(ROOT/p) for p in ['data/base/japan_land.gpkg','data/derived/coastline/coastline_master.gpkg','data/derived/political/approved_western/political_registry.json']}
    data['source_draft_sha256']=digest(WORK/'review_layer.json')
    data['coordinate_system']={'name':'japan_land_master_8192','axes':'x_right_y_down','units':'game_pixel','size':[8192,8192],'display_transform_applied':False}
    data['raster_georeference']=json.loads((WORK/'raster_georeference.json').read_text(encoding='utf-8'))
    (OUT/'editor_draft.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    shutil.copyfile(WORK/'warped_raster.png',OUT/'reference.png')
    print('Packaged isolated editor draft:',OUT)
if __name__=='__main__':run()
