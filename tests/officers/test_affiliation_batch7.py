import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'
def read(p): return json.loads(p.read_text(encoding='utf-8'))


class SeventhAffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = read(MASTER / 'affiliation_batch7_baseline.json')
        cls.profiles = read(MASTER / 'affiliations_1546.json')['officers']
        cls.report = read(MASTER / 'affiliation_batch7_research.json')
        cls.rows = {r['name']: r for r in cls.report['officers']}
        cls.runtime = {r['external_id']: r for r in read(ROOT / 'data/derived/officers/officers_1546.json')['officers']}

    def test_exactly_100_new_placements_and_1498_unchanged(self):
        selected = set(self.baseline['selected_ids'])
        self.assertEqual(len(selected), 100)
        self.assertEqual(selected, {r['id'] for r in self.rows.values()})
        eighth = read(MASTER / 'affiliation_batch8_baseline.json')
        ninth = read(MASTER / 'affiliation_batch9_baseline.json')
        tenth = read(MASTER / 'affiliation_batch10_baseline.json')
        self.assertEqual(selected | set(eighth['selected_ids']) | set(ninth['selected_ids']) | set(tenth['selected_ids']) | set(read(MASTER / 'affiliation_batch11_baseline.json')['selected_ids']), {q for q, a in self.profiles.items() if a != self.baseline['officers'][q]})
        for q in selected:
            old, new = self.baseline['officers'][q], self.profiles[q]
            self.assertIsNone(old['district_key'])
            self.assertFalse(old.get('research_batch') or old.get('scenario_batch'))
            self.assertTrue(new['district_key'])
            self.assertIn(new['role'], {'大名', '大名家一門', '武将', '浪人', '元服前'})

    def test_sources_and_runtime_match_each_decision(self):
        for row in self.rows.values():
            self.assertEqual(row['before'], self.baseline['officers'][row['id']])
            self.assertEqual(row['after'], self.profiles[row['id']])
            self.assertEqual(row['after'], self.runtime[row['id']]['affiliation_1546'])
            self.assertTrue(row['after']['historical_review_note'])
            source = row['sources'][0]
            self.assertEqual(source['snapshot_sha256'], hashlib.sha256((ROOT / source['snapshot_path']).read_bytes()).hexdigest())

    def test_100_future_reservations_never_become_start_assignments(self):
        future = [r for r in self.rows.values() if r['before']['availability'] == 'not_born']
        self.assertEqual(len(future), 100)
        for row in future:
            a, r = row['after'], self.runtime[row['id']]
            self.assertTrue(a['future_placement_reserved'])
            self.assertEqual(a['availability'], 'not_born')
            self.assertEqual(a['role'], '元服前')
            self.assertFalse(a['can_serve_at_start'])
            self.assertEqual(r['temporal_status'], 'unborn')
            self.assertFalse(r['start_present'])
            self.assertEqual(r['start_service_status'], 'not_born')
            self.assertIsNone(r['start_affiliation'])
            self.assertIsNone(r['start_district_id'])
            self.assertIsNone(r['start_role'])
            self.assertEqual(r['reserved_affiliation'], a['house_id'])
            self.assertEqual(r['reserved_district_id'], a['district_key'])
            self.assertEqual(r['reserved_role'], '元服前')
        self.assertTrue(self.rows['本多忠勝']['after']['future_placement_reserved'])

    def test_only_registered_known_fathers_supply_minor_houses(self):
        inherited = 0
        for row in self.rows.values():
            a = row['after']
            if a['role'] != '元服前': continue
            check = a['father_assignment_check']
            if check['status'] == 'inherited':
                inherited += 1
                self.assertTrue(a['house_id'])
                self.assertEqual(a['house_id'], self.profiles[check['father_id']]['house_id'])
            else:
                self.assertIsNone(a['house_id'])
        self.assertEqual(inherited, 40)
        for n in ['津軽為信', '松平信吉', '松平忠頼', '松平家信']:
            self.assertIsNone(self.rows[n]['after']['house_id'])
            self.assertIsNone(self.rows[n]['after']['father_assignment_check']['father_id'])

    def test_same_batch_parent_chains_and_namesakes(self):
        for child, father in [('本多忠政', '本多忠勝'), ('本多忠刻', '本多忠政'), ('有馬直純', '有馬晴信'), ('毛利秀就', '毛利輝元'), ('水野勝俊', '水野勝成')]:
            c, f = self.rows[child], self.rows[father]
            self.assertEqual(c['after']['father_assignment_check']['father_id'], f['id'])
            self.assertTrue(c['after']['house_id'])
            self.assertEqual(c['after']['house_id'], f['after']['house_id'])
        self.assertEqual(self.rows['本多康俊']['after']['father_assignment_check']['father_name'], '酒井忠次')
        self.assertEqual(self.rows['松平忠吉']['after']['father_assignment_check']['father_name'], '徳川家康')
        self.assertIsNone(self.rows['松平信吉']['after']['father_assignment_check']['father_id'])
        self.assertIsNone(self.rows['松平家信']['after']['father_assignment_check']['father_id'])

    def test_unknown_father_houses_and_date_uncertainty_preserved(self):
        for name in ['森成利', '森長可', '直江兼続', '真田信之']:
            self.assertIsNone(self.rows[name]['after']['house_id'])
        self.assertIn('生年不詳', self.rows['明石全登']['after']['historical_review_note'])
        self.assertIn('若狭', self.rows['木下利房']['after']['historical_review_note'])
        for row in self.rows.values():
            self.assertFalse(row['after']['can_serve_at_start'])

    def test_scores_family_relationships_and_baseline_migration(self):
        for f, digest in self.baseline['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((MASTER / f).read_bytes()).hexdigest(), digest)
        current = read(MASTER / 'lineages_baseline.json')
        for k, v in self.baseline['lineages_baseline'].items():
            if k != 'affiliations_sha256': self.assertEqual(current[k], v)
        migration = read(MASTER / 'affiliation_batch7_migration.json')
        self.assertEqual(migration['previous_affiliations_sha256'], self.baseline['lineages_baseline']['affiliations_sha256'])
        self.assertEqual(migration['affiliations_sha256'], read(MASTER / 'affiliation_batch8_baseline.json')['lineages_baseline']['affiliations_sha256'])


if __name__ == '__main__': unittest.main()
