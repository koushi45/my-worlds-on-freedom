import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(p):
    return json.loads((ROOT / p).read_text(encoding='utf-8'))


class AffiliationResearchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = read('data/master/officers/affiliation_research_100_baseline.json')
        cls.report = read('data/master/officers/affiliation_research_100.json')
        cls.profiles = read('data/master/officers/affiliation_historical_1546.json')['officers']
        cls.rows = {r['name']: r for r in cls.report['officers']}

    def test_only_the_selected_unknown_100_change(self):
        selected = set(self.baseline['selected_ids'])
        self.assertEqual(len(selected), 100)
        self.assertEqual(selected, {r['external_id'] for r in self.rows.values()})
        changed = {q for q, old in self.baseline['officers'].items() if old != self.profiles[q]}
        self.assertEqual(changed, selected)
        for q in selected:
            self.assertEqual(self.baseline['officers'][q]['status'], 'unresolved')

    def test_scores_lineages_and_relationships_are_byte_identical(self):
        for name, expected in self.baseline['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((ROOT / 'data/master/officers' / name).read_bytes()).hexdigest(), expected, name)

    def test_each_decision_is_traceable_to_a_source_and_runtime(self):
        for row in self.rows.values():
            self.assertEqual(row['after'], self.profiles[row['external_id']])
            self.assertEqual(row['before'], self.baseline['officers'][row['external_id']])
            self.assertTrue(row['remaining'])
            self.assertTrue(row['sources'])
            for source in row['sources']:
                for key in ('url', 'title', 'publisher', 'locator', 'scope'):
                    self.assertTrue(source[key])
            self.assertIn('取得版', row['sources'][0]['title'])
            self.assertTrue((ROOT / row['sources'][0]['cached_path']).exists())

    def test_dated_identity_and_accession_corrections(self):
        def p(n):
            return self.rows[n]['after']
        self.assertEqual(p('福原貞俊')['death_reference'], [1593, 1593])
        self.assertEqual(p('福原貞俊')['house_id'], 'mori')
        for name in ('長野顕業', '村上隆勝'):
            self.assertEqual(p(name)['status'], 'deceased')
            self.assertIsNone(p(name)['district_key'])
        self.assertEqual(p('島津忠親')['status'], 'same_year_ambiguous')
        self.assertEqual(p('島津忠親')['reference_house_ids'], ['hongo', 'shimazu_hoshu'])
        self.assertIsNone(p('島津忠親')['district_key'])
        self.assertEqual(p('水野信近')['house_id'], 'mizuno')
        self.assertIn('刈谷継承前', p('水野信近')['role'])
        self.assertIn('1550年', p('水野信近')['reason'])

    def test_distinct_branches_and_non_service_roles(self):
        def p(n):
            return self.rows[n]['after']
        self.assertEqual(p('大崎義宣')['house_id'], 'osaki_yoshinobu')
        self.assertNotEqual(p('大崎義宣')['house_id'], p('一栗放牛')['house_id'])
        self.assertNotEqual(p('松平清善')['house_id'], p('本多重次')['house_id'])
        self.assertEqual(p('島津忠兼')['house_id'], 'shimazu_sasshu')
        for name in ('前田利家', '丹羽長秀', '松平清宗', '本多忠真', '能美賢次', '山内直通', '杉坊明算'):
            self.assertFalse(p(name)['can_serve_at_start'], name)
        self.assertEqual(p('高山友照')['district_display'], '摂津国・川辺郡')

    def test_report_counts_and_existing_house_pools(self):
        self.assertEqual(len(self.rows), 100)
        self.assertEqual(sum(bool(r['after']['district_key']) for r in self.rows.values()), 66)
        houses = {h['id']: h for h in read('data/master/officers/house_placement_pools_1546.json')['houses']}
        for old in self.baseline['houses']:
            self.assertEqual(houses[old['id']], old)


if __name__ == '__main__':
    unittest.main()
