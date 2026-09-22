import hashlib
import json
from pathlib import Path
import unittest
import numpy as np
from PIL import Image
from pyproj import Transformer

ROOT = Path(__file__).resolve().parents[2]

class ElevationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT/'data/derived/elevation/elevation_manifest.json').read_text(encoding='utf-8'))
        cls.height = np.array(Image.open(ROOT/'assets/map/elevation/elevation_m.png'))

    def test_real_dem_and_master(self):
        m = self.manifest
        self.assertEqual(hashlib.sha256((ROOT/'data/base/japan_land.gpkg').read_bytes()).hexdigest().upper(),m['source_master_sha256'])
        self.assertGreater(self.height.max(),3000)
        self.assertLess(self.height.max(),4000)
        land = np.array(Image.open(ROOT/'data/derived/land_masks/land_mask_8192.png').resize((4096,4096),Image.Resampling.BOX))
        self.assertTrue(np.all(self.height[land==0]==0))
        self.assertLess(m['max_display_y_derivative'],1)
        # Fuji is high, Kanto plain is low: also detects axis / CRS mistakes.
        d = m['game_transform']
        t = Transformer.from_crs('EPSG:4326',d['projection'],always_xy=True)
        def sample(lon,lat):
            px,py=t.transform(lon,lat)
            bx,by,_,_=d['projected_scope_bounds_m'];s=d['uniform_scale_px_per_m']
            x=int((d['offset_x_px']+(px-bx)*s)/2)
            y=int((d['offset_y_px']+d['content_height_px']-(py-by)*s)/2)
            return self.height[y-2:y+3,x-2:x+3].max()
        self.assertGreater(sample(138.7274,35.3606),3000)
        self.assertLess(sample(139.65,35.7),150)

    def test_all_lod_coverage_and_hashes(self):
        original=json.loads((ROOT/'data/derived/map_images/map_images_manifest.json').read_text())
        self.assertEqual(len(self.manifest['tiles']),41)
        for tile in original['tiles']:
            output=self.manifest['tiles'][tile['tile_id']]
            path=ROOT/output['file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest().upper(),output['sha256'])
            alpha=np.array(Image.open(path))[:,:,3]
            coverage=np.array(Image.open(ROOT/tile['files']['land_coverage']))
            self.assertTrue(np.array_equal(alpha,coverage),tile['tile_id'])

if __name__=='__main__': unittest.main()
