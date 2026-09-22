import json
import struct
import unittest
from pathlib import Path

from shapely.geometry import Polygon


ROOT = Path(__file__).resolve().parents[2]


class IndependentFillMeshTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(
            (ROOT / "data/derived/scenarios/independent_districts_1546.json").read_text(encoding="utf-8")
        )
        cls.manifest = json.loads(
            (ROOT / "data/derived/scenarios/independent_district_fill_meshes.json").read_text(encoding="utf-8")
        )

    def test_every_current_district_has_an_exact_fill_mesh(self):
        self.assertEqual(len(self.source["regions"]), self.manifest["district_count"])
        self.assertEqual(set(self.source["regions"]), set(self.manifest["meshes"]))
        for district_id, region in self.source["regions"].items():
            entry = self.manifest["meshes"][district_id]
            raw = (ROOT / entry["file"].removeprefix("res://")).read_bytes()
            self.assertEqual(0, len(raw) % 24, district_id)
            values = struct.unpack(f"<{len(raw) // 4}f", raw)
            triangles = [
                Polygon([(values[i], values[i + 1]), (values[i + 2], values[i + 3]), (values[i + 4], values[i + 5])])
                for i in range(0, len(values), 6)
            ]
            mesh_area = sum(t.area for t in triangles)
            polygon_area = sum(Polygon(p[0], p[1:]).area for p in region["polygons"])
            # Runtime meshes store float32 vertices. Canonical coastlines add
            # substantially more triangles than the former simplified coast,
            # so bound accumulated float32 area error separately from the
            # generator's stricter double-precision equality check.
            self.assertAlmostEqual(polygon_area, mesh_area, delta=max(0.02, polygon_area * 3e-6), msg=district_id)


if __name__ == "__main__":
    unittest.main()
