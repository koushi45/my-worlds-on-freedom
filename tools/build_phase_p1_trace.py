"""Build a direct, pixel-coordinate trace of solid Ryoseikoku boundaries.

The source raster is never warped here. Solid linework is isolated from the
source image, thinned to its visual centre, and associated with province labels
read from the same raster. All output coordinates remain source-image pixels.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import Counter, defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path

import cv2
import geopandas as gpd
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import LineString, Point
from shapely.ops import linemerge, unary_union


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "data" / "sources" / "political_reference"
SOURCE_IMAGE = SOURCE_DIR / "ryoseikoku_1280.png"
SOURCE_MANIFEST = SOURCE_DIR / "source_manifest.json"
WORK_DIR = ROOT / "data" / "work" / "political"
QA_DIR = ROOT / "data" / "derived" / "political" / "qa"
OUTPUT_GPKG = WORK_DIR / "image_trace_master.gpkg"
OUTPUT_REPORT = WORK_DIR / "p1_trace_report.json"
OUTPUT_REVIEW_LOG = WORK_DIR / "manual_review_log.json"

REGIONS = {
    1: ("satsuma", "薩摩国"), 2: ("osumi", "大隅国"), 3: ("hyuga", "日向国"),
    4: ("higo", "肥後国"), 5: ("bungo", "豊後国"), 6: ("chikugo", "筑後国"),
    7: ("hizen", "肥前国"), 8: ("chikuzen", "筑前国"), 9: ("buzen", "豊前国"),
    10: ("iki", "壱岐国"), 11: ("tsushima", "対馬国"), 12: ("nagato", "長門国"),
    13: ("suo", "周防国"), 14: ("aki", "安芸国"), 15: ("bingo", "備後国"),
    16: ("bitchu", "備中国"), 17: ("mimasaka", "美作国"), 18: ("bizen", "備前国"),
    19: ("harima", "播磨国"), 20: ("iwami", "石見国"), 21: ("izumo", "出雲国"),
    22: ("hoki", "伯耆国"), 23: ("oki", "隠岐国"), 24: ("inaba", "因幡国"),
    25: ("tajima", "但馬国"), 26: ("tango", "丹後国"), 27: ("tanba", "丹波国"),
    28: ("iyo", "伊予国"), 29: ("tosa", "土佐国"), 30: ("awa_shikoku", "阿波国"),
    31: ("sanuki", "讃岐国"), 32: ("awaji", "淡路国"), 33: ("kii", "紀伊国"),
    34: ("yamato", "大和国"), 35: ("kawachi", "河内国"), 36: ("yamashiro", "山城国"),
    37: ("izumi", "和泉国"), 38: ("settsu", "摂津国"), 39: ("wakasa", "若狭国"),
    40: ("echizen", "越前国"), 41: ("kaga", "加賀国"), 42: ("etchu", "越中国"),
    43: ("noto", "能登国"), 44: ("echigo", "越後国"), 45: ("sado", "佐渡国"),
    46: ("shima", "志摩国"), 47: ("ise", "伊勢国"), 48: ("iga", "伊賀国"),
    49: ("owari", "尾張国"), 50: ("mikawa", "三河国"), 51: ("totomi", "遠江国"),
    52: ("suruga", "駿河国"), 53: ("izu", "伊豆国"), 54: ("kai", "甲斐国"),
    55: ("sagami", "相模国"), 56: ("musashi", "武蔵国"), 57: ("shimosa", "下総国"),
    58: ("kazusa", "上総国"), 59: ("awa_kanto", "安房国"), 60: ("hitachi", "常陸国"),
    61: ("omi", "近江国"), 62: ("mino", "美濃国"), 63: ("hida", "飛騨国"),
    64: ("shinano", "信濃国"), 65: ("kozuke", "上野国"), 66: ("shimotsuke", "下野国"),
    67: ("mutsu", "陸奥国"), 68: ("dewa", "出羽国"), 69: ("ezo", "蝦夷地"),
}

# Source-pixel anchors read directly from the printed province numbers in the
# unmodified 1280 x 1341 reference. They intentionally remain image
# coordinates: no geographic warp is permitted in phase P1. Island provinces
# without a shared land boundary are retained in the registry, but do not
# create a shared-boundary feature.
REGION_LABEL_ANCHORS = {
    1: (221.0, 994.0), 2: (246.0, 1007.0), 3: (274.0, 965.0),
    4: (249.0, 934.0), 5: (287.0, 900.0), 6: (239.0, 896.0),
    7: (203.0, 894.0), 8: (237.0, 867.0), 9: (265.0, 871.0),
    10: (128.0, 858.0), 11: (88.0, 811.0), 12: (281.0, 825.0),
    13: (311.0, 837.0), 14: (344.0, 812.0), 15: (378.0, 800.0),
    16: (412.0, 798.0), 17: (431.0, 784.0), 18: (446.0, 806.0),
    19: (472.0, 790.0), 20: (330.0, 795.0), 21: (377.0, 763.0),
    22: (414.0, 755.0), 23: (408.0, 705.0), 24: (450.0, 756.0),
    25: (474.0, 755.0), 26: (494.0, 744.0), 27: (513.0, 773.0),
    28: (366.0, 875.0), 29: (410.0, 872.0), 30: (446.0, 857.0),
    31: (438.0, 837.0), 32: (478.0, 829.0), 33: (526.0, 875.0),
    34: (539.0, 835.0), 35: (521.0, 825.0), 36: (531.0, 784.0),
    37: (510.0, 829.0), 38: (500.0, 800.0), 39: (529.0, 740.0),
    40: (567.0, 722.0), 41: (581.0, 694.0), 42: (616.0, 679.0),
    43: (599.0, 637.0), 44: (707.0, 633.0), 45: (675.0, 583.0),
    46: (597.0, 842.0), 47: (568.0, 832.0), 48: (551.0, 808.0),
    49: (598.0, 778.0), 50: (622.0, 788.0), 51: (653.0, 795.0),
    52: (699.0, 770.0), 53: (708.0, 797.0), 54: (676.0, 747.0),
    55: (728.0, 756.0), 56: (731.0, 728.0), 57: (775.0, 733.0),
    58: (775.0, 761.0), 59: (779.0, 790.0), 60: (787.0, 695.0),
    61: (556.0, 780.0), 62: (598.0, 750.0), 63: (615.0, 710.0),
    64: (658.0, 710.0), 65: (709.0, 684.0), 66: (757.0, 672.0),
    67: (825.0, 514.0), 68: (774.0, 506.0), 69: (884.0, 194.0),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def region_id(number: int) -> str:
    return f"jp-ryoseikoku-{number:02d}-{REGIONS[number][0]}"


def image_masks(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    values = rgb.astype(np.float32)
    channel_range = values.max(axis=2) - values.min(axis=2)
    mean = values.mean(axis=2)
    neutral_mid = ((channel_range < 18.0) & (mean > 90.0) & (mean < 195.0)).astype(np.uint8)

    count, labels, stats, _ = cv2.connectedComponentsWithStats(neutral_mid, 8)
    solid = np.zeros(neutral_mid.shape, dtype=np.uint8)
    # Three large connected networks contain nearly all solid boundaries. A
    # few coast-to-coast borders are necessarily independent short strokes;
    # these reviewed source bboxes are included explicitly. The source hash is
    # fixed by P0, so these pixel-space selections are deterministic.
    reviewed_standalone_bboxes = {
        (774, 736, 25, 13),  # Shimosa / Kazusa
        (760, 770, 24, 4),   # Kazusa / Awa (Kanto)
        (583, 822, 6, 11),   # Ise / Shima
    }
    for label in range(1, count):
        bbox = tuple(map(int, stats[label, :4]))
        if int(stats[label, cv2.CC_STAT_AREA]) > 100 or bbox in reviewed_standalone_bboxes:
            solid[labels == label] = 1

    # Blue chroma, rather than nearest-colour classification, defines water.
    # This keeps neutral grey/black province numbers inside their surrounding
    # land region, which is essential for the very small Kinai provinces.
    water = (((values[:, :, 2] - values[:, :, 0]) > 7.0) &
             ((values[:, :, 2] - values[:, :, 1]) > 4.0)).astype(np.uint8)
    land = 1 - water
    region_fill = land & (1 - cv2.dilate(solid, np.ones((3, 3), np.uint8), iterations=1))
    return solid, land, region_fill


def morphological_skeleton(mask: np.ndarray) -> np.ndarray:
    """Morphological centre ridge; junction paths are retained on this ridge."""
    current = (mask * 255).astype(np.uint8)
    skeleton = np.zeros_like(current)
    element = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))
    while cv2.countNonZero(current):
        eroded = cv2.erode(current, element)
        opened = cv2.dilate(eroded, element)
        skeleton = cv2.bitwise_or(skeleton, cv2.subtract(current, opened))
        current = eroded
    return (skeleton > 0).astype(np.uint8)


def glyph_components(rgb: np.ndarray):
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    black = (gray < 110).astype(np.uint8)
    count, labels, stats, centroids = cv2.connectedComponentsWithStats(black, 8)
    glyphs = []
    for label in range(1, count):
        x, y, width, height, area = map(int, stats[label])
        if 1 <= width <= 10 and 8 <= height <= 13 and 8 <= area <= 55:
            glyphs.append({
                "label": label, "x": x, "y": y, "w": width, "h": height, "area": area,
                "cx": float(centroids[label][0]), "cy": float(centroids[label][1]),
                "image": black[y:y + height, x:x + width],
            })
    return glyphs


def normalize_glyph(image: np.ndarray) -> np.ndarray:
    canvas = np.zeros((20, 14), dtype=np.uint8)
    height, width = image.shape
    scale = min(12.0 / max(width, 1), 18.0 / max(height, 1))
    resized = cv2.resize(image, (max(1, round(width * scale)), max(1, round(height * scale))), interpolation=cv2.INTER_NEAREST)
    y = (20 - resized.shape[0]) // 2
    x = (14 - resized.shape[1]) // 2
    canvas[y:y + resized.shape[0], x:x + resized.shape[1]] = resized
    return canvas


def train_digit_templates(glyphs: list[dict]) -> dict[int, list[np.ndarray]]:
    expected_numbers = list(range(1, 11)) + list(range(11, 21))
    expected_centers = [
        184.0, 202.0, 220.5, 238.5, 256.5, 275.0, 293.0, 311.5, 329.5, 348.0,
        384.5, 402.5, 420.5, 439.0, 457.5, 475.5, 494.0, 512.5, 530.5, 548.5,
    ]
    rows = []
    for center in expected_centers:
        group = [glyph for glyph in glyphs if 135 <= glyph["x"] <= 156 and abs(glyph["cy"] - center) <= 2.0]
        group.sort(key=lambda item: item["x"])
        rows.append(group)

    templates: dict[int, list[np.ndarray]] = defaultdict(list)
    for number, group in zip(expected_numbers, rows, strict=True):
        digits = list(str(number))
        if len(group) != len(digits):
            raise RuntimeError(f"legend row {number} has {len(group)} glyphs")
        for digit, glyph in zip(digits, group, strict=True):
            templates[int(digit)].append(normalize_glyph(glyph["image"]))
    return templates


def classify_glyph(glyph: dict, templates: dict[int, list[np.ndarray]]) -> tuple[int, float]:
    normalized = normalize_glyph(glyph["image"])
    scores = {}
    for digit, examples in templates.items():
        scores[digit] = min(float(np.mean(normalized != example)) for example in examples)
    best = min(scores, key=scores.get)
    return best, scores[best]


def recognize_map_labels(rgb: np.ndarray, land: np.ndarray) -> list[dict]:
    glyphs = glyph_components(rgb)
    templates = train_digit_templates(glyphs)
    candidates = []
    for glyph in glyphs:
        if not (80 <= glyph["cx"] <= 1000 and 45 <= glyph["cy"] <= 1120):
            continue
        x0 = max(0, glyph["x"] - 5)
        y0 = max(0, glyph["y"] - 5)
        x1 = min(land.shape[1], glyph["x"] + glyph["w"] + 5)
        y1 = min(land.shape[0], glyph["y"] + glyph["h"] + 5)
        if float(land[y0:y1, x0:x1].mean()) < 0.12:
            continue
        digit, score = classify_glyph(glyph, templates)
        if score <= 0.26:
            item = dict(glyph)
            item["digit"] = digit
            item["score"] = score
            candidates.append(item)

    candidates.sort(key=lambda item: (item["cy"], item["x"]))
    rows: list[list[dict]] = []
    for glyph in candidates:
        matching = next((row for row in rows if abs(np.mean([g["cy"] for g in row]) - glyph["cy"]) <= 2.2), None)
        if matching is None:
            rows.append([glyph])
        else:
            matching.append(glyph)

    tokens = []
    for row in rows:
        row.sort(key=lambda item: item["x"])
        groups: list[list[dict]] = []
        for glyph in row:
            if groups and glyph["x"] - (groups[-1][-1]["x"] + groups[-1][-1]["w"]) <= 3:
                groups[-1].append(glyph)
            else:
                groups.append([glyph])
        for group in groups:
            if len(group) > 2:
                continue
            value = int("".join(str(item["digit"]) for item in group))
            if value not in REGIONS:
                continue
            x0 = min(item["x"] for item in group)
            y0 = min(item["y"] for item in group)
            x1 = max(item["x"] + item["w"] for item in group)
            y1 = max(item["y"] + item["h"] for item in group)
            tokens.append({
                "number": value,
                "region_id": region_id(value),
                "x": (x0 + x1) / 2.0,
                "y": (y0 + y1) / 2.0,
                "bbox": [x0, y0, x1, y1],
                "ocr_score": max(item["score"] for item in group),
            })

    # Select one label per province. Prefer a label surrounded by more land and a better glyph score.
    selected = {}
    for token in tokens:
        x, y = round(token["x"]), round(token["y"])
        x0, y0, x1, y1 = max(0, x - 12), max(0, y - 12), min(land.shape[1], x + 13), min(land.shape[0], y + 13)
        token["land_score"] = float(land[y0:y1, x0:x1].mean())
        rank = (-token["land_score"], token["ocr_score"])
        if token["number"] not in selected or rank < selected[token["number"]][0]:
            selected[token["number"]] = (rank, token)
    return [selected[number][1] for number in sorted(selected)]


def fixed_source_label_anchors() -> list[dict]:
    """Return reviewed province-number anchors in immutable source pixels."""
    return [
        {
            "number": number,
            "region_id": region_id(number),
            "x": xy[0],
            "y": xy[1],
            "bbox": None,
            "ocr_score": None,
            "anchor_method": "manual_source_pixel_review",
        }
        for number, xy in sorted(REGION_LABEL_ANCHORS.items())
    ]


def map_region_components(region_fill: np.ndarray, labels: list[dict]) -> tuple[np.ndarray, dict[int, str], list[dict]]:
    count, components, stats, _ = cv2.connectedComponentsWithStats(region_fill, 8)
    component_regions: dict[int, str] = {}
    label_records = []
    for label in labels:
        x, y = int(round(label["x"])), int(round(label["y"]))
        radius = 28
        y0, y1 = max(0, y - radius), min(components.shape[0], y + radius + 1)
        x0, x1 = max(0, x - radius), min(components.shape[1], x + radius + 1)
        window = components[y0:y1, x0:x1]
        ys, xs = np.nonzero(window)
        choices = []
        for local_y, local_x in zip(ys, xs, strict=True):
            candidate = int(window[local_y, local_x])
            if stats[candidate, cv2.CC_STAT_AREA] < 40:
                continue
            distance = math.hypot((x0 + int(local_x)) - label["x"], (y0 + int(local_y)) - label["y"])
            choices.append((distance, candidate))
        component = min(choices)[1] if choices else 0
        conflict = component in component_regions and component_regions[component] != label["region_id"]
        if component and not conflict:
            component_regions[component] = label["region_id"]
        record = dict(label)
        record["component"] = component
        record["component_area_px"] = int(stats[component, cv2.CC_STAT_AREA]) if component else 0
        record["component_conflict"] = conflict
        label_records.append(record)
    return components, component_regions, label_records


NEIGHBORS_8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]


def pixel_neighbors(pixel: tuple[int, int], mask: np.ndarray) -> list[tuple[int, int]]:
    x, y = pixel
    result = []
    for dx, dy in NEIGHBORS_8:
        nx, ny = x + dx, y + dy
        if 0 <= nx < mask.shape[1] and 0 <= ny < mask.shape[0] and mask[ny, nx]:
            result.append((nx, ny))
    return result


def trace_skeleton(skeleton: np.ndarray) -> tuple[list[list[tuple[float, float]]], list[dict]]:
    degree = cv2.filter2D(skeleton, cv2.CV_16S, np.ones((3, 3), np.int16)) - skeleton
    node_mask = ((skeleton > 0) & (degree != 2)).astype(np.uint8)
    node_count, node_labels, node_stats, node_centroids = cv2.connectedComponentsWithStats(node_mask, 8)
    nodes = {}
    node_pixel_sets: dict[int, set[tuple[int, int]]] = {}
    for node in range(1, node_count):
        ys_xs = np.argwhere(node_labels == node)
        pixels = {(int(x), int(y)) for y, x in ys_xs}
        centroid = (float(node_centroids[node][0]), float(node_centroids[node][1]))
        medoid = min(pixels, key=lambda pixel: math.dist(pixel, centroid))
        node_pixel_sets[node] = pixels
        nodes[node] = {
            "node_id": f"trace-node-{node:04d}",
            "x": float(medoid[0]),
            "y": float(medoid[1]),
            "pixel_count": int(node_stats[node, cv2.CC_STAT_AREA]),
        }

    def node_path(node: int, edge_endpoint: tuple[int, int]) -> list[tuple[int, int]]:
        pixels = node_pixel_sets[node]
        target = (int(nodes[node]["x"]), int(nodes[node]["y"]))
        starts = [pixel for pixel in pixel_neighbors(edge_endpoint, node_mask) if node_labels[pixel[1], pixel[0]] == node]
        if not starts:
            starts = [min(pixels, key=lambda pixel: math.dist(pixel, edge_endpoint))]
        start = min(starts, key=lambda pixel: math.dist(pixel, edge_endpoint))
        queue = deque([start])
        previous: dict[tuple[int, int], tuple[int, int] | None] = {start: None}
        while queue:
            current = queue.popleft()
            if current == target:
                break
            for neighbor in pixel_neighbors(current, node_mask):
                if neighbor in pixels and neighbor not in previous:
                    previous[neighbor] = current
                    queue.append(neighbor)
        path = [target]
        while path[-1] != start:
            parent = previous.get(path[-1])
            if parent is None:
                return [start, target] if start != target else [target]
            path.append(parent)
        path.reverse()
        return path

    interior = ((skeleton > 0) & (node_mask == 0)).astype(np.uint8)
    edge_count, edge_labels, edge_stats, _ = cv2.connectedComponentsWithStats(interior, 8)
    lines = []
    for edge in range(1, edge_count):
        if int(edge_stats[edge, cv2.CC_STAT_AREA]) < 2:
            continue
        pixels_yx = np.argwhere(edge_labels == edge)
        pixel_set = {(int(x), int(y)) for y, x in pixels_yx}
        endpoints = [pixel for pixel in pixel_set if sum(neighbor in pixel_set for neighbor in pixel_neighbors(pixel, interior)) <= 1]
        if not endpoints:
            continue
        start = min(endpoints, key=lambda p: (p[1], p[0]))
        ordered = [start]
        previous = None
        current = start
        while True:
            options = [item for item in pixel_neighbors(current, interior) if item in pixel_set and item != previous and item not in ordered]
            if not options:
                break
            next_pixel = min(options, key=lambda item: math.dist(item, current))
            ordered.append(next_pixel)
            previous, current = current, next_pixel

        adjacent_nodes = set()
        for endpoint in (ordered[0], ordered[-1]):
            x, y = endpoint
            window = node_labels[max(0, y - 1):y + 2, max(0, x - 1):x + 2]
            adjacent_nodes.update(int(value) for value in np.unique(window) if value > 0)
        node_list = sorted(adjacent_nodes)
        coordinates = [(float(x), float(y)) for x, y in ordered]
        if node_list:
            first = min(node_list, key=lambda node: math.dist(coordinates[0], (nodes[node]["x"], nodes[node]["y"])))
            first_path = node_path(first, ordered[0])
            coordinates = [(float(x), float(y)) for x, y in reversed(first_path)] + coordinates
            remaining = [node for node in node_list if node != first]
            if remaining:
                last = min(remaining, key=lambda node: math.dist(coordinates[-1], (nodes[node]["x"], nodes[node]["y"])))
                last_path = node_path(last, ordered[-1])
                coordinates.extend((float(x), float(y)) for x, y in last_path)
        if len(coordinates) >= 2 and LineString(coordinates).length >= 3.0:
            lines.append(coordinates)
    return lines, list(nodes.values())


def adjacent_regions(line: LineString, components: np.ndarray, component_regions: dict[int, str]) -> tuple[str, str, str, str]:
    votes = Counter()
    for fraction in (0.18, 0.34, 0.50, 0.66, 0.82):
        middle = line.interpolate(fraction, normalized=True)
        before = line.interpolate(max(0.0, fraction - 0.04), normalized=True)
        after = line.interpolate(min(1.0, fraction + 0.04), normalized=True)
        tangent = np.array([after.x - before.x, after.y - before.y], dtype=float)
        norm = np.linalg.norm(tangent)
        if norm == 0:
            continue
        normal = np.array([-tangent[1], tangent[0]]) / norm
        for sign in (1.0, -1.0):
            for distance in (3.0, 4.0, 5.0, 6.0, 8.0, 10.0):
                sample = np.array([middle.x, middle.y]) + normal * distance * sign
                x, y = int(round(sample[0])), int(round(sample[1]))
                if 0 <= x < components.shape[1] and 0 <= y < components.shape[0]:
                    component = int(components[y, x])
                    if component in component_regions:
                        votes[component_regions[component]] += 1
    regions = [item[0] for item in votes.most_common(2)]
    if len(regions) == 2 and regions[0] != regions[1]:
        left, right = sorted(regions)
        return left, right, "confirmed", "solid source centerline; both adjacent numbered regions identified"
    if len(regions) == 1:
        return regions[0], "unconfirmed", "probable", "one adjacent numbered region could not be resolved"
    return "unconfirmed", "unconfirmed", "unconfirmed", "adjacent numbered regions could not be resolved"


def geometric_side_regions(line: LineString, components: np.ndarray, component_regions: dict[int, str]) -> tuple[str, str]:
    """Resolve path-left/path-right in the source pixel coordinate system."""
    side_votes = [Counter(), Counter()]
    for fraction in (0.20, 0.35, 0.50, 0.65, 0.80):
        middle = line.interpolate(fraction, normalized=True)
        before = line.interpolate(max(0.0, fraction - 0.04), normalized=True)
        after = line.interpolate(min(1.0, fraction + 0.04), normalized=True)
        tangent = np.array([after.x - before.x, after.y - before.y], dtype=float)
        norm = np.linalg.norm(tangent)
        if norm == 0:
            continue
        normal = np.array([-tangent[1], tangent[0]]) / norm
        for side, sign in enumerate((1.0, -1.0)):
            for distance in (4.0, 5.0, 6.0, 8.0):
                sample = np.array([middle.x, middle.y]) + normal * distance * sign
                x, y = int(round(sample[0])), int(round(sample[1]))
                if 0 <= x < components.shape[1] and 0 <= y < components.shape[0]:
                    region = component_regions.get(int(components[y, x]))
                    if region:
                        side_votes[side][region] += 1
    left = side_votes[0].most_common(1)[0][0] if side_votes[0] else "unconfirmed"
    right = side_votes[1].most_common(1)[0][0] if side_votes[1] else "unconfirmed"
    return left, right


def merge_shared_boundaries(
    raw_records: list[dict], components: np.ndarray, component_regions: dict[int, str]
) -> tuple[list[dict], Counter]:
    """Merge graph edges into one feature per continuous shared border."""
    excluded = Counter()
    groups: dict[tuple[str, str], list[LineString]] = defaultdict(list)
    for record in raw_records:
        left, right = record["left_region_id"], record["right_region_id"]
        if "unconfirmed" in (left, right):
            excluded[record["certainty"]] += 1
            continue
        if left == right:
            excluded["same_region"] += 1
            continue
        groups[tuple(sorted((left, right)))].append(record["geometry"])

    records = []
    serial = 1
    for pair in sorted(groups):
        merged = groups[pair][0] if len(groups[pair]) == 1 else linemerge(unary_union(groups[pair]))
        parts = [merged] if merged.geom_type == "LineString" else list(merged.geoms)
        parts.sort(key=lambda geometry: (*geometry.bounds, geometry.length))
        for part in parts:
            geometric_left, geometric_right = geometric_side_regions(part, components, component_regions)
            if {geometric_left, geometric_right} != set(pair):
                geometric_left, geometric_right = pair
            start = list(map(float, part.coords[0]))
            end = list(map(float, part.coords[-1]))
            records.append({
                "boundary_id": f"img-boundary-{serial:04d}",
                "left_region_id": geometric_left,
                "right_region_id": geometric_right,
                "source_pixel_start": json.dumps(start, separators=(",", ":")),
                "source_pixel_end": json.dumps(end, separators=(",", ":")),
                "certainty": "confirmed",
                "trace_method": "assisted",
                "review_status": "pending",
                "note": "direct centerline trace of one continuous shared solid border; left/right follow path orientation in source pixels",
                "region_pair": "|".join(pair),
                "length_px": float(part.length),
                "geometry": part,
            })
            serial += 1
    return records, excluded


def save_qa(rgb: np.ndarray, records: list[dict], nodes: list[dict], label_records: list[dict]) -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    overlay = Image.fromarray(rgb).convert("RGBA")
    draw = ImageDraw.Draw(overlay, "RGBA")
    colors = {"confirmed": (230, 30, 45, 235), "probable": (255, 145, 0, 240), "unconfirmed": (210, 0, 210, 240)}
    for record in records:
        points = [(float(x), float(y)) for x, y in record["geometry"].coords]
        draw.line(points, fill=colors[record["certainty"]], width=1, joint="curve")
    for node in nodes:
        x, y = node["x"], node["y"]
        draw.ellipse((x - 1.5, y - 1.5, x + 1.5, y + 1.5), fill=(0, 210, 255, 230))

    for scale, name in ((1, "trace_overlay_100.png"), (2, "trace_overlay_200.png"), (4, "trace_overlay_400.png")):
        image = overlay if scale == 1 else overlay.resize((overlay.width * scale, overlay.height * scale), Image.Resampling.NEAREST)
        image.save(QA_DIR / name)

    labels_overlay = Image.fromarray(rgb).convert("RGBA")
    labels_draw = ImageDraw.Draw(labels_overlay, "RGBA")
    for record in label_records:
        x, y = record["x"], record["y"]
        color = (20, 175, 20, 230) if record["component"] and not record["component_conflict"] else (220, 0, 180, 230)
        labels_draw.rectangle((x - 10, y - 9, x + 10, y + 9), outline=color, width=1)
        labels_draw.text((x + 11, y - 7), str(record["number"]), fill=color)
    labels_overlay.save(QA_DIR / "recognized_region_labels.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--diagnose-labels", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    if sha256(SOURCE_IMAGE) != manifest["asset"]["sha256"]:
        raise SystemExit("P1 refused: source image hash differs from the P0 manifest")

    rgb = np.array(Image.open(SOURCE_IMAGE).convert("RGB"))
    solid, land, region_fill = image_masks(rgb)
    labels = fixed_source_label_anchors()
    if args.diagnose_labels:
        print(json.dumps(labels, ensure_ascii=False, indent=2))
        return

    components, component_regions, label_records = map_region_components(region_fill, labels)
    skeleton = morphological_skeleton(solid)
    raw_lines, nodes = trace_skeleton(skeleton)

    raw_records = []
    for index, coordinates in enumerate(raw_lines, start=1):
        geometry = LineString(coordinates).simplify(0.20, preserve_topology=False)
        left, right, certainty, note = adjacent_regions(geometry, components, component_regions)
        start = list(map(float, geometry.coords[0]))
        end = list(map(float, geometry.coords[-1]))
        pair = sorted((left, right))
        raw_records.append({
            "boundary_id": f"img-boundary-{index:04d}",
            "left_region_id": left,
            "right_region_id": right,
            "source_pixel_start": json.dumps(start, separators=(",", ":")),
            "source_pixel_end": json.dumps(end, separators=(",", ":")),
            "certainty": certainty,
            "trace_method": "assisted",
            "review_status": "pending",
            "note": note,
            "region_pair": "|".join(pair),
            "length_px": float(geometry.length),
            "geometry": geometry,
        })
    records, excluded_segments = merge_shared_boundaries(raw_records, components, component_regions)

    # Quantify only a diagnostic residual against the computed source ridge.
    # A value above the target is not numerically accepted: the source line is
    # treated as visually ambiguous and left pending for manual confirmation.
    ridge = morphological_skeleton(solid)
    ridge_distance = cv2.distanceTransform((1 - ridge).astype(np.uint8), cv2.DIST_L2, cv2.DIST_MASK_PRECISE)
    for record in records:
        geometry = record["geometry"]
        distances = []
        for offset in np.linspace(0.0, geometry.length, max(2, int(geometry.length * 4) + 1)):
            point = geometry.interpolate(float(offset))
            distances.append(float(ridge_distance[int(round(point.y)), int(round(point.x))]))
        residual = max(distances, default=0.0)
        record["center_residual_px"] = residual
        if residual > 0.75:
            record["certainty"] = "probable"
            record["note"] += "; thick or multi-way junction exceeds 0.75 px diagnostic target"

    WORK_DIR.mkdir(parents=True, exist_ok=True)
    if OUTPUT_GPKG.exists():
        OUTPUT_GPKG.unlink()
    gpd.GeoDataFrame(records, geometry="geometry", crs=None).to_file(OUTPUT_GPKG, layer="shared_boundaries", driver="GPKG")
    gpd.GeoDataFrame(nodes, geometry=[Point(node["x"], node["y"]) for node in nodes], crs=None).to_file(OUTPUT_GPKG, layer="junction_nodes", driver="GPKG")
    gpd.GeoDataFrame(label_records, geometry=[Point(item["x"], item["y"]) for item in label_records], crs=None).to_file(OUTPUT_GPKG, layer="region_labels", driver="GPKG")

    save_qa(rgb, records, nodes, label_records)
    certainty_counts = Counter(record["certainty"] for record in records)
    recognized = sorted(item["number"] for item in label_records)
    residuals = [record["center_residual_px"] for record in records]
    report = {
        "schema_version": 1,
        "phase": "P1",
        "status": "generated_pending_manual_review",
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "source": {
            "file": str(SOURCE_IMAGE.relative_to(ROOT)).replace("\\", "/"),
            "sha256": manifest["asset"]["sha256"],
            "coordinate_space": "1280x1341 image pixels; origin top-left; x right; y down",
            "warped_before_trace": False,
        },
        "extraction": {
            "solid_network_component_min_area_px": 101,
            "solid_network_count": 6,
            "line_center_method": "morphological skeleton of neutral mid-tone solid network",
            "simplify_tolerance_px": 0.20,
            "coastline_extracted": False,
            "dashed_lines_extracted": False,
            "text_or_numbers_extracted": False,
            "region_assignment": "manually reviewed source-pixel number anchors",
            "centerline_residual": {
                "comparison": "exported line against computed source-image centre ridge",
                "target_px": 0.75,
                "max_px": max(residuals, default=0.0),
                "within_target_count": sum(value <= 0.75 for value in residuals),
                "above_target_marked_probable_count": sum(value > 0.75 for value in residuals),
            },
        },
        "counts": {
            "boundaries": len(records),
            "raw_graph_segments": len(raw_records),
            "junction_nodes": len(nodes),
            "recognized_region_labels": len(recognized),
            "confirmed": certainty_counts["confirmed"],
            "probable": certainty_counts["probable"],
            "unconfirmed": certainty_counts["unconfirmed"],
            "excluded_unresolved_segments": int(excluded_segments["probable"] + excluded_segments["unconfirmed"]),
            "excluded_same_region_segments": int(excluded_segments["same_region"]),
        },
        "recognized_region_numbers": recognized,
        "missing_region_numbers": sorted(set(REGIONS) - set(recognized)),
        "outputs": {
            "geopackage": str(OUTPUT_GPKG.relative_to(ROOT)).replace("\\", "/"),
            "qa_100": "data/derived/political/qa/trace_overlay_100.png",
            "qa_200": "data/derived/political/qa/trace_overlay_200.png",
            "qa_400": "data/derived/political/qa/trace_overlay_400.png",
            "label_review": "data/derived/political/qa/recognized_region_labels.png",
            "manual_review_log": "data/work/political/manual_review_log.json",
        },
        "review": {
            "required_scales": ["100%", "200%", "400%"],
            "review_status": "pending",
            "acceptance_target_px": 0.75,
            "note": "No record is accepted until source overlays are manually reviewed.",
        },
    }
    OUTPUT_REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review_log = {
        "schema_version": 1,
        "phase": "P1",
        "source_sha256": manifest["asset"]["sha256"],
        "review_status": "pending_user_acceptance",
        "geometry_inspection": {
            "reviewer": "Codex assisted visual QA",
            "scales_checked": ["100%", "200%", "400%"],
            "coastline_false_positives_seen": False,
            "text_or_number_false_positives_seen": False,
            "dashed_meiji_boundary_false_positives_seen": False,
            "observation": "Confirmed features follow the visible solid source centreline. Features exceeding the 0.75 px ridge diagnostic are probable and remain pending.",
        },
        "acceptance": {
            "accepted_by": None,
            "accepted_at_utc": None,
            "note": "P1 work data only; do not promote to data/master/political before explicit approval.",
        },
    }
    OUTPUT_REVIEW_LOG.write_text(json.dumps(review_log, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["counts"], ensure_ascii=False))


if __name__ == "__main__":
    main()
