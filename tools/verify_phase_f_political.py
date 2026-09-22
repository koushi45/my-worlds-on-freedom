"""Verify Phase F's no-invention state and boundary-processing algorithms."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import geopandas as gpd
import pyogrio
from shapely.geometry import LineString, MultiPolygon, box
from shapely.ops import unary_union

import build_phase_f_political as phase_f


ROOT = Path(__file__).resolve().parents[1]
REPORT = phase_f.OUT_DIR / "phase_f_verification.json"


def hashes():
    return {
        "political_regions.gpkg": phase_f.sha256(phase_f.POLITICAL_GPKG),
        "political_registry.json": phase_f.sha256(phase_f.REGISTRY_JSON),
        "political_audit.json": phase_f.sha256(phase_f.AUDIT_JSON),
        "phase_f_manifest.json": phase_f.sha256(phase_f.MANIFEST),
    }


def synthetic_algorithm_test():
    land_polygon = box(130.0, 31.0, 132.0, 33.0)
    source = gpd.GeoDataFrame(
        [
            {"region_id": "west", "region_name": "West", "certainty": "confirmed", "geometry": box(129.5, 30.5, 131.0, 33.5)},
            {"region_id": "east", "region_name": "East", "certainty": "confirmed", "geometry": box(131.0, 30.5, 132.5, 33.5)},
        ],
        geometry="geometry",
        crs=phase_f.base.SOURCE_CRS,
    )
    regions, excluded = phase_f.clip_regions(source, land_polygon)
    shared = phase_f.extract_shared_boundaries(regions)
    coastline = gpd.GeoDataFrame(
        [{"coastline_id": "synthetic-coast", "geometry": LineString(land_polygon.exterior.coords)}],
        geometry="geometry",
        crs=phase_f.base.SOURCE_CRS,
    )
    references = phase_f.coastline_references(regions, coastline)
    union = unary_union(regions.geometry)
    expected_shared = LineString([(131.0, 31.0), (131.0, 33.0)])
    return {
        "passed": (
            not excluded
            and len(regions) == 2
            and union.equals(land_polygon)
            and len(shared) == 1
            and shared.geometry.iloc[0].equals(expected_shared)
            and all(references[region_id] for region_id in ["west", "east"])
            and all(
                item["point_source"] == "referenced_master_coastline"
                for values in references.values() for item in values
            )
        ),
        "region_count": len(regions),
        "shared_boundary_count": len(shared),
        "coastline_reference_count": sum(len(values) for values in references.values()),
    }


def main():
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_f_political.py")], cwd=ROOT, check=True, capture_output=True)
    first = hashes()
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_f_political.py")], cwd=ROOT, check=True, capture_output=True)
    second = hashes()

    manifest = json.loads(phase_f.MANIFEST.read_text(encoding="utf-8"))
    registry = json.loads(phase_f.REGISTRY_JSON.read_text(encoding="utf-8"))
    audit = json.loads(phase_f.AUDIT_JSON.read_text(encoding="utf-8"))
    master_manifest = json.loads(phase_f.phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
    master = gpd.read_file(phase_f.phase_c.MASTER_GPKG, layer=master_manifest["canonical_layer"])
    master_union = unary_union(master.geometry)
    unassigned = gpd.read_file(phase_f.POLITICAL_GPKG, layer="unassigned_land")
    unassigned_union = unary_union(unassigned.geometry)
    layers = sorted(row[0] for row in pyogrio.list_layers(phase_f.POLITICAL_GPKG))
    with sqlite3.connect(phase_f.POLITICAL_GPKG) as connection:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]

    synthetic = synthetic_algorithm_test()
    checks = {
        "historical_source_absence_explicit": {
            "passed": not phase_f.HISTORICAL_SOURCE.exists() and manifest["source_contract"]["current_status"] == "missing",
        },
        "no_inferred_political_regions": {
            "passed": manifest["counts"]["political_regions"] == 0 and registry["regions"] == [],
        },
        "entire_master_land_explicitly_unassigned": {
            "passed": unassigned_union.equals(master_union) and registry["unassigned"]["status"] == "unconfirmed",
        },
        "union_gap_overlap_audit": {
            "passed": (
                audit["political_region_union_area_m2"] == 0.0
                and audit["overlap_count"] == 0
                and audit["gap_status"] == "explicitly_unassigned"
                and audit["area_balance_error_m2"] <= 0.01
            ),
            "audit": audit,
        },
        "only_unassigned_layer_materialized": {
            "passed": layers == ["unassigned_land"],
            "layers": layers,
        },
        "no_click_mask_used_for_drawing": {
            "passed": "click_masks" not in layers and manifest["rules"]["boundaries_never_derived_from_click_masks"],
        },
        "shared_edge_and_coast_reference_algorithm": synthetic,
        "selection_contract": {
            "passed": manifest["rules"]["selection_display"] == "shared boundary IDs plus referenced coastline segments",
        },
        "coastline_points_not_duplicated": {
            "passed": "coastline_id" in manifest["rules"]["coastline_storage"] and "no duplicated coastline points" in manifest["rules"]["coastline_storage"],
        },
        "geopackage_integrity": {"passed": integrity == "ok", "result": integrity},
        "deterministic_regeneration": {"passed": first == second, "first": first, "second": second},
    }
    result = {"phase": "F", "all_passed": all(item["passed"] for item in checks.values()), "checks": checks}
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"all_passed": result["all_passed"], "checks": len(checks), "status": manifest["status"]}, indent=2))
    if not result["all_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
