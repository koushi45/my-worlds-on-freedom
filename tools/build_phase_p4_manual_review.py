"""Generate Phase P4 national and regional manual-review packages.

All review scopes remain pending until the user explicitly accepts them.
National views never present pending candidates as accepted political data.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

import geopandas as gpd
from PIL import Image, ImageDraw, ImageFont
from shapely.geometry import LineString, MultiLineString, MultiPolygon, Point, Polygon, box
from shapely.ops import polygonize_full, substring, unary_union

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_phase_p1_trace as p1  # noqa: E402
import build_phase_p2_regional_warp as p2  # noqa: E402
import build_phase_p3_political_regions as p3  # noqa: E402

OUT_DIR = ROOT / "data/derived/political/qa/p4"
REVIEW_REGISTRY = p3.WORK_DIR / "regional_review_status.json"
REPORT_PATH = p3.WORK_DIR / "p4_review_report.json"
INDEX_PATH = OUT_DIR / "README.md"
WIDTH = 1600
HEIGHT = 1200
MARGIN = 70

SCOPES = {
    "national": {"name_ja": "全国", "numbers": list(range(1, 70))},
    "kyushu": {"name_ja": "九州", "numbers": list(range(1, 10))},
    "shikoku": {"name_ja": "四国", "numbers": [28, 29, 30, 31]},
    "chugoku": {"name_ja": "中国", "numbers": [n for n in range(12, 28) if n != 23]},
    "kinki": {"name_ja": "近畿", "numbers": [33, 34, 35, 36, 37, 38, 39, 48, 61]},
    "tokai": {"name_ja": "東海", "numbers": [46, 47, 49, 50, 51, 52, 53, 62, 63]},
    "kanto": {"name_ja": "関東", "numbers": [55, 56, 57, 58, 59, 60, 65, 66]},
    "koshinetsu_hokuriku": {"name_ja": "甲信越・北陸", "numbers": [40, 41, 42, 43, 44, 54, 64]},
    "tohoku": {"name_ja": "東北・蝦夷地", "numbers": [67, 68, 69]},
    "major_islands": {"name_ja": "主要離島", "numbers": [10, 11, 23, 32, 45]},
}
REVIEW_ORDER = [
    "kyushu", "shikoku", "chugoku", "kinki", "tokai", "kanto",
    "koshinetsu_hokuriku", "tohoku", "major_islands",
]

IMAGE_TYPES = {
    "01_source_trace_overlay": "指定画像＋画像座標トレース",
    "02_warped_boundary_land": "変換後境界＋japan_land",
    "03_region_translucent_fill": "国別半透明塗り分け",
    "04_adjacency_errors": "隣接関係エラー",
    "05_topology_issues": "重複・隙間・自己交差・未閉鎖面",
    "06_unconfirmed_segments_endpoints": "unconfirmed区間・端点",
    "07_coastline_reference_segments": "海岸線参照区間",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def font(size: int):
    candidates = [
        Path("C:/Windows/Fonts/YuGothM.ttc"), Path("C:/Windows/Fonts/meiryo.ttc"),
        Path("C:/Windows/Fonts/msgothic.ttc"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def parts(geometry, kind):
    if geometry is None or geometry.is_empty:
        return []
    if isinstance(geometry, kind):
        return [geometry]
    if hasattr(geometry, "geoms"):
        result = []
        for item in geometry.geoms:
            result.extend(parts(item, kind))
        return result
    return []


def region_ids(scope_id: str) -> set[str]:
    return {p1.region_id(number) for number in SCOPES[scope_id]["numbers"]}


def filter_boundaries(frame: gpd.GeoDataFrame, scope_id: str) -> gpd.GeoDataFrame:
    if scope_id == "national":
        return frame
    ids = region_ids(scope_id)
    return frame[frame["left_region_id"].isin(ids) | frame["right_region_id"].isin(ids)]


def padded_bounds(bounds, fraction=0.08, minimum=30.0):
    min_x, min_y, max_x, max_y = map(float, bounds)
    width = max(max_x - min_x, minimum)
    height = max(max_y - min_y, minimum)
    pad = max(width, height) * fraction
    return min_x - pad, min_y - pad, max_x + pad, max_y + pad


class Canvas:
    def __init__(self, bounds, title: str, subtitle: str, background=(35, 62, 75)):
        self.bounds = bounds
        self.image = Image.new("RGB", (WIDTH, HEIGHT), background)
        self.draw = ImageDraw.Draw(self.image, "RGBA")
        self.title = title
        self.subtitle = subtitle

    def xy(self, x, y):
        min_x, min_y, max_x, max_y = self.bounds
        available_w = WIDTH - MARGIN * 2
        available_h = HEIGHT - MARGIN * 2
        scale = min(available_w / max(max_x - min_x, 1e-9), available_h / max(max_y - min_y, 1e-9))
        offset_x = MARGIN + (available_w - (max_x - min_x) * scale) / 2
        offset_y = MARGIN + (available_h - (max_y - min_y) * scale) / 2
        return offset_x + (x - min_x) * scale, offset_y + (y - min_y) * scale

    def coords(self, coordinates):
        return [self.xy(x, y) for x, y in coordinates]

    def polygon(self, geometry, fill, outline=None, width=1):
        for polygon in parts(geometry, Polygon):
            points = self.coords(polygon.exterior.coords)
            self.draw.polygon(points, fill=fill)
            if outline:
                self.draw.line(points, fill=outline, width=width, joint="curve")
            for ring in polygon.interiors:
                self.draw.polygon(self.coords(ring.coords), fill=(35, 62, 75, 255))

    def line(self, geometry, fill, width=2):
        for line in parts(geometry, LineString):
            self.draw.line(self.coords(line.coords), fill=fill, width=width, joint="curve")

    def point(self, geometry, fill, radius=4):
        x, y = self.xy(geometry.x, geometry.y)
        self.draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=fill)

    def finish(self, path: Path, legend: list[tuple[str, tuple]], notes: list[str] | None = None):
        self.draw.rectangle((0, 0, WIDTH, 56), fill=(16, 25, 31, 225))
        self.draw.text((18, 8), self.title, font=font(24), fill=(255, 255, 255, 255))
        self.draw.text((WIDTH - 600, 13), self.subtitle, font=font(16), fill=(220, 225, 230, 255))
        x = 18
        y = HEIGHT - 38
        self.draw.rectangle((0, HEIGHT - 48, WIDTH, HEIGHT), fill=(16, 25, 31, 220))
        for label, color in legend:
            self.draw.rectangle((x, y, x + 16, y + 16), fill=color)
            self.draw.text((x + 23, y - 3), label, font=font(14), fill=(255, 255, 255, 255))
            x += 35 + max(90, len(label) * 16)
        if notes:
            note_y = 68
            for note in notes[:12]:
                self.draw.text((18, note_y), note, font=font(14), fill=(30, 30, 30, 255), stroke_width=2, stroke_fill=(255, 255, 255, 220))
                note_y += 20
        path.parent.mkdir(parents=True, exist_ok=True)
        self.image.save(path)


def source_bounds(scope_id, source_boundaries, source_labels):
    if scope_id == "national":
        return (0.0, 0.0, 1280.0, 1341.0)
    scoped = filter_boundaries(source_boundaries, scope_id)
    label_subset = source_labels[source_labels["number"].isin(SCOPES[scope_id]["numbers"])]
    geometries = [*scoped.geometry, *label_subset.geometry]
    if not geometries:
        return (0.0, 0.0, 1280.0, 1341.0)
    return padded_bounds(unary_union(geometries).bounds, 0.12, 20.0)


def target_bounds(scope_id, target_boundaries, labels):
    if scope_id == "national":
        return (0.0, 0.0, 8192.0, 8192.0)
    scoped = filter_boundaries(target_boundaries, scope_id)
    label_subset = labels[
        labels["number"].isin(SCOPES[scope_id]["numbers"]) & labels.geometry.notna()
    ]
    geometries = [*scoped.geometry, *label_subset.geometry]
    if not geometries:
        return (0.0, 0.0, 8192.0, 8192.0)
    return padded_bounds(unary_union(geometries).bounds, 0.12, 100.0)


def draw_land(canvas, land_union, clip):
    canvas.polygon(land_union.intersection(clip), (245, 242, 230, 255))


def source_overlay(scope_id, source_boundaries, source_labels, output):
    bounds = source_bounds(scope_id, source_boundaries, source_labels)
    source = Image.open(p2.SOURCE_IMAGE).convert("RGB")
    left, top, right, bottom = bounds
    crop = source.crop((max(0, int(left)), max(0, int(top)), min(1280, int(math.ceil(right))), min(1341, int(math.ceil(bottom)))))
    crop.thumbnail((WIDTH - 2*MARGIN, HEIGHT - 2*MARGIN), Image.Resampling.LANCZOS)
    canvas = Canvas(bounds, f"P4 / {SCOPES[scope_id]['name_ja']} / 01", IMAGE_TYPES["01_source_trace_overlay"], background=(238, 238, 238))
    # Rebuild background to the same fit used by vector coordinates.
    bx0, by0 = canvas.xy(max(0, left), max(0, top))
    bx1, by1 = canvas.xy(min(1280, right), min(1341, bottom))
    resized = crop.resize((max(1, int(bx1-bx0)), max(1, int(by1-by0))), Image.Resampling.LANCZOS)
    canvas.image.paste(resized, (int(bx0), int(by0)))
    canvas.draw = ImageDraw.Draw(canvas.image, "RGBA")
    for row in filter_boundaries(source_boundaries, scope_id).itertuples(index=False):
        color = (0, 210, 255, 235) if row.certainty == "confirmed" else (255, 130, 0, 245)
        canvas.line(row.geometry, color, 3)
    canvas.finish(output, [("confirmed trace", (0,210,255,255)), ("probable trace", (255,130,0,255))])


def render_target_views(scope_id, context, output_dir):
    boundaries = filter_boundaries(context["boundaries"], scope_id)
    ids = region_ids(scope_id)
    candidates = context["candidates"][context["candidates"]["region_id"].isin(ids)]
    ambiguous = context["ambiguous"]
    endpoints = context["endpoints"][context["endpoints"]["boundary_id"].isin(boundaries["boundary_id"])]
    bounds = target_bounds(scope_id, context["boundaries"], context["labels"])
    clip = box(*bounds)
    land = context["land_union"]

    canvas = Canvas(bounds, f"P4 / {SCOPES[scope_id]['name_ja']} / 02", IMAGE_TYPES["02_warped_boundary_land"])
    draw_land(canvas, land, clip)
    canvas.line(context["coast_union"].intersection(clip), (38,38,38,255), 2)
    for row in boundaries.itertuples(index=False):
        canvas.line(row.geometry, (34, 83, 178, 255) if row.certainty == "confirmed" else (235, 130, 25, 255), 3)
    canvas.finish(output_dir / "02_warped_boundary_land.png", [("canonical coast", (38,38,38,255)), ("warped border", (34,83,178,255))])

    canvas = Canvas(bounds, f"P4 / {SCOPES[scope_id]['name_ja']} / 03", IMAGE_TYPES["03_region_translucent_fill"])
    draw_land(canvas, land, clip)
    if scope_id != "national":
        palette = [(54,162,235,110), (234,102,128,110), (71,190,125,110), (177,114,222,110)]
        for index, row in enumerate(candidates.itertuples(index=False)):
            canvas.polygon(row.geometry, palette[index % len(palette)], (25,25,25,220), 2)
    canvas.line(context["coast_union"].intersection(clip), (35,35,35,255), 2)
    note = ["全国版はacceptedのみ表示（現在0件）"] if scope_id == "national" else [f"pending候補: {len(candidates)}件（承認色ではない）"]
    canvas.finish(output_dir / "03_region_translucent_fill.png", [("pending candidate", (54,162,235,150)), ("unassigned land", (245,242,230,255))], note)

    canvas = Canvas(bounds, f"P4 / {SCOPES[scope_id]['name_ja']} / 04", IMAGE_TYPES["04_adjacency_errors"])
    draw_land(canvas, land, clip)
    adjacency_by_boundary = context["adjacency_by_boundary"]
    counts = {"match": 0, "mismatch": 0, "not_testable_missing_region": 0}
    colors = {"match": (30,175,95,255), "mismatch": (220,35,55,255), "not_testable_missing_region": (245,145,25,255)}
    for row in boundaries.itertuples(index=False):
        status = adjacency_by_boundary.get(row.boundary_id, "not_testable_missing_region")
        counts[status] = counts.get(status, 0) + 1
        canvas.line(row.geometry, colors[status], 4)
    canvas.finish(output_dir / "04_adjacency_errors.png", [("match", colors["match"]), ("mismatch", colors["mismatch"]), ("not testable", colors["not_testable_missing_region"])], [f"{key}: {value}" for key,value in counts.items()])

    canvas = Canvas(bounds, f"P4 / {SCOPES[scope_id]['name_ja']} / 05", IMAGE_TYPES["05_topology_issues"])
    draw_land(canvas, land, clip)
    candidate_union = candidates.geometry.union_all() if not candidates.empty else Polygon()
    gap = land.intersection(clip).difference(candidate_union)
    canvas.polygon(gap, (220, 45, 45, 70))
    for row in ambiguous[ambiguous.geometry.intersects(clip)].itertuples(index=False):
        canvas.polygon(row.geometry.intersection(clip), (245, 160, 35, 75), (225,120,20,180), 1)
    for row in boundaries[~boundaries.geometry.is_simple].itertuples(index=False):
        canvas.line(row.geometry, (190, 30, 210, 255), 5)
    for row in endpoints[endpoints["status"] == "unconfirmed_endpoint"].itertuples(index=False):
        canvas.point(row.geometry, (255, 20, 20, 255), 5)
    canvas.finish(output_dir / "05_topology_issues.png", [("unassigned gap", (220,45,45,150)), ("ambiguous face", (245,160,35,170)), ("self-intersection", (190,30,210,255)), ("open endpoint", (255,20,20,255))])

    canvas = Canvas(bounds, f"P4 / {SCOPES[scope_id]['name_ja']} / 06", IMAGE_TYPES["06_unconfirmed_segments_endpoints"])
    draw_land(canvas, land, clip)
    unconfirmed_lines = boundaries[(boundaries["certainty"] != "confirmed") | (boundaries["review_status"] != "accepted")]
    for row in unconfirmed_lines.itertuples(index=False):
        canvas.line(row.geometry, (245, 135, 25, 255), 4)
    open_endpoints = endpoints[endpoints["status"] == "unconfirmed_endpoint"]
    for row in open_endpoints.itertuples(index=False):
        canvas.point(row.geometry, (230, 25, 35, 255), 6)
    notes = [f"segments: {len(unconfirmed_lines)} / endpoints: {len(open_endpoints)}"] + open_endpoints["endpoint_id"].tolist()[:10]
    canvas.finish(output_dir / "06_unconfirmed_segments_endpoints.png", [("unconfirmed/pending segment", (245,135,25,255)), ("unconfirmed endpoint", (230,25,35,255))], notes)

    canvas = Canvas(bounds, f"P4 / {SCOPES[scope_id]['name_ja']} / 07", IMAGE_TYPES["07_coastline_reference_segments"])
    draw_land(canvas, land, clip)
    canvas.line(context["coast_union"].intersection(clip), (120, 125, 130, 255), 2)
    ref_count = 0
    for reference in context["coast_refs"]:
        if reference["part_id"].split(":part-")[0] not in ids:
            continue
        coast = context["coast_lookup"][reference["coastline_id"]]
        start = reference["start_distance_8192"]
        end = reference["end_distance_8192"]
        segment = substring(coast, min(start, end), max(start, end))
        canvas.line(segment, (0, 210, 235, 255), 5)
        ref_count += 1
    canvas.finish(output_dir / "07_coastline_reference_segments.png", [("canonical coast", (120,125,130,255)), ("referenced interval", (0,210,235,255))], [f"coastline references: {ref_count}"])

    return {
        "scope_id": scope_id,
        "name_ja": SCOPES[scope_id]["name_ja"],
        "status": "pending",
        "region_ids": sorted(ids),
        "candidate_parts": len(candidates),
        "unconfirmed_segments": len(boundaries[(boundaries["certainty"] != "confirmed") | (boundaries["review_status"] != "accepted")]),
        "unconfirmed_endpoints": int((endpoints["status"] == "unconfirmed_endpoint").sum()),
        "artifacts": {key: f"data/derived/political/qa/p4/{scope_id}/{key}.png" for key in IMAGE_TYPES},
    }


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source_boundaries = gpd.read_file(p2.P1_GPKG, layer="shared_boundaries")
    source_labels = gpd.read_file(p2.P1_GPKG, layer="region_labels")
    boundaries = gpd.read_file(p2.WARPED_GPKG, layer="shared_boundaries_8192")
    candidates = gpd.read_file(p3.OUTPUT_GPKG, layer="closed_region_candidates")
    ambiguous = gpd.read_file(p3.OUTPUT_GPKG, layer="ambiguous_closed_faces")
    endpoints = gpd.read_file(p3.OUTPUT_GPKG, layer="boundary_endpoints")
    labels = gpd.read_file(p3.OUTPUT_GPKG, layer="region_label_anchors_8192")
    coasts = gpd.read_file(p2.COAST_GPKG, layer="coastline_8192")
    _, land_union = p3.canonical_land_8192()
    adjacency = json.loads(p3.ADJACENCY_JSON.read_text(encoding="utf-8"))
    adjacency_by_boundary = {}
    for row in adjacency["expected_named_adjacencies"]:
        for boundary_id in row["source_boundary_ids"]:
            adjacency_by_boundary[boundary_id] = row["status"]
    coast_refs = json.loads(p3.COAST_REFS_JSON.read_text(encoding="utf-8"))["references"]
    context = {
        "boundaries": boundaries, "candidates": candidates, "ambiguous": ambiguous,
        "endpoints": endpoints, "labels": labels, "land_union": land_union,
        "coast_union": coasts.geometry.union_all(), "coast_refs": coast_refs,
        "coast_lookup": dict(zip(coasts["coastline_id"], coasts.geometry)),
        "adjacency_by_boundary": adjacency_by_boundary,
    }

    review_scopes = []
    for scope_id in ["national", *REVIEW_ORDER]:
        scope_dir = OUT_DIR / scope_id
        source_overlay(scope_id, source_boundaries, source_labels, scope_dir / "01_source_trace_overlay.png")
        review_scopes.append(render_target_views(scope_id, context, scope_dir))
        scoped_boundaries = filter_boundaries(boundaries, scope_id)
        scoped_ids = region_ids(scope_id)
        scoped_candidates = candidates[candidates["region_id"].isin(scoped_ids)]
        scoped_endpoints = endpoints[endpoints["boundary_id"].isin(scoped_boundaries["boundary_id"])]
        scoped_clip = box(*target_bounds(scope_id, boundaries, labels))
        candidate_union = scoped_candidates.geometry.union_all() if not scoped_candidates.empty else Polygon()
        overlaps = []
        for left_position, left in enumerate(scoped_candidates.itertuples(index=False)):
            for right in list(scoped_candidates.itertuples(index=False))[left_position + 1:]:
                area = left.geometry.intersection(right.geometry).area
                if area > p3.EPSILON:
                    overlaps.append({"left_part_id": left.part_id, "right_part_id": right.part_id, "area_8192": area})
        adjacency_items = []
        for item in adjacency["expected_named_adjacencies"]:
            if set((item["left_region_id"], item["right_region_id"])) & scoped_ids:
                adjacency_items.append(item)
        (scope_dir / "review_items.json").write_text(json.dumps({
            "scope_id": scope_id,
            "status": "pending",
            "unconfirmed_endpoint_ids": scoped_endpoints.loc[scoped_endpoints["status"] == "unconfirmed_endpoint", "endpoint_id"].tolist(),
            "unconfirmed_boundary_ids": scoped_boundaries.loc[
                (scoped_boundaries["certainty"] != "confirmed") | (scoped_boundaries["review_status"] != "accepted"), "boundary_id"
            ].tolist(),
            "non_simple_boundary_ids": scoped_boundaries.loc[~scoped_boundaries.geometry.is_simple, "boundary_id"].tolist(),
            "ambiguous_face_ids": ambiguous.loc[ambiguous.geometry.intersects(scoped_clip), "face_id"].tolist(),
            "overlap_pairs": overlaps,
            "unassigned_gap_area_8192": float(land_union.intersection(scoped_clip).difference(candidate_union).area),
            "adjacency_items": adjacency_items,
            "coastline_reference_items": [item for item in coast_refs if item["part_id"].split(":part-")[0] in scoped_ids],
        }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    registry = {
        "schema_version": 1,
        "phase": "P4",
        "review_order": REVIEW_ORDER,
        "national_policy": "only explicitly accepted regional data may enter an accepted national set",
        "accepted_region_ids": [],
        "all_regions_accepted": False,
        "scopes": {row["scope_id"]: row for row in review_scopes},
        "acceptance_log": [],
    }
    REVIEW_REGISTRY.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    index_lines = [
        "# Phase P4 manual review", "",
        "All scopes are pending. Review order: " + " → ".join(REVIEW_ORDER) + ".", "",
        "The national accepted set is empty until regional approval is explicitly recorded.", "",
    ]
    for scope_id in ["national", *REVIEW_ORDER]:
        index_lines.extend([f"## {SCOPES[scope_id]['name_ja']} (`{scope_id}`)", ""])
        for image_id, description in IMAGE_TYPES.items():
            index_lines.append(f"- [{description}]({scope_id}/{image_id}.png)")
        index_lines.extend([f"- [Review item list]({scope_id}/review_items.json)", ""])
    INDEX_PATH.write_text("\n".join(index_lines) + "\n", encoding="utf-8")
    images = sorted(OUT_DIR.glob("*/*.png"))
    report = {
        "schema_version": 1, "phase": "P4", "status": "generated_pending_user_review",
        "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "review_order": REVIEW_ORDER,
        "counts": {"scopes": len(review_scopes), "image_types": len(IMAGE_TYPES), "images": len(images), "accepted_scopes": 0},
        "national_acceptance_policy_enforced": True,
        "source_hashes": {
            "reference_image": sha256(p2.SOURCE_IMAGE), "p1_trace": sha256(p2.P1_GPKG),
            "p2_boundaries": sha256(p2.WARPED_GPKG), "p3_candidates": sha256(p3.OUTPUT_GPKG),
            "canonical_land": sha256(p2.MASTER_LAND), "canonical_coastline": sha256(p2.COAST_GPKG),
        },
        "outputs": {
            "qa_root": OUT_DIR.relative_to(ROOT).as_posix(),
            "qa_index": INDEX_PATH.relative_to(ROOT).as_posix(),
            "review_registry": REVIEW_REGISTRY.relative_to(ROOT).as_posix(),
            "image_sha256": {path.relative_to(ROOT).as_posix(): sha256(path) for path in images},
        },
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["counts"], ensure_ascii=False))


if __name__ == "__main__":
    main()
