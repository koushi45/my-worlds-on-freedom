"""Independent topology and source-stroke checks for the hand-drawn draft."""
import json
import unittest
from pathlib import Path
import cv2
import numpy as np
from shapely.geometry import LineString, Polygon, Point, box
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[2]


class HanddrawnKinki(unittest.TestCase):
    def test_strokes_connections_and_approved_protection(self):
        draft=json.loads((ROOT/'data/derived/editor/kinki/editor_draft.json').read_text(encoding='utf-8'))
        approved=json.loads((ROOT/'data/derived/political/approved_western/political_registry.json').read_text(encoding='utf-8'))
        lines=[LineString(b['points']) for b in draft['boundaries']]
        self.assertEqual(len(lines),46)
        self.assertEqual(draft['status'],'editor_draft_only')
        coast=LineString(next(iter(draft['coastlines'].values())))
        ids={r['boundary_id'] for r in draft['shared_boundary_references']}
        seam=unary_union([LineString(b['points']) for b in approved['boundaries'] if b['boundary_id'] in ids])
        land=unary_union([Polygon(p) for r in approved['regions'] for p in r['polygons']])
        scale=draft['handdrawn_source']['scale'];offset=np.array(draft['handdrawn_source']['offset'])
        image=cv2.imread(str(ROOT/'data/work/political/kinki_handdrawn/source.png'))
        ink=np.max(image,axis=2)<45
        distance=cv2.distanceTransform((~ink).astype(np.uint8),cv2.DIST_L2,5)
        errors=[]
        for i,line in enumerate(lines):
            self.assertTrue(line.is_valid and line.is_simple)
            self.assertLess(line.intersection(land).length,.01)
            network=unary_union(lines[:i]+lines[i+1:]+[coast,seam])
            for xy in (line.coords[0],line.coords[-1]):
                p=Point(xy)
                self.assertTrue(network.distance(p)<.01 or box(*draft['bounds']).boundary.distance(p)<8*scale, (i,xy))
            for along in np.arange(12*scale,line.length-12*scale,2*scale):
                xy=(np.array(line.interpolate(along).coords[0])-offset)/scale
                x,y=np.rint(xy).astype(int)
                errors.append(float(distance[y,x]))
        self.assertLess(max(errors),2.1)
        report=json.loads((ROOT/'data/work/political/kinki_handdrawn/trace_report.json').read_text(encoding='utf-8'))
        self.assertLess(report['shore_residual_source_px']['p90'],2)


if __name__=='__main__':unittest.main()
