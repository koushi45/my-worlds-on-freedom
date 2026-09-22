"""Keep only explicitly approved island districts, using base-map coastlines exactly."""
import copy
import json
from pathlib import Path

from shapely.geometry import Point, Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree


ROOT = Path(__file__).resolve().parents[1]

CURATED_ISLANDS = (
    {
        "id": "hizen/island-tsushima",
        "name": "対馬",
        "province": "対馬国",
        "source_id": "hizen/candidate-district-candidate-g67015",
        "house_id": "so",
        "coastline_ids": ("jp-coast-c48b7a8a750c53fa",),
    },
    {
        "id": "hizen/island-hirado",
        "name": "平戸島",
        "province": "肥前国",
        "source_id": "hizen/candidate-district-candidate-g67015",
        "house_id": "matsuura",
        "coastline_ids": ("jp-coast-1f241e9ef00c51d0",),
    },
    {
        "id": "iyo/island-murakami-suigun",
        "name": "村上水軍領地",
        "province": "伊予国",
        "source_id": "iyo/candidate-district-candidate-g61005",
        "house_id": "murakami_noshima",
        "coastline_ids": (
            "jp-coast-7827b9f3fcc75d56",
            "jp-coast-5c7d0c23da8653b5",
            "jp-coast-896e652f5b5657d4",
        ),
    },
    {
        "id": "awa_shikoku/island-awaji",
        "name": "淡路島",
        "province": "淡路国",
        "source_id": "awa_shikoku/candidate-district-candidate-g59007",
        "house_id": "miyoshi",
        "coastline_ids": ("jp-coast-5a8606adb3c65cba",),
    },
)


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf8"))


def pack_polygon(polygon):
    return [list(polygon.exterior.coords)] + [list(ring.coords) for ring in polygon.interiors]


def curate(data):
    land = read("data/derived/land_masks/land_master_8192.json")
    coastlines = land["coastlines"]
    topology = data["connectivity"]
    removed_ids = set(topology["extra_districts"])
    for district_id in removed_ids:
        data["regions"].pop(district_id, None)

    extras = {}
    for item in CURATED_ISLANDS:
        polygons = []
        for coastline_id in item["coastline_ids"]:
            polygon = Polygon(coastlines[coastline_id]["points"])
            assert polygon.is_valid and not polygon.is_empty and not polygon.interiors, coastline_id
            polygons.append(polygon)
        geometry = unary_union(polygons)
        record = copy.deepcopy(data["regions"][item["source_id"]])
        record.update(
            polygons=[pack_polygon(polygon) for polygon in polygons],
            bounds=list(geometry.bounds),
            label=list(geometry.representative_point().coords)[0],
        )
        data["regions"][item["id"]] = record
        extras[item["id"]] = {
            "source_id": item["source_id"],
            "name": item["name"],
            "province": item["province"],
            "house_id": item["house_id"],
            "coastline_ids": list(item["coastline_ids"]),
            "coastline_only": True,
            "geometry_basis": "base_land_coastline_exact",
        }

    topology["extra_districts"] = extras
    topology["operations"] = [
        operation for operation in topology["operations"]
        if operation.get("target") not in removed_ids and operation.get("kind") != "island"
    ]
    active = sorted(data["regions"])
    topology["active_district_ids"] = active
    topology["retired_district_ids"] = sorted(
        set(topology.get("previous_layout_ids", [])) - set(active)
    )
    topology["policy"] = (
        "本州・九州・四国・北海道外の島郡は対馬・平戸島・村上水軍領地・淡路島のみ。"
        "形状はベース地図の海岸線と完全一致し、専用の郡境線を重ねない。"
    )
    topology["stats"].update(
        after_island_curation=len(active),
        island_districts=len(extras),
        removed_island_districts=len(removed_ids),
        multipart_after=sum(len(region["polygons"]) > 1 for region in data["regions"].values()),
    )

    keys = active
    geometries = [
        unary_union([Polygon(polygon[0], polygon[1:]) for polygon in data["regions"][key]["polygons"]])
        for key in keys
    ]
    tree = STRtree(geometries)
    sites = read("data/derived/governance/governance_1546.json")["sites"]
    topology["site_district_candidates"] = {
        site_id: sorted(
            keys[int(i)] for i in tree.query(Point(site["point"]))
            if geometries[int(i)].covers(Point(site["point"]))
        )
        for site_id, site in sites.items()
    }
    data["overlap_cleanup"]["after_districts"] = len(active)
    data["overlap_cleanup"]["removed_districts"] = len(topology["retired_district_ids"])
    return data


if __name__ == "__main__":
    path = ROOT / "data/derived/scenarios/independent_districts_1546.json"
    value = curate(json.loads(path.read_text(encoding="utf8")))
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf8")
    (path.parent / "district_connectivity_1546.json").write_text(
        json.dumps(value["connectivity"], ensure_ascii=False, separators=(",", ":")), encoding="utf8"
    )
    print(f"Island districts: {len(value['connectivity']['extra_districts'])}; total: {len(value['regions'])}")
