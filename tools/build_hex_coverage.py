"""Render coverage: land-intersecting hexes plus five offshore neighbor rings.

Uses the same canonical coastline and coordinate transform as build_detail_map.
Political and district boundaries are deliberately not inputs.
"""
import json
import math
import re
from pathlib import Path

import numpy as np
import shapely
from pyproj import Transformer
from shapely.geometry import shape
from shapely.ops import transform, unary_union

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data/derived/detail_map/hex_coverage.json"
RINGS = 5
NEIGHBORS = ((0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1), (1, 0))


def main():
    source = (ROOT / "scripts/map/hex_grid.gd").read_text(encoding="utf-8")
    radius = float(re.search(r"const RADIUS := ([\d.]+)", source)[1])
    manifest = json.loads((ROOT / "data/base/japan_land_manifest.json").read_text())
    m = manifest["game_transform"]
    projection = Transformer.from_crs("EPSG:4326", m["projection"], always_xy=True)
    bx, by, _, _ = m["projected_scope_bounds_m"]

    def xy(lon, lat):
        x, y = projection.transform(lon, lat)
        scale = m["uniform_scale_px_per_m"]
        return (m["offset_x_px"] + (x-bx)*scale,
                m["offset_y_px"] + m["content_height_px"] - (y-by)*scale)

    features = json.loads((ROOT / "data/base/japan_land.geojson").read_text())["features"]
    land = unary_union([transform(xy, shape(f["geometry"])) for f in features])
    shapely.prepare(land)
    cells, centers = [], []
    for r in range(math.ceil(8192 / (radius*1.5))):
        for q in range(math.floor(-r*0.5), math.ceil(8192/(math.sqrt(3)*radius)-r*0.5)):
            x, y = math.sqrt(3)*radius*(q+r*0.5), radius*1.5*r
            if 0 <= x < 8192 and 0 <= y < 8192:
                cells.append((q, r))
                centers.append((x, y))
    angles = np.pi/6 + np.arange(6)*np.pi/3
    corners = np.column_stack((np.cos(angles), np.sin(angles))) * radius
    polygons = shapely.polygons(np.asarray(centers)[:, None, :] + corners)
    on_land = shapely.intersects(land, polygons)
    allowed = {cell for cell, hit in zip(cells, on_land) if hit}
    land_count = len(allowed)
    world = set(cells)
    frontier = allowed.copy()
    for _ in range(RINGS):
        frontier = {(q+dq, r+dr) for q, r in frontier for dq, dr in NEIGHBORS} & world - allowed
        allowed.update(frontier)
    rows = {}
    for q, r in sorted(allowed, key=lambda cell: (cell[1], cell[0])):
        rows.setdefault(str(r), []).append(q)
    payload = dict(radius=radius, offshore_rings=RINGS, land_cells=land_count,
                   visible_cells=len(allowed), rows=rows)
    OUTPUT.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Hex coverage: radius={radius}, land={land_count}, visible={len(allowed)}, offshore rings={RINGS}")


if __name__ == "__main__":
    main()
