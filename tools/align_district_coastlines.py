"""Rebuild mainland district coverage from canonical land/coast rings.

The established inland district geometry remains the ownership seed.  It is
clipped to the approved land, and every residual face is assigned to the seed
sharing the longest boundary.  The final union therefore covers the land
exactly while every seaward edge is an interval of the canonical coastline.
"""
from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path

from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree


ROOT = Path(__file__).resolve().parents[1]
LAND_PATH = ROOT / "data/derived/land_masks/land_master_8192.json"
REGISTRY_PATH = ROOT / "data/derived/scenarios/district_coastline_references_1546.json"
REPORT_PATH = ROOT / "data/work/districts/coast_alignment/alignment_build_report.json"

# These are the only canonical rings carrying active mainland districts in the
# 1546 scenario. Hokkaido has no district seed and is intentionally not created.
MAINLAND_COASTLINE_IDS = (
    "jp-coast-103576025d905fd4",
    "jp-coast-e4e520d341c65420",
    "jp-coast-d6bda8f108065a05",
)
COAST_NODE_TOLERANCE = 5e-6


def read(path: Path):
    return json.loads(path.read_text(encoding="utf8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parts(geometry):
    if geometry.geom_type == "Polygon":
        return [geometry]
    return [part for child in getattr(geometry, "geoms", ()) for part in parts(child)]


def geometry(record):
    return unary_union([Polygon(polygon[0], polygon[1:]) for polygon in record["polygons"]])


def pack(polygon):
    return [list(map(list, polygon.exterior.coords))] + [
        list(map(list, ring.coords)) for ring in polygon.interiors
    ]


def _tree_indices(tree: STRtree, query_geometry):
    return [int(index) for index in tree.query(query_geometry)]


def canonicalize_shared_coast_nodes(final_geometries, lands):
    """Place all near-coast boundary nodes on one shared canonical point."""
    coast_lines = {coast_id: LineString(land.exterior.coords) for coast_id, land in lands.items()}
    canonical_distances = {
        coast_id: [line.project(Point(value)) for value in line.coords]
        for coast_id, line in coast_lines.items()
    }
    replacements = {}
    max_movement = 0.0
    for item in final_geometries.values():
        for polygon in parts(item):
            for ring in [polygon.exterior, *polygon.interiors]:
                for coordinate in ring.coords:
                    point = Point(coordinate)
                    choices = sorted(
                        (line.distance(point), coast_id, line.project(point))
                        for coast_id, line in coast_lines.items()
                    )
                    distance, coast_id, along = choices[0]
                    if distance <= COAST_NODE_TOLERANCE:
                        line = coast_lines[coast_id]
                        canonical = min(canonical_distances[coast_id], key=lambda value: abs(value - along))
                        shared_distance = canonical if abs(canonical - along) <= COAST_NODE_TOLERANCE else along
                        shared = line.interpolate(shared_distance)
                        key = (float(coordinate[0]), float(coordinate[1]))
                        replacements[key] = (shared.x, shared.y)
                        max_movement = max(max_movement, point.distance(shared))

    result = {}
    skipped = []
    for key, item in final_geometries.items():
        polygons = []
        for polygon in parts(item):
            exterior = [replacements.get(tuple(coordinate), tuple(coordinate)) for coordinate in polygon.exterior.coords]
            holes = [
                [replacements.get(tuple(coordinate), tuple(coordinate)) for coordinate in ring.coords]
                for ring in polygon.interiors
            ]
            rebuilt = Polygon(exterior, holes)
            if rebuilt.is_empty or not rebuilt.is_valid:
                skipped.append(key)
                polygons = []
                break
            polygons.append(rebuilt)
        result[key] = unary_union(polygons) if polygons else item
    return result, {
        "tolerance": COAST_NODE_TOLERANCE,
        "moved_coordinate_count": len(replacements),
        "max_movement": max_movement,
        "skipped_invalid_districts": sorted(set(skipped)),
    }


def align_mainlands(data: dict) -> tuple[dict, dict]:
    land_data = read(LAND_PATH)
    lands = {
        coast_id: Polygon(land_data["coastlines"][coast_id]["points"])
        for coast_id in MAINLAND_COASTLINE_IDS
    }
    target_land = unary_union(list(lands.values()))
    old = {key: geometry(record) for key, record in data["regions"].items()}
    mainland_keys = sorted(key for key, item in old.items() if item.intersection(target_land).area > 1e-8)
    clipped = [
        unary_union(parts(old[key].intersection(target_land)))
        for key in mainland_keys
    ]
    clipped_union = unary_union(clipped)
    gap = target_land.difference(clipped_union)
    gap_parts = sorted(parts(gap), key=lambda item: (-item.area, item.bounds))
    tree = STRtree(clipped)
    additions: dict[str, list] = defaultdict(list)
    ambiguous = []
    nearest_only = 0

    for face in gap_parts:
        candidates = _tree_indices(tree, face.buffer(1e-7))
        if not candidates:
            nearest_only += 1
            candidates = [int(tree.nearest(face))]
        scored = []
        for index in candidates:
            shared_geometry = face.boundary.intersection(clipped[index].boundary)
            # GEOS can return a null geometry for collapsed machine-precision
            # slivers; those candidates still participate by distance.
            shared = shared_geometry.length if shared_geometry is not None else 0.0
            distance = face.distance(clipped[index])
            support = face.buffer(0.01).intersection(clipped[index]).area
            # A proper line contact is required before a point contact.  This
            # keeps a residual face connected to its owning district even when
            # GEOS collapses the measured intersection length to null.
            line_contact = clipped[index].relate(face)[4] == "1"
            scored.append((-int(line_contact), -shared, -support, distance, mainland_keys[index], index))
        scored.sort()
        winner = scored[0]
        additions[winner[4]].append(face)
        if face.area > 1e-4 and len(scored) > 1:
            first_shared = -winner[1]
            second_shared = -scored[1][1]
            first_support = -winner[2]
            second_support = -scored[1][2]
            if (
                abs(first_shared - second_shared) <= max(1e-9, first_shared * 1e-6)
                and abs(first_support - second_support) <= max(1e-10, first_support * 1e-6)
            ):
                ambiguous.append(
                    {
                        "area": face.area,
                        "bounds": list(face.bounds),
                        "selected": winner[4],
                        "other": scored[1][4],
                        "shared_boundary": first_shared,
                    }
                )

    before = {}
    after = {}
    final_geometries = {}
    for index, key in enumerate(mainland_keys):
        final = unary_union([clipped[index], *additions.get(key, [])])
        final_geometries[key] = final

    # The established scenario has no detached mainland district parts.  A
    # canonical land clip can expose old sea-spanning lobes as separate pieces;
    # transfer each such piece to the line-adjacent district, matching the
    # existing enclave-cleanup policy while preserving complete land coverage.
    detached_transfers = []
    detached_pool = []
    for key in mainland_keys:
        polygons = sorted(parts(final_geometries[key]), key=lambda item: -item.area)
        final_geometries[key] = polygons[0]
        detached_pool.extend((key, polygon) for polygon in polygons[1:])
    for _round in range(len(detached_pool) + 1):
        if not detached_pool:
            break
        deferred = []
        progress = 0
        for source_key, detached in detached_pool:
            choices = []
            for candidate_key, candidate in final_geometries.items():
                if candidate_key == source_key or detached.distance(candidate) > 1e-6:
                    continue
                merged = unary_union([candidate, detached])
                if len(parts(merged)) != 1:
                    continue
                hit = detached.boundary.intersection(candidate.boundary)
                shared = hit.length if hit is not None else 0.0
                choices.append((-shared, candidate_key, merged))
            if not choices:
                deferred.append((source_key, detached))
                continue
            choices.sort(key=lambda value: value[:-1])
            winner_key = choices[0][1]
            final_geometries[winner_key] = choices[0][2]
            detached_transfers.append(
                {"source": source_key, "target": winner_key, "area_world2": detached.area}
            )
            progress += 1
        detached_pool = deferred
        if progress == 0:
            break
    unjoined_detached = []
    for source_key, detached in detached_pool:
        final_geometries[source_key] = unary_union([final_geometries[source_key], detached])
        unjoined_detached.append({"district_id": source_key, "area_world2": detached.area})

    # Overlay arithmetic can leave sub-micrometre ribbons along a canonical
    # edge. Feed those exact difference faces back to the line-adjacent owner;
    # this does not buffer or simplify the coastline.
    residual_repairs = []
    for _round in range(20):
        final_union = unary_union(list(final_geometries.values()))
        residual = target_land.difference(final_union)
        if residual.area <= 1e-10:
            break
        snapshot = [final_geometries[key] for key in mainland_keys]
        residual_tree = STRtree(snapshot)
        for face in parts(residual):
            candidate_indices = _tree_indices(residual_tree, face.buffer(1e-6))
            choices = []
            for index in candidate_indices:
                candidate = snapshot[index]
                hit = face.boundary.intersection(candidate.boundary)
                shared = hit.length if hit is not None else 0.0
                support = face.buffer(0.01).intersection(candidate).area
                choices.append((-shared, -support, mainland_keys[index]))
            if not choices:
                index = int(residual_tree.nearest(face))
                choices = [(0.0, 0.0, mainland_keys[index])]
            choices.sort()
            owner = choices[0][2]
            final_geometries[owner] = unary_union([final_geometries[owner], face])
            residual_repairs.append({"district_id": owner, "area_world2": face.area})

    for key in mainland_keys:
        final_geometries[key] = final_geometries[key].intersection(target_land)

    final_geometries, node_canonicalization = canonicalize_shared_coast_nodes(final_geometries, lands)
    skipped_nodes = set(node_canonicalization["skipped_invalid_districts"])
    post_snap_overlap_repairs = []
    snapshot = [final_geometries[key] for key in mainland_keys]
    snap_tree = STRtree(snapshot)
    for index, item in enumerate(snapshot):
        for other_index in _tree_indices(snap_tree, item):
            if other_index <= index:
                continue
            other = snapshot[other_index]
            overlap = item.intersection(other)
            if overlap is None or overlap.area <= 1e-5:
                continue
            first_key = mainland_keys[index]
            second_key = mainland_keys[other_index]
            if first_key in skipped_nodes and second_key not in skipped_nodes:
                loser = first_key
            elif second_key in skipped_nodes and first_key not in skipped_nodes:
                loser = second_key
            else:
                loser = max(first_key, second_key)
            final_geometries[loser] = final_geometries[loser].difference(overlap)
            post_snap_overlap_repairs.append(
                {"district_id": loser, "area_world2": overlap.area, "pair": [first_key, second_key]}
            )

    for key in mainland_keys:
        final = final_geometries[key]
        polygons = parts(final)
        if not polygons or not final.is_valid:
            raise AssertionError(f"invalid aligned geometry: {key}")
        before[key] = old[key].area
        after[key] = final.area
        record = data["regions"][key]
        record["polygons"] = [pack(polygon) for polygon in polygons]
        record["bounds"] = list(final.bounds)
        label = Point(record["label"])
        if not final.contains(label):
            record["label"] = list(final.representative_point().coords)[0]

    final_union = unary_union([geometry(data["regions"][key]) for key in mainland_keys])
    report = {
        "schema_version": 1,
        "land_master_sha256": sha256(LAND_PATH),
        "mainland_coastline_ids": list(MAINLAND_COASTLINE_IDS),
        "mainland_district_count": len(mainland_keys),
        "gap_before_world2": gap.area,
        "gap_after_world2": target_land.difference(final_union).area,
        "outside_after_world2": final_union.difference(target_land).area,
        "gap_face_count": len(gap_parts),
        "nearest_only_face_count": nearest_only,
        "ambiguous_faces": ambiguous,
        "detached_part_transfers": detached_transfers,
        "unjoined_point_contact_parts": unjoined_detached,
        "residual_precision_repairs": residual_repairs,
        "shared_coast_node_canonicalization": node_canonicalization,
        "post_snap_overlap_repairs": post_snap_overlap_repairs,
        "area_changes_world2": {
            key: after[key] - before[key] for key in mainland_keys
            if abs(after[key] - before[key]) > 1e-12
        },
        "unseeded_hokkaido_policy": "No active 1546 district overlaps the Hokkaido ring; no district was invented.",
    }
    data["coast_alignment"] = {
        "method": "canonical_land_partition_from_existing_district_seeds",
        "land_master_sha256": report["land_master_sha256"],
        "coastline_ids": list(MAINLAND_COASTLINE_IDS),
        "report": str(REPORT_PATH.relative_to(ROOT)).replace("\\", "/"),
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    return data, report


def _point_coordinates(value):
    if value.is_empty:
        return []
    if value.geom_type == "Point":
        return [value.coords[0]]
    if value.geom_type == "LineString":
        return [value.coords[0], value.coords[-1]]
    return [point for child in value.geoms for point in _point_coordinates(child)]


def _line_coordinates(value):
    if value.is_empty:
        return []
    if value.geom_type in ("LineString", "LinearRing"):
        return list(value.coords)
    return [point for child in value.geoms for point in _line_coordinates(child)]


def build_reference_registry(data: dict) -> dict:
    land_data = read(LAND_PATH)
    coast_ids = list(MAINLAND_COASTLINE_IDS)
    for extra in data["connectivity"].get("extra_districts", {}).values():
        coast_ids.extend(extra.get("coastline_ids", []))
    coast_ids = list(dict.fromkeys(coast_ids))
    keys = sorted(data["regions"])
    geometries = [geometry(data["regions"][key]) for key in keys]
    tree = STRtree(geometries)
    references = []
    nodes = {}
    coast_hashes = {}
    uncovered = []

    for coast_id in coast_ids:
        raw = land_data["coastlines"][coast_id]["points"]
        ring = LineString(raw)
        coast_polygon = Polygon(raw)
        coast_cuts = {0.0, ring.length}
        for index in _tree_indices(tree, ring.buffer(1e-6)):
            for coordinate in _line_coordinates(geometries[index].boundary):
                point = Point(coordinate)
                if ring.distance(point) <= 1e-7:
                    coast_cuts.add(ring.project(point))
        coast_hashes[coast_id] = hashlib.sha256(
            json.dumps(raw, separators=(",", ":")).encode("utf8")
        ).hexdigest()
        intervals = []
        along = 0.0
        for start, end in zip(raw, raw[1:]):
            segment = LineString([start, end])
            length = segment.length
            cuts = [0.0, length] + [
                distance - along for distance in coast_cuts
                if along < distance < along + length
            ]
            candidate_indices = _tree_indices(tree, segment)
            for index in candidate_indices:
                hit = segment.intersection(geometries[index].boundary)
                cuts.extend(segment.project(Point(point)) for point in _point_coordinates(hit))
            cuts = sorted(set(round(value, 12) for value in cuts))
            for left, right in zip(cuts, cuts[1:]):
                if right - left <= 1e-10:
                    continue
                midpoint = segment.interpolate((left + right) / 2.0)
                dx = end[0] - start[0]
                dy = end[1] - start[1]
                scale = math.hypot(dx, dy)
                epsilon = min(1e-3, max(1e-6, (right - left) * 1e-4))
                left_point = Point(midpoint.x - dy / scale * epsilon, midpoint.y + dx / scale * epsilon)
                right_point = Point(midpoint.x + dy / scale * epsilon, midpoint.y - dx / scale * epsilon)
                inside_point = left_point if coast_polygon.covers(left_point) else right_point
                boundary_scores = sorted(
                    (geometries[index].boundary.distance(midpoint), keys[index], index)
                    for index in candidate_indices
                )
                if not boundary_scores:
                    index = int(tree.nearest(inside_point))
                    boundary_scores = [(geometries[index].boundary.distance(midpoint), keys[index], index)]
                boundary_distance, owner, _ = boundary_scores[0]
                if boundary_distance > 1e-7:
                    uncovered.append(
                        {"coastline_id": coast_id, "distance": along + left, "boundary_distance": boundary_distance}
                    )
                interval = [along + left, along + right, owner]
                if intervals and intervals[-1][2] == owner and abs(intervals[-1][1] - interval[0]) < 1e-8:
                    intervals[-1][1] = interval[1]
                else:
                    intervals.append(interval)
            along += length

        if len(intervals) > 1 and intervals[0][2] == intervals[-1][2]:
            first = intervals.pop(0)
            last = intervals.pop()
            intervals.append([last[0], first[1], first[2], True])
        for number, interval in enumerate(intervals):
            start_distance, end_distance, district_id = interval[:3]
            wrap = len(interval) == 4
            for distance in (start_distance, end_distance):
                point = ring.interpolate(distance)
                node_id = f"{coast_id}@{distance:.12f}"
                nodes[node_id] = {
                    "coastline_id": coast_id,
                    "distance": distance,
                    "point": [point.x, point.y],
                }
            references.append(
                {
                    "arc_id": f"district-coast-{coast_id}-{number:04d}",
                    "district_id": district_id,
                    "coastline_id": coast_id,
                    "start_distance": start_distance,
                    "end_distance": end_distance,
                    "wrap": wrap,
                    "direction": "forward",
                    "start_node_id": f"{coast_id}@{start_distance:.12f}",
                    "end_node_id": f"{coast_id}@{end_distance:.12f}",
                    "source_sha256": coast_hashes[coast_id],
                    "basis": "final_polygon_boundary_intersection",
                    "review_status": "confirmed" if district_id else "unresolved",
                }
            )

    registry = {
        "schema_version": 1,
        "source_land_master": str(LAND_PATH.relative_to(ROOT)).replace("\\", "/"),
        "source_land_master_sha256": sha256(LAND_PATH),
        "coastline_hashes": coast_hashes,
        "coastline_ids": coast_ids,
        "nodes": nodes,
        "references": references,
        "unresolved": uncovered,
    }
    REGISTRY_PATH.write_text(json.dumps(registry, ensure_ascii=False, separators=(",", ":")), encoding="utf8")
    return registry
