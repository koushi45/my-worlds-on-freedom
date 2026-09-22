import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def read(p):
    return json.loads((ROOT/p).read_text(encoding='utf-8'))

class ScenarioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=read('data/master/officers/affiliations_1546.json')['officers']
        cls.rows={r['name']:r for r in read('data/master/officers/affiliation_scenario_100.json')['officers']}
        cls.houses={h['id']:h for h in read('data/master/officers/house_placement_pools_1546.json')['houses']}

    def test_five_roles_and_availability_are_separate(self):
        self.assertEqual({a['role'] for a in self.data.values()},{'大名','大名家一門','武将','浪人','元服前'})
        for a in self.data.values():
            self.assertTrue(a['historical_role'])
            if a['availability'] in ('deceased','not_born'):
                if a.get('future_placement_reserved'):
                    self.assertEqual(a['availability'], 'not_born')
                    self.assertIn(a['scenario_batch'], ('affiliation_batch6_100', 'affiliation_batch7_100', 'affiliation_batch8_100', 'affiliation_batch9_100', 'affiliation_batch10_100', 'affiliation_batch11_65'))
                    self.assertTrue(a['district_key'])
                elif a.get('reference_placement_only'):
                    self.assertEqual(a['scenario_batch'], 'affiliation_batch11_65')
                    self.assertTrue(a['district_key'])
                else:
                    self.assertIsNone(a['district_key'])
                self.assertFalse(a['can_serve_at_start'])
            if a['role']=='元服前':self.assertFalse(a['can_serve_at_start'])

    def test_named_user_settings(self):
        mori=self.rows['森可成']
        self.assertIsNone(mori['house_id'])
        self.assertEqual(mori['house_display'],'不明')
        self.assertEqual(mori['role'],'浪人')
        self.assertIn(mori['district_key'],self.houses['oda_nobuhide']['pool'])
        self.assertEqual(self.rows['市橋長利']['house_id'],'saito')
        niwa=self.rows['丹羽氏勝']
        self.assertEqual(niwa['house_id'],'oda_nobutsugu')
        self.assertEqual(niwa['role'],'武将')
        self.assertIn(niwa['district_key'],self.houses['oda_nobutsugu']['pool'])
        ikoma=self.rows['生駒親正']
        self.assertIsNone(ikoma['house_id'])
        self.assertEqual(ikoma['role'],'浪人')
        self.assertEqual(ikoma['district_display'],'美濃国・可児郡')

    def test_all_100_have_location_except_two_deceased(self):
        self.assertEqual(len(self.rows),100)
        unplaced=[r for r in self.rows.values() if r.get('reference_placement_only')]
        self.assertEqual({r['name'] for r in unplaced},{'長野顕業','村上隆勝'})
        for r in unplaced:self.assertEqual(r['availability'],'deceased')
        for r in self.rows.values():
            if r.get('scenario_override'):self.assertTrue(r['placement_reason'])

    def test_research_uncertainty_is_not_rewritten_as_fact(self):
        a=self.rows['島津忠親']
        self.assertEqual(a['historical_status'],'same_year_ambiguous')
        self.assertEqual(a['availability'],'uncertain')
        self.assertIsNone(a['house_id'])
        self.assertIsNotNone(a['district_key'])
        self.assertFalse(self.rows['大井貞隆']['can_serve_at_start'])
