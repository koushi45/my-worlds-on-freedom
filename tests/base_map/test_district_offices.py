"""Independent checks of generated administrative tile assignments."""
import json
import math
import unittest
from pathlib import Path

from shapely.geometry import Polygon, Point
from shapely.ops import unary_union
from shapely import STRtree

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))


class DistrictOfficesTest(unittest.TestCase):
    def test_every_assigned_hex_is_unique_and_completely_inside_its_district(self):
        regions = read("data/derived/scenarios/independent_districts_1546.json")["regions"]
        sources = read("data/editorial/governance/district_office_sources.json")
        data = read("data/derived/scenarios/district_offices_1546.json")
        records = data["records"]
        self.assertEqual(set(records), set(regions)-set(sources["omit_districts"]))
        ids = list(regions)
        geometry = [unary_union([Polygon(p[0], p[1:]) for p in regions[k]["polygons"]]) for k in ids]
        tree = STRtree(geometry)
        used = set()
        for key, record in records.items():
            with self.subTest(district=key):
                cell = tuple(record["cell"])
                self.assertNotIn(cell, used)
                used.add(cell)
                radius = data["radius"]
                x, y = record["point"]
                self.assertAlmostEqual(x, math.sqrt(3)*radius*(cell[0]+cell[1]/2), places=6)
                self.assertAlmostEqual(y, radius*1.5*cell[1], places=6)
                hexagon = Polygon([(x+radius*math.cos(math.pi/6+i*math.pi/3), y+radius*math.sin(math.pi/6+i*math.pi/3)) for i in range(6)])
                own = geometry[ids.index(key)]
                self.assertTrue(own.contains(hexagon))
                self.assertGreater(hexagon.distance(own.boundary), .049)
                for other in tree.query(hexagon):
                    if ids[int(other)] != key:
                        self.assertFalse(geometry[int(other)].intersects(hexagon))
                self.assertFalse(record["historically_confirmed_office"])
                self.assertFalse(record["boundary_exception"])
                if record["method"] == "historical_reference":
                    self.assertTrue(record["reference"]["source_url"].startswith("https://"))
                    self.assertLessEqual(record["reference_distance_world"], 4*radius)
                else:
                    self.assertGreater(record["candidate_count"], 0)
        self.assertEqual(data["report"]["unresolved"], [])


if __name__ == "__main__":
    unittest.main()
