import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / 'data/master/officers'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


class RemainingAffiliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = read(MASTER / 'affiliation_batch11_baseline.json')
        cls.profiles = read(MASTER / 'affiliations_1546.json')['officers']
        cls.report = read(MASTER / 'affiliation_batch11_research.json')
        cls.rows = {r['name']: r for r in cls.report['officers']}
        cls.runtime = {r['external_id']: r for r in read(ROOT / 'data/derived/officers/officers_1546.json')['officers']}

    def test_remaining_65_only_and_no_unplaced_people(self):
        ids = set(self.baseline['selected_ids'])
        self.assertEqual(len(ids), 65)
        self.assertEqual(ids, {r['id'] for r in self.rows.values()})
        self.assertEqual(ids, {q for q, a in self.profiles.items() if a != self.baseline['officers'][q]})
        self.assertEqual(len(self.profiles) - len(ids), 1533)
        self.assertEqual(ids, {q for q, a in self.baseline['officers'].items() if not a['district_key']})
        self.assertTrue(all(a['district_key'] for a in self.profiles.values()))
        districts = {d['key'] for d in read(ROOT / 'docs/districts/areas/district_areas.json')['rows']}
        for q in ids:
            self.assertIn(self.profiles[q]['district_key'], districts)
            self.assertIn(self.profiles[q]['role'], {'大名', '大名家一門', '武将', '浪人', '元服前'})

    def test_sources_and_published_records_match(self):
        summaries = 0
        for row in self.rows.values():
            q = row['id']
            self.assertEqual(row['before'], self.baseline['officers'][q])
            self.assertEqual(row['after'], self.profiles[q])
            self.assertEqual(row['after'], self.runtime[q]['affiliation_1546'])
            self.assertTrue(row['after']['historical_review_note'])
            source = row['sources'][0]
            path = ROOT / source['snapshot_path']
            self.assertEqual(source['snapshot_sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
            if source['source_kind'] == 'attributed_editorial_research_summary':
                summaries += 1
                self.assertEqual(read(path)['format'], 'editorial_summary_not_source_transcription')
        self.assertEqual(summaries, 3)

    def test_chronology_preserved_and_all_reference_placements_inactive(self):
        reference = future = 0
        for q, original in self.baseline['raw_chronology'].items():
            r = self.runtime[q]
            self.assertEqual(r['source_birth_year_range'], original.get('birth_year_range'))
            self.assertEqual(r['source_death_year_range'], original.get('death_year_range'))
            self.assertEqual(r['temporal_status'], original['temporal_status'])
            self.assertEqual(r['start_present'], original['start_present'])
            self.assertEqual(r['birth_year_range'][0], r['birth_year_range'][1])
            self.assertEqual(r['death_year_range'][0], r['death_year_range'][1])
        for row in self.rows.values():
            a, r = row['after'], self.runtime[row['id']]
            self.assertFalse(a['can_serve_at_start'])
            for k in ['start_affiliation', 'start_district_id', 'start_role']:
                self.assertIsNone(r[k])
            if a.get('future_placement_reserved'):
                future += 1
                self.assertFalse(r['start_present'])
                self.assertEqual(r['start_service_status'], 'not_born')
                self.assertEqual(r['reserved_district_id'], a['district_key'])
            else:
                reference += 1
                self.assertTrue(a['reference_placement_only'])
                self.assertEqual(r['reference_district_id'], a['district_key'])
                self.assertEqual(r['reference_role'], a['role'])
                if row['before']['availability'] == 'deceased':
                    self.assertEqual(a['availability'], 'deceased')
                    self.assertFalse(r['start_present'])
        self.assertEqual((reference, future), (62, 3))

    def test_house_pools_not_expanded_to_cover_geographic_proxies(self):
        path = MASTER / 'house_placement_pools_1546.json'
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), self.baseline['house_pools_sha256'])
        houses = {h['id']: h for h in read(path)['houses']}
        for row in self.rows.values():
            a = row['after']
            if a['house_id']:
                self.assertEqual(houses[a['house_id']]['pool'], [])
                self.assertTrue(a['geographic_proxy'])
                self.assertIsNone(a['placement_house_id'])
                self.assertIn('領地ではなく', a['placement_reason'])
        self.assertEqual(self.rows['宗晴康']['after']['role'], '大名')
        self.assertEqual(self.rows['宗義調']['after']['role'], '大名家一門')
        self.assertEqual(self.rows['武田元光']['after']['role'], '大名家一門')
        self.assertEqual(self.rows['武田信高 (若狭武田氏)']['after']['house_id'], 'takeda_wakasa')

    def test_only_registered_known_father_is_inherited(self):
        child = self.rows['松前慶広']['after']
        self.assertEqual(child['father_assignment_check']['father_id'], 'Q10514629')
        self.assertEqual(child['house_id'], self.profiles['Q10514629']['house_id'])
        self.assertEqual(child['house_id'], 'kakizaki')
        for name in ['宗義智', '沼田麝香', '長宗我部盛恒']:
            a = self.rows[name]['after']
            self.assertIsNone(a['house_id'])
            self.assertEqual(a['father_assignment_check']['status'], 'father_unregistered_or_unresolved')

    def test_identity_holds_and_reference_labels_are_visible(self):
        for name, text in [('鈴木孫一', '重複'), ('長宗我部盛恒', '疑問符'), ('小田顕家 (常陸国)', '騎西'), ('六角義介', '矛盾'), ('竹田右衛門', '伝来地域')]:
            self.assertIn(text, self.rows[name]['after']['historical_review_note'])
            self.assertFalse(self.rows[name]['after']['can_serve_at_start'])
        report = (ROOT / 'docs/officers/affiliation_research_remaining_65.html').read_text(encoding='utf-8')
        self.assertEqual(report.count('<tr id='), 65)
        self.assertIn('参照用配置（開始時配属なし）', report)
        template = (ROOT / 'tools/officers/roster_template.html').read_text(encoding='utf-8')
        self.assertIn('affiliation_research_remaining_65.html', template)
        self.assertIn('reference_placement_only', template)

    def test_protected_data_and_explicit_hash_migration(self):
        for name, digest in self.baseline['protected_sha256'].items():
            self.assertEqual(hashlib.sha256((MASTER / name).read_bytes()).hexdigest(), digest)
        current = read(MASTER / 'lineages_baseline.json')
        for k, v in self.baseline['lineages_baseline'].items():
            if k != 'affiliations_sha256':
                self.assertEqual(current[k], v)
        migration = read(MASTER / 'affiliation_batch11_migration.json')
        self.assertEqual(migration['previous_affiliations_sha256'], self.baseline['lineages_baseline']['affiliations_sha256'])
        canonical = json.dumps(read(MASTER / 'affiliations_1546.json'), ensure_ascii=False, sort_keys=True).encode()
        self.assertEqual(hashlib.sha256(canonical).hexdigest(), current['affiliations_sha256'])
        self.assertEqual(migration['affiliations_sha256'], current['affiliations_sha256'])


if __name__ == '__main__':
    unittest.main()
