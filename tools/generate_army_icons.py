"""Rasterize the team-colored map unit at every native display size."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "ui" / "army"
SIZES = (64, 96, 128, 192, 256)
COLORS = {
    "blue": "#317ec6",
    "green": "#42a36a",
    "red": "#c84345",
    "neutral": "#8d9299",
}
SHAPE = ((16, 48), (16, 31), (24, 31), (24, 18),
         (40, 18), (40, 31), (48, 31), (48, 48))


def draw_icon(side: int, fill: str) -> Image.Image:
    # Each target is rasterized from the shape. The 4x canvas is an offline
    # antialiasing step; the game loads the resulting PNG at native pixel size.
    factor = side / 64 * 4
    canvas = Image.new("RGBA", (side * 4, side * 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    points = [(round(x * factor), round(y * factor)) for x, y in SHAPE]
    draw.polygon(points, fill="#18242b")
    inner = [(round(x * factor), round(y * factor)) for x, y in
             ((18, 46), (18, 33), (26, 33), (26, 20),
              (38, 20), (38, 33), (46, 33), (46, 46))]
    draw.polygon(inner, fill=fill)
    draw.line(points + [points[0]], fill="#d9bc78", width=max(1, round(factor)))
    draw.line([(round(27 * factor), round(23 * factor)),
               (round(37 * factor), round(23 * factor))],
              fill="#e9f0eb", width=max(1, round(factor)))
    return canvas.resize((side, side), Image.Resampling.LANCZOS)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, fill in COLORS.items():
        for side in SIZES:
            draw_icon(side, fill).save(OUTPUT / f"totsu_{name}_{side}.png", optimize=True)
    print(f"Generated {len(COLORS) * len(SIZES)} transparent army PNGs")


if __name__ == "__main__":
    main()
