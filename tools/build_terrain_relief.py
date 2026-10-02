"""Bake measured slope lighting and terrain shadows for the game map.

The existing displaced mesh and picking surface remain shared by all layers.
This continuous field adds fine DEM relief without per-frame height sampling.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = Path(__file__).resolve().parents[1]


def lighting(height, metres_per_pixel):
    height = np.asarray(height, dtype=np.float32)
    smooth = gaussian_filter(height, 0.9)
    exaggeration = 3.0
    # A low northwestern sun casts shadows across valleys. Sample only valid
    # neighbours; the edges of the Japan raster must never wrap around.
    horizon = np.zeros_like(height)
    for distance in (1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64):
        if distance >= min(height.shape):
            continue
        rise = (smooth[:-distance, :-distance] - smooth[distance:, distance:]) * exaggeration
        rise -= np.sqrt(2) * distance * metres_per_pixel * np.tan(np.deg2rad(32))
        horizon[distance:, distance:] = np.maximum(horizon[distance:, distance:], rise)
    shadow = np.clip(horizon / (metres_per_pixel * 2), 0, 1)
    enclosure = np.maximum(0, gaussian_filter(smooth, 5) - smooth)
    occlusion = np.clip(enclosure / (metres_per_pixel * 0.8), 0, 1)
    attenuation = (1 - shadow * 0.15) * (1 - occlusion * 0.08)
    attenuation[height <= 0] = 1
    return np.rint(attenuation * 255).astype(np.uint8)


def main():
    source = ROOT / 'assets/map/elevation/elevation_m.png'
    height = np.asarray(Image.open(source), dtype=np.float32)
    manifest = json.loads((ROOT / 'data/derived/elevation/elevation_manifest.json').read_text(encoding='utf-8'))
    metres_per_pixel = 8192 / height.shape[1] / manifest['game_transform']['uniform_scale_px_per_m']
    output = ROOT / 'assets/map/elevation/terrain_lighting.png'
    temporary = output.with_suffix('.png.pending')
    Image.fromarray(lighting(height, metres_per_pixel)).save(temporary, format='PNG')
    temporary.replace(output)
    report = {
        'source': source.relative_to(ROOT).as_posix(),
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'output': output.relative_to(ROOT).as_posix(),
        'output_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'size': list(height.shape[::-1]),
        'encoding': 'luminance / 255 = broad shadow attenuation; sampled by the offline texture baker only',
        'sun': 'northwest, 32 degrees; 3x vertical exaggeration for horizon shadows',
        'shadows': 'measured DEM horizon and valley ambient occlusion',
        'shadow_strength': 0.15, 'occlusion_strength': 0.08,
        'fine_illumination': 'computed per detail texture from zoom 11 DEM; linear light baked into PNG',
    }
    (ROOT / 'data/derived/elevation/terrain_lighting.json').write_text(
        json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Terrain lighting ready:', output)


if __name__ == '__main__':
    main()
