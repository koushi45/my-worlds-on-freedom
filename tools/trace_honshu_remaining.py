"""Trace the supplied eastern Honshu image, without adopting its coastline."""
import json
from pathlib import Path
import cv2
import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union, nearest_points
from trace_kinki_handdrawn import thin, trace
from prepare_kinki_editor import ROOT, digest

OUT=ROOT/'data/work/political/honshu_remaining'
SOURCE=OUT/'source.png'
UPLOAD=Path('C:/Users/nanoa/AppData/Local/Temp/codex-clipboard-28784781-3c62-4708-98b5-f2be8228212a.png')


def save(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def parts(g):
    if g.geom_type=='LineString':return [] if g.is_empty else [g]
    return [p for child in getattr(g,'geoms',[]) for p in parts(child)]


def run():
    OUT.mkdir(parents=True,exist_ok=True)
    if not SOURCE.exists():SOURCE.write_bytes(UPLOAD.read_bytes())
    image=cv2.imread(str(SOURCE));h,w=image.shape[:2]
    seed=json.loads((ROOT/'data/derived/editor/kinki/editor_draft.json').read_text(encoding='utf-8'))
    locked=json.loads((ROOT/'data/derived/political/approved_western/political_registry.json').read_text(encoding='utf-8'))
    coast=LineString(next(iter(seed['coastlines'].values())))
    rgb=image.astype(np.int16)
    sea=(rgb[:,:,0]>rgb[:,:,2]+20)&(rgb[:,:,1]>rgb[:,:,2]+10)&(rgb[:,:,2]<90)
    shoreline=(cv2.dilate(sea.astype(np.uint8),np.ones((3,3),np.uint8))!=sea)&(~sea)
    shoreline[:5]=False;shoreline[-5:]=False;shoreline[:,:5]=False;shoreline[:,-5:]=False
    y,x=np.where(shoreline);samples=np.c_[x,y][::4].astype(float)
    scale=2.15;offset=np.array([3870.,2300.])
    cached=json.loads((OUT/'trace_report.json').read_text(encoding='utf-8')) if (OUT/'trace_report.json').exists() else {}
    if cached.get('source_sha256')==digest(SOURCE):
        scale=cached['scale'];offset=np.array(cached['offset'])
    # Position the reference on the existing base; never replace coast data.
    for iteration in range(0 if cached.get('source_sha256')==digest(SOURCE) else 40):
        world=samples*scale+offset;pts=shapely.points(world)
        nearest=shapely.get_coordinates(shapely.line_interpolate_point(coast,shapely.line_locate_point(coast,pts)))
        distances=np.linalg.norm(nearest-world,axis=1)
        keep=distances<max(5.,60.-iteration*2)
        a=samples[keep];b=nearest[keep];ac=a-a.mean(axis=0);bc=b-b.mean(axis=0)
        scale=float((ac*bc).sum()/(ac*ac).sum());offset=b.mean(axis=0)-a.mean(axis=0)*scale
    residual=shapely.distance(shapely.points(samples*scale+offset),coast)/scale
    print('Registration',scale,offset,'mainland inliers',np.percentile(residual[residual<5],[50,90]),flush=True)
    land_distance=cv2.distanceTransform((~sea).astype(np.uint8),cv2.DIST_L2,5)
    ink=(np.max(image,axis=2)<145)&(land_distance>9)&(~sea)
    ink[:3]=False;ink[-3:]=False;ink[:,:3]=False;ink[:,-3:]=False
    # Small pale labels and disconnected speckles are not province lines.
    count,labels,stats,_=cv2.connectedComponentsWithStats(ink.astype(np.uint8),8)
    keep_ids=[i for i in range(1,count) if stats[i,cv2.CC_STAT_AREA]>=35]
    mask=np.isin(labels,keep_ids)
    strokes=trace(thin(mask))
    gradient_x=cv2.Sobel(land_distance,cv2.CV_32F,1,0,ksize=3)
    gradient_y=cv2.Sobel(land_distance,cv2.CV_32F,0,1,ksize=3)
    protected=unary_union([Polygon(p) for r in locked['regions'] for p in r['polygons']])
    new=[];rejected_coastal=[]
    for stroke in strokes:
        if stroke.length<8:continue
        samples_px=np.array([stroke.interpolate(s).coords[0] for s in np.arange(0,stroke.length,2)])
        pixel=np.rint(samples_px).astype(int)
        distances=land_distance[pixel[:,1],pixel[:,0]]
        if np.max(distances)<25:
            directions=np.diff(samples_px,axis=0)
            normals=np.c_[gradient_x[pixel[:-1,1],pixel[:-1,0]],gradient_y[pixel[:-1,1],pixel[:-1,0]]]
            alignment=np.abs(np.sum(directions*normals,axis=1))/(np.linalg.norm(directions,axis=1)*np.linalg.norm(normals,axis=1)+1e-6)
            if float(np.mean(alignment))<.55:
                rejected_coastal.append(list(stroke.coords))
                continue
        coords=np.array(stroke.coords)*scale+offset
        line=LineString(coords)
        if line.intersection(protected).length>.01:continue
        new.append({'boundary_id':f'honshu:image:{len(new):03d}','points':coords.tolist(),
            'trace_method':'provided_image_centerline','certainty':'unconfirmed','review_status':'pending',
            'review_reason':'Blurry source; junctions, loops, and coastal endpoints require review.'})
    # Retain the preceding hand-drawn Kinki lines west of this reference.
    # Inside the new reference, use its lines only, avoiding double boundaries.
    image_bounds=[*offset.tolist(),*(offset+np.array([w,h])*scale).tolist()]
    frame=box(*image_bounds)
    retained=[]
    for b in seed['boundaries']:
        for i,line in enumerate(parts(LineString(b['points']).difference(frame))):
            if line.length<2:continue
            retained.append({**b,'boundary_id':b['boundary_id']+f':retained:{i}',
                'points':list(line.coords),'review_status':'pending'})
    bounds=[min(seed['bounds'][0],image_bounds[0]),min(seed['bounds'][1],image_bounds[1]),
            max(seed['bounds'][2],image_bounds[2]),max(seed['bounds'][3],image_bounds[3])]
    data={**seed,'scope':'honshu','display_name':'本州（近畿以東）','bounds':bounds,'regions':[],
        'boundaries':retained+new,'source_draft_sha256':digest(SOURCE),'legacy_reference_hashes':[],
        'handdrawn_source':{'sha256':digest(SOURCE),'scale':scale,'offset':offset.tolist()},
        'raster_georeference':{'bounds_8192':image_bounds,'pixels_per_game_unit':1/scale,'size':[w,h]},
        'pending':['Unconfirmed image traces only; do not infer country ownership or close ambiguous loops.'],
        'reference_hashes':{p:digest(ROOT/p) for p in seed['reference_hashes']}}
    save(OUT/'editor_draft.json',data)
    overlay=image.copy()
    for b in new:
        pixels=np.rint((np.array(b['points'])-offset)/scale).astype(np.int32)
        cv2.polylines(overlay,[pixels],False,(210,185,0),1,cv2.LINE_AA)
    cv2.imwrite(str(OUT/'trace_overlay.png'),overlay)
    cv2.imwrite(str(OUT/'stroke_mask.png'),mask.astype(np.uint8)*255)
    save(OUT/'trace_report.json',{'status':'unconfirmed','scale':scale,'offset':offset.tolist(),
        'new_lines':len(new),'retained_kinki_lines':len(retained),'source_sha256':digest(SOURCE),
        'excluded_coastal_fragments':rejected_coastal,
        'coastline_policy':'Canonical coast unchanged; source coast excluded from tracing',
        'mainland_alignment_inlier_px':np.percentile(residual[residual<5],[50,90]).tolist()})
    print('New lines',len(new),'retained',len(retained),flush=True)


if __name__=='__main__':run()
