"""Continuous, deterministic terrain colours from a real elevation raster.

Vegetation is an artistic estimate; the coastline, relief and snow line follow
the source data. Noise is sampled in world coordinates so adjacent tiles meet.
"""
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates


def _smooth(a, b, value):
    t = np.clip((value - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _noise(world_x, world_y, spacing, seed):
    """Cubic value noise on a global lattice, with enough border for seams."""
    gx = np.asarray(world_x, dtype=np.float32) / spacing
    gy = np.asarray(world_y, dtype=np.float32) / spacing
    left = int(np.floor(gx.min())) - 3
    top = int(np.floor(gy.min())) - 3
    right = int(np.ceil(gx.max())) + 4
    bottom = int(np.ceil(gy.max())) + 4
    ix = np.arange(left, right, dtype=np.int64).astype(np.uint32)[None, :]
    iy = np.arange(top, bottom, dtype=np.int64).astype(np.uint32)[:, None]
    values = ix * np.uint32(0x9E3779B1) ^ iy * np.uint32(0x85EBCA77) ^ np.uint32(seed)
    values ^= values >> np.uint32(16)
    values *= np.uint32(0x7FEB352D)
    values ^= values >> np.uint32(15)
    values *= np.uint32(0x846CA68B)
    values ^= values >> np.uint32(16)
    coords = np.array(np.broadcast_arrays((gy - top)[:, None], (gx - left)[None, :]), dtype=np.float32)
    return map_coordinates(values.astype(np.float32) / np.float32(2**32), coords,
                           order=3, mode='nearest', prefilter=True).astype(np.float32)


def render_legacy(height_m, world_x, world_y, metres_per_pixel, close=False, lit=True):
    height = np.asarray(height_m, dtype=np.float32)
    slope_height = gaussian_filter(height, 0.9)
    dy, dx = np.gradient(slope_height, metres_per_pixel)
    slope = np.hypot(dx, dy)
    shade = np.clip(0.57 + 0.49 * (0.55 * dx + 0.65 * dy + 0.78) / np.sqrt(slope * slope + 1.0), 0.39, 1.12)
    broad = _noise(world_x, world_y, 64.0, 0x91D5A73B) - 0.5
    patches = _noise(world_x, world_y, 15.0, 0xC5A86B13) - 0.5
    canopy = _noise(world_x, world_y, 3.2, 0x347BC051) - 0.5
    grain = _noise(world_x, world_y, 0.72, 0xBF21D739) - 0.5
    dry = _smooth(-0.12, 0.20, broad * 0.75 + patches * 0.25 + _smooth(900, 1800, height) * 0.12)
    forest = _smooth(-0.13, 0.16, broad * 0.6 + patches * 0.4 + _smooth(120, 700, height) * 0.16 - _smooth(1350, 2050, height) * 0.34)
    forest *= 0.10 + 0.90 * np.maximum(_smooth(100, 550, height), _smooth(0.07, 0.30, slope))
    forest *= 1.0 - _smooth(0.65, 1.25, slope) * 0.55
    rock = np.maximum(_smooth(0.32, 0.95, slope) * 0.82, _smooth(950, 2050, height + patches * 240) * 0.88)
    rock = np.clip(rock + _smooth(0.22, 0.55, slope) * _smooth(1300, 2100, height) * 0.18, 0.0, 1.0)
    snow = _smooth(2210, 2570, height + broad * 140 + patches * 90)
    snow *= 1.0 - _smooth(1.0, 2.0, slope) * 0.32
    grass = np.array([117, 145, 88], dtype=np.float32)
    meadow = np.array([168, 157, 108], dtype=np.float32)
    woodland = np.array([54, 86, 55], dtype=np.float32)
    stone = np.array([130, 124, 111], dtype=np.float32)
    summit = np.array([227, 229, 221], dtype=np.float32)
    colour = grass + dry[..., None] * (meadow - grass)
    colour += forest[..., None] * (woodland - colour)
    colour += rock[..., None] * (stone - colour)
    colour += snow[..., None] * (summit - colour)
    detail = patches * 9 + canopy * (8 + forest * 16) + grain * 8
    detail *= 1.0 - snow * 0.65
    colour += detail[..., None]
    if close:
        fine = _noise(world_x, world_y, 0.38, 0xD42876A1) - 0.5
        clumps = _noise(world_x, world_y, 1.15, 0x59C7E22B) - 0.5
        close_detail = fine * (8 + forest * 11 + rock * 9) + clumps * (7 + forest * 8)
        colour += (close_detail * (1.0 - snow * 0.65))[..., None]
    if lit:
        colour *= shade[..., None]
    return np.clip(colour, 0, 255).astype(np.uint8)


STYLE = {
    "name": "continuous vegetation and measured relief v1",
    "ambient": 0.38, "diffuse": 0.68, "relief_strength": 3.0,
    "sun_direction": [-0.55, -0.65, 0.78],
    "grass_rgb": [158, 176, 108], "dry_grass_rgb": [179, 170, 119],
    "forest_rgb": [64, 99, 68], "rock_rgb": [153, 148, 127],
    "surface_spacing_world": 0.65, "fine_spacing_world": 0.30,
    "normal_radius_world": 0.09,
    "shadow_strength": 0.15, "valley_strength": 0.08,
    "colour_space": "sRGB albedo to linear light to sRGB baked PNG",
    "shapes": "continuous value noise only; no crowns, dots or fractures",
}


def srgb_to_linear(colour):
    value = np.clip(colour / 255.0, 0.0, 1.0)
    return np.where(value <= 0.04045, value / 12.92, ((value + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(colour):
    value = np.clip(colour, 0.0, 1.0)
    return np.where(value <= 0.0031308, value * 12.92, 1.055 * value ** (1 / 2.4) - 0.055) * 255.0


def components(height_m, world_x, world_y, metres_per_pixel, close=False, variant="adopted"):
    """Separate colour and fine illumination; neither draws discrete marks."""
    height = np.asarray(height_m, np.float32)
    # A constant world-space radius gives matching normals in all texture tiers.
    world_step = abs(float(world_x[1] - world_x[0]))
    smooth = gaussian_filter(height, STYLE["normal_radius_world"] / world_step)
    dy, dx = np.gradient(smooth, metres_per_pixel)
    slope = np.hypot(dx, dy)
    diffuse = np.maximum(0, (0.55 * dx * STYLE["relief_strength"] + 0.65 * dy * STYLE["relief_strength"] + 0.78) /
                         np.sqrt((dx * dx + dy * dy) * STYLE["relief_strength"] ** 2 + 1) /
                         np.linalg.norm(STYLE["sun_direction"]))
    illumination = STYLE["ambient"] + STYLE["diffuse"] * diffuse
    if variant == "lighting":
        colour = render_legacy(height, world_x, world_y, metres_per_pixel, close, lit=False).astype(np.float32)
    else:
        broad = _noise(world_x, world_y, 64.0, 0x91D5A73B) - 0.5
        patches = _noise(world_x, world_y, 12.0, 0xC5A86B13) - 0.5
        middle = _noise(world_x, world_y, 5.0, 0x347BC051) - 0.5
        dry = _smooth(-0.14, 0.24, broad * 0.7 + patches * 0.3)
        forest = _smooth(-0.15, 0.20, broad * 0.55 + patches * 0.45 + _smooth(100, 650, height) * 0.15)
        forest *= 0.15 + 0.85 * np.maximum(_smooth(100, 600, height), _smooth(0.055, 0.25, slope))
        forest *= 1 - _smooth(1400, 2350, height) * 0.6
        # Rock is a muted exposed surface, without lines or cracks.
        rock = _smooth(0.32, 0.95, slope) * (0.25 + _smooth(1000, 2250, height) * 0.36)
        rock = np.maximum(rock, _smooth(1750, 2650, height + patches * 140) * 0.48)
        snow = _smooth(2210, 2570, height + broad * 140 + patches * 90)
        snow *= 1 - _smooth(1, 2, slope) * 0.32
        colour = np.asarray(STYLE["grass_rgb"], np.float32) + dry[..., None] * (
            np.asarray(STYLE["dry_grass_rgb"], np.float32) - np.asarray(STYLE["grass_rgb"], np.float32))
        colour += forest[..., None] * (np.asarray(STYLE["forest_rgb"], np.float32) - colour)
        colour += rock[..., None] * (np.asarray(STYLE["rock_rgb"], np.float32) - colour)
        colour += snow[..., None] * (np.asarray([227, 229, 221], np.float32) - colour)
        detail = patches * 6 + middle * (5 + forest * 6)
        if variant in ("adopted", "albedo"):
            surface = _noise(world_x, world_y, STYLE["surface_spacing_world"], 0xBF21D739) - 0.5
            fine = _noise(world_x, world_y, STYLE["fine_spacing_world"], 0xD42876A1) - 0.5
            detail += surface * (8 + forest * 4) + fine * 5
        colour += (detail * (1 - snow * 0.75))[..., None]
    # A restrained warm sun and cool ambient tint retain shaded vegetation.
    tint = np.asarray([0.94, 0.99, 1.03], np.float32) + diffuse[..., None] * np.asarray([0.07, 0.025, -0.06], np.float32)
    return np.clip(colour, 0, 255), illumination[..., None] * tint


def render(height_m, world_x, world_y, metres_per_pixel, close=False,
           variant="adopted", broad_attenuation=None):
    colour, illumination = components(height_m, world_x, world_y, metres_per_pixel, close, variant)
    if variant == "albedo":
        return np.rint(colour).astype(np.uint8)
    if broad_attenuation is not None:
        illumination *= np.asarray(broad_attenuation, np.float32)[..., None]
    return np.rint(linear_to_srgb(srgb_to_linear(colour) * illumination)).astype(np.uint8)
