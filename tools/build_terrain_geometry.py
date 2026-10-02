"""Build terrain with 2x vertical exaggeration and a finer DEM patch around Mount Fuji.

The compact little-endian uint16 grids are shared by rendering and ray picking.
No source DEM, coastline or geographic coordinates are modified.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

ROOT = Path(__file__).resolve().parents[1]

def main():
    source = ROOT / 'assets/map/elevation/elevation_m.png'
    height = np.asarray(Image.open(source), dtype=np.float32)
    axis = np.arange(4097, dtype=np.float32) - 0.5
    output = np.empty((4097,4097), dtype='<u2')
    for start in range(0,4097,128):
        y, x = np.meshgrid(axis[start:start+128], axis, indexing='ij')
        output[start:start+128] = np.rint(map_coordinates(height,[y,x],order=1,mode='nearest'))
    target = ROOT / 'data/derived/elevation/terrain_vertices.bin'
    target.write_bytes(output.tobytes())
    transform = json.loads((ROOT/'data/base/japan_land_manifest.json').read_text(encoding='utf-8'))['game_transform']
    metadata = {
        'source': source.relative_to(ROOT).as_posix(),
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'grid': 4097, 'step_world': 2, 'encoding': 'little-endian uint16 metres',
        'height_scale': transform['uniform_scale_px_per_m'] * 2.0,
        'vertical_exaggeration': 2.0, 'smoothing': 'none; bilinear measured DEM only',
        'far_step_world': 16, 'near_step_world': 2,
        'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
    }
    metadata['fuji_detail'] = build_fuji_detail(transform)
    (target.parent/'terrain_geometry.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(metadata),flush=True)

def build_fuji_detail(transform):
    from pyproj import Transformer
    from build_detail_map import fetch
    projection = Transformer.from_crs('EPSG:4326', transform['projection'], always_xy=True)
    inverse = Transformer.from_crs(transform['projection'], 'EPSG:4326', always_xy=True)
    bx, by, _, _ = transform['projected_scope_bounds_m']
    scale = transform['uniform_scale_px_per_m']
    px, py = projection.transform(138.7274, 35.3606)
    center = np.array([transform['offset_x_px']+(px-bx)*scale,
                       transform['offset_y_px']+transform['content_height_px']-(py-by)*scale])
    origin = np.floor(center/16)*16-64
    step = 0.25
    axis = np.arange(513)*step
    xx, yy = np.meshgrid(origin[0]+axis, origin[1]+axis)
    lon, lat = inverse.transform(bx+(xx-transform['offset_x_px'])/scale,
        by+(transform['content_height_px']-yy+transform['offset_y_px'])/scale)
    tx = (lon+180)/360*2048
    ty = (1-np.arcsinh(np.tan(np.deg2rad(lat)))/np.pi)/2*2048
    minx, maxx = int(np.floor(tx.min())), int(np.floor(tx.max()))+1
    miny, maxy = int(np.floor(ty.min())), int(np.floor(ty.max()))+1
    mosaic = np.zeros(((maxy-miny+1)*256,(maxx-minx+1)*256), np.float32)
    sources = []
    for x in range(minx,maxx+1):
        for y in range(miny,maxy+1):
            record = fetch((x,y))
            sources.append(record)
            rgb = np.asarray(Image.open(ROOT/record['file']).convert('RGB'),dtype=np.float32)
            mosaic[(y-miny)*256:(y-miny+1)*256,(x-minx)*256:(x-minx+1)*256] = rgb[:,:,0]*256+rgb[:,:,1]+rgb[:,:,2]/256-32768
    heights = map_coordinates(mosaic,[(ty-miny)*256-.5,(tx-minx)*256-.5],order=1,mode='nearest')
    assert np.isfinite(heights).all() and 3500 < heights.max() < 4000 and heights.min() >= 0
    path = ROOT/'data/derived/elevation/fuji_vertices.bin'
    path.write_bytes(np.rint(heights).astype('<u2').tobytes())
    return dict(file=path.relative_to(ROOT).as_posix(), origin=origin.tolist(), span=128,
                grid=513, step_world=step, sample_spacing_m=step/scale,
                source='Mapzen / AWS Terrain Tiles (Terrarium, zoom 11)', sources=sources,
                smoothing='none; bilinear measured DEM only', maximum_elevation_m=float(heights.max()),
                sha256=hashlib.sha256(path.read_bytes()).hexdigest())

if __name__ == '__main__': main()
