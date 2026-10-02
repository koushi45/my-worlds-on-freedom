"""Classify covered hexes from the measured DEM and the mapped water geometry.

The DEM has one sample per two world units. A high mountain contains at least
one measured sample of 2,500 m or more inside the hex, not merely a high center.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates
import shapely
from pyproj import Transformer
from shapely.geometry import LineString, Polygon, shape
from shapely.ops import transform, unary_union

ROOT = Path(__file__).resolve().parents[1]
COVERAGE = ROOT / "data/derived/detail_map/hex_coverage.json"
HEIGHT = ROOT / "assets/map/elevation/elevation_m.png"
WATER = ROOT / "data/derived/hydrography/water_registry.json"
LAND = ROOT / "data/base/japan_land.geojson"
LAND_MANIFEST = ROOT / "data/base/japan_land_manifest.json"
OUTPUT = ROOT / "data/derived/detail_map/hex_terrain.json"
RADIUS = 6.0
PIXEL_SPAN = 2.0
HIGH_MOUNTAIN_M = 2500
MOUNTAIN_M = 700
MOUNTAIN_SLOPE_DEGREES = 5.0
# 0: plain, 1: mountain, 2: river, 3: high mountain, 4: no land.


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def axial_at(x: np.ndarray, y: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    q = (math.sqrt(3) / 3 * x - y / 3) / RADIUS
    r = 2 * y / (3 * RADIUS)
    s = -q - r
    qi, ri, si = np.rint(q), np.rint(r), np.rint(s)
    dq, dr, ds = abs(qi - q), abs(ri - r), abs(si - s)
    q_big = (dq > dr) & (dq > ds)
    r_big = ~q_big & (dr > ds)
    qi = np.where(q_big, -ri - si, qi)
    ri = np.where(r_big, -qi - si, ri)
    return qi.astype(np.int32), ri.astype(np.int32)


def main() -> None:
    coverage = read(COVERAGE)
    assert coverage["radius"] == RADIUS
    cells = [(int(q), int(r)) for r, columns in coverage["rows"].items() for q in columns]
    indexes = {cell: i for i, cell in enumerate(cells)}
    axial = np.asarray(cells, dtype=np.int32)
    centers = np.column_stack((math.sqrt(3) * RADIUS * (axial[:, 0] + axial[:, 1] * .5),
                               RADIUS * 1.5 * axial[:, 1]))
    heights = np.asarray(Image.open(HEIGHT), dtype=np.float32)
    assert heights.shape == (4096, 4096)
    coordinates = np.vstack((centers[:, 1] / PIXEL_SPAN - .5,
                             centers[:, 0] / PIXEL_SPAN - .5))
    center_heights = map_coordinates(heights, coordinates, order=1, mode="nearest")
    # A 5 degree smoothed gradient is the same practical mountain criterion
    # already used when placing district offices.
    transform_spec = read(LAND_MANIFEST)["game_transform"]
    metres_per_pixel = PIXEL_SPAN / transform_spec["uniform_scale_px_per_m"]
    dy, dx = np.gradient(gaussian_filter(heights, .7), metres_per_pixel)
    slopes = np.degrees(np.arctan(np.hypot(dx, dy)))
    center_slopes = map_coordinates(slopes, coordinates, order=1, mode="nearest")
    classes = np.where((center_heights >= MOUNTAIN_M) |
                       ((center_heights > 0) & (center_slopes >= MOUNTAIN_SLOPE_DEGREES)),
                       1, 0).astype(np.uint8)

    angles = math.pi / 6 + np.arange(6) * math.pi / 3
    corners = RADIUS * np.column_stack((np.cos(angles), np.sin(angles)))
    hexes = shapely.polygons(centers[:, None, :] + corners)
    tree = shapely.STRtree(hexes)
    water = read(WATER)
    projection = Transformer.from_crs("EPSG:4326", transform_spec["projection"], always_xy=True)
    bx, by, _, _ = transform_spec["projected_scope_bounds_m"]

    def xy(lon, lat):
        x, y = projection.transform(lon, lat)
        scale = transform_spec["uniform_scale_px_per_m"]
        return (transform_spec["offset_x_px"] + (x - bx) * scale,
                transform_spec["offset_y_px"] + transform_spec["content_height_px"] - (y - by) * scale)

    land = unary_union([transform(xy, shape(row["geometry"])) for row in read(LAND)["features"]])
    lake_polygons = [Polygon(row["rings"][0], row["rings"][1:])
                     for row in water["lakes"] if row.get("source_type") != 1 and row["rings"]]
    dry_land = shapely.make_valid(land.difference(shapely.make_valid(unary_union(lake_polygons))))
    shapely.prepare(dry_land)
    # Interior centers need no expensive polygon clipping. Clip only coastal
    # and lake-edge cells whose centers fall outside dry land.
    on_land = shapely.contains(dry_land, shapely.points(centers))
    fringe = np.flatnonzero(~on_land)
    candidates = fringe[shapely.intersects(dry_land, hexes[fringe])]
    on_land[candidates] = shapely.area(shapely.intersection(dry_land, hexes[candidates])) > 1e-6

    # Match WaterLayer._draw_content: hidden source records do not make river tiles.
    rivers = [LineString(row["points"]) for row in water["rivers"]
              if row.get("visible_by_default", True) and len(row["points"]) >= 2]
    rivers += [Polygon(row["rings"][0], row["rings"][1:])
               for row in water["lakes"] if row.get("source_type") == 1
               and row.get("visible_by_default", True) and row["rings"]]
    for river in rivers:
        for index in tree.query(river, predicate="intersects"):
            if on_land[index]: classes[index] = 2

    # Map every >=2,500 m DEM sample to its containing hex. Sampling just the
    # center or corners would miss a narrow summit within an otherwise low tile.
    high_y, high_x = np.nonzero(heights >= HIGH_MOUNTAIN_M)
    high_q, high_r = axial_at((high_x + .5) * PIXEL_SPAN,
                              (high_y + .5) * PIXEL_SPAN)
    for q, r in set(zip(high_q.tolist(), high_r.tolist())):
        index = indexes.get((q, r))
        if index is not None and on_land[index]:
            classes[index] = 3

    classes[~on_land] = 4

    cursor = 0
    rows = {}
    for r, columns in coverage["rows"].items():
        rows[r] = "".join(str(code) for code in classes[cursor:cursor + len(columns)])
        cursor += len(columns)
    assert cursor == coverage["visible_cells"]
    counts = {name: int(np.count_nonzero(classes == code)) for code, name in
              enumerate(("plain", "mountain", "river", "high_mountain", "no_land"))}
    payload = {
        "schema_version": 1, "radius": RADIUS, "tile_count": len(cells),
        "codes": {"plain": 0, "mountain": 1, "river": 2, "high_mountain": 3, "no_land": 4},
        "mountain_minimum_m": MOUNTAIN_M,
        "mountain_slope_degrees": MOUNTAIN_SLOPE_DEGREES,
        "high_mountain_minimum_m": HIGH_MOUNTAIN_M,
        "sources_sha256": {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                           for path in (COVERAGE, HEIGHT, WATER, LAND, LAND_MANIFEST)},
        "counts": counts, "rows": rows,
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Classified {len(cells)} tiles: {counts}")


if __name__ == "__main__":
    main()
