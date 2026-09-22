import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


class ThirdAffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = read(MASTER / 'affiliation_batch3_baseline.json')
        cls.profiles = read(MASTER / 'affiliations_1546.json')['officers']
        cls.report = read(MASTER / 'affiliation_batch3_research.json')
        cls.rows = {x['name']: x for x in cls.report['officers']}

    def test_exactly_100_new_people_and_all_have_role_and_district(self):
        selected = set(self.baseline['selected_ids'])
        self.assertEqual(len(selected), 100)
        self.assertEqual(selected, {x['id'] for x in self.rows.values()})
        changed = {q for q, a in self.profiles.items() if a != self.baseline['officers'][q]}
        fourth = read(MASTER / 'affiliation_batch4_baseline.json')
        fifth = read(MASTER / 'affiliation_batch5_baseline.json')
        sixth = read(MASTER / 'affiliation_batch6_baseline.json')
        seventh = read(MASTER / 'affiliation_batch7_baseline.json')
        eighth = read(MASTER / 'affiliation_batch8_baseline.json')
        ninth = read(MASTER / 'affiliation_batch9_baseline.json')
        tenth = read(MASTER / 'affiliation_batch10_baseline.json')
        self.assertEqual(changed, selected | set(fourth['selected_ids']) | set(fifth['selected_ids']) | set(sixth['selected_ids']) | set(seventh['selected_ids']) | set(eighth['selected_ids']) | set(ninth['selected_ids']) | set(tenth['selected_ids']) | set(read(MASTER / 'affiliation_batch11_baseline.json')['selected_ids']))
        for q in selected:
            before = self.baseline['officers'][q]
            self.assertFalse(before['district_key'])
            self.assertFalse(before.get('research_batch'))
            self.assertFalse(before.get('scenario_batch'))
            a = self.profiles[q]
            self.assertTrue(a['district_key'])
            self.assertIn(a['role'], {'大名', '大名家一門', '武将', '浪人', '元服前'})

    def test_scores_families_and_relationships_unchanged(self):
        for file, expected in self.baseline['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((MASTER / file).read_bytes()).hexdigest(), expected)
        original = self.baseline['lineages_baseline']
        current = read(MASTER / 'lineages_baseline.json')
        for k in original:
            if k != 'affiliations_sha256':
                self.assertEqual(original[k], current[k])

    def test_every_decision_has_sources_and_matches_runtime(self):
        for row in self.rows.values():
            self.assertEqual(row['after'], self.profiles[row['id']])
            self.assertTrue(row['after']['historical_review_note'])
            self.assertTrue(row['after']['placement_reason'])
            src = row['sources'][0]
            self.assertTrue(src['url'].startswith('https://'))
            self.assertEqual(hashlib.sha256((ROOT / src['snapshot_path']).read_bytes()).hexdigest(), src['snapshot_sha256'])

    def test_father_affiliation_only_inherited_when_registered_and_known(self):
        inherited = 0
        for row in self.rows.values():
            a = row['after']
            check = a.get('father_assignment_check')
            if not check:
                continue
            if check['status'] == 'inherited':
                inherited += 1
                self.assertIn(check['father_id'], self.profiles)
                self.assertTrue(self.profiles[check['father_id']]['house_id'])
                self.assertEqual(a['house_id'], self.profiles[check['father_id']]['house_id'])
                self.assertEqual(a['role'], '元服前')
            else:
                self.assertIsNone(a['house_id'])
        self.assertEqual(inherited, 8)
        self.assertEqual(self.rows['池田知正']['after']['house_id'], 'ikeda_settsu')
        self.assertEqual(self.rows['池田長正']['after']['role'], '大名家一門')
        self.assertIsNone(self.rows['跡部昌忠']['after']['house_id'])
        self.assertIsNone(self.rows['跡部勝忠']['after']['house_id'])

    def test_temporal_uncertainty_not_resolved_by_placement(self):
        for row in self.rows.values():
            a = row['after']
            if a['role'] == '元服前' or a['availability'] == 'uncertain':
                self.assertFalse(a['can_serve_at_start'], row['name'])
        for name in ['国分盛廉', 'ヤジロウ', '内藤源左衛門', '仙石定盛']:
            self.assertEqual(self.rows[name]['after']['availability'], 'uncertain')

    def test_late_employers_and_same_surnames_not_collapsed(self):
        for name in ['乾和信', '新庄直忠', '長崎元家', '三木清閑']:
            self.assertIsNone(self.rows[name]['after']['house_id'])
        self.assertEqual(self.rows['伊丹総堅']['after']['house_id'], 'hatakeyama_noto')
        self.assertEqual(self.rows['伊勢貞就']['after']['house_id'], 'hojo')
        self.assertNotEqual(self.rows['松平元心']['after']['house_id'], self.rows['松平重吉']['after']['house_id'])


if __name__ == '__main__':
    unittest.main()
