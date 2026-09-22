"""Build the approved Japan canonical land polygon for Phase B.

Approved source: Natural Earth 1:10m Land 5.1.1 only.
No visual smoothing or simplification is performed on canonical geometry.
"""

from __future__ import annotations

import hashlib
import json
import platform
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import geopandas as gpd
import pandas as pd
import pyogrio
import pyproj
import shapely
from PIL import Image, ImageDraw, ImageFont
from pyproj import CRS, Geod, Transformer
from shapely import make_valid
from shapely.geometry import MultiPolygon, Polygon, box
from shapely.ops import transform, unary_union


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/sources/candidates/natural_earth_10m/extracted/ne_10m_land.shp"
SOURCE_ARCHIVE = ROOT / "data/sources/candidates/natural_earth_10m/raw/ne_10m_land.zip"
OUT_DIR = ROOT / "data/base"
OUT_GPKG = OUT_DIR / "japan_land.gpkg"
OUT_GEOJSON = OUT_DIR / "japan_land.geojson"
OUT_MANIFEST = OUT_DIR / "japan_land_manifest.json"
OUT_REPAIR_LOG = OUT_DIR / "japan_land_repair_log.json"
OUT_PREVIEW = OUT_DIR / "japan_land_preview.png"

SOURCE_VERSION = "5.1.1"
SOURCE_CRS = "EPSG:4326"
LAYER_CANONICAL = "japan_land"
LAYER_HOLES = "japan_land_holes"
MIN_ISLAND_AREA_KM2 = 2.0
GAME_SIZE = 8192
GAME_PADDING = 128
GPKG_FIXED_LAST_CHANGE = "2026-01-01T00:00:00.000Z"
NAMESPACE = uuid.UUID("d7ba25fd-6457-51ce-b216-961a811fe426")

# Natural Earth Land is physical data without country ownership. These fixed
# representative-point corridors select the Sengoku game area while excluding
# Nansei, Ogasawara, nearby continental/coastal land and the Kuril chain.
SELECTION_CORRIDORS = [
    ("hokkaido", (139.0, 41.0, 145.0, 46.0)),
    ("eastern_japan", (134.0, 32.5, 142.5, 42.5)),
    ("shikoku_and_setouchi", (131.5, 32.5, 135.5, 34.8)),
    ("western_japan", (129.1, 33.7, 136.0, 36.8)),
    ("kyushu_and_western_islands", (128.2, 30.5, 132.2, 33.7)),
    ("izu_islands", (138.5, 30.5, 141.0, 35.5)),
]
GAME_GEOGRAPHIC_SCOPE = (128.0, 30.0, 146.0, 46.0)
AREA_CRS = "+proj=aea +lat_1=30 +lat_2=46 +lat_0=38 +lon_0=137 +datum=WGS84 +units=m +no_defs"
GAME_PROJECTION = "+proj=lcc +lat_1=30 +lat_2=46 +lat_0=38 +lon_0=137 +datum=WGS84 +units=m +no_defs"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def vertex_count(geom) -> int:
    count = 0
    for polygon in geom.geoms if geom.geom_type == "MultiPolygon" else [geom]:
        count += len(polygon.exterior.coords)
        count += sum(len(ring.coords) for ring in polygon.interiors)
    return count


def inner_ring_count(geom) -> int:
    return sum(
        len(polygon.interiors)
        for polygon in (geom.geoms if geom.geom_type == "MultiPolygon" else [geom])
    )


def consecutive_duplicate_count(geom) -> int:
    result = 0
    for polygon in geom.geoms if geom.geom_type == "MultiPolygon" else [geom]:
        for ring in [polygon.exterior, *polygon.interiors]:
            coords = list(ring.coords)
            result += sum(coords[i] == coords[i - 1] for i in range(1, len(coords)))
    return result


def polygonal_only(geom):
    if geom.geom_type in ("Polygon", "MultiPolygon"):
        return geom
    polygons = []
    if hasattr(geom, "geoms"):
        for part in geom.geoms:
            if part.geom_type == "Polygon":
                polygons.append(part)
            elif part.geom_type == "MultiPolygon":
                polygons.extend(part.geoms)
    return MultiPolygon(polygons)


def as_multipolygon(geom) -> MultiPolygon:
    if geom.geom_type == "Polygon":
        return MultiPolygon([geom])
    if geom.geom_type == "MultiPolygon":
        return geom
    return polygonal_only(geom)


def projected_scope_bounds() -> tuple[float, float, float, float]:
    min_lon, min_lat, max_lon, max_lat = GAME_GEOGRAPHIC_SCOPE
    perimeter = []
    for i in range(101):
        t = i / 100
        perimeter.extend(
            [
                (min_lon + (max_lon - min_lon) * t, min_lat),
                (min_lon + (max_lon - min_lon) * t, max_lat),
                (min_lon, min_lat + (max_lat - min_lat) * t),
                (max_lon, min_lat + (max_lat - min_lat) * t),
            ]
        )
    transformer = Transformer.from_crs(SOURCE_CRS, GAME_PROJECTION, always_xy=True)
    points = [transformer.transform(x, y) for x, y in perimeter]
    return (
        min(p[0] for p in points),
        min(p[1] for p in points),
        max(p[0] for p in points),
        max(p[1] for p in points),
    )


def game_transform_definition():
    projected_bounds = projected_scope_bounds()
    min_x, min_y, max_x, max_y = projected_bounds
    usable = GAME_SIZE - GAME_PADDING * 2
    scale = min(usable / (max_x - min_x), usable / (max_y - min_y))
    content_w = (max_x - min_x) * scale
    content_h = (max_y - min_y) * scale
    offset_x = GAME_PADDING + (usable - content_w) / 2
    offset_y = GAME_PADDING + (usable - content_h) / 2
    return projected_bounds, scale, offset_x, offset_y, content_h


def to_game_geometry(geom, projected_bounds, scale, offset_x, offset_y, content_h):
    project = Transformer.from_crs(SOURCE_CRS, GAME_PROJECTION, always_xy=True)
    min_x, min_y, _, _ = projected_bounds

    def map_point(x, y, z=None):
        px, py = project.transform(x, y)
        gx = offset_x + (px - min_x) * scale
        gy = offset_y + content_h - (py - min_y) * scale
        return (gx, gy) if z is None else (gx, gy, z)

    return transform(map_point, geom)


def from_game_geometry(geom, projected_bounds, scale, offset_x, offset_y, content_h):
    """Invert the deterministic 8192 transform back to the source CRS."""
    inverse = Transformer.from_crs(GAME_PROJECTION, SOURCE_CRS, always_xy=True)
    min_x, min_y, _, _ = projected_bounds

    def map_point(x, y, z=None):
        px = min_x + (x - offset_x) / scale
        py = min_y + (content_h - (y - offset_y)) / scale
        longitude, latitude = inverse.transform(px, py)
        return (longitude, latitude) if z is None else (longitude, latitude, z)

    return transform(map_point, geom)


def render_preview(game_gdf: gpd.GeoDataFrame):
    size = 1400
    canvas = Image.new("RGB", (size, size), (28, 55, 70))
    draw = ImageDraw.Draw(canvas)

    def px(point):
        return point[0] / GAME_SIZE * size, point[1] / GAME_SIZE * size

    for geom in game_gdf.geometry:
        for polygon in geom.geoms:
            draw.polygon([px(p) for p in polygon.exterior.coords], fill=(238, 239, 232))
            for ring in polygon.interiors:
                draw.polygon([px(p) for p in ring.coords], fill=(28, 55, 70))
    candidates = [Path("C:/Windows/Fonts/meiryo.ttc"), Path("C:/Windows/Fonts/segoeui.ttf")]
    font_path = next((p for p in candidates if p.exists()), None)
    title_font = ImageFont.truetype(str(font_path), 28) if font_path else ImageFont.load_default()
    draw.text((24, 20), "Canonical Japan Land / game 8192 preview", fill=(238, 239, 232), font=title_font)
    canvas.save(OUT_PREVIEW, optimize=True)


def normalize_geopackage_container(path: Path):
    """Remove container timestamps so identical inputs produce identical bytes."""
    with sqlite3.connect(path) as connection:
        connection.execute("UPDATE gpkg_contents SET last_change = ?", (GPKG_FIXED_LAST_CHANGE,))
        connection.commit()
        connection.execute("VACUUM")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source = gpd.read_file(SOURCE)
    source = source.explode(index_parts=True)
    source.index.names = ["source_feature", "source_part"]
    source = source.reset_index()
    source["representative_point"] = source.geometry.representative_point()

    selection_mask = unary_union([box(*bounds) for _, bounds in SELECTION_CORRIDORS])
    source["in_game_corridor"] = source["representative_point"].apply(selection_mask.covers)
    candidate = source[source.in_game_corridor].copy()
    projected_for_area = candidate.set_geometry("geometry").to_crs(AREA_CRS)
    candidate["area_km2_filter"] = projected_for_area.area.values / 1_000_000
    below_threshold = candidate[candidate.area_km2_filter < MIN_ISLAND_AREA_KM2].copy()
    selected = candidate[candidate.area_km2_filter >= MIN_ISLAND_AREA_KM2].copy()

    repair_events = []
    output_records = []
    for row in selected.itertuples(index=False):
        original = row.geometry
        before_area = abs(Geod(ellps="WGS84").geometry_area_perimeter(original)[0])
        before_vertices = vertex_count(original)
        duplicates = consecutive_duplicate_count(original)
        repaired = original
        reasons = []
        if not repaired.is_valid:
            repaired = polygonal_only(make_valid(repaired))
            reasons.append("self_intersection_or_invalid_geometry")
        if duplicates:
            # remove_repeated_points does not alter non-repeated coordinates
            repaired = shapely.remove_repeated_points(repaired, tolerance=0.0)
            reasons.append("consecutive_duplicate_vertices")
        repaired = as_multipolygon(repaired)
        after_area = abs(Geod(ellps="WGS84").geometry_area_perimeter(repaired)[0])
        after_vertices = vertex_count(repaired)
        source_id = f"ne_10m_land:{row.source_feature}:{row.source_part}"
        feature_id = f"jp-land-{uuid.uuid5(NAMESPACE, SOURCE_VERSION + ':' + source_id).hex[:16]}"
        part_class = "mainland" if row.area_km2_filter > 200_000 else "island"
        status = "repaired" if reasons else "unchanged"
        note = "; ".join(reasons) if reasons else "source coordinates unchanged"
        output_records.append(
            {
                "feature_id": feature_id,
                "part_class": part_class,
                "source_id": source_id,
                "source_version": SOURCE_VERSION,
                "edit_status": status,
                "edit_note": note,
                "geometry": repaired,
            }
        )
        if reasons:
            repair_events.append(
                {
                    "feature_id": feature_id,
                    "source_id": source_id,
                    "reasons": reasons,
                    "area_before_m2": before_area,
                    "area_after_m2": after_area,
                    "area_delta_m2": after_area - before_area,
                    "vertices_before": before_vertices,
                    "vertices_after": after_vertices,
                    "vertex_delta": after_vertices - before_vertices,
                }
            )

    canonical = gpd.GeoDataFrame(output_records, geometry="geometry", crs=SOURCE_CRS)
    canonical = canonical.sort_values(["part_class", "feature_id"]).reset_index(drop=True)

    # Persist every source inner ring as a deterministic lake-linked record.
    hole_records = []
    for feature in canonical.itertuples(index=False):
        ring_index = 0
        for polygon in feature.geometry.geoms:
            for ring in polygon.interiors:
                hole_id = f"jp-hole-{uuid.uuid5(NAMESPACE, feature.feature_id + ':' + str(ring_index)).hex[:16]}"
                hole_records.append(
                    {
                        "hole_id": hole_id,
                        "parent_feature_id": feature.feature_id,
                        "lake_id": hole_id.replace("jp-hole-", "jp-lake-"),
                        "source_id": feature.source_id,
                        "hole_role": "source_inner_ring_lake",
                        "geometry": Polygon(ring),
                    }
                )
                ring_index += 1
    if hole_records:
        holes = gpd.GeoDataFrame(hole_records, geometry="geometry", crs=SOURCE_CRS)
    else:
        holes = gpd.GeoDataFrame(
            columns=["hole_id", "parent_feature_id", "lake_id", "source_id", "hole_role"],
            geometry=gpd.GeoSeries([], crs=SOURCE_CRS),
            crs=SOURCE_CRS,
        )

    bounds, scale, offset_x, offset_y, content_h = game_transform_definition()
    game = canonical.copy()
    game.geometry = game.geometry.apply(
        lambda geom: as_multipolygon(to_game_geometry(geom, bounds, scale, offset_x, offset_y, content_h))
    )
    game = game.set_crs(None, allow_override=True)

    if OUT_GPKG.exists():
        OUT_GPKG.unlink()
    canonical.to_file(OUT_GPKG, layer=LAYER_CANONICAL, driver="GPKG", engine="pyogrio")
    if not holes.empty:
        holes.to_file(OUT_GPKG, layer=LAYER_HOLES, driver="GPKG", engine="pyogrio", append=True)
    normalize_geopackage_container(OUT_GPKG)

    if OUT_GEOJSON.exists():
        OUT_GEOJSON.unlink()
    canonical.to_file(
        OUT_GEOJSON,
        driver="GeoJSON",
        engine="pyogrio",
        layer_options={"RFC7946": "YES", "COORDINATE_PRECISION": "15"},
    )

    render_preview(game)

    geod = Geod(ellps="WGS84")
    total_area_m2 = sum(abs(geod.geometry_area_perimeter(geom)[0]) for geom in canonical.geometry)
    manifest = {
        "schema_version": 1,
        "status": "canonical",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "approval": {
            "approved_source": "Natural Earth 1:10m Land 5.1.1 only",
            "approved_by": "user",
            "approval_context": "Nansei Islands are outside the Sengoku game unit scope",
        },
        "canonical": {
            "file": OUT_GPKG.relative_to(ROOT).as_posix(),
            "sha256": None,
            "layer": LAYER_CANONICAL,
            "geometry_type": "MultiPolygon",
            "crs": canonical.crs.to_string(),
            "crs_wkt": canonical.crs.to_wkt(),
            "extent": [float(v) for v in canonical.total_bounds],
            "geodesic_area_m2": total_area_m2,
            "feature_count": len(canonical),
            "mainland_count": int((canonical.part_class == "mainland").sum()),
            "island_count": int((canonical.part_class == "island").sum()),
            "inner_ring_count": sum(inner_ring_count(g) for g in canonical.geometry),
            "vertex_count": sum(vertex_count(g) for g in canonical.geometry),
        },
        "geojson_mirror": {
            "file": OUT_GEOJSON.relative_to(ROOT).as_posix(),
            "sha256": sha256(OUT_GEOJSON),
            "crs": "RFC 7946 WGS 84 longitude/latitude",
            "feature_count": len(canonical),
        },
        "source": {
            "name": "Natural Earth 1:10m Land",
            "version": SOURCE_VERSION,
            "archive": SOURCE_ARCHIVE.relative_to(ROOT).as_posix(),
            "archive_sha256": sha256(SOURCE_ARCHIVE),
            "crs": SOURCE_CRS,
            "license": "public domain",
        },
        "selection": {
            "game_geographic_scope": GAME_GEOGRAPHIC_SCOPE,
            "corridors": [{"name": name, "bounds": bounds_} for name, bounds_ in SELECTION_CORRIDORS],
            "min_island_area_km2": MIN_ISLAND_AREA_KM2,
            "selected_feature_count": len(canonical),
            "excluded_below_area_threshold_count": len(below_threshold),
            "nansen_ogasawara_excluded_by_scope": True,
        },
        "repairs": {
            "allowed_only": [
                "self-intersection repair",
                "duplicate vertex and zero-length edge removal",
                "duplicate polygon merge",
                "obvious ring orientation normalization",
            ],
            "visual_smoothing": False,
            "simplification": False,
            "event_count": len(repair_events),
            "area_delta_m2": sum(e["area_delta_m2"] for e in repair_events),
            "vertex_delta": sum(e["vertex_delta"] for e in repair_events),
        },
        "game_transform": {
            "layer": None,
            "materialized": False,
            "materialization_gate": "Gate 1 user approval",
            "coordinate_space": [0, 0, GAME_SIZE, GAME_SIZE],
            "north_up": True,
            "y_axis": "down",
            "projection": GAME_PROJECTION,
            "fixed_geographic_scope": GAME_GEOGRAPHIC_SCOPE,
            "projected_scope_bounds_m": bounds,
            "uniform_scale_px_per_m": scale,
            "offset_x_px": offset_x,
            "offset_y_px": offset_y,
            "content_height_px": content_h,
            "padding_px": GAME_PADDING,
            "deterministic_formula": "WGS84 -> stated LCC; x=offset_x+(X-minX)*scale; y=offset_y+content_height-(Y-minY)*scale",
        },
        "holes": {
            "layer": LAYER_HOLES if not holes.empty else None,
            "count": len(holes),
            "policy": "Each source inner ring is preserved and linked to a deterministic lake_id.",
        },
        "tools": {
            "python": platform.python_version(),
            "geopandas": gpd.__version__,
            "pandas": pd.__version__,
            "pyogrio": pyogrio.__version__,
            "shapely": shapely.__version__,
            "pyproj": pyproj.__version__,
            "platform": platform.platform(),
            "script": "tools/build_japan_land_base.py",
        },
    }

    # Hash only after all GeoPackage layers have been written.
    manifest["canonical"]["sha256"] = sha256(OUT_GPKG)
    OUT_MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    OUT_REPAIR_LOG.write_text(
        json.dumps(
            {
                "source_version": SOURCE_VERSION,
                "repair_event_count": len(repair_events),
                "events": repair_events,
                "note": "No entry means no permitted repair changed canonical coordinates.",
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(
        json.dumps(
            {
                "gpkg": str(OUT_GPKG),
                "geojson": str(OUT_GEOJSON),
                "features": len(canonical),
                "holes": len(holes),
                "repairs": len(repair_events),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
