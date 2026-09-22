"""Build stable house theme colours while separating neighbouring rulers."""
from __future__ import annotations

import colorsys
import json
from collections import Counter, defaultdict
from pathlib import Path

import shapely
from shapely.geometry import Polygon
from shapely.strtree import STRtree


ROOT = Path(__file__).resolve().parents[1]
GOVERNANCE = ROOT / "data/derived/governance/governance_1546.json"
TOPOLOGY = ROOT / "data/derived/scenarios/district_connectivity_1546.json"
GEOMETRY = ROOT / "data/derived/scenarios/independent_districts_1546.json"
DESTINATION = ROOT / "data/derived/governance/house_theme_colors_1546.json"

# Medium-value colours remain legible as a translucent band over both plains and mountains.
PALETTE = [
    "#d4473b", "#337ac8", "#3b985b", "#d0a625", "#8758c4", "#df7830",
    "#299493", "#c44e88", "#7fa23b", "#5364c1", "#c58a27", "#318cb1",
    "#c6576b", "#8b9338", "#7252aa", "#d46643", "#2d896e", "#3c86d6",
    "#b79a30", "#97558e", "#4f8948", "#b4583e", "#435e8e", "#b67632",
]

# Only especially clear associations are locked. The remainder are graph-coloured.
LOCKED = {
    "takeda": ("#cf3632", "user_direction", None),
    "date": (
        "#292d38",
        "museum_object_association",
        "https://www.city.sendai.jp/museum/shuzohin/shuzohin/shuzohin-05.html",
    ),
}

# These are editorial starting preferences, not claims that a single historical flag colour existed.
PREFERRED = {
    "oda_nobuhide": "#34394a", "imagawa": "#8758c4", "hojo": "#d0a625",
    "nagao": "#337ac8", "uesugi_yamanouchi": "#5364c1", "mori": "#318cb1",
    "ouchi": "#97558e", "amago": "#df7830", "otomo": "#299493",
    "shimazu": "#7252aa", "chosokabe": "#8758c4", "asakura": "#3b985b",
    "azai": "#3c86d6", "miyoshi": "#c44e88", "matsudaira": "#2d896e",
    "saito": "#7fa23b", "satake": "#8b9338", "ryuzoji": "#b4583e",
}


def geometry_for(record: dict):
    parts = []
    for polygon in record["polygons"]:
        parts.append(Polygon(polygon[0], polygon[1:]))
    return shapely.make_valid(shapely.union_all(parts))


def rgb(colour: str) -> tuple[float, float, float]:
    return tuple(int(colour[i : i + 2], 16) / 255.0 for i in (1, 3, 5))


def colour_distance(left: str, right: str) -> float:
    lh, ls, lv = colorsys.rgb_to_hsv(*rgb(left))
    rh, rs, rv = colorsys.rgb_to_hsv(*rgb(right))
    hue = min(abs(lh - rh), 1.0 - abs(lh - rh)) * 2.0
    return (hue * hue + (ls - rs) ** 2 * 0.20 + (lv - rv) ** 2 * 0.15) ** 0.5


def main() -> None:
    governance = json.loads(GOVERNANCE.read_text(encoding="utf-8"))
    topology = json.loads(TOPOLOGY.read_text(encoding="utf-8"))
    geometry = json.loads(GEOMETRY.read_text(encoding="utf-8"))["regions"]
    extra = topology["extra_districts"]

    district_house = {}
    shapes = []
    district_ids = []
    for district_id, record in geometry.items():
        if district_id in governance["districts"]:
            house_id = governance["districts"][district_id]["house_id"]
        elif district_id in extra:
            source = extra[district_id]["source_id"]
            house_id = extra[district_id].get(
                "house_id", governance["districts"][source]["house_id"]
            )
        else:
            raise KeyError(f"No ownership record for {district_id}")
        district_house[district_id] = house_id
        district_ids.append(district_id)
        shapes.append(geometry_for(record))

    adjacency: dict[str, set[str]] = defaultdict(set)
    tree = STRtree(shapes)
    for left_index, left in enumerate(shapes):
        # A small tolerance catches borders whose independently simplified vertices differ slightly.
        for right_index in tree.query(left.buffer(0.75)):
            right_index = int(right_index)
            if right_index <= left_index or left.distance(shapes[right_index]) > 0.75:
                continue
            left_house = district_house[district_ids[left_index]]
            right_house = district_house[district_ids[right_index]]
            if left_house == right_house:
                continue
            adjacency[left_house].add(right_house)
            adjacency[right_house].add(left_house)

    houses = governance["houses"]
    assigned = dict(PREFERRED)
    assigned.update({house_id: entry[0] for house_id, entry in LOCKED.items()})
    use_count = Counter(assigned.values())
    order = sorted(houses, key=lambda house_id: (-len(adjacency[house_id]), house_id))
    while len(assigned) < len(houses):
        candidates = [h for h in order if h not in assigned]
        house_id = max(
            candidates,
            key=lambda h: (sum(n in assigned for n in adjacency[h]), len(adjacency[h]), h),
        )
        neighbouring_colours = [assigned[n] for n in adjacency[house_id] if n in assigned]
        preferred = PREFERRED.get(house_id)

        def score(colour: str) -> tuple:
            exact_conflicts = sum(colour == neighbour for neighbour in neighbouring_colours)
            minimum_distance = min(
                (colour_distance(colour, neighbour) for neighbour in neighbouring_colours),
                default=1.0,
            )
            preference = 0.18 if colour == preferred else 0.0
            return (-exact_conflicts, minimum_distance + preference, -use_count[colour])

        chosen = max(PALETTE, key=score)
        assigned[house_id] = chosen
        use_count[chosen] += 1

    themes = {}
    for house_id in sorted(houses):
        locked = LOCKED.get(house_id)
        themes[house_id] = {
            "name": houses[house_id]["display_name"],
            "color": assigned[house_id],
            "basis": locked[1] if locked else (
                "editorial_preference_and_adjacency" if house_id in PREFERRED else "adjacency_palette"
            ),
        }
        if locked and locked[2]:
            themes[house_id]["source_url"] = locked[2]

    adjacent_pairs = sorted([a, b] for a in adjacency for b in adjacency[a] if a < b)
    conflicts = [pair for pair in adjacent_pairs if assigned[pair[0]] == assigned[pair[1]]]
    adjacent_distances = [colour_distance(assigned[a], assigned[b]) for a, b in adjacent_pairs]
    output = {
        "schema_version": 1,
        "scenario_id": governance["scenario_id"],
        "policy": "明確な家色を優先し、その他は隣接勢力間の識別性を最大化する編集配色。",
        "palette": PALETTE,
        "stats": {
            "houses": len(houses),
            "active_houses": len(set(district_house.values())),
            "adjacent_house_pairs": sum(map(len, adjacency.values())) // 2,
            "same_colour_adjacent_pairs": len(conflicts),
            "minimum_adjacent_colour_distance": round(min(adjacent_distances), 4),
            "near_colour_adjacent_pairs": sum(distance < 0.12 for distance in adjacent_distances),
        },
        "same_colour_adjacent_pairs": conflicts,
        "themes": themes,
    }
    DESTINATION.write_text(
        json.dumps(output, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(
        f"House themes: {len(themes)} houses, {output['stats']['adjacent_house_pairs']} "
        f"adjacent pairs, {len(conflicts)} same-colour conflicts"
    )


if __name__ == "__main__":
    main()
