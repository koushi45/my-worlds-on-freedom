import importlib.util
import unittest
from pathlib import Path

import numpy as np

spec = importlib.util.spec_from_file_location('terrain_relief', Path(__file__).resolve().parents[2] / 'tools/build_terrain_relief.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TerrainReliefTests(unittest.TestCase):
    def test_flat_ground_and_water_are_uniform(self):
        flat = module.lighting(np.full((128, 128), 20, dtype=np.float32), 100)
        self.assertEqual(int(flat.max()), int(flat.min()))
        water = module.lighting(np.zeros((128, 128), dtype=np.float32), 100)
        self.assertTrue(np.all(water == 255))

    def test_measured_ridge_lights_sunward_slope_and_shadows_valley(self):
        y, x = np.mgrid[:128, :128]
        ridge = 20 + 1800 * np.exp(-((x + y - 110) / 8) ** 2)
        result = module.lighting(ridge, 100)
        # The broad field contributes shadow only; directional diffuse light
        # is now calculated at each native texture resolution.
        import sys
        sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
        from terrain_texture import components
        axis = np.arange(128, dtype=np.float32)
        _, light = components(ridge, axis, axis, 100, variant="colour")
        combined = light.mean(axis=2) * result / 255
        self.assertGreater(float(combined[48, 48]), float(combined[62, 62]))
        self.assertLess(int(result[62, 62]), int(result[110, 110]))
        self.assertGreaterEqual(result.min(), 199)
        self.assertLessEqual(result.max(), 255)


if __name__ == '__main__':
    unittest.main()
