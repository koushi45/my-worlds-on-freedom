"""Check that user-edited borders and draft country frames use identical edges."""
import json
import unittest
from pathlib import Path
from shapely.geometry import LineString, Polygon
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[2]


class AlignedChugokuDraft(unittest.TestCase):
    def test_outline_and_line_agreement(self):
        data = json.loads((ROOT / 'data/derived/editor/chugoku/editor_draft.json').read_text(encoding='utf-8'))
        self.assertEqual(data['status'], 'editor_draft_only')
        self.assertEqual(len(data['regions']), 11)
        faces = [Polygon(r['polygons'][0]) for r in data['regions']]
        union = unary_union(faces)
        self.assertEqual(union.geom_type, 'Polygon')
        self.assertEqual(len(union.interiors), 0)
        self.assertAlmostEqual(sum(p.area for p in faces), union.area, places=6)
        borders = unary_union([LineString(b['points']) for b in data['boundaries']])
        coast = unary_union([LineString(r) for r in data['coastlines'].values()])
        outlines = unary_union([p.boundary for p in faces])
        self.assertLess(outlines.difference(unary_union([borders, coast]).buffer(1e-4)).length, 1e-6)
        self.assertLess(borders.difference(outlines.buffer(1e-4)).length, 1e-6)
        for face in faces:
            self.assertTrue(face.is_valid)
        runtime = json.loads((ROOT / 'data/derived/political/approved_western/political_registry.json').read_text(encoding='utf-8'))
        self.assertEqual(len(runtime['regions']), 24)
        self.assertIn('chugoku', runtime['regional_bounds'])
        approved = json.loads((ROOT / 'data/master/political/chugoku/1.1.0/political_registry_master.json').read_text(encoding='utf-8'))
        self.assertEqual(approved['regions'], data['regions'])
        self.assertEqual([b['points'] for b in approved['boundaries']], [b['points'] for b in data['boundaries']])
        self.assertEqual(approved['coastlines'], data['coastlines'])


if __name__ == '__main__':
    unittest.main()
