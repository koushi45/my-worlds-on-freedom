"""Verify Phase E map rendering, clipping, composition, and global tiling."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pyogrio
from PIL import Image, ImageChops
from shapely.geometry import box

import build_phase_e_map_images as phase_e


ROOT = Path(__file__).resolve().parents[1]
REPORT = phase_e.DATA_DIR / "map_images_verification.json"


def file_set(manifest):
    paths = [phase_e.WATER_REGISTRY, phase_e.MANIFEST]
    for tile in manifest["tiles"]:
        paths.extend(ROOT / path for path in tile["files"].values())
    return sorted(set(paths))


def aggregate_hash(manifest):
    digest = hashlib.sha256()
    for path in file_set(manifest):
        digest.update(path.relative_to(ROOT).as_posix().encode("utf-8"))
        digest.update(bytes.fromhex(phase_e.sha256(path)))
    return digest.hexdigest().upper()


def images_equal(left, right):
    return left.mode == right.mode and left.size == right.size and ImageChops.difference(left, right).getbbox() is None


def main():
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_e_map_images.py")], cwd=ROOT, check=True, capture_output=True)
    first_manifest = json.loads(phase_e.MANIFEST.read_text(encoding="utf-8"))
    first_hash = aggregate_hash(first_manifest)
    subprocess.run([sys.executable, str(ROOT / "tools/build_phase_e_map_images.py")], cwd=ROOT, check=True, capture_output=True)
    manifest = json.loads(phase_e.MANIFEST.read_text(encoding="utf-8"))
    second_hash = aggregate_hash(manifest)
    water_registry = json.loads(phase_e.WATER_REGISTRY.read_text(encoding="utf-8"))

    missing_files = []
    hash_mismatches = []
    dimension_failures = []
    vector_coverage_mismatches = []
    vector_coastline_mismatches = []
    composition_mismatches = []
    terrain_clip_failures = []
    coastline_reference_failures = []
    intermediate_coverage_values = False

    lod_cache = {}
    for tile in manifest["tiles"]:
        level = tile["lod"]
        if level not in lod_cache:
            lod_cache[level] = (
                pyogrio.read_dataframe(phase_e.lod.LOD_GPKG, layer=f"land_lod{level}"),
                pyogrio.read_dataframe(phase_e.lod.LOD_GPKG, layer=f"coastline_lod{level}"),
            )
        land, coast = lod_cache[level]
        paths = {name: ROOT / path for name, path in tile["files"].items()}
        for name, path in paths.items():
            if not path.exists():
                missing_files.append(path.relative_to(ROOT).as_posix())
            elif phase_e.sha256(path) != tile["sha256"][name]:
                hash_mismatches.append(path.relative_to(ROOT).as_posix())
        if any(not path.exists() for path in paths.values()):
            continue

        with Image.open(paths["land_coverage"]) as stored_coverage:
            coverage = stored_coverage.copy()
        with Image.open(paths["coastline"]) as stored_coastline:
            coastline = stored_coastline.convert("RGBA")
        if coverage.size != (phase_e.TILE_SIZE, phase_e.TILE_SIZE) or coverage.mode != "L":
            dimension_failures.append(tile["tile_id"] + ":land_coverage")
        colors = coverage.getcolors(maxcolors=256) or []
        intermediate_coverage_values = intermediate_coverage_values or any(0 < value < 255 for _, value in colors)

        expected_coverage = phase_e.render_land_coverage(land, tile["global_viewport"])
        if not images_equal(coverage, expected_coverage):
            vector_coverage_mismatches.append(tile["tile_id"])
        expected_coastline = phase_e.render_coastline(coast, tile["global_viewport"])
        if not images_equal(coastline, expected_coastline):
            vector_coastline_mismatches.append(tile["tile_id"])

        expected_ids = sorted(
            coast.loc[
                coast.visible & coast.geometry.intersects(box(*tile["global_viewport"])),
                "coastline_id",
            ].tolist()
        )
        if tile["coastline_vector"]["coastline_ids"] != expected_ids:
            coastline_reference_failures.append(tile["tile_id"])

        opened = {}
        for name in ["water", "land_fill", *phase_e.EMPTY_LAYERS, "composite"]:
            with Image.open(paths[name]) as image:
                opened[name] = image.convert("RGBA")
            if opened[name].size != (phase_e.TILE_SIZE, phase_e.TILE_SIZE):
                dimension_failures.append(tile["tile_id"] + ":" + name)
        expected_composite = opened["water"].copy()
        expected_composite = Image.alpha_composite(expected_composite, opened["land_fill"])
        for name in phase_e.EMPTY_LAYERS:
            alpha = opened[name].getchannel("A")
            outside = ImageChops.multiply(alpha, ImageChops.invert(coverage))
            if outside.getbbox() is not None or alpha.getbbox() is not None:
                terrain_clip_failures.append(tile["tile_id"] + ":" + name)
            expected_composite = Image.alpha_composite(expected_composite, opened[name])
        expected_composite = Image.alpha_composite(expected_composite, coastline)
        if not images_equal(opened["composite"], expected_composite):
            composition_mismatches.append(tile["tile_id"])

    profile_partition_failures = []
    for profile in phase_e.RENDER_PROFILES:
        level_tiles = [tile for tile in manifest["tiles"] if tile["lod"] == profile["lod"]]
        grid = profile["grid"]
        expected = {
            (row, column): [
                column * phase_e.base.GAME_SIZE / grid,
                row * phase_e.base.GAME_SIZE / grid,
                (column + 1) * phase_e.base.GAME_SIZE / grid,
                (row + 1) * phase_e.base.GAME_SIZE / grid,
            ]
            for row in range(grid) for column in range(grid)
        }
        actual = {(tile["row"], tile["column"]): tile["global_viewport"] for tile in level_tiles}
        if actual != expected:
            profile_partition_failures.append(profile["lod"])

    lake_ids = [lake["water_id"] for lake in water_registry["lakes"]]
    distinct_water_ids = (
        water_registry["ocean"]["water_id"] == phase_e.OCEAN_ID
        and phase_e.OCEAN_ID not in lake_ids
        and len(lake_ids) == len(set(lake_ids))
        and all(identifier.startswith("jp-lake-") for identifier in lake_ids)
    )

    checks = {
        "five_lod_profiles_and_three_families": {
            "passed": len(manifest["profiles"]) == 5 and {item["family"] for item in manifest["profiles"]} == {"national", "regional", "local"},
        },
        "global_tile_partition": {"passed": not profile_partition_failures, "failures": profile_partition_failures},
        "all_files_present_and_hashed": {"passed": not missing_files and not hash_mismatches, "missing": missing_files, "hash_mismatches": hash_mismatches},
        "dimensions_and_modes": {"passed": not dimension_failures, "failures": dimension_failures},
        "land_coverage_directly_from_lod_vectors": {"passed": not vector_coverage_mismatches, "mismatches": vector_coverage_mismatches},
        "coverage_antialiasing_present": {"passed": intermediate_coverage_values, "method": manifest["coverage_antialiasing"]},
        "coastline_directly_from_matching_lod_vectors": {"passed": not vector_coastline_mismatches, "mismatches": vector_coastline_mismatches},
        "coastline_ids_match_tile_intersections": {"passed": not coastline_reference_failures, "failures": coastline_reference_failures},
        "terrain_layers_clipped_and_uninvented": {
            "passed": not terrain_clip_failures and all(item["status"] == "empty_awaiting_approved_source" for item in manifest["terrain_layers"].values()),
            "failures": terrain_clip_failures,
        },
        "ocean_and_lake_ids_separate": {"passed": distinct_water_ids, "ocean_id": phase_e.OCEAN_ID, "lake_ids": lake_ids},
        "coastline_is_final_composite_layer": {"passed": not composition_mismatches and manifest["render_order"][-1] == "coastline", "mismatches": composition_mismatches},
        "no_geometry_moving_filter_or_color_inference": {
            "passed": manifest["rules"]["geometry_moving_filters"] is False and "no color threshold" in manifest["rules"]["land_sea_source"],
        },
        "deterministic_regeneration": {"passed": first_hash == second_hash, "first_aggregate_sha256": first_hash, "second_aggregate_sha256": second_hash},
    }
    result = {"phase": "E", "all_passed": all(item["passed"] for item in checks.values()), "checks": checks}
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"all_passed": result["all_passed"], "checks": len(checks), "tiles": len(manifest["tiles"])}, indent=2))
    if not result["all_passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
