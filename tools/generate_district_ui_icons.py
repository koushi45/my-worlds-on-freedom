"""Build native-size transparent district icons from the game's lacquer HUD art.

The source directory contains original bitmap illustrations. Shared symbols use
the same originals as the top HUD, keeping their material and lighting coherent.
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DISTRICT = ROOT / "assets/ui/district"
HUD = ROOT / "assets/ui/hud"
SIZES = (256, 192, 128, 96, 64)
SHARED = {
    "house": "castle",
    "people": "people",
    "rice": "rice",
    "coin": "koban",
    "levy": "spears",
    "security": "security",
    "defense": "military",
}
UNIQUE = (
    "governor", "disaster", "autonomy", "infrastructure", "plus",
    "irrigation", "market", "office", "construction",
    "workshop", "temple", "farm_estate", "barracks", "fort",
)


def build(name: str, source: Path) -> None:
    with Image.open(source) as image:
        original = image.convert("RGBA")
        for side in SIZES:
            original.resize((side, side), Image.Resampling.LANCZOS).save(
                DISTRICT / f"{name}_{side}.png", optimize=True
            )


def main() -> None:
    for name, hud_name in SHARED.items():
        build(name, HUD / f"{hud_name}.png")
    for name in UNIQUE:
        build(name, DISTRICT / "source" / f"{name}.png")
    print(f"Generated {(len(SHARED) + len(UNIQUE)) * len(SIZES)} district PNGs")


if __name__ == "__main__":
    main()
