"""Add exact water triangles around existing detailed land tiles.

The canonical land shape stays untouched. A one-cell overlap covers the coarse
resident backdrop at zoomed coastlines without moving any shore vertices.
"""

import hashlib
import json
from pathlib import Path

from pyproj import Transformer
from shapely import constrained_delaunay_triangles
from shapely.geometry import Polygon, box, shape
from shapely.ops import transform, unary_union


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data/derived/detail_map/manifest.json"
MASTER = ROOT / "data/base/japan_land.geojson"
TRANSFORM = ROOT / "data/base/japan_land_manifest.json"
STEP = 16


def parts(geometry):
    if geometry.is_empty:
        return []
    if geometry.geom_type == "Polygon":
        return [geometry]
    return [part for item in geometry.geoms for part in parts(item)]


def main() -> None:
    transform_data = json.loads(TRANSFORM.read_text(encoding="utf-8"))["game_transform"]
    projection = Transformer.from_crs("EPSG:4326", transform_data["projection"], always_xy=True)
    scale = transform_data["uniform_scale_px_per_m"]
    base_x, base_y = transform_data["projected_scope_bounds_m"][:2]

    def game_xy(lon, lat):
        px, py = projection.transform(lon, lat)
        return (
            transform_data["offset_x_px"] + (px - base_x) * scale,
            transform_data["offset_y_px"] + transform_data["content_height_px"] - (py - base_y) * scale,
        )

    features = json.loads(MASTER.read_text(encoding="utf-8"))["features"]
    land = unary_union([transform(game_xy, shape(feature["geometry"])) for feature in features])
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    for index, tile in enumerate(manifest["tiles"]):
        x0, y0, x1, y1 = map(int, tile["global_viewport"])
        bounds = box(max(0, x0 - STEP), max(0, y0 - STEP), min(8192, x1 + STEP), min(8192, y1 + STEP))
        water = bounds.difference(land)
        vertices = []
        indices = []
        lookup = {}

        def add_triangle(points):
            for point in points:
                key = tuple(round(float(value), 9) for value in point)
                if key not in lookup:
                    lookup[key] = len(vertices)
                    vertices.append(key)
                indices.append(lookup[key])

        start_x, start_y, end_x, end_y = map(int, bounds.bounds)
        for cy in range(start_y, end_y, STEP):
            for cx in range(start_x, end_x, STEP):
                for corners in (
                    [(cx, cy), (cx + STEP, cy), (cx, cy + STEP)],
                    [(cx + STEP, cy), (cx + STEP, cy + STEP), (cx, cy + STEP)],
                ):
                    triangle = Polygon(corners)
                    if water.covers(triangle):
                        add_triangle(corners)
                    elif water.intersects(triangle):
                        for polygon in parts(water.intersection(triangle)):
                            for piece in constrained_delaunay_triangles(polygon).geoms:
                                if piece.area > 1e-10:
                                    add_triangle(list(piece.exterior.coords)[:3])

        geometry_path = ROOT / tile["files"]["geometry"]
        geometry = json.loads(geometry_path.read_text(encoding="utf-8"))
        geometry["water_vertices"] = vertices
        geometry["water_indices"] = indices
        geometry_path.write_text(json.dumps(geometry, separators=(",", ":")), encoding="utf-8")
        tile["hashes"]["geometry"] = hashlib.sha256(geometry_path.read_bytes()).hexdigest()
        if index % 25 == 0:
            print(f"Water meshes {index + 1}/{len(manifest['tiles'])}", flush=True)

    manifest["water_mesh_gutter_world_units"] = STEP
    MANIFEST.write_text(json.dumps(manifest, separators=(",", ":"), ensure_ascii=False), encoding="utf-8")
    print(f"Added water geometry to {len(manifest['tiles'])} detail tiles")


if __name__ == "__main__":
    main()
