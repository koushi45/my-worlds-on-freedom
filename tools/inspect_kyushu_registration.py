"""Diagnostic previews only; no canonical data writes."""
from pathlib import Path
from PIL import Image, ImageDraw
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import build_phase_p2_regional_warp as p2
import geopandas as gpd
import numpy as np
from shapely.geometry import Point

out=ROOT/'data/work/political/kyushu_registration'
out.mkdir(parents=True,exist_ok=True)
im=Image.open(ROOT/'data/work/political/coast_alignment_v2/source_rgba.png').getchannel('A')
im=Image.eval(im,lambda x:255-x).convert('RGB')
crop=(350,725,620,935)
im=im.crop(crop).resize((1350,1050))
d=ImageDraw.Draw(im)
for x in range(350,621,10):
    d.line(((x-350)*5,0,(x-350)*5,1050),fill=(220,170,170),width=1)
    d.text(((x-350)*5+2,2),str(x),fill=(220,0,0))
for y in range(730,936,10):
    d.line((0,(y-725)*5,1350,(y-725)*5),fill=(220,170,170),width=1)
    d.text((2,(y-725)*5+2),str(y),fill=(220,0,0))
im.save(out/'source_grid.png')
raw=Image.open(ROOT/'data/work/political/coast_alignment_v2/source_rgba.png').getchannel('A')
raw=Image.eval(raw,lambda x:255-x)
raw.crop((425,735,545,810)).resize((1440,900)).save(out/'north_detail.png')
co=gpd.read_file(p2.COAST_GPKG,layer='coastline_8192')
q=p2.game_point(131,32.5)
co['dist']=co.distance(q)
print(co.nsmallest(5,'dist')[['coastline_id','dist']].to_string(index=False))
print('game corners',[(lon,lat,list(p2.game_point(lon,lat).coords)) for lon,lat in [(129,31),(132,34)]])
geo=gpd.read_file(p2.COAST_GPKG,layer='coastline') if False else gpd.read_file(p2.MASTER_LAND,layer='japan_land')
im=Image.new('RGB',(1200,1400),'#203e4b'); d=ImageDraw.Draw(im)
def xy(lon,lat): return ((lon-129.4)*400,(34.1-lat)*430)
for multi in geo.geometry:
    for poly in multi.geoms:
        if poly.bounds[0]<132.1 and poly.bounds[2]>129.4 and poly.bounds[1]<34.1 and poly.bounds[3]>30.85:
            d.polygon([xy(*pt) for pt in poly.exterior.coords],fill='#faf9f5')
for lon in np.arange(129.4,132.41,.2):
    x,y=xy(lon,34.1);d.line((x,0,x,1400),fill='#91aaaa');d.text((x+2,2),f'{lon:.1f}',fill='red')
for lat in np.arange(31,34.1,.2):
    x,y=xy(129.4,lat);d.line((0,y,1200,y),fill='#91aaaa');d.text((2,y),f'{lat:.1f}',fill='red')
im.save(out/'target_grid.png')
