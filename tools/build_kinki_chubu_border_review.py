"""Regional image registration and ink-traced line review, never inferred areas.

Unlike the approved-region publisher this intentionally does not assign faces
until dense inland junctions and neighbouring-region joins have been reviewed.
"""
import json
from pathlib import Path
import geopandas as gpd
import numpy as np
import cv2
from PIL import Image,ImageDraw
from shapely.geometry import Point,LineString,Polygon,box
from shapely.ops import unary_union,substring
import build_kinki_chubu_registration as registration
from build_coastline_alignment_v2 import font

ROOT=registration.ROOT
WORK=registration.WORK
core=registration.core

def build(name):
    full=json.loads(registration.SPEC.read_text(encoding='utf-8'))
    spec_path=WORK/'chubu_spec.json' if name=='chubu' else registration.SPEC
    spec=json.loads(spec_path.read_text(encoding='utf-8')) if name=='chubu' else full['regions'][name]
    out=WORK/name;qa=out/'qa';qa.mkdir(parents=True,exist_ok=True)
    frozen_paths=[core.p2.MASTER_LAND,core.p2.COAST_GPKG,ROOT/full['source'],ROOT/'data/derived/political/approved_western/political_registry.json']
    frozen={str(p.relative_to(ROOT)):core.digest(p) for p in frozen_paths}
    coast=gpd.read_file(core.p2.COAST_GPKG,layer='coastline_8192').set_index('coastline_id').loc[spec['coastline_id']].geometry
    _,land=core.p3.canonical_land_8192()
    mesh,src,dst=registration.create_mesh(spec,coast)
    bmin=dst.min(axis=0)-50;bmax=dst.max(axis=0)+50;bounds=np.r_[bmin,bmax].tolist()
    scale=min(1.4,1800/(bmax-bmin).max())
    alpha=np.array(Image.open(ROOT/full['source']).getchannel('A'))
    if 'source_offset' in full:
        ox,oy=full['source_offset'];width,height=full['coordinate_canvas_size']
        alpha=np.pad(alpha,((oy,height-oy-alpha.shape[0]),(ox,width-ox-alpha.shape[1])),constant_values=0)
    ink_distance=cv2.distanceTransform((alpha<128).astype(np.uint8),cv2.DIST_L2,cv2.DIST_MASK_PRECISE)
    warped,_,_=registration.warp(alpha,mesh,bounds,scale)
    Image.fromarray(warped).save(out/'warped_raster.png')
    core.save_json(out/'raster_georeference.json',{'bounds_8192':bounds,'pixels_per_game_unit':scale,'pixel_origin':'integer pixel centres'})
    source_rows=[];raw_rows=[];rows=[];issues=[];trace_gaps=[];anchor_reviews=[]
    def anchor(p):
        x,y=p;ix,iy=int(round(x)),int(round(y))
        ys,xs=np.nonzero(alpha[max(0,iy-5):iy+6,max(0,ix-5):ix+6]>=200)
        if not len(xs):return p
        candidates=np.c_[xs+max(0,ix-5),ys+max(0,iy-5)]
        distances=np.linalg.norm(candidates-np.array(p),axis=1)
        best=int(distances.argmin())
        if distances[best]>4:return p
        q=candidates[best].tolist()
        if distances[best]>.75:anchor_reviews.append({'original':p,'ink_point':q,'distance_input_px':float(distances[best]),'status':'pending'})
        return q
    snapped_nodes={id:anchor(p) for id,p in spec['nodes'].items()}
    for a,b,start,end,middle in spec['boundaries']:
        points=core.assisted_trace(alpha,[snapped_nodes[start]]+[anchor(p) for p in middle]+[snapped_nodes[end]])
        record={'boundary_id':f'{name}:{a}:{b}:{start}:{end}','region_a':a,'region_b':b,
                'certainty':'probable','review_status':'pending','trace_method':'assisted','start_node':start,'end_node':end}
        # Never display the searcher's straight fallback through blank paper.
        samples=np.array(core.resample(points,.25));indices=np.rint(samples).astype(int)
        distance=ink_distance[indices[:,1],indices[:,0]];supported=distance<=.75
        breaks=np.flatnonzero(np.diff(np.r_[False,supported,False])).reshape(-1,2)
        if not supported.all():trace_gaps.append({'boundary_id':record['boundary_id'],'unsupported_sample_count':int((~supported).sum()),'total_samples':len(samples),'status':'unconfirmed','action':'no invented connector; refine trace anchors'})
        for run,(lo,hi) in enumerate(breaks):
            if hi-lo<2:continue
            line=LineString(samples[lo:hi])
            if line.length<.75:continue
            r={**record,'boundary_id':record['boundary_id']+f':run{run}','certainty':'unconfirmed' if not supported.all() else 'probable'}
            raw=mesh.line(line.coords)
            source_rows.append({**r,'geometry':line});raw_rows.append({**r,'geometry':raw})
            parts=[p for p in core.p3.line_parts(raw.intersection(land)) if p.length>1e-6]
            removed=raw.length-sum(p.length for p in parts)
            unresolved=len(parts)!=1 or removed>1e-6
            if unresolved:issues.append({'boundary_id':r['boundary_id'],'land_runs':len(parts),'sea_length_game_px':removed,'status':'unconfirmed_endpoint','action':'review source-to-coast correspondence; do not fill or snap all vertices'})
            for i,p in enumerate(parts):rows.append({**r,'boundary_id':r['boundary_id']+f':part{i}',
                                                   'certainty':'unconfirmed' if unresolved else r['certainty'],'geometry':p})
    gpkg=out/'border_review_candidate.gpkg'
    if gpkg.exists():gpkg.unlink()
    layers={'source_boundaries_px':source_rows,'raw_warped_boundaries_8192':raw_rows,'display_boundaries_8192':rows,
            'canonical_coastline_8192':[{'coastline_id':spec['coastline_id'],'geometry':coast}],
            'control_points_8192':[{'control_id':p[0],'source_x':s[0],'source_y':s[1],'target_x':t[0],'target_y':t[1],'review_status':'pending','geometry':Point(t)} for p,s,t in zip(spec['controls'],src,dst)],
            'warp_mesh_source':[{'triangle_id':i,'geometry':Polygon(t)} for i,t in enumerate(mesh.s)],
            'warp_mesh_target':[{'triangle_id':i,'geometry':Polygon(t)} for i,t in enumerate(mesh.t)]}
    for key,data in layers.items():gpd.GeoDataFrame(data,geometry='geometry').to_file(gpkg,layer=key,driver='GPKG')
    core.p2.normalize_gpkg(gpkg)
    def xy(points):return [tuple(p) for p in (np.array(points)-bounds[:2])*scale]
    base=Image.new('RGB',(warped.shape[1],warped.shape[0]),'#203e4b');d=ImageDraw.Draw(base)
    viewport=box(*bounds)
    for p in core.p3.polygon_parts(land.intersection(viewport)):
        d.polygon(xy(p.exterior.coords),fill='#faf9f5')
        for hole in p.interiors:d.polygon(xy(hole.coords),fill='#203e4b')
    image=base.convert('RGBA');image.alpha_composite(Image.fromarray(warped));d=ImageDraw.Draw(image)
    visible_coast=core.p3.line_parts(coast.intersection(viewport))
    for line in visible_coast:d.line(xy(line.coords),fill='#ec4784',width=2)
    image.save(qa/'01_actual_warp.png')
    for row in rows:d.line(xy(row['geometry'].coords),fill='#00b9cf',width=2)
    image.save(qa/'02_raster_vector_overlay.png')
    d=ImageDraw.Draw(base)
    for line in visible_coast:d.line(xy(line.coords),fill='#42382e',width=2)
    for row in rows:d.line(xy(row['geometry'].coords),fill='#42382e',width=2)
    base.save(qa/'03_boundaries.png')
    for id,point in spec['seeds'].items():
        target=mesh.transform([point])[0];d.text(xy([target])[0],spec['names'][id],font=font(17),anchor='mm',fill='#333333')
    base.save(qa/'04_names_unconfirmed.png')
    crop=spec['crop'];factor=4
    preview=Image.fromarray(255-alpha).convert('RGB').crop(crop).resize(((crop[2]-crop[0])*factor,(crop[3]-crop[1])*factor));d=ImageDraw.Draw(preview)
    for row in source_rows:d.line([((x-crop[0])*factor,(y-crop[1])*factor) for x,y in row['geometry'].coords],fill='#00b9cf',width=2)
    preview.save(qa/'05_source_trace.png')
    core.save_json(out/'review_layer.json',{'status':'pending_user_review','scope':name,'bounds':bounds,
        'coastlines':{spec['coastline_id']:list(coast.coords)},
        'boundaries':[{k:v for k,v in r.items() if k!='geometry'}|{'points':list(r['geometry'].coords)} for r in rows],
        'regions':[],'coastline_references':[],
        'region_labels':[{'region_id':id,'name_ja':spec['names'][id],'point':mesh.transform([p])[0].tolist()} for id,p in spec['seeds'].items()],
        'pending':['face construction','coast interval ownership','cross-region seam reconciliation','dense junction review','offshore ownership']})
    assert frozen=={str(p.relative_to(ROOT)):core.digest(p) for p in frozen_paths}
    report={'status':'pending_user_review','scope':name,'control_count':len(src),'source_border_count':len(source_rows),'display_parts':len(rows),
            'input_hashes_unchanged':frozen,'spec_sha256':core.digest(spec_path),'generator_sha256':core.digest(Path(__file__)),
            'folded_triangles':int((mesh.jac<=0).sum()),'anchor_reviews':anchor_reviews,'unconfirmed_endpoints':issues,'unsupported_trace_intervals':trace_gaps,
            'coordinate_spaces':{'source':'image pixel x right, y down','target':'canonical local 8192 game coordinates; not EPSG:4326'},
            'not_completed':['Closed country polygons and coast interval ownership are NOT yet validated.','Not production-ready or user-approved.'],
            'outputs_sha256':{p.name:core.digest(p) for p in [gpkg,out/'review_layer.json',out/'warped_raster.png']}}
    core.save_json(out/'registration_report.json',report)
    print(name,len(rows),'line parts;',len(issues),'endpoint issues',flush=True)

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--region',choices=['kinki','chubu','all'],default='all')
    args=parser.parse_args()
    for name in ['kinki','chubu'] if args.region=='all' else [args.region]:build(name)
