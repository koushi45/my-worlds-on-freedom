"""Verify Phase G source contracts, transforms, containment, and no-invention state."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import geopandas as gpd
import pyogrio
from PIL import Image
from shapely.geometry import LineString, Point, box
from shapely.ops import unary_union

import build_phase_g_derivatives as phase_g


ROOT = Path(__file__).resolve().parents[1]
REPORT = phase_g.OUT_DIR / "phase_g_verification.json"


def hashes():
    return {
        "phase_g_layers.gpkg": phase_g.sha256(phase_g.OUT_GPKG),
        "phase_g_registry.json": phase_g.sha256(phase_g.REGISTRY),
        "terrain_classification_8192.png": phase_g.sha256(phase_g.TERRAIN_RASTER),
        "terrain_codes.json": phase_g.sha256(phase_g.TERRAIN_CODES),
        "phase_g_manifest.json": phase_g.sha256(phase_g.MANIFEST),
    }


def synthetic_test():
    land = box(130.0, 31.0, 132.0, 33.0)
    linear = gpd.GeoDataFrame(
        [{"item_id": "line", "geometry": LineString([(129.0, 32.0), (133.0, 32.0)])}],
        geometry="geometry",
        crs=phase_g.base.SOURCE_CRS,
    )
    clipped_line = phase_g.clip_linear(linear, land)
    game_line = phase_g.to_game(clipped_line)
    bounds, scale, offset_x, offset_y, content_h = phase_g.base.game_transform_definition()
    expected_game = phase_g.base.to_game_geometry(clipped_line.geometry.iloc[0], bounds, scale, offset_x, offset_y, content_h)

    polygonal = gpd.GeoDataFrame(
        [{"item_id": "area", "geometry": box(129.0, 30.0, 131.0, 32.0)}],
        geometry="geometry",
        crs=phase_g.base.SOURCE_CRS,
    )
    clipped_polygon = phase_g.clip_polygonal(polygonal, land)
    castles = gpd.GeoDataFrame(
        [
            {"castle_id": "inside", "geometry": Point(131.0, 32.0)},
            {"castle_id": "outside", "geometry": Point(129.0, 30.0)},
        ],
        geometry="geometry",
        crs=phase_g.base.SOURCE_CRS,
    )
    accepted_castles, rejected_castles = phase_g.filter_castles(castles, land)
    return {
        "passed": (
            clipped_line.geometry.iloc[0].equals(LineString([(130.0, 32.0), (132.0, 32.0)]))
            and game_line.geometry.iloc[0].equals_exact(expected_game, 0.0)
            and clipped_polygon.geometry.iloc[0].equals(box(130.0, 31.0, 131.0, 32.0))
            and accepted_castles.castle_id.tolist() == ["inside"]
            and rejected_castles == ["outside"]
        ),
        "linear_clipped": True,
        "shared_transform_exact": game_line.geometry.iloc[0].equals_exact(expected_game, 0.0),
        "accepted_castles": accepted_castles.castle_id.tolist(),
        "rejected_castles": rejected_castles,
    }


def main():
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_g_derivatives.py")], cwd=ROOT, check=True, capture_output=True)
    first = hashes()
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_g_derivatives.py")], cwd=ROOT, check=True, capture_output=True)
    second = hashes()

    manifest = json.loads(phase_g.MANIFEST.read_text(encoding="utf-8"))
    registry = json.loads(phase_g.REGISTRY.read_text(encoding="utf-8"))
    codes = json.loads(phase_g.TERRAIN_CODES.read_text(encoding="utf-8"))
    master_manifest = json.loads(phase_g.phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
    master = gpd.read_file(phase_g.phase_c.MASTER_GPKG, layer=master_manifest["canonical_layer"])
    unassigned = gpd.read_file(phase_g.OUT_GPKG, layer="unassigned_land")
    layers = sorted(row[0] for row in pyogrio.list_layers(phase_g.OUT_GPKG))
    with sqlite3.connect(phase_g.OUT_GPKG) as connection:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    with Image.open(phase_g.TERRAIN_RASTER) as terrain:
        terrain_size = list(terrain.size)
        terrain_mode = terrain.mode
        terrain_values = sorted(value for _, value in (terrain.getcolors(maxcolors=256) or []))

    all_missing = all(item["status"] == "missing" for item in manifest["source_contracts"].values())
    all_zero_counts = all(value == 0 for value in manifest["counts"].values())
    no_oblique_artifact = all("oblique" not in path.name.lower() and "tilt" not in path.name.lower() for path in phase_g.OUT_DIR.rglob("*"))
    synthetic = synthetic_test()
    checks = {
        "seven_source_contracts_explicit": {
            "passed": set(manifest["source_contracts"]) == set(phase_g.SOURCE_CONTRACTS) and all_missing,
        },
        "no_unapproved_data_invented": {
            "passed": all_zero_counts and all(not registry[key] for key in ["rivers", "lakes", "roads", "castles", "cultures", "population"]),
        },
        "master_land_preserved_as_unassigned": {
            "passed": unary_union(unassigned.geometry).equals(unary_union(master.geometry)),
        },
        "only_unassigned_vector_layer_materialized": {
            "passed": layers == ["unassigned_land"],
            "layers": layers,
        },
        "river_road_shared_transform_and_land_clipping": synthetic,
        "castle_geographic_only_contract": {
            "passed": manifest["rules"]["castle_coordinate_storage"] == "geographic master only; no saved display coordinate" and "castle_game_8192" not in layers,
        },
        "terrain_classification_shares_phase_c_mask": {
            "passed": (
                manifest["land_mask_reference"]["sha256"] == phase_g.sha256(phase_g.phase_c.LAND_MASK)
                and terrain_size == [8192, 8192]
                and terrain_mode == "L"
                and terrain_values == [0]
                and codes == {"codes": {"unclassified": 0}, "nodata": 0}
            ),
        },
        "land_containment_policy": {
            "passed": "clipped to master land" in manifest["rules"]["land_containment"] and "outside rejected" in manifest["rules"]["land_containment"],
        },
        "no_persisted_oblique_coordinates": {
            "passed": no_oblique_artifact and manifest["rules"]["oblique_display"] == "runtime visual transform only; no oblique coordinates persisted",
        },
        "geopackage_integrity": {"passed": integrity == "ok", "result": integrity},
        "deterministic_regeneration": {"passed": first == second, "first": first, "second": second},
    }
    result = {"phase": "G", "all_passed": all(item["passed"] for item in checks.values()), "checks": checks}
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"all_passed": result["all_passed"], "checks": len(checks), "status": manifest["status"]}, indent=2))
    if not result["all_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
