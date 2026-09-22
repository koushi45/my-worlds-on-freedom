import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


class FourthAffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = read(MASTER / 'affiliation_batch4_baseline.json')
        cls.profiles = read(MASTER / 'affiliations_1546.json')['officers']
        cls.report = read(MASTER / 'affiliation_batch4_research.json')
        cls.rows = {r['name']: r for r in cls.report['officers']}

    def test_exactly_100_previously_unplaced_and_1498_unchanged(self):
        selected = set(self.baseline['selected_ids'])
        self.assertEqual(len(selected), 100)
        self.assertEqual(selected, {r['id'] for r in self.rows.values()})
        fifth = read(MASTER / 'affiliation_batch5_baseline.json')
        sixth = read(MASTER / 'affiliation_batch6_baseline.json')
        seventh = read(MASTER / 'affiliation_batch7_baseline.json')
        eighth = read(MASTER / 'affiliation_batch8_baseline.json')
        ninth = read(MASTER / 'affiliation_batch9_baseline.json')
        tenth = read(MASTER / 'affiliation_batch10_baseline.json')
        self.assertEqual(selected | set(fifth['selected_ids']) | set(sixth['selected_ids']) | set(seventh['selected_ids']) | set(eighth['selected_ids']) | set(ninth['selected_ids']) | set(tenth['selected_ids']) | set(read(MASTER / 'affiliation_batch11_baseline.json')['selected_ids']), {q for q, a in self.profiles.items()
                                    if a != self.baseline['officers'][q]})
        for q in selected:
            old, new = self.baseline['officers'][q], self.profiles[q]
            self.assertIsNone(old['district_key'])
            self.assertFalse(old.get('scenario_batch'))
            self.assertFalse(old.get('research_batch'))
            self.assertTrue(new['district_key'])
            self.assertIn(new['role'], {'大名', '大名家一門', '武将', '浪人', '元服前'})

    def test_sources_and_runtime_agree(self):
        for row in self.rows.values():
            self.assertEqual(row['after'], self.profiles[row['id']])
            self.assertTrue(row['after']['placement_reason'])
            self.assertTrue(row['after']['historical_review_note'])
            source = row['sources'][0]
            self.assertEqual(hashlib.sha256((ROOT / source['snapshot_path']).read_bytes()).hexdigest(),
                             source['snapshot_sha256'])

    def test_previous_scores_lineages_and_relationships_preserved(self):
        for file, expected in self.baseline['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((MASTER / file).read_bytes()).hexdigest(), expected)
        current = read(MASTER / 'lineages_baseline.json')
        for key, value in self.baseline['lineages_baseline'].items():
            if key != 'affiliations_sha256':
                self.assertEqual(current[key], value)

    def test_minor_inheritance_uses_only_known_registered_father(self):
        inherited = set()
        for name, row in self.rows.items():
            a = row['after']
            if a['role'] != '元服前':
                continue
            check = a['father_assignment_check']
            if check['status'] == 'inherited':
                inherited.add(name)
                self.assertTrue(self.profiles[check['father_id']]['house_id'])
                self.assertEqual(a['house_id'], self.profiles[check['father_id']]['house_id'])
            else:
                self.assertIsNone(a['house_id'])
        self.assertEqual(inherited, {'小笠原貞慶', '最上義光', '山浦景国', '奥平貞治'})
        self.assertEqual(self.rows['服部正成']['after']['father_assignment_check']['status'],
                         'father_house_unknown')
        self.assertIsNone(self.rows['吉弘鎮信']['after']['house_id'])

    def test_no_activation_for_uncertain_dates_or_minors(self):
        for row in self.rows.values():
            a = row['after']
            if a['availability'] == 'uncertain' or a['role'] == '元服前':
                self.assertFalse(a['can_serve_at_start'], row['name'])
        for name in ['佐野秀綱', '中島可之助', '坪内昌家', '望月千代女']:
            self.assertEqual(self.rows[name]['after']['availability'], 'uncertain')

    def test_late_employers_not_backdated_and_branches_distinguished(self):
        for name in ['服部保長', '服部正成', '前野長宗', '天野雄光', '明石則実', '奥平貞友']:
            self.assertIsNone(self.rows[name]['after']['house_id'])
        self.assertEqual(self.rows['小林房実']['after']['house_id'], 'oyamada_gunnai')
        self.assertEqual(self.rows['日根野景盛']['after']['house_id'], 'hosokawa_izumi')
        self.assertEqual(self.rows['徳島胤順']['after']['house_id'], 'ryuzoji')


if __name__ == '__main__':
    unittest.main()
