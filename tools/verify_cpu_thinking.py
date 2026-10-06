"""Run CPU/clock/save regressions with the real Windows renderer."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "qa" / "cpu-thinking-checks"
TESTS = [
    "game_clock", "minimize_resume", "army_route_search", "cpu_scheduler", "day_barrier",
    "cpu_controller", "cpu_simulation", "army_campaign", "army_automation",
    "army_merge", "occupation", "diplomacy", "start_session", "technology_orders",
    "technology_tree", "commerce_technology",
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for name in TESTS:
        command = ["godot_console", "--path", str(ROOT), "--script",
                   f"tests/base_map/godot/test_{name}.gd"]
        if name in {"game_clock", "army_route_search"}:
            command.insert(1, "--headless")
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=240)
        output = result.stdout.decode("utf-8", errors="replace")
        (OUT / f"{name}.log").write_text(output, encoding="utf-8")
        passed = result.returncode == 0 and "SCRIPT ERROR" not in output and "FAIL:" not in output
        rows.append({"test": name, "passed": passed, "exit_code": result.returncode,
                     "engine_error_lines": [line for line in output.splitlines()
                                            if line.startswith(("ERROR:", "WARNING:"))]})
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
    (OUT / "results.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0 if all(row["passed"] for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
