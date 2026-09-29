"""Adopt an exported hex-road network, omitting Kyushu/Shikoku and orphan roads."""

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import shapely
from pyproj import Transformer
from shapely.geometry import shape
from shapely.ops import transform


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data/derived/scenarios/hex_roads_1546.json"
QA_REPORT = ROOT / "builds/qa/official_hex_roads_report.json"
ISLANDS = {
    "kyushu": "jp-land-df6efb10e39e5964",
    "shikoku": "jp-land-4528338d54c851ca",
}
NEIGHBORS = ((1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="exported hex_roads.json")
    args = parser.parse_args()
    raw = args.source.read_bytes()
    document = json.loads(raw.decode("utf-8-sig"))
    assert document["schema_version"] == 1 and document["kind"] == "hex_road_network"
    assert document["coordinates"] == "pointy_top_axial_q_r"
    assert document["connection_rule"] == "all_six_occupied_neighbors"
    radius = float(document["hex_radius"])
    assert radius == 6.0
    cells = {tuple(row) for row in document["cells"]}
    assert len(cells) == len(document["cells"])

    manifest = json.loads((ROOT / "data/base/japan_land_manifest.json").read_text(encoding="utf-8"))
    transform_spec = manifest["game_transform"]
    projection = Transformer.from_crs("EPSG:4326", transform_spec["projection"], always_xy=True)
    bound_x, bound_y, _, _ = transform_spec["projected_scope_bounds_m"]

    def world(lon: float, lat: float) -> tuple[float, float]:
        x, y = projection.transform(lon, lat)
        scale = transform_spec["uniform_scale_px_per_m"]
        return (
            transform_spec["offset_x_px"] + (x - bound_x) * scale,
            transform_spec["offset_y_px"] + transform_spec["content_height_px"] - (y - bound_y) * scale,
        )

    land_features = json.loads((ROOT / "data/base/japan_land.geojson").read_text(encoding="utf-8"))["features"]
    by_id = {feature["properties"]["feature_id"]: feature for feature in land_features}
    ordered = np.asarray(document["cells"], dtype=np.int32)
    centers = np.column_stack((
        math.sqrt(3) * radius * (ordered[:, 0] + ordered[:, 1] * 0.5),
        1.5 * radius * ordered[:, 1],
    ))
    angles = math.pi / 6 + np.arange(6) * math.pi / 3
    corners = np.column_stack((np.cos(angles), np.sin(angles))) * radius
    hexes = shapely.polygons(centers[:, None, :] + corners)
    island_removed: set[tuple[int, int]] = set()
    island_counts = {}
    for name, feature_id in ISLANDS.items():
        feature = by_id[feature_id]
        geographic = shape(feature["geometry"])
        assert geographic.area > 1.0  # Main island, not a small offshore island.
        island = transform(world, geographic)
        hits = np.flatnonzero(shapely.intersects(island, hexes))
        island_counts[name] = len(hits)
        island_removed.update(map(tuple, ordered[hits]))

    remaining = cells - island_removed
    exclusions = {frozenset(map(tuple, edge)) for edge in document.get("excluded_edges", [])}
    assert len(exclusions) == len(document.get("excluded_edges", []))
    offices = json.loads((ROOT / "data/derived/scenarios/district_offices_1546.json").read_text(encoding="utf-8"))["records"]
    office_cells = {tuple(record["cell"]) for record in offices.values()}
    pending = set(remaining)
    retained: set[tuple[int, int]] = set()
    orphan_sizes = []
    retained_components = 0
    while pending:
        seed = pending.pop()
        component = {seed}
        stack = [seed]
        while stack:
            q, r = stack.pop()
            for dq, dr in NEIGHBORS:
                neighbor = (q + dq, r + dr)
                if neighbor in pending and frozenset(((q, r), neighbor)) not in exclusions:
                    pending.remove(neighbor)
                    component.add(neighbor)
                    stack.append(neighbor)
        if component & office_cells:
            retained.update(component)
            retained_components += 1
        else:
            orphan_sizes.append(len(component))

    removed = cells - retained
    result = dict(document)
    result["cells"] = [row for row in document["cells"] if tuple(row) in retained]
    # Retain dormant exclusions for future edits, except those touching deleted tiles.
    result["excluded_edges"] = [
        edge for edge in document.get("excluded_edges", [])
        if all(tuple(endpoint) not in removed for endpoint in edge)
    ]
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = {
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "source_cells": len(cells),
        "kyushu_cells": island_counts["kyushu"],
        "shikoku_cells": island_counts["shikoku"],
        "island_cells_removed": len(island_removed),
        "orphan_components_removed": len(orphan_sizes),
        "orphan_cells_removed": sum(orphan_sizes),
        "official_cells": len(retained),
        "retained_components": retained_components,
        "office_cells_preserved_outside_islands": len(remaining & office_cells & retained),
        "excluded_edges": len(result["excluded_edges"]),
    }
    assert report["source_cells"] == report["island_cells_removed"] + report["orphan_cells_removed"] + report["official_cells"]
    QA_REPORT.parent.mkdir(parents=True, exist_ok=True)
    QA_REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
