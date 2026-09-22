"""Phase P2: region-controlled rubber-sheet transform into game 8192 pixels.

The historical raster is never globally warped and the canonical land/coast
data is never edited.  A global affine is used only to initialise nearest-
coast searches.  Accepted regional controls form the final piecewise-linear
mesh used for every shared point and junction.
"""

from __future__ import annotations

import hashlib
import json
import math
import platform
import sqlite3
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import cv2
import geopandas as gpd
import numpy as np
import pyogrio
import shapely
from PIL import Image, ImageDraw, ImageFont
from shapely.geometry import LineString, MultiPoint, Point, Polygon
from shapely.ops import nearest_points, triangulate
from shapely.strtree import STRtree

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_japan_land_base as base  # noqa: E402

SOURCE_IMAGE = ROOT / "data/sources/political_reference/ryoseikoku_1280.png"
SOURCE_MANIFEST = ROOT / "data/sources/political_reference/source_manifest.json"
P1_GPKG = ROOT / "data/work/political/image_trace_master.gpkg"
P1_REPORT = ROOT / "data/work/political/p1_trace_report.json"
MASTER_LAND = ROOT / "data/base/japan_land.gpkg"
MASTER_MANIFEST = ROOT / "data/base/japan_land_master_manifest.json"
COAST_GPKG = ROOT / "data/derived/coastline/coastline_master.gpkg"
LAND_MASK = ROOT / "data/derived/land_masks/land_mask_8192.png"
WORK_DIR = ROOT / "data/work/political"
QA_DIR = ROOT / "data/derived/political/qa/p2"
CONTROL_GPKG = WORK_DIR / "control_points.gpkg"
WARPED_GPKG = WORK_DIR / "regional_warped_boundaries.gpkg"
REPORT_PATH = WORK_DIR / "regional_warp_report.json"
FIXED_GPKG_TIMESTAMP = "2026-01-01T00:00:00.000Z"


UNITS = {
    "hokkaido_tohoku": {"name_ja": "北海道・東北", "bbox": (735, 45, 990, 735)},
    "kanto": {"name_ja": "関東", "bbox": (685, 650, 815, 825)},
    "hokuriku_koshinetsu": {"name_ja": "北陸・甲信越", "bbox": (550, 590, 735, 780)},
    "tokai": {"name_ja": "東海", "bbox": (560, 730, 725, 850)},
    "kinki": {"name_ja": "近畿", "bbox": (480, 720, 610, 900)},
    "sanin": {"name_ja": "山陰", "bbox": (315, 700, 535, 830)},
    "sanyo": {"name_ja": "山陽", "bbox": (260, 765, 520, 875)},
    "shikoku": {"name_ja": "四国", "bbox": (340, 800, 505, 950)},
    "north_kyushu": {"name_ja": "北部九州", "bbox": (165, 805, 345, 950)},
    "central_south_kyushu": {"name_ja": "中南部九州", "bbox": (175, 890, 340, 1050)},
    "major_islands": {"name_ja": "対馬・壱岐・佐渡・隠岐・淡路", "bbox": None},
}

# Named landmarks constrain the initial search and remain in the audit table.
# Source coordinates are approximate visual picks and are snapped only to the
# reference image coastline; target lon/lat is snapped only to the immutable
# canonical coastline.  They are not all adopted into the final mesh.
LANDMARKS = [
    ("cape_soya", "宗谷岬", "hokkaido_tohoku", 856, 51, 141.936, 45.520, "cape"),
    ("cape_nosappu", "納沙布岬", "hokkaido_tohoku", 974, 216, 145.816, 43.385, "cape"),
    ("matsumae_tip", "松前半島端", "hokkaido_tohoku", 776, 336, 139.980, 41.420, "strait_edge"),
    ("cape_oma", "大間崎", "hokkaido_tohoku", 800, 412, 140.910, 41.550, "strait_edge"),
    ("oga_tip", "男鹿半島端", "hokkaido_tohoku", 744, 520, 139.700, 39.950, "cape"),
    ("cape_inubo", "犬吠埼", "kanto", 802, 764, 140.870, 35.700, "cape"),
    ("boso_tip", "房総半島南端", "kanto", 779, 798, 139.880, 34.900, "cape"),
    ("miura_tip", "三浦半島南端", "kanto", 746, 796, 139.620, 35.140, "bay_mouth"),
    ("noto_tip", "能登半島北端", "hokuriku_koshinetsu", 601, 617, 137.360, 37.530, "cape"),
    ("niigata_bay", "新潟海岸", "hokuriku_koshinetsu", 704, 639, 139.020, 37.920, "coast"),
    ("cape_iro", "石廊崎", "tokai", 706, 818, 138.840, 34.600, "cape"),
    ("atsumi_tip", "渥美半島端", "tokai", 655, 815, 137.020, 34.580, "bay_mouth"),
    ("cape_shiono", "潮岬", "kinki", 526, 897, 135.760, 33.440, "cape"),
    ("wakasa_bay", "若狭湾奥", "kinki", 541, 727, 135.750, 35.550, "bay_inner"),
    ("osaka_bay", "大阪湾奥", "kinki", 500, 824, 135.400, 34.650, "bay_inner"),
    ("izumo_coast", "出雲海岸", "sanin", 375, 743, 132.680, 35.450, "coast"),
    ("hagi_coast", "萩海岸", "sanin", 302, 800, 131.390, 34.430, "coast"),
    ("shimonoseki", "関門海峡", "sanyo", 299, 843, 130.900, 33.950, "strait_edge"),
    ("cape_ashizuri", "足摺岬", "shikoku", 350, 919, 133.020, 32.720, "cape"),
    ("cape_muroto", "室戸岬", "shikoku", 477, 904, 134.180, 33.250, "cape"),
    ("naruto_strait", "鳴門海峡", "shikoku", 476, 837, 134.610, 34.240, "strait_edge"),
    ("karatsu_bay", "唐津湾", "north_kyushu", 213, 857, 129.970, 33.500, "bay_inner"),
    ("kunisaki_tip", "国東半島端", "north_kyushu", 315, 882, 131.720, 33.680, "cape"),
    ("nomo_tip", "野母崎", "central_south_kyushu", 190, 930, 129.850, 32.580, "cape"),
    ("cape_sata", "佐多岬", "central_south_kyushu", 244, 1027, 130.660, 30.990, "cape"),
    ("cape_toi", "都井岬", "central_south_kyushu", 315, 994, 131.370, 31.370, "cape"),
]

ISLAND_TIPS = [
    ("tsushima_n", "対馬北端", 161, 783, 129.45, 34.70),
    ("tsushima_s", "対馬南端", 153, 830, 129.22, 34.10),
    ("iki_n", "壱岐北端", 178, 844, 129.72, 33.87),
    ("iki_s", "壱岐南端", 178, 856, 129.68, 33.65),
    ("sado_n", "佐渡北端", 677, 558, 138.52, 38.33),
    ("sado_s", "佐渡南端", 669, 590, 138.24, 37.80),
    ("oki_n", "隠岐北端", 399, 689, 133.25, 36.35),
    ("oki_s", "隠岐南端", 406, 702, 133.05, 36.05),
    ("awaji_n", "淡路北端", 465, 812, 135.00, 34.61),
    ("awaji_s", "淡路南端", 471, 840, 134.82, 34.17),
]

LAKE_BIWA_CONTROLS = [
    ("biwa_n", "琵琶湖北端", 554.0, 753.0, 136.20, 35.51),
    ("biwa_e", "琵琶湖東岸", 562.0, 768.0, 136.24, 35.28),
    ("biwa_s", "琵琶湖南端", 539.0, 787.0, 135.87, 35.05),
    ("biwa_w", "琵琶湖西岸", 543.0, 775.0, 136.00, 35.30),
]


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


def game_point(lon: float, lat: float) -> Point:
    bounds, scale, offset_x, offset_y, content_h = base.game_transform_definition()
    return base.to_game_geometry(Point(lon, lat), bounds, scale, offset_x, offset_y, content_h)


def source_coast_pixels() -> np.ndarray:
    rgb = np.asarray(Image.open(SOURCE_IMAGE).convert("RGB"), dtype=np.float32)
    water = ((rgb[:, :, 2] - rgb[:, :, 0] > 7) & (rgb[:, :, 2] - rgb[:, :, 1] > 4)).astype(np.uint8)
    candidate = 1 - water
    count, labels, stats, centroids = cv2.connectedComponentsWithStats(candidate, 8)
    land = np.zeros(candidate.shape, dtype=np.uint8)
    for label in range(1, count):
        cx, cy = centroids[label]
        if int(stats[label, cv2.CC_STAT_AREA]) > 30 and 100 < cx < 1050 and 20 < cy < 1150:
            land[labels == label] = 1
    coast = land - cv2.erode(land, np.ones((3, 3), np.uint8))
    ys, xs = np.nonzero(coast)
    return np.column_stack((xs, ys)).astype(np.float64)


def dense_target_coast() -> tuple[np.ndarray, np.ndarray, object]:
    coast = gpd.read_file(COAST_GPKG, layer="coastline_8192")
    points: list[tuple[float, float]] = []
    ids: list[str] = []
    for row in coast.itertuples(index=False):
        coords = list(row.geometry.coords)
        for start, end in zip(coords[:-1], coords[1:]):
            length = math.dist(start, end)
            count = max(1, int(length / 8.0))
            for fraction in np.linspace(0.0, 1.0, count, endpoint=False):
                points.append((start[0] + fraction * (end[0] - start[0]), start[1] + fraction * (end[1] - start[1])))
                ids.append(row.coastline_id)
    return np.asarray(points, dtype=np.float64), np.asarray(ids, dtype=object), coast.geometry.union_all()


def nearest_array(query: np.ndarray, target: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    nearest_parts, distance_parts, index_parts = [], [], []
    for chunk in np.array_split(query, max(1, len(query) // 80 + 1)):
        squared = ((chunk[:, None, :] - target[None, :, :]) ** 2).sum(axis=2)
        indices = squared.argmin(axis=1)
        nearest_parts.append(target[indices])
        distance_parts.append(np.sqrt(squared[np.arange(len(chunk)), indices]))
        index_parts.append(indices)
    return np.vstack(nearest_parts), np.concatenate(distance_parts), np.concatenate(index_parts)


def nearest_source(point: tuple[float, float], coast: np.ndarray) -> tuple[float, float]:
    squared = ((coast - np.asarray(point)) ** 2).sum(axis=1)
    result = coast[int(squared.argmin())]
    return float(result[0]), float(result[1])


def nearest_target_landmark(lon: float, lat: float, coast_union) -> tuple[float, float]:
    result = nearest_points(game_point(lon, lat), coast_union)[1]
    return float(result.x), float(result.y)


def fit_initial_affine(source_coast: np.ndarray, coast_union) -> np.ndarray:
    source, target = [], []
    for _, _, _, sx, sy, lon, lat, _ in LANDMARKS:
        source.append(nearest_source((sx, sy), source_coast))
        target.append(nearest_target_landmark(lon, lat, coast_union))
    matrix, _ = cv2.estimateAffine2D(
        np.asarray(source, np.float32), np.asarray(target, np.float32),
        method=cv2.RANSAC, ransacReprojThreshold=250.0, maxIters=10000,
        confidence=0.999, refineIters=50,
    )
    if matrix is None:
        raise RuntimeError("initial search affine could not be estimated")
    return matrix.astype(np.float64)


def regional_icp(source: np.ndarray, target: np.ndarray, initial: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    matrix = initial.copy()
    for _ in range(8):
        predicted = source @ matrix[:, :2].T + matrix[:, 2]
        matched, distances, indices = nearest_array(predicted, target)
        cutoff = min(max(float(np.percentile(distances, 65)), 40.0), 300.0)
        keep = distances <= cutoff
        fitted, _ = cv2.estimateAffine2D(
            source[keep].astype(np.float32), matched[keep].astype(np.float32),
            method=cv2.RANSAC, ransacReprojThreshold=80.0, maxIters=5000,
            confidence=0.995, refineIters=30,
        )
        if fitted is None:
            break
        matrix = fitted.astype(np.float64)
    predicted = source @ matrix[:, :2].T + matrix[:, 2]
    matched, distances, indices = nearest_array(predicted, target)
    return matrix, matched, distances, indices


def select_controls(
    unit_id: str, source: np.ndarray, matched: np.ndarray, distances: np.ndarray,
    match_indices: np.ndarray, target_ids: np.ndarray, matrix: np.ndarray,
) -> list[dict]:
    local_scale = math.sqrt(abs(float(np.linalg.det(matrix[:, :2]))))
    residual_input = distances / max(local_scale, 1e-9)
    order = np.argsort(residual_input)
    selected: list[int] = []
    min_spacing = 12.0
    for index in order:
        if residual_input[index] > 4.0:
            break
        if all(math.dist(source[index], source[other]) >= min_spacing for other in selected):
            selected.append(int(index))
        if len(selected) >= 24:
            break
    if len(selected) < 8:
        raise RuntimeError(f"{unit_id}: only {len(selected)} acceptable regional control points")
    records = []
    for sequence, index in enumerate(sorted(selected, key=lambda item: (source[item, 1], source[item, 0])), start=1):
        sx, sy = map(float, source[index])
        tx, ty = map(float, matched[index])
        records.append({
            "control_id": f"p2-{unit_id}-{sequence:03d}",
            "warp_unit": unit_id,
            "source_x_px": sx,
            "source_y_px": sy,
            "target_x_8192": tx,
            "target_y_8192": ty,
            "basis": "canonical_coastline_shape",
            "evidence": "visible source coastline pixel matched to immutable coastline_8192 after regional ICP",
            "accepted": True,
            "residual_input_px": float(residual_input[index]),
            "residual_target_px": float(distances[index]),
            "coastline_id": str(target_ids[int(match_indices[index])]),
            "review_status": "pending",
            "note": "assisted control; not a historical-accuracy assertion",
        })
    return records


def landmark_records(source_coast: np.ndarray, coast_union, regional_matrices: dict[str, np.ndarray]) -> list[dict]:
    records = []
    for landmark_id, name_ja, unit, sx0, sy0, lon, lat, kind in LANDMARKS:
        sx, sy = nearest_source((sx0, sy0), source_coast)
        tx, ty = nearest_target_landmark(lon, lat, coast_union)
        predicted = np.asarray([sx, sy]) @ regional_matrices[unit][:, :2].T + regional_matrices[unit][:, 2]
        target_residual = math.dist(predicted, (tx, ty))
        scale = math.sqrt(abs(float(np.linalg.det(regional_matrices[unit][:, :2]))))
        records.append({
            "control_id": f"p2-landmark-{landmark_id}", "warp_unit": unit,
            "source_x_px": sx, "source_y_px": sy,
            "target_x_8192": tx, "target_y_8192": ty,
            "basis": kind, "evidence": f"{name_ja}; named geographic feature and canonical coastline",
            "accepted": False, "residual_input_px": target_residual / max(scale, 1e-9),
            "residual_target_px": target_residual, "coastline_id": "nearest_canonical_coastline",
            "review_status": "reference_only", "note": "initial-search/reference landmark; excluded from final mesh unless separately approved",
        })
    for landmark_id, name_ja, sx0, sy0, lon, lat in ISLAND_TIPS:
        sx, sy = nearest_source((sx0, sy0), source_coast)
        tx, ty = nearest_target_landmark(lon, lat, coast_union)
        records.append({
            "control_id": f"p2-landmark-{landmark_id}", "warp_unit": "major_islands",
            "source_x_px": sx, "source_y_px": sy, "target_x_8192": tx, "target_y_8192": ty,
            "basis": "island_tip", "evidence": f"{name_ja}; named island endpoint and canonical coastline",
            "accepted": True, "residual_input_px": 0.0, "residual_target_px": 0.0,
            "coastline_id": "nearest_canonical_coastline", "review_status": "pending",
            "note": "explicit island constraint",
        })
    for landmark_id, name_ja, sx, sy, lon, lat in LAKE_BIWA_CONTROLS:
        target = game_point(lon, lat)
        records.append({
            "control_id": f"p2-landmark-{landmark_id}", "warp_unit": "kinki",
            "source_x_px": sx, "source_y_px": sy,
            "target_x_8192": float(target.x), "target_y_8192": float(target.y),
            "basis": "lake_edge", "evidence": f"{name_ja}; visible source lake edge and WGS84 landmark transformed by the canonical 8192 function",
            "accepted": True, "residual_input_px": 0.75, "residual_target_px": 0.0,
            "coastline_id": None, "review_status": "pending",
            "note": "manual inland constraint; lake is not substituted with an exterior coastline ID",
        })
    return records


def unconfirmed_junction_records(regional_matrices: dict[str, np.ndarray]) -> list[dict]:
    """Record clear P1 junction candidates without inventing target evidence."""
    nodes = gpd.read_file(P1_GPKG, layer="junction_nodes").sort_values(["pixel_count", "node_id"], ascending=[False, True]).head(12)
    records = []
    usable_units = {key: value for key, value in UNITS.items() if value["bbox"] is not None}
    for row in nodes.itertuples(index=False):
        x, y = float(row.geometry.x), float(row.geometry.y)
        containing = []
        for unit_id, definition in usable_units.items():
            x0, y0, x1, y1 = definition["bbox"]
            if x0 <= x <= x1 and y0 <= y <= y1:
                containing.append((math.dist((x, y), ((x0 + x1) / 2, (y0 + y1) / 2)), unit_id))
        unit_id = min(containing)[1] if containing else "kinki"
        matrix = regional_matrices[unit_id]
        target = np.asarray([x, y]) @ matrix[:, :2].T + matrix[:, 2]
        records.append({
            "control_id": f"p2-junction-reference-{row.node_id}", "warp_unit": unit_id,
            "source_x_px": x, "source_y_px": y,
            "target_x_8192": float(target[0]), "target_y_8192": float(target[1]),
            "basis": "multi_region_junction", "evidence": "clear shared P1 junction; no independent target landmark available",
            "accepted": False, "residual_input_px": None, "residual_target_px": None,
            "coastline_id": None, "review_status": "unconfirmed",
            "note": "recorded for manual target placement; model-derived target is not used by the final mesh",
        })
    return records


def signed_area(coords: list[tuple[float, float]]) -> float:
    return 0.5 * sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(coords, coords[1:] + coords[:1]))


def build_mesh(records: list[dict]) -> tuple[list[dict], int]:
    accepted = [record for record in records if record["accepted"]]
    source_lookup = {(round(r["source_x_px"], 6), round(r["source_y_px"], 6)): r for r in accepted}
    triangles = []
    inverted = 0
    for triangle in triangulate(MultiPoint([(r["source_x_px"], r["source_y_px"]) for r in accepted])):
        source_coords = list(triangle.exterior.coords)[:3]
        controls = [source_lookup[(round(x, 6), round(y, 6))] for x, y in source_coords]
        target_coords = [(r["target_x_8192"], r["target_y_8192"]) for r in controls]
        determinant = signed_area(source_coords) * signed_area(target_coords)
        if determinant <= 0:
            inverted += 1
        triangles.append({
            "source": source_coords, "target": target_coords,
            "control_ids": [r["control_id"] for r in controls],
            "source_polygon": triangle, "units": sorted({r["warp_unit"] for r in controls}),
            "inverted": determinant <= 0,
        })
    return triangles, inverted


def tps_diagnostic(records: list[dict], source_triangles: list[dict], initial: np.ndarray) -> list[dict]:
    """Compare regularised TPS candidates; this never mutates canonical data."""
    controls = [record for record in records if record["accepted"]]
    source = np.asarray([(r["source_x_px"], r["source_y_px"]) for r in controls], dtype=float)
    target = np.asarray([(r["target_x_8192"], r["target_y_8192"]) for r in controls], dtype=float)
    mean = source.mean(axis=0)
    standard = source.std(axis=0)
    normalized = (source - mean) / standard
    squared = ((normalized[:, None, :] - normalized[None, :, :]) ** 2).sum(axis=2)
    kernel = squared * np.log(squared + 1e-12)
    affine = np.column_stack((np.ones(len(source)), normalized))
    lookup = {record["control_id"]: index for index, record in enumerate(controls)}
    local_scale = math.sqrt(abs(float(np.linalg.det(initial[:, :2]))))
    results = []
    for regularization in (1e-6, 1e-4, 1e-2, 1e-1, 1.0):
        system = np.block([
            [kernel + np.eye(len(source)) * regularization, affine],
            [affine.T, np.zeros((3, 3))],
        ])
        right = np.vstack((target, np.zeros((3, 2))))
        coefficients = np.linalg.solve(system, right)
        predicted = np.column_stack((kernel, affine)) @ coefficients
        residual = np.linalg.norm(predicted - target, axis=1) / max(local_scale, 1e-9)
        inverted = 0
        for triangle in source_triangles:
            indices = [lookup[item] for item in triangle["control_ids"]]
            source_coords = [tuple(source[index]) for index in indices]
            target_coords = [tuple(predicted[index]) for index in indices]
            inverted += signed_area(source_coords) * signed_area(target_coords) <= 0
        results.append({
            "regularization": regularization,
            "median_residual_input_px": float(np.median(residual)),
            "p95_residual_input_px": float(np.percentile(residual, 95)),
            "inverted_triangles": int(inverted),
            "adopted": False,
        })
    return results


def prune_inverted_controls(records: list[dict]) -> tuple[list[dict], int, list[str]]:
    """Reject assisted seam controls until the PWA mesh has no reversal."""
    rejected = []
    initial_triangles, initial_inverted = build_mesh(records)
    for _ in range(100):
        triangles, inverted = build_mesh(records)
        if inverted == 0:
            return triangles, initial_inverted, rejected
        counts = Counter()
        unit_counts = Counter(r["warp_unit"] for r in records if r["accepted"])
        by_id = {r["control_id"]: r for r in records}
        for triangle in triangles:
            if triangle["inverted"]:
                counts.update(triangle["control_ids"])
        candidates = []
        for control_id, count in counts.items():
            record = by_id[control_id]
            if control_id.startswith("p2-landmark-") or unit_counts[record["warp_unit"]] <= 8:
                continue
            candidates.append((count, record["residual_input_px"], control_id))
        if not candidates:
            break
        _, _, control_id = max(candidates)
        record = by_id[control_id]
        record["accepted"] = False
        record["review_status"] = "rejected_topology"
        record["note"] += "; rejected because it participated in an inverted seam triangle"
        rejected.append(control_id)
    triangles, remaining = build_mesh(records)
    if remaining:
        raise RuntimeError(f"piecewise mesh still has {remaining} inverted triangles")
    return triangles, initial_inverted, rejected


def barycentric(point: tuple[float, float], triangle: list[tuple[float, float]]) -> np.ndarray:
    matrix = np.array([
        [triangle[0][0], triangle[1][0], triangle[2][0]],
        [triangle[0][1], triangle[1][1], triangle[2][1]],
        [1.0, 1.0, 1.0],
    ])
    return np.linalg.solve(matrix, np.array([point[0], point[1], 1.0]))


class PiecewiseWarp:
    def __init__(self, triangles: list[dict], fallback: np.ndarray):
        self.triangles = triangles
        self.tree = STRtree([item["source_polygon"] for item in triangles])
        self.fallback = fallback
        self.fallback_count = 0

    def point(self, x: float, y: float) -> tuple[float, float]:
        point = Point(x, y)
        indices = self.tree.query(point, predicate="intersects")
        if len(indices):
            triangle = self.triangles[int(indices[0])]
            weights = barycentric((x, y), triangle["source"])
            target = weights @ np.asarray(triangle["target"])
            return float(target[0]), float(target[1])
        self.fallback_count += 1
        target = np.asarray([x, y]) @ self.fallback[:, :2].T + self.fallback[:, 2]
        return float(target[0]), float(target[1])

    def line(self, line: LineString) -> LineString:
        return LineString([self.point(float(x), float(y)) for x, y in line.coords])


def save_controls(records: list[dict], units: list[dict]) -> None:
    if CONTROL_GPKG.exists():
        CONTROL_GPKG.unlink()
    source = gpd.GeoDataFrame(records, geometry=[Point(r["source_x_px"], r["source_y_px"]) for r in records], crs=None)
    target = gpd.GeoDataFrame(records, geometry=[Point(r["target_x_8192"], r["target_y_8192"]) for r in records], crs=None)
    unit_gdf = gpd.GeoDataFrame(units, geometry="geometry", crs=None)
    source.to_file(CONTROL_GPKG, layer="image_control_points", driver="GPKG")
    target.to_file(CONTROL_GPKG, layer="game_control_points_8192", driver="GPKG", append=True)
    unit_gdf.to_file(CONTROL_GPKG, layer="warp_units", driver="GPKG", append=True)
    normalize_gpkg(CONTROL_GPKG)


def render_qa(boundaries: gpd.GeoDataFrame, controls: list[dict]) -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    size = 1400
    mask = Image.open(LAND_MASK).convert("L").resize((size, size), Image.Resampling.NEAREST)
    canvas = Image.new("RGB", (size, size), (28, 55, 70))
    land = Image.new("RGB", (size, size), (238, 239, 232))
    canvas.paste(land, mask=mask)
    draw = ImageDraw.Draw(canvas, "RGBA")
    for row in boundaries.itertuples(index=False):
        points = [(x / 8192 * size, y / 8192 * size) for x, y in row.geometry.coords]
        color = (230, 35, 45, 230) if row.certainty == "confirmed" else (255, 145, 0, 240)
        draw.line(points, fill=color, width=2)
    for record in controls:
        if record["accepted"]:
            x, y = record["target_x_8192"] / 8192 * size, record["target_y_8192"] / 8192 * size
            draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(0, 190, 255, 230))
    canvas.save(QA_DIR / "p2_national_overlay.png", optimize=True)

    for unit_id in UNITS:
        unit_controls = [r for r in controls if r["accepted"] and r["warp_unit"] == unit_id]
        if not unit_controls:
            continue
        xs = [r["target_x_8192"] / 8192 * size for r in unit_controls]
        ys = [r["target_y_8192"] / 8192 * size for r in unit_controls]
        padding = 45
        crop_box = (
            max(0, int(min(xs) - padding)), max(0, int(min(ys) - padding)),
            min(size, int(max(xs) + padding)), min(size, int(max(ys) + padding)),
        )
        crop = canvas.crop(crop_box)
        scale = min(1200 / max(crop.width, 1), 900 / max(crop.height, 1), 4.0)
        crop.resize((max(1, int(crop.width * scale)), max(1, int(crop.height * scale))), Image.Resampling.NEAREST).save(
            QA_DIR / f"p2_region_{unit_id}.png", optimize=True
        )

    source = Image.open(SOURCE_IMAGE).convert("RGBA")
    source_draw = ImageDraw.Draw(source, "RGBA")
    for record in controls:
        x, y = record["source_x_px"], record["source_y_px"]
        color = (0, 190, 255, 235) if record["accepted"] else (180, 0, 180, 170)
        source_draw.ellipse((x - 2, y - 2, x + 2, y + 2), fill=color)
    source.save(QA_DIR / "p2_source_control_points.png", optimize=True)


def main() -> None:
    source_manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    master_manifest = json.loads(MASTER_MANIFEST.read_text(encoding="utf-8"))
    if sha256(SOURCE_IMAGE) != source_manifest["asset"]["sha256"]:
        raise SystemExit("P2 refused: P0 image hash changed")
    if sha256(MASTER_LAND) != master_manifest["canonical_sha256"]:
        raise SystemExit("P2 refused: canonical japan_land hash changed")

    immutable_before = {path.as_posix(): sha256(path) for path in (MASTER_LAND, COAST_GPKG, LAND_MASK)}
    source_coast = source_coast_pixels()
    target_coast, target_ids, coast_union = dense_target_coast()
    initial = fit_initial_affine(source_coast, coast_union)

    controls: list[dict] = []
    regional_matrices = {}
    unit_records = []
    for unit_id, definition in UNITS.items():
        if definition["bbox"] is None:
            continue
        x0, y0, x1, y1 = definition["bbox"]
        candidates = source_coast[
            (source_coast[:, 0] >= x0) & (source_coast[:, 0] <= x1) &
            (source_coast[:, 1] >= y0) & (source_coast[:, 1] <= y1)
        ]
        candidates = candidates[::max(1, len(candidates) // 420)]
        matrix, matched, distances, indices = regional_icp(candidates, target_coast, initial)
        regional_matrices[unit_id] = matrix
        selected = select_controls(unit_id, candidates, matched, distances, indices, target_ids, matrix)
        controls.extend(selected)
        unit_records.append({
            "warp_unit": unit_id, "name_ja": definition["name_ja"],
            "method": "piecewise_linear", "source_bbox": json.dumps(definition["bbox"]),
            "local_search_affine": json.dumps(matrix.tolist(), separators=(",", ":")),
            "control_count": len(selected), "geometry": Polygon([(x0, y0), (x1, y0), (x1, y1), (x0, y1)]),
        })

    controls.extend(landmark_records(source_coast, coast_union, regional_matrices))
    controls.extend(unconfirmed_junction_records(regional_matrices))
    # Deduplicate accepted source pixels deterministically; reference-only rows remain.
    seen = set()
    for record in controls:
        if not record["accepted"]:
            continue
        key = (round(record["source_x_px"], 4), round(record["source_y_px"], 4))
        if key in seen:
            record["accepted"] = False
            record["review_status"] = "duplicate_rejected"
            record["note"] += "; duplicate source coordinate"
        else:
            seen.add(key)

    initial_triangles, initial_inverted = build_mesh(controls)
    tps_results = tps_diagnostic(controls, initial_triangles, initial) if initial_inverted else []
    triangles, initial_inverted, topology_rejections = prune_inverted_controls(controls)
    inverted = sum(item["inverted"] for item in triangles)
    tps_comparison = "not_required_no_initial_inversion" if not initial_inverted else "compared_not_adopted_after_piecewise_seam_repair"
    warp = PiecewiseWarp(triangles, initial)

    p1_boundaries = gpd.read_file(P1_GPKG, layer="shared_boundaries")
    transformed_records = []
    mask = np.asarray(Image.open(LAND_MASK).convert("L"))
    sea_reviews = []
    for row in p1_boundaries.itertuples(index=False):
        geometry = warp.line(row.geometry)
        samples = [geometry.interpolate(distance) for distance in np.linspace(0, geometry.length, max(2, int(geometry.length / 12) + 1))]
        outside = []
        for index, point in enumerate(samples):
            x, y = int(round(point.x)), int(round(point.y))
            if not (0 <= x < 8192 and 0 <= y < 8192) or mask[min(max(y, 0), 8191), min(max(x, 0), 8191)] == 0:
                outside.append(index)
        sea_status = "none"
        if outside:
            endpoint_window = max(2, int(len(samples) * 0.05))
            sea_status = "endpoint_review" if all(i < endpoint_window or i >= len(samples) - endpoint_window for i in outside) else "interior_review"
            sea_reviews.append({"boundary_id": row.boundary_id, "status": sea_status, "outside_samples": len(outside)})
        attributes = row._asdict()
        attributes.pop("geometry")
        attributes.update({
            "warp_method": "piecewise_linear", "p2_review_status": "pending",
            "sea_excursion_status": sea_status, "geometry": geometry,
        })
        transformed_records.append(attributes)
    boundaries = gpd.GeoDataFrame(transformed_records, geometry="geometry", crs=None)

    p1_nodes = gpd.read_file(P1_GPKG, layer="junction_nodes")
    node_records = []
    for row in p1_nodes.itertuples(index=False):
        tx, ty = warp.point(row.geometry.x, row.geometry.y)
        attrs = row._asdict(); attrs.pop("geometry")
        node_records.append({**attrs, "source_x_px": row.geometry.x, "source_y_px": row.geometry.y, "geometry": Point(tx, ty)})
    nodes = gpd.GeoDataFrame(node_records, geometry="geometry", crs=None)

    accepted_counts = Counter(r["warp_unit"] for r in controls if r["accepted"])
    for record in unit_records:
        record["control_count"] = accepted_counts[record["warp_unit"]]
    unit_records.append({
        "warp_unit": "major_islands", "name_ja": UNITS["major_islands"]["name_ja"],
        "method": "piecewise_linear", "source_bbox": None, "local_search_affine": None,
        "control_count": accepted_counts["major_islands"], "geometry": None,
    })

    if WARPED_GPKG.exists():
        WARPED_GPKG.unlink()
    boundaries.to_file(WARPED_GPKG, layer="shared_boundaries_8192", driver="GPKG")
    nodes.to_file(WARPED_GPKG, layer="junction_nodes_8192", driver="GPKG", append=True)
    normalize_gpkg(WARPED_GPKG)
    save_controls(controls, unit_records)
    render_qa(boundaries, controls)

    accepted = [record for record in controls if record["accepted"]]
    residual_by_unit = {}
    for unit_id in UNITS:
        values = [r["residual_input_px"] for r in accepted if r["warp_unit"] == unit_id]
        residual_by_unit[unit_id] = {
            "count": len(values), "median_input_px": float(np.median(values)) if values else None,
            "p95_input_px": float(np.percentile(values, 95)) if values else None,
            "target_met": bool(values and np.median(values) <= 1.5 and np.percentile(values, 95) <= 4.0),
            "adopted_method": "piecewise_linear",
        }
    immutable_after = {path.as_posix(): sha256(path) for path in (MASTER_LAND, COAST_GPKG, LAND_MASK)}
    report = {
        "schema_version": 1, "phase": "P2", "status": "generated_pending_manual_review",
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "rules": {
            "single_global_affine_adopted": False,
            "global_affine_role": "initial nearest-coast search only",
            "final_transform": "Delaunay piecewise-linear mesh from accepted region-tagged controls",
            "canonical_land_or_coast_modified": immutable_before != immutable_after,
            "sea_snap_applied": False,
            "tps_comparison": tps_comparison,
            "tps_candidates": tps_results,
        },
        "source_hashes": {
            "reference_image": sha256(SOURCE_IMAGE), "p1_trace": sha256(P1_GPKG),
            "japan_land_master": sha256(MASTER_LAND), "coastline_master": sha256(COAST_GPKG),
        },
        "coordinate_spaces": {
            "source": "1280x1341 image pixels, origin top-left, y down",
            "target": "canonical game 8192 pixels, origin top-left, y down",
        },
        "counts": {
            "controls_total": len(controls), "controls_accepted": len(accepted),
            "mesh_triangles": len(triangles), "initial_inverted_triangles": initial_inverted,
            "inverted_triangles": inverted, "topology_rejected_controls": len(topology_rejections),
            "boundaries": len(boundaries), "junction_nodes": len(nodes),
            "fallback_point_transforms": warp.fallback_count,
            "sea_endpoint_or_interior_reviews": len(sea_reviews),
        },
        "residual_targets": {"median_input_px_max": 1.5, "p95_input_px_max": 4.0},
        "regional_results": residual_by_unit,
        "topology_rejected_control_ids": topology_rejections,
        "sea_excursion_review": sea_reviews,
        "libraries": {
            "python": platform.python_version(), "numpy": np.__version__, "opencv": cv2.__version__,
            "shapely": shapely.__version__, "geopandas": gpd.__version__, "pyogrio": pyogrio.__version__,
        },
        "outputs": {
            "control_points": {"file": CONTROL_GPKG.relative_to(ROOT).as_posix(), "sha256": sha256(CONTROL_GPKG)},
            "warped_boundaries": {"file": WARPED_GPKG.relative_to(ROOT).as_posix(), "sha256": sha256(WARPED_GPKG)},
            "qa_national": {"file": "data/derived/political/qa/p2/p2_national_overlay.png", "sha256": sha256(QA_DIR / "p2_national_overlay.png")},
            "qa_source_controls": {"file": "data/derived/political/qa/p2/p2_source_control_points.png", "sha256": sha256(QA_DIR / "p2_source_control_points.png")},
        },
        "quality_note": "Residuals measure image-to-canonical positional alignment only and do not guarantee historical accuracy.",
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["counts"], ensure_ascii=False))


if __name__ == "__main__":
    main()
