"""Build Phase G derivative infrastructure from explicitly approved sources only."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import geopandas as gpd
import pyogrio
import shapely
from PIL import Image, ImageDraw
from shapely.geometry import LineString, MultiLineString, MultiPolygon
from shapely.ops import unary_union

import build_japan_land_base as base
import build_phase_c_coastline_mask as phase_c


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "data/sources/approved/phase_g"
OUT_DIR = ROOT / "data/derived/phase_g"
OUT_GPKG = OUT_DIR / "phase_g_layers.gpkg"
REGISTRY = OUT_DIR / "phase_g_registry.json"
MANIFEST = OUT_DIR / "phase_g_manifest.json"
TERRAIN_RASTER = OUT_DIR / "terrain_classification_8192.png"
TERRAIN_CODES = OUT_DIR / "terrain_codes.json"
FIXED_GPKG_TIMESTAMP = "2026-01-01T00:00:00.000Z"

SOURCE_CONTRACTS = {
    "rivers": {"file": "rivers.gpkg", "layer": "rivers", "id": "river_id", "fields": ["river_id", "name"], "geometry": "line"},
    "lakes": {"file": "lakes.gpkg", "layer": "lakes", "id": "lake_id", "fields": ["lake_id", "name"], "geometry": "polygon"},
    "roads": {"file": "roads.gpkg", "layer": "roads", "id": "road_id", "fields": ["road_id", "name"], "geometry": "line"},
    "castles": {"file": "castles.gpkg", "layer": "castles", "id": "castle_id", "fields": ["castle_id", "name", "rank"], "geometry": "point"},
    "cultures": {"file": "cultures.gpkg", "layer": "culture_regions", "id": "culture_id", "fields": ["culture_id", "name"], "geometry": "polygon"},
    "population": {"file": "population.gpkg", "layer": "population_regions", "id": "population_id", "fields": ["population_id", "population", "year"], "geometry": "polygon"},
    "terrain": {"file": "terrain.gpkg", "layer": "terrain_regions", "id": "terrain_id", "fields": ["terrain_id", "terrain_class"], "geometry": "polygon"},
}


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


def lineal_only(geometry):
    lines = []
    if geometry.geom_type in ("LineString", "LinearRing"):
        lines = [LineString(geometry.coords)]
    elif geometry.geom_type == "MultiLineString":
        lines = list(geometry.geoms)
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            lines.extend(lineal_only(part))
    return MultiLineString(lines) if len(lines) > 1 else (lines[0] if lines else MultiLineString([]))


def polygonal_only(geometry):
    polygons = []
    if geometry.geom_type == "Polygon":
        polygons = [geometry]
    elif geometry.geom_type == "MultiPolygon":
        polygons = list(geometry.geoms)
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            selected = polygonal_only(part)
            polygons.extend(selected.geoms if selected.geom_type == "MultiPolygon" else [selected])
    return MultiPolygon(polygons)


def load_source(name):
    contract = SOURCE_CONTRACTS[name]
    path = SOURCE_DIR / contract["file"]
    if not path.exists():
        return None
    layers = {row[0] for row in pyogrio.list_layers(path)}
    if contract["layer"] not in layers:
        raise ValueError(f"{name}: missing layer {contract['layer']}")
    frame = gpd.read_file(path, layer=contract["layer"])
    missing = sorted(set(contract["fields"]) - set(frame.columns))
    if missing or frame.crs is None:
        raise ValueError(f"{name}: missing fields={missing}, crs={frame.crs}")
    if frame[contract["id"]].isna().any() or frame[contract["id"]].duplicated().any():
        raise ValueError(f"{name}: IDs must be present and unique")
    return frame.to_crs(base.SOURCE_CRS)


def clip_linear(frame, land_union):
    if frame is None:
        return None
    result = frame.copy()
    result.geometry = result.geometry.apply(lambda geometry: lineal_only(shapely.make_valid(geometry).intersection(land_union)))
    return result[~result.geometry.is_empty].reset_index(drop=True)


def clip_polygonal(frame, land_union):
    if frame is None:
        return None
    result = frame.copy()
    result.geometry = result.geometry.apply(lambda geometry: polygonal_only(shapely.make_valid(geometry).intersection(land_union)))
    return result[~result.geometry.is_empty].reset_index(drop=True)


def to_game(frame):
    if frame is None:
        return None
    bounds, scale, offset_x, offset_y, content_h = base.game_transform_definition()
    result = frame.copy()
    result.geometry = result.geometry.apply(
        lambda geometry: base.to_game_geometry(geometry, bounds, scale, offset_x, offset_y, content_h)
    )
    return result.set_crs(None, allow_override=True)


def filter_castles(frame, land_union):
    if frame is None:
        return None, []
    inside = frame.geometry.apply(land_union.covers)
    rejected = frame.loc[~inside, "castle_id"].astype(str).tolist()
    return frame.loc[inside].reset_index(drop=True), rejected


def write_layer(frame, layer, append):
    if frame is None or frame.empty:
        return append, False
    frame.to_file(OUT_GPKG, layer=layer, driver="GPKG", engine="pyogrio", append=append)
    return True, True


def render_terrain(terrain, land_mask):
    codes = {"unclassified": 0}
    image = Image.new("L", (base.GAME_SIZE, base.GAME_SIZE), 0)
    if terrain is not None and not terrain.empty:
        classes = sorted(set(str(value) for value in terrain.terrain_class))
        codes.update({name: index + 1 for index, name in enumerate(classes)})
        game = to_game(terrain)
        draw = ImageDraw.Draw(image)
        for row in game.itertuples(index=False):
            value = codes[str(row.terrain_class)]
            for polygon in row.geometry.geoms:
                draw.polygon(list(polygon.exterior.coords), fill=value)
                for ring in polygon.interiors:
                    draw.polygon(list(ring.coords), fill=0)
    # The Phase C mask is authoritative; classifications outside it are erased.
    image = Image.composite(image, Image.new("L", image.size, 0), land_mask)
    image.save(TERRAIN_RASTER, optimize=True)
    TERRAIN_CODES.write_text(json.dumps({"codes": codes, "nodata": 0}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return codes


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    master_manifest = json.loads(phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
    if sha256(phase_c.MASTER_GPKG) != master_manifest["canonical_sha256"]:
        raise SystemExit("Approved land master hash mismatch")
    land = gpd.read_file(phase_c.MASTER_GPKG, layer=master_manifest["canonical_layer"])
    land_union = unary_union(land.geometry)
    sources = {name: load_source(name) for name in SOURCE_CONTRACTS}

    rivers = clip_linear(sources["rivers"], land_union)
    roads = clip_linear(sources["roads"], land_union)
    lakes = clip_polygonal(sources["lakes"], land_union)
    cultures = clip_polygonal(sources["cultures"], land_union)
    population = clip_polygonal(sources["population"], land_union)
    terrain = clip_polygonal(sources["terrain"], land_union)
    castles, outside_castles = filter_castles(sources["castles"], land_union)

    if OUT_GPKG.exists():
        OUT_GPKG.unlink()
    append = False
    layers = []
    for frame, layer in [
        (rivers, "river_master"),
        (to_game(rivers), "river_game_8192"),
        (lakes, "lake_master"),
        (roads, "road_master"),
        (to_game(roads), "road_game_8192"),
        (castles, "castle_master"),
        (cultures, "culture_master"),
        (population, "population_master"),
        (terrain, "terrain_master"),
    ]:
        append, written = write_layer(frame, layer, append)
        if written:
            layers.append(layer)

    unassigned = gpd.GeoDataFrame(
        [{"status": "unassigned", "reason": "approved_phase_g_sources_missing", "geometry": land_union}],
        geometry="geometry",
        crs=base.SOURCE_CRS,
    )
    append, _ = write_layer(unassigned, "unassigned_land", append)
    layers.append("unassigned_land")
    normalize_geopackage(OUT_GPKG)

    with Image.open(phase_c.LAND_MASK) as source_mask:
        land_mask = source_mask.convert("L").copy()
    terrain_codes = render_terrain(terrain, land_mask)

    source_status = {
        name: {
            "status": "approved_present" if frame is not None else "missing",
            "expected_file": (SOURCE_DIR / contract["file"]).relative_to(ROOT).as_posix(),
            "layer": contract["layer"],
            "required_fields": [*contract["fields"], "geometry"],
            "geometry": contract["geometry"],
        }
        for (name, contract), frame in zip(SOURCE_CONTRACTS.items(), sources.values())
    }
    registry = {
        "schema_version": 1,
        "source_status": source_status,
        "rivers": [] if rivers is None else rivers.river_id.astype(str).tolist(),
        "lakes": [] if lakes is None else lakes.lake_id.astype(str).tolist(),
        "roads": [] if roads is None else roads.road_id.astype(str).tolist(),
        "castles": [] if castles is None else [
            {
                "castle_id": str(row.castle_id),
                "name": str(row.name),
                "rank": str(row.rank),
                "coordinate_storage": "geographic_master_only",
                "display_coordinate": "computed_at_runtime_with_shared_transform",
            }
            for row in castles.itertuples(index=False)
        ],
        "cultures": [] if cultures is None else cultures.culture_id.astype(str).tolist(),
        "population": [] if population is None else population.population_id.astype(str).tolist(),
        "terrain_codes": terrain_codes,
        "outside_castle_ids_rejected": outside_castles,
    }
    REGISTRY.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    counts = {
        "rivers": 0 if rivers is None else len(rivers),
        "lakes": 0 if lakes is None else len(lakes),
        "roads": 0 if roads is None else len(roads),
        "castles": 0 if castles is None else len(castles),
        "cultures": 0 if cultures is None else len(cultures),
        "population": 0 if population is None else len(population),
        "terrain_regions": 0 if terrain is None else len(terrain),
    }
    manifest = {
        "schema_version": 1,
        "phase": "G",
        "status": "verified_pipeline_awaiting_approved_sources" if all(frame is None for frame in sources.values()) else "generated",
        "source_master_version": master_manifest["master_version"],
        "source_master_sha256": master_manifest["canonical_sha256"],
        "source_contracts": source_status,
        "counts": counts,
        "rules": {
            "river_and_road_transform": "same WGS84 to shared 8192 transform",
            "castle_coordinate_storage": "geographic master only; no saved display coordinate",
            "land_containment": "linear and polygonal inputs clipped to master land; castles outside rejected",
            "terrain_mask": "references exact Phase C land mask",
            "oblique_display": "runtime visual transform only; no oblique coordinates persisted",
            "missing_source_policy": "do not infer data",
        },
        "land_mask_reference": {
            "file": phase_c.LAND_MASK.relative_to(ROOT).as_posix(),
            "sha256": sha256(phase_c.LAND_MASK),
        },
        "outputs": {
            "geopackage": {"file": OUT_GPKG.relative_to(ROOT).as_posix(), "sha256": sha256(OUT_GPKG), "layers": layers},
            "registry": {"file": REGISTRY.relative_to(ROOT).as_posix(), "sha256": sha256(REGISTRY)},
            "terrain_classification": {"file": TERRAIN_RASTER.relative_to(ROOT).as_posix(), "sha256": sha256(TERRAIN_RASTER)},
            "terrain_codes": {"file": TERRAIN_CODES.relative_to(ROOT).as_posix(), "sha256": sha256(TERRAIN_CODES)},
        },
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "counts": counts}, indent=2))


if __name__ == "__main__":
    main()
