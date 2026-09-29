"""Apply the requested Kanzaki union after coastline alignment, without losing land."""
import json
from pathlib import Path
from shapely.geometry import Point
from shapely.strtree import STRtree
from curate_requested_district_layout import geometry, parts, pack

ROOT = Path(__file__).resolve().parents[1]
TARGET = "hizen/merged-3051a6f57adaff58"
SOURCES = ("chikuzen/unresolved-42cfaa8c657745ea", "chikugo/unresolved-42cfaa8c657745ea")
MERGES = {**dict.fromkeys(SOURCES, TARGET), "sagami/unresolved-42cfaa8c657745ea": "kai/unresolved-b48d2f62146c8828"}

MERGES["musashi/unresolved-42cfaa8c657745ea"] = "kai/unresolved-cd2be55f925d6adb"

def read(path):
    return json.loads((ROOT/path).read_text(encoding="utf8"))

def write(path, data):
    (ROOT/path).write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf8")

def merge(data):
    regions = data["regions"]
    for source, target in MERGES.items():
        combined = geometry(regions[target])
        if source in regions:
            combined = combined.union(geometry(regions.pop(source)))
        assert combined.is_valid
        regions[target].update(polygons=[pack(p) for p in parts(combined)], bounds=list(combined.bounds))
    topology = data["connectivity"]
    topology["requested_district_merges"] = MERGES
    topology["active_district_ids"] = sorted(regions)
    topology["retired_district_ids"] = sorted(set(topology.get("retired_district_ids", [])) | set(MERGES))
    topology["stats"]["after_requested_merges"] = len(regions)
    ids = sorted(regions)
    shapes = [geometry(regions[k]) for k in ids]
    tree = STRtree(shapes)
    sites = read("data/derived/governance/governance_1546.json")["sites"]
    topology["site_district_candidates"] = {
        key: [ids[int(i)] for i in tree.query(Point(site["point"])) if shapes[int(i)].covers(Point(site["point"]))]
        for key, site in sites.items()
    }
    return data

def refresh_related(data):
    catalog_path = "data/derived/scenarios/house_selection_1546.json"
    catalog = read(catalog_path)
    catalog["district_ids"] = sorted(data["regions"])
    for key in ("district_defaults", "district_origins"):
        for source in MERGES:
            catalog.get(key, {}).pop(source, None)
    write(catalog_path, catalog)
    write("data/derived/scenarios/district_review_highlights.json", {
        "color": "#ff0000", "opacity": 0.5, "district_ids": [],
        "note": "ユーザー指定：確認用の赤塗りをすべて解除する。"
    })

if __name__ == "__main__":
    path = "data/derived/scenarios/independent_districts_1546.json"
    data = merge(read(path))
    write(path, data)
    write("data/derived/scenarios/district_connectivity_1546.json", data["connectivity"])
    refresh_related(data)
    print(f"Merged into Kanzaki; {len(data['regions'])} active districts")
