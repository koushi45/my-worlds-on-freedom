"""Verify complete native PNG sets, transparency and distinct label artwork."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    manifest = json.loads((ROOT / "assets/ui/unique_icons/manifest.json").read_text(encoding="utf-8"))
    failures: list[str] = []
    fingerprints: dict[tuple[int, bytes], str] = {}
    count = 0
    for entry in manifest["entries"]:
        for side in manifest["sizes"]:
            paths = [ROOT / f"assets/ui/hud/compact/{entry['id']}_{side}.png"]
            if "district" in entry:
                paths.append(ROOT / f"assets/ui/district/{entry['district']}_{side}.png")
            for index, path in enumerate(paths):
                if not path.exists():
                    failures.append(f"Missing: {path.relative_to(ROOT)}")
                    continue
                with Image.open(path) as image:
                    if image.size != (side, side) or image.mode != "RGBA":
                        failures.append(f"Invalid size/mode: {path.name}")
                    alpha = image.getchannel("A")
                    if alpha.getextrema()[0] != 0 or not alpha.getbbox():
                        failures.append(f"Missing transparency/artwork: {path.name}")
                    if index == 0:
                        # Compare decoded pixels: PNG metadata cannot hide duplicate artwork.
                        key = (side, hashlib.sha256(image.tobytes()).digest())
                        previous = fingerprints.get(key)
                        if previous is not None:
                            failures.append(f"Shared image for different labels: {previous}, {entry['label']} ({side}px)")
                        fingerprints[key] = entry["label"]
                count += 1
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"PASS: {len(manifest['entries'])} distinct labels; {count} native transparent PNGs; no duplicate artwork")


if __name__ == "__main__":
    main()
