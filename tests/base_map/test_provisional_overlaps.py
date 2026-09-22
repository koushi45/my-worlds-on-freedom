import json
import unittest
from pathlib import Path
from shapely.geometry import Polygon
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))

class OverlapTests(unittest.TestCase):
    def test_retired_remnants_removed_as_district_units(self):
        data=read('data/derived/scenarios/independent_districts_1546.json')
        audit=read('data/master/district_overlap_review.json')
        catalog=read('data/derived/scenarios/house_selection_1546.json')
        outlines=read('data/derived/scenarios/district_outlines_1546.json')
        retired={r['id'] for r in audit['retired_remnants']}
        self.assertIn('owari/unresolved-42cfaa8c657745ea',retired)
        for ids in [data['regions'],catalog['district_ids'],outlines]:
            self.assertFalse(retired.intersection(ids))
            self.assertEqual(set(ids),set(data['regions']))
        for refs in data['connectivity']['site_district_candidates'].values():
            self.assertFalse(retired.intersection(refs))
        self.assertEqual(len(catalog['overlap_layout_ids']),782)
        self.assertEqual(len(data['connectivity']['extra_districts']),4)

    def test_provisional_overlap_removed_normal_disputes_preserved(self):
        data=read('data/derived/scenarios/independent_districts_1546.json')
        audit=read('data/master/district_overlap_review.json')
        provisional={p['id'] for p in audit['changes']}
        normal={(p['a'],p['b']):p['world_area'] for p in audit['pairs'] if not p['provisional_count']}
        keys=sorted(data['regions']); geoms=[Polygon(data['regions'][k]['polygons'][0][0],data['regions'][k]['polygons'][0][1:]) for k in keys]
        tree=STRtree(geoms); seen=set()
        for i,a in enumerate(geoms):
            for j in tree.query(a):
                if j<=i:continue
                area=a.intersection(geoms[j]).area
                # Match the documented double-precision area floor used by
                # coastline alignment verification. Overlay re-noding can
                # leave sub-1e-5 slivers that are not gameplay overlaps.
                if area<=1e-5:continue
                pair=(keys[i],keys[j])
                self.assertFalse(set(pair)&provisional,pair)
                self.assertAlmostEqual(area,normal[pair],delta=1e-5)
                seen.add(pair)
        self.assertEqual(seen,set(normal))
        chita=next(p for p in audit['changes'] if p['id']=='owari/unresolved-42cfaa8c657745ea')
        self.assertGreater(chita['removed_km2'],78)
        self.assertLess(chita['remaining_area']/chita['before_area'],0.001)
        self.assertTrue(any('仮2' in p['name'] for p in audit['changes']))

if __name__=='__main__':unittest.main()
