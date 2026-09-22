"""Render Phase E map images from shared LOD polygons and coastline vectors."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pyogrio
from PIL import Image, ImageDraw
from shapely.geometry import box

import build_japan_land_base as base
import build_phase_d_lod as lod


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/map/generated"
DATA_DIR = ROOT / "data/derived/map_images"
MANIFEST = DATA_DIR / "map_images_manifest.json"
WATER_REGISTRY = DATA_DIR / "water_registry.json"
TILE_SIZE = 2048
SUPERSAMPLE = 2
BLEED_PX = 4
OCEAN_ID = "jp-ocean-001"
LAND_COLOR = (239, 239, 233, 255)
OCEAN_COLOR = (29, 57, 72, 255)
COAST_COLOR = (10, 20, 25, 255)
COAST_WIDTH_PX = 1.5
EMPTY_LAYERS = ["terrain", "vegetation", "soil", "snow"]

# All five LODs are rendered. They form three image families: national,
# regional (two zoom steps), and local (two zoom steps).
RENDER_PROFILES = [
    {"lod": 0, "family": "national", "grid": 1},
    {"lod": 1, "family": "regional", "grid": 2},
    {"lod": 2, "family": "regional", "grid": 2},
    {"lod": 3, "family": "local", "grid": 4},
    {"lod": 4, "family": "local", "grid": 4},
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def tile_transform(point, viewport, canvas_size, bleed):
    min_x, min_y, max_x, max_y = viewport
    x, y = point
    px = bleed + (x - min_x) / (max_x - min_x) * TILE_SIZE
    py = bleed + (y - min_y) / (max_y - min_y) * TILE_SIZE
    return px * SUPERSAMPLE, py * SUPERSAMPLE


def downsample_and_crop(image):
    expanded = TILE_SIZE + BLEED_PX * 2
    reduced = image.resize((expanded, expanded), Image.Resampling.LANCZOS)
    return reduced.crop((BLEED_PX, BLEED_PX, BLEED_PX + TILE_SIZE, BLEED_PX + TILE_SIZE))


def render_land_coverage(land, viewport):
    expanded = TILE_SIZE + BLEED_PX * 2
    image = Image.new("L", (expanded * SUPERSAMPLE, expanded * SUPERSAMPLE), 0)
    draw = ImageDraw.Draw(image)
    for feature in land.itertuples(index=False):
        if not feature.visible:
            continue
        for polygon in feature.geometry.geoms:
            exterior = [tile_transform(point, viewport, expanded, BLEED_PX) for point in polygon.exterior.coords]
            draw.polygon(exterior, fill=255)
            for ring in polygon.interiors:
                hole = [tile_transform(point, viewport, expanded, BLEED_PX) for point in ring.coords]
                draw.polygon(hole, fill=0)
    return downsample_and_crop(image)


def render_coastline(coastline, viewport):
    expanded = TILE_SIZE + BLEED_PX * 2
    image = Image.new("RGBA", (expanded * SUPERSAMPLE, expanded * SUPERSAMPLE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width = max(1, round(COAST_WIDTH_PX * SUPERSAMPLE))
    for feature in coastline.itertuples(index=False):
        if not feature.visible:
            continue
        point_list = [tile_transform(point, viewport, expanded, BLEED_PX) for point in feature.geometry.coords]
        draw.line(point_list, fill=COAST_COLOR, width=width, joint="curve")
    return downsample_and_crop(image)


def clipped_empty_layer(coverage):
    # No external terrain dataset has been approved. Keep transparent schema
    # layers and still apply the authoritative vector-derived land coverage.
    layer = Image.new("RGBA", coverage.size, (0, 0, 0, 0))
    alpha = Image.new("L", coverage.size, 0)
    alpha = Image.composite(alpha, Image.new("L", coverage.size, 0), coverage)
    layer.putalpha(alpha)
    return layer


def save_png(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    master = json.loads(lod.phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
    phase_d = json.loads(lod.LOD_MANIFEST.read_text(encoding="utf-8"))
    if sha256(lod.phase_c.MASTER_GPKG) != master["canonical_sha256"]:
        raise SystemExit("Approved land master hash mismatch.")
    if sha256(lod.LOD_GPKG) != phase_d["outputs"]["geopackage"]["sha256"]:
        raise SystemExit("Phase D LOD GeoPackage hash mismatch.")

    water_registry = {
        "schema_version": 1,
        "ocean": {"water_id": OCEAN_ID, "class": "ocean", "name": "日本周辺海域"},
        "lakes": [],
        "id_policy": "Ocean and lakes use separate IDs; source inner rings become jp-lake-* entries.",
        "source_inner_ring_count": 0,
    }
    WATER_REGISTRY.write_text(json.dumps(water_registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    tile_records = []
    for profile in RENDER_PROFILES:
        level = profile["lod"]
        grid = profile["grid"]
        land = pyogrio.read_dataframe(lod.LOD_GPKG, layer=f"land_lod{level}")
        coast = pyogrio.read_dataframe(lod.LOD_GPKG, layer=f"coastline_lod{level}")
        span = base.GAME_SIZE / grid
        for row in range(grid):
            for column in range(grid):
                viewport = [column * span, row * span, (column + 1) * span, (row + 1) * span]
                tile_bounds = box(*viewport)
                coastline_ids = sorted(
                    coast.loc[coast.visible & coast.geometry.intersects(tile_bounds), "coastline_id"].tolist()
                )
                relative_dir = Path(f"lod{level}_{profile['family']}") / f"r{row:02d}_c{column:02d}"
                tile_dir = ASSET_DIR / relative_dir
                coverage = render_land_coverage(land, viewport)
                coastline = render_coastline(coast, viewport)
                land_fill = Image.new("RGBA", coverage.size, LAND_COLOR)
                land_fill.putalpha(coverage)
                water = Image.new("RGBA", coverage.size, OCEAN_COLOR)
                layers = {}
                for layer_name in EMPTY_LAYERS:
                    layer = clipped_empty_layer(coverage)
                    layer_path = tile_dir / f"{layer_name}.png"
                    save_png(layer, layer_path)
                    layers[layer_name] = layer_path

                composite = water.copy()
                composite = Image.alpha_composite(composite, land_fill)
                for layer_name in EMPTY_LAYERS:
                    composite = Image.alpha_composite(composite, Image.open(layers[layer_name]).convert("RGBA"))
                # The dedicated vector-derived coastline is always the final layer.
                composite = Image.alpha_composite(composite, coastline)

                output_paths = {
                    "land_coverage": tile_dir / "land_coverage.png",
                    "land_fill": tile_dir / "land_fill.png",
                    "water": tile_dir / "water.png",
                    "coastline": tile_dir / "coastline.png",
                    "composite": tile_dir / "composite.png",
                    **layers,
                }
                save_png(coverage, output_paths["land_coverage"])
                save_png(land_fill, output_paths["land_fill"])
                save_png(water, output_paths["water"])
                save_png(coastline, output_paths["coastline"])
                save_png(composite, output_paths["composite"])

                tile_records.append(
                    {
                        "tile_id": f"lod{level}-r{row:02d}-c{column:02d}",
                        "lod": level,
                        "family": profile["family"],
                        "row": row,
                        "column": column,
                        "global_viewport": viewport,
                        "output_size": [TILE_SIZE, TILE_SIZE],
                        "ocean_id": OCEAN_ID,
                        "lake_ids": [],
                        "coastline_vector": {
                            "geopackage": lod.LOD_GPKG.relative_to(ROOT).as_posix(),
                            "layer": f"coastline_lod{level}",
                            "coastline_ids": coastline_ids,
                            "draw_order": "above_all_textures",
                        },
                        "files": {
                            key: path.relative_to(ROOT).as_posix() for key, path in output_paths.items()
                        },
                        "sha256": {key: sha256(path) for key, path in output_paths.items()},
                    }
                )

    manifest = {
        "schema_version": 1,
        "phase": "E",
        "status": "generated",
        "generation_record": "deterministic_from_phase_d",
        "source_master_version": master["master_version"],
        "source_master_sha256": master["canonical_sha256"],
        "source_lod_sha256": phase_d["outputs"]["geopackage"]["sha256"],
        "global_coordinate_space": [0, 0, base.GAME_SIZE, base.GAME_SIZE],
        "tile_size": TILE_SIZE,
        "coverage_antialiasing": {"method": "2x supersampled coverage", "bleed_px": BLEED_PX, "filter": "LANCZOS"},
        "render_order": ["water", "land_fill", *EMPTY_LAYERS, "coastline"],
        "terrain_layers": {
            name: {"status": "empty_awaiting_approved_source", "clipped_to": "land_coverage"}
            for name in EMPTY_LAYERS
        },
        "rules": {
            "land_sea_source": "LOD polygon rasterization only; no color threshold inference",
            "geometry_moving_filters": False,
            "global_tile_coordinates": True,
            "coastline_above_textures": True,
            "coastline_vector_source": "matching coastline_lod* layer",
        },
        "water_registry": {
            "file": WATER_REGISTRY.relative_to(ROOT).as_posix(),
            "sha256": sha256(WATER_REGISTRY),
        },
        "profiles": RENDER_PROFILES,
        "tile_count": len(tile_records),
        "tiles": tile_records,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"tiles": len(tile_records), "profiles": len(RENDER_PROFILES)}, indent=2))


if __name__ == "__main__":
    main()
