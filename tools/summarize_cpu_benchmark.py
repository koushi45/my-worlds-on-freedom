"""Summarize the real-time CPU benchmark without conflating nested phase timings."""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    data = json.loads(args.path.read_text(encoding="utf-8"))
    groups = defaultdict(list)
    for row in data["results"]:
        groups[(row["fps_limit"], row["speed"])].append(row)
    print("| FPS上限 | 倍率 | 回数 | 実進行平均（日/秒） | 最小～最大 | フレームp95平均(ms) | CPU最大(ms) |")
    print("| --- | --- | --- | --- | --- | --- | --- |")
    for (fps, speed), rows in groups.items():
        rates = [r["days_per_second"] for r in rows]
        print(f"| {fps} | {speed} | {len(rows)} | {mean(rates):.3f} | "
              f"{min(rates):.3f}～{max(rates):.3f} | "
              f"{mean(r['frame_p95_ms'] for r in rows):.2f} | "
              f"{max(r['maximum_cpu_frame_ms'] for r in rows):.2f} |")


if __name__ == "__main__":
    main()
