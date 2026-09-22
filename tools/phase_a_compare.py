"""Create reproducible Phase-A coastline candidate comparison sheets.

This script does not create the canonical land polygon. It renders source data
directly, in a fixed JGD2011 plane rectangular CRS and physical extent for each
inspection area, so that candidates can be approved before Phase B begins.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import shapefile
from PIL import Image, ImageDraw, ImageFont
from pyproj import Transformer
from shapely.geometry import box, shape
from shapely.ops import transform


ROOT = Path(__file__).resolve().parents[1]
MLIT = ROOT / "data/sources/candidates/mlit_n03_2026/extracted/N03-20260101.shp"
NE = ROOT / "data/sources/candidates/natural_earth_10m/extracted/ne_10m_land.shp"
NE_MINOR = ROOT / "data/sources/candidates/natural_earth_10m/extracted/ne_10m_minor_islands.shp"
DEFAULT_OUT = ROOT / "data/phase_a/comparisons"

# name: center lon/lat, width/height in km, JGD2011 plane rectangular EPSG
AREAS = {
    "01_hokkaido": (142.15, 43.35, 720, 540, 6680),
    "02_tokyo_bay": (139.86, 35.46, 130, 115, 6677),
    "03_ise_bay": (136.79, 34.73, 155, 135, 6674),
    "04_osaka_bay": (135.20, 34.48, 150, 130, 6674),
    "05_seto_inland_sea": (133.55, 34.28, 520, 235, 6672),
    "06_western_kyushu": (129.80, 32.55, 390, 455, 6670),
    "07_nansei_islands": (127.10, 26.15, 930, 520, 6683),
}

PANEL_W, PANEL_H = 760, 590
MARGIN = 34
SEA = (31, 61, 78)
LAND_MLIT = (243, 186, 73)
LAND_NE = (113, 170, 214)
INK = (238, 242, 244)
COAST = (12, 20, 24)


def font(size: int):
    candidates = [
        Path("C:/Windows/Fonts/segoeui.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def iter_polygons(geom):
    if geom.is_empty:
        return
    if geom.geom_type == "Polygon":
        yield geom
    elif geom.geom_type in ("MultiPolygon", "GeometryCollection"):
        for item in geom.geoms:
            yield from iter_polygons(item)


def projected_window(lon, lat, width_km, height_km, epsg):
    fwd = Transformer.from_crs(6668, epsg, always_xy=True)
    inv = Transformer.from_crs(epsg, 6668, always_xy=True)
    cx, cy = fwd.transform(lon, lat)
    bounds = (
        cx - width_km * 500,
        cy - height_km * 500,
        cx + width_km * 500,
        cy + height_km * 500,
    )
    corners = [
        inv.transform(bounds[0], bounds[1]),
        inv.transform(bounds[0], bounds[3]),
        inv.transform(bounds[2], bounds[1]),
        inv.transform(bounds[2], bounds[3]),
    ]
    geo_bbox = (
        min(p[0] for p in corners),
        min(p[1] for p in corners),
        max(p[0] for p in corners),
        max(p[1] for p in corners),
    )
    return fwd, bounds, geo_bbox


def load_geometries(path: Path, bbox):
    reader = shapefile.Reader(str(path))
    for shp in reader.iterShapes(bbox=bbox):
        try:
            geom = shape(shp.__geo_interface__)
        except Exception:
            continue
        if not geom.is_empty:
            yield geom


def draw_candidate(paths, area, title, fill):
    if isinstance(paths, Path):
        paths = [paths]
    lon, lat, width_km, height_km, epsg = area
    fwd, bounds, geo_bbox = projected_window(lon, lat, width_km, height_km, epsg)
    clip = box(*bounds)
    geo_clip = box(*geo_bbox)
    canvas = Image.new("RGB", (PANEL_W, PANEL_H), SEA)
    draw = ImageDraw.Draw(canvas)
    map_rect = (MARGIN, 56, PANEL_W - MARGIN, PANEL_H - MARGIN)
    usable_w = map_rect[2] - map_rect[0]
    usable_h = map_rect[3] - map_rect[1]
    span_x = bounds[2] - bounds[0]
    span_y = bounds[3] - bounds[1]
    scale = min(usable_w / span_x, usable_h / span_y)
    actual_w, actual_h = span_x * scale, span_y * scale
    ox = map_rect[0] + (usable_w - actual_w) / 2
    oy = map_rect[1] + (usable_h - actual_h) / 2

    def px(point):
        x, y = point
        return (ox + (x - bounds[0]) * scale, oy + actual_h - (y - bounds[1]) * scale)

    for path in paths:
        for source_geom in load_geometries(path, geo_bbox):
            # Clip in geographic coordinates first. Projecting a global geometry
            # into a local Japan CRS can create invalid antimeridian artifacts.
            local_source = source_geom.intersection(geo_clip)
            if local_source.is_empty:
                continue
            projected = transform(fwd.transform, local_source)
            if not projected.intersects(clip):
                continue
            clipped = projected.intersection(clip)
            for polygon in iter_polygons(clipped):
                exterior = [px(p) for p in polygon.exterior.coords]
                if len(exterior) >= 3:
                    draw.polygon(exterior, fill=fill)
                for ring in polygon.interiors:
                    hole = [px(p) for p in ring.coords]
                    if len(hole) >= 3:
                        draw.polygon(hole, fill=SEA)

    draw.text((MARGIN, 16), title, font=font(25), fill=INK)
    draw.text((PANEL_W - MARGIN, 21), f"JGD2011 / CS {epsg - 6668} (EPSG:{epsg})", font=font(14), fill=INK, anchor="ra")
    bar_km = 100 if width_km >= 300 else 25
    bar_px = bar_km * 1000 * scale
    bx, by = MARGIN + 12, PANEL_H - MARGIN - 15
    draw.line((bx, by, bx + bar_px, by), fill=INK, width=4)
    draw.line((bx, by - 5, bx, by + 5), fill=INK, width=2)
    draw.line((bx + bar_px, by - 5, bx + bar_px, by + 5), fill=INK, width=2)
    draw.text((bx, by - 9), f"{bar_km} km", font=font(14), fill=INK, anchor="lb")
    return canvas


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--natural-earth-land-only",
        action="store_true",
        help="Compare MLIT N03 against Natural Earth Land without Minor Islands.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    if args.natural_earth_land_only:
        out = ROOT / "data/phase_a/comparisons_natural_earth_land_only"
        ne_paths = [NE]
        ne_title = "Natural Earth 1:10m Land only"
        variant = "Natural Earth Land 5.1.1 only; Minor Islands excluded"
    else:
        out = DEFAULT_OUT
        ne_paths = [NE, NE_MINOR]
        ne_title = "Natural Earth 1:10m + minor islands"
        variant = "Natural Earth Land 5.1.1 + Minor Islands 4.1.0"

    out.mkdir(parents=True, exist_ok=True)
    outputs = []
    for key, area in AREAS.items():
        left = draw_candidate(MLIT, area, "MLIT N03 (2026)", LAND_MLIT)
        right = draw_candidate(ne_paths, area, ne_title, LAND_NE)
        sheet = Image.new("RGB", (PANEL_W * 2, PANEL_H + 48), (18, 29, 35))
        sheet.paste(left, (0, 48))
        sheet.paste(right, (PANEL_W, 48))
        title = key.split("_", 1)[1].replace("_", " ").title()
        ImageDraw.Draw(sheet).text((PANEL_W, 24), title, font=font(28), fill=INK, anchor="mm")
        path = out / f"{key}.png"
        sheet.save(path, optimize=True)
        outputs.append(str(path.relative_to(ROOT)).replace("\\", "/"))

    manifest = {
        "purpose": "Phase A visual comparison only; not a canonical polygon",
        "natural_earth_variant": variant,
        "rules": "same projected CRS, physical extent, pixel dimensions and styling per area",
        "outputs": outputs,
        "areas": {
            k: {"center_lon_lat": v[:2], "width_km": v[2], "height_km": v[3], "epsg": v[4]}
            for k, v in AREAS.items()
        },
    }
    (out / "comparison_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # A compact index for review; full-resolution sheets remain authoritative.
    thumb_w = 760
    rows = []
    for path_text in outputs:
        with Image.open(ROOT / path_text) as source:
            thumb = source.copy()
            thumb.thumbnail((thumb_w, 340), Image.Resampling.LANCZOS)
            rows.append(thumb)
    index = Image.new("RGB", (thumb_w, sum(im.height for im in rows)), (18, 29, 35))
    y = 0
    for row in rows:
        index.paste(row, (0, y))
        y += row.height
    index.save(out / "00_all_areas_index.png", optimize=True)


if __name__ == "__main__":
    main()
