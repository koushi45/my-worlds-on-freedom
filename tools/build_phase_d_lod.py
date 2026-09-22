"""Build five deterministic LOD levels from the approved Japan land master."""

from __future__ import annotations

import hashlib
import json
import platform
import sqlite3
from pathlib import Path

import geopandas as gpd
import pyogrio
import shapely
from PIL import Image, ImageDraw
from shapely.geometry import LineString, MultiPolygon

import build_japan_land_base as base
import build_phase_c_coastline_mask as phase_c


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data/derived/lod"
PREVIEW_DIR = OUT_DIR / "preview"
LOD_GPKG = OUT_DIR / "japan_lod.gpkg"
LOD_JSON = OUT_DIR / "japan_lod.json"
LOD_MANIFEST = OUT_DIR / "lod_manifest.json"
FIXED_GPKG_TIMESTAMP = "2026-01-01T00:00:00.000Z"

# Tolerances are in the common 8192 game coordinate (pixels).  Visibility only
# affects rendering; every master feature remains present in every LOD layer.
LOD_DEFINITIONS = [
    {"level": 0, "name": "national", "simplify_tolerance_px": 4.0, "visible_min_area_km2": 100.0},
    {"level": 1, "name": "regional", "simplify_tolerance_px": 2.0, "visible_min_area_km2": 25.0},
    {"level": 2, "name": "subregional", "simplify_tolerance_px": 1.0, "visible_min_area_km2": 10.0},
    {"level": 3, "name": "local", "simplify_tolerance_px": 0.5, "visible_min_area_km2": 2.0},
    {"level": 4, "name": "detailed", "simplify_tolerance_px": 0.0, "visible_min_area_km2": 0.0},
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def normalize_geopackage(path: Path):
    with sqlite3.connect(path) as connection:
        connection.execute("UPDATE gpkg_contents SET last_change = ?", (FIXED_GPKG_TIMESTAMP,))
        connection.commit()
        connection.execute("VACUUM")


def as_multipolygon(geometry):
    if geometry.geom_type == "Polygon":
        return MultiPolygon([geometry])
    if geometry.geom_type == "MultiPolygon":
        return geometry
    raise ValueError(f"Unexpected simplified geometry type: {geometry.geom_type}")


def points(line):
    return [[float(x), float(y)] for x, y in line.coords]


def point_hash(point_list):
    packed = json.dumps(point_list, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(packed.encode("utf-8")).hexdigest().upper()


def render_preview(land, output):
    size = 1200
    image = Image.new("RGB", (size, size), (22, 45, 58))
    draw = ImageDraw.Draw(image)
    scale = size / base.GAME_SIZE
    for feature in land.itertuples(index=False):
        if not feature.visible:
            continue
        for polygon in feature.geometry.geoms:
            exterior = [(x * scale, y * scale) for x, y in polygon.exterior.coords]
            draw.polygon(exterior, fill=(238, 239, 232))
            draw.line(exterior, fill=(7, 15, 19), width=1)
            for ring in polygon.interiors:
                hole = [(x * scale, y * scale) for x, y in ring.coords]
                draw.polygon(hole, fill=(22, 45, 58))
    image.save(output, optimize=True)


def main():
    approval = json.loads(phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
    if not approval.get("approval", {}).get("approved") or not approval.get("derived_layers_allowed"):
        raise SystemExit("Gate 1 is not approved; Phase D derivatives are blocked.")
    if sha256(phase_c.MASTER_GPKG) != approval["canonical_sha256"]:
        raise SystemExit("Canonical GeoPackage hash differs from the approved master manifest.")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    canonical = gpd.read_file(phase_c.MASTER_GPKG, layer=approval["canonical_layer"])
    areas_km2 = canonical.to_crs(base.AREA_CRS).area / 1_000_000
    canonical = canonical.assign(area_km2=areas_km2.values)
    bounds, scale, offset_x, offset_y, content_h = base.game_transform_definition()
    game_master = canonical.copy()
    game_master.geometry = game_master.geometry.apply(
        lambda geom: as_multipolygon(base.to_game_geometry(geom, bounds, scale, offset_x, offset_y, content_h))
    )
    game_master = game_master.set_crs(None, allow_override=True)

    # Create a nested hierarchy from detailed to coarse. Each coarse geometry is
    # simplified from the immediately finer geometry using only the additional
    # tolerance, so its retained vertices remain anchored to the finer level.
    geometries_by_level = {
        4: dict(zip(game_master.feature_id, game_master.geometry))
    }
    for level in range(3, -1, -1):
        step_tolerance = (
            LOD_DEFINITIONS[level]["simplify_tolerance_px"]
            - LOD_DEFINITIONS[level + 1]["simplify_tolerance_px"]
        )
        geometries_by_level[level] = {
            feature_id: as_multipolygon(
                shapely.simplify(geometry, tolerance=step_tolerance, preserve_topology=True)
            )
            for feature_id, geometry in geometries_by_level[level + 1].items()
        }

    phase_c_coast = gpd.read_file(phase_c.COAST_GPKG, layer=phase_c.COAST_MASTER_LAYER)
    base_coast_ids = {
        (row.land_feature_id, int(row.part_index)): row.coastline_id
        for row in phase_c_coast.itertuples(index=False)
    }

    if LOD_GPKG.exists():
        LOD_GPKG.unlink()
    json_levels = []
    layer_names = []
    append = False
    for definition in LOD_DEFINITIONS:
        level = definition["level"]
        land = game_master.copy()
        land["geometry"] = [geometries_by_level[level][feature_id] for feature_id in land.feature_id]
        land["lod_level"] = level
        land["visible"] = land.area_km2 >= definition["visible_min_area_km2"]
        land = land[["feature_id", "part_class", "source_id", "area_km2", "lod_level", "visible", "geometry"]]
        land = land.sort_values("feature_id").reset_index(drop=True)

        coastline_records = []
        registry = {}
        visible_ids = []
        land_references = []
        for feature in land.itertuples(index=False):
            references = []
            for part_index, polygon in enumerate(feature.geometry.geoms):
                base_coastline_id = base_coast_ids[(feature.feature_id, part_index)]
                lod_coastline_id = f"{base_coastline_id}-lod{level}"
                line = LineString(polygon.exterior.coords)
                point_list = points(line)
                coastline_records.append(
                    {
                        "coastline_id": lod_coastline_id,
                        "base_coastline_id": base_coastline_id,
                        "land_feature_id": feature.feature_id,
                        "part_index": part_index,
                        "lod_level": level,
                        "visible": bool(feature.visible),
                        "point_count": len(point_list),
                        "point_hash": point_hash(point_list),
                        "geometry": line,
                    }
                )
                registry[lod_coastline_id] = {
                    "base_coastline_id": base_coastline_id,
                    "points": point_list,
                    "point_hash": point_hash(point_list),
                    "visible": bool(feature.visible),
                    "used_by": ["normal_display", "selection_display"],
                }
                references.append(lod_coastline_id)
                if feature.visible:
                    visible_ids.append(lod_coastline_id)
            land_references.append(
                {
                    "feature_id": feature.feature_id,
                    "visible": bool(feature.visible),
                    "coastline_ids": references,
                }
            )
        coast = gpd.GeoDataFrame(coastline_records, geometry="geometry", crs=None).sort_values("coastline_id")
        registry = {key: registry[key] for key in sorted(registry)}
        visible_ids.sort()

        land_layer = f"land_lod{level}"
        coast_layer = f"coastline_lod{level}"
        land.to_file(LOD_GPKG, layer=land_layer, driver="GPKG", engine="pyogrio", append=append)
        append = True
        coast.to_file(LOD_GPKG, layer=coast_layer, driver="GPKG", engine="pyogrio", append=True)
        layer_names.extend([land_layer, coast_layer])
        render_preview(land, PREVIEW_DIR / f"lod{level}_{definition['name']}.png")

        json_levels.append(
            {
                **definition,
                "land_layer": land_layer,
                "coastline_layer": coast_layer,
                "feature_count": len(land),
                "visible_feature_count": int(land.visible.sum()),
                "coastline_registry": registry,
                "visible_coastline_ids": visible_ids,
                "land_references": land_references,
                "render_profiles": {
                    "normal_display": {"registry": "coastline_registry", "id_list": "visible_coastline_ids"},
                    "selection_display": {"registry": "coastline_registry", "id_list": "visible_coastline_ids"},
                },
            }
        )

    normalize_geopackage(LOD_GPKG)
    transform_definition = {
        "coordinate_space": [0, 0, base.GAME_SIZE, base.GAME_SIZE],
        "north_up": True,
        "y_axis": "down",
        "projection": base.GAME_PROJECTION,
        "fixed_geographic_scope": list(base.GAME_GEOGRAPHIC_SCOPE),
        "projected_scope_bounds_m": list(bounds),
        "uniform_scale_px_per_m": scale,
        "offset_x_px": offset_x,
        "offset_y_px": offset_y,
        "content_height_px": content_h,
        "padding_px": base.GAME_PADDING,
    }
    lod_json = {
        "schema_version": 1,
        "source_master": {
            "file": phase_c.MASTER_GPKG.relative_to(ROOT).as_posix(),
            "layer": approval["canonical_layer"],
            "version": approval["master_version"],
            "sha256": approval["canonical_sha256"],
        },
        "transform": transform_definition,
        "small_island_policy": "All features exist at every LOD; visibility flags alone control rendering.",
        "levels": json_levels,
    }
    LOD_JSON.write_text(json.dumps(lod_json, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")

    manifest = {
        "schema_version": 1,
        "phase": "D",
        "status": "generated",
        "generation_record": "deterministic_from_approved_source",
        "source_master_version": approval["master_version"],
        "source_master_sha256": approval["canonical_sha256"],
        "lod_definitions": LOD_DEFINITIONS,
        "rules": {
            "source": "approved japan_land master only",
            "simplification": "Nested detailed-to-coarse Shapely Douglas-Peucker with preserve_topology=True in common 8192 coordinates",
            "land_and_coast_share_geometry": True,
            "normal_and_selection_share_point_registry": True,
            "small_islands_are_not_deleted": True,
        },
        "outputs": {
            "geopackage": {
                "file": LOD_GPKG.relative_to(ROOT).as_posix(),
                "sha256": sha256(LOD_GPKG),
                "layers": layer_names,
            },
            "json": {"file": LOD_JSON.relative_to(ROOT).as_posix(), "sha256": sha256(LOD_JSON)},
            "previews": [
                (PREVIEW_DIR / f"lod{item['level']}_{item['name']}.png").relative_to(ROOT).as_posix()
                for item in LOD_DEFINITIONS
            ],
        },
        "tools": {
            "python": platform.python_version(),
            "geopandas": gpd.__version__,
            "pyogrio": pyogrio.__version__,
            "shapely": shapely.__version__,
            "pillow": Image.__version__,
            "script": "tools/build_phase_d_lod.py",
        },
    }
    LOD_MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "levels": len(LOD_DEFINITIONS),
                "features_per_level": len(game_master),
                "visible_features": [level["visible_feature_count"] for level in json_levels],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
