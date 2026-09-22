"""Export the complete officer registry as a one-row-per-officer CSV file."""

from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / "data" / "derived" / "officers" / "officers_1546.json"
DEFAULT_OUTPUT = ROOT / "data" / "derived" / "officers" / "officers_1546.csv"

METADATA_COLUMNS = [
    "registry.schema_version",
    "registry.scenario_id",
    "registry.start_year",
    "registry.map_reference_year",
    "registry.assessment_basis",
    "registry.completeness",
    "record_number",
]

# Keep the columns most useful in Excel near the left edge. Every remaining
# scalar field is appended in stable alphabetical order.
PRIMARY_COLUMNS = [
    "id",
    "external_id",
    "display_name",
    "aliases",
    "birth_display",
    "birth_year_range",
    "birth_year_estimated",
    "birth_year_basis",
    "death_display",
    "death_year_range",
    "death_year_estimated",
    "death_year_basis",
    "age_range_at_start",
    "estimated_lifespan_years",
    "temporal_status",
    "temporal_note",
    "life_stage",
    "start_present",
    "start_service_status",
    "start_affiliation",
    "start_role",
    "start_district_id",
    "notable_registration",
    "identity_confidence",
    "lineage.display_name",
    "lineage.birth_family_display",
    "lineage.family_at_1546_display",
    "affiliation_1546.house_id",
    "affiliation_1546.house_display",
    "affiliation_1546.role",
    "affiliation_1546.district_key",
    "affiliation_1546.district_display",
    "affiliation_1546.can_serve_at_start",
    "affiliation_1546.availability",
    "assessment.cohort",
    "assessment.selection_rank",
    "assessment.scores.command",
    "assessment.scores.tactics",
    "assessment.scores.strategy",
    "assessment.scores.politics",
    "assessment.scores.trust",
    "total_ability",
    "assessment.score_reasons.command",
    "assessment.score_reasons.tactics",
    "assessment.score_reasons.strategy",
    "assessment.score_reasons.politics",
    "assessment.score_reasons.trust",
    "relationships.father",
    "relationships.mother",
    "relationships.children",
    "identity_sources",
]


def encode_value(value: Any) -> Any:
    """Return a CSV-safe scalar while preserving arrays as lossless JSON."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (list, dict)):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return value


def flatten(record: dict[str, Any], prefix: str = "") -> dict[str, Any]:
    """Flatten dictionaries; arrays remain complete JSON values in one cell."""
    result: dict[str, Any] = {}
    for key, value in record.items():
        path = f"{prefix}.{key}" if prefix else key
        if isinstance(value, dict):
            result.update(flatten(value, path))
        else:
            result[path] = encode_value(value)
    return result


def build_rows(registry: dict[str, Any]) -> tuple[list[str], list[dict[str, Any]]]:
    officers = registry.get("officers")
    if not isinstance(officers, list):
        raise ValueError("officers must be an array")
    expected = registry.get("stats", {}).get("roster_count")
    if expected is not None and len(officers) != expected:
        raise ValueError(f"roster count mismatch: {len(officers)} != {expected}")

    ids = [officer.get("id") for officer in officers]
    if any(not isinstance(officer_id, str) or not officer_id for officer_id in ids):
        raise ValueError("every officer must have a non-empty string ID")
    if len(set(ids)) != len(ids):
        raise ValueError("officer IDs must be unique")

    flattened = [flatten(officer) for officer in officers]
    all_columns = set().union(*(row.keys() for row in flattened))
    ordered_primary = [column for column in PRIMARY_COLUMNS if column in all_columns]
    remaining = sorted(all_columns - set(ordered_primary))
    columns = METADATA_COLUMNS + ordered_primary + remaining

    metadata = {
        "registry.schema_version": registry.get("schema_version"),
        "registry.scenario_id": registry.get("scenario_id"),
        "registry.start_year": registry.get("start_year"),
        "registry.map_reference_year": registry.get("map_reference_year"),
        "registry.assessment_basis": registry.get("assessment_basis"),
        "registry.completeness": registry.get("completeness"),
    }
    rows: list[dict[str, Any]] = []
    for index, values in enumerate(flattened, start=1):
        row = metadata | {"record_number": index} | values
        rows.append(row)
    return columns, rows


def export_csv(source: Path, destination: Path) -> dict[str, Any]:
    registry = json.loads(source.read_text(encoding="utf-8"))
    columns, rows = build_rows(registry)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    try:
        with temporary.open("w", encoding="utf-8-sig", newline="") as stream:
            writer = csv.DictWriter(
                stream,
                fieldnames=columns,
                extrasaction="raise",
                lineterminator="\n",
            )
            writer.writeheader()
            writer.writerows(rows)
        os.replace(temporary, destination)
    finally:
        if temporary.exists():
            temporary.unlink()

    def report_path(path: Path) -> str:
        try:
            return path.relative_to(ROOT).as_posix()
        except ValueError:
            return str(path)

    return {
        "source": report_path(source),
        "output": report_path(destination),
        "encoding": "UTF-8 with BOM",
        "rows": len(rows),
        "columns": len(columns),
        "first_id": rows[0]["id"] if rows else None,
        "last_id": rows[-1]["id"] if rows else None,
        "bytes": destination.stat().st_size,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    report = export_csv(args.input.resolve(), args.output.resolve())
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
