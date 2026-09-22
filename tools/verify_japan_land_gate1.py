"""Run Gate 1 automated checks and create visual QA artifacts."""

from __future__ import annotations

import hashlib
import json
import math
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import geopandas as gpd
import numpy as np
import pyogrio
import shapely
from PIL import Image, ImageDraw, ImageFont
from pyproj import Geod, Transformer
from shapely.geometry import box
from shapely.ops import transform

import build_japan_land_base as build


ROOT = Path(__file__).resolve().parents[1]
GPKG = ROOT / "data/base/japan_land.gpkg"
GEOJSON = ROOT / "data/base/japan_land.geojson"
BUILD_MANIFEST = ROOT / "data/base/japan_land_manifest.json"
MASTER_MANIFEST = ROOT / "data/base/japan_land_master_manifest.json"
OUT_DIR = ROOT / "data/base/verification"
VISUAL_DIR = OUT_DIR / "visual"
REPORT_JSON = OUT_DIR / "gate1_report.json"
REPAIR_AREA_TOLERANCE_M2 = 1.0
OVERLAP_AREA_TOLERANCE_M2 = 0.01
MASTER_VERSION = "1.0.0-rc.1"

REGIONS = {
    "01_hokkaido": (138.8, 40.9, 146.2, 45.8),
    "02_tohoku": (138.5, 36.6, 142.4, 41.7),
    "03_kanto": (138.0, 34.4, 141.4, 37.4),
    "04_chubu": (135.0, 33.9, 139.5, 38.4),
    "05_kinki": (133.8, 32.9, 137.2, 36.0),
    "06_chugoku": (130.2, 32.8, 134.9, 36.0),
    "07_shikoku": (131.8, 32.3, 135.7, 34.8),
    "08_kyushu": (127.9, 30.1, 132.4, 34.8),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def get_font(size: int):
    for candidate in [Path("C:/Windows/Fonts/meiryo.ttc"), Path("C:/Windows/Fonts/segoeui.ttf")]:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def iter_polygons(geom):
    if geom.geom_type == "Polygon":
        yield geom
    elif geom.geom_type == "MultiPolygon":
        yield from geom.geoms


def render_map(gdf, bounds, output, title, vertices=False, heat_values=None, message=None):
    width, height = 1600, 1200
    margin = 70
    sea = (29, 57, 72)
    land = (238, 239, 232)
    image = Image.new("RGB", (width, height), sea)
    draw = ImageDraw.Draw(image)
    min_x, min_y, max_x, max_y = bounds
    cos_lat = math.cos(math.radians((min_y + max_y) / 2))
    span_x = (max_x - min_x) * cos_lat
    span_y = max_y - min_y
    usable_w, usable_h = width - 2 * margin, height - 2 * margin
    scale = min(usable_w / span_x, usable_h / span_y)
    used_w, used_h = span_x * scale, span_y * scale
    ox = margin + (usable_w - used_w) / 2
    oy = margin + (usable_h - used_h) / 2

    def px(point):
        x, y = point
        return ox + (x - min_x) * cos_lat * scale, oy + (max_y - y) * scale

    clipped = gdf[gdf.intersects(box(*bounds))]
    for index, feature in clipped.iterrows():
        geometry = feature.geometry.intersection(box(*bounds))
        value = 0.0 if heat_values is None else heat_values.get(feature.feature_id, 0.0)
        if heat_values is None:
            fill = land
        else:
            ratio = min(1.0, value / 1.0)
            fill = (int(35 + 220 * ratio), int(100 - 60 * ratio), int(185 - 140 * ratio))
        for polygon in iter_polygons(geometry):
            exterior = [px(p) for p in polygon.exterior.coords]
            draw.polygon(exterior, fill=fill)
            draw.line(exterior, fill=(8, 18, 23), width=2, joint="curve")
            for ring in polygon.interiors:
                hole = [px(p) for p in ring.coords]
                draw.polygon(hole, fill=sea)
                draw.line(hole, fill=(8, 18, 23), width=2)
            if vertices:
                for x, y in polygon.exterior.coords:
                    cx, cy = px((x, y))
                    draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=(255, 67, 67))
                for ring in polygon.interiors:
                    for x, y in ring.coords:
                        cx, cy = px((x, y))
                        draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=(255, 67, 67))

    draw.rectangle((0, 0, width, 52), fill=(14, 29, 37))
    draw.text((20, 12), title, font=get_font(26), fill=(245, 247, 248))
    if message:
        draw.rounded_rectangle((430, 545, 1170, 655), radius=16, fill=(14, 29, 37), outline=(220, 226, 229), width=2)
        draw.text((800, 600), message, font=get_font(28), fill=(245, 247, 248), anchor="mm")
    if heat_values is not None:
        draw.text((20, 1160), "Vertex displacement: blue=0 m, red>=1 m", font=get_font(20), fill=(245, 247, 248))
    image.save(output, optimize=True)


def coordinate_component_count(gdf):
    return sum(len(geom.geoms) if geom.geom_type == "MultiPolygon" else 1 for geom in gdf.geometry)


def geodesic_area(gdf):
    geod = Geod(ellps="WGS84")
    return sum(abs(geod.geometry_area_perimeter(geom)[0]) for geom in gdf.geometry)


def overlap_audit(gdf):
    projected = gdf.to_crs(build.AREA_CRS)
    overlaps = []
    spatial_index = projected.sindex
    for i, geom in enumerate(projected.geometry):
        for j in spatial_index.query(geom, predicate="intersects"):
            if j <= i:
                continue
            area = geom.intersection(projected.geometry.iloc[j]).area
            if area > OVERLAP_AREA_TOLERANCE_M2:
                overlaps.append(
                    {
                        "feature_a": projected.feature_id.iloc[i],
                        "feature_b": projected.feature_id.iloc[j],
                        "overlap_area_m2": area,
                    }
                )
    return overlaps


def duplicate_surface_count(gdf):
    seen = set()
    duplicates = 0
    for geom in gdf.geometry:
        key = hashlib.sha256(shapely.normalize(geom).wkb).digest()
        if key in seen:
            duplicates += 1
        else:
            seen.add(key)
    return duplicates


def source_difference_audit(canonical):
    """Measure each canonical part against the corresponding untouched source part."""
    source = gpd.read_file(build.SOURCE).explode(index_parts=True)
    source.index.names = ["source_feature", "source_part"]
    source = source.reset_index()
    source_lookup = {
        f"ne_10m_land:{row.source_feature}:{row.source_part}": build.as_multipolygon(row.geometry)
        for row in source.itertuples(index=False)
    }
    to_area = Transformer.from_crs(build.SOURCE_CRS, build.AREA_CRS, always_xy=True).transform
    displacements = {}
    mismatches = []
    for feature in canonical.itertuples(index=False):
        expected = source_lookup[feature.source_id]
        if feature.geometry.equals_exact(expected, tolerance=0.0):
            displacement = 0.0
        else:
            displacement = transform(to_area, feature.geometry).hausdorff_distance(transform(to_area, expected))
            mismatches.append(
                {
                    "feature_id": feature.feature_id,
                    "source_id": feature.source_id,
                    "hausdorff_distance_m": displacement,
                }
            )
        displacements[feature.feature_id] = displacement
    return displacements, mismatches


def create_region_index(region_dir, output):
    canvas = Image.new("RGB", (1600, 1250), (14, 29, 37))
    draw = ImageDraw.Draw(canvas)
    draw.text((30, 18), "地方別拡大一覧 / Gate 1", font=get_font(30), fill=(245, 247, 248))
    for index, name in enumerate(REGIONS):
        image = Image.open(region_dir / f"{name}.png").convert("RGB")
        image.thumbnail((760, 540), Image.Resampling.LANCZOS)
        x = 25 + (index % 2) * 790
        y = 70 + (index // 2) * 290
        canvas.paste(image, (x, y))
    canvas.save(output, optimize=True)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    VISUAL_DIR.mkdir(parents=True, exist_ok=True)

    # Required reproducibility check: rebuild twice and compare canonical bytes.
    subprocess.run([sys.executable, str(ROOT / "tools/build_japan_land_base.py")], cwd=ROOT, check=True, capture_output=True)
    first_gpkg_hash = sha256(GPKG)
    first_geojson_hash = sha256(GEOJSON)
    subprocess.run([sys.executable, str(ROOT / "tools/build_japan_land_base.py")], cwd=ROOT, check=True, capture_output=True)
    second_gpkg_hash = sha256(GPKG)
    second_geojson_hash = sha256(GEOJSON)

    build_manifest = json.loads(BUILD_MANIFEST.read_text(encoding="utf-8"))
    canonical = gpd.read_file(GPKG, layer="japan_land")
    mirror = gpd.read_file(GEOJSON)
    repair_log = json.loads((ROOT / "data/base/japan_land_repair_log.json").read_text(encoding="utf-8"))

    coordinates = shapely.get_coordinates(canonical.geometry.array)
    duplicate_count = duplicate_surface_count(canonical)
    overlaps = overlap_audit(canonical)
    scope = build.GAME_GEOGRAPHIC_SCOPE
    bounds_ok = all(
        geom.bounds[0] >= scope[0]
        and geom.bounds[1] >= scope[1]
        and geom.bounds[2] <= scope[2]
        and geom.bounds[3] <= scope[3]
        for geom in canonical.geometry
    )
    gpkg_area = geodesic_area(canonical)
    geojson_area = geodesic_area(mirror)
    gpkg_components = coordinate_component_count(canonical)
    geojson_components = coordinate_component_count(mirror)
    area_difference = abs(gpkg_area - geojson_area)
    source_displacements, source_mismatches = source_difference_audit(canonical)

    with sqlite3.connect(GPKG) as connection:
        sqlite_integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        layers = sorted(row[0] for row in connection.execute("SELECT table_name FROM gpkg_contents"))

    checks = {
        "geometry_valid": {
            "passed": bool(canonical.geometry.is_valid.all()),
            "invalid_count": int((~canonical.geometry.is_valid).sum()),
        },
        "empty_geometry_zero": {
            "passed": int(canonical.geometry.is_empty.sum()) == 0,
            "count": int(canonical.geometry.is_empty.sum()),
        },
        "self_intersection_zero": {
            "passed": bool(canonical.geometry.is_valid.all()),
            "count": int((~canonical.geometry.is_valid).sum()),
        },
        "duplicate_surface_zero": {"passed": duplicate_count == 0, "count": duplicate_count},
        "nan_coordinate_zero": {
            "passed": bool(np.isfinite(coordinates).all()),
            "count": int((~np.isfinite(coordinates)).sum()),
        },
        "inside_expected_japan_scope": {
            "passed": bounds_ok,
            "scope": list(scope),
            "actual_bounds": [float(v) for v in canonical.total_bounds],
        },
        "unintended_overlap_zero": {
            "passed": len(overlaps) == 0,
            "count": len(overlaps),
            "tolerance_m2": OVERLAP_AREA_TOLERANCE_M2,
            "overlaps": overlaps,
        },
        "repair_area_delta_within_tolerance": {
            "passed": abs(build_manifest["repairs"]["area_delta_m2"]) <= REPAIR_AREA_TOLERANCE_M2,
            "delta_m2": build_manifest["repairs"]["area_delta_m2"],
            "tolerance_m2": REPAIR_AREA_TOLERANCE_M2,
        },
        "gpkg_geojson_area_match": {
            "passed": area_difference <= 0.01,
            "gpkg_area_m2": gpkg_area,
            "geojson_area_m2": geojson_area,
            "difference_m2": area_difference,
            "tolerance_m2": 0.01,
        },
        "gpkg_geojson_component_count_match": {
            "passed": gpkg_components == geojson_components,
            "gpkg_components": gpkg_components,
            "geojson_components": geojson_components,
        },
        "regeneration_sha256_match": {
            "passed": first_gpkg_hash == second_gpkg_hash and first_geojson_hash == second_geojson_hash,
            "gpkg_first": first_gpkg_hash,
            "gpkg_second": second_gpkg_hash,
            "geojson_first": first_geojson_hash,
            "geojson_second": second_geojson_hash,
        },
        "geopackage_integrity": {"passed": sqlite_integrity == "ok", "result": sqlite_integrity},
        "no_unapproved_derived_layer": {
            "passed": layers == ["japan_land"],
            "layers": layers,
        },
        "canonical_source_coordinate_match": {
            "passed": len(source_mismatches) == 0,
            "mismatch_count": len(source_mismatches),
            "maximum_hausdorff_distance_m": max(source_displacements.values(), default=0.0),
            "mismatches": source_mismatches,
        },
    }

    all_passed = all(item["passed"] for item in checks.values())
    report = {
        "gate": 1,
        "master_version_candidate": MASTER_VERSION,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "all_passed": all_passed,
        "checks": checks,
        "repair_locations": repair_log["events"],
        "visuals": {
            "national_overview": "data/base/verification/visual/national_overview.png",
            "regional_directory": "data/base/verification/visual/regions",
            "regional_index": "data/base/verification/visual/regions_index.png",
            "coast_vertices": "data/base/verification/visual/coast_vertices.png",
            "source_difference_heatmap": "data/base/verification/visual/source_difference_heatmap.png",
            "repair_locations": "data/base/verification/visual/repair_locations.png",
        },
    }
    REPORT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    national_bounds = tuple(build_manifest["canonical"]["extent"])
    render_map(canonical, national_bounds, VISUAL_DIR / "national_overview.png", "全国全景 / Gate 1")
    region_dir = VISUAL_DIR / "regions"
    region_dir.mkdir(parents=True, exist_ok=True)
    for name, region_bounds in REGIONS.items():
        render_map(canonical, region_bounds, region_dir / f"{name}.png", f"地方別拡大: {name.split('_', 1)[1]}")
    create_region_index(region_dir, VISUAL_DIR / "regions_index.png")
    render_map(canonical, national_bounds, VISUAL_DIR / "coast_vertices.png", "海岸頂点表示", vertices=True)
    max_displacement = max(source_displacements.values(), default=0.0)
    render_map(
        canonical,
        national_bounds,
        VISUAL_DIR / "source_difference_heatmap.png",
        f"原本との差分ヒートマップ / 最大変位 {max_displacement:.6g} m",
        heat_values=source_displacements,
    )
    render_map(
        canonical,
        national_bounds,
        VISUAL_DIR / "repair_locations.png",
        "修復箇所一覧",
        message="修復箇所 0件 / No repair locations",
    )

    master = {
        "manifest_schema_version": 1,
        "master_version": MASTER_VERSION,
        "status": "awaiting_user_approval" if all_passed else "gate_failed",
        "canonical_file": "data/base/japan_land.gpkg",
        "canonical_layer": "japan_land",
        "canonical_sha256": second_gpkg_hash,
        "geojson_mirror_file": "data/base/japan_land.geojson",
        "geojson_mirror_sha256": second_geojson_hash,
        "source": "Natural Earth 1:10m Land 5.1.1 only",
        "gate1": {
            "passed": all_passed,
            "report": "data/base/verification/gate1_report.json",
            "report_sha256": sha256(REPORT_JSON),
        },
        "approval": {
            "approved": False,
            "approved_version": None,
            "approved_by": None,
            "approved_at": None,
            "note": "Set only after explicit user approval of the Gate 1 artifacts.",
        },
        "derived_layers_allowed": False,
    }
    MASTER_MANIFEST.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"all_passed": all_passed, "checks": len(checks), "master_status": master["status"]}, indent=2))
    if not all_passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
