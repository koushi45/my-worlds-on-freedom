"""Build Phase F political regions without inventing missing historical data."""

from __future__ import annotations

import hashlib
import json
import sqlite3
import uuid
from pathlib import Path

import geopandas as gpd
import pyogrio
import shapely
from shapely.geometry import LineString, MultiLineString, MultiPolygon
from shapely.ops import unary_union

import build_japan_land_base as base
import build_phase_c_coastline_mask as phase_c


ROOT = Path(__file__).resolve().parents[1]
HISTORICAL_SOURCE = ROOT / "data/sources/approved/historical_regions.gpkg"
HISTORICAL_LAYER = "historical_regions"
OUT_DIR = ROOT / "data/derived/political"
POLITICAL_GPKG = OUT_DIR / "political_regions.gpkg"
REGISTRY_JSON = OUT_DIR / "political_registry.json"
AUDIT_JSON = OUT_DIR / "political_audit.json"
MANIFEST = OUT_DIR / "phase_f_manifest.json"
FIXED_GPKG_TIMESTAMP = "2026-01-01T00:00:00.000Z"
NAMESPACE = uuid.UUID("67708184-0ab7-591e-bfbb-49c9c948a933")


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


def polygonal_only(geometry):
    parts = []
    if geometry.geom_type == "Polygon":
        parts = [geometry]
    elif geometry.geom_type == "MultiPolygon":
        parts = list(geometry.geoms)
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            if part.geom_type == "Polygon":
                parts.append(part)
            elif part.geom_type == "MultiPolygon":
                parts.extend(part.geoms)
    return MultiPolygon(parts)


def lineal_only(geometry):
    parts = []
    if geometry.geom_type in ("LineString", "LinearRing"):
        parts = [LineString(geometry.coords)]
    elif geometry.geom_type == "MultiLineString":
        parts = list(geometry.geoms)
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            if part.geom_type in ("LineString", "LinearRing"):
                parts.append(LineString(part.coords))
            elif part.geom_type == "MultiLineString":
                parts.extend(part.geoms)
    return parts


def load_historical_source():
    if not HISTORICAL_SOURCE.exists():
        return None
    layers = {row[0] for row in pyogrio.list_layers(HISTORICAL_SOURCE)}
    if HISTORICAL_LAYER not in layers:
        raise ValueError(f"Missing layer {HISTORICAL_LAYER} in {HISTORICAL_SOURCE}")
    source = gpd.read_file(HISTORICAL_SOURCE, layer=HISTORICAL_LAYER)
    required = {"region_id", "region_name", "certainty"}
    missing = sorted(required - set(source.columns))
    if missing:
        raise ValueError(f"Historical source is missing required fields: {missing}")
    if source.crs is None:
        raise ValueError("Historical source CRS must be declared")
    if source.region_id.isna().any() or source.region_id.duplicated().any():
        raise ValueError("Historical region_id values must be present and unique")
    return source.to_crs(base.SOURCE_CRS)


def clip_regions(source, master_union):
    records = []
    excluded = []
    if source is None:
        return gpd.GeoDataFrame(
            columns=["region_id", "region_name", "certainty", "source_status", "geometry"],
            geometry="geometry",
            crs=base.SOURCE_CRS,
        ), excluded
    for row in source.sort_values("region_id").itertuples(index=False):
        clipped = polygonal_only(shapely.make_valid(row.geometry).intersection(master_union))
        if clipped.is_empty:
            excluded.append({"region_id": str(row.region_id), "reason": "outside_target_land"})
            continue
        records.append(
            {
                "region_id": str(row.region_id),
                "region_name": str(row.region_name),
                "certainty": str(row.certainty),
                "source_status": "historical_source_clipped_to_master_land",
                "geometry": clipped,
            }
        )
    return gpd.GeoDataFrame(records, geometry="geometry", crs=base.SOURCE_CRS), excluded


def extract_shared_boundaries(regions):
    records = []
    if regions.empty:
        return gpd.GeoDataFrame(
            columns=["boundary_id", "region_a", "region_b", "status", "geometry"],
            geometry="geometry",
            crs=base.SOURCE_CRS,
        )
    for left_index, left in regions.iterrows():
        for right_index in regions.sindex.query(left.geometry, predicate="intersects"):
            if right_index <= left_index:
                continue
            right = regions.iloc[right_index]
            shared = left.geometry.boundary.intersection(right.geometry.boundary)
            for part_index, line in enumerate(lineal_only(shared)):
                if line.is_empty or len(line.coords) < 2:
                    continue
                region_a, region_b = sorted([left.region_id, right.region_id])
                boundary_id = "jp-boundary-" + uuid.uuid5(
                    NAMESPACE, f"{region_a}:{region_b}:{part_index}:{shapely.normalize(line).wkb_hex}"
                ).hex[:16]
                records.append(
                    {
                        "boundary_id": boundary_id,
                        "region_a": region_a,
                        "region_b": region_b,
                        "status": "confirmed_shared_edge",
                        "geometry": line,
                    }
                )
    return gpd.GeoDataFrame(records, geometry="geometry", crs=base.SOURCE_CRS)


def coastline_references(regions, coastlines):
    references = {region_id: [] for region_id in regions.region_id}
    if regions.empty:
        return references
    for region in regions.itertuples(index=False):
        boundary = region.geometry.boundary
        for coast in coastlines.itertuples(index=False):
            if not boundary.intersects(coast.geometry):
                continue
            for segment_index, segment in enumerate(lineal_only(boundary.intersection(coast.geometry))):
                if segment.is_empty or segment.length == 0:
                    continue
                start = coast.geometry.project(shapely.Point(segment.coords[0]), normalized=True)
                end = coast.geometry.project(shapely.Point(segment.coords[-1]), normalized=True)
                references[region.region_id].append(
                    {
                        "coastline_id": coast.coastline_id,
                        "segment_index": segment_index,
                        "start_fraction": min(start, end),
                        "end_fraction": max(start, end),
                        "point_source": "referenced_master_coastline",
                    }
                )
        references[region.region_id].sort(
            key=lambda item: (item["coastline_id"], item["start_fraction"], item["end_fraction"])
        )
    return references


def pair_overlaps(regions):
    overlaps = []
    if regions.empty:
        return overlaps
    projected = regions.to_crs(base.AREA_CRS)
    for left_index, left in projected.iterrows():
        for right_index in projected.sindex.query(left.geometry, predicate="intersects"):
            if right_index <= left_index:
                continue
            area = left.geometry.intersection(projected.iloc[right_index].geometry).area
            if area > 0.01:
                overlaps.append(
                    {
                        "region_a": left.region_id,
                        "region_b": projected.iloc[right_index].region_id,
                        "area_m2": area,
                    }
                )
    return overlaps


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    master_manifest = json.loads(phase_c.MASTER_MANIFEST.read_text(encoding="utf-8"))
    if sha256(phase_c.MASTER_GPKG) != master_manifest["canonical_sha256"]:
        raise SystemExit("Approved land master hash mismatch")
    land = gpd.read_file(phase_c.MASTER_GPKG, layer=master_manifest["canonical_layer"])
    master_union = unary_union(land.geometry)
    coastlines = gpd.read_file(phase_c.COAST_GPKG, layer=phase_c.COAST_MASTER_LAYER)
    source = load_historical_source()
    regions, excluded = clip_regions(source, master_union)
    shared = extract_shared_boundaries(regions)
    coast_refs = coastline_references(regions, coastlines)

    political_union = unary_union(regions.geometry) if not regions.empty else MultiPolygon([])
    gap = polygonal_only(master_union.difference(political_union))
    overlaps = pair_overlaps(regions)
    area_master = gpd.GeoSeries([master_union], crs=base.SOURCE_CRS).to_crs(base.AREA_CRS).area.iloc[0]
    area_regions = 0.0 if regions.empty else regions.to_crs(base.AREA_CRS).area.sum()
    area_union = 0.0 if political_union.is_empty else gpd.GeoSeries([political_union], crs=base.SOURCE_CRS).to_crs(base.AREA_CRS).area.iloc[0]
    area_gap = 0.0 if gap.is_empty else gpd.GeoSeries([gap], crs=base.SOURCE_CRS).to_crs(base.AREA_CRS).area.iloc[0]

    click_masks = regions.copy()
    if not click_masks.empty:
        click_masks["click_mask_id"] = click_masks.region_id.map(lambda value: "jp-click-" + uuid.uuid5(NAMESPACE, value).hex[:16])
        click_masks["render_enabled"] = False
        click_masks = click_masks[["click_mask_id", "region_id", "render_enabled", "geometry"]]

    layers = []
    if POLITICAL_GPKG.exists():
        POLITICAL_GPKG.unlink()
    if not regions.empty:
        regions.to_file(POLITICAL_GPKG, layer="political_regions", driver="GPKG", engine="pyogrio")
        layers.append("political_regions")
    if not shared.empty:
        shared.to_file(POLITICAL_GPKG, layer="shared_boundaries", driver="GPKG", engine="pyogrio", append=bool(layers))
        layers.append("shared_boundaries")
    if not click_masks.empty:
        click_masks.to_file(POLITICAL_GPKG, layer="click_masks", driver="GPKG", engine="pyogrio", append=bool(layers))
        layers.append("click_masks")
    if not gap.is_empty:
        unassigned = gpd.GeoDataFrame(
            [{"status": "unassigned", "reason": "historical_source_missing" if source is None else "historical_source_gap", "geometry": gap}],
            geometry="geometry",
            crs=base.SOURCE_CRS,
        )
        unassigned.to_file(POLITICAL_GPKG, layer="unassigned_land", driver="GPKG", engine="pyogrio", append=bool(layers))
        layers.append("unassigned_land")
    normalize_geopackage(POLITICAL_GPKG)

    boundary_ids = {region_id: [] for region_id in regions.region_id}
    for item in shared.itertuples(index=False):
        boundary_ids[item.region_a].append(item.boundary_id)
        boundary_ids[item.region_b].append(item.boundary_id)
    registry = {
        "schema_version": 1,
        "source_status": "approved" if source is not None else "missing",
        "regions": [
            {
                "region_id": row.region_id,
                "region_name": row.region_name,
                "certainty": row.certainty,
                "selection_display": {
                    "shared_boundary_ids": sorted(boundary_ids[row.region_id]),
                    "coastline_references": coast_refs[row.region_id],
                },
                "click_mask": {
                    "click_mask_id": "jp-click-" + uuid.uuid5(NAMESPACE, row.region_id).hex[:16],
                    "purpose": "hit_test_only",
                    "render_enabled": False,
                    "display_boundary_source": "never_from_click_mask",
                },
            }
            for row in regions.sort_values("region_id").itertuples(index=False)
        ],
        "unassigned": {
            "status": "unconfirmed",
            "reason": "historical_source_missing" if source is None else "historical_source_gap",
            "area_m2": area_gap,
        },
    }
    REGISTRY_JSON.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    audit = {
        "master_land_area_m2": area_master,
        "political_region_area_sum_m2": area_regions,
        "political_region_union_area_m2": area_union,
        "gap_area_m2": area_gap,
        "coverage_ratio": area_union / area_master,
        "overlap_count": len(overlaps),
        "overlaps": overlaps,
        "gap_status": "explicitly_unassigned" if not gap.is_empty else "none",
        "excluded_source_regions": excluded,
        "area_balance_error_m2": abs(area_master - (area_union + area_gap)),
    }
    AUDIT_JSON.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    manifest = {
        "schema_version": 1,
        "phase": "F",
        "status": "verified_pipeline_awaiting_historical_source" if source is None else "generated",
        "source_contract": {
            "expected_file": HISTORICAL_SOURCE.relative_to(ROOT).as_posix(),
            "layer": HISTORICAL_LAYER,
            "required_fields": ["region_id", "region_name", "certainty", "geometry"],
            "current_status": "missing" if source is None else "present",
            "missing_data_policy": "Do not infer boundaries; preserve uncovered master land as unassigned.",
        },
        "operation": "political_region = historical_region intersection approved japan_land master",
        "rules": {
            "shared_edges_only": True,
            "coastline_storage": "coastline_id plus linear-reference fractions; no duplicated coastline points",
            "selection_display": "shared boundary IDs plus referenced coastline segments",
            "click_masks_are_hit_test_only": True,
            "boundaries_never_derived_from_click_masks": True,
        },
        "outputs": {
            "geopackage": {"file": POLITICAL_GPKG.relative_to(ROOT).as_posix(), "sha256": sha256(POLITICAL_GPKG), "layers": layers},
            "registry": {"file": REGISTRY_JSON.relative_to(ROOT).as_posix(), "sha256": sha256(REGISTRY_JSON)},
            "audit": {"file": AUDIT_JSON.relative_to(ROOT).as_posix(), "sha256": sha256(AUDIT_JSON)},
        },
        "counts": {
            "political_regions": len(regions),
            "shared_boundaries": len(shared),
            "click_masks": len(click_masks),
            "coastline_references": sum(len(items) for items in coast_refs.values()),
            "unassigned_features": 0 if gap.is_empty else 1,
        },
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "regions": len(regions), "gap_area_m2": area_gap}, indent=2))


if __name__ == "__main__":
    main()
