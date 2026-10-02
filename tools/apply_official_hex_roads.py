"""Validate and adopt an exported hex-road network as the official road data."""

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data/derived/scenarios/hex_roads_1546.json"
QA_REPORT = ROOT / "builds/qa/official_hex_roads_report.json"
COVERAGE = ROOT / "data/derived/detail_map/hex_coverage.json"
TERRAIN = ROOT / "data/derived/detail_map/hex_terrain.json"


def cell_from_json(value: object) -> tuple[int, int]:
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(f"Invalid road cell: {value!r}")
    if any(isinstance(n, bool) or not isinstance(n, (int, float))
           or not -2000 <= n <= 2000 or int(n) != n for n in value):
        raise ValueError(f"Invalid road coordinates: {value!r}")
    return int(value[0]), int(value[1])


def validate(document: object) -> dict[str, int]:
    if not isinstance(document, dict):
        raise ValueError("Road data must be a JSON object")
    expected = {
        "schema_version": 1,
        "kind": "hex_road_network",
        "hex_radius": 6.0,
        "coordinates": "pointy_top_axial_q_r",
        "connection_rule": "all_six_occupied_neighbors",
    }
    for key, value in expected.items():
        if document.get(key) != value:
            raise ValueError(f"Unexpected road data {key}: {document.get(key)!r}")

    coverage = json.loads(COVERAGE.read_text(encoding="utf-8"))
    terrain = json.loads(TERRAIN.read_text(encoding="utf-8"))
    if coverage["radius"] != expected["hex_radius"] or terrain["radius"] != expected["hex_radius"]:
        raise ValueError("Road, coverage and terrain hex radii do not match")
    terrain_by_cell = {}
    for row, qs in coverage["rows"].items():
        codes = terrain["rows"][row]
        if len(qs) != len(codes):
            raise ValueError(f"Coverage and terrain differ in row {row}")
        terrain_by_cell.update(((q, int(row)), code) for q, code in zip(qs, codes))

    rows = document.get("cells")
    if not isinstance(rows, list) or len(rows) > len(terrain_by_cell):
        raise ValueError("Invalid road cell array")
    cells = set()
    terrain_counts = {name: 0 for name in ("plain", "mountain", "river")}
    codes_to_names = {str(code): name for name, code in terrain["codes"].items()}
    for row in rows:
        cell = cell_from_json(row)
        if cell in cells:
            raise ValueError(f"Duplicate road cell: {cell}")
        code = terrain_by_cell.get(cell)
        if code is None:
            raise ValueError(f"Road cell outside the map: {cell}")
        name = codes_to_names[code]
        if name not in terrain_counts:
            raise ValueError(f"Road cell on impassable terrain: {cell} ({name})")
        cells.add(cell)
        terrain_counts[name] += 1

    edge_rows = document.get("excluded_edges", [])
    if not isinstance(edge_rows, list) or len(edge_rows) > len(terrain_by_cell) * 3:
        raise ValueError("Invalid excluded edge array")
    edges = set()
    dormant_edges = 0
    for row in edge_rows:
        if not isinstance(row, list) or len(row) != 2:
            raise ValueError(f"Invalid excluded edge: {row!r}")
        a, b = (cell_from_json(endpoint) for endpoint in row)
        if a not in terrain_by_cell or b not in terrain_by_cell:
            raise ValueError(f"Excluded edge outside the map: {row!r}")
        dq, dr = b[0] - a[0], b[1] - a[1]
        if (dq, dr) not in ((1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1)):
            raise ValueError(f"Excluded edge is not between adjacent hexes: {row!r}")
        edge = frozenset((a, b))
        if edge in edges:
            raise ValueError(f"Duplicate excluded edge: {row!r}")
        edges.add(edge)
        if a not in cells or b not in cells:
            dormant_edges += 1

    return {"road_cells": len(cells), "excluded_edges": len(edges),
            "dormant_excluded_edges": dormant_edges, **terrain_counts}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="exported hex_roads.json")
    args = parser.parse_args()
    raw = args.source.read_bytes()
    document = json.loads(raw.decode("utf-8-sig"))
    counts = validate(document)
    previous = json.loads(OUTPUT.read_text(encoding="utf-8")) if OUTPUT.exists() else None
    report = {
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "previous_road_cells": len(previous["cells"]) if previous else 0,
        "previous_excluded_edges": len(previous.get("excluded_edges", [])) if previous else 0,
        **counts,
    }
    OUTPUT.write_bytes(raw)
    QA_REPORT.parent.mkdir(parents=True, exist_ok=True)
    QA_REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
