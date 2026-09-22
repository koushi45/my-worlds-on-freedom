"""Verify immutable-master coastline alignment v2 outputs."""

from __future__ import annotations

import json

import geopandas as gpd
import pyogrio
from shapely.geometry import Point

import build_coastline_alignment_v2 as align

OUTPUT = align.QA_DIR / "validation_report.json"


def require(value, message):
    if not value: raise AssertionError(message)


def main():
    report=json.loads(align.REPORT_PATH.read_text(encoding="utf-8"))
    layers=set(pyogrio.list_layers(align.OUTPUT_GPKG)[:,0])
    require(layers=={"source_coast_samples","target_coast_controls_8192","source_coast_initial_8192","source_coast_aligned_8192"},"alignment layers differ")
    source=gpd.read_file(align.OUTPUT_GPKG,layer="source_coast_samples")
    target=gpd.read_file(align.OUTPUT_GPKG,layer="target_coast_controls_8192")
    aligned=gpd.read_file(align.OUTPUT_GPKG,layer="source_coast_aligned_8192")
    coasts=gpd.read_file(align.p2.COAST_GPKG,layer="coastline_8192")
    coast_lookup=dict(zip(coasts["coastline_id"],coasts.geometry))
    require(list(source["control_id"])==list(target["control_id"]),"source/target control identity differs")
    accepted=target[target["accepted"]==1]
    require(len(accepted)>0,"no accepted coastline controls")
    require(accepted.geometry.notna().all(),"accepted control has no target point")
    require(all(point.distance(coast_lookup[row.target_coastline_id]) <= 1e-8 for row,point in zip(accepted.itertuples(index=False),accepted.geometry)),"target control is not on referenced canonical coastline")
    def maximum_sample_distance(row):
        coast = coast_lookup[row.target_coastline_id]
        samples = [Point(x, y) for x, y in row.geometry.coords]
        samples.extend(row.geometry.interpolate(fraction, normalized=True) for fraction in (0.25, 0.5, 0.75))
        return max(point.distance(coast) for point in samples)
    require(all(maximum_sample_distance(row) <= 1e-8 for row in aligned.itertuples(index=False)),"aligned segment leaves referenced canonical coastline")
    require(report["method"]["transparent_rgb_ignored"] is True,"transparent RGB noise was not excluded")
    require(report["method"]["canonical_geometry_modified"] is False,"canonical geometry changed")
    require(report["method"]["political_boundaries_transformed"] is False,"unreviewed controls changed political boundaries")
    require(report["residuals"]["after_projection_game_px"]["max"]==0.0,"post-alignment residual is not zero")
    require(align.sha256(align.p2.MASTER_LAND)==report["input_hashes"]["japan_land_master"],"land master hash changed")
    require(align.sha256(align.p2.COAST_GPKG)==report["input_hashes"]["coastline_master"],"coast master hash changed")
    qa=[align.QA_DIR/f"{scope}_{view}.png" for scope in ("national","kyushu") for view in ("before","after","comparison")]
    require(all(path.exists() for path in qa),"QA overlay missing")
    result={"status":"pass_pending_correspondence_review","checks":{"alpha_only_source_extraction":"pass","canonical_master_immutable":"pass","identified_coastline_references":"pass","aligned_points_on_referenced_coast":"pass","political_boundaries_untouched":"pass","national_and_kyushu_qa":"pass"},"counts":report["counts"]}
    OUTPUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False))


if __name__=="__main__":main()
