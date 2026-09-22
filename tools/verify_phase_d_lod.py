"""Verify topology, provenance, shared references, and transitions for Phase D LODs."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import numpy as np
import pyogrio
import shapely
from shapely.geometry import LineString, Point

import build_phase_d_lod as lod


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "data/derived/lod/lod_verification.json"


def hashes():
    result = {
        "japan_lod.gpkg": lod.sha256(lod.LOD_GPKG),
        "japan_lod.json": lod.sha256(lod.LOD_JSON),
        "lod_manifest.json": lod.sha256(lod.LOD_MANIFEST),
    }
    for definition in lod.LOD_DEFINITIONS:
        path = lod.PREVIEW_DIR / f"lod{definition['level']}_{definition['name']}.png"
        result[path.name] = lod.sha256(path)
    return result


def coordinate_equal(left, right, tolerance=0.0):
    a = np.asarray(left.coords, dtype=float)
    b = np.asarray(right.coords, dtype=float)
    if a.shape != b.shape:
        return False
    if tolerance == 0.0:
        return bool(np.array_equal(a, b))
    return bool(np.allclose(a, b, atol=tolerance, rtol=0.0))


def overlap_count(frame, tolerance=1e-6):
    spatial_index = frame.sindex
    overlaps = 0
    for i, geometry in enumerate(frame.geometry):
        for j in spatial_index.query(geometry, predicate="intersects"):
            if j <= i:
                continue
            if geometry.intersection(frame.geometry.iloc[j]).area > tolerance:
                overlaps += 1
    return overlaps


def main():
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_d_lod.py")], cwd=ROOT, check=True, capture_output=True)
    first = hashes()
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_d_lod.py")], cwd=ROOT, check=True, capture_output=True)
    second = hashes()

    data = json.loads(lod.LOD_JSON.read_text(encoding="utf-8"))
    land_frames = {}
    coast_frames = {}
    level_checks = {}
    json_mismatches = []
    point_provenance_failures = []
    full_resolution = None

    for definition in lod.LOD_DEFINITIONS:
        level = definition["level"]
        land = pyogrio.read_dataframe(lod.LOD_GPKG, layer=f"land_lod{level}")
        coast = pyogrio.read_dataframe(lod.LOD_GPKG, layer=f"coastline_lod{level}")
        land_frames[level] = land
        coast_frames[level] = coast
        coast_lookup = dict(zip(coast.coastline_id, coast.geometry))
        coastline_from_land_mismatches = []
        for feature in land.itertuples(index=False):
            for part_index, polygon in enumerate(feature.geometry.geoms):
                base_id = next(
                    row.base_coastline_id
                    for row in coast.itertuples(index=False)
                    if row.land_feature_id == feature.feature_id and int(row.part_index) == part_index
                )
                coast_id = f"{base_id}-lod{level}"
                if coast_id not in coast_lookup or not coordinate_equal(LineString(polygon.exterior.coords), coast_lookup[coast_id]):
                    coastline_from_land_mismatches.append(coast_id)

        json_level = data["levels"][level]
        registry = json_level["coastline_registry"]
        for coast_id, line in coast_lookup.items():
            if coast_id not in registry or not coordinate_equal(line, LineString(registry[coast_id]["points"])):
                json_mismatches.append(coast_id)
        shared_profiles = (
            json_level["render_profiles"]["normal_display"]
            == json_level["render_profiles"]["selection_display"]
            == {"registry": "coastline_registry", "id_list": "visible_coastline_ids"}
        )
        level_checks[str(level)] = {
            "valid": bool(land.geometry.is_valid.all()),
            "empty_count": int(land.geometry.is_empty.sum()),
            "overlap_count": overlap_count(land),
            "feature_count": len(land),
            "coastline_count": len(coast),
            "visible_feature_count": int(land.visible.sum()),
            "coastline_from_land_mismatch_count": len(coastline_from_land_mismatches),
            "shared_render_profiles": shared_profiles,
        }
        if level == 4:
            full_resolution = {
                row.base_coastline_id: row.geometry for row in coast.itertuples(index=False)
            }

    for level, coast in coast_frames.items():
        for row in coast.itertuples(index=False):
            master_line = full_resolution[row.base_coastline_id]
            master_vertices = set(master_line.coords)
            if any(point not in master_vertices for point in row.geometry.coords):
                point_provenance_failures.append(row.coastline_id)

    transitions = []
    for coarse_level in range(4):
        fine_level = coarse_level + 1
        coarse = {row.base_coastline_id: row.geometry for row in coast_frames[coarse_level].itertuples(index=False)}
        fine = {row.base_coastline_id: row.geometry for row in coast_frames[fine_level].itertuples(index=False)}
        maximum_hausdorff = 0.0
        maximum_anchor_shift = 0.0
        for coast_id, coarse_line in coarse.items():
            fine_line = fine[coast_id]
            maximum_hausdorff = max(maximum_hausdorff, coarse_line.hausdorff_distance(fine_line))
            for point in coarse_line.coords:
                maximum_anchor_shift = max(maximum_anchor_shift, Point(point).distance(fine_line))
        coarse_tolerance = lod.LOD_DEFINITIONS[coarse_level]["simplify_tolerance_px"]
        fine_tolerance = lod.LOD_DEFINITIONS[fine_level]["simplify_tolerance_px"]
        # preserve_topology may make Hausdorff distance larger than the local
        # Douglas-Peucker perpendicular tolerance. Bound each transition to
        # twice the incremental tolerance while requiring retained anchors to
        # remain exactly on the next detailed coastline.
        allowed = 2.0 * (coarse_tolerance - fine_tolerance) + 1e-9
        transitions.append(
            {
                "from_lod": coarse_level,
                "to_lod": fine_level,
                "maximum_hausdorff_distance_px": maximum_hausdorff,
                "allowed_distance_px": allowed,
                "maximum_retained_anchor_shift_px": maximum_anchor_shift,
                "passed": maximum_hausdorff <= allowed and maximum_anchor_shift <= 1e-9,
            }
        )

    phase_c_full = pyogrio.read_dataframe(lod.phase_c.COAST_GPKG, layer=lod.phase_c.COAST_GAME_LAYER)
    phase_c_lookup = dict(zip(phase_c_full.coastline_id, phase_c_full.geometry))
    detailed_mismatches = [
        coast_id for coast_id, line in full_resolution.items()
        if coast_id not in phase_c_lookup or not coordinate_equal(line, phase_c_lookup[coast_id])
    ]

    with sqlite3.connect(lod.LOD_GPKG) as connection:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    layers = sorted(row[0] for row in pyogrio.list_layers(lod.LOD_GPKG))
    expected_layers = sorted(
        name for level in range(5) for name in (f"land_lod{level}", f"coastline_lod{level}")
    )

    checks = {
        "five_lod_levels": {"passed": len(data["levels"]) == 5 and sorted(land_frames) == list(range(5))},
        "all_features_retained_at_every_level": {
            "passed": all(item["feature_count"] == 154 for item in level_checks.values()),
            "counts": {key: value["feature_count"] for key, value in level_checks.items()},
        },
        "topology_valid_empty_and_overlap_free": {
            "passed": all(item["valid"] and item["empty_count"] == 0 and item["overlap_count"] == 0 for item in level_checks.values()),
            "levels": level_checks,
        },
        "coastline_generated_from_same_lod_polygon": {
            "passed": all(item["coastline_from_land_mismatch_count"] == 0 for item in level_checks.values()),
        },
        "normal_selection_share_points": {
            "passed": all(item["shared_render_profiles"] for item in level_checks.values()),
        },
        "json_matches_geopackage_coastlines": {"passed": not json_mismatches, "mismatches": json_mismatches},
        "lod_vertices_provenance_from_detailed_master": {
            "passed": not point_provenance_failures,
            "failures": point_provenance_failures,
        },
        "detailed_lod_matches_phase_c_exactly": {"passed": not detailed_mismatches, "mismatches": detailed_mismatches},
        "lod_transition_difference_within_budget": {
            "passed": all(item["passed"] for item in transitions),
            "transitions": transitions,
        },
        "geopackage_integrity_and_layers": {
            "passed": integrity == "ok" and layers == expected_layers,
            "integrity": integrity,
            "layers": layers,
        },
        "deterministic_regeneration_hashes": {"passed": first == second, "first": first, "second": second},
    }
    result = {"phase": "D", "all_passed": all(item["passed"] for item in checks.values()), "checks": checks}
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"all_passed": result["all_passed"], "checks": len(checks), "transitions": transitions}, indent=2))
    if not result["all_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
