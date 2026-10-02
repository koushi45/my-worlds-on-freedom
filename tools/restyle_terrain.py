"""Rebuild only the display textures, preserving approved geometry and DEM data.

Usage: python tools/restyle_terrain.py [--detail] [--close] [--high] [--overview] [--tile ID] [--workers 2]
With no flags, all levels of detail are refreshed. --close updates only the
250-percent texture tier; --high updates the 400-percent tier at 8x density.
"""
import argparse
import json
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np
from PIL import Image
from pyproj import Transformer
from scipy.ndimage import map_coordinates, median_filter

from build_detail_map import CACHE, DENSITY, ROOT, ZOOM, sha
from terrain_texture import render, STYLE


def save_png(image, path):
    # Replace complete files atomically so importers never read partial PNGs.
    for attempt in range(8):
        try:
            temporary = path.with_suffix(path.suffix + ".pending")
            image.save(temporary, format="PNG")
            temporary.replace(path)
            return
        except OSError:
            if attempt == 7:
                raise
            time.sleep(0.3 * (attempt + 1))


def save_text(path, content):
    for attempt in range(8):
        try:
            temporary = path.with_suffix(path.suffix + '.pending')
            temporary.write_text(content, encoding='utf-8')
            temporary.replace(path)
            return
        except OSError:
            if attempt == 7:
                raise
            time.sleep(0.3 * (attempt + 1))


def source_coordinates(transform, inverse, world_x, world_y):
    scale = transform['uniform_scale_px_per_m']
    bx, by, _, _ = transform['projected_scope_bounds_m']
    lon, lat = inverse.transform(bx + (world_x - transform['offset_x_px']) / scale,
                                  by + (transform['content_height_px'] - world_y + transform['offset_y_px']) / scale)
    return (lon + 180) / 360 * 2**ZOOM, (1 - np.arcsinh(np.tan(np.deg2rad(lat))) / np.pi) / 2 * 2**ZOOM


def render_detail_tile(job):
    tile, transform, base, close, high, variant, output_dir = job
    attenuation = np.asarray(Image.open(ROOT / "assets/map/elevation/terrain_lighting.png"), np.float32) / 255.0
    inverse = Transformer.from_crs(transform['projection'], 'EPSG:4326', always_xy=True)
    scale = transform['uniform_scale_px_per_m']
    x, y, x_end, y_end = tile['global_viewport']
    sample_x, sample_y = np.meshgrid(np.linspace(x - 2, x_end + 2, 17),
                                     np.linspace(y - 2, y_end + 2, 17))
    tx, ty = source_coordinates(transform, inverse, sample_x, sample_y)
    sx, sy = int(np.floor(tx.min())) - 1, int(np.floor(ty.min())) - 1
    ex, ey = int(np.floor(tx.max())) + 1, int(np.floor(ty.max())) + 1
    mosaic = np.empty(((ey - sy + 1) * 256, (ex - sx + 1) * 256), np.float32)
    for a in range(sx, ex + 1):
        for b in range(sy, ey + 1):
            source = CACHE / str(a) / f'{b}.png'
            if not source.exists():
                raise FileNotFoundError(f'Missing cached DEM source: {source}')
            rgb = np.asarray(Image.open(source).convert('RGB'), dtype=np.float32)
            height = rgb[:, :, 0] * 256 + rgb[:, :, 1] + rgb[:, :, 2] / 256 - 32768
            bad = (height > 4500) | (height < -12000)
            if bad.any():
                replacement = median_filter(height, size=3)
                height[bad] = replacement[bad]
            mosaic[(b - sy) * 256:(b - sy + 1) * 256,
                   (a - sx) * 256:(a - sx + 1) * 256] = height
    tiers = (['base'] if base else []) + (['close'] if close else []) + (['high'] if high else [])
    rendered = None
    for tier in reversed(tiers):
        density = {'base': DENSITY, 'close': 6, 'high': 8}[tier]
        gutter = density  # One world unit; normalized UVs match the baked mesh.
        size = 258 * density
        if rendered is None:
            halo = 16
            axis = (np.arange(size + halo * 2, dtype=np.float64) - gutter - halo + 0.5) / density
            wx, wy = np.meshgrid(x + axis, y + axis)
            tx, ty = source_coordinates(transform, inverse, wx, wy)
            height = np.maximum(0, map_coordinates(mosaic,
                [(ty - sy) * 256 - 0.5, (tx - sx) * 256 - 0.5], order=1, mode='nearest'))
            assert np.isfinite(height).all() and height.max() < 4500, tile['tile_id']
            broad = map_coordinates(attenuation, [wy / 2 - 0.5, wx / 2 - 0.5], order=1, mode='nearest')
            image = render(height, x + axis, y + axis, 1 / density / scale,
                           close=tier != 'base', variant=variant, broad_attenuation=broad)[halo:-halo, halo:-halo]
            rendered = Image.fromarray(image)
        # Offline downsampling preserves the same relief and vegetation at every tier.
        output = rendered if rendered.size == (size, size) else rendered.resize((size, size), Image.Resampling.LANCZOS)
        name = tile['tile_id'] + ('' if tier == 'base' else '-' + tier) + '.png'
        path = (Path(output_dir).resolve() if output_dir else ROOT / 'assets/map/detail') / name
        path.parent.mkdir(parents=True, exist_ok=True)
        save_png(output, path)
        field = 'relief' if tier == 'base' else 'relief_' + tier
        tile['files'][field] = path.relative_to(ROOT).as_posix()
        tile['hashes'][field] = sha(path)
        if tier != 'base':
            tile[tier + '_density'] = density
            tile[tier + '_gutter'] = gutter
            tile[tier + '_output_size'] = [size, size]
    return tile


def detail_tiles(selected=None, base=True, close=False, high=False, workers=1, variant="albedo", output_dir=None):
    manifest_path = ROOT / 'data/derived/detail_map/manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    transform = json.loads((ROOT / 'data/base/japan_land_manifest.json').read_text(encoding='utf-8'))['game_transform']
    tiles = [t for t in manifest['tiles'] if selected is None or t['tile_id'] == selected]
    if selected is not None and not tiles:
        raise ValueError(f'Unknown detail tile: {selected}')
    jobs = [(t, transform, base, close, high, variant, output_dir) for t in tiles]
    if workers == 1 or len(jobs) == 1:
        finished = map(render_detail_tile, jobs)
        for index, tile in enumerate(finished, 1):
            print(f'Detail {index}/{len(tiles)}: {tile["tile_id"]}', flush=True)
    else:
        # Workers write disjoint PNGs; only the parent publishes the manifest.
        with ProcessPoolExecutor(max_workers=workers) as pool:
            for index, tile in enumerate(pool.map(render_detail_tile, jobs), 1):
                target = next(t for t in manifest['tiles'] if t['tile_id'] == tile['tile_id'])
                target.update(tile)
                print(f'Detail {index}/{len(tiles)}: {tile["tile_id"]}', flush=True)
    manifest['texture_style'] = STYLE['name']
    manifest['texture_parameters'] = STYLE
    manifest['texture_sources'] = {str(p.relative_to(ROOT).as_posix()): sha(p) for p in [
        ROOT / 'tools/terrain_texture.py', ROOT / 'tools/restyle_terrain.py',
        ROOT / 'tools/build_terrain_relief.py', ROOT / 'assets/map/elevation/terrain_lighting.png',
        ROOT / 'data/base/japan_land_manifest.json']} 
    manifest['illumination'] = ('unlit sRGB albedo; runtime normals and directional light on measured 3D geometry'
                              if variant == 'albedo' else 'linear-light fine slope illumination and broad measured shadow baked into native PNGs')
    manifest['generation'] = 'highest requested tier rendered once; lower tiers downsampled offline in world alignment'
    if output_dir:
        report_path = Path(output_dir) / 'generation.json'
        report = {'variant': variant, 'parameters': STYLE, 'sources': manifest['texture_sources'], 'tiles': []}
        if report_path.exists():
            previous = json.loads(report_path.read_text(encoding='utf-8'))
            if previous.get('parameters') == STYLE and previous.get('variant') == variant:
                report['tiles'] = [t for t in previous['tiles'] if t['tile_id'] not in {t['tile_id'] for t in tiles}]
        report['tiles'].extend(tiles)
        save_text(report_path, json.dumps(report, indent=2))
        return
    if close:
        manifest['close_zoom_threshold'] = 2.5
    if high:
        manifest['high_zoom_threshold'] = 4.0
        manifest['maximum_zoom'] = 8
    save_text(manifest_path, json.dumps(manifest, separators=(',', ':'), ensure_ascii=False))


def render_overview(height, scale, attenuation=None, variant='albedo'):
    height = np.asarray(height, dtype=np.float32)
    assert height.shape == (4096, 4096)
    image = np.empty((4096, 4096, 3), dtype=np.uint8)
    for top in range(0, 4096, 1024):
        for left in range(0, 4096, 1024):
            y0, y1 = max(0, top - 8), min(4096, top + 1024 + 8)
            x0, x1 = max(0, left - 8), min(4096, left + 1024 + 8)
            rendered = render(height[y0:y1, x0:x1],
                              (np.arange(x0, x1) + 0.5) * 2,
                              (np.arange(y0, y1) + 0.5) * 2, 2 / scale, variant=variant,
                              broad_attenuation=None if attenuation is None else attenuation[y0:y1, x0:x1])
            image[top:top + 1024, left:left + 1024] = rendered[top - y0:top + 1024 - y0,
                                                                   left - x0:left + 1024 - x0]
            print(f'Overview {top // 1024 + 1},{left // 1024 + 1}/4', flush=True)
    return Image.fromarray(image)


def overview_tiles():
    transform = json.loads((ROOT / 'data/base/japan_land_manifest.json').read_text(encoding='utf-8'))['game_transform']
    scale = transform['uniform_scale_px_per_m']
    height = np.asarray(Image.open(ROOT / 'assets/map/elevation/elevation_m.png'), dtype=np.float32)
    attenuation = np.asarray(Image.open(ROOT / "assets/map/elevation/terrain_lighting.png"), np.float32) / 255.0
    relief = render_overview(height, scale, attenuation)
    # Far terrain remains available beyond the bounded near surface atlas.
    global_colour = relief.convert('RGBA')
    coverage = Image.open(ROOT / 'data/derived/land_masks/land_mask_8192.png').resize((4096,4096), Image.Resampling.BOX)
    global_colour.putalpha(coverage)
    save_png(global_colour, ROOT / 'assets/map/elevation/terrain_albedo.png')
    tiles = json.loads((ROOT / 'data/derived/map_images/map_images_manifest.json').read_text(encoding='utf-8'))['tiles']
    manifest_path = ROOT / 'data/derived/elevation/elevation_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for tile in tiles:
        bounds = tuple(int(v * 4096 / 8192) for v in tile['global_viewport'])
        output = relief.crop(bounds).resize(tuple(tile['output_size']), Image.Resampling.BILINEAR).convert('RGBA')
        coverage = Image.open(ROOT / tile['files']['land_coverage'])
        output.putalpha(coverage)
        path = ROOT / 'assets/map/elevation' / (tile['tile_id'] + '.png')
        save_png(output, path)
        manifest['tiles'][tile['tile_id']]['sha256'] = sha(path).upper()
    manifest['modifications'] = 'LCC reprojection; approved polygon clipping; continuous unlit vegetation colour; measured 3D terrain supplies runtime slope lighting and shadows.'
    save_text(manifest_path, json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--detail', action='store_true')
    parser.add_argument('--close', action='store_true')
    parser.add_argument('--high', action='store_true')
    parser.add_argument('--overview', action='store_true')
    parser.add_argument('--tile')
    parser.add_argument('--variant', choices=['lighting', 'colour', 'adopted', 'albedo'], default='albedo')
    parser.add_argument('--output-dir')
    parser.add_argument('--workers', type=int, default=2, choices=range(1, 5))
    args = parser.parse_args()
    if args.variant not in ("adopted", "albedo") and not args.output_dir:
        parser.error("comparison variants require --output-dir to preserve production textures")
    if args.output_dir and args.overview:
        parser.error("--output-dir is for isolated detail texture comparisons")
    all_tiers = not (args.detail or args.close or args.high or args.overview or args.tile)
    if args.tile or args.detail or args.close or args.high or all_tiers:
        detail_tiles(args.tile, base=args.detail or (args.tile is not None and not args.high) or all_tiers,
                     close=args.close or args.detail or (args.tile is not None and not args.high) or all_tiers,
                     high=args.high or args.detail or args.tile is not None or all_tiers, workers=args.workers,
                     variant=args.variant, output_dir=args.output_dir)
    if args.overview or (all_tiers and not args.output_dir):
        overview_tiles()


if __name__ == '__main__':
    main()
