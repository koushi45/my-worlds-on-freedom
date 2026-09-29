"""Consistency checks for the requested cross-province district union."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TARGET = "hizen/merged-3051a6f57adaff58"
SOURCES = {"chikuzen/unresolved-42cfaa8c657745ea", "chikugo/unresolved-42cfaa8c657745ea"}

def read(path):
    return json.loads((ROOT/path).read_text(encoding="utf8"))

class KanzakiMergeTest(unittest.TestCase):
    def test_active_ids_population_facilities_and_fills_agree(self):
        shape_path = "data/derived/scenarios/independent_districts_1546.json"
        regions = read(shape_path)["regions"]
        topology = read("data/derived/scenarios/district_connectivity_1546.json")
        population = read("data/derived/population/district_population_1546.json")
        catalog = read("data/derived/scenarios/house_selection_1546.json")
        fills = read("data/derived/scenarios/independent_district_fill_meshes.json")
        self.assertEqual(len(regions), 649)
        self.assertFalse(set(regions) & SOURCES)
        for ids in (topology["active_district_ids"], population["districts"], catalog["district_ids"], fills["meshes"]):
            self.assertEqual(set(ids), set(regions))
        self.assertEqual(fills["source_sha256"], hashlib.sha256((ROOT/shape_path).read_bytes()).hexdigest())
        self.assertEqual(set(population["districts"][TARGET]["merged_district_ids"]), SOURCES)
        tsuru = "kai/unresolved-b48d2f62146c8828"
        miura = "sagami/unresolved-42cfaa8c657745ea"
        self.assertNotIn(miura, regions)
        self.assertEqual(population["districts"][tsuru]["name"], "都留郡")
        self.assertEqual(population["districts"][tsuru]["merged_district_ids"], [miura])
        self.assertEqual(population["districts"]["echizen/unresolved-42cfaa8c657745ea"]["name"], "敦賀郡")
        self.assertNotIn("musashi/unresolved-42cfaa8c657745ea", regions)
        self.assertEqual(population["districts"]["kai/unresolved-cd2be55f925d6adb"]["merged_district_ids"], ["musashi/unresolved-42cfaa8c657745ea"])
        for case, field in (("adopted", "population_estimate"), ("low", "population_low"), ("high", "population_high")):
            self.assertEqual(sum(r[field] for r in population["districts"].values()), population["case_totals"][case])
        for ids in topology["site_district_candidates"].values():
            self.assertTrue(set(ids) <= set(regions))

    def test_review_red_fills_are_removed(self):
        overrides = read("data/editorial/governance/district_display_overrides.json")["districts"]
        highlights = read("data/derived/scenarios/district_review_highlights.json")
        self.assertEqual(highlights["district_ids"], [])
        self.assertFalse(any(r.get("keep_red") for r in overrides.values()))
