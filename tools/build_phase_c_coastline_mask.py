"""Build Phase C coastline and 8192 land-mask derivatives from the approved master."""

from __future__ import annotations

import hashlib
import json
import platform
import sqlite3
import uuid
from pathlib import Path

import geopandas as gpd
import pyogrio
import shapely
from PIL import Image, ImageDraw
from shapely.geometry import LineString

import build_japan_land_base as base


ROOT = Path(__file__).resolve().parents[1]
MASTER_GPKG = ROOT / "data/base/japan_land.gpkg"
MASTER_MANIFEST = ROOT / "data/base/japan_land_master_manifest.json"
COAST_DIR = ROOT / "data/derived/coastline"
MASK_DIR = ROOT / "data/derived/land_masks"
COAST_GPKG = COAST_DIR / "coastline_master.gpkg"
LAND_MASK = MASK_DIR / "land_mask_8192.png"
LAND_JSON = MASK_DIR / "land_master_8192.json"
PHASE_C_MANIFEST = ROOT / "data/derived/phase_c_manifest.json"
COAST_MASTER_LAYER = "coastline_master"
COAST_GAME_LAYER = "coastline_8192"
FIXED_GPKG_TIMESTAMP = "2026-01-01T00:00:00.000Z"
COAST_NAMESPACE = uuid.UUID("11954d70-3153-5b8f-9835-55906fdb4e2e")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def point_hash(points) -> str:
    packed = json.dumps(points, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(packed.encode("utf-8")).hexdigest().upper()


def normalize_geopackage(path: Path):
    with sqlite3.connect(path) as connection:
        connection.execute("UPDATE gpkg_contents SET last_change = ?", (FIXED_GPKG_TIMESTAMP,))
        connection.commit()
        connection.execute("VACUUM")


def line_points(line: LineString):
    return [[float(x), float(y)] for x, y in line.coords]


def main():
    approval = json.loads(MASTER_MANIFEST.read_text(encoding="utf-8"))
    if not approval.get("approval", {}).get("approved") or not approval.get("derived_layers_allowed"):
        raise SystemExit("Gate 1 is not approved; Phase C derivatives are blocked.")
    if sha256(MASTER_GPKG) != approval["canonical_sha256"]:
        raise SystemExit("Canonical GeoPackage hash differs from the approved master manifest.")

    COAST_DIR.mkdir(parents=True, exist_ok=True)
    MASK_DIR.mkdir(parents=True, exist_ok=True)
    canonical = gpd.read_file(MASTER_GPKG, layer=approval["canonical_layer"])
    bounds, scale, offset_x, offset_y, content_h = base.game_transform_definition()

    master_records = []
    game_records = []
    land_features = []
    coastline_registry = {}
    all_coastline_ids = []
    mask_parts = []

    for feature in canonical.sort_values("feature_id").itertuples(index=False):
        feature_parts = []
        for part_index, polygon in enumerate(feature.geometry.geoms):
            coastline_id = "jp-coast-" + uuid.uuid5(
                COAST_NAMESPACE, f"{approval['master_version']}:{feature.feature_id}:{part_index}:exterior"
            ).hex[:16]
            source_line = LineString(polygon.exterior.coords)
            game_line = base.to_game_geometry(
                source_line, bounds, scale, offset_x, offset_y, content_h
            )
            source_points = line_points(source_line)
            game_points = line_points(game_line)
            coordinate_hash = point_hash(game_points)
            attributes = {
                "coastline_id": coastline_id,
                "land_feature_id": feature.feature_id,
                "part_index": part_index,
                "ring_role": "exterior",
                "point_count": len(source_points),
            }
            master_records.append({**attributes, "point_hash": point_hash(source_points), "geometry": source_line})
            game_records.append({**attributes, "point_hash": coordinate_hash, "geometry": game_line})
            coastline_registry[coastline_id] = {
                "points": game_points,
                "point_hash": coordinate_hash,
                "point_count": len(game_points),
                "used_by": ["normal_display", "selection_display"],
            }
            all_coastline_ids.append(coastline_id)

            holes = []
            mask_holes = []
            for hole_index, ring in enumerate(polygon.interiors):
                hole_game = base.to_game_geometry(
                    LineString(ring.coords), bounds, scale, offset_x, offset_y, content_h
                )
                hole_points = line_points(hole_game)
                holes.append({"hole_index": hole_index, "points": hole_points, "point_hash": point_hash(hole_points)})
                mask_holes.append(hole_points)

            feature_parts.append(
                {
                    "part_index": part_index,
                    "exterior_coastline_id": coastline_id,
                    "interior_rings": holes,
                }
            )
            mask_parts.append((game_points, mask_holes))
        land_features.append({"feature_id": feature.feature_id, "parts": feature_parts})

    master_coast = gpd.GeoDataFrame(master_records, geometry="geometry", crs=canonical.crs).sort_values("coastline_id")
    game_coast = gpd.GeoDataFrame(game_records, geometry="geometry", crs=None).sort_values("coastline_id")
    all_coastline_ids.sort()
    coastline_registry = {key: coastline_registry[key] for key in all_coastline_ids}

    if COAST_GPKG.exists():
        COAST_GPKG.unlink()
    master_coast.to_file(COAST_GPKG, layer=COAST_MASTER_LAYER, driver="GPKG", engine="pyogrio")
    game_coast.to_file(COAST_GPKG, layer=COAST_GAME_LAYER, driver="GPKG", engine="pyogrio", append=True)
    normalize_geopackage(COAST_GPKG)

    mask = Image.new("L", (base.GAME_SIZE, base.GAME_SIZE), 0)
    draw = ImageDraw.Draw(mask)
    for exterior, holes in mask_parts:
        draw.polygon([tuple(point) for point in exterior], fill=255)
        for hole in holes:
            draw.polygon([tuple(point) for point in hole], fill=0)
    mask.save(LAND_MASK, optimize=True)

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
        "deterministic_formula": "WGS84 -> stated LCC; x=offset_x+(X-minX)*scale; y=offset_y+content_height-(Y-minY)*scale",
    }
    land_json = {
        "schema_version": 1,
        "source_master": {
            "file": MASTER_GPKG.relative_to(ROOT).as_posix(),
            "layer": approval["canonical_layer"],
            "version": approval["master_version"],
            "sha256": approval["canonical_sha256"],
        },
        "transform": transform_definition,
        "land_features": land_features,
        "coastlines": coastline_registry,
        "all_coastline_ids": all_coastline_ids,
        "render_profiles": {
            "normal_display": {"registry": "coastlines", "id_list": "all_coastline_ids"},
            "selection_display": {"registry": "coastlines", "id_list": "all_coastline_ids"},
        },
        "mask": {
            "file": LAND_MASK.relative_to(ROOT).as_posix(),
            "size": [base.GAME_SIZE, base.GAME_SIZE],
            "mode": "L",
            "sea_value": 0,
            "land_value": 255,
            "rasterization": "Pillow polygon fill using the same transformed exterior/interior point lists",
        },
    }
    LAND_JSON.write_text(json.dumps(land_json, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")

    phase_manifest = {
        "schema_version": 1,
        "phase": "C",
        "status": "generated",
        "generation_record": "deterministic_from_approved_source",
        "source_approved_at": approval["approval"]["approved_at"],
        "source_master_version": approval["master_version"],
        "source_master_sha256": approval["canonical_sha256"],
        "rules": {
            "coastline_source": "exterior rings of approved japan_land only",
            "coordinate_inference": False,
            "shared_transform": True,
            "normal_and_selection_share_registry": True,
        },
        "counts": {
            "land_features": len(land_features),
            "coastline_rings": len(all_coastline_ids),
            "coastline_points": sum(item["point_count"] for item in coastline_registry.values()),
            "inner_rings": sum(len(part["interior_rings"]) for feature in land_features for part in feature["parts"]),
        },
        "outputs": {
            "coastline_geopackage": {
                "file": COAST_GPKG.relative_to(ROOT).as_posix(),
                "sha256": sha256(COAST_GPKG),
                "layers": [COAST_MASTER_LAYER, COAST_GAME_LAYER],
            },
            "land_mask_8192": {"file": LAND_MASK.relative_to(ROOT).as_posix(), "sha256": sha256(LAND_MASK)},
            "land_master_8192": {"file": LAND_JSON.relative_to(ROOT).as_posix(), "sha256": sha256(LAND_JSON)},
        },
        "tools": {
            "python": platform.python_version(),
            "geopandas": gpd.__version__,
            "pyogrio": pyogrio.__version__,
            "shapely": shapely.__version__,
            "pillow": Image.__version__,
            "script": "tools/build_phase_c_coastline_mask.py",
        },
    }
    PHASE_C_MANIFEST.write_text(json.dumps(phase_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"coastlines": len(all_coastline_ids), "points": phase_manifest["counts"]["coastline_points"]}, indent=2))


if __name__ == "__main__":
    main()
