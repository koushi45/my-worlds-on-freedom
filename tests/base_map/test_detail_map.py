"""Independent ground geometry, seam, sampling density and provenance checks."""
import hashlib
import json
import unittest
from pathlib import Path
import numpy as np
from PIL import Image
from pyproj import Transformer
from shapely.geometry import shape, Polygon, LineString, box
from shapely.ops import unary_union, transform

ROOT=Path(__file__).resolve().parents[2]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))

class DetailMap(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.d=read('data/derived/detail_map/manifest.json')
        m=read('data/base/japan_land_manifest.json')['game_transform']
        proj=Transformer.from_crs('EPSG:4326',m['projection'],always_xy=True)
        def xy(lon,lat):
            x,y=proj.transform(lon,lat)
            return m['offset_x_px']+(x-m['projected_scope_bounds_m'][0])*m['uniform_scale_px_per_m'],m['offset_y_px']+m['content_height_px']-(y-m['projected_scope_bounds_m'][1])*m['uniform_scale_px_per_m']
        cls.land=unary_union([transform(xy,shape(f['geometry'])) for f in read('data/base/japan_land.geojson')['features']])

    def test_source_and_coordinate_contract(self):
        self.assertEqual(self.d['world_size'],[8192,8192])
        self.assertEqual(self.d['maximum_zoom'],4)
        self.assertEqual(self.d['source_zoom'],11)
        self.assertEqual(self.d['density'],4)
        for p,h in self.d['input_hashes'].items(): self.assertEqual(hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),h)
        for s in self.d['sources']: self.assertEqual(hashlib.sha256((ROOT/s['file']).read_bytes()).hexdigest(),s['sha256'])

    def test_complete_exact_land_and_no_tile_edge_shorelines(self):
        total=0
        for tile in self.d['tiles']:
            g=read(tile['files']['geometry']);pts=g['vertices'];ids=g['indices']
            triangles=[Polygon([pts[j] for j in ids[i:i+3]]) for i in range(0,len(ids),3)]
            area=sum(t.area for t in triangles)
            expected=self.land.intersection(box(*tile['global_viewport']))
            self.assertAlmostEqual(area,expected.area,places=4)
            combined=unary_union(triangles)
            self.assertLess(combined.symmetric_difference(expected).area,1e-4)
            total+=area
            for coast in g['coasts']:
                self.assertLess(LineString(coast).difference(self.land.boundary.buffer(1e-7)).length,1e-5)
            # Every triangle stays inside one of the existing 16-unit terrain
            # planes (x, y and x+y grid lines); no change to the pick transform.
            for triangle in triangles:
                v=np.array(triangle.exterior.coords)[:3]
                for axis in [v[:,0],v[:,1],v[:,0]+v[:,1]]:
                    self.assertLessEqual(np.floor((axis.max()-1e-7)/16)-np.floor((axis.min()+1e-7)/16),0)
        self.assertAlmostEqual(total,self.land.area,places=3)

    def test_gutters_match_and_four_texels_per_world_unit(self):
        tiles={tuple(t['global_viewport'][:2]):t for t in self.d['tiles']}
        for (x,y),tile in tiles.items():
            image=np.asarray(Image.open(ROOT/tile['files']['relief']))
            self.assertEqual(image.shape,(1032,1032,3))
            for dx,dy in [(256,0),(0,256)]:
                neighbor=tiles.get((x+dx,y+dy))
                if neighbor is None: continue
                other=np.asarray(Image.open(ROOT/neighbor['files']['relief']))
                a,b=(image[:,-8:],other[:,:8]) if dx else (image[-8:],other[:8])
                self.assertLessEqual(np.abs(a.astype(int)-b.astype(int)).max(),1,(x,y,dx,dy))

    def test_close_terrain_is_complete_and_seamless(self):
        self.assertEqual(self.d['close_zoom_threshold'],2.5)
        tiles={tuple(t['global_viewport'][:2]):t for t in self.d['tiles']}
        for (x,y),tile in tiles.items():
            self.assertEqual(tile['close_density'],6)
            self.assertEqual(tile['close_gutter'],6)
            self.assertEqual(tile['close_output_size'],[1548,1548])
            path=ROOT/tile['files']['relief_close']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),tile['hashes']['relief_close'])
            image=np.asarray(Image.open(path))
            self.assertEqual(image.shape,(1548,1548,3))
            for dx,dy in [(256,0),(0,256)]:
                neighbor=tiles.get((x+dx,y+dy))
                if neighbor is None: continue
                other=np.asarray(Image.open(ROOT/neighbor['files']['relief_close']))
                a,b=(image[:,-12:],other[:,:12]) if dx else (image[-12:],other[:12])
                self.assertLessEqual(np.abs(a.astype(int)-b.astype(int)).max(),1,(x,y,dx,dy))

    def test_coastal_water_uses_the_same_land_boundary(self):
        self.assertEqual(self.d['water_mesh_gutter_world_units'],16)
        samples=[tile for tile in self.d['tiles'] if tile['tile_id'] in {
            'detail-r21-c13', 'detail-r22-c12', 'detail-r23-c12',
            'detail-r24-c08', 'detail-r25-c05',
        }]
        self.assertEqual(len(samples),5)
        for tile in samples:
            path=ROOT/tile['files']['geometry']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),tile['hashes']['geometry'])
            geometry=read(tile['files']['geometry'])
            vertices=geometry['water_vertices']
            indices=geometry['water_indices']
            triangles=[Polygon([vertices[j] for j in indices[i:i+3]]) for i in range(0,len(indices),3)]
            self.assertTrue(triangles,tile['tile_id'])
            water=unary_union(triangles)
            x0,y0,x1,y1=tile['global_viewport']
            expected=box(max(0,x0-16),max(0,y0-16),min(8192,x1+16),min(8192,y1+16)).difference(self.land)
            self.assertLess(water.symmetric_difference(expected).area,1e-4,tile['tile_id'])

if __name__=='__main__': unittest.main()
