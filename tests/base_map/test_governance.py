"""Referential/temporal integrity and reproducible generation of government setup."""
import hashlib
import importlib.util
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/governance'))
import build_governance


class GovernanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = json.loads((ROOT/'data/derived/governance/governance_1546.json').read_text(encoding='utf8'))
        cls.o = {x['id']:x for x in json.loads((ROOT/build_governance.INPUTS['officers']).read_text(encoding='utf8'))['officers']}

    def test_full_coverage(self):
        districts=json.loads((ROOT/build_governance.INPUTS['districts']).read_text(encoding='utf8'))['regions']
        sites=json.loads((ROOT/build_governance.INPUTS['sites']).read_text(encoding='utf8'))['sites']
        self.assertEqual(set(self.g['districts']), {r['key'] for r in districts})
        self.assertEqual(set(self.g['sites']), {r['id'] for r in sites if r['adoption_status']!='excluded'})
        self.assertEqual(self.g['stats']['accepted_sites'],254)

    def test_roster_unchanged(self):
        for path,digest in self.g['input_hashes'].items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),digest,path)

    def test_assignments_match_existing_house_and_availability(self):
        for r in [*self.g['districts'].values(),*self.g['sites'].values()]:
            self.assertIn(r['house_id'],self.g['houses'],r['name'])
            self.assertEqual(r['year'],1546)
            self.assertTrue(r['note'])
            g=r['governor']
            if not g or not g['officer_id']:continue
            a=self.o[g['officer_id']]['affiliation_1546']
            self.assertEqual(a['house_id'],r['house_id'],r['name'])
            self.assertIn(a['role'],['大名','大名家一門','武将'],r['name'])
            self.assertEqual(a['availability'],'available',r['name'])
            b=a.get('birth_reference');d=a.get('death_reference')
            if b:self.assertLessEqual(min(b),1546)
            if d:self.assertGreaterEqual(max(d),1546)

    def test_known_temporal_and_office_exceptions(self):
        sites={s['map_name']:s for s in self.g['sites'].values()}
        self.assertEqual(sites['栃尾城']['governor']['name'],'上杉謙信')
        self.assertEqual(sites['栃尾城']['ruler']['name'],'長尾晴景')
        self.assertEqual(sites['黒井城']['governor']['name'],'荻野秋清')
        self.assertEqual(sites['刈谷城']['governor']['name'],'水野信元')
        self.assertEqual(sites['川越城']['house_id'],'hojo')
        self.assertEqual(sites['水戸城']['house_id'],'edo_mito')
        self.assertEqual(sites['志布志']['house_id'],'shimazu_hoshu')
        self.assertEqual(sites['岩村城']['governor']['name'],'遠山景前')
        self.assertEqual(sites['堺']['house_id'],'sakai_council')
        self.assertIsNone(sites['堺']['governor'])
        self.assertIsNone(sites['三沢城']['governor'],'child ruler must not become an acting governor')
        for s in self.g['sites'].values():
            if s['temporal_status'] in ['not_yet_established','established_during_start_year']:
                self.assertIsNone(s['governor'],s['name'])
                self.assertTrue(s['research_source_ids'],s['name'])

    def test_no_forced_geographic_assignment(self):
        for s in self.g['sites'].values():
            keys=s['district_candidates']
            self.assertTrue(all(k in self.g['districts'] for k in keys))
            if not keys:
                self.assertIsNone(s['district_key'])
                self.assertEqual(s['district_link_status'],'unresolved')
            if len(keys)>1:self.assertEqual(s['district_link_status'],'ambiguous')

    def test_user_directed_iga_ueno_and_shima_ownership(self):
        districts = self.g['districts']
        self.assertEqual(districts['iga/merged-dff55b62903ec44f']['house_id'],'rokkaku')
        self.assertEqual(districts['ise/candidate-district-candidate-g07013']['house_id'],'kitabatake')
        self.assertEqual(self.g['sites']['site_1582_shima_108']['house_id'],'kitabatake')

    def test_reproducible(self):
        original=(ROOT/'data/derived/governance/governance_1546.json').read_bytes()
        build_governance.build()
        self.assertEqual((ROOT/'data/derived/governance/governance_1546.json').read_bytes(),original)


if __name__=='__main__':unittest.main()
