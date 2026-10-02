"""Derive display-only shore distance and coastal relief from approved inputs."""

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter, maximum_filter


ROOT = Path(__file__).resolve().parents[1]
LAND_MASK = ROOT / "data/derived/land_masks/land_mask_8192.png"
ELEVATION = ROOT / "assets/map/elevation/elevation_m.png"
OUTPUT = ROOT / "assets/map/coast_style_field.png"
MANIFEST = ROOT / "data/derived/coast_style/manifest.json"
SIZE = 2048
WORLD_UNITS_PER_PIXEL = 8192 / SIZE


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    coverage = np.asarray(
        Image.open(LAND_MASK).resize((SIZE, SIZE), Image.Resampling.BOX),
        dtype=np.uint8,
    )
    land = coverage >= 128
    water_distance, nearest_land = distance_transform_edt(~land, return_indices=True)
    land_distance = distance_transform_edt(land)

    # The source DEM has two samples per style pixel. The local inland rise
    # separates low shores from steep shores; this is an inferred visual class.
    elevation = np.asarray(Image.open(ELEVATION), dtype=np.float32)
    elevation = elevation.reshape(SIZE, 2, SIZE, 2).mean(axis=(1, 3))
    elevation[~land] = 0
    inland_rise = np.maximum(0, maximum_filter(elevation, size=3) - elevation)
    cliff = np.clip((inland_rise - 20) / 100, 0, 1)
    cliff = cliff[nearest_land[0], nearest_land[1]]
    cliff = gaussian_filter(cliff, sigma=6)

    rgba = np.empty((SIZE, SIZE, 4), dtype=np.uint8)
    rgba[:, :, 0] = np.rint(
        np.clip((water_distance - 0.5) * WORLD_UNITS_PER_PIXEL / 128, 0, 1) * 255
    ).astype(np.uint8)
    rgba[:, :, 1] = np.rint(cliff * 255).astype(np.uint8)
    rgba[:, :, 2] = coverage
    # Keep alpha nonzero so the texture importer cannot rewrite RGB values in
    # transparent pixels while fixing alpha borders.
    rgba[:, :, 3] = 128 + np.rint(
        np.clip((land_distance - 0.5) * WORLD_UNITS_PER_PIXEL / 32, 0, 1) * 127
    ).astype(np.uint8)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUTPUT, optimize=True)

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(
        json.dumps(
            {
                "purpose": "display_only",
                "world_size": 8192,
                "size": SIZE,
                "channels": {
                    "r": "water_distance_0_to_128_world_units",
                    "g": "inferred_coastal_cliff_factor",
                    "b": "approved_land_coverage",
                    "a": "128_plus_land_distance_0_to_32_world_units_on_127_steps",
                },
                "inputs": {
                    str(LAND_MASK.relative_to(ROOT)).replace("\\", "/"): digest(LAND_MASK),
                    str(ELEVATION.relative_to(ROOT)).replace("\\", "/"): digest(ELEVATION),
                },
                "output_sha256": digest(OUTPUT),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(OUTPUT, OUTPUT.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
