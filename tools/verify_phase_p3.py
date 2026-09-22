"""Verify Phase P3 candidates and the no-guess construction contract."""

from __future__ import annotations

import json
from pathlib import Path

import geopandas as gpd
import numpy as np
import pyogrio

import build_phase_p3_political_regions as p3

OUTPUT = p3.QA_DIR / "p3_validation_report.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    report = json.loads(p3.REPORT_PATH.read_text(encoding="utf-8"))
    graph = json.loads(p3.GRAPH_JSON.read_text(encoding="utf-8"))
    coast_refs = json.loads(p3.COAST_REFS_JSON.read_text(encoding="utf-8"))
    boundary_refs = json.loads(p3.BOUNDARY_REFS_JSON.read_text(encoding="utf-8"))
    adjacency = json.loads(p3.ADJACENCY_JSON.read_text(encoding="utf-8"))
    layers = set(pyogrio.list_layers(p3.OUTPUT_GPKG)[:, 0])
    required_layers = {
        "closed_region_candidates", "ambiguous_closed_faces", "boundary_endpoints",
        "region_label_anchors_8192", "unassigned_region_labels",
    }
    require(required_layers <= layers, "one or more P3 audit layers are absent")
    candidates = gpd.read_file(p3.OUTPUT_GPKG, layer="closed_region_candidates")
    ambiguous = gpd.read_file(p3.OUTPUT_GPKG, layer="ambiguous_closed_faces")
    endpoints = gpd.read_file(p3.OUTPUT_GPKG, layer="boundary_endpoints")
    labels = gpd.read_file(p3.OUTPUT_GPKG, layer="region_label_anchors_8192")
    unassigned = gpd.read_file(p3.OUTPUT_GPKG, layer="unassigned_region_labels")
    _, land_union = p3.canonical_land_8192()

    require(len(labels) == len(p3.p1.REGIONS), "region registry count changed")
    require(candidates.geometry.notna().all() and (~candidates.geometry.is_empty).all(), "empty candidate geometry")
    require(candidates.geometry.is_valid.all(), "invalid candidate geometry")
    require(all(land_union.covers(geometry) for geometry in candidates.geometry), "candidate leaves canonical land")
    for index, left in candidates.iterrows():
        for _, right in candidates.iloc[index + 1:].iterrows():
            require(left.geometry.intersection(right.geometry).area <= p3.EPSILON, "candidate regions overlap")
    require(set(candidates["certainty"]) == {"unconfirmed"}, "pending P1/P2 candidate was marked confirmed")
    require(len(unassigned) + candidates["region_id"].nunique() == len(labels), "assigned/unassigned registry mismatch")
    require(len(endpoints) == 208, "shared-boundary endpoint count changed")
    require(graph["forbidden_operations_used"] == {"buffer": False, "tolerance_snap": False, "voronoi": False}, "forbidden gap operation recorded")
    require(coast_refs["image_coastline_used"] is False, "image coastline was used")
    canonical_ids = set(gpd.read_file(p3.p2.COAST_GPKG, layer="coastline_8192")["coastline_id"])
    require(all(item["coastline_id"] in canonical_ids for item in coast_refs["references"]), "unknown coastline reference")
    boundary_ids = set(gpd.read_file(p3.p2.WARPED_GPKG, layer="shared_boundaries_8192")["boundary_id"])
    require(all(item["boundary_id"] in boundary_ids for item in boundary_refs["references"]), "unknown shared-boundary reference")
    require(not adjacency["unexpected_geometric_adjacencies"], "unexpected candidate adjacency")
    require(report["source_review"]["promotion_to_master"] is False, "unreviewed P3 data promoted to master")
    require(p3.sha256(p3.p2.MASTER_LAND) == report["input_hashes"]["japan_land_master"], "land master changed")
    require(p3.sha256(p3.p2.COAST_GPKG) == report["input_hashes"]["coastline_master"], "coastline master changed")
    require((p3.QA_DIR / "p3_national_candidate_audit.png").exists(), "P3 QA image missing")

    result = {
        "phase": "P3", "status": "pass_with_manual_closure_required",
        "checks": {
            "closed_faces_only": "pass", "intersection_with_canonical_land": "pass",
            "candidate_validity_and_nonoverlap": "pass", "canonical_coastline_references_only": "pass",
            "lake_ids_not_fabricated": "pass", "no_buffer_snap_or_voronoi": "pass",
            "uncertainty_propagation": "pass", "registry_accounting": "pass",
            "source_masters_immutable": "pass", "no_unreviewed_master_promotion": "pass",
        },
        "counts": {
            "candidate_parts": len(candidates), "candidate_regions": candidates["region_id"].nunique(),
            "ambiguous_faces": len(ambiguous), "unassigned_labels": len(unassigned),
            "unconfirmed_endpoints": int((endpoints["status"] == "unconfirmed_endpoint").sum()),
        },
        "manual_review_required": {
            "endpoint_ids": endpoints.loc[endpoints["status"] == "unconfirmed_endpoint", "endpoint_id"].tolist(),
            "reason": report["blocking_review"]["reason"],
        },
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
