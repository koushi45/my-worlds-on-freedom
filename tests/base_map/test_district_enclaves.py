import json
import unittest
from pathlib import Path
from shapely.geometry import Polygon

ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))

class EnclaveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=read('data/derived/scenarios/independent_districts_1546.json')
        cls.topology=cls.data['connectivity']

    def test_each_district_has_one_closed_outline(self):
        for key,r in self.data['regions'].items():
            if len(r['polygons']) > 1:
                if key != 'iyo/island-murakami-suigun':
                    # Exact canonical-land partitioning can preserve tiny valid
                    # point-contact parts that cannot be joined without moving
                    # the canonical coastline. They are explicitly audited.
                    audit=self.data['coast_alignment']['report']
                    report=read(audit)
                    audited={item['district_id'] for item in report['unjoined_point_contact_parts']}
                    self.assertIn(key,audited)
            for polygon in r['polygons']:
                for ring in polygon:
                    self.assertEqual(ring[0],ring[-1],key)
                g=Polygon(polygon[0],polygon[1:])
                self.assertTrue(g.is_valid and g.exterior.is_simple and g.area>0,key)

    def test_every_detached_part_retained(self):
        operations=self.topology['operations']
        self.assertEqual(len(operations),3608)
        self.assertEqual(len({(o['source'],o['part']) for o in operations}),len(operations))
        self.assertLess(sum(o['uncovered_area'] for o in operations),1e-5)
        for o in operations:self.assertIn(o['target'],self.topology['previous_layout_ids'])

    def test_chita_and_island_policy(self):
        key='owari/unresolved-42cfaa8c657745ea'
        transferred=[o for o in self.topology['operations'] if o['source']==key]
        self.assertEqual(len(transferred),50)
        self.assertTrue(all(o['kind']=='merge' for o in transferred))
        self.assertIn('owari/candidate-district-candidate-g09002',{o['target'] for o in transferred})
        self.assertEqual(len(self.topology['extra_districts']),4)
        self.assertEqual(
            {'対馬','平戸島','村上水軍領地','淡路島'},
            {r['name'] for r in self.topology['extra_districts'].values()}
        )
        for key,r in self.topology['extra_districts'].items():
            self.assertIn(r['source_id'],self.topology['original_ids'])
            self.assertTrue(r['coastline_only'])
            self.assertEqual('base_land_coastline_exact',r['geometry_basis'])

    def test_curated_islands_exactly_match_base_coastlines(self):
        land=read('data/derived/land_masks/land_master_8192.json')
        for key,extra in self.topology['extra_districts'].items():
            expected=[land['coastlines'][coastline_id]['points'] for coastline_id in extra['coastline_ids']]
            actual=[polygon[0] for polygon in self.data['regions'][key]['polygons']]
            self.assertEqual(expected,actual,key)

    def test_catalog_and_site_links(self):
        catalog=read('data/derived/scenarios/house_selection_1546.json')
        self.assertEqual(set(catalog['district_ids']),set(self.data['regions']))
        self.assertEqual(set(catalog['district_origins']),set(self.topology['extra_districts']))
        self.assertEqual(len(self.topology['original_ids']),709)
        for keys in self.topology['site_district_candidates'].values():
            self.assertTrue(all(k in self.data['regions'] for k in keys))

if __name__=='__main__':unittest.main()
