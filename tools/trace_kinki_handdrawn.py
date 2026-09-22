"""Register the user's base-map drawing and trace its black interior strokes."""
import json
from pathlib import Path
import cv2
import numpy as np
import shapely
import geopandas as gpd
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union, nearest_points
from prepare_kinki_editor import ROOT, digest

SOURCE=Path('C:/Users/nanoa/AppData/Local/Temp/codex-clipboard-8e557136-590b-4e1c-b019-41f4efda3582.png')
OUT=ROOT/'data/work/political/kinki_handdrawn'
if (OUT/'source.png').exists():SOURCE=OUT/'source.png'

def save(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def thin(mask):
    a=np.pad(mask.astype(np.uint8),1)
    while True:
        changed=False
        for step in range(2):
            p=[a[:-2,1:-1],a[:-2,2:],a[1:-1,2:],a[2:,2:],a[2:,1:-1],a[2:,:-2],a[1:-1,:-2],a[:-2,:-2]]
            count=sum(p);cross=sum((p[i]==0)&(p[(i+1)%8]==1) for i in range(8))
            c1=p[0]*p[2]*(p[4] if step==0 else p[6])
            c2=(p[2] if step==0 else p[0])*p[4]*p[6]
            remove=(a[1:-1,1:-1]==1)&(count>=2)&(count<=6)&(cross==1)&(c1==0)&(c2==0)
            if remove.any():a[1:-1,1:-1][remove]=0;changed=True
        if not changed:break
    return a[1:-1,1:-1]

def trace(skeleton):
    pixels=set(map(tuple,np.argwhere(skeleton)))
    adjacent={}
    for y,x in pixels:
        neighbors=[]
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            q=(y+dy,x+dx)
            if q in pixels and not (dy and dx and ((y+dy,x) in pixels or (y,x+dx) in pixels)):
                neighbors.append(q)
        adjacent[(y,x)]=neighbors
    nodes={p for p in pixels if len(adjacent[p])!=2}
    groups=[];seen=set();node_id={}
    for p in sorted(nodes):
        if p in seen:continue
        group=[];stack=[p];seen.add(p)
        while stack:
            q=stack.pop();group.append(q)
            for n in adjacent[q]:
                if n in nodes and n not in seen:seen.add(n);stack.append(n)
        for q in group:node_id[q]=len(groups)
        groups.append(np.mean(group,axis=0)[::-1].tolist())
    visited=set();lines=[]
    def key(a,b):return tuple(sorted([a,b]))
    for p in sorted(nodes):
        for q in adjacent[p]:
            if q in nodes or key(p,q) in visited:continue
            coords=[groups[node_id[p]]];prev=p;current=q;visited.add(key(prev,current))
            while current not in nodes:
                coords.append(list(current[::-1]))
                nxt=next(n for n in adjacent[current] if n!=prev)
                prev,current=current,nxt;visited.add(key(prev,current))
            coords.append(groups[node_id[current]])
            line=LineString(coords).simplify(.8)
            if line.length>=4:lines.append(line)
    return lines

def run():
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'source.png').write_bytes(SOURCE.read_bytes())
    image=cv2.imread(str(SOURCE));h,w=image.shape[:2]
    seed=json.loads((ROOT/'data/derived/editor/kinki/editor_draft.json').read_text(encoding='utf-8'))
    locked=json.loads((ROOT/'data/derived/political/approved_western/political_registry.json').read_text(encoding='utf-8'))
    coast=LineString(next(iter(seed['coastlines'].values())))
    rgb=image.astype(np.int16)
    sea=(rgb[:,:,0]>rgb[:,:,2]+20)&(rgb[:,:,1]>rgb[:,:,2]+10)&(rgb[:,:,2]<80)
    shore=(cv2.dilate(sea.astype(np.uint8),np.ones((3,3),np.uint8))!=sea)&(~sea)
    shore[:4,:]=False;shore[-4:,:]=False;shore[:,:4]=False;shore[:,-4:]=False
    y,x=np.where(shore);samples=np.c_[x,y][::3].astype(float)
    scale=1.065;offset=np.array([2907.,4390.])
    # Uniform scale and translation only: the drawing already uses the base.
    for iteration in range(35):
        world=samples*scale+offset
        pts=shapely.points(world)
        closest=shapely.get_coordinates(shapely.line_interpolate_point(coast,shapely.line_locate_point(coast,pts)))
        dist=np.linalg.norm(closest-world,axis=1)
        good=dist<max(3.,18.-iteration)
        u=samples[good];v=closest[good];uc=u-u.mean(axis=0);vc=v-v.mean(axis=0)
        scale=float((uc*vc).sum()/(uc*uc).sum());offset=v.mean(axis=0)-scale*u.mean(axis=0)
    world=samples*scale+offset
    residual=shapely.distance(shapely.points(world),coast)/scale
    all_coasts=gpd.read_file(ROOT/'data/derived/coastline/coastline_master.gpkg',layer='coastline_8192')
    tree=shapely.STRtree(all_coasts.geometry.values)
    closest_indices=tree.nearest(shapely.points(world))
    residual=shapely.distance(shapely.points(world),all_coasts.geometry.values[closest_indices])/scale
    print('Registration',scale,offset,'median/p90 px',np.percentile(residual,[50,90]),flush=True)
    # Black pen is distinct from the brown approved lines and blue ocean.
    black=np.max(image,axis=2)<45
    land_distance=cv2.distanceTransform((~sea).astype(np.uint8),cv2.DIST_L2,5)
    mask=black&(land_distance>3)
    mask[:3,:]=False;mask[-3:,:]=False;mask[:,:3]=False;mask[:,-3:]=False
    strokes=trace(thin(mask))
    faces=unary_union([Polygon(ring) for r in locked['regions'] for ring in r['polygons']])
    shared=[b for b in locked['boundaries'] if b['boundary_id'].startswith('chugoku:') and b['region_b']=='outside_chugoku']
    seam=unary_union([LineString(b['points']) for b in shared])
    boundaries=[];snaps=[]
    for stroke in strokes:
        coords=np.array(stroke.coords)*scale+offset
        line=LineString(coords)
        # Existing approved territory and its border are never retraced.
        if line.intersection(faces.buffer(1)).length>line.length*.5:continue
        for end in [0,-1]:
            pt=Point(coords[end]);target=seam if pt.distance(seam)<10*scale else coast
            dist=pt.distance(target)
            if dist<10*scale:
                new=nearest_points(pt,target)[1].coords[0]
                snaps.append({'from':coords[end].tolist(),'to':list(new),'distance_source_px':dist/scale})
                coords[end]=new
        if LineString(coords).length<4*scale:continue
        boundaries.append({'boundary_id':f'kinki:handdrawn:{len(boundaries):03d}',
            'points':coords.tolist(),'trace_method':'user_handdrawn_centerline','certainty':'user_drawn','review_status':'pending'})
    bounds=[*offset.tolist(),*(offset+np.array([w,h])*scale).tolist()]
    data={**seed,'boundaries':boundaries,'bounds':bounds,'regions':[],
          'source_draft_sha256':digest(SOURCE),'legacy_reference_hashes':[],
          'coastline_references':[],'region_labels':[],'pending':['Image-edge endpoints remain open; province areas are not yet approved.'],
          'shared_boundary_migration':{},'reference_hashes':{p:digest(ROOT/p) for p in seed['reference_hashes']},
          'raster_georeference':{'bounds_8192':bounds,'pixels_per_game_unit':1/scale,'size':[w,h]},
          'handdrawn_source':{'sha256':digest(SOURCE),'scale':scale,'offset':offset.tolist()}}
    save(OUT/'editor_draft.json',data)
    overlay=image.copy()
    for b in boundaries:
        xy=np.rint((np.array(b['points'])-offset)/scale).astype(np.int32)
        cv2.polylines(overlay,[xy],False,(210,185,0),1,cv2.LINE_AA)
    cv2.imwrite(str(OUT/'trace_overlay.png'),overlay)
    save(OUT/'trace_report.json',{'source_sha256':digest(SOURCE),'source_size':[w,h],'scale':scale,'offset':offset.tolist(),
        'shore_residual_source_px':dict(zip(['median','p90'],np.percentile(residual,[50,90]).tolist())),
        'stroke_count':len(boundaries),'endpoint_snaps':snaps,'status':'editor_draft_only'})
    print('Traced',len(boundaries),'lines',flush=True)

if __name__=='__main__':run()
