"""Apply the user-approved removal and merge decisions to the district layout."""
import json
from pathlib import Path

from shapely.geometry import Point, Polygon
from shapely.ops import unary_union


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "data/work/districts/coast_alignment/user_layout_curation.json"

REMOVED = {
    "honshu-area-01/unresolved-42cfaa8c657745ea": "下北郡周辺（仮）",
    "honshu-area-05/unresolved-42cfaa8c657745ea": "気仙郡周辺（仮）",
    "kazusa/unresolved-42cfaa8c657745ea": "武射郡周辺（仮）",
    "honshu-area-30/unresolved-42cfaa8c657745ea": "長狭郡周辺（仮）",
    "izu/unresolved-42cfaa8c657745ea": "加茂郡周辺（仮）",
    "suruga/unresolved-42cfaa8c657745ea": "安倍郡周辺（仮）",
    "osumi/unresolved-42cfaa8c657745ea": "南大隅郡周辺（仮）",
    "etchu/unresolved-42cfaa8c657745ea": "礪波郡周辺（仮）",
    "noto/unresolved-42cfaa8c657745ea": "鳳至郡周辺（仮）",
    "kaga/unresolved-42cfaa8c657745ea": "河北郡周辺（仮）",
    "hoki/unresolved-42cfaa8c657745ea": "河村郡周辺（仮）",
    "iwami/unresolved-42cfaa8c657745ea": "邑智郡周辺（仮）",
    "bitchu/unresolved-42cfaa8c657745ea": "哲多郡周辺（仮）",
    "bingo/unresolved-42cfaa8c657745ea": "御調郡周辺（仮）",
    "nagato/unresolved-42cfaa8c657745ea": "豊浦郡周辺（仮）",
}

MERGED = {
    "izumi/unresolved-42cfaa8c657745ea": (
        "izumi/candidate-district-candidate-g04001", "日根郡周辺（仮）", "大鳥郡"
    ),
    "suo/unresolved-42cfaa8c657745ea": (
        "suo/candidate-district-candidate-g55004", "都濃郡周辺（仮）", "熊毛郡"
    ),
    "hizen/unresolved-42cfaa8c657745ea": (
        "hizen/candidate-district-candidate-g67009", "西彼杵郡周辺（仮）", "北高来郡"
    ),
    "tosa/unresolved-42cfaa8c657745ea": (
        "tosa/candidate-district-candidate-g62007", "幡多郡周辺（仮）", "幡多郡"
    ),
    "mikawa/unresolved-42cfaa8c657745ea": (
        "totomi/candidate-district-candidate-g11003", "渥美郡周辺（仮）", "敷智郡"
    ),
    "awa_shikoku/unresolved-42cfaa8c657745ea": (
        "tosa/candidate-district-candidate-g62001", "海部郡周辺（仮）", "安芸郡"
    ),
}


def geometry(record):
    return unary_union([Polygon(polygon[0], polygon[1:]) for polygon in record["polygons"]])


def parts(value):
    if value.geom_type == "Polygon":
        return [value]
    return [part for child in value.geoms for part in parts(child)]


def pack(polygon):
    return [list(map(list, polygon.exterior.coords))] + [
        list(map(list, ring.coords)) for ring in polygon.interiors
    ]


def curate(data):
    regions = data["regions"]
    missing = sorted((set(REMOVED) | set(MERGED)) - set(regions))
    if missing:
        raise KeyError(f"requested district IDs missing: {missing}")
    operations = []

    for source, display_name in REMOVED.items():
        area = geometry(regions[source]).area
        del regions[source]
        operations.append(
            {"kind": "remove", "source": source, "source_name": display_name, "area_world2": area}
        )

    for source, (target, source_name, target_name) in MERGED.items():
        if target not in regions:
            raise KeyError(f"merge target missing: {target}")
        source_geometry = geometry(regions[source])
        merged_geometry = unary_union([geometry(regions[target]), source_geometry])
        if not merged_geometry.is_valid or merged_geometry.is_empty:
            raise ValueError(f"invalid requested merge: {source} -> {target}")
        record = regions[target]
        record["polygons"] = [pack(polygon) for polygon in parts(merged_geometry)]
        record["bounds"] = list(merged_geometry.bounds)
        if not merged_geometry.contains(Point(record["label"])):
            record["label"] = list(merged_geometry.representative_point().coords)[0]
        del regions[source]
        operations.append(
            {
                "kind": "merge",
                "source": source,
                "source_name": source_name,
                "target": target,
                "target_name": target_name,
                "area_world2": source_geometry.area,
            }
        )

    data["user_layout_curation"] = {
        "status": "applied",
        "operations": operations,
        "pending": {},
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(
        json.dumps(data["user_layout_curation"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf8",
    )
    return data
