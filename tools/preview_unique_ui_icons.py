"""Create a labelled contact sheet for visual review of generated UI artwork."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--count", type=int, default=24)
    args = parser.parse_args()
    manifest = json.loads((ROOT / "assets/ui/unique_icons/manifest.json").read_text(encoding="utf-8"))
    items = [entry for entry in manifest["entries"][args.start:args.start + args.count]
             if (ROOT / f"assets/ui/unique_icons/sources/{entry['id']}.png").exists()]
    if not items:
        raise SystemExit("No generated artwork in selected range")
    canvas = Image.new("RGB", (640, ((len(items) + 3) // 4) * 160), "#101821")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype("C:/Windows/Fonts/meiryo.ttc", 13)
    for index, entry in enumerate(items):
        x, y = (index % 4) * 160, (index // 4) * 160
        with Image.open(ROOT / f"assets/ui/unique_icons/sources/{entry['id']}.png") as source:
            image = source.convert("RGBA")
        image.thumbnail((108, 108), Image.Resampling.LANCZOS)
        canvas.paste(image, (x + (160 - image.width) // 2, y + 8 + (108 - image.height) // 2), image)
        lines = [""]
        for character in entry["label"]:
            if font.getlength(lines[-1] + character) > 150:
                lines.append("")
            lines[-1] += character
        for row, line in enumerate(lines):
            draw.text((x + 4, y + 123 + row * 17), line, font=font, fill="#e5c17b")
    output = ROOT / f"builds/qa/unique_icons_{args.start}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    print(f"{len(items)} icons: {output}")


if __name__ == "__main__":
    main()
