"""Verify Phase P4 review artifacts and approval isolation."""

from __future__ import annotations

import json

from PIL import Image

import build_phase_p4_manual_review as p4

OUTPUT = p4.OUT_DIR / "p4_validation_report.json"


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    report = json.loads(p4.REPORT_PATH.read_text(encoding="utf-8"))
    registry = json.loads(p4.REVIEW_REGISTRY.read_text(encoding="utf-8"))
    expected_scopes = ["national", *p4.REVIEW_ORDER]
    require(list(registry["scopes"]) == expected_scopes, "review scope order differs")
    require(registry["accepted_region_ids"] == [], "a region was accepted without user approval")
    require(registry["all_regions_accepted"] is False, "all regions marked accepted")
    require(all(registry["scopes"][scope]["status"] == "pending" for scope in expected_scopes), "non-pending review scope exists")
    require(report["national_acceptance_policy_enforced"] is True, "national isolation policy absent")
    image_count = 0
    for scope in expected_scopes:
        review_items = p4.OUT_DIR / scope / "review_items.json"
        require(review_items.exists(), f"missing review item index: {scope}")
        for image_id in p4.IMAGE_TYPES:
            path = p4.OUT_DIR / scope / f"{image_id}.png"
            require(path.exists(), f"missing QA image: {scope}/{image_id}")
            with Image.open(path) as image:
                require(image.size == (p4.WIDTH, p4.HEIGHT), f"wrong QA dimensions: {path}")
            require(p4.sha256(path) == report["outputs"]["image_sha256"][path.relative_to(p4.ROOT).as_posix()], f"QA hash mismatch: {path}")
            image_count += 1
    require(image_count == 70, "P4 must contain 70 review images")
    require(p4.sha256(p4.p2.MASTER_LAND) == report["source_hashes"]["canonical_land"], "canonical land changed")
    require(p4.sha256(p4.p2.COAST_GPKG) == report["source_hashes"]["canonical_coastline"], "canonical coastline changed")
    result = {
        "phase": "P4", "status": "pass_pending_user_review",
        "checks": {
            "seven_views_per_scope": "pass", "national_and_nine_regional_scopes": "pass",
            "review_order": "pass", "all_scopes_pending": "pass",
            "unapproved_regions_excluded_from_accepted_national_set": "pass",
            "artifact_hashes": "pass", "canonical_inputs_immutable": "pass",
        },
        "counts": {"scopes": len(expected_scopes), "images": image_count, "accepted_scopes": 0},
    }
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
