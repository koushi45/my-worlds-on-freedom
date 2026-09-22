"""Build Phase P3 political-region candidates without geometric guesswork.

Only the P2 transformed shared borders and the immutable canonical coastline
participate in polygonisation.  No buffer, tolerance snap, Voronoi fill, or
raster-derived coastline is used.  Faces that cannot be assigned to exactly
one source province label remain review features instead of being guessed.
"""

from __future__ import annotations

import hashlib
import json
import math
import platform
import sqlite3
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import geopandas as gpd
import numpy as np
import pyogrio
import shapely
from PIL import Image, ImageDraw
from shapely.geometry import LineString, MultiLineString, MultiPolygon, Point, Polygon
from shapely.ops import linemerge, polygonize_full, unary_union

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_japan_land_base as base  # noqa: E402
import build_phase_p1_trace as p1  # noqa: E402
import build_phase_p2_regional_warp as p2  # noqa: E402

WORK_DIR = ROOT / "data/work/political"
QA_DIR = ROOT / "data/derived/political/qa/p3"
OUTPUT_GPKG = WORK_DIR / "political_regions_candidate.gpkg"
OUTPUT_GEOJSON = WORK_DIR / "political_regions_candidate.geojson"
GRAPH_JSON = WORK_DIR / "political_planar_graph.json"
COAST_REFS_JSON = WORK_DIR / "political_coastline_references.json"
BOUNDARY_REFS_JSON = WORK_DIR / "political_boundary_references.json"
ADJACENCY_JSON = WORK_DIR / "political_adjacency_audit.json"
REPORT_PATH = WORK_DIR / "p3_region_report.json"
FIXED_GPKG_TIMESTAMP = "2026-01-01T00:00:00.000Z"
EPSILON = 1e-8


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def normalize_gpkg(path: Path) -> None:
    with sqlite3.connect(path) as connection:
        connection.execute("UPDATE gpkg_contents SET last_change = ?", (FIXED_GPKG_TIMESTAMP,))
        connection.commit()
        connection.execute("VACUUM")


def line_parts(geometry):
    if geometry.is_empty:
        return []
    if isinstance(geometry, LineString):
        return [geometry]
    if isinstance(geometry, MultiLineString):
        return list(geometry.geoms)
    if hasattr(geometry, "geoms"):
        result = []
        for item in geometry.geoms:
            result.extend(line_parts(item))
        return result
    return []


def polygon_parts(geometry):
    if geometry.is_empty:
        return []
    if isinstance(geometry, Polygon):
        return [geometry]
    if isinstance(geometry, MultiPolygon):
        return list(geometry.geoms)
    if hasattr(geometry, "geoms"):
        result = []
        for item in geometry.geoms:
            result.extend(polygon_parts(item))
        return result
    return []


def transform_labels() -> gpd.GeoDataFrame:
    """Apply the persisted P2 piecewise-linear mesh to P1 label anchors."""
    controls = gpd.read_file(p2.CONTROL_GPKG, layer="image_control_points")
    records = []
    for row in controls.itertuples(index=False):
        record = row._asdict()
        record.pop("geometry")
        record["accepted"] = bool(record["accepted"])
        records.append(record)
    triangles, inverted = p2.build_mesh(records)
    if any(item["inverted"] for item in triangles) or inverted:
        raise RuntimeError("P2 control mesh contains an inverted triangle")
    # The fallback affine in P2 is intentionally an initial-search tool only.
    # Labels outside the accepted PWA mesh must therefore remain unresolved.
    warp = p2.PiecewiseWarp(triangles, np.asarray([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]]))

    transformed = []
    for row in gpd.read_file(p2.P1_GPKG, layer="region_labels").itertuples(index=False):
        source_point = Point(float(row.geometry.x), float(row.geometry.y))
        indices = warp.tree.query(source_point, predicate="intersects")
        geometry = None
        transform_status = "outside_p2_mesh"
        if len(indices):
            triangle = triangles[int(indices[0])]
            weights = p2.barycentric((source_point.x, source_point.y), triangle["source"])
            target = weights @ np.asarray(triangle["target"])
            geometry = Point(float(target[0]), float(target[1]))
            transform_status = "piecewise_linear"
        transformed.append({
            "region_id": row.region_id,
            "number": int(row.number),
            "name_ja": p1.REGIONS[int(row.number)][1],
            "source_x_px": float(row.geometry.x),
            "source_y_px": float(row.geometry.y),
            "transform_status": transform_status,
            "geometry": geometry,
        })
    return gpd.GeoDataFrame(transformed, geometry="geometry", crs=None)


def canonical_land_8192() -> tuple[gpd.GeoDataFrame, object]:
    land = gpd.read_file(p2.MASTER_LAND, layer="japan_land")
    bounds, scale, offset_x, offset_y, content_h = base.game_transform_definition()
    transformed = land.copy()
    transformed.geometry = transformed.geometry.map(
        lambda geometry: base.to_game_geometry(geometry, bounds, scale, offset_x, offset_y, content_h)
    )
    return transformed, transformed.geometry.union_all()


def segment_index(line: LineString, distance: float) -> int:
    coords = list(line.coords)
    travelled = 0.0
    for index, (start, end) in enumerate(zip(coords[:-1], coords[1:])):
        length = math.dist(start, end)
        if distance <= travelled + length + EPSILON:
            return index
        travelled += length
    return max(0, len(coords) - 2)


def coastline_references(face: Polygon, coasts: gpd.GeoDataFrame, part_id: str) -> list[dict]:
    records = []
    for coast in coasts.itertuples(index=False):
        overlap = face.boundary.intersection(coast.geometry)
        if isinstance(overlap, MultiLineString):
            overlap = linemerge(overlap)
        for sequence, part in enumerate(line_parts(overlap), start=1):
            if part.length <= EPSILON:
                continue
            start = Point(part.coords[0])
            end = Point(part.coords[-1])
            start_distance = float(coast.geometry.project(start))
            end_distance = float(coast.geometry.project(end))
            records.append({
                "part_id": part_id,
                "coastline_id": coast.coastline_id,
                "land_feature_id": coast.land_feature_id,
                "reference_part": sequence,
                "start_distance_8192": start_distance,
                "end_distance_8192": end_distance,
                "start_segment_index": segment_index(coast.geometry, start_distance),
                "end_segment_index": segment_index(coast.geometry, end_distance),
                "direction": "forward" if end_distance >= start_distance else "reverse",
                "point_hash": coast.point_hash,
            })
    return records


def boundary_references(face: Polygon, boundaries: gpd.GeoDataFrame, part_id: str) -> list[dict]:
    records = []
    for border in boundaries.itertuples(index=False):
        overlap = face.boundary.intersection(border.geometry)
        length = sum(item.length for item in line_parts(overlap))
        if length <= EPSILON:
            continue
        records.append({
            "part_id": part_id,
            "boundary_id": border.boundary_id,
            "left_region_id": border.left_region_id,
            "right_region_id": border.right_region_id,
            "length_8192": float(length),
            "source_certainty": border.certainty,
            "source_review_status": border.review_status,
        })
    return records


def endpoint_audit(boundaries: gpd.GeoDataFrame, coast_union) -> gpd.GeoDataFrame:
    records = []
    lines = list(boundaries.geometry)
    for row_index, row in enumerate(boundaries.itertuples(index=False)):
        for endpoint_name, coordinate in (("start", row.geometry.coords[0]), ("end", row.geometry.coords[-1])):
            point = Point(coordinate)
            connected_boundaries = []
            for other_index, other in enumerate(lines):
                if other_index == row_index:
                    continue
                if point.distance(other) <= EPSILON:
                    connected_boundaries.append(boundaries.iloc[other_index]["boundary_id"])
            coast_distance = float(point.distance(coast_union))
            on_coast = coast_distance <= EPSILON
            connected = bool(connected_boundaries) or on_coast
            records.append({
                "endpoint_id": f"{row.boundary_id}:{endpoint_name}",
                "boundary_id": row.boundary_id,
                "endpoint": endpoint_name,
                "status": "connected" if connected else "unconfirmed_endpoint",
                "on_canonical_coast": on_coast,
                "coast_distance_8192": coast_distance,
                "connected_boundary_ids": json.dumps(sorted(connected_boundaries), ensure_ascii=False),
                "geometry": point,
            })
    return gpd.GeoDataFrame(records, geometry="geometry", crs=None)


def render_qa(land_union, coasts, boundaries, candidates, ambiguous, endpoints) -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    scale = 0.25
    image = Image.new("RGB", (2048, 2048), (35, 62, 75))
    draw = ImageDraw.Draw(image, "RGBA")

    def path(coords):
        return [(int(round(x * scale)), int(round(y * scale))) for x, y in coords]

    for polygon in polygon_parts(land_union):
        draw.polygon(path(polygon.exterior.coords), fill=(247, 245, 237, 255))
    for row in ambiguous.itertuples(index=False):
        draw.polygon(path(row.geometry.exterior.coords), fill=(235, 164, 52, 60))
    for row in candidates.itertuples(index=False):
        draw.polygon(path(row.geometry.exterior.coords), fill=(69, 170, 110, 105))
    for coast in coasts.geometry:
        draw.line(path(coast.coords), fill=(35, 42, 45, 255), width=2)
    for border in boundaries.geometry:
        draw.line(path(border.coords), fill=(42, 67, 143, 255), width=2)
    for row in endpoints[endpoints["status"] == "unconfirmed_endpoint"].itertuples(index=False):
        x, y = path([(row.geometry.x, row.geometry.y)])[0]
        draw.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(220, 45, 45, 255))
    image.save(QA_DIR / "p3_national_candidate_audit.png")


def main() -> None:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    labels = transform_labels()
    land, land_union = canonical_land_8192()
    coasts = gpd.read_file(p2.COAST_GPKG, layer="coastline_8192")
    boundaries = gpd.read_file(p2.WARPED_GPKG, layer="shared_boundaries_8192")

    # Exact-coordinate planar noding only. unary_union introduces intersection
    # nodes but has no distance tolerance and therefore cannot close a gap.
    noded = unary_union([*boundaries.geometry, *coasts.geometry])
    polygonized, dangles, cuts, invalid = polygonize_full(noded)
    faces = []
    for polygon in polygonized.geoms:
        clipped = polygon.intersection(land_union)
        for part in polygon_parts(clipped):
            if part.area > EPSILON:
                faces.append(part)

    candidate_records = []
    ambiguous_records = []
    coast_refs = []
    border_refs = []
    assigned_region_ids = set()
    for face_index, face in enumerate(sorted(faces, key=lambda item: (item.bounds[1], item.bounds[0], -item.area)), start=1):
        contained = labels[labels.geometry.map(lambda point: point is not None and face.covers(point))]
        region_ids = sorted(contained["region_id"].tolist())
        if len(region_ids) != 1:
            ambiguous_records.append({
                "face_id": f"p3-face-{face_index:04d}",
                "label_count": len(region_ids),
                "candidate_region_ids": json.dumps(region_ids, ensure_ascii=False),
                "review_reason": "no_region_label" if not region_ids else "multiple_region_labels",
                "geometry": face,
            })
            continue
        region_id = region_ids[0]
        if region_id in assigned_region_ids:
            # A second closed part is valid as an island/enclave part. It uses
            # the same region_id and receives a stable independent part_id.
            part_sequence = 1 + sum(r["region_id"] == region_id for r in candidate_records)
        else:
            part_sequence = 1
        assigned_region_ids.add(region_id)
        label = contained.iloc[0]
        part_id = f"{region_id}:part-{part_sequence:03d}"
        refs = boundary_references(face, boundaries, part_id)
        coast = coastline_references(face, coasts, part_id)
        # P1/P2 are still pending manual acceptance, so even island-only faces
        # remain candidate/unconfirmed until P4 review.
        candidate_records.append({
            "region_id": region_id,
            "region_number": int(label["number"]),
            "name_ja": label["name_ja"],
            "part_id": part_id,
            "part_index": part_sequence - 1,
            "part_role": "primary" if part_sequence == 1 else "island_or_enclave",
            "certainty": "unconfirmed",
            "review_status": "pending",
            "construction": "exact_planar_face_intersection",
            "boundary_ids": json.dumps(sorted(r["boundary_id"] for r in refs), ensure_ascii=False),
            "coastline_ids": json.dumps(sorted({r["coastline_id"] for r in coast}), ensure_ascii=False),
            "lake_ids": "[]",
            "geometry": face,
        })
        border_refs.extend(refs)
        coast_refs.extend(coast)

    candidates = gpd.GeoDataFrame(candidate_records, geometry="geometry", crs=None)
    ambiguous = gpd.GeoDataFrame(ambiguous_records, geometry="geometry", crs=None)
    endpoints = endpoint_audit(boundaries, coasts.geometry.union_all())
    unassigned_labels = labels[~labels["region_id"].isin(assigned_region_ids)].copy()
    unassigned_labels["status"] = "not_in_unambiguous_closed_face"

    # Expected adjacency is carried by the source's named region pairs. Actual
    # adjacency is only asserted where two built candidate regions share line.
    expected = defaultdict(list)
    for row in boundaries.itertuples(index=False):
        pair = tuple(sorted((row.left_region_id, row.right_region_id)))
        expected[pair].append(row.boundary_id)
    actual = defaultdict(float)
    for left_index, left in candidates.iterrows():
        for right_index, right in candidates.iloc[left_index + 1:].iterrows():
            length = left.geometry.boundary.intersection(right.geometry.boundary).length
            if length > EPSILON:
                actual[tuple(sorted((left.region_id, right.region_id)))] += float(length)
    adjacency_rows = []
    for pair, ids in sorted(expected.items()):
        both_built = pair[0] in assigned_region_ids and pair[1] in assigned_region_ids
        adjacency_rows.append({
            "left_region_id": pair[0], "right_region_id": pair[1],
            "source_boundary_ids": sorted(ids),
            "actual_shared_length_8192": actual.get(pair, 0.0),
            "status": "match" if both_built and actual.get(pair, 0.0) > EPSILON else (
                "mismatch" if both_built else "not_testable_missing_region"
            ),
        })
    unexpected = [
        {"left_region_id": pair[0], "right_region_id": pair[1], "actual_shared_length_8192": length}
        for pair, length in sorted(actual.items()) if pair not in expected
    ]

    for path in (OUTPUT_GPKG, OUTPUT_GEOJSON):
        if path.exists():
            path.unlink()
    if not candidates.empty:
        candidates.to_file(OUTPUT_GPKG, layer="closed_region_candidates", driver="GPKG")
        candidates.to_file(OUTPUT_GEOJSON, driver="GeoJSON")
    ambiguous.to_file(OUTPUT_GPKG, layer="ambiguous_closed_faces", driver="GPKG", append=OUTPUT_GPKG.exists())
    endpoints.to_file(OUTPUT_GPKG, layer="boundary_endpoints", driver="GPKG", append=True)
    labels.to_file(OUTPUT_GPKG, layer="region_label_anchors_8192", driver="GPKG", append=True)
    unassigned_labels.to_file(OUTPUT_GPKG, layer="unassigned_region_labels", driver="GPKG", append=True)
    normalize_gpkg(OUTPUT_GPKG)

    COAST_REFS_JSON.write_text(json.dumps({
        "schema_version": 1,
        "source": "canonical coastline_8192 only",
        "image_coastline_used": False,
        "references": coast_refs,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    BOUNDARY_REFS_JSON.write_text(json.dumps({
        "schema_version": 1,
        "source": "P2 transformed shared boundaries",
        "references": border_refs,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ADJACENCY_JSON.write_text(json.dumps({
        "schema_version": 1,
        "expected_named_adjacencies": adjacency_rows,
        "unexpected_geometric_adjacencies": unexpected,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    graph = {
        "schema_version": 1,
        "coordinate_space": "canonical game 8192 pixels; origin top-left; y down",
        "construction": "exact planar noding and polygonize_full",
        "forbidden_operations_used": {"buffer": False, "tolerance_snap": False, "voronoi": False},
        "inputs": {
            "shared_boundaries": p2.WARPED_GPKG.relative_to(ROOT).as_posix(),
            "canonical_coastline": p2.COAST_GPKG.relative_to(ROOT).as_posix(),
            "canonical_land": p2.MASTER_LAND.relative_to(ROOT).as_posix(),
        },
        "counts": {
            "input_shared_boundaries": len(boundaries), "canonical_coastlines": len(coasts),
            "polygonized_faces": len(faces), "dangles": len(dangles.geoms),
            "cuts": len(cuts.geoms), "invalid_rings": len(invalid.geoms),
            "unconfirmed_endpoints": int((endpoints["status"] == "unconfirmed_endpoint").sum()),
        },
        "lake_reference_status": {
            "status": "unavailable",
            "reason": "approved japan_land has no interior rings and no approved lake master with lake_id exists",
            "coastline_ids_substituted": False,
        },
    }
    GRAPH_JSON.write_text(json.dumps(graph, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    render_qa(land_union, coasts, boundaries, candidates, ambiguous, endpoints)

    status = "generated_candidates_pending_manual_closure_and_review"
    report = {
        "schema_version": 1, "phase": "P3", "status": status,
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "formula": "political_region = traced_historical_region intersection japan_land_master",
        "source_review": {
            "p1": json.loads(p2.P1_REPORT.read_text(encoding="utf-8"))["status"],
            "p2": json.loads(p2.REPORT_PATH.read_text(encoding="utf-8"))["status"],
            "promotion_to_master": False,
        },
        "rules": {
            "interior_source": "P2 shared boundaries only; source approval state preserved",
            "sea_closure": "canonical coastline_id segment references only",
            "lake_closure": "not fabricated; blocked until approved lake IDs exist",
            "raster_coastline_copied": False,
            "automatic_gap_ownership": False,
            "buffer_snap_or_voronoi_used": False,
        },
        "counts": {
            "regions_in_registry": len(labels), "closed_region_candidate_parts": len(candidates),
            "candidate_region_ids": candidates["region_id"].nunique() if not candidates.empty else 0,
            "ambiguous_closed_faces": len(ambiguous), "unassigned_region_labels": len(unassigned_labels),
            "unconfirmed_endpoints": int((endpoints["status"] == "unconfirmed_endpoint").sum()),
            "coastline_segment_references": len(coast_refs), "shared_boundary_references": len(border_refs),
            "adjacency_matches": sum(row["status"] == "match" for row in adjacency_rows),
            "adjacency_mismatches": sum(row["status"] == "mismatch" for row in adjacency_rows),
            "adjacency_not_testable": sum(row["status"] == "not_testable_missing_region" for row in adjacency_rows),
        },
        "blocking_review": {
            "reason": "most transformed boundary endpoints do not exactly meet another approved boundary or canonical coastline",
            "policy": "left open for manual P4 correction; no automatic ownership assignment",
        },
        "input_hashes": {
            "japan_land_master": sha256(p2.MASTER_LAND), "coastline_master": sha256(p2.COAST_GPKG),
            "p2_boundaries": sha256(p2.WARPED_GPKG), "p1_trace": sha256(p2.P1_GPKG),
        },
        "outputs": {
            "candidate_gpkg": OUTPUT_GPKG.relative_to(ROOT).as_posix(),
            "candidate_geojson": OUTPUT_GEOJSON.relative_to(ROOT).as_posix() if OUTPUT_GEOJSON.exists() else None,
            "planar_graph": GRAPH_JSON.relative_to(ROOT).as_posix(),
            "coastline_references": COAST_REFS_JSON.relative_to(ROOT).as_posix(),
            "boundary_references": BOUNDARY_REFS_JSON.relative_to(ROOT).as_posix(),
            "adjacency_audit": ADJACENCY_JSON.relative_to(ROOT).as_posix(),
            "qa": (QA_DIR / "p3_national_candidate_audit.png").relative_to(ROOT).as_posix(),
        },
        "libraries": {
            "python": platform.python_version(), "numpy": np.__version__, "shapely": shapely.__version__,
            "geopandas": gpd.__version__, "pyogrio": pyogrio.__version__,
        },
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": status, **report["counts"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
