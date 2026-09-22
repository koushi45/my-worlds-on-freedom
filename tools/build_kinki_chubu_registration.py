"""Separate regional image warps and political review vectors; immutable base."""
import argparse
import json
from pathlib import Path
import cv2
import geopandas as gpd
import numpy as np
import shapely
from PIL import Image,ImageDraw
from shapely.geometry import Point,Polygon,LineString
from shapely.ops import nearest_points,substring,unary_union,polygonize,linemerge
import build_kyushu_registration as core
from build_coastline_alignment_v2 import font

ROOT=core.ROOT
WORK=ROOT/'data/work/political/kinki_chubu_registration'
SPEC=WORK/'spec.json'

def coast_arcs(coast,coast_id,cuts):
    result=[]
    for i,(start,name,pt) in enumerate(cuts):
        end,other,last=cuts[(i+1)%len(cuts)]
        if end<start:
            coords=list(substring(coast,start,coast.length).coords)+list(substring(coast,0,end).coords)[1:]
        else:coords=list(substring(coast,start,end).coords)
        coords[0]=pt;coords[-1]=last
        result.append({'arc_id':f'coast:{i:02d}','coastline_id':coast_id,'start_distance':start,
                       'end_distance':end,'wrap':end<start,'geometry':LineString(coords)})
    return result

def create_mesh(spec,coast):
    src=np.array([p[1:3] for p in spec['controls']],float)
    dst=np.array([(core.p2.game_point(*p[3:5]) if p[0] in spec.get('interior_controls',[]) else nearest_points(core.p2.game_point(*p[3:5]),coast)[1]).coords[0] for p in spec['controls']])
    for i,p in enumerate(spec['controls']):
        if p[0] in spec.get('target_overrides',{}):
            dst[i]=nearest_points(Point(spec['target_overrides'][p[0]]),coast)[1].coords[0]
    matrix=np.linalg.lstsq(np.c_[src,np.ones(len(src))],dst,rcond=None)[0]
    x0,y0,x1,y1=spec['crop'];xs=np.linspace(x0-25,x1+25,9);ys=np.linspace(y0-25,y1+25,7)
    guard=np.array([[x,y] for j,y in enumerate(ys) for i,x in enumerate(xs) if i in (0,8) or j in (0,6)])
    mesh=core.Mesh(np.vstack([src,guard]),np.vstack([dst,np.c_[guard,np.ones(len(guard))]@matrix]))
    if (mesh.jac<=1e-8).any():
        ids=[p[0] for p in spec['controls']]+[f'guard{i}' for i in range(len(guard))]
        bad=[[ids[i] for i in triangle] for triangle,jac in zip(mesh.indices,mesh.jac) if jac<=1e-8]
        raise RuntimeError(f'Folded/degenerate triangles: {bad}')
    polys=[Polygon(t) for t in mesh.t]
    assert abs(sum(p.area for p in polys)-unary_union(polys).area)<1e-5
    return mesh,src,dst

def warp(alpha,mesh,bounds,scale):
    w,h=np.ceil((np.array(bounds[2:])-bounds[:2])*scale).astype(int)
    mx=np.full((h,w),-100,np.float32);my=mx.copy()
    for s,t in zip(mesh.s,mesh.t):
        p=(t-bounds[:2])*scale
        x0,y0=np.maximum(np.floor(p.min(axis=0)).astype(int),0)
        x1,y1=np.minimum(np.ceil(p.max(axis=0)).astype(int)+1,[w,h])
        if x1<=x0 or y1<=y0:continue
        yy,xx=np.mgrid[y0:y1,x0:x1]
        q=np.c_[xx.ravel()/scale+bounds[0],yy.ravel()/scale+bounds[1],np.ones(xx.size)]
        bary=q @ np.linalg.inv(np.c_[t,np.ones(3)])
        good=np.all(bary>=-1e-9,axis=1);mapped=bary @ s
        oy,ox=yy.ravel()[good],xx.ravel()[good]
        mx[oy,ox]=mapped[good,0];my[oy,ox]=mapped[good,1]
    ink=cv2.remap(alpha,mx,my,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
    out=np.zeros((h,w,4),np.uint8);out[:,:,3]=ink
    return out,mx,my

def build(name):
    all_spec=json.loads(SPEC.read_text(encoding='utf-8'));spec=all_spec['regions'][name]
    out=WORK/name;qa=out/'qa';qa.mkdir(parents=True,exist_ok=True)
    source=ROOT/all_spec['source']
    frozen={str(p.relative_to(ROOT)):core.digest(p) for p in [core.p2.MASTER_LAND,core.p2.COAST_GPKG,source,
        ROOT/'data/master/political/kyushu/1.0.0/political_master_manifest.json',
        ROOT/'data/derived/political/approved_kyushu/political_registry.json']}
    frame=gpd.read_file(core.p2.COAST_GPKG,layer='coastline_8192')
    coast=frame.set_index('coastline_id').loc[spec['coastline_id']].geometry
    _,whole_land=core.p3.canonical_land_8192()
    land=next(p for p in core.p3.polygon_parts(whole_land) if p.contains(core.p2.game_point(*spec['land_seed'])))
    mesh,src,dst=create_mesh(spec,coast)
    alpha=np.array(Image.open(source).getchannel('A'))
    # Mesh bounds only show this region, not the rest of Honshu.
    bmin=dst.min(axis=0)-60;bmax=dst.max(axis=0)+60
    bounds=np.r_[bmin,bmax].tolist();scale=min(1.3,1800/(bmax-bmin).max())
    warped,mx,my=warp(alpha,mesh,bounds,scale)
    Image.fromarray(warped).save(out/'warped_raster.png')
    core.save_json(out/'raster_georeference.json',{'bounds_8192':bounds,'pixels_per_game_unit':scale,'size':[warped.shape[1],warped.shape[0]],'pixel_origin':'integer pixel centres'})
    nodes={k:tuple(mesh.transform([p])[0]) for k,p in spec['nodes'].items()}
    borders=[];source_lines=[];trims=[];raw_vectors=[]
    for left,right,start,end,middle in spec['boundaries']:
        coords=core.assisted_trace(alpha,[spec['nodes'][start]]+middle+[spec['nodes'][end]])
        line=mesh.line(coords);pts=list(line.coords);pts[0]=nodes[start];pts[-1]=nodes[end];line=LineString(pts)
        pieces=[p for p in core.p3.line_parts(line.intersection(land)) if p.length>1e-7]
        if len(pieces)!=1:
            raise RuntimeError(f'{left}/{right} land runs: '+str([(p.length,p.coords[0],p.coords[-1]) for p in pieces]))
        clipped=pieces[0];pts=list(clipped.coords)
        if Point(pts[0]).distance(Point(line.coords[0]))>Point(pts[-1]).distance(Point(line.coords[0])):pts.reverse()
        for node,pt in [(start,pts[0]),(end,pts[-1])]:
            dist=Point(nodes[node]).distance(Point(pt))
            if dist>1e-7:
                if node not in spec['coast_nodes']:raise RuntimeError(f'Interior node outside land: {node}')
                trims.append({'node_id':node,'original':nodes[node],'clipped':pt,'distance_game_px':dist,'status':'pending'})
                nodes[node]=tuple(pt)
        pts[0]=nodes[start];pts[-1]=nodes[end]
        record={'boundary_id':f'{name}:{left}:{right}','region_a':left,'region_b':right,'start_node':start,'end_node':end,
                'certainty':'probable','review_status':'pending','trace_method':'assisted'}
        source_lines.append({**record,'geometry':LineString(coords)})
        borders.append({**record,'geometry':LineString(pts)})
        raw_vectors.append({**record,'geometry':line})
    cuts=sorted((coast.project(Point(nodes[n])),n,nodes[n]) for n in spec['coast_nodes'])
    arcs=coast_arcs(coast,spec['coastline_id'],cuts)
    graph=unary_union([r['geometry'] for r in borders+arcs]);faces=list(polygonize(graph))
    regions=[];face_ids=[]
    for id,seed in spec['seeds'].items():
        point=Point(mesh.transform([seed])[0]);indices=[i for i,f in enumerate(faces) if f.covers(point)]
        if len(indices)!=1:raise RuntimeError(f'{id}: no unique closed region; indices={indices}')
        face_ids.append(indices[0])
        regions.append({'region_id':id,'name_ja':spec['names'][id],'certainty':'probable','review_status':'pending','geometry':faces[indices[0]].intersection(land)})
    if len(set(face_ids))!=len(face_ids):raise RuntimeError(f'Duplicate regions {list(zip(spec["seeds"],face_ids))}')
    scope=land
    if spec.get('scope_endpoints'):
        east=[r for r in borders if r['region_b'] not in spec['seeds']]
        endpoints=spec['scope_endpoints'];cut=sorted((coast.project(Point(nodes[n])),n,nodes[n]) for n in endpoints)
        outer_arcs=coast_arcs(coast,spec['coastline_id'],cut)
        # Only image-traced eastern boundary plus canonical coast delimit scope.
        outer_faces=list(polygonize(unary_union([r['geometry'] for r in east+outer_arcs])))
        anchor=Point(mesh.transform([next(iter(spec['seeds'].values()))])[0])
        candidates=[p for p in outer_faces if p.covers(anchor)]
        if len(candidates)!=1:raise RuntimeError('Chugoku east-edge scope is not closed')
        scope=candidates[0].intersection(land)
    union=unary_union([r['geometry'] for r in regions])
    gap=scope.difference(union).area;overlap=sum(r['geometry'].area for r in regions)-union.area
    print(name,'faces',len(faces),'gap',gap,'overlap',overlap,flush=True)
    # Save diagnostics on incomplete topology rather than silently filling gaps.
    issues={'faces':len(faces),'face_areas':[p.area for p in faces],'face_ids':face_ids,'gap':gap,'overlap':overlap}
    core.save_json(out/'topology_diagnostics.json',issues)
    if gap>1e-6 or abs(overlap)>1e-6:raise RuntimeError('Review graph gaps/overlaps before completing')
    # Retain only traced graph edges separating the labelled faces. Ink tracing
    # can backtrack near a thick T junction; those spurs do not separate countries.
    lookup={r['region_id']:r['geometry'] for r in regions}
    clean=[];junction_cleanup=[]
    for r in borders:
        shared=lookup[r['region_a']].boundary
        if r['region_b'] in lookup:shared=shared.intersection(lookup[r['region_b']].boundary)
        keep=r['geometry'].intersection(shared)
        parts=core.p3.line_parts(keep)
        merged=linemerge(parts) if parts else LineString()
        runs=[p for p in core.p3.line_parts(merged) if p.length>1e-6]
        if not runs:raise RuntimeError('No shared face edge: '+r['boundary_id'])
        removed=r['geometry'].length-sum(p.length for p in runs)
        junction_cleanup.append({'boundary_id':r['boundary_id'],'removed_length_game_px':removed,'runs':len(runs),'status':'pending'})
        for i,line in enumerate(runs):
            clean.append({**r,'boundary_id':r['boundary_id']+(f':part{i}' if len(runs)>1 else ''),'geometry':line})
    borders=clean
    selected_arcs=[]
    for a in arcs:
        point=a['geometry'].interpolate(.5,normalized=True)
        owners=[r['region_id'] for r in regions if r['geometry'].boundary.distance(point)<1e-7]
        if len(owners)==1:a['region_id']=owners[0];selected_arcs.append(a)
        elif len(owners)>1:raise RuntimeError('Ambiguous coast arc')
    gpkg=out/'political_candidate.gpkg'
    if gpkg.exists():gpkg.unlink()
    layers={'source_boundaries_px':source_lines,'shared_boundaries_8192':borders,'raw_warped_boundaries_8192':raw_vectors,
            'political_regions_8192':regions,'coastline_references_8192':selected_arcs,
            'scope_land_8192':[{'scope':name,'geometry':scope}],
            'warp_mesh_source':[{'triangle_id':i,'geometry':Polygon(p)} for i,p in enumerate(mesh.s)],
            'warp_mesh_target':[{'triangle_id':i,'geometry':Polygon(p)} for i,p in enumerate(mesh.t)],
            'control_points_8192':[{'control_id':row[0],'source_x':s[0],'source_y':s[1],'target_x':t[0],'target_y':t[1],'review_status':'pending','geometry':Point(t)} for row,s,t in zip(spec['controls'],src,dst)]}
    for key,rows in layers.items():gpd.GeoDataFrame(rows,geometry='geometry').to_file(gpkg,layer=key,driver='GPKG')
    core.p2.normalize_gpkg(gpkg)
    review={'status':'pending_user_review','scope':name,'bounds':bounds,'raster':'warped_raster.png',
            'coastlines':{spec['coastline_id']:list(coast.coords)},
            'boundaries':[{k:v for k,v in r.items() if k!='geometry'}|{'points':list(r['geometry'].coords)} for r in borders],
            'coastline_references':[{k:v for k,v in r.items() if k!='geometry'} for r in selected_arcs],
            'regions':[{'region_id':r['region_id'],'name_ja':r['name_ja'],'polygons':[list(p.exterior.coords) for p in core.p3.polygon_parts(r['geometry'])]} for r in regions]}
    core.save_json(out/'review_layer.json',review)
    def xy(points):return [tuple(p) for p in (np.asarray(points)-bounds[:2])*scale]
    base=Image.new('RGB',(warped.shape[1],warped.shape[0]),'#203e4b');d=ImageDraw.Draw(base)
    from shapely.geometry import box
    visible_land=whole_land.intersection(box(*bounds))
    for p in core.p3.polygon_parts(visible_land):d.polygon(xy(p.exterior.coords),fill='#faf9f5')
    before=base.convert('RGBA');before.alpha_composite(Image.fromarray(warped))
    d=ImageDraw.Draw(before)
    for r in selected_arcs:d.line(xy(r['geometry'].coords),fill='#ec4784',width=2)
    before.save(qa/'01_actual_warp.png')
    for r in borders:d.line(xy(r['geometry'].coords),fill='#00b9cf',width=2)
    before.save(qa/'02_raster_vector_overlay.png')
    d=ImageDraw.Draw(base)
    for r in selected_arcs+borders:d.line(xy(r['geometry'].coords),fill='#332b24',width=2)
    base.save(qa/'03_boundaries.png')
    colors=['#dba5ab','#e9cd94','#afd0ad','#c7b4db','#a9cde0','#e1b898','#e0df9b','#b4c4e1','#c3d09b','#e4b8d1','#bad8d3']
    for r,color in zip(regions,colors):
        for p in core.p3.polygon_parts(r['geometry']):d.polygon(xy(p.exterior.coords),fill=color)
    for r in borders:d.line(xy(r['geometry'].coords),fill='#332b24',width=2)
    for r in regions:d.text(xy(r['geometry'].representative_point().coords)[0],r['name_ja'],font=font(21),anchor='mm',fill='#202020')
    base.save(qa/'04_regions.png')
    crop=spec['crop'];trace=Image.fromarray(255-alpha).convert('RGB').crop(crop).resize(((crop[2]-crop[0])*6,(crop[3]-crop[1])*6))
    d=ImageDraw.Draw(trace)
    for r in source_lines:d.line([((x-crop[0])*6,(y-crop[1])*6) for x,y in r['geometry'].coords],fill='#00b9cf',width=2)
    trace.save(qa/'05_source_trace.png')
    loo=[]
    for i in range(len(src)):
        keep=np.arange(len(mesh.src))!=i
        pred=core.Mesh(mesh.src[keep],mesh.dst[keep]).transform([src[i]])[0]
        loo.append(float(np.linalg.norm(pred-dst[i])))
    report={'status':'pending_user_review','scope':name,'counts':{'regions':len(regions),'shared_boundaries':len(borders),'controls':len(src),'triangles':len(mesh.s),'coast_arcs':len(selected_arcs)},
            'spec_sha256':core.digest(SPEC),'generator_sha256':core.digest(Path(__file__)),'junction_cleanup':junction_cleanup,'source_sha256':core.digest(source),'immutable_before':frozen,
            'immutable_after':{p:core.digest(ROOT/p) for p in frozen},'coastal_endpoint_adjustments':trims,
            'gap_area_game_px2':gap,'overlap_area_game_px2':overlap,'folded_triangles':int((mesh.jac<=0).sum()),
            'leave_one_out_control_error_game_px':{'median':float(np.median(loo)),'p95':float(np.percentile(loo,95)),'max':float(max(loo))},
            'coordinate_spaces':{'image':'pixels x-right/y-down','game':'canonical 8192 plane, NOT geographic coordinates','source_crs':'EPSG:4326'},
            'limitations':['Visual source registration, not independent historical accuracy.','Coastline detail does not match perfectly.','Offshore ownership unresolved. No production integration.'],
            'outputs_sha256':{p.name:core.digest(p) for p in [gpkg,out/'review_layer.json',out/'warped_raster.png']}}
    assert report['immutable_before']==report['immutable_after']
    core.save_json(out/'registration_report.json',report)
    print('Saved',out,flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--region',choices=['kinki','chubu','all'],default='all');args=parser.parse_args()
    for name in ['kinki','chubu'] if args.region=='all' else [args.region]:build(name)


