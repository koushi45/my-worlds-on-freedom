from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "builds" / "windows-latest"
EXE = OUTPUT_DIR / "MyWorldsOnFreedom.exe"
PCK = OUTPUT_DIR / "MyWorldsOnFreedom.pck"
LOG = OUTPUT_DIR / "export.log"
REPORT = OUTPUT_DIR / "export_report.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    global OUTPUT_DIR, EXE, PCK, LOG, REPORT
    parser = argparse.ArgumentParser(description="Export and record the Windows release.")
    parser.add_argument("--godot", default="godot_console", help="Godot console executable or absolute path")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR,
                        help="Export directory (use a fresh directory when a running executable is locked)")
    args = parser.parse_args()
    OUTPUT_DIR = args.output_dir.resolve()
    EXE = OUTPUT_DIR / "MyWorldsOnFreedom.exe"
    PCK = EXE.with_suffix(".pck")
    LOG = OUTPUT_DIR / "export.log"
    REPORT = OUTPUT_DIR / "export_report.json"
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    command = [
        args.godot,
        "--headless",
        "--path",
        str(ROOT),
        "--export-release",
        "Windows",
        str(EXE),
    ]
    result = subprocess.run(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    LOG.write_text(result.stdout, encoding="utf-8")
    artifacts = {}
    for path in (EXE, PCK):
        if path.exists():
            stat = path.stat()
            artifacts[path.name] = {
                "bytes": stat.st_size,
                "modified_utc": datetime.fromtimestamp(
                    stat.st_mtime, timezone.utc
                ).isoformat(),
                "sha256": sha256(path),
            }
    lower_log = result.stdout.lower()
    report = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "command": command,
        "exit_code": result.returncode,
        "artifacts": artifacts,
        "log": str(LOG).replace("\\", "/"),
        "error_lines": [
            line
            for line in result.stdout.splitlines()
            if "error" in line.lower() or "failed" in line.lower()
        ],
        "resource_shortage_detected": any(
            marker in lower_log
            for marker in ("out of memory", "resource exhausted", "cannot allocate")
        ),
    }
    REPORT.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if result.returncode != 0:
        return result.returncode
    return 0 if len(artifacts) == 2 and not report["error_lines"] and not report["resource_shortage_detected"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
