"""Verify phase P1 work products without promoting them to master data."""

from __future__ import annotations

import json
from pathlib import Path

import geopandas as gpd
import pyogrio
from PIL import Image

from build_phase_p1_trace import (
    OUTPUT_GPKG,
    OUTPUT_REPORT,
    OUTPUT_REVIEW_LOG,
    QA_DIR,
    REGIONS,
    SOURCE_IMAGE,
    SOURCE_MANIFEST,
    sha256,
)


REQUIRED_COLUMNS = {
    "boundary_id", "left_region_id", "right_region_id",
    "source_pixel_start", "source_pixel_end", "certainty",
    "trace_method", "review_status", "note", "geometry",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    source_manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    report = json.loads(OUTPUT_REPORT.read_text(encoding="utf-8"))
    review = json.loads(OUTPUT_REVIEW_LOG.read_text(encoding="utf-8"))

    require(sha256(SOURCE_IMAGE) == source_manifest["asset"]["sha256"], "P0 source hash changed")
    with Image.open(SOURCE_IMAGE) as image:
        require(image.size == (1280, 1341), "source image is not 1280 x 1341")

    layers = set(pyogrio.list_layers(OUTPUT_GPKG)[:, 0])
    require(layers == {"shared_boundaries", "junction_nodes", "region_labels"}, f"unexpected GPKG layers: {layers}")
    boundaries = gpd.read_file(OUTPUT_GPKG, layer="shared_boundaries")
    require(REQUIRED_COLUMNS <= set(boundaries.columns), "mandatory shared-boundary attributes are missing")
    require(boundaries["boundary_id"].is_unique, "boundary_id values are not unique")
    require(not boundaries.empty, "shared boundary layer is empty")
    require(boundaries.geometry.notna().all() and (~boundaries.geometry.is_empty).all(), "empty boundary geometry")
    require(boundaries.geometry.is_valid.all(), "invalid boundary geometry")
    require((boundaries.geometry.geom_type == "LineString").all(), "non-LineString boundary geometry")
    require((boundaries["left_region_id"] != boundaries["right_region_id"]).all(), "same region on both sides")
    require(set(boundaries["certainty"]) <= {"confirmed", "probable", "unconfirmed"}, "invalid certainty")
    require(set(boundaries["trace_method"]) <= {"manual", "assisted"}, "invalid trace_method")
    require(set(boundaries["review_status"]) <= {"pending", "accepted", "rejected"}, "invalid review_status")

    valid_ids = {f"jp-ryoseikoku-{number:02d}-{slug}" for number, (slug, _) in REGIONS.items()}
    require(set(boundaries["left_region_id"]) <= valid_ids, "unknown left_region_id")
    require(set(boundaries["right_region_id"]) <= valid_ids, "unknown right_region_id")
    for geometry in boundaries.geometry:
        min_x, min_y, max_x, max_y = geometry.bounds
        require(0 <= min_x <= max_x < 1280 and 0 <= min_y <= max_y < 1341, "geometry outside source pixels")

    labels = gpd.read_file(OUTPUT_GPKG, layer="region_labels")
    require(len(labels) == 69, "region label registry does not contain all 69 source IDs")
    require(labels["number"].is_unique, "duplicate source region number")
    require(int(labels["component_conflict"].sum()) == 0, "region/component assignment conflict")

    for name, size in (("trace_overlay_100.png", (1280, 1341)),
                       ("trace_overlay_200.png", (2560, 2682)),
                       ("trace_overlay_400.png", (5120, 5364))):
        with Image.open(QA_DIR / name) as image:
            require(image.size == size, f"{name} has wrong dimensions")

    require(report["source"]["warped_before_trace"] is False, "source was marked as warped")
    require(report["counts"]["boundaries"] == len(boundaries), "report/GPKG count mismatch")
    require(review["review_status"] == "pending_user_acceptance", "unexpected promotion status")

    validation = {
        "phase": "P1",
        "status": "pass_pending_user_acceptance",
        "checks": {
            "source_hash_and_dimensions": "pass",
            "required_layers_and_attributes": "pass",
            "line_geometry_validity_and_bounds": "pass",
            "region_id_registry_and_component_conflicts": "pass",
            "qa_scale_dimensions": "pass",
            "no_pretrace_warp": "pass",
            "master_promotion_blocked": "pass",
        },
        "counts": {"boundaries": len(boundaries), "region_labels": len(labels)},
    }
    output = QA_DIR / "p1_validation_report.json"
    output.write_text(json.dumps(validation, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(validation, ensure_ascii=False))


if __name__ == "__main__":
    main()
