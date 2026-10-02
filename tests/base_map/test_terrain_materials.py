"""Verify continuous terrain textures across streamed tiles."""
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
from terrain_texture import render


class TerrainMaterialTests(unittest.TestCase):
    def test_albedo_ignores_baked_light_and_shadow_parameters(self):
        from terrain_texture import STYLE
        from unittest.mock import patch
        axis = 4450 + np.arange(128) / 8
        height = (500 + np.broadcast_to(np.arange(128), (128,128))*6).astype(np.float32)
        original = render(height, axis, axis, 28, variant='albedo')
        with patch.dict(STYLE, ambient=0.0, diffuse=0.0):
            dark_light = render(height, axis, axis, 28, variant='albedo',
                                broad_attenuation=np.zeros_like(height))
        np.testing.assert_array_equal(original, dark_light)

    def test_adjacent_tiles_agree_in_their_shared_world_region(self):
        y = 5500 + np.arange(256) / 8
        x = 4450 + np.arange(256) / 8
        next_x = x + 16
        def heights(axis):
            return (700 + 80 * np.sin(axis[None, :] / 12) +
                    40 * np.cos(y[:, None] / 15)).astype(np.float32)
        a = render(heights(x), x, y, 28, close=True)
        b = render(heights(next_x), next_x, y, 28, close=True)
        # Ignore the derivative stencil at each render's outer boundary.
        difference = np.abs(a[8:-8, 136:-8].astype(int) - b[8:-8, 8:120].astype(int))
        self.assertLessEqual(difference.max(), 1)

    def test_broad_shadow_is_applied_once_in_linear_light(self):
        axis = np.arange(128, dtype=np.float32) / 8 + 4450
        height = np.full((128, 128), 700, dtype=np.float32)
        full = render(height, axis, axis, 28)
        half = render(height, axis, axis, 28, broad_attenuation=np.full(height.shape, 0.5))
        from terrain_texture import srgb_to_linear
        ratio = srgb_to_linear(half.astype(np.float32)) / srgb_to_linear(full.astype(np.float32))
        # Allow the two 8-bit sRGB quantizations in darker colour channels.
        self.assertLess(np.abs(ratio - 0.5).max(), 0.03)

    def test_surface_detail_stays_quiet_in_snow(self):
        axis = 4450 + np.arange(256) / 8
        contrasts = []
        for elevation in [30, 700, 2800]:
            image = render(np.full((256, 256), elevation, np.float32), axis, axis, 28)
            contrasts.append(np.abs(np.diff(image.astype(float), axis=1)).mean())
        self.assertLess(contrasts[0], 1.5)
        self.assertLess(contrasts[1], 1.5)
        self.assertLess(contrasts[2], contrasts[1] / 2)

    def test_render_strips_do_not_introduce_horizontal_seams(self):
        x = 4450 + np.arange(256) / 8
        y = 5500 + np.arange(768) / 8
        heights = (700 + 80 * np.sin(x[None, :] / 12) + 40 * np.cos(y[:, None] / 15)).astype(np.float32)
        image = render(heights, x, y, 28, close=True)
        reference = render(heights[224:448], x, y[224:448], 28, close=True)
        difference = np.abs(image[240:432].astype(int) - reference[16:-16].astype(int))
        self.assertLessEqual(difference.max(), 1)


if __name__ == '__main__':
    unittest.main()
