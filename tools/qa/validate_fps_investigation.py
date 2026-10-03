"""Verify the exported pack, normal startup, and the redraw experiment captures."""
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "builds/performance_800"
BUILD = ROOT / "builds/windows-latest"


def main():
    checks = []
    commands = [
        ("normal_startup", [str(BUILD / "MyWorldsOnFreedom.exe"), "--quit-after", "120"]),
        *[(Path(script).stem, [shutil.which("godot_console"), "--headless", "--main-pack",
                              str(BUILD / "MyWorldsOnFreedom.pck"), "--script", str(ROOT / script)])
          for script in ["tests/base_map/godot/test_map_optimization.gd",
                         "tests/base_map/godot/test_terrain_chunks.gd"]],
    ]
    for label, command in commands:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=180)
        log = result.stdout + result.stderr
        (OUT / f"fps_final_{label}.log").write_text(log, encoding="utf-8")
        errors = [line for line in log.splitlines() if line.startswith(("SCRIPT ERROR:", "ERROR:", "FAIL:"))]
        checks.append({"label": label, "command": command, "exit_code": result.returncode, "errors": errors})
    report = {"export": json.loads((BUILD / "export_report.json").read_text(encoding="utf-8")),
              "checks": checks}
    (OUT / "fps_final_validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    visual = []
    for label in ["kinki", "fuji", "kanto"]:
        first = OUT / f"fps_baseline_r4_{label}.png"
        second = OUT / f"fps_single_marker_redraw_r4_{label}.png"
        a = np.asarray(Image.open(first).convert("RGB"), dtype=np.int16)
        b = np.asarray(Image.open(second).convert("RGB"), dtype=np.int16)
        difference = np.abs(a - b)
        visual.append({"label": label, "baseline": str(first), "experiment": str(second),
                       "mean_absolute_rgb_difference": float(difference.mean()),
                       "changed_pixels": int(np.any(difference != 0, axis=2).sum()),
                       "pixels_over_32": int(np.any(difference > 32, axis=2).sum()),
                       "total_pixels": int(a.shape[0] * a.shape[1])})
    (OUT / "fps_single_marker_visual.json").write_text(json.dumps(visual, indent=2), encoding="utf-8")
    print(json.dumps({"checks": checks, "visual": visual}, ensure_ascii=False, indent=2))
    assert report["export"]["exit_code"] == 0 and not report["export"]["error_lines"]
    assert all(c["exit_code"] == 0 and not c["errors"] for c in checks)


if __name__ == "__main__":
    main()
