"""Collect final near-overlay test and release-startup evidence."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "builds/performance_800"
checks = []
for name, expected in [("near_overlay_test", "NEAR_OVERLAY_PROBE PASS"),
                       ("near_overlay_regression", "MAP_OPTIMIZATION PASS"),
                       ("near_overlay_startup", "OpenGL API")]:
    log = (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace")
    errors = [line for line in log.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:", "FAIL:"))]
    checks.append({"check": name, "expected_found": expected in log, "errors": errors})
startup = json.loads((OUT / "near_overlay_startup.json").read_text())
report = {"export": json.loads((ROOT / "builds/windows-latest/export_report.json").read_text(encoding="utf-8")),
          "startup_exit_code": startup["exit_code"], "checks": checks,
          "initial_cleanup_warning": "The first headless near-overlay test passed its assertions but emitted an exit resource warning. The repeated and final tests were clean; see near_overlay_test_initial.log."}
(OUT / "near_overlay_validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
assert report["export"]["exit_code"] == 0 and startup["exit_code"] == 0
assert all(c["expected_found"] and not c["errors"] for c in checks)
print("NEAR OVERLAY VALIDATION: PASS")
