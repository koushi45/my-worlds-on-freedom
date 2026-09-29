"""Lossless meter samples for the developer contour shader (not display relief)."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def main():
    source = ROOT / "assets/map/elevation/elevation_m.png"
    mask = ROOT / "data/derived/land_masks/land_mask_8192.png"
    heights = np.asarray(Image.open(source), dtype=np.uint16)
    land = np.asarray(Image.open(mask).resize((heights.shape[1], heights.shape[0]), Image.Resampling.NEAREST))
    packed = np.stack([(heights >> 8).astype(np.uint8), (heights & 255).astype(np.uint8), land], axis=-1)
    assert np.array_equal(packed[:, :, 0].astype(np.uint16)*256 + packed[:, :, 1], heights)
    destination = ROOT / "assets/map/elevation/contour_height_field.png"
    Image.fromarray(packed).save(destination)
    report = {"interval_m": 50, "index_interval_m": 250, "height_encoding": "R*256+G meters; B=land mask",
              "size": list(heights.shape), "world_extent": [0, 0, 8192, 8192],
              "minimum_m": int(heights.min()), "maximum_m": int(heights.max()),
              "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "land_mask_sha256": hashlib.sha256(mask.read_bytes()).hexdigest(),
              "output_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}
    (ROOT / "data/derived/elevation/contour_manifest.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf8")
    print(f"Packed {heights.shape} meter samples losslessly, max {heights.max()}m")

if __name__ == "__main__": main()
