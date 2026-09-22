"""4 texels/world-unit display tiles; exact land clipped to the existing terrain mesh.

Display-only Terrarium z11. Neither routing DEM, map coordinates nor displacement
mesh changes. Adjacent tiles sample identical global coordinates with 4px gutters.
"""
import hashlib
import json
import math
import time
import urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import numpy as np
from PIL import Image
from pyproj import Transformer
from scipy.ndimage import map_coordinates, gaussian_filter, median_filter
from shapely.geometry import shape, box, Polygon
from shapely.ops import transform, unary_union
from shapely import constrained_delaunay_triangles

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/map/detail'
META=ROOT/'data/derived/detail_map'
CACHE=ROOT/'data/sources/elevation/terrarium/11'
SPAN=256; DENSITY=4; GUTTER=4; SIZE=SPAN*DENSITY+2*GUTTER; ZOOM=11
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,d): p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,separators=(',',':'),ensure_ascii=False),encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def parts(g,kind):
    if g.is_empty: return []
    if g.geom_type==kind: return [g]
    return [p for c in getattr(g,'geoms',[]) for p in parts(c,kind)]

def fetch(cell):
    x,y=cell;p=CACHE/str(x)/f'{y}.png'
    url=f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{ZOOM}/{x}/{y}.png'
    if not p.exists():
        p.parent.mkdir(parents=True,exist_ok=True)
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url,timeout=30) as r: content=r.read()
                tmp=p.with_suffix('.tmp');tmp.write_bytes(content)
                with Image.open(tmp) as im: assert im.size==(256,256);im.verify()
                tmp.replace(p);break
            except Exception:
                if attempt==2: raise
                time.sleep(attempt+1)
    return dict(file=p.relative_to(ROOT).as_posix(),url=url,sha256=sha(p))

def main():
    OUT.mkdir(parents=True,exist_ok=True);META.mkdir(parents=True,exist_ok=True)
    m=read('data/base/japan_land_manifest.json')['game_transform']
    projection=Transformer.from_crs('EPSG:4326',m['projection'],always_xy=True)
    inverse=Transformer.from_crs(m['projection'],'EPSG:4326',always_xy=True)
    scale=m['uniform_scale_px_per_m'];bx,by,_,_=m['projected_scope_bounds_m']
    def xy(lon,lat):
        x,y=projection.transform(lon,lat)
        return m['offset_x_px']+(x-bx)*scale,m['offset_y_px']+m['content_height_px']-(y-by)*scale
    land=unary_union([transform(xy,shape(f['geometry'])) for f in read('data/base/japan_land.geojson')['features']])
    def source_coords(x,y):
        lon,lat=inverse.transform(bx+(x-m['offset_x_px'])/scale,by+(m['content_height_px']-y+m['offset_y_px'])/scale)
        return (lon+180)/360*2**ZOOM,(1-np.arcsinh(np.tan(np.deg2rad(lat)))/np.pi)/2*2**ZOOM
    tiles=[];cells=set()
    for row in range(32):
        for col in range(32):
            x,y=col*SPAN,row*SPAN;bounds=[x,y,x+SPAN,y+SPAN]
            clip=land.intersection(box(*bounds))
            if clip.area<1e-7: continue
            xx,yy=np.meshgrid(np.linspace(x-2,x+SPAN+2,17),np.linspace(y-2,y+SPAN+2,17))
            tx,ty=source_coords(xx,yy)
            sb=[math.floor(tx.min())-1,math.floor(ty.min())-1,math.floor(tx.max())+1,math.floor(ty.max())+1]
            cells.update((a,b) for a in range(sb[0],sb[2]+1) for b in range(sb[1],sb[3]+1))
            tiles.append(dict(tile_id=f'detail-r{row:02}-c{col:02}',global_viewport=bounds,source_bounds=sb))
    print(f'{len(tiles)} land tiles; fetching {len(cells)} z11 DEM tiles',flush=True)
    sources=[]
    with ThreadPoolExecutor(max_workers=16) as pool:
        tasks=[pool.submit(fetch,c) for c in sorted(cells)]
        for i,task in enumerate(as_completed(tasks)):
            sources.append(task.result())
            if i%100==0: print(f'DEM {i+1}/{len(cells)}',flush=True)
    def render(tile):
        x,y,_,_=tile['global_viewport'];sx,sy,ex,ey=tile.pop('source_bounds')
        repairs=[]
        mosaic=np.zeros(((ey-sy+1)*256,(ex-sx+1)*256),np.float32)
        for a in range(sx,ex+1):
            for b in range(sy,ey+1):
                rgb=np.asarray(Image.open(CACHE/str(a)/f'{b}.png').convert('RGB'),dtype=np.float32)
                h=rgb[:,:,0]*256+rgb[:,:,1]+rgb[:,:,2]/256-32768
                bad=(h>4500)|(h< -12000)
                if bad.any():
                    replacement=median_filter(h,size=3)
                    for row,col in zip(*np.where(bad)):
                        repairs.append(dict(source=f'{ZOOM}/{a}/{b}',pixel=[int(col),int(row)],original_m=float(h[row,col]),replacement_m=float(replacement[row,col]),reason='Implausible Japanese elevation sample; 3x3 median in display mosaic only.'))
                    h[bad]=replacement[bad]
                mosaic[(b-sy)*256:(b-sy+1)*256,(a-sx)*256:(a-sx+1)*256]=h
        axis=(np.arange(SIZE+8,dtype=np.float64)-GUTTER-4+.5)/DENSITY
        xx,yy=np.meshgrid(x+axis,y+axis);tx,ty=source_coords(xx,yy)
        height=np.maximum(0,map_coordinates(mosaic,[(ty-sy)*256-.5,(tx-sx)*256-.5],order=1,mode='nearest'))
        assert np.isfinite(height).all() and height.max()<4500, (tile['tile_id'],height.max())
        dy,dx=np.gradient(gaussian_filter(height,.65),1/DENSITY/scale)
        shade=np.clip(.64+(.55*dx+.65*dy+.75)/np.sqrt(dx*dx+dy*dy+1)*.48,.43,1.15)
        stops=[0,100,300,700,1200,1800,2500,3800]
        colors=np.array([[190,204,153],[168,192,130],[136,169,111],[113,145,99],[141,153,113],[165,158,132],[189,183,167],[238,233,219]])
        color=np.stack([np.interp(height,stops,colors[:,c]) for c in range(3)],axis=-1)
        image=np.clip(color*shade[:,:,None],0,255).astype(np.uint8)[4:-4,4:-4]
        path=OUT/(tile['tile_id']+'.png');Image.fromarray(image).save(path)
        # Identical source triangle planes to elevation_surface.mesh_for, then
        # intersect with the original polygon. Holes and islands survive clipping.
        clipped=land.intersection(box(*tile['global_viewport']))
        vertices=[];indices=[];lookup={}
        def add_tri(points):
            for p in points:
                key=tuple(round(float(v),9) for v in p)
                if key not in lookup: lookup[key]=len(vertices);vertices.append(key)
                indices.append(lookup[key])
        for cy in range(y,y+SPAN,16):
            for cx in range(x,x+SPAN,16):
                for corners in [[(cx,cy),(cx+16,cy),(cx,cy+16)],[(cx+16,cy),(cx+16,cy+16),(cx,cy+16)]]:
                    tri=Polygon(corners)
                    if clipped.covers(tri): add_tri(corners)
                    elif clipped.intersects(tri):
                        for polygon in parts(clipped.intersection(tri),'Polygon'):
                            for t in constrained_delaunay_triangles(polygon).geoms:
                                if t.area>1e-10: add_tri(list(t.exterior.coords)[:3])
        coasts=[list(map(list,l.coords)) for l in parts(land.boundary.intersection(box(*tile['global_viewport'])),'LineString')]
        geometry=OUT/(tile['tile_id']+'.json')
        write(geometry,dict(vertices=vertices,indices=indices,coasts=coasts))
        tile.update(files=dict(relief=path.relative_to(ROOT).as_posix(),geometry=geometry.relative_to(ROOT).as_posix()),
                    output_size=[SIZE,SIZE],gutter=GUTTER,density=DENSITY,land_area=clipped.area,
                    hashes=dict(relief=sha(path),geometry=sha(geometry)),source_outlier_repairs=repairs)
        return tile
    finished=[]
    with ThreadPoolExecutor(max_workers=2) as pool:
        for i,t in enumerate(pool.map(render,tiles)):
            finished.append(t)
            if i%10==0: print(f'Rendered {i+1}/{len(tiles)}',flush=True)
    inputs=['data/base/japan_land.geojson','data/base/japan_land_manifest.json','assets/map/elevation/mesh_height.png']
    write(META/'manifest.json',dict(schema_version=1,world_size=[8192,8192],maximum_zoom=4,density=DENSITY,tile_span=SPAN,
        source_zoom=ZOOM,source='AWS Terrain Tiles / Mapzen Terrarium',tiles=finished,sources=sorted(sources,key=lambda s:s['file']),
        input_hashes={p:sha(ROOT/p) for p in inputs},note='Display only; original land geometry and terrain displacement preserved. Native DEM resolution varies; 4 texels/world-unit does not imply surveyed 56m accuracy.'))
    print('Detail map complete',flush=True)

if __name__=='__main__': main()
