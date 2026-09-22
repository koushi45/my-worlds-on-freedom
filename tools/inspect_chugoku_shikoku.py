"""Read-only GIS registration diagnostics for the next review regions."""
from pathlib import Path
from PIL import Image,ImageDraw
import geopandas as gpd
import numpy as np
import build_phase_p2_regional_warp as p2
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'data/work/political/chugoku_shikoku_registration'
OUT.mkdir(parents=True,exist_ok=True)
raw=Image.open(ROOT/'data/work/political/coast_alignment_v2/source_rgba.png').getchannel('A')
raw=Image.eval(raw,lambda x:255-x).convert('RGB')
Image.open(ROOT/'data/sources/political_reference/ryoseikoku_1280.png').crop((250,735,465,855)).resize((1290,720)).save(OUT/'original_province_labels.png')
Image.open(ROOT/'data/sources/political_reference/ryoseikoku_1280.png').crop((320,820,478,940)).resize((948,720)).save(OUT/'original_shikoku_labels.png')
for name,box in [('overview',(480,625,820,825)),('shikoku',(540,710,690,820)),('chugoku',(485,625,750,755)),('west',(490,685,572,746))]:
    factor=5;im=raw.crop(box).resize(((box[2]-box[0])*factor,(box[3]-box[1])*factor));d=ImageDraw.Draw(im)
    for x in range(box[0],box[2],10):
        d.line(((x-box[0])*factor,0,(x-box[0])*factor,im.height),fill='#ebcccc')
        d.text(((x-box[0])*factor+2,1),str(x),fill='red')
    for y in range(box[1],box[3],10):
        d.line((0,(y-box[1])*factor,im.width,(y-box[1])*factor),fill='#ebcccc')
        d.text((1,(y-box[1])*factor+1),str(y),fill='red')
    im.save(OUT/f'{name}_source_grid.png')
    raw.crop(box).resize(((box[2]-box[0])*factor,(box[3]-box[1])*factor)).save(OUT/f'{name}_source.png')
co=gpd.read_file(p2.COAST_GPKG,layer='coastline_8192')
from shapely.geometry import Polygon
for name,lon,lat in [('shikoku',133.5,33.8),('honshu',133,34.8)]:
    print(name,[(r.coastline_id,r.geometry.bounds) for r in co.itertuples() if Polygon(r.geometry).contains(p2.game_point(lon,lat))])
land=gpd.read_file(p2.MASTER_LAND,layer='japan_land')
im=Image.new('RGB',(1500,1100),'#203e4b');d=ImageDraw.Draw(im)
def xy(lon,lat):return ((lon-130.6)*330,(35.7-lat)*330)
for geom in land.geometry:
    for p in geom.geoms:d.polygon([xy(*pt) for pt in p.exterior.coords],fill='#faf9f5')
for lon in np.arange(130.6,135.2,.2):
    x,y=xy(lon,35.7);d.line((x,0,x,1100),fill='#aabbba');d.text((x+2,1),f'{lon:.1f}',fill='red')
for lat in np.arange(32.5,35.8,.2):
    x,y=xy(130.6,lat);d.line((0,y,1500,y),fill='#aabbba');d.text((1,y),f'{lat:.1f}',fill='red')
im.save(OUT/'target_grid.png')
