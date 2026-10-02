"""Translate sourced assessment inputs to a reproducible mean-15 game scale.

Master assessments remain the historical research inputs. This policy is applied
once during every roster rebuild, before totals and documentation are generated.
Only unrecorded and participation-inferred scores receive seeded imputation or
mean calibration. Documented outcome scores are never randomized for balance.
"""
from __future__ import annotations

import collections
import copy
import hashlib
import json
import math
import statistics
from pathlib import Path
from statistics import NormalDist

ROOT = Path(__file__).resolve().parents[2]
KEYS = ("command", "tactics", "strategy", "politics", "trust")
LABELS = dict(zip(KEYS, ("統率", "武勇", "知略", "政治", "人望")))
# Weak hints from recorded work in related domains, never a proxy for popularity,
# family status, scenario role, or another person's achievements.
RELATED = {"command": ("tactics",), "tactics": ("command",),
           "strategy": ("politics",), "politics": ("strategy",), "trust": ()}


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def round_score(value):
    return math.floor(value + 0.5)


def evidence_value(value, anchors):
    for (x0, y0), (x1, y1) in zip(anchors, anchors[1:]):
        if x0 <= value <= x1:
            return round_score(y0 + (value - x0) * (y1 - y0) / (x1 - x0))
    raise ValueError(f"Score outside the historical scale: {value}")


def fixed_quantile(seed, officer_id, key):
    digest = hashlib.sha256(f"{seed}:{officer_id}:{key}".encode("utf-8")).digest()
    return (int.from_bytes(digest[:8], "big") + 0.5) / (2**64)


def imputed_value(spec, shift):
    low, high = spec["bounds"]
    distribution = NormalDist(spec["center"] + shift, spec["sd"])
    # Truncate before drawing: clipping would create spikes at the bounds.
    left = distribution.cdf(low - 0.5)
    right = distribution.cdf(high + 0.5)
    value = distribution.inv_cdf(left + spec["quantile"] * (right - left))
    return min(high, max(low, round_score(value)))


def infer_basis(assessment, key):
    basis = assessment.get("score_basis", {}).get(key)
    if basis:
        return basis
    return ("no_record" if assessment.get("score_confidence", {}).get(key) == "limited_evidence"
            else "historical_editorial")


def apply_policy(records, policy=None, reviews=None):
    policy = policy or read(ROOT / "data/master/officers/score_policy_mean15.json")
    reviews = reviews or read(ROOT / "data/master/officers/major_failure_reviews.json")
    ids = {r["external_id"] for r in records}
    if len(ids) != len(records):
        raise ValueError("Duplicate officer IDs")
    unknown_reviews = set(reviews["officers"]) - ids
    if unknown_reviews:
        raise ValueError(f"Failure review has unknown officer IDs: {unknown_reviews}")
    work = {}
    before = {r["external_id"]: copy.deepcopy(r["assessment"]) for r in records}
    for r in records:
        q = r["external_id"]
        old = before[q]
        if old.get("score_policy") == policy["id"]:
            raise ValueError("Reassessment requires historical inputs, not already calibrated output")
        review = reviews["officers"].get(q)
        major_failure = bool(review and review["status"] == "major_unrecovered_failure")
        if major_failure and not (review.get("personal_responsibility") and
                                  review.get("recovery_review") and review.get("source_refs")):
            raise ValueError(f"Incomplete major failure review: {q}")
        specs = {}
        for key in KEYS:
            value = old["scores"][key]
            basis = infer_basis(old, key)
            spec = {"old_score": value, "basis": basis, "value": value, "kind": "historical_evidence"}
            if value is None:
                spec["kind"] = "unrated"
            elif major_failure:
                spec.update(kind="major_unrecovered_failure", value=min(9, max(3, evidence_value(value, policy["evidence_scale_anchors"]))))
                if basis == "no_record":
                    spec.update(center=6, sd=1.5, bounds=policy["major_unrecovered_failure_bounds"],
                                quantile=fixed_quantile(policy["seed"], q, key))
                    spec["value"] = imputed_value(spec, 0)
            elif basis in ("no_record", "participation_standard"):
                prior = policy["unrecorded" if basis == "no_record" else "participation"]
                center = prior.get("center", 15)
                related = []
                if basis == "no_record":
                    for other in RELATED[key]:
                        other_basis = infer_basis(old, other)
                        other_score = old["scores"].get(other)
                        if other_basis in ("achievement", "mixed", "historical_editorial") and other_score is not None:
                            related.append({"ability": other, "reason": old["score_reasons"][other],
                                            "score": evidence_value(other_score, policy["evidence_scale_anchors"])})
                    if related:
                        limit = prior["related_adjustment_limit"]
                        delta = (statistics.mean(v["score"] for v in related) - 15) * prior["related_evidence_weight"]
                        center += min(limit, max(-limit, delta))
                else:
                    center += (value - prior["old_anchor"]) * prior["responsibility_step"]
                spec.update(kind="imputed" if basis == "no_record" else "participation_inferred",
                            center=center, sd=prior["sd"], bounds=prior["bounds"], related_evidence=related,
                            quantile=fixed_quantile(policy["seed"], q, key))
            else:
                spec["value"] = evidence_value(value, policy["evidence_scale_anchors"])
            specs[key] = spec
        work[q] = specs

    calibration = {}
    for key in KEYS:
        fixed = [specs[key]["value"] for specs in work.values()
                 if specs[key]["kind"] not in ("imputed", "participation_inferred", "unrated")]
        estimated = [specs[key] for specs in work.values()
                     if specs[key]["kind"] in ("imputed", "participation_inferred")]
        n = len(fixed) + len(estimated)
        target_sum = policy["target_mean"] * n
        low, high = -policy["calibration_shift_limit"], policy["calibration_shift_limit"]
        candidates = [low, high, 0.0]
        # Integer-valued, monotone objective; no rerolling and no individual swaps.
        for _ in range(45):
            middle = (low + high) / 2
            candidates.append(middle)
            total = sum(fixed) + sum(imputed_value(s, middle) for s in estimated)
            if total < target_sum:
                low = middle
            else:
                high = middle
        shift = min(candidates, key=lambda x: (abs(sum(fixed) + sum(imputed_value(s, x) for s in estimated) - target_sum), abs(x)))
        for spec in estimated:
            spec["value"] = imputed_value(spec, shift)
            spec["calibration_shift"] = shift
        calibration[key] = {"shift": round(shift, 8), "fixed_count": len(fixed), "estimated_count": len(estimated)}

    for r in records:
        q = r["external_id"]
        old = before[q]
        a = copy.deepcopy(old)
        review = reviews["officers"].get(q)
        a["score_basis"] = {key: work[q][key]["basis"] for key in KEYS}
        a["score_confidence"] = dict(old.get("score_confidence", {}))
        a["score_provenance"] = {}
        for key, spec in work[q].items():
            a["scores"][key] = spec["value"]
            provenance = {k: v for k, v in spec.items() if k not in ("value", "quantile")}
            provenance["historical_reason"] = old["score_reasons"].get(key, "未評価")
            if "center" in provenance:
                provenance["center"] = round(provenance["center"], 4)
                provenance["seed_key"] = f"{policy['seed']}:{q}:{key}"
            a["score_provenance"][key] = provenance
            if spec["kind"] == "imputed":
                a["score_confidence"][key] = "limited_evidence"
                a["score_reasons"][key] = f"成否材料なし：{provenance['historical_reason']}。中心{spec['center']:.2f}・標準偏差{spec['sd']}のゲーム用固定補完。"
            elif spec["kind"] == "participation_inferred":
                a["score_confidence"][key] = "limited_evidence"
                a["score_reasons"][key] = f"参加実績：{provenance['historical_reason']}。参加だけで高評価にせず、役割・責任に応じた中心{spec['center']:.2f}の遂行推定。"
            elif spec["kind"] == "major_unrecovered_failure":
                a["score_basis"][key] = "major_unrecovered_failure"
                a["score_reasons"][key] = f"重大な失態・挽回なしによる全能力の低評価：{review['personal_responsibility']}。従来の項目別根拠：{provenance['historical_reason']}"
            elif spec["kind"] == "historical_evidence":
                a["score_reasons"][key] = f"{provenance['historical_reason']}（15点中心の共通評価尺度で再評価）"
        a["score_policy"] = policy["id"]
        a["score_method"] = "生涯評価・1〜30点・1点刻み。功績・失敗は共通尺度で評価。成否材料なしは中心15前後・標準偏差3の固定補完、参加実績は責任別の遂行推定。各能力の平均目標15、補完中心の校正は±2以内。"
        a["caveat"] = "能力値はゲーム用の編集評価。史料の記載と固定補完を区別し、項目別の根拠・補完条件を保存。資料不足は低能力を意味しない。重大な失態・挽回なしの全能力低下はゲーム上のルールであり、史実上の全能力の測定ではない。生涯能力は開始時の出仕資格を意味しない。"
        if review:
            a["major_failure_review"] = copy.deepcopy(review)
            a["source_refs"] = list(dict.fromkeys(a["source_refs"] + review["source_refs"]))
        r["assessment"] = a
        values = list(a["scores"].values())
        r["total_ability"] = sum(values) if all(v is not None for v in values) else None

    dimensions = []
    for key in (*KEYS, "total"):
        values = [r["total_ability"] if key == "total" else r["assessment"]["scores"][key] for r in records]
        values = [v for v in values if v is not None]
        original = [(sum(a["scores"].values()) if all(v is not None for v in a["scores"].values()) else None)
                    if key == "total" else a["scores"][key] for a in before.values()]
        original = [v for v in original if v is not None]
        counts = collections.Counter(values)
        dimensions.append({"key": key, "label": "総合" if key == "total" else LABELS[key],
                           "n": len(values), "mean": statistics.mean(values), "median": statistics.median(values),
                           "sd": statistics.pstdev(values), "minimum": min(values), "maximum": max(values),
                           "before_mean": statistics.mean(original), "before_at12": original.count(12),
                           "at12": counts[12], "at60": counts[60], "mode": counts.most_common(1)[0][0],
                           "mode_percent": 100 * counts.most_common(1)[0][1] / len(values),
                           "bins": [{"value": v, "count": counts[v], "percent": 100 * counts[v] / len(values)}
                                    for v in range(min(values), max(values) + 1)]})
    return {"policy_id": policy["id"], "population": len(records), "calibration": calibration,
            "dimensions": dimensions,
            "major_unrecovered_failure_ids": sorted(q for q, a in work.items() if any(s["kind"] == "major_unrecovered_failure" for s in a.values())),
            "historical_inputs": "data/master/officers/assessments.json",
            "raw_assessments_unchanged": True}
