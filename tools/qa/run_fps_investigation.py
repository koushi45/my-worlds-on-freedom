"""Sequential release-build ablations; never run GPU samples concurrently."""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "builds/performance_800"
VARIANTS = {
    "baseline": [],
    "production_overlays": ["--production-overlays"],
    "terrain_low": ["--production-overlays","--terrain-load=0"],
    "terrain_medium": ["--production-overlays","--terrain-load=1"],
    "terrain_high": ["--production-overlays","--terrain-load=2"],
    "material_400": ["--material-tier=400"],
    "material_100": ["--material-tier=100"],
    "atlas_half": ["--atlas-scale=0.5"],
    "atlas_quarter": ["--atlas-scale=0.25"],
    "no_shadows": ["--no-shadows"],
    "simple_surface": ["--simple-surface"],
    "no_markers": ["--no-markers"],
    "no_marker_text": ["--no-marker-text"],
    "no_crests": ["--no-crests"],
    "no_hex_lines": ["--no-hex-lines"],
    "no_roads": ["--no-roads"],
    "no_occlusion": ["--no-occlusion"],
    "no_hex": ["--no-hex"],
    "no_borders": ["--no-borders"],
    "no_source": ["--no-source"],
    "freeze_near": ["--freeze-near"],
    "no_near": ["--no-near"],
    "cache_far": ["--cache-far"],
    "combined": ["--cache-far", "--no-hex", "--freeze-near"],
    "fast_diagnostic": ["--no-markers", "--no-hex", "--atlas-scale=0.5"],
    "single_marker_redraw": ["--single-marker-redraw"],
    "markers_fast": ["--no-marker-text", "--no-occlusion"],
    "near_512": ["--marker-radius=512", "--single-marker-redraw"],
    "near_320": ["--marker-radius=320", "--single-marker-redraw"],
    "hex_noaa": ["--hex-noaa", "--single-marker-redraw"],
    "hex_mesh": ["--hex-mesh", "--single-marker-redraw"],
    "temporal_100": ["--occlusion-interval=100", "--single-marker-redraw"],
    "near_mesh": ["--marker-radius=320", "--hex-mesh", "--single-marker-redraw"],
    "near_temporal_mesh": ["--marker-radius=320", "--hex-mesh", "--occlusion-interval=100", "--single-marker-redraw"],
    "temporal_mesh": ["--hex-mesh", "--occlusion-interval=100", "--single-marker-redraw"],
    "near512_mesh": ["--marker-radius=512", "--hex-mesh", "--single-marker-redraw"],
    "near512_temporal_mesh": ["--marker-radius=512", "--hex-mesh", "--occlusion-interval=100", "--single-marker-redraw"],
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", nargs="+", default=list(VARIANTS))
    parser.add_argument("--round", default="r1")
    parser.add_argument("--frames", type=int, default=120)
    args = parser.parse_args()
    for variant in args.variants:
        label = f"fps_{variant}_{args.round}"
        command = ["python", "tools/qa/run_gpu_check.py",
                   "tests/base_map/godot/benchmark_map_800.gd", label,
                   "--release", f"--stage={label}", "--fps-limit=0",
                   f"--frames={args.frames}", *VARIANTS[variant]]
        print("START", label, flush=True)
        subprocess.run(command, cwd=ROOT, check=True)
        result = json.loads((OUT / f"{label}.json").read_text(encoding="utf-8"))
        print("RESULT", label, [(r["label"], r["mode"], round(r["fps"], 1),
                                  round(r["p95_ms"], 1)) for r in result["results"]], flush=True)


if __name__ == "__main__":
    main()
