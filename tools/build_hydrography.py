"""Generate independent river/lake vectors from GSI Global Map Japan v2."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import zipfile
import numpy as np
import pyogrio
from pyproj import Transformer
from shapely import make_valid, constrained_delaunay_triangles
from shapely.geometry import Polygon, box
from shapely.ops import transform, unary_union
from select_major_rivers import select

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'data/sources/hydrography'
OUT = ROOT/'data/derived/hydrography'
URL = 'https://www1.gsi.go.jp/geowww/globalmap-gsi/download/data/gm-japan/gm-jpn-hydro_u_2.zip'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def parts(geometry, kind):
    if geometry.is_empty: return
    if geometry.geom_type == kind: yield geometry
    elif hasattr(geometry,'geoms'):
        for item in geometry.geoms: yield from parts(item,kind)

def save(path, data):
    path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')

def main():
    SOURCE.mkdir(parents=True,exist_ok=True)
    OUT.mkdir(parents=True,exist_ok=True)
    (SOURCE/'.gdignore').touch()
    archive=SOURCE/'gm-jpn-hydro_u_2.zip'
    if not archive.exists():
        temp=archive.with_suffix('.tmp')
        subprocess.run(['curl.exe','--fail','--location','--max-time','120','--output',str(temp),URL],check=True)
        with zipfile.ZipFile(temp) as z: assert z.testzip() is None
        temp.replace(archive)
    master=json.loads((ROOT/'data/base/japan_land_master_manifest.json').read_text())
    assert digest(ROOT/master['canonical_file'])==master['canonical_sha256']
    definition=json.loads((ROOT/'data/base/japan_land_manifest.json').read_text())['game_transform']
    p='/vsizip/'+archive.as_posix()+'/gm-jpn-hydro_u_2/'
    rivers=pyogrio.read_dataframe(p+'riverl_jpn.shp')
    waters=pyogrio.read_dataframe(p+'inwatera_jpn.shp')
    major_lines,major_surfaces,selection_report=select(rivers,waters)
    project=Transformer.from_crs(rivers.crs,definition['projection'],always_xy=True)
    source_project=Transformer.from_crs('EPSG:4326',definition['projection'],always_xy=True)
    bx,by,_,_=definition['projected_scope_bounds_m']
    scale=definition['uniform_scale_px_per_m']
    def convert(x,y,z=None,transformer=project):
        px,py=transformer.transform(x,y)
        return (definition['offset_x_px']+(np.asarray(px)-bx)*scale,
                definition['offset_y_px']+definition['content_height_px']-(np.asarray(py)-by)*scale)
    land_data=pyogrio.read_dataframe(ROOT/master['canonical_file'],layer=master['canonical_layer'])
    land=unary_union([transform(lambda x,y,z=None:convert(x,y,z,source_project),g) for g in land_data.geometry])
    lake_records=[]
    lake_shapes=[]
    for index,row in waters.iterrows():
        geom=make_valid(transform(convert,row.geometry)).intersection(land)
        for part_index,poly in enumerate(parts(geom,'Polygon')):
            if poly.area<=1e-8: continue
            lake_shapes.append(poly)
            triangles=[]
            # Cut the actual lake polygon at every terrain mesh edge; preserve holes.
            x0,y0,x1,y1=poly.bounds
            for y in range(math.floor(y0/16)*16,math.ceil(y1/16)*16,16):
                for x in range(math.floor(x0/16)*16,math.ceil(x1/16)*16,16):
                    if not poly.intersects(box(x,y,x+16,y+16)): continue
                    for cell in [Polygon([(x,y),(x+16,y),(x,y+16)]),Polygon([(x+16,y),(x+16,y+16),(x,y+16)])]:
                        for piece in parts(poly.intersection(cell),'Polygon'):
                            for triangle in constrained_delaunay_triangles(piece).geoms:
                                triangles.extend([list(p) for p in list(triangle.exterior.coords)[:3]])
            name='' if row['nam']=='UNK' else row['nam']
            lake_records.append({'id':f'jp-lake-gsi-{index:04d}-{part_index}', 'source_index':int(index),
                'visible_by_default':int(row['hyt'])!=1 or int(index) in major_surfaces,
                'main_stems':major_surfaces.get(int(index),[]),
                'source_type':int(row['hyt']),'name':name,'bounds':list(poly.bounds),
                'area_km2':poly.area/scale**2/1e6,'rings':[list(poly.exterior.coords)]+[list(r.coords) for r in poly.interiors],
                'triangles':triangles,'label_point':list(poly.representative_point().coords)[0]})
    lake_union=unary_union(lake_shapes)
    river_records=[]
    for index,row in rivers.iterrows():
        geom=transform(convert,row.geometry).intersection(land).difference(lake_union)
        for part_index,line in enumerate(parts(geom,'LineString')):
            if line.length<1e-6: continue
            river_records.append({'id':f'jp-river-gsi-{index:04d}-{part_index}','source_index':int(index),
                'visible_by_default':int(index) in major_lines,'main_stems':major_lines.get(int(index),[]),
                'source_line_type':int(row['lit']),'name':'' if row['nam']=='UNK' else row['nam'],
                'bounds':list(line.bounds),'points':list(line.coords)})
    river_records.sort(key=lambda r:r['id'])
    lake_records.sort(key=lambda r:r['id'])
    registry={'schema_version':1,'coordinate_space':[0,0,8192,8192],
              'source':'GSI Global Map Japan v2 hydrography (2011)',
              'rivers':river_records,'lakes':lake_records}
    save(OUT/'water_registry.json',registry)
    save(OUT/'major_rivers_selection.json',{'policy':'Explicit main-stem names; only unnamed connecting edges; no named tributaries.',
        'main_stems':selection_report,'visible_river_parts':sum(r['visible_by_default'] for r in river_records),
        'hidden_river_parts':sum(not r['visible_by_default'] for r in river_records),
        'visible_river_surfaces':sum(l['source_type']==1 and l['visible_by_default'] for l in lake_records)})
    (OUT/'SOURCE-README.txt').write_bytes(zipfile.ZipFile(archive).read('gm-jpn-hydro_u_2/Read_me.txt'))
    for name,url in [('GSI-TERMS.html','https://www.gsi.go.jp/kikakuchousei/kikakuchousei40182.html')]:
        path=OUT/name
        if not path.exists(): subprocess.run(['curl.exe','--fail','--location','--silent','--output',str(path),url],check=True)
    (OUT/'ATTRIBUTION.md').write_text('出典：国土地理院「地球地図日本 第2版 水系」（2011年）\n'
        'https://www.gsi.go.jp/kankyochiri/gm_jpn.html\n\n'
        '本ゲーム用に投影変換・基盤陸地へのクリップ・河川の湖面内除去・湖面の三角形分割・着色を行いました。\n'
        '国土地理院が作成したゲーム地図ではありません。現代の水系を用いた描画で、戦国期の河道復元ではありません。\n\n'
        '利用条件：国土地理院コンテンツ利用規約／公共データ利用規約（PDL1.0）\n'
        'https://www.gsi.go.jp/kikakuchousei/kikakuchousei40182.html\n',encoding='utf-8')
    save(OUT/'hydrography_manifest.json',{'source_url':URL,'source_sha256':digest(archive),
        'source_crs':str(rivers.crs),'game_transform':definition,'source_master_sha256':master['canonical_sha256'],
        'river_parts':len(river_records),'lake_parts':len(lake_records),'lake_mesh_step':16,
        'registry_sha256':digest(OUT/'water_registry.json'),
        'limitations':'Generalized 1:1,000,000 modern hydrography. No historical river reconstruction. Source unknown names remain unnamed.'})
    print(f'Created {len(river_records)} river parts, {len(lake_records)} water polygons',flush=True)

if __name__=='__main__': main()
