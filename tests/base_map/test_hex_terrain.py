"""Check the baked hex terrain against representative source observations."""
import json
import math
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


class HexTerrainTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.coverage = json.loads((ROOT / "data/derived/detail_map/hex_coverage.json").read_text(encoding="utf-8"))
        cls.terrain = json.loads((ROOT / "data/derived/detail_map/hex_terrain.json").read_text(encoding="utf-8"))

    def tile_at(self, x, y):
        radius = self.coverage["radius"]
        q = (math.sqrt(3) / 3 * x - y / 3) / radius
        r = 2 * y / (3 * radius)
        s = -q - r
        qi, ri, si = round(q), round(r), round(s)
        if abs(qi - q) > abs(ri - r) and abs(qi - q) > abs(si - s):
            qi = -ri - si
        elif abs(ri - r) > abs(si - s):
            ri = -qi - si
        row = str(ri)
        return int(self.terrain["rows"][row][self.coverage["rows"][row].index(qi)])

    def test_coverage_and_source_observations(self):
        self.assertEqual(self.terrain["tile_count"], self.coverage["visible_cells"])
        self.assertEqual(set(self.terrain["counts"]), {"plain", "mountain", "river", "high_mountain", "no_land"})
        self.assertGreaterEqual(self.terrain["counts"]["no_land"],
                                self.coverage["visible_cells"] - self.coverage["land_cells"])
        self.assertTrue(all(len(self.terrain["rows"][row]) == len(columns)
                            for row, columns in self.coverage["rows"].items()))
        height = np.asarray(Image.open(ROOT / "assets/map/elevation/elevation_m.png"))
        y, x = np.unravel_index(height.argmax(), height.shape)
        self.assertGreaterEqual(int(height[y, x]), 2500)
        self.assertEqual(self.tile_at((x + .5) * 2, (y + .5) * 2), 3)
        water = json.loads((ROOT / "data/derived/hydrography/water_registry.json").read_text(encoding="utf-8"))
        hidden = next(row for row in water["rivers"] if row["id"] == "jp-river-gsi-0022-0")
        hidden_point = hidden["points"][len(hidden["points"]) // 2]
        self.assertEqual(self.tile_at(*hidden_point), 0)
        visible = next(row for row in water["rivers"] if row["id"] == "jp-river-gsi-0058-0")
        visible_point = visible["points"][len(visible["points"]) // 2]
        self.assertEqual(self.tile_at(*visible_point), 2)


if __name__ == "__main__":
    unittest.main()
