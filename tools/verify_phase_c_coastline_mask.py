"""Verify Phase C coastline, shared references, and 8192 land mask."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import pyogrio
from PIL import Image
from shapely.geometry import LineString

import build_japan_land_base as base
import build_phase_c_coastline_mask as phase_c


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "data/derived/phase_c_verification.json"


def coordinates_equal(left, right, tolerance=1e-9):
    a = np.asarray(left.coords, dtype=float)
    b = np.asarray(right.coords, dtype=float)
    return a.shape == b.shape and bool(np.allclose(a, b, atol=tolerance, rtol=0.0))


def snapshot_hashes():
    return {
        "coastline_master.gpkg": phase_c.sha256(phase_c.COAST_GPKG),
        "land_mask_8192.png": phase_c.sha256(phase_c.LAND_MASK),
        "land_master_8192.json": phase_c.sha256(phase_c.LAND_JSON),
        "phase_c_manifest.json": phase_c.sha256(phase_c.PHASE_C_MANIFEST),
    }


def main():
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_c_coastline_mask.py")], cwd=ROOT, check=True, capture_output=True)
    first_hashes = snapshot_hashes()
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_c_coastline_mask.py")], cwd=ROOT, check=True, capture_output=True)
    second_hashes = snapshot_hashes()

    approval = json.loads(phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
    canonical = gpd.read_file(phase_c.MASTER_GPKG, layer=approval["canonical_layer"])
    coast_master = gpd.read_file(phase_c.COAST_GPKG, layer=phase_c.COAST_MASTER_LAYER)
    coast_game = gpd.read_file(phase_c.COAST_GPKG, layer=phase_c.COAST_GAME_LAYER)
    land_json = json.loads(phase_c.LAND_JSON.read_text(encoding="utf-8"))
    bounds, scale, offset_x, offset_y, content_h = base.game_transform_definition()

    expected = {}
    expected_game = {}
    for feature in canonical.itertuples(index=False):
        for part_index, polygon in enumerate(feature.geometry.geoms):
            coast_id = "jp-coast-" + phase_c.uuid.uuid5(
                phase_c.COAST_NAMESPACE,
                f"{approval['master_version']}:{feature.feature_id}:{part_index}:exterior",
            ).hex[:16]
            line = LineString(polygon.exterior.coords)
            expected[coast_id] = line
            expected_game[coast_id] = base.to_game_geometry(line, bounds, scale, offset_x, offset_y, content_h)

    master_lookup = dict(zip(coast_master.coastline_id, coast_master.geometry))
    game_lookup = dict(zip(coast_game.coastline_id, coast_game.geometry))
    master_mismatches = [key for key in expected if key not in master_lookup or not coordinates_equal(expected[key], master_lookup[key], 0.0)]
    game_mismatches = [key for key in expected_game if key not in game_lookup or not coordinates_equal(expected_game[key], game_lookup[key])]
    json_mismatches = []
    for key, expected_line in expected_game.items():
        stored = land_json["coastlines"].get(key)
        if stored is None or not coordinates_equal(expected_line, LineString(stored["points"]), 0.0):
            json_mismatches.append(key)

    normal = land_json["render_profiles"]["normal_display"]
    selection = land_json["render_profiles"]["selection_display"]
    shared_reference = normal == selection == {"registry": "coastlines", "id_list": "all_coastline_ids"}
    ids = land_json["all_coastline_ids"]
    registry_ids = list(land_json["coastlines"].keys())

    with Image.open(phase_c.LAND_MASK) as image:
        mask_size = list(image.size)
        mask_mode = image.mode
        colors = image.getcolors(maxcolors=256)
        color_values = sorted(value for _, value in colors) if colors else []
        sea_corner_values = [image.getpixel(point) for point in [(0, 0), (8191, 0), (0, 8191), (8191, 8191)]]
        representative_failures = []
        for geom in canonical.geometry:
            point = base.to_game_geometry(geom.representative_point(), bounds, scale, offset_x, offset_y, content_h)
            pixel = (max(0, min(8191, int(point.x))), max(0, min(8191, int(point.y))))
            if image.getpixel(pixel) != 255:
                representative_failures.append(pixel)

    with sqlite3.connect(phase_c.COAST_GPKG) as connection:
        sqlite_integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    layers = sorted(row[0] for row in pyogrio.list_layers(phase_c.COAST_GPKG))

    expected_transform = {
        "coordinate_space": [0, 0, base.GAME_SIZE, base.GAME_SIZE],
        "north_up": True,
        "y_axis": "down",
        "projection": base.GAME_PROJECTION,
        "fixed_geographic_scope": list(base.GAME_GEOGRAPHIC_SCOPE),
        "projected_scope_bounds_m": list(bounds),
        "uniform_scale_px_per_m": scale,
        "offset_x_px": offset_x,
        "offset_y_px": offset_y,
        "content_height_px": content_h,
        "padding_px": base.GAME_PADDING,
        "deterministic_formula": "WGS84 -> stated LCC; x=offset_x+(X-minX)*scale; y=offset_y+content_height-(Y-minY)*scale",
    }

    checks = {
        "approved_master_hash": {
            "passed": approval["approval"]["approved"] and phase_c.sha256(phase_c.MASTER_GPKG) == approval["canonical_sha256"],
        },
        "coastline_count_matches_outer_rings": {
            "passed": len(expected) == len(coast_master) == len(coast_game),
            "expected": len(expected),
            "master": len(coast_master),
            "game": len(coast_game),
        },
        "master_coastline_exactly_matches_exteriors": {"passed": not master_mismatches, "mismatches": master_mismatches},
        "game_coastline_uses_shared_transform": {"passed": not game_mismatches, "mismatches": game_mismatches},
        "json_coastline_points_match_game_layer": {"passed": not json_mismatches, "mismatches": json_mismatches},
        "normal_selection_share_id_list_and_registry": {"passed": shared_reference, "normal": normal, "selection": selection},
        "coastline_ids_unique_and_complete": {
            "passed": len(ids) == len(set(ids)) and ids == registry_ids == sorted(expected),
            "count": len(ids),
        },
        "transform_metadata_matches_generator": {"passed": land_json["transform"] == expected_transform},
        "mask_dimensions_and_binary_values": {
            "passed": mask_size == [8192, 8192] and mask_mode == "L" and color_values == [0, 255],
            "size": mask_size,
            "mode": mask_mode,
            "values": color_values,
        },
        "mask_land_and_sea_samples": {
            "passed": not representative_failures and sea_corner_values == [0, 0, 0, 0],
            "land_sample_failures": representative_failures,
            "sea_corner_values": sea_corner_values,
        },
        "geopackage_integrity_and_layers": {
            "passed": sqlite_integrity == "ok" and layers == sorted([phase_c.COAST_MASTER_LAYER, phase_c.COAST_GAME_LAYER]),
            "integrity": sqlite_integrity,
            "layers": layers,
        },
        "deterministic_regeneration_hashes": {
            "passed": first_hashes == second_hashes,
            "first": first_hashes,
            "second": second_hashes,
        },
    }
    result = {
        "phase": "C",
        "all_passed": all(item["passed"] for item in checks.values()),
        "checks": checks,
    }
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"all_passed": result["all_passed"], "checks": len(checks)}, indent=2))
    if not result["all_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
