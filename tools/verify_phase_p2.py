"""Automated checks for Phase P2 regional rubber-sheet work products."""

from __future__ import annotations

import json
from pathlib import Path

import geopandas as gpd
import numpy as np
import pyogrio

import build_phase_p2_regional_warp as p2


OUTPUT = p2.QA_DIR / "p2_validation_report.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    report = json.loads(p2.REPORT_PATH.read_text(encoding="utf-8"))
    required_units = set(p2.UNITS)

    control_layers = set(pyogrio.list_layers(p2.CONTROL_GPKG)[:, 0])
    require(control_layers == {"image_control_points", "game_control_points_8192", "warp_units"}, "control GPKG layers differ")
    source = gpd.read_file(p2.CONTROL_GPKG, layer="image_control_points")
    target = gpd.read_file(p2.CONTROL_GPKG, layer="game_control_points_8192")
    units = gpd.read_file(p2.CONTROL_GPKG, layer="warp_units")
    require(set(units["warp_unit"]) == required_units, "one or more required correction units are absent")
    require(set(source["warp_unit"]) == required_units, "one or more units have no control records")
    require(source["control_id"].is_unique and target["control_id"].is_unique, "control IDs are not unique")
    require(list(source["control_id"]) == list(target["control_id"]), "source/target control ordering differs")

    required_columns = {
        "control_id", "warp_unit", "source_x_px", "source_y_px",
        "target_x_8192", "target_y_8192", "basis", "evidence",
        "accepted", "residual_input_px", "residual_target_px", "review_status",
    }
    require(required_columns <= set(source.columns), "mandatory control attributes are absent")
    require(np.allclose(source.geometry.x, source["source_x_px"]) and np.allclose(source.geometry.y, source["source_y_px"]), "source control geometry mismatch")
    require(np.allclose(target.geometry.x, target["target_x_8192"]) and np.allclose(target.geometry.y, target["target_y_8192"]), "target control geometry mismatch")
    accepted = source[source["accepted"] == 1]
    require(not accepted.empty, "no accepted controls")
    for unit_id in required_units:
        values = accepted.loc[accepted["warp_unit"] == unit_id, "residual_input_px"].to_numpy()
        require(len(values) >= 8, f"{unit_id} has fewer than eight accepted controls")
        require(float(np.median(values)) <= 1.5, f"{unit_id} median residual exceeds 1.5 input pixels")
        require(float(np.percentile(values, 95)) <= 4.0, f"{unit_id} p95 residual exceeds 4 input pixels")

    warped_layers = set(pyogrio.list_layers(p2.WARPED_GPKG)[:, 0])
    require(warped_layers == {"shared_boundaries_8192", "junction_nodes_8192"}, "warped GPKG layers differ")
    boundaries = gpd.read_file(p2.WARPED_GPKG, layer="shared_boundaries_8192")
    nodes = gpd.read_file(p2.WARPED_GPKG, layer="junction_nodes_8192")
    p1_boundaries = gpd.read_file(p2.P1_GPKG, layer="shared_boundaries")
    p1_nodes = gpd.read_file(p2.P1_GPKG, layer="junction_nodes")
    require(len(boundaries) == len(p1_boundaries), "P1/P2 boundary count differs")
    require(len(nodes) == len(p1_nodes), "P1/P2 junction count differs")
    require(list(boundaries["boundary_id"]) == list(p1_boundaries["boundary_id"]), "boundary IDs changed")
    require(boundaries.geometry.notna().all() and (~boundaries.geometry.is_empty).all(), "empty warped boundary")
    require(boundaries.geometry.is_valid.all(), "invalid warped boundary")
    min_x, min_y, max_x, max_y = boundaries.total_bounds
    require(0 <= min_x <= max_x < 8192 and 0 <= min_y <= max_y < 8192, "warped geometry outside game coordinates")

    nonsimple = boundaries[~boundaries.geometry.is_simple]
    require((nonsimple["certainty"] == "probable").all(), "a confirmed line became non-simple")
    require(report["rules"]["single_global_affine_adopted"] is False, "global affine was adopted")
    require(report["rules"]["canonical_land_or_coast_modified"] is False, "canonical data changed")
    require(report["rules"]["sea_snap_applied"] is False, "sea snapping was applied")
    require(report["counts"]["fallback_point_transforms"] == 0, "points fell outside piecewise mesh")
    require(report["counts"]["inverted_triangles"] == 0, "piecewise mesh contains inversion")
    if report["counts"]["initial_inverted_triangles"]:
        require(bool(report["rules"]["tps_candidates"]), "TPS was not compared after initial inversion")
    require(p2.sha256(p2.MASTER_LAND) == report["source_hashes"]["japan_land_master"], "japan_land hash changed")
    require(p2.sha256(p2.COAST_GPKG) == report["source_hashes"]["coastline_master"], "coastline hash changed")

    result = {
        "phase": "P2", "status": "pass_pending_manual_review",
        "checks": {
            "required_regional_units": "pass", "control_attributes_and_dual_coordinates": "pass",
            "regional_residual_targets": "pass", "piecewise_mesh_no_inversion": "pass",
            "p1_identity_and_geometry_counts": "pass", "canonical_inputs_immutable": "pass",
            "no_global_affine_adoption": "pass", "no_mechanical_sea_snap": "pass",
            "tps_compared_when_required": "pass",
        },
        "counts": {
            "accepted_controls": len(accepted), "boundaries": len(boundaries), "junction_nodes": len(nodes),
            "probable_non_simple_source_lines": len(nonsimple),
            "sea_endpoint_reviews": len(report["sea_excursion_review"]),
        },
        "manual_review_required": {
            "probable_non_simple_boundary_ids": nonsimple["boundary_id"].tolist(),
            "sea_excursion_items": report["sea_excursion_review"],
        },
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
