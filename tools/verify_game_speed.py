"""Sequential rendered speed checks; keep other games/builds stopped while running."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "qa"
CASES = [
    ("speed_8_days_final", ["--seconds=60", "--repeats=3", "--fps=60,30"], True),
    ("speed_8_days_war_final", ["--seconds=60", "--repeats=3", "--fps=60,30", "--scenario=war"], True),
    ("speed_8_days_profile_off", ["--seconds=20", "--repeats=1", "--fps=60,30", "--profile=off"], False),
    ("speed_other_multipliers", ["--seconds=10", "--repeats=1", "--fps=60", "--speeds=1,2,4", "--profile=off"], False),
    ("speed_50_armies", ["--seconds=15", "--repeats=1", "--fps=60,30", "--scenario=war", "--army-count=50"], False),
    ("speed_100_armies", ["--seconds=15", "--repeats=1", "--fps=60,30", "--scenario=war", "--army-count=100"], False),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    checks = []
    for name, options, required_goal in CASES:
        print(f"Starting {name}", flush=True)
        command = ["godot_console", "--path", str(ROOT), "--script",
                   "tests/base_map/godot/benchmark_cpu_thinking.gd", "--", "--speeds=8",
                   *options, f"--output=res://builds/qa/{name}.json"]
        # The last explicit speed selection wins; do not mask --speeds=1,2,4.
        if any(option.startswith("--speeds=") for option in options):
            command.remove("--speeds=8")
        result_path = OUT / f"{name}.json"
        previous_mtime = result_path.stat().st_mtime_ns if result_path.exists() else None
        with (OUT / f"{name}.log").open("w", encoding="utf-8") as log:
            process = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        output = (OUT / f"{name}.log").read_text(encoding="utf-8", errors="replace")
        fresh = result_path.exists() and result_path.stat().st_mtime_ns != previous_mtime
        data = json.loads(result_path.read_text(encoding="utf-8")) if fresh else {}
        rows = data.get("results", [])
        valid = process.returncode == 0 and "SCRIPT ERROR" not in output and "FAIL:" not in output
        valid = valid and bool(rows) and all(row.get("save_valid") and row.get("indexes_valid") for row in rows)
        if required_goal:
            valid = valid and len(rows) == 6
        goal = bool(rows) and all(row["days_per_second"] >= row["speed"] - 0.05 for row in rows)
        checks.append({"case": name, "command": command, "functional_pass": valid,
                       "required_goal": required_goal, "speed_goal_pass": goal,
                       "initial_armies": data.get("initial_armies"),
                       "minimum_days_per_second": min((row["days_per_second"] for row in rows), default=0),
                       "engine_error_lines": [line for line in output.splitlines() if line.startswith(("ERROR:", "WARNING:"))]})
        (OUT / "speed_8_days_checks.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{name}: functional={valid}, minimum={checks[-1]['minimum_days_per_second']:.4f}, goal={goal}", flush=True)
        if not valid:
            return 1
    return 0 if all(not row["required_goal"] or row["speed_goal_pass"] for row in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
