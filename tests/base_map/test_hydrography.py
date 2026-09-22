import hashlib
import json
from pathlib import Path
import unittest
from shapely.geometry import Polygon, LineString
from shapely.ops import unary_union
import numpy as np

ROOT=Path(__file__).resolve().parents[2]

class HydrographyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((ROOT/'data/derived/hydrography/water_registry.json').read_text(encoding='utf-8'))
        cls.manifest=json.loads((ROOT/'data/derived/hydrography/hydrography_manifest.json').read_text())

    def test_provenance_and_lake_tessellation(self):
        self.assertEqual(hashlib.sha256((ROOT/'data/base/japan_land.gpkg').read_bytes()).hexdigest().upper(),self.manifest['source_master_sha256'])
        self.assertEqual(hashlib.sha256((ROOT/'data/derived/hydrography/water_registry.json').read_bytes()).hexdigest().upper(),self.manifest['registry_sha256'])
        self.assertEqual(len({l['id'] for l in self.data['lakes']}),len(self.data['lakes']))
        names={l['name'] for l in self.data['lakes']}
        self.assertTrue({'BIWA KO','SUWA KO','KASUMI-GA URA','INAWASHIRO KO'}<=names)
        for lake in self.data['lakes']:
            polygon=Polygon(lake['rings'][0],lake['rings'][1:])
            self.assertTrue(polygon.is_valid)
            vertices=np.asarray(lake['triangles']).reshape(-1,3,2)
            a=vertices[:,1]-vertices[:,0];b=vertices[:,2]-vertices[:,0]
            area=np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0]).sum()/2
            self.assertAlmostEqual(area,polygon.area,places=6)
            for tri in vertices:
                # A lake mesh triangle may not cross a terrain grid edge.
                for coords in (tri[:,0],tri[:,1],tri[:,0]+tri[:,1]):
                    self.assertLessEqual(np.ceil((coords.max()-1e-7)/16)-np.floor((coords.min()+1e-7)/16),1)

    def test_rivers_clipped_to_land_and_lake_shore(self):
        # Read the existing authoritative game-space polygons without changing them.
        import pyogrio
        import sys
        sys.path.insert(0,str(ROOT/'tools'))
        import build_japan_land_base as base
        land=unary_union([base.to_game_geometry(g,*base.game_transform_definition()) for g in pyogrio.read_dataframe(ROOT/'data/base/japan_land.gpkg',layer='japan_land').geometry])
        water=unary_union([Polygon(l['rings'][0],l['rings'][1:]) for l in self.data['lakes']])
        self.assertLess(water.difference(land).area,1e-5)
        for river in self.data['rivers']:
            line=LineString(river['points'])
            self.assertTrue(line.is_valid)
            self.assertLess(line.difference(land).length,1e-5)
            self.assertLess(line.intersection(water).length,1e-5)

    def test_main_stems_only_and_hidden_data_retained(self):
        report=json.loads((ROOT/'data/derived/hydrography/major_rivers_selection.json').read_text(encoding='utf-8'))
        self.assertEqual(len(self.data['rivers']),4581)
        self.assertEqual(len(self.data['lakes']),804)
        self.assertGreater(report['hidden_river_parts'],3000)
        chosen=set()
        for stem in report['main_stems']:
            chosen.update(stem['selected_source_indices'])
        for river in self.data['rivers']:
            self.assertEqual(river['visible_by_default'],river['source_index'] in chosen)
            if river['name'] in ['KINU G.','EDO G.','KATSURA G.','WATARASE G.','TADAMI G.']:
                self.assertFalse(river['visible_by_default'],river['id'])
        for name in ['TONE G.','CHIKUGO G.','KISO G.','YODO G.','SHINANO G.']:
            self.assertTrue(any(r['name']==name and r['visible_by_default'] for r in self.data['rivers']),name)

if __name__=='__main__':unittest.main()
