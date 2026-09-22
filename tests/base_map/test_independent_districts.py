import json
import unittest
from pathlib import Path
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[2]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def geom(r): return unary_union([Polygon(p[0],p[1:]) for p in r['polygons']])

class IndependentDistrictTests(unittest.TestCase):
    def test_all_existing_ids_and_closed_valid_shapes(self):
        d=read('data/derived/scenarios/independent_districts_1546.json')
        ids={r['key'] for r in read('data/derived/districts/unconfirmed/index.json')['regions']}
        self.assertEqual((ids|set(d['connectivity']['extra_districts']))-set(d['connectivity']['retired_district_ids']),set(d['regions']))
        self.assertEqual(sum(r['basis']=='unclipped_comparison' for r in d['review'].values()),634)
        for r in d['regions'].values():
            g=geom(r)
            self.assertTrue(g.is_valid and not g.is_empty)
            self.assertTrue(g.contains(Point(r['label'])))

    def test_country_crossings_retained(self):
        d=read('data/derived/scenarios/independent_districts_1546.json')['regions']
        countries={r['region_id']:unary_union([Polygon(p) for p in r['polygons']]) for r in read('data/derived/political/approved_western/political_registry.json')['regions']}
        for example in read('tests/base_map/independent_crossings.json'):
            r=d[example['key']];point=Point(example['point'])
            self.assertTrue(geom(r).contains(point))
            self.assertFalse(countries[r['parent']].covers(point))
            old=read(f'data/derived/districts/unconfirmed/{r["parent"]}/geometry.json')
            previous=next(x for x in old['regions'] if x['key']==example['key'])
            self.assertFalse(geom(previous).covers(point))

    def test_user_requested_removals_and_merges_are_applied(self):
        d=read('data/derived/scenarios/independent_districts_1546.json')
        curation=d['user_layout_curation']
        self.assertEqual('applied',curation['status'])
        self.assertEqual({},curation['pending'])
        removals=[item for item in curation['operations'] if item['kind']=='remove']
        merges=[item for item in curation['operations'] if item['kind']=='merge']
        self.assertEqual(15,len(removals))
        self.assertEqual(7,len(merges))
        for item in removals+merges:
            self.assertNotIn(item['source'],d['regions'])
        for item in merges:
            self.assertIn(item['target'],d['regions'])

if __name__=='__main__': unittest.main()
