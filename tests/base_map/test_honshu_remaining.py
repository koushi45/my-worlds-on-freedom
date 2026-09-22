"""Validate pending source traces without promoting them to approved regions."""
import hashlib
import json
import unittest
from pathlib import Path
import cv2
import numpy as np
from shapely.geometry import LineString, Polygon
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[2]

class HonshuRemaining(unittest.TestCase):
    def test_pending_lines_and_immutable_base(self):
        d=json.loads((ROOT/'data/derived/editor/honshu/editor_draft.json').read_text(encoding='utf-8'))
        self.assertEqual(d['status'],'editor_draft_only')
        self.assertEqual(d['scope'],'honshu')
        self.assertEqual(d['regions'],[])
        for name,sha in d['reference_hashes'].items():
            self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),sha)
        approved=json.loads((ROOT/'data/derived/political/approved_western/political_registry.json').read_text(encoding='utf-8'))
        self.assertEqual(len(approved['regions']),24)
        mainland=Polygon(next(iter(d['coastlines'].values())))
        protected=unary_union([Polygon(p) for r in approved['regions'] for p in r['polygons']])
        image=cv2.imread(str(ROOT/'data/work/political/honshu_remaining/source.png'))
        ink=(np.max(image,axis=2)<145)
        ink_distance=cv2.distanceTransform((~ink).astype(np.uint8),cv2.DIST_L2,5)
        scale=d['handdrawn_source']['scale'];offset=np.array(d['handdrawn_source']['offset'])
        new=[b for b in d['boundaries'] if b['boundary_id'].startswith('honshu:image:')]
        self.assertGreater(len(new),50)
        for b in new:
            self.assertEqual(b['certainty'],'unconfirmed')
            self.assertEqual(b['review_status'],'pending')
            line=LineString(b['points'])
            self.assertTrue(line.is_valid)
            self.assertLess(line.difference(mainland).length,.01)
            self.assertLess(line.intersection(protected).length,.01)
            for p in b['points']:
                x,y=np.rint((np.array(p)-offset)/scale).astype(int)
                self.assertLess(ink_distance[y,x],2.1)
        report=json.loads((ROOT/'data/work/political/honshu_remaining/trace_report.json').read_text(encoding='utf-8'))
        self.assertGreater(len(report['excluded_coastal_fragments']),10)

if __name__=='__main__':unittest.main()
