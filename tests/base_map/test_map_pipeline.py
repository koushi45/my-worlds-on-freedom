from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

import geopandas as gpd
import numpy as np
import pyogrio
from PIL import Image
from shapely.geometry import LineString, Point
from shapely.ops import unary_union


ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import build_japan_land_base as base
import build_phase_c_coastline_mask as phase_c
import build_phase_d_lod as phase_d
import build_phase_e_map_images as phase_e
import build_phase_f_political as phase_f


class MapPipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.master_manifest = json.loads(phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
        cls.master = gpd.read_file(phase_c.MASTER_GPKG, layer=cls.master_manifest["canonical_layer"])
        cls.lod_json = json.loads(phase_d.LOD_JSON.read_text(encoding="utf-8"))
        cls.map_manifest = json.loads(phase_e.MANIFEST.read_text(encoding="utf-8"))

    def test_01_master_validity_and_fixed_hash(self):
        self.assertTrue(self.master.geometry.is_valid.all())
        self.assertFalse(self.master.geometry.is_empty.any())
        self.assertEqual(phase_c.sha256(phase_c.MASTER_GPKG), self.master_manifest["canonical_sha256"])
        gate = json.loads((ROOT / "data/base/verification/gate1_report.json").read_text(encoding="utf-8"))
        self.assertTrue(gate["all_passed"])
        self.assertTrue(gate["checks"]["regeneration_sha256_match"]["passed"])

    def test_02_crs_game_coordinate_round_trip(self):
        bounds, scale, offset_x, offset_y, content_h = base.game_transform_definition()
        for geometry in self.master.geometry.iloc[::17]:
            game = base.to_game_geometry(geometry, bounds, scale, offset_x, offset_y, content_h)
            restored = base.from_game_geometry(game, bounds, scale, offset_x, offset_y, content_h)
            self.assertTrue(geometry.equals_exact(restored, 1e-10))

    def test_03_each_lod_coastline_equals_land_exterior(self):
        for level in range(5):
            land = pyogrio.read_dataframe(phase_d.LOD_GPKG, layer=f"land_lod{level}")
            coast = pyogrio.read_dataframe(phase_d.LOD_GPKG, layer=f"coastline_lod{level}")
            lookup = {
                (row.land_feature_id, int(row.part_index)): row.geometry
                for row in coast.itertuples(index=False)
            }
            for feature in land.itertuples(index=False):
                for part_index, polygon in enumerate(feature.geometry.geoms):
                    expected = LineString(polygon.exterior.coords)
                    actual = lookup[(feature.feature_id, part_index)]
                    self.assertEqual(expected.hausdorff_distance(actual), 0.0)
                    self.assertTrue(expected.equals_exact(actual, 0.0))

    def test_04_normal_and_selection_share_coastline_ids(self):
        for level in self.lod_json["levels"]:
            self.assertEqual(level["render_profiles"]["normal_display"], level["render_profiles"]["selection_display"])
            self.assertEqual(
                level["render_profiles"]["normal_display"],
                {"registry": "coastline_registry", "id_list": "visible_coastline_ids"},
            )

    def test_05_overlapping_view_families_have_consistent_land(self):
        frames = {
            level: pyogrio.read_dataframe(phase_d.LOD_GPKG, layer=f"land_lod{level}")
            for level in range(5)
        }
        for coarse_level, fine_level in [(0, 1), (1, 2), (2, 3), (3, 4)]:
            coarse = frames[coarse_level]
            fine = frames[fine_level]
            common = set(coarse.loc[coarse.visible, "feature_id"]) & set(fine.loc[fine.visible, "feature_id"])
            coarse_union = unary_union(coarse.loc[coarse.feature_id.isin(common), "geometry"])
            fine_union = unary_union(fine.loc[fine.feature_id.isin(common), "geometry"])
            difference = coarse_union.symmetric_difference(fine_union)
            coast = fine_union.boundary
            allowed = 2.0 * (
                phase_d.LOD_DEFINITIONS[coarse_level]["simplify_tolerance_px"]
                - phase_d.LOD_DEFINITIONS[fine_level]["simplify_tolerance_px"]
            ) + 1e-9
            self.assertTrue(difference.is_empty or difference.difference(coast.buffer(allowed)).area < 1e-6)

    def test_06_tile_seams_only_change_at_vector_coast(self):
        tiles = {(tile["lod"], tile["row"], tile["column"]): tile for tile in self.map_manifest["tiles"]}
        for profile in phase_e.RENDER_PROFILES:
            grid = profile["grid"]
            if grid == 1:
                continue
            level = profile["lod"]
            span = base.GAME_SIZE / grid
            coast_frame = pyogrio.read_dataframe(phase_d.LOD_GPKG, layer=f"coastline_lod{level}")
            coast_union = unary_union(coast_frame.loc[coast_frame.visible, "geometry"])
            global_per_pixel = span / phase_e.TILE_SIZE
            allowed = global_per_pixel * (phase_e.BLEED_PX + 1.0)
            for row in range(grid):
                for column in range(grid - 1):
                    left = tiles[(level, row, column)]
                    right = tiles[(level, row, column + 1)]
                    with Image.open(ROOT / left["files"]["land_coverage"]) as image:
                        left_edge = np.asarray(image)[:, -1]
                    with Image.open(ROOT / right["files"]["land_coverage"]) as image:
                        right_edge = np.asarray(image)[:, 0]
                    seam_x = (column + 1) * span
                    for y_index in np.flatnonzero(left_edge != right_edge):
                        point = Point(seam_x, row * span + (y_index + 0.5) * global_per_pixel)
                        self.assertLessEqual(point.distance(coast_union), allowed)
            for row in range(grid - 1):
                for column in range(grid):
                    top = tiles[(level, row, column)]
                    bottom = tiles[(level, row + 1, column)]
                    with Image.open(ROOT / top["files"]["land_coverage"]) as image:
                        top_edge = np.asarray(image)[-1, :]
                    with Image.open(ROOT / bottom["files"]["land_coverage"]) as image:
                        bottom_edge = np.asarray(image)[0, :]
                    seam_y = (row + 1) * span
                    for x_index in np.flatnonzero(top_edge != bottom_edge):
                        point = Point(column * span + (x_index + 0.5) * global_per_pixel, seam_y)
                        self.assertLessEqual(point.distance(coast_union), allowed)

    def test_07_top_down_oblique_inverse(self):
        tilt, shear = 0.72, 0.18
        for x, y in [(0.0, 0.0), (8192.0, 8192.0), (1234.5, 6789.25)]:
            oblique_x, oblique_y = x + shear * y, tilt * y
            restored_y = oblique_y / tilt
            restored_x = oblique_x - shear * restored_y
            self.assertAlmostEqual(x, restored_x, places=9)
            self.assertAlmostEqual(y, restored_y, places=9)

    def test_08_click_targets_match_display_contract(self):
        registry = json.loads(phase_f.REGISTRY_JSON.read_text(encoding="utf-8"))
        layers = {row[0] for row in pyogrio.list_layers(phase_f.POLITICAL_GPKG)}
        if not registry["regions"]:
            self.assertNotIn("click_masks", layers)
            self.assertNotIn("shared_boundaries", layers)
            return
        boundaries = pyogrio.read_dataframe(phase_f.POLITICAL_GPKG, layer="shared_boundaries")
        valid_boundary_ids = set(boundaries.boundary_id)
        valid_coast_ids = set(gpd.read_file(phase_c.COAST_GPKG, layer=phase_c.COAST_MASTER_LAYER).coastline_id)
        for region in registry["regions"]:
            self.assertFalse(region["click_mask"]["render_enabled"])
            self.assertTrue(set(region["selection_display"]["shared_boundary_ids"]) <= valid_boundary_ids)
            self.assertTrue(
                {item["coastline_id"] for item in region["selection_display"]["coastline_references"]}
                <= valid_coast_ids
            )

    def test_09_offscreen_tile_culling_contract(self):
        def visible(lod_level, bounds):
            x0, y0, x1, y1 = bounds
            result = []
            for tile in self.map_manifest["tiles"]:
                if tile["lod"] != lod_level:
                    continue
                a0, b0, a1, b1 = tile["global_viewport"]
                if a0 < x1 and x0 < a1 and b0 < y1 and y0 < b1:
                    result.append(tile["tile_id"])
            return result

        self.assertEqual(len(visible(4, [100, 100, 300, 300])), 1)
        self.assertEqual(visible(4, [-1000, -1000, -900, -900]), [])

    def test_10_platform_runtime_asset_compatibility(self):
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertEqual(set(re.findall(r'^name="([^"]+)"', presets, re.MULTILINE)), {"Windows", "Web", "Android", "iOS", "Windows Unconfirmed", "Android Unconfirmed"})
        filters = re.findall(r'^include_filter="([^"]+)"', presets, re.MULTILINE)
        self.assertEqual(len(filters), 6)
        for block in re.split(r'\[preset\.\d+\]', presets)[1:]:
            name = re.search(r'^name="([^"]+)"', block, re.MULTILINE).group(1)
            excluded = re.search(r'^exclude_filter="([^"]*)"', block, re.MULTILINE).group(1).split(',')
            for shape_dir in ('data/derived/map_runtime/parents/*', 'data/derived/map_runtime/districts/*'):
                self.assertEqual(shape_dir in excluded, not name.endswith(' Unconfirmed'))
        for value in filters:
            patterns = value.split(',')
            for required in ['data/derived/map_images/map_images_manifest.json',
                             'data/derived/map_runtime/*',
                             'data/derived/hydrography/*',
                             'data/derived/elevation/*', 'assets/map/elevation/*.png',
                             'data/derived/political/approved_western/*',
                             'assets/map/generated/**/*.png', 'scripts/**/*.gd']:
                self.assertIn(required, patterns)
        for tile in self.map_manifest["tiles"]:
            for path in tile["files"].values():
                self.assertNotIn("\\", path)
                self.assertNotIn(":", path)
            with Image.open(ROOT / tile["files"]["composite"]) as image:
                self.assertLessEqual(max(image.size), 2048)

        godot = shutil.which("godot_console") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot, "Godot executable is required for runtime loading tests")
        runtime_tests = (
            ("res://tests/base_map/godot/test_map_runtime.gd", "Godot map runtime tests passed"),
            ("res://tests/base_map/godot/test_main_scene.gd", "Godot main scene rendering contract passed"),
        )
        for script, success_message in runtime_tests:
            completed = subprocess.run(
                [godot, "--headless", "--path", str(ROOT), "--script", script],
                cwd=ROOT,
                capture_output=True,
                text=True,
                timeout=120,
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertIn(success_message, completed.stdout + completed.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
