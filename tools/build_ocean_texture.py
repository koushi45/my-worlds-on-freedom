"""Build a seamless, understated ocean texture for the map renderer."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


SIZE = 512
OUTPUT = Path(__file__).resolve().parents[1] / "assets/map/ocean_texture.png"


def main() -> None:
    rng = np.random.default_rng(1546)
    y, x = np.mgrid[:SIZE, :SIZE].astype(np.float32)
    # Integer frequencies make every color band tile cleanly on all four sides.
    variation = np.zeros((SIZE, SIZE), dtype=np.float32)
    for frequency, amplitude, count in ((1, 2.8, 5), (2, 1.7, 6), (4, 0.9, 8), (8, 0.35, 10)):
        for _ in range(count):
            wave_x = int(rng.integers(-frequency, frequency + 1))
            wave_y = int(rng.integers(-frequency, frequency + 1))
            if wave_x == wave_y == 0:
                continue
            phase = rng.uniform(0, np.pi * 2)
            variation += amplitude / np.sqrt(count) * np.sin(
                (x * wave_x + y * wave_y) * (2 * np.pi / SIZE) + phase
            )

    variation *= 2.1
    base = np.array([29, 57, 72], dtype=np.float32)
    tint = np.array([0.75, 1.2, 1.45], dtype=np.float32)
    pixels = np.clip(base + variation[..., None] * tint, 0, 255).astype(np.uint8)
    image = Image.fromarray(pixels, "RGB").convert("RGBA")

    # Short, soft strokes suggest surface ripples without obscuring coastlines.
    ripples = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(ripples)
    for _ in range(115):
        left = int(rng.integers(0, SIZE))
        top = int(rng.integers(0, SIZE))
        width = int(rng.integers(12, 52))
        bend = int(rng.integers(-4, 5))
        color = (100, 153, 169, int(rng.integers(24, 48)))
        points = [(left, top), (left + width // 2, top + bend), (left + width, top)]
        for dx in (-SIZE, 0, SIZE):
            for dy in (-SIZE, 0, SIZE):
                draw.line([(px + dx, py + dy) for px, py in points], fill=color, width=2)
    ripples = ripples.filter(ImageFilter.GaussianBlur(0.6))
    image = Image.alpha_composite(image, ripples).convert("RGB")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
