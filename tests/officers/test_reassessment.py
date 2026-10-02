import copy
import json
import unittest
from pathlib import Path

from tools.officers.reassess import KEYS, apply_policy, fixed_quantile

ROOT = Path(__file__).resolve().parents[2]


class ReassessmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))
        cls.master = json.loads((ROOT/'data/master/officers/assessments.json').read_text(encoding='utf-8'))
        cls.records = {r['external_id']: r for r in cls.data['officers']}
        cls.reviews = json.loads((ROOT/'data/master/officers/major_failure_reviews.json').read_text(encoding='utf-8'))

    def test_population_totals_bounds_and_source_traceability(self):
        self.assertEqual(len(self.records), 1598)
        sources = {s['id'] for s in self.data['sources']}
        for q, r in self.records.items():
            a = r['assessment']
            self.assertEqual(a['score_policy'], 'historical_mean15_v3')
            self.assertEqual(r['total_ability'], sum(a['scores'].values()))
            self.assertTrue(set(a['source_refs']) <= sources)
            self.assertEqual(a['evidence'], self.master[q]['evidence'])
            for key in KEYS:
                value = a['scores'][key]
                self.assertIs(type(value), int)
                self.assertTrue(1 <= value <= 30)
                p = a['score_provenance'][key]
                self.assertEqual(p['old_score'], self.master[q]['scores'][key])
                self.assertEqual(p['historical_reason'], self.master[q]['score_reasons'][key])
                if p['kind'] in ('imputed', 'participation_inferred'):
                    self.assertTrue(p['bounds'][0] <= value <= p['bounds'][1])
                    self.assertLessEqual(abs(p['calibration_shift']), 2)
                    self.assertEqual(a['score_confidence'][key], 'limited_evidence')
                else:
                    self.assertNotIn('calibration_shift', p)

    def test_mean_and_concentration(self):
        for key in KEYS:
            values = [r['assessment']['scores'][key] for r in self.records.values()]
            self.assertLess(abs(sum(values)/len(values) - 15), 0.01)
            self.assertLess(values.count(12)/len(values), 0.15)
            self.assertLess(max(values.count(v) for v in set(values))/len(values), 0.20)
            self.assertGreater(len(set(values)), 20)

    def test_major_failures_need_explicit_evidence_and_recovery_review(self):
        flagged = {q for q, v in self.reviews['officers'].items() if v['status']=='major_unrecovered_failure'}
        self.assertEqual(len(flagged), 6)
        for q in flagged:
            a = self.records[q]['assessment']
            self.assertTrue(all(3 <= v <= 9 for v in a['scores'].values()))
            self.assertTrue(all(v=='major_unrecovered_failure' for v in a['score_basis'].values()))
            self.assertTrue(a['major_failure_review']['personal_responsibility'])
            self.assertTrue(a['major_failure_review']['recovery_review'])
        self.assertNotIn('Q7450595', flagged)  # Sengoku Hidehisa recovered.
        self.assertGreater(max(self.records['Q7450595']['assessment']['scores'].values()), 9)
        self.assertNotIn('Q11556549', flagged)  # Conflicting shooting accounts.
        for q, r in self.records.items():
            if q not in flagged:
                self.assertNotIn('major_unrecovered_failure', r['assessment']['score_basis'].values())

    def test_rebuild_is_deterministic_and_order_independent(self):
        records = copy.deepcopy(self.data['officers'])
        for r in records:
            r['assessment'] = copy.deepcopy(self.master[r['external_id']])
        records.reverse()
        report = apply_policy(records)
        for r in records:
            expected = self.records[r['external_id']]
            self.assertEqual(r['assessment'], expected['assessment'])
            self.assertEqual(r['total_ability'], expected['total_ability'])
        self.assertEqual(report['population'], 1598)
        with self.assertRaisesRegex(ValueError, 'historical inputs'):
            apply_policy(records)

    def test_fixed_seed_is_per_person_and_per_ability(self):
        self.assertEqual(fixed_quantile('seed','person','trust'), fixed_quantile('seed','person','trust'))
        self.assertNotEqual(fixed_quantile('seed','person','trust'), fixed_quantile('seed','person','command'))
        self.assertNotEqual(fixed_quantile('seed','person','trust'), fixed_quantile('seed','other','trust'))


if __name__=='__main__':
    unittest.main()
