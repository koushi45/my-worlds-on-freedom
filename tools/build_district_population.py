"""Build deterministic 1546 game population estimates from the work ledgers."""

from __future__ import annotations

import hashlib
import json
import subprocess
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "data/work/population"
CONNECTIVITY = ROOT / "data/derived/scenarios/district_connectivity_1546.json"
HOUSE_SELECTION = ROOT / "data/derived/scenarios/house_selection_1546.json"
GEOMETRY = ROOT / "data/derived/scenarios/independent_districts_1546.json"
GOVERNANCE = ROOT / "data/derived/governance/governance_1546.json"
OUTPUT = ROOT / "data/derived/population/district_population_1546.json"
MANIFEST = ROOT / "data/derived/population/manifest_1546.json"
EXPECTED_HASHES = {
    CONNECTIVITY: "b182d185aa5019fa746ec33d66235dfc1df0412d8aa758a2194e2996294413db",
    HOUSE_SELECTION: "323081a11c517fdfa03fd1a58c6dfbe64f2a07e5ecdad22912e555b598eea116",
    GEOMETRY: "2e47ab9c62b5803b18632e26a771ba47a60fa748d828fa1d6750ed1f2a3a5a45",
}


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


def largest_remainder(total: int, weighted_ids: list[tuple[str, float]]) -> tuple[dict[str, int], dict[str, float]]:
    weight_sum = sum(weight for _, weight in weighted_ids)
    if total < 0 or weight_sum <= 0:
        raise ValueError("invalid allocation total or zero weights")
    raw = {key: total * weight / weight_sum for key, weight in weighted_ids}
    result = {key: int(value) for key, value in raw.items()}
    remainder = total - sum(result.values())
    order = sorted(raw, key=lambda key: (-(raw[key] - result[key]), key))
    for key in order[:remainder]:
        result[key] += 1
    return result, raw


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


def effective_group_kokudaka(controls: dict, active_groups: set[str]) -> dict[str, int]:
    explicit = controls["source_country_components"]
    koku = controls["country_kokudaka_1598"]
    analogue = controls["analogue_kokudaka"]
    result = {}
    for group in active_groups:
        members = explicit.get(group, [group])
        result[group] = sum(koku.get(member, 0) + analogue.get(member, 0) for member in members)
        if result[group] <= 0:
            raise ValueError(f"allocation group has no productive proxy: {group}")
    return result


def main() -> None:
    for path, expected in EXPECTED_HASHES.items():
        actual = sha256(path)
        if actual != expected:
            raise SystemExit(f"locked input changed: {path.relative_to(ROOT)} {actual}")
    connectivity = read_json(CONNECTIVITY)
    house_selection = read_json(HOUSE_SELECTION)
    geometry = read_json(GEOMETRY)
    governance = read_json(GOVERNANCE)
    sources = read_json(WORK / "sources.json")
    observations = read_json(WORK / "observations.json")
    crosswalk_data = read_json(WORK / "district_crosswalk.json")
    controls = read_json(WORK / "controls_1546.json")
    assumptions = read_json(WORK / "assumptions_1546.json")
    active_ids = connectivity["active_district_ids"]
    if set(active_ids) != set(house_selection["district_ids"]) or set(active_ids) != set(geometry["regions"]):
        raise SystemExit("scenario district ID sets differ")
    merges = connectivity.get("requested_district_merges", {})
    allocation_ids = sorted(set(active_ids) | set(merges))
    records = district_records(dict(connectivity, active_district_ids=allocation_ids), governance)
    crosswalk_by_district = {row["district_id"]: row for row in crosswalk_data["crosswalks"].values()}
    if set(crosswalk_by_district) != set(allocation_ids):
        raise SystemExit("crosswalk does not cover active districts exactly")

    districts_by_group = defaultdict(list)
    for district_id in allocation_ids:
        row = crosswalk_by_district[district_id]
        districts_by_group[row["allocation_group_id"]].append(district_id)
    group_koku = effective_group_kokudaka(controls, set(districts_by_group))
    cases = {}
    group_case_totals = {}
    raw_case_values = defaultdict(dict)
    for case, definition in controls["national_cases"].items():
        group_totals, _ = largest_remainder(
            definition["population_1546"], sorted(group_koku.items())
        )
        group_case_totals[case] = group_totals
        district_totals = {}
        for group, district_ids in districts_by_group.items():
            allocated, raw = largest_remainder(
                group_totals[group],
                [(district_id, crosswalk_by_district[district_id]["allocation_weight"]) for district_id in district_ids],
            )
            district_totals.update(allocated)
            for district_id, value in raw.items():
                raw_case_values[district_id][case] = value
        cases[case] = district_totals

    output_districts = {}
    all_source_ids = [
        "ipss_population_statistics_2026",
        "maddison_world_economy_2006",
        "keicho_kokudaka_transcription",
        "rekihaku_kyudaka_database",
        "honda_kyudaka_agrivillage_v2_01",
        "game_boundary_1546",
    ]
    for district_id in allocation_ids:
        crosswalk = crosswalk_by_district[district_id]
        observation_id = "obs_distribution_" + district_id.replace("/", "__")
        observation = observations["observations"][observation_id]
        fallback = observation["indicator"] == "geodesic_area_fallback"
        output_districts[district_id] = {
            "district_id": district_id,
            "name": records[district_id]["name"],
            "province": records[district_id]["province"],
            "scenario_year": 1546,
            "population_estimate": cases["adopted"][district_id],
            "population_low": cases["low"][district_id],
            "population_high": cases["high"][district_id],
            "population_low_raw": raw_case_values[district_id]["low"],
            "population_estimate_raw": raw_case_values[district_id]["adopted"],
            "population_high_raw": raw_case_values[district_id]["high"],
            "population_definition": "男女・子供・高齢者、農村・都市・港・寺社・武家を含む総居住人口",
            "method": "analogue_fallback" if fallback else "regional_allocation",
            "adoption_status": "provisional",
            "evidence_grade": "D" if fallback else "C",
            "temporal_confidence": {"grade": "low", "reason": "郡内配分指標が幕末期村落分布で、1546年との差が大きい。"},
            "boundary_confidence": {"grade": crosswalk["boundary_confidence"], "reason": "村落代表点を現行ゲーム境界へ空間対応。"},
            "source_ids": all_source_ids,
            "observation_ids": [observation_id],
            "assumption_ids": [
                "assumption_national_backcast_0018",
                "assumption_province_kokudaka_share",
                "assumption_district_village_points",
                "assumption_zero_koku_islands",
                "assumption_largest_remainder",
            ],
            "allocation_group_ids": [crosswalk["allocation_group_id"]],
            "crosswalk_ids": [crosswalk["crosswalk_id"]],
            "urban_population_included": "総人口に包含。都市人口を分離できないため別枠加算なし。",
            "notes": "史料と明示した仮定によるゲーム用推定。整数値は1人単位の史実精度を意味しない。",
            "review_status": "automatic_checks_passed",
            "model_version": assumptions["model_version"],
            "boundary_version": assumptions["boundary_version"],
        }

    # Preserve the locked regional estimates, then transfer the populations of
    # user-merged districts. Cross-province unions must not discard residents.
    for source, target in merges.items():
        old = output_districts.pop(source)
        recipient = output_districts[target]
        for field in ("population_low", "population_estimate", "population_high",
                      "population_low_raw", "population_estimate_raw", "population_high_raw"):
            recipient[field] += old[field]
        for field in ("source_ids", "observation_ids", "assumption_ids", "allocation_group_ids", "crosswalk_ids"):
            recipient[field] = sorted(set(recipient[field]) | set(old[field]))
        recipient.setdefault("merged_district_ids", []).append(source)
        recipient["method"] = "regional_allocation_then_requested_merge"

    output = {
        "schema_version": 1,
        "scenario_year": 1546,
        "model_version": assumptions["model_version"],
        "boundary_version": assumptions["boundary_version"],
        "population_definition": "total_resident_population",
        "case_totals": {case: sum(values.values()) for case, values in cases.items()},
        "allocation_group_case_totals": group_case_totals,
        "districts": output_districts,
    }
    write_json(OUTPUT, output)
    try:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        commit = "unknown"
    manifest = {
        "schema_version": 1,
        "scenario_year": 1546,
        "model_version": assumptions["model_version"],
        "git_commit_at_input_lock": commit,
        "retrieved_on": "2026-09-22",
        "active_district_ids": active_ids,
        "map_excluded_historical_regions": ["佐渡国", "隠岐国", "壱岐国"],
        "input_sha256": {
            str(path.relative_to(ROOT)).replace("\\", "/"): sha256(path)
            for path in [CONNECTIVITY, HOUSE_SELECTION, GEOMETRY, *sorted(WORK.glob("*.json"))]
        },
        "output_sha256": {str(OUTPUT.relative_to(ROOT)).replace("\\", "/"): sha256(OUTPUT)},
        "district_count": len(output_districts),
        "case_totals": output["case_totals"],
        "evidence_grade_counts": {
            grade: sum(row["evidence_grade"] == grade for row in output_districts.values())
            for grade in ["A", "B", "C", "D"]
        },
    }
    write_json(MANIFEST, manifest)
    print(f"Built {len(output_districts)} districts; adopted total={output['case_totals']['adopted']:,}")


if __name__ == "__main__":
    main()
