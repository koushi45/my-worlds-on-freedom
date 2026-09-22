"""Verify canonical coastline ownership and the final district geometry."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from shapely.geometry import LineString, Polygon
from shapely.ops import substring, unary_union
from shapely.strtree import STRtree


ROOT = Path(__file__).resolve().parents[1]
DISTRICT_PATH = ROOT / "data/derived/scenarios/independent_districts_1546.json"
REGISTRY_PATH = ROOT / "data/derived/scenarios/district_coastline_references_1546.json"
LAND_PATH = ROOT / "data/derived/land_masks/land_master_8192.json"
BASELINE_PATH = ROOT / "data/work/districts/coast_alignment/baseline_20260919/input_hashes.json"
BASELINE_DISTRICTS = ROOT / "data/work/districts/coast_alignment/baseline_20260919/data/derived/scenarios/independent_districts_1546.json"
REPORT_PATH = ROOT / "data/work/districts/coast_alignment/verification_report.json"
DOUBLE_LENGTH_TOLERANCE = 1e-7
DOUBLE_AREA_FLOOR = 1e-5
FLOAT32_COORDINATE_TOLERANCE = 1e-3


def read(path: Path):
    return json.loads(path.read_text(encoding="utf8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def geom(record):
    return unary_union([Polygon(polygon[0], polygon[1:]) for polygon in record["polygons"]])


def arc(line: LineString, start: float, end: float, wrap: bool):
    if not wrap:
        return substring(line, start, end)
    return unary_union([substring(line, start, line.length), substring(line, 0.0, end)])


def main() -> None:
    districts = read(DISTRICT_PATH)
    registry = read(REGISTRY_PATH)
    land = read(LAND_PATH)
    baseline = read(BASELINE_DISTRICTS)
    geometries = {key: geom(value) for key, value in districts["regions"].items()}
    failures = []
    coast_results = {}

    if registry["source_land_master_sha256"] != digest(LAND_PATH):
        failures.append("land master hash differs from coastline registry")

    references_by_coast = {}
    for reference in registry["references"]:
        references_by_coast.setdefault(reference["coastline_id"], []).append(reference)
        if reference["district_id"] not in geometries:
            failures.append(f"unknown district reference: {reference['arc_id']}")

    for coast_id in registry["coastline_ids"]:
        raw = land["coastlines"][coast_id]["points"]
        line = LineString(raw)
        intervals = []
        boundary_difference = 0.0
        for reference in references_by_coast.get(coast_id, []):
            ranges = [(reference["start_distance"], reference["end_distance"])]
            if reference["wrap"]:
                ranges = [(reference["start_distance"], line.length), (0.0, reference["end_distance"])]
            intervals.extend(ranges)
            expected = arc(line, reference["start_distance"], reference["end_distance"], reference["wrap"])
            boundary_difference += expected.difference(
                geometries[reference["district_id"]].boundary.buffer(DOUBLE_LENGTH_TOLERANCE)
            ).length
        intervals.sort()
        gap = intervals[0][0] if intervals else line.length
        overlap = 0.0
        cursor = 0.0
        for start, end in intervals:
            if start > cursor:
                gap += start - cursor
            elif start < cursor:
                overlap += cursor - start
            cursor = max(cursor, end)
        gap += max(0.0, line.length - cursor)
        coast_results[coast_id] = {
            "length": line.length,
            "reference_count": len(references_by_coast.get(coast_id, [])),
            "gap_length": gap,
            "overlap_length": overlap,
            "boundary_difference_length": boundary_difference,
        }
        if gap > DOUBLE_LENGTH_TOLERANCE or overlap > DOUBLE_LENGTH_TOLERANCE:
            failures.append(f"coast interval discontinuity: {coast_id}")
        if boundary_difference > DOUBLE_LENGTH_TOLERANCE:
            failures.append(f"district boundary differs from canonical coast: {coast_id}")

    mainland_ids = districts["coast_alignment"]["coastline_ids"]
    mainland = unary_union([Polygon(land["coastlines"][coast_id]["points"]) for coast_id in mainland_ids])
    mainland_districts = [item for item in geometries.values() if item.intersection(mainland).area > 1e-8]
    district_union = unary_union(mainland_districts)
    area_tolerance = max(DOUBLE_AREA_FLOOR, mainland.area * 1e-9)
    land_gap = mainland.difference(district_union).area
    sea_excess = district_union.difference(mainland).area
    if land_gap > area_tolerance:
        failures.append(f"mainland unassigned area {land_gap}")
    if sea_excess > area_tolerance:
        failures.append(f"district sea excess {sea_excess}")

    invalid = [key for key, item in geometries.items() if item.is_empty or not item.is_valid]
    if invalid:
        failures.append(f"invalid districts: {invalid[:5]}")

    keys = sorted(geometries)
    values = [geometries[key] for key in keys]
    tree = STRtree(values)
    overlap_area = 0.0
    overlap_pairs = []
    for index, item in enumerate(values):
        for other in tree.query(item):
            other = int(other)
            if other <= index:
                continue
            area = item.intersection(values[other]).area
            if area > DOUBLE_AREA_FLOOR:
                overlap_area += area
                overlap_pairs.append([keys[index], keys[other], area])
    if overlap_pairs:
        failures.append(f"district overlaps: {len(overlap_pairs)}")

    old_ids = set(baseline["regions"])
    new_ids = set(districts["regions"])
    old_topology = baseline["connectivity"]
    new_topology = districts["connectivity"]
    expected_ids = (old_ids | set(new_topology["extra_districts"])) - set(new_topology["retired_district_ids"])
    if new_ids != expected_ids:
        failures.append("district ID policy changed")
    if old_topology.get("original_ids") != new_topology.get("original_ids"):
        failures.append("original district IDs changed")

    island_failures = []
    for district_id, extra in new_topology["extra_districts"].items():
        actual = [polygon[0] for polygon in districts["regions"][district_id]["polygons"]]
        expected = [land["coastlines"][coast_id]["points"] for coast_id in extra["coastline_ids"]]
        if actual != expected or not extra.get("coastline_only"):
            island_failures.append(district_id)
    if island_failures:
        failures.append(f"curated island mismatch: {island_failures}")

    report = {
        "schema_version": 1,
        "verified_at_utc": datetime.now(timezone.utc).isoformat(),
        "status": "passed" if not failures else "failed",
        "double_precision_tolerances": {
            "length": DOUBLE_LENGTH_TOLERANCE,
            "area_floor": DOUBLE_AREA_FLOOR,
            "area_relative": 1e-9,
        },
        "runtime_float32_coordinate_tolerance": FLOAT32_COORDINATE_TOLERANCE,
        "input_hash_baseline": str(BASELINE_PATH.relative_to(ROOT)).replace("\\", "/"),
        "district_sha256": digest(DISTRICT_PATH),
        "registry_sha256": digest(REGISTRY_PATH),
        "district_count": len(geometries),
        "coastal_interval_count": len(registry["references"]),
        "unresolved_registry_items": registry["unresolved"],
        "coastlines": coast_results,
        "mainland_area": mainland.area,
        "mainland_unassigned_area": land_gap,
        "district_sea_excess_area": sea_excess,
        "overlap_area": overlap_area,
        "overlap_pairs": overlap_pairs,
        "invalid_districts": invalid,
        "curated_island_failures": island_failures,
        "failures": failures,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    print(json.dumps({"status": report["status"], "failures": failures}, ensure_ascii=False))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
