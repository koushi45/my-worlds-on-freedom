import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'


def read(p):
    return json.loads(p.read_text(encoding='utf-8'))


class TenthAffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = read(MASTER / 'affiliation_batch10_baseline.json')
        cls.profiles = read(MASTER / 'affiliations_1546.json')['officers']
        cls.report = read(MASTER / 'affiliation_batch10_research.json')
        cls.rows = {r['name']: r for r in cls.report['officers']}
        cls.runtime = {r['external_id']: r for r in read(ROOT / 'data/derived/officers/officers_1546.json')['officers']}

    def test_exactly_100_new_districts_and_1498_unchanged(self):
        selected = set(self.baseline['selected_ids'])
        self.assertEqual(len(selected), 100)
        self.assertEqual(selected, {r['id'] for r in self.rows.values()})
        self.assertEqual(selected | set(read(MASTER / 'affiliation_batch11_baseline.json')['selected_ids']), {q for q, a in self.profiles.items() if a != self.baseline['officers'][q]})
        districts = {d['key'] for d in read(ROOT / 'docs/districts/areas/district_areas.json')['rows']}
        for q in selected:
            self.assertIsNone(self.baseline['officers'][q]['district_key'])
            self.assertIn(self.profiles[q]['district_key'], districts)
            self.assertIn(self.profiles[q]['role'], {'大名', '大名家一門', '武将', '浪人', '元服前'})

    def test_research_provenance_and_runtime_agree(self):
        summaries = 0
        for row in self.rows.values():
            self.assertEqual(row['before'], self.baseline['officers'][row['id']])
            self.assertEqual(row['after'], self.profiles[row['id']])
            self.assertEqual(row['after'], self.runtime[row['id']]['affiliation_1546'])
            self.assertTrue(row['after']['historical_review_note'])
            source = row['sources'][0]
            path = ROOT / source['snapshot_path']
            self.assertEqual(source['snapshot_sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
            if source['source_kind'] == 'attributed_editorial_research_summary':
                summaries += 1
                self.assertEqual(read(path)['format'], 'editorial_summary_not_source_transcription')
        self.assertEqual(summaries, 15)

    def test_raw_chronology_preserved_and_34_reservations_inactive(self):
        future = set(self.baseline['future_reserved_ids'])
        self.assertEqual(len(future), 34)
        self.assertEqual(future, {r['id'] for r in self.rows.values() if r['after'].get('future_placement_reserved')})
        for q, original in self.baseline['raw_chronology'].items():
            r = self.runtime[q]
            if original.get('birth_year_range') is not None:
                self.assertEqual(r['source_birth_year_range'], original['birth_year_range'])
            if original.get('death_year_range') is not None:
                self.assertEqual(r['source_death_year_range'], original['death_year_range'])
            self.assertEqual(r['temporal_status'], original['temporal_status'])
            self.assertEqual(r['start_present'], original['start_present'])
            self.assertEqual(r['birth_year_range'][0], r['birth_year_range'][1])
            self.assertEqual(r['death_year_range'][0], r['death_year_range'][1])
        for q in future:
            a, r = self.profiles[q], self.runtime[q]
            self.assertFalse(r['start_present'] or a['can_serve_at_start'])
            self.assertEqual(r['start_service_status'], 'not_born')
            for k in ['start_affiliation', 'start_district_id', 'start_role']:
                self.assertIsNone(r[k])
            self.assertEqual(r['reserved_district_id'], a['district_key'])
            self.assertEqual(r['reserved_affiliation'], a['house_id'])
            self.assertEqual(r['reserved_role'], '元服前')

    def test_father_inheritance_and_house_territory_pools(self):
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
        self.assertEqual(inherited, 11)
        self.assertEqual(self.report['stats']['with_house'], 18)
        self.assertEqual(self.report['stats']['unknown_house'], 82)

    def test_namesakes_are_separate_without_renaming_runtime_people(self):
        shonai, obama = self.rows['酒井忠勝（庄内）'], self.rows['酒井忠勝（小浜）']
        self.assertEqual(shonai['id'], 'Q5367620')
        self.assertEqual(obama['id'], 'Q7402768')
        self.assertEqual(shonai['after']['father_assignment_check']['father_name'], '酒井家次')
        self.assertEqual(obama['after']['father_assignment_check']['father_name'], '酒井忠利')
        for row in [shonai, obama]:
            self.assertEqual(self.runtime[row['id']]['display_name'], '酒井忠勝')
        self.assertIsNone(self.rows['遠山直勝']['after']['father_assignment_check']['father_id'])

    def test_uncertainties_and_geographic_proxies_are_explicit(self):
        for name in ['上林政重', '武田義頼', '国富貞次', '板倉定重']:
            a = self.rows[name]['after']
            self.assertEqual(a['role'], '元服前')
            self.assertFalse(a.get('future_placement_reserved'))
            self.assertFalse(a['can_serve_at_start'])
        for name in ['野口長宗', '渡辺七右衛門', '脇坂左兵衛']:
            a = self.rows[name]['after']
            self.assertEqual(a['district_display'], '阿波国・板野郡')
            self.assertIn('淡路国が現行地図に未収録', a['historical_review_note'])
            self.assertIsNone(a['house_id'])
        self.assertEqual(self.rows['中野一安']['after']['house_id'], 'oda_nobuhide')
        self.assertEqual(self.rows['水越勝重']['after']['house_id'], 'jinbo')
        self.assertIn('実在性', self.rows['六角義実']['after']['historical_review_note'])
        self.assertTrue(all(not r['after']['can_serve_at_start'] for r in self.rows.values()))

    def test_protected_data_and_hash_migration(self):
        for f, digest in self.baseline['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((MASTER / f).read_bytes()).hexdigest(), digest)
        current = read(MASTER / 'lineages_baseline.json')
        for k, v in self.baseline['lineages_baseline'].items():
            if k != 'affiliations_sha256':
                self.assertEqual(current[k], v)
        migration = read(MASTER / 'affiliation_batch10_migration.json')
        self.assertEqual(migration['previous_affiliations_sha256'], self.baseline['lineages_baseline']['affiliations_sha256'])
        canonical = json.dumps(read(MASTER / 'affiliations_1546.json'), ensure_ascii=False, sort_keys=True).encode()
        self.assertEqual(hashlib.sha256(canonical).hexdigest(), current['affiliations_sha256'])
        self.assertEqual(migration['affiliations_sha256'], read(MASTER / 'affiliation_batch11_baseline.json')['lineages_baseline']['affiliations_sha256'])


if __name__ == '__main__':
    unittest.main()
