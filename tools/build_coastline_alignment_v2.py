"""Align the user-provided raster coastline to the immutable master coast.

The RGBA alpha channel is the only line-intensity input; transparent RGB noise
is ignored.  A robust affine establishes geographic correspondence, after
which each accepted raster-coast sample is projected onto one identified
canonical coastline feature.  The master land/coast geometries are read-only.
"""

from __future__ import annotations

import hashlib
import json
import math
import platform
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

import cv2
import geopandas as gpd
import numpy as np
import pyogrio
import shapely
from PIL import Image, ImageDraw, ImageFont
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import nearest_points, substring

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_phase_p2_regional_warp as p2  # noqa: E402
import build_phase_p3_political_regions as p3  # noqa: E402

WORK_DIR = ROOT / "data/work/political/coast_alignment_v2"
QA_DIR = ROOT / "data/derived/political/qa/coast_alignment_v2"
SOURCE_RGBA = WORK_DIR / "source_rgba.png"
SOURCE_ALPHA = WORK_DIR / "source_alpha.png"
SOURCE_LAND = WORK_DIR / "source_land_recovered.png"
SOURCE_COAST = WORK_DIR / "source_coast_extracted.png"
OUTPUT_GPKG = WORK_DIR / "coastline_alignment_controls.gpkg"
REPORT_PATH = WORK_DIR / "coastline_alignment_report.json"
FIXED_GPKG_TIMESTAMP = "2026-01-01T00:00:00.000Z"
ALPHA_THRESHOLD = 96
MAX_INITIAL_DISTANCE_8192 = 350.0
SAMPLE_STEP = 3


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


def extract_source_coast() -> tuple[list[np.ndarray], dict]:
    rgba = cv2.imread(str(SOURCE_RGBA), cv2.IMREAD_UNCHANGED)
    if rgba is None or rgba.ndim != 3 or rgba.shape[2] != 4:
        raise RuntimeError("source_rgba.png must contain an alpha channel")
    alpha = rgba[:, :, 3]
    cv2.imwrite(str(SOURCE_ALPHA), alpha)
    line = (alpha > ALPHA_THRESHOLD).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(line, 8)
    retained = np.zeros_like(line)
    component_count = 0
    for label in range(1, count):
        x, y, width, height, area = map(int, stats[label])
        # The enhanced map occupies this stable geographic work area. Text
        # columns and transparent-pixel colour noise are outside/independent.
        if area > 100 and x >= 300 and x + width <= 1350 and y >= 20 and y + height <= rgba.shape[0]:
            retained[labels == label] = 1
            component_count += 1
    sealed = cv2.morphologyEx(retained, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    sealed = cv2.dilate(sealed, np.ones((3, 3), np.uint8), iterations=1)
    free = (1 - sealed).astype(np.uint8)
    flood = free.copy()
    flood_mask = np.zeros((free.shape[0] + 2, free.shape[1] + 2), np.uint8)
    cv2.floodFill(flood, flood_mask, (0, 0), 2)
    enclosed = (flood == 1).astype(np.uint8)
    cell_count, cell_labels, cell_stats, _ = cv2.connectedComponentsWithStats(enclosed, 8)
    land = np.zeros_like(enclosed)
    retained_cells = 0
    for label in range(1, cell_count):
        x, y, _, _, area = map(int, cell_stats[label])
        if area >= 15 and 300 < x < 1350 and 20 < y < rgba.shape[0]:
            land[cell_labels == label] = 1
            retained_cells += 1
    near_land = cv2.dilate(land, np.ones((7, 7), np.uint8), iterations=1)
    land = ((land > 0) | ((sealed > 0) & (near_land > 0))).astype(np.uint8) * 255
    cv2.imwrite(str(SOURCE_LAND), land)
    contours, _ = cv2.findContours(land, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    contours = sorted(contours, key=cv2.contourArea, reverse=True)
    coastline = np.zeros_like(land)
    cv2.drawContours(coastline, contours, -1, 255, 1)
    cv2.imwrite(str(SOURCE_COAST), coastline)
    arrays = [contour[:, 0, :].astype(np.float64) for contour in contours if len(contour) >= 4]
    return arrays, {
        "rgba_size": [int(rgba.shape[1]), int(rgba.shape[0])],
        "alpha_threshold": ALPHA_THRESHOLD,
        "retained_line_components": component_count,
        "retained_enclosed_cells": retained_cells,
        "exterior_contours": len(arrays),
    }


def canonical_parts_and_points():
    land, land_union = p3.canonical_land_8192()
    polygon_parts = []
    for geometry in land.geometry:
        polygon_parts.extend(list(geometry.geoms))
    polygon_parts.sort(key=lambda geometry: geometry.area, reverse=True)
    coasts = gpd.read_file(p2.COAST_GPKG, layer="coastline_8192")
    dense_points, dense_ids, _ = p2.dense_target_coast()
    return polygon_parts, land_union, coasts, dense_points, dense_ids


def nearest_array(query: np.ndarray, target: np.ndarray):
    nearest, distances, indices = p2.nearest_array(query, target)
    return nearest, distances, indices


def fit_initial_affine(source_points: np.ndarray, source_contours: list[np.ndarray], canonical_parts, target_dense):
    source_major = np.vstack(source_contours[:3])
    target_major = np.vstack([np.asarray(polygon.exterior.coords) for polygon in canonical_parts[:4]])
    source_min, source_max = source_major.min(axis=0), source_major.max(axis=0)
    target_min, target_max = target_major.min(axis=0), target_major.max(axis=0)
    scale = (target_max - target_min) / (source_max - source_min)
    matrix = np.asarray([
        [scale[0], 0.0, target_min[0] - source_min[0] * scale[0]],
        [0.0, scale[1], target_min[1] - source_min[1] * scale[1]],
    ], dtype=np.float64)
    for _ in range(25):
        predicted = source_points @ matrix[:, :2].T + matrix[:, 2]
        matched, distances, _ = nearest_array(predicted, target_dense)
        cutoff = min(float(np.percentile(distances, 55)), 200.0)
        keep = distances <= cutoff
        fitted, _ = cv2.estimateAffine2D(
            source_points[keep].astype(np.float32), matched[keep].astype(np.float32),
            method=cv2.RANSAC, ransacReprojThreshold=60.0, maxIters=8000,
            confidence=0.999, refineIters=40,
        )
        if fitted is None:
            break
        matrix = fitted.astype(np.float64)
    return matrix


def line_runs(distances: list[float | None], ids: list[str | None], contour_id: str, coast_lookup):
    records = []
    for index in range(len(distances) - 1):
        if distances[index] is None or distances[index + 1] is None or ids[index] != ids[index + 1]:
            continue
        start_distance, end_distance = distances[index], distances[index + 1]
        # A large jump is a closed-ring seam or a wrong feature transition;
        # it must not create a long canonical detour.
        if abs(end_distance - start_distance) > 500.0 or abs(end_distance - start_distance) <= 1e-9:
            continue
        coast = coast_lookup[ids[index]]
        geometry = substring(coast, min(start_distance, end_distance), max(start_distance, end_distance))
        if geometry.is_empty or geometry.length <= 1e-9:
            continue
        records.append({
            "alignment_segment_id": f"{contour_id}:segment-{len(records)+1:04d}",
            "source_contour_id": contour_id,
            "source_start_sequence": index,
            "source_end_sequence": index + 1,
            "target_coastline_id": ids[index],
            "start_distance_8192": start_distance,
            "end_distance_8192": end_distance,
            "geometry": geometry,
        })
    return records


def font(size):
    path = Path("C:/Windows/Fonts/YuGothM.ttc")
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def render_overlay(path, bounds, land_union, coasts, initial_lines, aligned_lines, mode, title):
    size = 1800
    image = Image.new("RGB", (size, size), (31, 62, 78))
    draw = ImageDraw.Draw(image, "RGBA")
    margin = 55
    min_x, min_y, max_x, max_y = bounds
    scale = min((size - 2*margin)/(max_x-min_x), (size-2*margin)/(max_y-min_y))
    ox = margin + ((size-2*margin)-(max_x-min_x)*scale)/2
    oy = margin + ((size-2*margin)-(max_y-min_y)*scale)/2
    def xy(point): return (ox+(point[0]-min_x)*scale, oy+(point[1]-min_y)*scale)
    def polys(geometry):
        if isinstance(geometry, Polygon): return [geometry]
        if hasattr(geometry, "geoms"):
            result=[]
            for item in geometry.geoms: result.extend(polys(item))
            return result
        return []
    def lines(geometry):
        if geometry is None or geometry.is_empty: return []
        if isinstance(geometry, LineString): return [geometry]
        if hasattr(geometry, "geoms"):
            result=[]
            for item in geometry.geoms: result.extend(lines(item))
            return result
        return []
    clip = box(*bounds)
    for polygon in polys(land_union.intersection(clip)):
        draw.polygon([xy(p) for p in polygon.exterior.coords], fill=(247,245,238,255))
    for coast in coasts.geometry:
        for line in lines(coast.intersection(clip)):
            draw.line([xy(p) for p in line.coords], fill=(15,18,20,255), width=5, joint="curve")
    if mode in ("before", "comparison"):
        for geometry in initial_lines.geometry:
            for line in lines(geometry.intersection(clip)):
                draw.line([xy(p) for p in line.coords], fill=(230,48,55,225), width=3, joint="curve")
    if mode in ("after", "comparison"):
        for geometry in aligned_lines.geometry:
            for line in lines(geometry.intersection(clip)):
                draw.line([xy(p) for p in line.coords], fill=(0,215,235,255), width=3, joint="curve")
    draw.rectangle((0,0,size,45),fill=(15,23,28,235))
    draw.text((14,7),title,font=font(22),fill=(255,255,255,255))
    draw.rectangle((0,size-42,size,size),fill=(15,23,28,235))
    legend = [("canonical coast",(15,18,20,255))]
    if mode in ("before","comparison"): legend.append(("source before",(230,48,55,255)))
    if mode in ("after","comparison"): legend.append(("source aligned",(0,215,235,255)))
    x=15
    for label,color in legend:
        draw.rectangle((x,size-29,x+16,size-13),fill=color)
        draw.text((x+22,size-32),label,font=font(14),fill=(255,255,255,255))
        x+=180
    image.save(path)


def main():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    immutable_before = {path.as_posix(): sha256(path) for path in (p2.MASTER_LAND, p2.COAST_GPKG)}
    contours, extraction = extract_source_coast()
    source_points = np.vstack([contour[::SAMPLE_STEP] for contour in contours])
    canonical_parts, land_union, coasts, target_dense, target_ids = canonical_parts_and_points()
    affine = fit_initial_affine(source_points, contours, canonical_parts, target_dense)
    predicted = source_points @ affine[:, :2].T + affine[:, 2]
    _, initial_distances, nearest_indices = nearest_array(predicted, target_dense)

    coast_lookup = dict(zip(coasts["coastline_id"], coasts.geometry))
    source_records = []
    target_records = []
    aligned_segment_records = []
    initial_line_records = []
    offset = 0
    accepted_distances = []
    rejected = 0
    for contour_index, contour in enumerate(contours, start=1):
        sampled = contour[::SAMPLE_STEP]
        contour_id = f"source-coast-{contour_index:03d}"
        initial_coords = sampled @ affine[:, :2].T + affine[:, 2]
        initial_line_records.append({"source_contour_id": contour_id, "geometry": LineString(initial_coords)})
        projected_distances = []
        projected_ids = []
        for sequence, (source_point, initial_point) in enumerate(zip(sampled, initial_coords)):
            flat_index = offset + sequence
            distance = float(initial_distances[flat_index])
            coastline_id = str(target_ids[int(nearest_indices[flat_index])])
            accepted = distance <= MAX_INITIAL_DISTANCE_8192
            target_point = None
            if accepted:
                target_point = nearest_points(Point(initial_point), coast_lookup[coastline_id])[1]
                projected_distances.append(float(coast_lookup[coastline_id].project(target_point)))
                projected_ids.append(coastline_id)
                accepted_distances.append(distance)
            else:
                rejected += 1
                projected_distances.append(None)
                projected_ids.append(None)
            common = {
                "control_id": f"{contour_id}:point-{sequence:05d}",
                "source_contour_id": contour_id, "source_sequence": sequence,
                "source_x_px": float(source_point[0]), "source_y_px": float(source_point[1]),
                "initial_x_8192": float(initial_point[0]), "initial_y_8192": float(initial_point[1]),
                "target_coastline_id": coastline_id if accepted else None,
                "initial_distance_8192": distance, "accepted": accepted,
                "alignment_method": "identified_coastline_projection" if accepted else "unresolved",
            }
            source_records.append({**common, "geometry": Point(source_point)})
            target_records.append({**common, "geometry": target_point})
        offset += len(sampled)
        if projected_distances:
            aligned_segment_records.extend(line_runs(projected_distances, projected_ids, contour_id, coast_lookup))

    sources = gpd.GeoDataFrame(source_records, geometry="geometry", crs=None)
    targets = gpd.GeoDataFrame(target_records, geometry="geometry", crs=None)
    initial_lines = gpd.GeoDataFrame(initial_line_records, geometry="geometry", crs=None)
    aligned_lines = gpd.GeoDataFrame(aligned_segment_records, geometry="geometry", crs=None)
    if OUTPUT_GPKG.exists(): OUTPUT_GPKG.unlink()
    sources.to_file(OUTPUT_GPKG, layer="source_coast_samples", driver="GPKG")
    targets.to_file(OUTPUT_GPKG, layer="target_coast_controls_8192", driver="GPKG", append=True)
    initial_lines.to_file(OUTPUT_GPKG, layer="source_coast_initial_8192", driver="GPKG", append=True)
    aligned_lines.to_file(OUTPUT_GPKG, layer="source_coast_aligned_8192", driver="GPKG", append=True)
    normalize_gpkg(OUTPUT_GPKG)

    bounds = (0.0,0.0,8192.0,8192.0)
    kyushu_points = [p2.game_point(lon,lat) for lon,lat in [(128.8,30.7),(132.2,34.3)]]
    kyushu_bounds = (min(p.x for p in kyushu_points), min(p.y for p in kyushu_points), max(p.x for p in kyushu_points), max(p.y for p in kyushu_points))
    for scope, scope_bounds in (("national",bounds),("kyushu",kyushu_bounds)):
        render_overlay(QA_DIR/f"{scope}_before.png",scope_bounds,land_union,coasts,initial_lines,aligned_lines,"before",f"Coast alignment v2 / {scope} / before")
        render_overlay(QA_DIR/f"{scope}_after.png",scope_bounds,land_union,coasts,initial_lines,aligned_lines,"after",f"Coast alignment v2 / {scope} / after")
        render_overlay(QA_DIR/f"{scope}_comparison.png",scope_bounds,land_union,coasts,initial_lines,aligned_lines,"comparison",f"Coast alignment v2 / {scope} / comparison")

    scale_px_per_m = p2.base.game_transform_definition()[1]
    accepted_array = np.asarray(accepted_distances)
    immutable_after = {path.as_posix(): sha256(path) for path in (p2.MASTER_LAND, p2.COAST_GPKG)}
    report = {
        "schema_version": 1, "status": "generated_pending_correspondence_review",
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00","Z"),
        "source": {"file": SOURCE_RGBA.relative_to(ROOT).as_posix(), "sha256": sha256(SOURCE_RGBA), **extraction},
        "method": {
            "transparent_rgb_ignored": True,
            "initial_transform": "robust affine ICP used for coastline identity search",
            "final_coast_alignment": "each accepted source sample projected onto its identified canonical coastline_id",
            "canonical_geometry_modified": immutable_before != immutable_after,
            "political_boundaries_transformed": False,
            "note": "controls require review before they are used to transform inland political boundaries",
        },
        "counts": {
            "source_contours": len(contours), "source_samples": len(sources),
            "accepted_controls": int(targets["accepted"].sum()), "rejected_controls": rejected,
            "aligned_segments": len(aligned_lines), "target_coastline_ids_referenced": int(targets.loc[targets["accepted"],"target_coastline_id"].nunique()),
        },
        "residuals": {
            "before_projection_game_px": {"median": float(np.median(accepted_array)), "p95": float(np.percentile(accepted_array,95)), "max": float(np.max(accepted_array))},
            "before_projection_km": {"median": float(np.median(accepted_array)/scale_px_per_m/1000), "p95": float(np.percentile(accepted_array,95)/scale_px_per_m/1000)},
            "after_projection_game_px": {"median": 0.0, "p95": 0.0, "max": 0.0},
        },
        "affine_matrix": affine.tolist(),
        "input_hashes": {"japan_land_master": sha256(p2.MASTER_LAND), "coastline_master": sha256(p2.COAST_GPKG)},
        "outputs": {
            "controls": OUTPUT_GPKG.relative_to(ROOT).as_posix(), "controls_sha256": sha256(OUTPUT_GPKG),
            "source_alpha": SOURCE_ALPHA.relative_to(ROOT).as_posix(), "source_land": SOURCE_LAND.relative_to(ROOT).as_posix(),
            "source_coast": SOURCE_COAST.relative_to(ROOT).as_posix(), "qa_dir": QA_DIR.relative_to(ROOT).as_posix(),
        },
        "libraries": {"python":platform.python_version(),"opencv":cv2.__version__,"numpy":np.__version__,"shapely":shapely.__version__,"geopandas":gpd.__version__,"pyogrio":pyogrio.__version__},
    }
    REPORT_PATH.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"counts":report["counts"],"residuals":report["residuals"]},ensure_ascii=False))


if __name__ == "__main__": main()
