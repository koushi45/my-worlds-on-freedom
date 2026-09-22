"""Behavioral regressions for near-parallel roads and the unified stroke network."""
import json
import sys
import unittest
from pathlib import Path
from shapely.geometry import LineString, Point
from shapely.ops import unary_union
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from road_sharing import share


class SharingBehavior(unittest.TestCase):
    def setUp(self):
        self.a=[[x,0] for x in range(0,41,2)]
        self.b=[[x,2] for x in range(0,41,2)]

    def test_parallel_reverse_shared_and_endpoints_retained(self):
        for target in [self.a,self.a[::-1]]:
            result,events=share(self.b,target,lambda a,b:True,protected=[self.b[0],self.b[-1]])
            self.assertTrue(events)
            self.assertEqual(result[0],self.b[0]); self.assertEqual(result[-1],self.b[-1])
            self.assertGreater(LineString(result).intersection(LineString(target)).length,30)

    def test_crossing_short_and_distant_are_preserved(self):
        for points in [[[20,y] for y in range(-20,21,2)],[[x,2] for x in range(0,11,2)],[[x,10] for x in range(0,41,2)]]:
            result,events=share(points,self.a,lambda a,b:True)
            self.assertFalse(events); self.assertEqual(result,points)

    def test_river_between_roads_blocks_sharing(self):
        river=LineString([[-10,1],[50,1]])
        result,events=share(self.b,self.a,lambda a,b: not LineString([a,b]).intersects(river))
        self.assertFalse(events); self.assertEqual(result,self.b)

    def test_protected_waypoint_survives(self):
        result,_=share(self.b,self.a,lambda a,b:True,minimum=8,protected=[[20,2]])
        self.assertIn([20,2],result)


class SharedArtifact(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
        cls.data=read('data/derived/road_connections/shared_display.json')
        cls.connections=read('data/derived/road_connections/connections_1582.json')

    def test_no_duplicate_strokes(self):
        lines=[LineString(s['points']) for s in self.data['strokes']]
        tree=STRtree(lines)
        for i,line in enumerate(lines):
            for j in tree.query(line,predicate='intersects'):
                if int(j)>i: self.assertLess(line.intersection(lines[int(j)]).length,1e-5)

    def test_membership_sources_and_connection_coverage(self):
        ids={r['id'] for r in self.connections['routes']}
        for s in self.data['strokes']:
            self.assertTrue(set(s['connection_ids'])<=ids)
            self.assertTrue(s['connection_ids'])
        for r in self.connections['routes']:
            coverage=unary_union([LineString(s['points']) for s in self.data['strokes'] if r['id'] in s['connection_ids']])
            self.assertLess(LineString(r['points']).difference(coverage.buffer(1e-5)).length,1e-4)
            self.assertEqual(r['points'][0],r['original_points'][0])
            self.assertEqual(r['points'][-1],r['original_points'][-1])
            for v in r['fixed_waypoint_mapping']:
                self.assertLess(LineString(r['points']).distance(Point(v['point'])),1e-5)

    def test_inputs_current(self):
        import hashlib
        for p,h in self.data['input_hashes'].items():
            self.assertEqual(hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),h)

    def test_only_estimated_connections_remain(self):
        self.assertFalse((ROOT/'data/derived/roads').exists())
        self.assertFalse((ROOT/'data/sources/roads').exists())
        self.assertNotIn('historical_routes',self.data)
        self.assertEqual(len(self.connections['routes']),285)
        self.assertEqual(self.connections['summary']['site_status_counts'],{'connected':250,'land_exempt':4})
        for stroke in self.data['strokes']:
            self.assertNotIn('historical_ids',stroke)


if __name__=='__main__': unittest.main()
