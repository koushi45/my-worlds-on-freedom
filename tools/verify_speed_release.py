"""Check the exported Windows game, then benchmark its packaged implementation."""
from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "qa"
EXE = ROOT / "builds" / "windows-latest" / "MyWorldsOnFreedom.exe"
PCK = EXE.with_suffix(".pck")
EXIT_DIAGNOSTICS: dict[str, list[str]] = {}


def run(name: str, arguments: list[str]) -> bool:
    # Official export templates restrict --main-pack overrides. The executable
    # loads the same-name PCK beside it automatically.
    command = [str(EXE), "--log-file", str(OUT / f"{name}.log"), *arguments]
    process = subprocess.run(command, cwd=EXE.parent, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=480)
    path = OUT / f"{name}.log"
    if not path.exists():
        path.write_bytes(process.stdout)
    log = path.read_text(encoding="utf-8", errors="replace")
    console = process.stdout.decode("utf-8", errors="replace")
    if console and console not in log:
        log += "\n" + console
        path.write_text(log, encoding="utf-8")
    # Existing Godot resource cleanup diagnostics do not describe a failed
    # assertion. Keep them in the report; every other ERROR remains fatal.
    errors = [line.strip() for line in log.splitlines() if "ERROR:" in line]
    cleanup = [line for line in errors if re.fullmatch(r"ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.", line)]
    EXIT_DIAGNOSTICS[name] = cleanup
    return process.returncode == 0 and "SCRIPT ERROR" not in log and "FAIL:" not in log and not any(line not in cleanup for line in errors)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    result = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "My Worlds on Freedom" / "qa_cpu_release" / "result.json"
    previous_mtime = result.stat().st_mtime_ns if result.exists() else None
    print("Starting packaged save/load check", flush=True)
    smoke = run("speed_8_days_windows_release", ["--", "--cpu-release-check"])
    fresh = result.exists() and result.stat().st_mtime_ns != previous_mtime
    report = json.loads(result.read_text(encoding="utf-8")) if fresh else {}
    smoke = smoke and bool(report.get("ok")) and Path(report.get("executable", "")).resolve() == EXE.resolve()
    (OUT / "speed_8_days_windows_release_result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Packaged save/load: {smoke}", flush=True)
    startup = run("speed_8_days_windows_startup", ["--quit-after", "120"])
    checks = {"save_load_pass": smoke, "ordinary_startup_pass": startup, "benchmarks": [], "exit_resource_diagnostics": EXIT_DIAGNOSTICS}
    if not smoke or not startup:
        (OUT / "speed_8_days_windows_checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
        return 1
    cases = [("normal", "normal", 12, 60, 3, True), ("war", "war", 12, 60, 3, True),
             ("stress50", "war", 50, 15, 1, False), ("stress100", "war", 100, 15, 1, False)]
    for label, scenario, army_count, seconds, repeats, required_goal in cases:
        name = f"speed_8_days_packaged_{label}"
        print(f"Starting {name}", flush=True)
        path = OUT / f"{name}.json"
        previous_mtime = path.stat().st_mtime_ns if path.exists() else None
        arguments = ["--", "--cpu-speed-check",
                     f"--seconds={seconds}", f"--repeats={repeats}", "--fps=60,30", "--speeds=8",
                     "--profile=off" if required_goal else "--profile=on", f"--army-count={army_count}",
                     f"--scenario={scenario}", f"--output={path.as_posix()}"]
        valid = run(name, arguments)
        fresh = path.exists() and path.stat().st_mtime_ns != previous_mtime
        data = json.loads(path.read_text(encoding="utf-8")) if fresh else {}
        rows = data.get("results", [])
        valid = valid and len(rows) == repeats * 2 and all(row.get("save_valid") and row.get("indexes_valid") for row in rows)
        goal = bool(rows) and all(row["days_per_second"] >= 7.95 for row in rows)
        checks["benchmarks"].append({"scenario": label, "required_goal": required_goal, "initial_armies":data.get("initial_armies"),
                                     "functional_pass": valid, "speed_goal_pass": goal,
                                     "minimum_days_per_second": min((row["days_per_second"] for row in rows), default=0)})
        (OUT / "speed_8_days_windows_checks.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{name}: functional={valid}, goal={goal}, minimum={checks['benchmarks'][-1]['minimum_days_per_second']:.4f}", flush=True)
        if not valid:
            return 1
    return 0 if all(not check["required_goal"] or check["speed_goal_pass"] for check in checks["benchmarks"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
