"""Verify completeness, references and conserved totals for 1546 population."""

from __future__ import annotations

import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(relative: str):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> None:
    connectivity = load("data/derived/scenarios/district_connectivity_1546.json")
    house_selection = load("data/derived/scenarios/house_selection_1546.json")
    geometry = load("data/derived/scenarios/independent_districts_1546.json")
    sources = load("data/work/population/sources.json")["sources"]
    observations = load("data/work/population/observations.json")["observations"]
    crosswalks = load("data/work/population/district_crosswalk.json")["crosswalks"]
    assumptions = load("data/work/population/assumptions_1546.json")["assumptions"]
    controls = load("data/work/population/controls_1546.json")
    population = load("data/derived/population/district_population_1546.json")
    manifest = load("data/derived/population/manifest_1546.json")
    active = set(connectivity["active_district_ids"])
    require(active == set(house_selection["district_ids"]), "house-selection ID mismatch")
    require(active == set(geometry["regions"]), "geometry ID mismatch")
    require(active == set(population["districts"]), "population ID mismatch")
    require(len(active) == len(connectivity["active_district_ids"]), "duplicate active ID")

    assumption_ids = {row["assumption_id"] for row in assumptions.values()}
    crosswalk_by_district = Counter(row["district_id"] for row in crosswalks.values())
    require(set(crosswalk_by_district) == active, "crosswalk coverage mismatch")
    require(all(value == 1 for value in crosswalk_by_district.values()), "duplicate district crosswalk")
    weights_by_group = defaultdict(float)
    case_group_sums = {case: defaultdict(int) for case in ["low", "adopted", "high"]}
    evidence = Counter()
    for district_id, row in population["districts"].items():
        values = [row["population_low"], row["population_estimate"], row["population_high"]]
        require(all(isinstance(value, int) and not isinstance(value, bool) and value >= 0 for value in values), f"invalid population: {district_id}")
        require(values[0] <= values[1] <= values[2], f"invalid range: {district_id}")
        require(row["scenario_year"] == 1546, f"wrong scenario year: {district_id}")
        require(row["adoption_status"] in ["adopted", "provisional"], f"status: {district_id}")
        require(row["evidence_grade"] in ["A", "B", "C", "D"], f"evidence: {district_id}")
        require(all(source_id in sources for source_id in row["source_ids"]), f"source ref: {district_id}")
        require(all(observation_id in observations for observation_id in row["observation_ids"]), f"observation ref: {district_id}")
        require(all(assumption_id in assumption_ids for assumption_id in row["assumption_ids"]), f"assumption ref: {district_id}")
        require(all(crosswalk_id in crosswalks for crosswalk_id in row["crosswalk_ids"]), f"crosswalk ref: {district_id}")
        group = row["allocation_group_ids"][0]
        case_group_sums["low"][group] += values[0]
        case_group_sums["adopted"][group] += values[1]
        case_group_sums["high"][group] += values[2]
        evidence[row["evidence_grade"]] += 1
    for crosswalk in crosswalks.values():
        require(0 <= crosswalk["allocation_weight"] <= 1, "invalid crosswalk weight")
        weights_by_group[crosswalk["allocation_group_id"]] += crosswalk["allocation_weight"]
        require(all(source_id in sources for source_id in crosswalk["source_ids"]), "crosswalk source ref")
    for group, total in weights_by_group.items():
        require(math.isclose(total, 1.0, abs_tol=1e-9), f"group weights do not sum to 1: {group}={total}")
    for case, key in [("low", "population_low"), ("adopted", "population_estimate"), ("high", "population_high")]:
        total = sum(row[key] for row in population["districts"].values())
        require(total == controls["national_cases"][case]["population_1546"], f"national total: {case}")
        require(total == population["case_totals"][case], f"reported total: {case}")
        require(dict(case_group_sums[case]) == population["allocation_group_case_totals"][case], f"group conservation: {case}")
    output_path = ROOT / "data/derived/population/district_population_1546.json"
    require(manifest["output_sha256"]["data/derived/population/district_population_1546.json"] == sha256(output_path), "output hash mismatch")
    require(manifest["district_count"] == len(active), "manifest count")
    require(manifest["evidence_grade_counts"] == {grade: evidence[grade] for grade in ["A", "B", "C", "D"]}, "manifest evidence counts")
    print(f"Population verification passed: {len(active)} districts, adopted total {population['case_totals']['adopted']:,}")


if __name__ == "__main__":
    main()
