"""Import a cited village-point dataset into the 1546 population work ledgers.

This is a one-time, reproducible spatial crosswalk step.  The imported village
counts are a late-Edo distribution proxy, never observations of 1546 people.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

from pyproj import Geod, Transformer
from shapely.geometry import MultiPolygon, Point, Polygon
from shapely.ops import transform
from shapely.strtree import STRtree


ROOT = Path(__file__).resolve().parents[1]
CONNECTIVITY = ROOT / "data/derived/scenarios/district_connectivity_1546.json"
GEOMETRY = ROOT / "data/derived/scenarios/independent_districts_1546.json"
GOVERNANCE = ROOT / "data/derived/governance/governance_1546.json"
LAND_MANIFEST = ROOT / "data/base/japan_land_manifest.json"
CONTROLS = ROOT / "data/work/population/controls_1546.json"
OBSERVATIONS = ROOT / "data/work/population/observations.json"
CROSSWALK = ROOT / "data/work/population/district_crosswalk.json"
SOURCE_ID = "honda_kyudaka_agrivillage_v2_01"
MAX_NEAREST_GAME_UNITS = 50.0


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def as_geometry(record: dict):
    polygons = []
    for polygon in record["polygons"]:
        if not polygon:
            continue
        polygons.append(Polygon(polygon[0], polygon[1:]))
    return MultiPolygon(polygons) if len(polygons) != 1 else polygons[0]


def district_records(connectivity: dict, governance: dict) -> dict[str, dict]:
    result = {}
    for district_id in connectivity["active_district_ids"]:
        if district_id in governance["districts"]:
            row = governance["districts"][district_id]
            result[district_id] = {"name": row["name"], "province": row["province"]}
        else:
            row = connectivity["extra_districts"][district_id]
            result[district_id] = {"name": row["name"], "province": row["province"]}
    return result


def province_to_group(controls: dict) -> dict[str, str]:
    result = {}
    for group, members in controls["allocation_groups"].items():
        for member in members:
            result[member] = group
    for country in controls["country_kokudaka_1598"]:
        result.setdefault(country, country)
    return result


def game_transform(manifest: dict):
    definition = manifest["game_transform"]
    projected = Transformer.from_crs("EPSG:4326", definition["projection"], always_xy=True)
    min_x, min_y, _, _ = definition["projected_scope_bounds_m"]
    scale = definition["uniform_scale_px_per_m"]
    offset_x = definition["offset_x_px"]
    offset_y = definition["offset_y_px"]
    content_height = definition["content_height_px"]

    def forward(lon: float, lat: float) -> tuple[float, float]:
        px, py = projected.transform(lon, lat)
        return (
            offset_x + (px - min_x) * scale,
            offset_y + content_height - (py - min_y) * scale,
        )

    inverse_projection = Transformer.from_crs(definition["projection"], "EPSG:4326", always_xy=True)

    def inverse_point(x, y, z=None):
        px = min_x + (x - offset_x) / scale
        py = min_y + (content_height - (y - offset_y)) / scale
        lon, lat = inverse_projection.transform(px, py)
        return (lon, lat) if z is None else (lon, lat, z)

    return forward, inverse_point


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--village-csv",
        required=True,
        type=Path,
        help="02_kyudaka_v2.01/01_Data/01_Village_point_data_v2.csv",
    )
    args = parser.parse_args()
    if not args.village_csv.is_file():
        raise SystemExit(f"missing village CSV: {args.village_csv}")

    connectivity = read_json(CONNECTIVITY)
    geometry_data = read_json(GEOMETRY)
    governance = read_json(GOVERNANCE)
    controls = read_json(CONTROLS)
    manifest = read_json(LAND_MANIFEST)
    active_ids = connectivity["active_district_ids"]
    if set(active_ids) != set(geometry_data["regions"]):
        raise SystemExit("active and geometry district IDs differ")

    records = district_records(connectivity, governance)
    province_groups = province_to_group(controls)
    missing_groups = sorted({row["province"] for row in records.values()} - set(province_groups))
    if missing_groups:
        raise SystemExit(f"no allocation group for provinces: {missing_groups}")

    geometries = [as_geometry(geometry_data["regions"][district_id]) for district_id in active_ids]
    tree = STRtree(geometries)
    forward, inverse = game_transform(manifest)
    counts = Counter()
    assignment_mode = Counter()
    unmatched_by_source_country = Counter()
    source_rows = 0

    with args.village_csv.open("r", encoding="cp932", newline="") as stream:
        reader = csv.reader(stream)
        next(reader)
        for row in reader:
            if len(row) < 19 or not row[17] or not row[18]:
                continue
            source_rows += 1
            point = Point(*forward(float(row[17]), float(row[18])))
            matches = tree.query(point, predicate="covered_by")
            if len(matches):
                index = min((int(value) for value in matches), key=lambda i: (geometries[i].area, active_ids[i]))
                mode = "point_in_polygon"
            else:
                index = int(tree.nearest(point))
                if point.distance(geometries[index]) > MAX_NEAREST_GAME_UNITS:
                    unmatched_by_source_country[row[3]] += 1
                    continue
                mode = "nearest_within_50_game_units"
            counts[active_ids[index]] += 1
            assignment_mode[mode] += 1

    geod = Geod(ellps="WGS84")
    areas = {}
    for district_id, geom in zip(active_ids, geometries):
        lonlat = transform(inverse, geom)
        area_m2, _ = geod.geometry_area_perimeter(lonlat)
        areas[district_id] = abs(area_m2) / 1_000_000.0

    ids_by_group = defaultdict(list)
    for district_id in active_ids:
        ids_by_group[province_groups[records[district_id]["province"]]].append(district_id)
    weights = {}
    methods = {}
    for group, district_ids in ids_by_group.items():
        known_count = sum(counts[district_id] for district_id in district_ids)
        known_area = sum(areas[district_id] for district_id in district_ids if counts[district_id] > 0)
        density = known_count / known_area if known_area > 0 else 0.01
        for district_id in district_ids:
            if counts[district_id] > 0:
                weights[district_id] = float(counts[district_id])
                methods[district_id] = "late_village_point_count"
            else:
                weights[district_id] = max(areas[district_id] * density, 0.01)
                methods[district_id] = "geodesic_area_fallback"

    group_weight_sums = {
        group: sum(weights[district_id] for district_id in district_ids)
        for group, district_ids in ids_by_group.items()
    }
    observations = {}
    crosswalks = {}
    for district_id in active_ids:
        group = province_groups[records[district_id]["province"]]
        observation_id = "obs_distribution_" + district_id.replace("/", "__")
        crosswalk_id = "crosswalk_" + district_id.replace("/", "__")
        observations[observation_id] = {
            "observation_id": observation_id,
            "district_id": district_id,
            "record_year": 1868,
            "indicator": methods[district_id],
            "village_point_count": counts[district_id],
            "geodesic_area_km2": round(areas[district_id], 6),
            "allocation_weight_raw": round(weights[district_id], 9),
            "source_ids": [SOURCE_ID, "game_boundary_1546"],
            "note": "人口観測ではない。幕末村落点を現行ゲーム境界へ集計した1546年配分用代理指標。",
        }
        crosswalks[crosswalk_id] = {
            "crosswalk_id": crosswalk_id,
            "source_region_id": f"late-village-points:{district_id}",
            "district_id": district_id,
            "allocation_group_id": group,
            "allocation_weight": weights[district_id] / group_weight_sums[group],
            "basis": methods[district_id],
            "source_ids": [SOURCE_ID, "game_boundary_1546"],
            "boundary_confidence": "medium" if counts[district_id] > 0 else "low",
        }

    write_json(
        OBSERVATIONS,
        {
            "schema_version": 1,
            "import": {
                "source_id": SOURCE_ID,
                "source_file_sha256": sha256(args.village_csv),
                "source_rows_with_coordinates": source_rows,
                "assigned_rows": sum(counts.values()),
                "assignment_modes": dict(sorted(assignment_mode.items())),
                "unmatched_by_source_country": dict(sorted(unmatched_by_source_country.items())),
                "warning": "後代資料の空間分布指標であり、1546年人口の直接観測ではない。",
            },
            "observations": observations,
        },
    )
    write_json(
        CROSSWALK,
        {
            "schema_version": 1,
            "boundary_version": "district-connectivity-1546@d60a386b",
            "crosswalks": crosswalks,
        },
    )
    print(
        f"Imported {sum(counts.values())}/{source_rows} village points; "
        f"{sum(value == 'geodesic_area_fallback' for value in methods.values())} district fallbacks"
    )


if __name__ == "__main__":
    main()
