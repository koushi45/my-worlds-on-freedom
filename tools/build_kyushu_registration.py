"""Register the actual Kyushu raster and its shared-border traces.

Canonical files are read-only. One piecewise-affine mesh is used in BOTH
directions: raster resampling, vector transformation and click-region seeds.
Outputs are work/review artifacts, never approved political master data.
"""
from __future__ import annotations
import hashlib
import heapq
import json
import sys
from pathlib import Path
import cv2
import geopandas as gpd
import numpy as np
import shapely
from PIL import Image, ImageDraw
from shapely.geometry import Point, LineString, MultiPoint, Polygon
from shapely.ops import triangulate, nearest_points, substring, polygonize, unary_union

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_phase_p2_regional_warp as p2
import build_phase_p3_political_regions as p3

WORK=ROOT/'data/work/political/kyushu_registration'
QA=WORK/'qa'
SPEC=WORK/'registration_spec.json'
NAMES={'chikuzen':'筑前国','buzen':'豊前国','chikugo':'筑後国','hizen':'肥前国',
       'bungo':'豊後国','higo':'肥後国','hyuga':'日向国','satsuma':'薩摩国','osumi':'大隅国'}

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def save_json(path, obj): path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def resample(coords,step=.25):
    line=LineString(coords)
    return np.array([line.interpolate(float(d)).coords[0] for d in np.linspace(0,line.length,max(2,int(line.length/step)+1))])

def assisted_trace(alpha,points):
    """Trace ink ridges inside a narrow, manually identified border corridor.

    This is not country segmentation or nearest-coast projection. White areas
    cost much more than the middle of the visible black stroke. Shared node
    coordinates remain exact. Return the reviewed corridor's centerline.
    """
    p=np.asarray(points,float);origin=np.floor(p.min(axis=0)-6).astype(int)
    upper=np.ceil(p.max(axis=0)+7).astype(int);factor=4
    ink=cv2.resize(alpha[origin[1]:upper[1],origin[0]:upper[0]],None,fx=factor,fy=factor,interpolation=cv2.INTER_CUBIC)/255.
    h,w=ink.shape
    corridor=np.ones((h,w),np.uint8)
    local=(p-origin)*factor
    cv2.polylines(corridor,[np.round(local).astype(np.int32)],False,0,1)
    proximity=cv2.distanceTransform(corridor,cv2.DIST_L2,5)/factor
    thickness=cv2.distanceTransform((ink>.45).astype(np.uint8),cv2.DIST_L2,5)/factor
    cost=1+18*(1-ink)**2+1.5/(.25+thickness)+.06*proximity**2
    cost[proximity>5]=np.inf
    start=tuple(np.round(local[0]).astype(int));end=tuple(np.round(local[-1]).astype(int))
    dist=np.full((h,w),np.inf);prev={};dist[start[1],start[0]]=0;heap=[(0.,start)]
    directions=[(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]
    while heap:
        value,(x,y)=heapq.heappop(heap)
        if value>dist[y,x]:continue
        if (x,y)==end:break
        for dx,dy in directions:
            xx,yy=x+dx,y+dy
            if not (0<=xx<w and 0<=yy<h):continue
            v=value+(.5*(cost[y,x]+cost[yy,xx]))*(1.41421356237 if dx and dy else 1)
            if v<dist[yy,xx]:dist[yy,xx]=v;prev[(xx,yy)]=(x,y);heapq.heappush(heap,(v,(xx,yy)))
    if not np.isfinite(dist[end[1],end[0]]):raise RuntimeError('Untraceable corridor; manual review required')
    chain=[end]
    while chain[-1]!=start:chain.append(prev[chain[-1]])
    arr=np.array(chain[::-1],float)/factor+origin
    # Quarter-pixel sampling and subpixel simplification remove grid stairs.
    arr=np.asarray(LineString(arr).simplify(.12,preserve_topology=True).coords)
    arr[0]=p[0];arr[-1]=p[-1]
    return arr.tolist()

class Mesh:
    def __init__(self,src,dst):
        self.src=np.asarray(src,dtype=float);self.dst=np.asarray(dst,dtype=float)
        lookup={tuple(p):i for i,p in enumerate(self.src)}
        self.indices=np.array([[lookup[tuple(p)] for p in list(t.exterior.coords)[:3]] for t in triangulate(MultiPoint(self.src))])
        self.s=self.src[self.indices]; self.t=self.dst[self.indices]
        self.inv=np.linalg.inv(np.concatenate([self.s,np.ones((len(self.s),3,1))],axis=2))
        self.fwd=np.einsum('nij,njk->nik',self.inv,self.t)
        self.rev=np.linalg.inv(np.concatenate([self.t,np.ones((len(self.t),3,1))],axis=2)) @ self.s
        self.jac=np.linalg.det(self.fwd[:,:2,:])

    def transform(self,points):
        pts=np.asarray(points,dtype=float).reshape(-1,2)
        output=np.full_like(pts,np.nan);done=np.zeros(len(pts),bool)
        h=np.c_[pts,np.ones(len(pts))]
        for i,inv in enumerate(self.inv):
            b=h @ inv
            chosen=np.all(b>=-1e-8,axis=1)&~done
            output[chosen]=b[chosen] @ self.t[i];done|=chosen
        if not done.all(): raise ValueError(f'{np.count_nonzero(~done)} points outside regional registration mesh')
        return output

    def line(self,coords):
        # Split at every mesh edge. Merely transforming original vertices
        # would not follow the same piecewise transform as the raster.
        src=LineString(coords)
        measures={0.,src.length}
        for tri in self.s:
            crossing=src.intersection(Polygon(tri).boundary)
            for p in shapely.get_coordinates(crossing): measures.add(src.project(Point(p)))
        measures.update(src.project(Point(p)) for p in coords)
        return LineString(self.transform([src.interpolate(d).coords[0] for d in sorted(measures)]))

def build():
    WORK.mkdir(exist_ok=True,parents=True);QA.mkdir(exist_ok=True)
    spec=json.loads(SPEC.read_text(encoding='utf-8'))
    source=ROOT/spec['source']
    frozen={str(p.relative_to(ROOT)):digest(p) for p in [p2.MASTER_LAND,p2.COAST_GPKG,source]}
    coasts=gpd.read_file(p2.COAST_GPKG,layer='coastline_8192')
    coast=coasts.set_index('coastline_id').loc[spec['coastline_id']].geometry
    _,canonical_union=p3.canonical_land_8192()
    mainland=[p for p in p3.polygon_parts(canonical_union) if p.contains(p2.game_point(131,32.5))]
    assert len(mainland)==1
    land=mainland[0]
    assert land.exterior.hausdorff_distance(coast)<1e-8
    assert len(land.interiors)==0, 'Lake references must be implemented before supporting lake holes'
    src=np.array([[p[1],p[2]] for p in spec['controls']],float)
    dst=np.array([nearest_points(p2.game_point(p[3],p[4]),coast)[1].coords[0] for p in spec['controls']])
    for i,p in enumerate(spec['controls']):
        if p[0] in spec.get('target_endpoint_overrides',{}):
            dst[i]=nearest_points(Point(spec['target_endpoint_overrides'][p[0]]['point_8192']),coast)[1].coords[0]
    # Exterior support nodes bound the regional warp, not geographic evidence.
    fitted=np.linalg.lstsq(np.c_[src,np.ones(len(src))],dst,rcond=None)[0]
    guard=np.array([[x,y] for y in range(710,951,30) for x in range(390,571,30)
                    if x in (390,570) or y in (710,950)],float)
    dst=np.vstack([dst,np.c_[guard,np.ones(len(guard))]@fitted]);src=np.vstack([src,guard])
    mesh=Mesh(src,dst)
    print('triangles',len(mesh.indices),'reversed',int((mesh.jac<=0).sum()),'min determinant',mesh.jac.min(),flush=True)
    diagnostics={'triangle_count':len(mesh.indices),'reversed_triangles':int((mesh.jac<=0).sum()),'determinant_min':float(mesh.jac.min())}
    save_json(WORK/'mesh_diagnostics.json',diagnostics)
    if (mesh.jac<=0).any():
        print('reversed controls',[[spec['controls'][i][0] if i<len(spec['controls']) else f'guard{i}' for i in tri] for tri,jac in zip(mesh.indices,mesh.jac) if jac<=0],flush=True)
        print('reversed land fractions',[Polygon(t).intersection(land).area/Polygon(t).area for t,jac in zip(mesh.t,mesh.jac) if jac<=0],flush=True)
        # Stop before publishing a folded raster or border layer.
        return False
    rgba=Image.open(source)
    alpha=np.array(rgba.getchannel('A'))
    # Unmodified source pixels (alpha is actual ink; RGB contains transparent noise).
    normalized=Image.fromarray(255-alpha).convert('RGB')
    normalized.crop((405,730,550,910)).resize((1160,1440)).save(QA/'01_source.png')
    controls=[]
    for row,s,t in zip(spec['controls'],src,dst):
        controls.append({'control_id':row[0],'source_x':s[0],'source_y':s[1],
                         'target_x':t[0],'target_y':t[1],'review_status':'pending',
                         'basis':'visual named coastal correspondence','geometry':Point(t)})
    minx,miny,maxx,maxy=land.bounds
    bounds=(minx-55,miny-55,maxx+55,maxy+55)
    scale=1.2
    width=int(np.ceil((bounds[2]-bounds[0])*scale));height=int(np.ceil((bounds[3]-bounds[1])*scale))
    def xy(points): return (np.asarray(points)-np.array(bounds[:2]))*scale
    # Inverse mapping for every destination pixel, using the very same triangles.
    mapx=np.full((height,width),-100,np.float32);mapy=mapx.copy()
    coverage=np.zeros((height,width),np.uint8)
    for i,tri in enumerate(mesh.t):
        px=xy(tri);x0,y0=np.maximum(np.floor(px.min(axis=0)).astype(int),0)
        x1,y1=np.minimum(np.ceil(px.max(axis=0)).astype(int)+1,[width,height])
        if x1<=x0 or y1<=y0: continue
        yy,xx=np.mgrid[y0:y1,x0:x1]
        pts=np.c_[xx.ravel()/scale+bounds[0],yy.ravel()/scale+bounds[1],np.ones(xx.size)]
        bary=pts @ np.linalg.inv(np.c_[tri,np.ones(3)])
        inside=np.all(bary>=-1e-9,axis=1)
        mapped=bary @ mesh.s[i]
        oy,ox=yy.ravel()[inside],xx.ravel()[inside]
        mapx[oy,ox]=mapped[inside,0];mapy[oy,ox]=mapped[inside,1];coverage[oy,ox]=255
    warped=cv2.remap(alpha,mapx,mapy,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    out=np.zeros((height,width,4),np.uint8);out[:,:,3]=warped
    Image.fromarray(out).save(WORK/'warped_raster.png')
    Image.fromarray(coverage).save(WORK/'warp_coverage.png')
    save_json(WORK/'raster_georeference.json',{'bounds_8192':bounds,'pixels_per_game_unit':scale,
             'pixel_origin':'integer pixel centres','size':[width,height],
             'transform':'inverse of saved forward piecewise-affine mesh','not_geographic_crs':True})
    # One trace per shared border; endpoints are shared node IDs, not duplicated guesses.
    source_lines=[];borders=[];line_ridge_errors=[]
    distance=cv2.distanceTransform((alpha<128).astype(np.uint8),cv2.DIST_L2,5)
    nodes=spec['nodes']
    mapped_nodes={name:tuple(mesh.transform([point])[0]) for name,point in nodes.items()}
    endpoint_nodes=['north','west','ariake_n','ariake_e','kunisaki','east','west_s','bay_n','bay_e']
    endpoint_review=[]
    for left,right,start,end,middle in spec['boundaries']:
        points=[nodes[start]]+middle+[nodes[end]]
        points=assisted_trace(alpha,points)
        line=mesh.line(points)
        exact=list(line.coords);exact[0]=mapped_nodes[start];exact[-1]=mapped_nodes[end];line=LineString(exact)
        raw_line=line
        # Water-only tails from raster/base coastal generalisation are trimmed
        # at the FIRST shoreline intersection; no inland point is snapped.
        parts=[p for p in p3.line_parts(line.intersection(land)) if p.length>1e-7]
        if len(parts)!=1:
            print('land runs',left,right,[(p.length,list(p.coords)[0],list(p.coords)[-1]) for p in parts],flush=True)
            raise RuntimeError(f'{left}/{right}: multiple land runs; manual review required')
        line=parts[0]
        if Point(line.coords[0]).distance(Point(raw_line.coords[0]))>Point(line.coords[-1]).distance(Point(raw_line.coords[0])):
            line=LineString(list(line.coords)[::-1])
        for n,pt,original in [(start,line.coords[0],raw_line.coords[0]),(end,line.coords[-1],raw_line.coords[-1])]:
            trim=Point(pt).distance(Point(original))
            if trim>1e-7:
                if n not in endpoint_nodes:raise RuntimeError('An interior junction crossed the sea')
                endpoint_review.append({'node_id':n,'original_game':original,'coast_intersection_game':pt,'trim_game_px':trim,'status':'pending'})
                mapped_nodes[n]=tuple(pt)
        # Intersection arithmetic can perturb untouched junctions by ulps.
        # Reuse their single authoritative node tuple after clipping as well.
        exact=list(line.coords);exact[0]=mapped_nodes[start];exact[-1]=mapped_nodes[end];line=LineString(exact)
        record={'boundary_id':f'kyushu:{left}:{right}','region_a':left,'region_b':right,
                'start_node':start,'end_node':end,'certainty':'probable','review_status':'pending',
                'trace_method':'assisted','note':'Ink-ridge trace in a manually identified corridor; water-only tails clipped to canonical land; user review pending'}
        source_lines.append({**record,'geometry':LineString(points)})
        borders.append({**record,'geometry':line})
        samples=resample(points)
        err=cv2.remap(distance,samples[:,0].astype(np.float32).reshape(-1,1),samples[:,1].astype(np.float32).reshape(-1,1),cv2.INTER_LINEAR).ravel()
        line_ridge_errors.extend(err.tolist())
    # Insert known border endpoints in the canonical ring by linear referencing.
    # Referenced points retain original coastline coordinates (roundoff only).
    cuts=sorted((coast.project(Point(mapped_nodes[n])),n) for n in endpoint_nodes)
    arcs=[]
    for i,(start,node) in enumerate(cuts):
        end,endnode=cuts[(i+1)%len(cuts)]
        if end<start:
            pieces=[substring(coast,start,coast.length),substring(coast,0,end)]
            coords=list(pieces[0].coords)+list(pieces[1].coords)[1:]
        else: coords=list(substring(coast,start,end).coords)
        coords[0]=mapped_nodes[node];coords[-1]=mapped_nodes[endnode]
        arcs.append({'coastline_id':spec['coastline_id'],'arc_id':f'kyushu:coast:{i:02}',
                     'start_distance':start,'end_distance':end,'wrap':end<start,
                     'geometry':LineString(coords)})
    graph=unary_union([r['geometry'] for r in borders+arcs])
    faces=list(polygonize(graph))
    if len(faces)!=len(spec['region_seeds']):
        raise RuntimeError(f'Unexpected closed faces: {len(faces)}; inspect junctions before publication')
    regions=[]
    for key,seed in spec['region_seeds'].items():
        point=Point(mesh.transform([seed])[0]);matching=[f for f in faces if f.covers(point)]
        if len(matching)!=1: raise RuntimeError(f'{key}: expected one closed face, found {len(matching)}')
        face=matching[0].intersection(land)
        regions.append({'region_id':key,'name_ja':NAMES[key],'certainty':'probable',
                        'review_status':'pending','geometry':face})
    union=unary_union([r['geometry'] for r in regions])
    overlap=sum(r['geometry'].area for r in regions)-union.area
    gap=land.difference(union).area
    outside=sum(r['geometry'].difference(land).area for r in regions)
    border_outside=sum(r['geometry'].difference(land).length for r in borders)
    assert gap<1e-6 and abs(overlap)<1e-6 and outside<1e-6 and border_outside<1e-6
    assert all(r['geometry'].is_simple for r in borders)
    # Each arc is attributed by which region shares it, not a raster mask.
    for arc in arcs:
        midpoint=arc['geometry'].interpolate(.5,normalized=True)
        owners=[r['region_id'] for r in regions if r['geometry'].distance(midpoint)<1e-7]
        arc['region_id']=owners[0] if len(owners)==1 else None
        if len(owners)!=1:
            print('ambiguous arc',arc['arc_id'],list(midpoint.coords),'distances',[(r['region_id'],r['geometry'].distance(midpoint)) for r in regions], 'faces',len(faces),'gap',gap,'overlap',overlap,'borderoutside',border_outside,flush=True)
            raise RuntimeError('Coast arc has ambiguous owner')
    gpkg=WORK/'kyushu_candidate.gpkg'
    if gpkg.exists(): gpkg.unlink()
    layers={'control_points_8192':controls,'source_boundaries_px':source_lines,
            'shared_boundaries_8192':borders,'coastline_references_8192':arcs,'political_regions_8192':regions,
            'warp_mesh_source':[{'triangle_id':i,'geometry':Polygon(t)} for i,t in enumerate(mesh.s)],
            'warp_mesh_target':[{'triangle_id':i,'geometry':Polygon(t)} for i,t in enumerate(mesh.t)]}
    for name,records in layers.items():
        gpd.GeoDataFrame(records,geometry='geometry',crs=None).to_file(gpkg,layer=name,driver='GPKG')
    p2.normalize_gpkg(gpkg)
    # Runtime review layer: canonical coast ID + original point array; selection
    # resolves arclength references, never the click polygon/mask boundary.
    review={'status':'pending_user_review','bounds':bounds,'raster':'warped_raster.png',
            'coastlines':{spec['coastline_id']:list(coast.coords)},
            'boundaries':[{k:v for k,v in r.items() if k!='geometry'}|{'points':list(r['geometry'].coords)} for r in borders],
            'coastline_references':[{k:v for k,v in r.items() if k!='geometry'} for r in arcs],
            'regions':[{'region_id':r['region_id'],'name_ja':r['name_ja'],'polygons':[list(p.exterior.coords) for p in p3.polygon_parts(r['geometry'])]} for r in regions]}
    save_json(WORK/'review_layer.json',review)
    # QA: actual raster, vectors, land and mismatch views use the same viewport.
    base_image=Image.new('RGB',(width,height),'#203e4b')
    draw=ImageDraw.Draw(base_image)
    draw.polygon([tuple(p) for p in xy(coast.coords)],fill='#faf9f5')
    over=base_image.convert('RGBA');over.alpha_composite(Image.fromarray(out))
    d=ImageDraw.Draw(over);d.line([tuple(p) for p in xy(coast.coords)],fill='#ec4784',width=2)
    over.save(QA/'02_actual_warped_image.png')
    vector=base_image.copy();d=ImageDraw.Draw(vector)
    d.line([tuple(p) for p in xy(coast.coords)],fill='#26333a',width=2)
    for r in borders:d.line([tuple(p) for p in xy(r['geometry'].coords)],fill='#332b24',width=3)
    vector.save(QA/'03_boundaries_and_canonical_coast.png')
    d=ImageDraw.Draw(over)
    for r in borders:d.line([tuple(p) for p in xy(r['geometry'].coords)],fill='#00b9cf',width=2)
    over.save(QA/'04_raster_vector_overlay.png')
    colored=base_image.copy();d=ImageDraw.Draw(colored)
    colors=['#dba5ab','#e9cd94','#afd0ad','#c7b4db','#a9cde0','#e1b898','#e0df9b','#b4c4e1','#c3d09b']
    for r,color in zip(regions,colors):
        for poly in p3.polygon_parts(r['geometry']):d.polygon([tuple(p) for p in xy(poly.exterior.coords)],fill=color)
        p=xy(r['geometry'].representative_point().coords)[0]
        from build_coastline_alignment_v2 import font
        d.text(tuple(p),r['name_ja'],fill='#202020',font=font(24),anchor='mm')
    for r in borders:d.line([tuple(p) for p in xy(r['geometry'].coords)],fill='#332b24',width=2)
    colored.save(QA/'05_regions.png')
    traced=normalized.crop((405,730,550,910)).resize((1160,1440)).convert('RGB');d=ImageDraw.Draw(traced)
    for r in source_lines:d.line([((x-405)*8,(y-730)*8) for x,y in r['geometry'].coords],fill='#00b9cf',width=2)
    traced.save(QA/'06_source_trace_overlay.png')
    # Leave-one-out controls measure interpolation sensitivity, not the
    # tautological zero error at fitted control points.
    loo=[]
    for i in range(len(controls)):
        keep=np.arange(len(src))!=i
        held=Mesh(src[keep],dst[keep]).transform([src[i]])[0]
        loo.append(float(np.linalg.norm(held-dst[i])))
    report={**diagnostics,'status':'pending_user_review','scope':spec['scope'],
            'spec_sha256':digest(SPEC),'generator_sha256':digest(Path(__file__)),
            'coordinate_spaces':{'source_boundaries_px':'Source image pixels, x-right y-down, no geographic CRS',
                'layers_8192':'Canonical game-plane units, x-right y-down, NOT EPSG:4326',
                'geographic_crs':'EPSG:4326 (unchanged land source)',
                'game_transform_definition':'tools/build_japan_land_base.py:game_transform_definition',
                'game_transform_module_sha256':digest(ROOT/'tools/build_japan_land_base.py')},
            'source_hash':digest(source),'immutable_hashes_before':frozen,
            'immutable_hashes_after':{p:digest(ROOT/p) for p in frozen},
            'counts':{'controls':len(controls),'shared_boundaries':len(borders),'regions':len(regions),'coast_arcs':len(arcs)},
            'topology':{'gap_area_game_px2':gap,'overlap_area_game_px2':overlap,'outside_area_game_px2':outside,
                        'border_outside_length_game_px':border_outside,'invalid_regions':sum(not r['geometry'].is_valid for r in regions)},
            'coastal_endpoint_review':endpoint_review,
            'leave_one_out_control_error_game_px':{'median':float(np.median(loo)),'p95':float(np.percentile(loo,95)),'max':float(max(loo)),
                'meaning':'Held-out visual correspondence prediction error; not independently surveyed accuracy'},
            'source_trace_distance_to_ink_px':{'median':float(np.median(line_ridge_errors)),'p95':float(np.percentile(line_ridge_errors,95)),'max':float(max(line_ridge_errors))},
            'limitations':['Approximate visual control points; user approval pending.',
                          'Coastline detail differs between raster and Natural Earth; raster coast is not replaced by canonical arcs in registration QA.',
                          'Offshore islands remain unassigned. The image is not evidence of daimyo control at a particular date.',
                          'Distance to ink is a tracing sanity check, not centerline accuracy or historical accuracy.'],
            'libraries':{'numpy':np.__version__,'opencv':cv2.__version__,'shapely':shapely.__version__},
            'outputs_sha256':{p.name:digest(p) for p in [gpkg,WORK/'warped_raster.png',WORK/'review_layer.json']}}
    save_json(WORK/'registration_report.json',report)
    assert report['immutable_hashes_before']==report['immutable_hashes_after']
    print(json.dumps(report['topology']),flush=True)
    print(json.dumps(report['source_trace_distance_to_ink_px']),flush=True)
    return True

if __name__=='__main__':
    if not build(): sys.exit(2)
