import json
import unittest
from pathlib import Path
from shapely.geometry import Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))

class PriorityTests(unittest.TestCase):
    def test_priorities_and_small_overlaps_resolved(self):
        d=read('data/derived/scenarios/independent_districts_1546.json')
        audit=read('data/master/district_overlap_review.json')
        factor=1/read('data/derived/land_masks/land_master_8192.json')['transform']['uniform_scale_px_per_m']**2/1e6
        geoms={k:Polygon(r['polygons'][0][0]) for k,r in d['regions'].items()}
        expected=read('data/master/district_overlap_decisions.json')['priorities']
        self.assertEqual([(p['loser'],p['winner']) for p in audit['resolution']['priorities']],[(p['loser'],p['winner']) for p in expected])
        for p in audit['resolution']['priorities']:
            self.assertLessEqual(geoms[p['loser_id']].intersection(geoms[p['winner_id']]).area,1e-8)
        # The newly specified winners keep the disputed land, not just a
        # non-overlapping result obtained by deleting both sides.
        for decision in audit['resolution']['priorities'][-2:]:
            pair=next(p for p in audit['before_resolution_pairs'] if {p['a'],p['b']}=={decision['loser_id'],decision['winner_id']})
            overlap=unary_union([Polygon(q[0],q[1:]) for q in pair['polygons']])
            self.assertLess(overlap.difference(geoms[decision['winner_id']]).area*factor,.1)
        transfers=audit['resolution']['reassigned_fragments']
        successors={}
        for priority in audit['resolution']['priorities']:
            successors.setdefault(priority['loser_id'],set()).add(priority['winner_id'])
        for transfer in transfers:
            original=unary_union([Polygon(q[0],q[1:]) for q in transfer['polygons']])
            # A later priority can move an already reassigned fragment onward
            # (for example 香川郡 -> 三木郡 -> 寒川郡). Verify that the land
            # survives anywhere along the final successor chain.
            owners={transfer['target']}
            frontier=list(owners)
            while frontier:
                for successor in successors.get(frontier.pop(),()):
                    if successor not in owners:
                        owners.add(successor)
                        frontier.append(successor)
            final_land=unary_union([geoms[owner] for owner in owners])
            self.assertLess(original.difference(final_land).area*factor,.01)
        western=[p for p in transfers if p['source']=='hyuga/candidate-district-candidate-g69005']
        self.assertEqual(len(western),3)
        self.assertTrue(all(p['target']=='satsuma/candidate-district-candidate-g71013' for p in western))
        self.assertEqual(audit['pending'],[])
        self.assertEqual(len(audit['resolution']['pending_actions']),14)
        for p in audit['resolution']['pending_actions']:
            if 'target' in p:
                original=unary_union([Polygon(q[0],q[1:]) for q in p['polygons']])
                self.assertLess(original.difference(geoms[p['target']]).area*factor,.01)
        keys=sorted(geoms);tree=STRtree([geoms[k] for k in keys]);count=0
        for i,k in enumerate(keys):
            for jj in tree.query(geoms[k]):
                j=int(jj)
                if j<=i:continue
                overlap=geoms[k].intersection(geoms[keys[j]])
                if overlap.area<=1e-8:continue
                count+=1
                ps=[overlap] if overlap.geom_type=='Polygon' else overlap.geoms
                for p in ps:
                    if p.area<=1e-8:continue
                    self.assertGreater(p.area*factor,.01)
                    self.assertFalse(p.area*factor<=.1 and p.buffer(-.15).is_empty)
        self.assertEqual(count,len(audit['pairs']))
        overlay=read('data/derived/scenarios/district_warning_overlay_1546.json')
        self.assertEqual(overlay['normal_pairs'],count)
        self.assertEqual(overlay['pending_count'],0)

if __name__=='__main__':unittest.main()
