"""Conservative height bounds for exact terrain ray traversal (no mesh LOD change)."""
from pathlib import Path
import hashlib
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "data/derived/elevation"


def main():
    raw = (FOLDER / "terrain_vertices.bin").read_bytes()
    heights = np.frombuffer(raw, dtype="<u2").reshape(4097, 4097)
    fuji_raw = (FOLDER / "fuji_vertices.bin").read_bytes()
    metadata = json.loads((FOLDER / "terrain_geometry.json").read_text(encoding="utf-8"))
    detail = metadata["fuji_detail"]
    origin = detail["origin"]
    span = detail["span"]
    fuji_max = int(np.frombuffer(fuji_raw, dtype="<u2").max())
    tiers = []
    payload = bytearray()
    for step in (256, 64, 16):
        side = 8192 // step
        result = np.zeros((side, side), dtype="<u2")
        # Extend by one far-grid cell: seam morphs and the Fuji parent surface
        # can sample coarse vertices outside this block. Maxima bound both.
        for y in range(side):
            for x in range(side):
                x0, y0 = x * step, y * step
                patch = heights[max(0,(y0-16)//2):min(4097,(y0+step+16)//2+1),
                                max(0,(x0-16)//2):min(4097,(x0+step+16)//2+1)]
                highest = int(patch.max())
                if x0 <= origin[0]+span+16 and x0+step >= origin[0]-16 and y0 <= origin[1]+span+16 and y0+step >= origin[1]-16:
                    highest = max(highest, fuji_max)
                result[y,x] = highest
        tiers.append({"step":step,"side":side,"offset":len(payload)})
        payload.extend(result.tobytes())
    (FOLDER / "terrain_ray_bounds.bin").write_bytes(payload)
    (FOLDER / "terrain_ray_bounds.json").write_text(json.dumps({
        "terrain_sha256":hashlib.sha256(raw).hexdigest(),
        "fuji_sha256":hashlib.sha256(fuji_raw).hexdigest(),
        "tiers":tiers,"bytes":len(payload)
    },indent=2)+"\n",encoding="utf-8")
    print("Exact terrain ray bounds:",len(payload),"bytes")


if __name__ == "__main__":
    main()
