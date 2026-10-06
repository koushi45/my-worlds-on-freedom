"""Measure 16x playback and combat optimizations in the Windows export."""
from __future__ import annotations

import json
import argparse
from pathlib import Path
import verify_speed_release

from verify_speed_release import OUT, run, EXIT_DIAGNOSTICS


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-dir", type=Path, default=verify_speed_release.EXE.parent)
    args = parser.parse_args()
    verify_speed_release.EXE = args.build_dir.resolve() / "MyWorldsOnFreedom.exe"
    OUT.mkdir(parents=True, exist_ok=True)
    checks = {"ordinary_startup_pass": run("speed16_startup", ["--quit-after", "120"]),
              "benchmarks": [], "exit_resource_diagnostics": EXIT_DIAGNOSTICS}
    cases = [("normal", "normal", 0, 16, 60), ("war", "war", 12, 16, 60),
             ("war8", "war", 12, 8, 60), ("stress100", "war", 100, 8, 15)]
    for label, scenario, armies, speed, seconds in cases:
        name = f"speed16_packaged_{label}"
        path = OUT / f"{name}.json"
        previous = path.stat().st_mtime_ns if path.exists() else None
        print(f"Starting {name}", flush=True)
        valid = run(name, ["--", "--cpu-speed-check", f"--seconds={seconds}", "--repeats=1",
                           "--fps=60,30", f"--speeds={speed}",
                           "--profile=on" if armies == 100 else "--profile=off",
                           f"--army-count={armies}", f"--scenario={scenario}",
                           f"--output={path.as_posix()}"])
        fresh = path.exists() and path.stat().st_mtime_ns != previous
        data = json.loads(path.read_text(encoding="utf-8")) if fresh else {}
        rows = data.get("results", [])
        valid = valid and len(rows) == 2 and all(r.get("save_valid") and r.get("indexes_valid") and r.get("speed") == speed for r in rows)
        checks["benchmarks"].append({"scenario": label, "speed": speed, "functional_pass": valid,
                                     "required_speed_goal": label == "war8",
                                     "speed_goal_pass": bool(rows) and all(r["days_per_second"] >= speed - 0.05 for r in rows),
                                     "rates": [r["days_per_second"] for r in rows], "initial_armies": data.get("initial_armies")})
        (OUT / "speed16_windows_checks.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(checks["benchmarks"][-1], flush=True)
        if not valid:
            return 1
    return 0 if checks["ordinary_startup_pass"] and all(not c["required_speed_goal"] or c["speed_goal_pass"] for c in checks["benchmarks"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
