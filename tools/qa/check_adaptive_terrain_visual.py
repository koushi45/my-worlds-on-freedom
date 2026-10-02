"""Compare frozen full-frame adaptive terrain renders against uniform geometry."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[2]
folder = root / "builds/performance_800/adaptive_visual"
cases = json.loads((folder / "report.json").read_text(encoding="utf-8"))
assert len(cases) == 13, "Missing visual poses"
failed = False
for case in cases:
    index = case["index"]
    original = np.asarray(Image.open(folder / f"{index}_original.png").convert("RGB"), dtype=np.int16)
    reduced = np.asarray(Image.open(folder / f"{index}_reduced.png").convert("RGB"), dtype=np.int16)
    assert original.shape == reduced.shape
    delta = np.abs(original - reduced)
    case["mean_absolute_rgb_error_255"] = float(delta.mean())
    case["changed_pixel_percent"] = float((delta.max(axis=2) > 0).mean() * 100)
    case["over_32_pixel_percent"] = float((delta.max(axis=2) > 32).mean() * 100)
    case["pass"] = case["mean_absolute_rgb_error_255"] <= 1.0 and case["over_32_pixel_percent"] <= 0.5
    failed |= not case["pass"]
    print(index, "PASS" if case["pass"] else "FAIL", "mae", round(case["mean_absolute_rgb_error_255"], 5), "large_delta_percent", round(case["over_32_pixel_percent"], 5))
(folder / "metrics.json").write_text(json.dumps(cases, indent=2), encoding="utf-8")
raise SystemExit(1 if failed else 0)
