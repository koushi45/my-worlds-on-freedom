"""Reproducible real DEM overlay; never modifies the approved land or Phase E tiles."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import urllib.request
import numpy as np
from PIL import Image
from pyproj import Transformer
from scipy.ndimage import map_coordinates, gaussian_filter, median_filter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data/derived/elevation'
ASSETS = ROOT / 'assets/map/elevation'
SOURCE = ROOT / 'data/sources/elevation/terrarium'
SIZE = 4096
ZOOM = 8

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def fetch(tile):
    x, y = tile
    path = SOURCE / str(ZOOM) / str(x) / f'{y}.png'
    url = f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{ZOOM}/{x}/{y}.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        with urllib.request.urlopen(url, timeout=60) as response:
            content = response.read()
        temp = path.with_suffix('.tmp')
        temp.write_bytes(content)
        with Image.open(temp) as im:
            assert im.size == (256, 256)
            im.verify()
        temp.replace(path)
    return {'file': str(path.relative_to(ROOT)), 'url': url, 'sha256': sha(path)}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    (SOURCE.parent/'.gdignore').touch()
    master = json.loads((ROOT/'data/base/japan_land_master_manifest.json').read_text())
    assert sha(ROOT/master['canonical_file']) == master['canonical_sha256']
    definition = json.loads((ROOT/'data/base/japan_land_manifest.json').read_text())['game_transform']
    scale = definition['uniform_scale_px_per_m']
    bx, by, _, _ = definition['projected_scope_bounds_m']
    inverse = Transformer.from_crs(definition['projection'], 'EPSG:4326', always_xy=True)
    axis = (np.arange(SIZE, dtype=np.float32)+0.5)*8192/SIZE
    xx, yy = np.meshgrid(axis, axis)
    lon, lat = inverse.transform(bx+(xx-definition['offset_x_px'])/scale,
        by+(definition['content_height_px']-yy+definition['offset_y_px'])/scale)
    tx = (lon+180)/360*(2**ZOOM)
    ty = (1-np.arcsinh(np.tan(np.deg2rad(lat)))/np.pi)/2*(2**ZOOM)
    land = np.array(Image.open(ROOT/'data/derived/land_masks/land_mask_8192.png').resize((SIZE,SIZE), Image.Resampling.BOX))>0
    # Only source tiles touching the approved land, plus neighbors for interpolation.
    cells = set(zip(np.floor(tx[land]).astype(int), np.floor(ty[land]).astype(int)))
    cells = sorted({(x+dx,y+dy) for x,y in cells for dx in (-1,0,1) for dy in (-1,0,1)})
    print(f'Fetching/caching {len(cells)} DEM tiles', flush=True)
    with ThreadPoolExecutor(max_workers=10) as pool:
        sources = list(pool.map(fetch, cells))
    minx, maxx = min(x for x,y in cells), max(x for x,y in cells)
    miny, maxy = min(y for x,y in cells), max(y for x,y in cells)
    mosaic = np.zeros(((maxy-miny+1)*256,(maxx-minx+1)*256), np.float32)
    repairs = []
    for (x,y), record in zip(cells,sources):
        rgb = np.array(Image.open(ROOT/record['file']).convert('RGB'), dtype=np.float32)
        decoded = rgb[:,:,0]*256+rgb[:,:,1]+rgb[:,:,2]/256-32768
        bad = (decoded>9000) | (decoded < -12000)
        if bad.any():
            replacement = median_filter(decoded,size=3)
            for row,col in zip(*np.where(bad)):
                repairs.append({'source':record['file'],'pixel':[int(col),int(row)],
                    'original_m':float(decoded[row,col]),'replacement_m':float(replacement[row,col]),
                    'reason':'Physically implausible DEM outlier; local 3x3 median in derived mosaic only.'})
            decoded[bad] = replacement[bad]
        mosaic[(y-miny)*256:(y-miny+1)*256,(x-minx)*256:(x-minx+1)*256] = decoded
    height = map_coordinates(mosaic, [(ty-miny)*256-0.5,(tx-minx)*256-0.5], order=1, mode='nearest')
    height = np.maximum(height,0).astype(np.float32)
    height[~land] = 0
    assert np.isfinite(height).all() and height.max()<4000, 'Japan DEM failed elevation range validation'
    Image.fromarray(np.rint(height).astype(np.uint16)).save(ASSETS/'elevation_m.png')
    # Common 16-world-unit grid. Gentle displacement preserves a one-to-one map/pick transform.
    display = gaussian_filter(height, 5.0)
    coords = np.linspace(-0.5,SIZE-0.5,513)
    gx, gy = np.meshgrid(coords,coords)
    nodes = np.rint(map_coordinates(display,[gy,gx],order=1,mode='nearest')).astype(np.uint16)
    max_dy = np.abs(np.diff(nodes.astype(float),axis=0)).max()/16
    exaggeration = min(0.028, 0.60/max(max_dy,0.001))
    rgb = np.zeros((513,513,3),np.uint8)
    rgb[:,:,0] = nodes//256
    rgb[:,:,1] = nodes%256
    Image.fromarray(rgb).save(ASSETS/'mesh_height.png')
    # Hillshade uses actual metre spacing, independent of display exaggeration.
    softened = gaussian_filter(height,0.65)
    dy, dx = np.gradient(softened, 8192/SIZE/scale)
    light = (0.55*dx+0.65*dy+0.75)/np.sqrt(dx*dx+dy*dy+1)
    shade = np.clip(0.64+light*0.48,0.43,1.15)
    stops = [0,100,300,700,1200,1800,2500,3800]
    colors = np.array([[190,204,153],[168,192,130],[136,169,111],[113,145,99],
                       [141,153,113],[165,158,132],[189,183,167],[238,233,219]])
    color = np.stack([np.interp(height,stops,colors[:,c]) for c in range(3)],axis=-1)
    color = np.clip(color*shade[:,:,None],0,255).astype(np.uint8)
    relief = Image.fromarray(color)
    tiles = json.loads((ROOT/'data/derived/map_images/map_images_manifest.json').read_text())['tiles']
    outputs = {}
    for tile in tiles:
        bounds = tuple(int(v*SIZE/8192) for v in tile['global_viewport'])
        image = relief.crop(bounds).resize(tuple(tile['output_size']),Image.Resampling.BILINEAR).convert('RGBA')
        coverage = Image.open(ROOT/tile['files']['land_coverage'])
        image.putalpha(coverage)
        path = ASSETS/(tile['tile_id']+'.png')
        image.save(path)
        outputs[tile['tile_id']] = {'file':str(path.relative_to(ROOT)), 'sha256':sha(path)}
    for name in ('attribution.md','formats.md'):
        path = OUT/name
        if not path.exists():
            with urllib.request.urlopen('https://raw.githubusercontent.com/tilezen/joerd/master/docs/'+name, timeout=60) as r:
                path.write_bytes(r.read())
    manifest = {'schema_version':1,'source':'Mapzen / AWS Terrain Tiles (Terrarium, zoom 8)',
        'accessed':'2026-09-11','source_registry':'https://registry.opendata.aws/terrain-tiles/',
        'attribution':'Mapzen; SRTM and GMTED2010 courtesy of USGS; ETOPO1 courtesy of NOAA.',
        'modifications':'LCC reprojection; approved polygon clipping; hillshade and hypsometric tint; smoothed display mesh.',
        'source_master_sha256':master['canonical_sha256'],'game_transform':definition,
        'height_size':SIZE,'height_units':'metres','mesh_step':16,'mesh_encoding':'R*256+G metres',
        'display_height_scale':exaggeration,'max_display_y_derivative':float(max_dy*exaggeration),
        'maximum_sampled_elevation_m':float(height.max()),'source_outlier_repairs':repairs,'sources':sources,'tiles':outputs,
        'assets':{name:sha(ASSETS/name) for name in ('elevation_m.png','mesh_height.png')}}
    (OUT/'elevation_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Created {len(outputs)} relief tiles; peak {height.max():.0f} m; displacement {exaggeration:.5f}',flush=True)

if __name__ == '__main__':
    main()
