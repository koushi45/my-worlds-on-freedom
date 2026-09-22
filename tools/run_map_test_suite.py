"""Run the required map pipeline tests with the standard library test runner."""

from __future__ import annotations

import subprocess
import sys
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main():
    command = [
        sys.executable,
        "-m",
        "unittest",
        "discover",
        "-s",
        "tests/base_map",
        "-p",
        "test_*.py",
        "-v",
    ]
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if completed.stdout:
        print(completed.stdout, end="")
    if completed.stderr:
        print(completed.stderr, end="", file=sys.stderr)
    match = re.search(r"Ran (\d+) tests?", completed.stdout + completed.stderr)
    report = {
        "suite": "map_pipeline_minimum_requirements",
        "passed": completed.returncode == 0,
        "test_count": int(match.group(1)) if match else None,
        "requirements": {
            "master_validity_and_hash": "test_01_master_validity_and_fixed_hash",
            "crs_8192_round_trip": "test_02_crs_game_coordinate_round_trip",
            "lod_coastline_land_distance_zero": "test_03_each_lod_coastline_equals_land_exterior",
            "normal_selection_same_coastline_ids": "test_04_normal_and_selection_share_coastline_ids",
            "national_regional_local_overlap": "test_05_overlapping_view_families_have_consistent_land",
            "tile_seams": "test_06_tile_seams_only_change_at_vector_coast",
            "top_down_oblique_inverse": "test_07_top_down_oblique_inverse",
            "click_target_display_boundary": "test_08_click_targets_match_display_contract",
            "offscreen_tile_culling": "test_09_offscreen_tile_culling_contract",
            "windows_android_ios_web_loading": "test_10_platform_runtime_asset_compatibility",
        },
        "runtime": {
            "godot_headless_test": "tests/base_map/godot/test_map_runtime.gd",
            "platforms": ["Windows", "Android", "iOS", "Web"],
            "scope": "portable JSON/PNG resource and export-preset loading contract; not signed native exports",
        },
    }
    output = ROOT / "data/derived/testing/map_test_report.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    raise SystemExit(completed.returncode)


if __name__ == "__main__":
    main()
