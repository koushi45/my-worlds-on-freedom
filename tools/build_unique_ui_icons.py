"""Bake generated artwork into native-size UI PNGs (production-time only)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "assets/ui/unique_icons"


def bake(icon_id: str, source: Path) -> None:
    manifest = json.loads((DIRECTORY / "manifest.json").read_text(encoding="utf-8"))
    entry = next(item for item in manifest["entries"] if item["id"] == icon_id)
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] != 0 or not alpha.getbbox():
        raise ValueError(f"{icon_id}: generated artwork needs a transparent background")
    image = image.crop(alpha.getbbox())
    sources = DIRECTORY / "sources"
    sources.mkdir(parents=True, exist_ok=True)
    image.save(sources / f"{icon_id}.png")
    for side in manifest["sizes"]:
        # Existing compact cells are 28px for a 64px transparent texture.
        compact_side = round(side * 0.375)
        compact = Image.new("RGBA", (side, side))
        art = image.copy()
        art.thumbnail((compact_side, compact_side), Image.Resampling.LANCZOS)
        compact.alpha_composite(art, ((side - art.width) // 2, (side - art.height) // 2))
        compact.save(ROOT / f"assets/ui/hud/compact/{icon_id}_{side}.png")
        if "district" in entry:
            full = Image.new("RGBA", (side, side))
            art = image.copy()
            art.thumbnail((round(side * 0.88), round(side * 0.88)), Image.Resampling.LANCZOS)
            full.alpha_composite(art, ((side - art.width) // 2, (side - art.height) // 2))
            full.save(ROOT / f"assets/ui/district/{entry['district']}_{side}.png")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("icon_id")
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    bake(args.icon_id, args.source)
    print(f"Baked {args.icon_id}: 256, 192, 128, 96, 64px")


if __name__ == "__main__":
    main()
