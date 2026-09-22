import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


class RelationshipTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles = read('data/master/officers/relationships.json')['officers']
        cls.roster = read('data/derived/officers/officers_1546.json')['officers']
        cls.byid = {r['external_id']: r for r in cls.roster}
        cls.edges = read('data/master/officers/relationship_evidence.json')['edges']

    def test_coverage_and_runtime_export(self):
        self.assertEqual(set(self.profiles), set(self.byid))
        for q, p in self.profiles.items():
            self.assertEqual(self.byid[q]['relationships'], p)
            for key in ['father', 'mother', 'children', 'parents_unspecified']:
                ids = [x['external_id'] for x in p[key]]
                self.assertEqual(len(ids), len(set(ids)))
                self.assertNotIn(q, ids)
                for x in p[key]:
                    self.assertTrue(x['source_urls'])
                    if x['officer_id']:
                        self.assertEqual(x['officer_id'], self.byid[x['external_id']]['id'])

    def test_parent_child_links_are_reciprocal(self):
        for q, p in self.profiles.items():
            for key in ['father', 'mother', 'parents_unspecified']:
                for parent in p[key]:
                    if parent['external_id'] in self.profiles:
                        self.assertIn(q, [c['external_id'] for c in self.profiles[parent['external_id']]['children']])
            for child in p['children']:
                if child['external_id'] in self.profiles:
                    c = self.profiles[child['external_id']]
                    self.assertIn(q, [v['external_id'] for k in ['father', 'mother', 'parents_unspecified'] for v in c[k]])

    def test_sources_and_adoption_are_retained(self):
        for e in self.edges:
            self.assertTrue(e['evidence'])
            self.assertNotEqual(e['parent'], e['child'])
            for source in e['evidence']:
                self.assertNotEqual(source['rank'], 'deprecated')
                self.assertTrue(source['statement_id'])
                self.assertIn('qualifiers', source)
                self.assertIn('references', source)
            if e['kind'] == '養親子':
                self.assertTrue(any('養' in s or 'adopt' in s.lower() for s in e['qualifier_labels']))

    def test_tadakatsu_and_ieyasu_have_parents_without_changing_start_status(self):
        self.assertIn('Q11093359', [x['external_id'] for x in self.profiles['Q467417']['father']])
        self.assertIn('Q1064935', [x['external_id'] for x in self.profiles['Q171977']['father']])
        self.assertIn('Q5366163', [x['external_id'] for x in self.profiles['Q171977']['mother']])
        self.assertEqual(self.byid['Q467417']['affiliation_1546']['availability'], 'not_born')
        self.assertIsNone(self.byid['Q467417']['start_district_id'])
        self.assertTrue(self.byid['Q467417']['affiliation_1546']['future_placement_reserved'])


if __name__ == '__main__':
    unittest.main()
