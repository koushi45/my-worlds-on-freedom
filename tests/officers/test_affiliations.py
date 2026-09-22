import hashlib,json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
class AffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.master=read('data/master/officers/affiliations_1546.json')
        cls.profiles=cls.master['officers']
        cls.roster=read('data/derived/officers/officers_1546.json')['officers']
        cls.names={r['display_name']:r for r in cls.roster}
        cls.houses={h['id']:h for h in read('data/master/officers/house_placement_pools_1546.json')['houses']}
        cls.districts={d['key']:d for d in read('docs/districts/areas/district_areas.json')['rows']}
    def test_every_assessed_officer_has_a_profile_and_scores_are_unchanged(self):
        self.assertEqual(set(self.profiles),{r['external_id'] for r in self.roster})
        self.assertEqual(len(self.profiles),1598)
        assessments=read('data/master/officers/assessments.json')
        digest=hashlib.sha256(json.dumps(assessments,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
        self.assertEqual(digest,self.master['assessment_sha256'])
        for r in self.roster:self.assertEqual(r['affiliation_1546'],self.profiles[r['external_id']])
    def test_every_placement_is_within_that_houses_explicit_pool(self):
        for a in self.profiles.values():
            self.assertTrue(a['reason'])
            if a['district_key']:
                self.assertIn(a['district_key'],self.districts)
                placement_house=a.get('placement_house_id',a['house_id'])
                if placement_house:
                    self.assertIn(a['district_key'],self.houses[placement_house]['pool'])
                else:
                    self.assertEqual(a['placement_policy'],'user_scenario_location')
                    self.assertTrue(a['placement_reason'])
                self.assertEqual(a['assignment_kind'],'gameplay_distributed_not_historical_residence')
                self.assertIn(a['status'],['reviewed','provisional','scenario'])
            if a['status'] in ['unborn','deceased','same_year_ambiguous','unresolved']:
                self.assertIsNone(a['district_key'])
                self.assertFalse(a['can_serve_at_start'])
            if '幼少' in a['role']:self.assertFalse(a['can_serve_at_start'])
    def test_user_examples_and_accession_dates(self):
        def p(n):return self.profiles[self.names[n]['external_id']]
        self.assertEqual(p('北条氏康')['house_id'],'hojo')
        self.assertEqual(p('北条氏康')['role'],'大名')
        self.assertTrue(p('北条氏康')['district_display'].startswith(('相模国','伊豆国')))
        self.assertEqual(p('立花道雪')['house_id'],'otomo')
        self.assertEqual(p('立花道雪')['role'],'武将')
        self.assertTrue(p('立花道雪')['district_display'].startswith('豊後国'))
        for n in ['織田信長','大友宗麟','徳川家康','上杉謙信']:
            self.assertNotEqual('大名',p(n)['role'])
        self.assertEqual(p('徳川家康')['house_id'],'matsudaira')
        for n in ['本多忠勝', '伊達政宗']:
            self.assertEqual(p(n)['availability'], 'not_born')
            self.assertTrue(p(n)['future_placement_reserved'])
            self.assertEqual(p(n)['role'], '元服前')
            self.assertFalse(p(n)['can_serve_at_start'])
            self.assertIsNone(self.names[n]['start_affiliation'])
            self.assertIsNone(self.names[n]['start_district_id'])
    def test_balanced_distribution_and_no_1582_expansion(self):
        from collections import Counter
        for h in self.houses.values():
            counts=Counter(a['district_key'] for a in self.profiles.values() if a['house_id']==h['id'] and a['district_key'])
            if h['pool']:
                values=[counts[k] for k in h['pool']]
                self.assertLessEqual(max(values)-min(values),1)
        self.assertTrue(all(k.startswith('aki/') for k in self.houses['mori']['pool']))
        self.assertTrue(all(k.startswith('bungo/') for k in self.houses['otomo']['pool']))
        self.assertNotIn('鹿児島郡',' '.join(self.houses['shimazu']['district_names']))
        self.assertEqual(self.houses['takeda_wakasa']['pool'],[])
if __name__=='__main__':unittest.main()
