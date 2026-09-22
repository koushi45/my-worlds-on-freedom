import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


class LineageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lineages = read('data/master/officers/lineages.json')['officers']
        cls.roster = read('data/derived/officers/officers_1546.json')['officers']
        cls.names = {r['display_name']: r for r in cls.roster}
        cls.families = {r['id']: r for r in read('data/master/officers/lineage_families.json')['families']}

    def profile(self, name):
        return self.lineages[self.names[name]['external_id']]

    def test_full_coverage_without_changing_scores_or_employers(self):
        baseline = read('data/master/officers/lineages_baseline.json')
        self.assertEqual(sorted(self.lineages), baseline['roster_ids'])
        for field, path in [('assessments_sha256', 'assessments.json'), ('affiliations_sha256', 'affiliations_1546.json')]:
            data = read('data/master/officers/' + path)
            digest = hashlib.sha256(json.dumps(data, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
            self.assertEqual(digest, baseline[field])
        for r in self.roster:
            self.assertEqual(r['lineage'], self.lineages[r['external_id']])

    def test_family_references_and_unresolved_not_merged(self):
        for p in self.lineages.values():
            if p['family_id']:
                self.assertIn(p['family_id'], self.families)
                self.assertEqual(p['display_name'], self.families[p['family_id']]['display_name'])
                self.assertTrue(p['source_urls'])
                self.assertNotEqual(p['status'], 'unresolved')
            else:
                self.assertEqual(p['status'], 'unresolved')
            self.assertTrue(p['note'])

    def test_same_surname_different_families(self):
        for a, b in [('本多忠勝', '本多正信'), ('武田信玄', '武田義統'), ('毛利元就', '毛利勝永'), ('上杉謙信', '上杉憲政')]:
            x, y = self.profile(a), self.profile(b)
            self.assertTrue(x['family_id'])
            self.assertTrue(y['family_id'])
            self.assertNotEqual(x['family_id'], y['family_id'])
        self.assertNotEqual(self.lineages['Q5367620']['family_id'], self.lineages['Q7402768']['family_id'])

    def test_birth_family_and_employer_remain_separate(self):
        self.assertEqual(self.profile('六角定治')['display_name'], '六角家')
        self.assertNotIn('六角貞治', self.names)
        self.assertEqual(self.profile('本多忠勝')['display_name'], '本多家（忠勝系）')
        self.assertEqual(self.names['本多忠勝']['affiliation_1546']['availability'], 'not_born')
        self.assertIsNone(self.names['本多忠勝']['start_district_id'])
        self.assertTrue(self.names['本多忠勝']['affiliation_1546']['future_placement_reserved'])
        self.assertEqual(self.names['立花道雪']['affiliation_1546']['house_id'], 'otomo')
        self.assertEqual(self.profile('立花道雪')['family_at_1546_display'], '戸次家')
        self.assertEqual(self.profile('上杉謙信')['family_at_1546_display'], '長尾家（越後・府内）')


if __name__ == '__main__':
    unittest.main()
