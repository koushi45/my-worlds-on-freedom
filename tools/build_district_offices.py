"""Choose one administrative hex per active district, with auditable provenance.

Full hex containment and no contact with other districts take precedence over
historical proximity. Terrain suitability is a proxy, not historical crop yield.
"""
from pathlib import Path
import hashlib
import json
import math
import re

import numpy as np
from PIL import Image
from pyproj import Transformer
from scipy.ndimage import map_coordinates, uniform_filter, gaussian_filter
from scipy.spatial import cKDTree
import shapely
from shapely.geometry import Polygon, Point, shape
from shapely.ops import transform, unary_union

ROOT = Path(__file__).resolve().parents[1]
GEOMETRY = "data/derived/scenarios/independent_districts_1546.json"
SOURCES = "data/editorial/governance/district_office_sources.json"
OUTPUT = "data/derived/scenarios/district_offices_1546.json"
REPORT = "data/derived/testing/district_offices_report.json"


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def write(path, value):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()


def main():
    radius = float(re.search(r"const RADIUS := ([\d.]+)", (ROOT/"scripts/map/hex_grid.gd").read_text())[1])
    regions = read(GEOMETRY)["regions"]
    governance = read("data/derived/governance/governance_1546.json")
    topology = read("data/derived/scenarios/district_connectivity_1546.json")
    sources = read(SOURCES)
    ids = sorted(regions)
    geometry = [shapely.make_valid(unary_union([Polygon(p[0], p[1:]) for p in regions[k]["polygons"]])) for k in ids]
    tree = shapely.STRtree(geometry)
    definition = read("data/base/japan_land_manifest.json")["game_transform"]
    projection = Transformer.from_crs("EPSG:4326", definition["projection"], always_xy=True)
    inverse = Transformer.from_crs(definition["projection"], "EPSG:4326", always_xy=True)
    bx, by, _, _ = definition["projected_scope_bounds_m"]
    scale = definition["uniform_scale_px_per_m"]

    def xy(lon, lat):
        x, y = projection.transform(lon, lat)
        return definition["offset_x_px"]+(x-bx)*scale, definition["offset_y_px"]+definition["content_height_px"]-(y-by)*scale

    def lonlat(x, y):
        return inverse.transform(bx+(x-definition["offset_x_px"])/scale, by+(definition["content_height_px"]-y+definition["offset_y_px"])/scale)

    land = unary_union([transform(xy, shape(f["geometry"])) for f in read("data/base/japan_land.geojson")["features"]])
    water = read("data/derived/hydrography/water_registry.json")
    lakes = unary_union([Polygon(r["rings"][0], r["rings"][1:]) for r in water["lakes"] if r["rings"] and int(r["source_type"]) != 1])
    dry_land = shapely.make_valid(land.difference(shapely.make_valid(lakes)))
    shapely.prepare(dry_land)
    rows = read("data/derived/detail_map/hex_coverage.json")["rows"]
    cells = np.array([(q, int(r)) for r, qs in rows.items() for q in qs], dtype=int)
    centers = np.column_stack((math.sqrt(3)*radius*(cells[:, 0]+cells[:, 1]*.5), radius*1.5*cells[:, 1]))
    angles = np.pi/6+np.arange(6)*np.pi/3
    corners = radius*np.column_stack((np.cos(angles), np.sin(angles)))
    hexes = shapely.polygons(centers[:, None, :]+corners)
    points = shapely.points(centers)
    full_land = shapely.covers(dry_land, hexes)
    center_land = shapely.contains(dry_land, points)

    # 4096-square measured DEM: 2 world units/sample. No display exaggeration.
    height = np.asarray(Image.open(ROOT/"assets/map/elevation/elevation_m.png"), dtype=float)
    pixel_span = 8192/height.shape[0]
    softened = gaussian_filter(height, .7)
    dy, dx = np.gradient(softened, pixel_span/scale)
    slope = np.arctan(np.hypot(dx, dy))*180/np.pi
    land_pixels = np.asarray(Image.open(ROOT/"data/derived/land_masks/land_mask_8192.png").resize((height.shape[1], height.shape[0]), Image.Resampling.BOX)) > 127
    flat = uniform_filter(((slope < 5.0) & (height < 700) & land_pixels).astype(float), size=9)
    coords = [centers[:, 1]/pixel_span-.5, centers[:, 0]/pixel_span-.5]
    elevations = map_coordinates(height, coords, order=1, mode="nearest")
    slopes = map_coordinates(slope, coords, order=1, mode="nearest")
    flats = map_coordinates(flat, coords, order=1, mode="nearest")
    sites = governance["sites"]
    economic_points = [s["point"] for s in sites.values() if set(s["roles"]) & {"port", "settlement"}]
    distances = cKDTree(economic_points).query(centers)[0] if economic_points else np.full(len(centers), 10000.)
    base_scores = 5*flats + 2*np.exp(-slopes/5) + 1/(1+elevations/300) + .6*np.exp(-distances/60)

    references = {}
    rejected_references = []
    for ref in sources["references"]:
        location = Point(sites[ref["site_id"]]["point"])
        containing = [int(i) for i in tree.query(location) if geometry[i].covers(location)]
        if not containing:
            rejected_references.append({"id": ref["id"], "reason": "reference outside current district geometry"})
            continue
        owner = max(containing, key=lambda i: geometry[i].boundary.distance(location))
        references.setdefault(ids[owner], []).append(ref)

    records, unresolved, used = {}, [], set()
    for index, district_id in enumerate(ids):
        if district_id in sources.get("omit_districts", {}):
            continue
        g = geometry[index]
        x0, y0, x1, y1 = g.bounds
        candidates = np.flatnonzero((centers[:, 0]>=x0)&(centers[:, 0]<=x1)&(centers[:, 1]>=y0)&(centers[:, 1]<=y1)&full_land)
        candidates = candidates[shapely.contains(g.buffer(-.05), hexes[candidates])]
        neighbors = [int(i) for i in tree.query(g) if int(i) != index]
        if neighbors and len(candidates):
            others = unary_union([geometry[i] for i in neighbors])
            candidates = candidates[~shapely.intersects(others, hexes[candidates])]
        exception = False
        if not len(candidates):
            if sources.get("boundary_exceptions", {}).get(district_id) == "center_inside":
                candidates = np.flatnonzero(shapely.contains(g, points) & center_land)
                exception = True
            if not len(candidates):
                unresolved.append({"district_id": district_id, "reason": "no complete dry-land hex clear of district boundaries", "area": g.area})
                continue
        candidates = np.array([i for i in candidates if tuple(cells[i]) not in used], dtype=int)
        if not len(candidates):
            raise ValueError("All candidates reserved by another district: " + district_id)
        clearance = shapely.distance(hexes[candidates], g.boundary)
        centroid = np.array(g.representative_point().coords[0])
        centrality = np.linalg.norm(centers[candidates]-centroid, axis=1)
        scores = base_scores[candidates] + .35*np.minimum(clearance/(radius*4), 1) + .2*np.exp(-centrality/100)
        best = int(np.argmax(scores))
        chosen = int(candidates[best])
        reference = None
        reference_distance = None
        for ref in references.get(district_id, []):
            delta = np.linalg.norm(centers[candidates]-np.array(sites[ref["site_id"]]["point"]), axis=1)
            near = np.flatnonzero(delta <= radius*4)
            if len(near):
                # Closest suitable interior tile around the documented medieval center.
                local = int(near[np.argmax(scores[near] - delta[near]/radius*2)])
                if reference_distance is None or delta[local] < reference_distance:
                    chosen, best = int(candidates[local]), local
                    reference, reference_distance = ref, float(delta[local])
            else:
                rejected_references.append({"id": ref["id"], "reason": "no safe interior tile within four radii"})
        q, r = map(int, cells[chosen])
        used.add((q, r))
        record = governance["districts"].get(district_id, topology["extra_districts"].get(district_id, {}))
        name = record.get("name", district_id)
        method = "historical_reference" if reference else "terrain_estimate"
        basis = (reference["name"]+"を参考に郡内のタイルへ配置（推定）") if reference else "郡内の平坦地・低地の広がりと集落・港への近さから選定（推定）"
        records[district_id] = {
            "district_id": district_id, "name": name+" 郡奉行所", "cell": [q, r],
            "point": centers[chosen].tolist(), "lonlat": list(lonlat(*centers[chosen])),
            "method": method, "historically_confirmed_office": False, "basis": basis,
            "reference": reference, "reference_distance_world": reference_distance,
            "elevation_m": round(float(elevations[chosen]), 1), "slope_degrees": round(float(slopes[chosen]), 2),
            "nearby_flat_land_fraction": round(float(flats[chosen]), 4), "suitability_score": round(float(scores[best]), 4),
            "candidate_count": len(candidates), "border_clearance_world": round(float(clearance[best]), 4) if not exception else 0,
            "boundary_exception": exception,
        }
    hashes = {path: sha(path) for path in [GEOMETRY, SOURCES, "assets/map/elevation/elevation_m.png", "scripts/map/hex_grid.gd",
              "data/derived/land_masks/land_mask_8192.png", "data/base/japan_land_manifest.json", "data/base/japan_land.geojson",
              "data/derived/hydrography/water_registry.json", "data/derived/governance/governance_1546.json",
              "data/derived/scenarios/district_connectivity_1546.json", "data/derived/detail_map/hex_coverage.json"]}
    report = {"district_count": len(ids), "placed_count": len(records), "historical_reference_count": sum(r["method"] == "historical_reference" for r in records.values()),
              "terrain_estimate_count": sum(r["method"] == "terrain_estimate" for r in records.values()),
              "boundary_exceptions": [k for k, r in records.items() if r["boundary_exception"]], "unresolved": unresolved,
              "omitted_by_request": sources.get("omit_districts", {}),
              "rejected_references": rejected_references, "source_hashes": hashes}
    write(OUTPUT, {"schema_version": 1, "radius": radius, "scenario_year": 1546, "policy": sources["policy"], "records": records, "report": report})
    write(REPORT, report)
    print(json.dumps({k: v for k, v in report.items() if k != "source_hashes"}, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
