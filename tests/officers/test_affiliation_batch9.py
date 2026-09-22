import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'


def read(p):
    return json.loads(p.read_text(encoding='utf-8'))


class NinthAffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = read(MASTER / 'affiliation_batch9_baseline.json')
        cls.profiles = read(MASTER / 'affiliations_1546.json')['officers']
        cls.report = read(MASTER / 'affiliation_batch9_research.json')
        cls.rows = {r['name']: r for r in cls.report['officers']}
        cls.runtime = {r['external_id']: r for r in read(ROOT / 'data/derived/officers/officers_1546.json')['officers']}

    def test_exactly_100_new_placements_and_other_1498_unchanged(self):
        selected = set(self.baseline['selected_ids'])
        self.assertEqual(len(selected), 100)
        self.assertEqual(selected, {r['id'] for r in self.rows.values()})
        self.assertEqual(selected | set(read(MASTER / 'affiliation_batch10_baseline.json')['selected_ids']) | set(read(MASTER / 'affiliation_batch11_baseline.json')['selected_ids']), {q for q, a in self.profiles.items() if a != self.baseline['officers'][q]})
        districts = {r['key'] for r in read(ROOT / 'docs/districts/areas/district_areas.json')['rows']}
        for q in selected:
            self.assertIsNone(self.baseline['officers'][q]['district_key'])
            self.assertIn(self.profiles[q]['district_key'], districts)
            self.assertIn(self.profiles[q]['role'], {'大名', '大名家一門', '武将', '浪人', '元服前'})

    def test_sources_report_and_runtime_match(self):
        for row in self.rows.values():
            self.assertEqual(row['before'], self.baseline['officers'][row['id']])
            self.assertEqual(row['after'], self.profiles[row['id']])
            self.assertEqual(row['after'], self.runtime[row['id']]['affiliation_1546'])
            self.assertTrue(row['after']['historical_review_note'])
            source = row['sources'][0]
            self.assertEqual(source['snapshot_sha256'], hashlib.sha256((ROOT / source['snapshot_path']).read_bytes()).hexdigest())

    def test_80_future_reservations_do_not_activate_uncertain_births(self):
        future = set(self.baseline['future_reserved_ids'])
        self.assertEqual(len(future), 80)
        self.assertEqual(future, {r['id'] for r in self.rows.values() if r['after'].get('future_placement_reserved')})
        self.assertTrue(any(self.runtime[q]['temporal_status'] == 'unresolved' for q in future))
        for q in future:
            a, r = self.profiles[q], self.runtime[q]
            self.assertIn(r['temporal_status'], ('unborn', 'unresolved'))
            self.assertFalse(r['start_present'] or a['can_serve_at_start'])
            self.assertEqual(r['start_service_status'], 'not_born')
            self.assertEqual(a['role'], '元服前')
            for k in ['start_affiliation', 'start_district_id', 'start_role']:
                self.assertIsNone(r[k])
            self.assertEqual(r['reserved_district_id'], a['district_key'])
            self.assertEqual(r['reserved_affiliation'], a['house_id'])
            self.assertEqual(r['reserved_role'], '元服前')

    def test_minor_house_requires_registered_known_father(self):
        inherited = 0
        houses = {h['id']: h for h in read(MASTER / 'house_placement_pools_1546.json')['houses']}
        for row in self.rows.values():
            a = row['after']
            if a['role'] == '元服前':
                check = a['father_assignment_check']
                if check['status'] == 'inherited':
                    inherited += 1
                    self.assertTrue(a['house_id'])
                    self.assertEqual(a['house_id'], self.profiles[check['father_id']]['house_id'])
                else:
                    self.assertIsNone(a['house_id'])
            if a['house_id']:
                self.assertIn(a['district_key'], houses[a['house_id']]['pool'])
        self.assertEqual(inherited, 32)
        check = self.rows['酒井忠当']['after']['father_assignment_check']
        self.assertEqual(check['father_id'], 'Q5367620')
        self.assertNotEqual(check['father_id'], 'Q7402768')
        self.assertIsNone(self.rows['松平忠利']['after']['father_assignment_check']['father_id'])

    def test_start_minors_and_geographic_substitutions_are_explicit(self):
        for name in ['一柳直末', '牧村利貞', '九鬼嘉隆', '青柳信正']:
            a = self.rows[name]['after']
            self.assertEqual(a['role'], '元服前')
            self.assertFalse(a.get('future_placement_reserved'))
            self.assertFalse(a['can_serve_at_start'])
        for name in ['新城盛継', '新城直継']:
            self.assertEqual(self.rows[name]['after']['district_display'], '岩代国・安達郡')
        self.assertEqual(self.rows['安見勝之']['after']['district_display'], '河内国・讃良郡')
        self.assertIn('志摩国が現行地図に未収録', self.rows['九鬼嘉隆']['after']['historical_review_note'])
        self.assertIn('矛盾', self.rows['桜庭信正']['after']['historical_review_note'])
        self.assertEqual(self.runtime[self.rows['青柳信正']['id']]['temporal_status'], 'unresolved')

    def test_adult_roles_and_unknown_houses_remain_provisional(self):
        for name, house, role in [('飯尾乗連', 'imagawa', '武将'), ('長野吉業', 'aizu_nagano', '大名家一門'), ('小野寺稙道', 'onodera', '大名')]:
            a = self.rows[name]['after']
            self.assertEqual((a['house_id'], a['role']), (house, role))
            self.assertFalse(a['can_serve_at_start'])
        self.assertEqual(self.report['stats']['with_house'], 35)
        self.assertEqual(self.report['stats']['unknown_house'], 65)
        for row in self.rows.values():
            if row['after']['role'] == '浪人':
                self.assertIsNone(row['after']['house_id'])

    def test_scores_lineages_relationships_and_hash_migration(self):
        for f, digest in self.baseline['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((MASTER / f).read_bytes()).hexdigest(), digest)
        current = read(MASTER / 'lineages_baseline.json')
        for k, v in self.baseline['lineages_baseline'].items():
            if k != 'affiliations_sha256':
                self.assertEqual(current[k], v)
        migration = read(MASTER / 'affiliation_batch9_migration.json')
        self.assertEqual(migration['previous_affiliations_sha256'], self.baseline['lineages_baseline']['affiliations_sha256'])
        self.assertEqual(migration['affiliations_sha256'], read(MASTER / 'affiliation_batch10_baseline.json')['lineages_baseline']['affiliations_sha256'])
        canonical = json.dumps(read(MASTER / 'affiliations_1546.json'), ensure_ascii=False, sort_keys=True).encode()
        self.assertEqual(hashlib.sha256(canonical).hexdigest(), current['affiliations_sha256'])


if __name__ == '__main__':
    unittest.main()
