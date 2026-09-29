"""Draw the time HUD's gold lacquer controls at their five native sizes."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "assets/ui/time"
SIZES = (256, 192, 128, 96, 64)
SOURCE_SIZE = 1024
GOLD = (224, 183, 100, 255)
BRIGHT = (255, 231, 169, 255)
DARK = (110, 69, 27, 255)


def artwork(name: str) -> Image.Image:
    image = Image.new("RGBA", (SOURCE_SIZE, SOURCE_SIZE))
    shadow = Image.new("RGBA", image.size)
    s = ImageDraw.Draw(shadow)
    s.ellipse((120, 120, 904, 904), fill=(0, 0, 0, 110))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(32)))
    draw = ImageDraw.Draw(image)
    draw.ellipse((112, 112, 912, 912), fill=(17, 28, 44, 245), outline=DARK, width=34)
    draw.ellipse((137, 137, 887, 887), outline=GOLD, width=26)
    draw.arc((166, 166, 858, 858), 200, 340, fill=BRIGHT, width=12)
    draw.arc((166, 166, 858, 858), 20, 160, fill=GOLD, width=8)
    for x, y in ((512, 149), (875, 512), (512, 875), (149, 512)):
        draw.ellipse((x - 17, y - 17, x + 17, y + 17), fill=BRIGHT)
    if name == "pause":
        for x in (356, 562):
            draw.rounded_rectangle((x, 318, x + 102, 706), radius=18, fill=GOLD, outline=BRIGHT, width=12)
    elif name == "play":
        draw.polygon(((372, 293), (746, 512), (372, 731)), fill=GOLD)
        draw.line(((372, 293), (746, 512), (372, 731), (372, 293)), fill=BRIGHT, width=24, joint="curve")
    elif name in ("slower", "faster"):
        direction = -1 if name == "slower" else 1
        centers = (425, 610) if direction < 0 else (399, 584)
        for center in centers:
            tip = center + direction * 145
            back = center - direction * 65
            draw.polygon(((tip, 512), (back, 328), (back, 696)), fill=GOLD)
            draw.line(((tip, 512), (back, 328), (back, 696), (tip, 512)), fill=BRIGHT, width=18, joint="curve")
    elif name == "calendar":
        draw.rounded_rectangle((294, 318, 730, 722), radius=40, fill=(239, 220, 177, 255), outline=GOLD, width=24)
        draw.rectangle((308, 394, 716, 460), fill=DARK)
        for x in (388, 636):
            draw.rounded_rectangle((x - 19, 266, x + 19, 378), radius=14, fill=BRIGHT)
        for y in (528, 620):
            for x in (382, 512, 642):
                draw.ellipse((x - 22, y - 22, x + 22, y + 22), fill=DARK)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("calendar", "slower", "pause", "play", "faster"):
        original = artwork(name)
        for size in SIZES:
            original.resize((size, size), Image.Resampling.LANCZOS).save(OUT / f"{name}_{size}.png", optimize=True)


if __name__ == "__main__":
    main()
