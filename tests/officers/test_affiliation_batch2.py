import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


class AdditionalAffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = read(MASTER / 'affiliation_batch2_baseline.json')
        cls.profiles = read(MASTER / 'affiliations_1546.json')['officers']
        cls.report = read(MASTER / 'affiliation_batch2_research.json')
        cls.rows = {r['name']: r for r in cls.report['officers']}

    def test_exactly_100_new_placements_and_no_other_changes(self):
        selected = set(self.before['selected_ids'])
        self.assertEqual(len(selected), 100)
        self.assertEqual(selected, {r['id'] for r in self.rows.values()})
        changed = {q for q, a in self.profiles.items() if a != self.before['officers'][q]}
        # The explicitly requested third batch has its own preservation baseline.
        third = read(MASTER / 'affiliation_batch3_baseline.json')
        fourth = read(MASTER / 'affiliation_batch4_baseline.json')
        fifth = read(MASTER / 'affiliation_batch5_baseline.json')
        sixth = read(MASTER / 'affiliation_batch6_baseline.json')
        seventh = read(MASTER / 'affiliation_batch7_baseline.json')
        eighth = read(MASTER / 'affiliation_batch8_baseline.json')
        ninth = read(MASTER / 'affiliation_batch9_baseline.json')
        tenth = read(MASTER / 'affiliation_batch10_baseline.json')
        self.assertEqual(changed, selected | set(third['selected_ids']) | set(fourth['selected_ids']) | set(fifth['selected_ids']) | set(sixth['selected_ids']) | set(seventh['selected_ids']) | set(eighth['selected_ids']) | set(ninth['selected_ids']) | set(tenth['selected_ids']) | set(read(MASTER / 'affiliation_batch11_baseline.json')['selected_ids']))
        for q in selected:
            self.assertIsNone(self.before['officers'][q]['district_key'])
            self.assertFalse(self.before['officers'][q].get('research_batch'))
            self.assertTrue(self.profiles[q]['district_key'])
        for name, digest in self.before['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((MASTER / name).read_bytes()).hexdigest(), digest)

    def test_evidence_snapshots_and_runtime_match_report(self):
        for row in self.rows.values():
            self.assertEqual(row['after'], self.profiles[row['id']])
            self.assertTrue(row['after']['historical_review_note'])
            self.assertTrue(row['after']['placement_reason'])
            source = row['sources'][0]
            self.assertEqual(hashlib.sha256((ROOT / source['snapshot_path']).read_bytes()).hexdigest(), source['snapshot_sha256'])
            self.assertTrue(source['url'].startswith('https://'))

    def test_later_employers_not_backdated(self):
        for name in ['明智光秀', '滝川一益', '村井貞勝', '生駒家長', '大内輝弘']:
            a = self.rows[name]['after']
            self.assertIsNone(a['house_id'])
            self.assertEqual(a['role'], '浪人')
        self.assertTrue(self.rows['大内輝弘']['after']['district_display'].startswith('豊後国'))
        self.assertEqual(self.rows['堀尾吉晴']['after']['house_id'], 'oda_iwakura')
        self.assertEqual(self.rows['千坂景親']['after']['house_id'], 'uesugi_echigo')

    def test_minors_and_uncertain_people_not_activated_by_placement(self):
        for row in self.rows.values():
            a = row['after']
            if a['role'] == '元服前' or a['availability'] == 'uncertain':
                self.assertFalse(a['can_serve_at_start'], row['name'])
        for name in ['小早川繁平', '三沢為清']:
            self.assertEqual(self.rows[name]['after']['role'], '大名')
            self.assertFalse(self.rows[name]['after']['can_serve_at_start'])
        self.assertEqual(self.rows['三木通秋']['after']['role'], '大名')
        self.assertTrue(self.rows['三木通秋']['after']['can_serve_at_start'])
        self.assertEqual(self.rows['上杉朝定']['after']['availability'], 'uncertain')
        self.assertEqual(self.rows['小島弥太郎']['after']['availability'], 'uncertain')

    def test_unknown_employer_does_not_erase_life_date(self):
        self.assertEqual(self.rows['明智光秀']['after']['availability'], 'available')
        self.assertTrue(self.rows['明智光秀']['after']['can_serve_at_start'])


if __name__ == '__main__':
    unittest.main()
