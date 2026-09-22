import hashlib
import importlib.util
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('roster',ROOT/'tools/officers/build_roster.py')
roster=importlib.util.module_from_spec(spec);spec.loader.exec_module(roster)

class RosterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data=json.loads((ROOT/'data/derived/officers/officers_1546.json').read_text(encoding='utf-8'))
        cls.records={r['external_id']:r for r in cls.data['officers']}

    def test_date_precision_is_not_fabricated(self):
        def claim(year,precision):return [{'used':True,'value':{'time':f'+{year:04d}-00-00T00:00:00Z','precision':precision}}]
        self.assertEqual(roster.year_range(claim(1600,7)),[1501,1600])
        self.assertEqual(roster.year_range(claim(1520,8)),[1520,1529])
        self.assertEqual(roster.year_range(claim(1546,9)),[1546,1546])
        self.assertIsNone(roster.year_range([{'used':True,'value':{}}]))

    def test_temporal_boundary_and_missing_dates(self):
        self.assertEqual(roster.classify([1534,1534],[1582,1582])[0],'alive')
        self.assertEqual(roster.classify([1546,1546],[1598,1598])[0],'same_year_ambiguous')
        self.assertEqual(roster.classify([1520,1520],[1546,1546])[0],'same_year_ambiguous')
        self.assertEqual(roster.classify(None,[1582,1582])[0],'unresolved')
        self.assertEqual(roster.classify([1501,1600],[1582,1582])[0],'unresolved')
        self.assertEqual(roster.classify([1547,1547],[1611,1611])[0],'excluded')
        self.assertEqual(roster.classify([1500,1500],[1545,1545])[0],'excluded')

    def test_game_dates_are_complete_exact_and_traceable(self):
        for r in self.records.values():
            self.assertEqual(len(r['birth_year_range']),2)
            self.assertEqual(len(r['death_year_range']),2)
            self.assertEqual(r['birth_year_range'][0],r['birth_year_range'][1])
            self.assertEqual(r['death_year_range'][0],r['death_year_range'][1])
            self.assertIn('birth_year_estimated',r)
            self.assertIn('death_year_estimated',r)
            if r['source_birth_year_range']:
                self.assertEqual(r['birth_year_range'][0],r['source_birth_year_range'][0])
            if r['source_death_year_range']:
                self.assertEqual(r['death_year_range'][0],r['source_death_year_range'][1])
            if r['death_year_basis']=='estimated_from_birth_and_lifespan':
                self.assertTrue(55<=r['death_year_range'][0]-r['birth_year_range'][0]<=70)

    def test_child_and_ambiguous_are_not_service_assignments(self):
        for q in ['Q171411','Q187550','Q171977']:
            self.assertTrue(self.records[q]['start_present'])
        for q in ['Q187550','Q171977']:self.assertEqual(self.records[q]['life_stage'],'child')
        self.assertEqual(self.records['Q171411']['life_stage'],'genpuku_recorded')
        self.assertFalse(self.records['Q907019']['start_present'])
        self.assertEqual(self.records['Q907019']['temporal_status'],'same_year_ambiguous')
        for r in self.records.values():
            if r['affiliation_1546'].get('future_placement_reserved'):
                self.assertIsNone(r['start_affiliation'])
                self.assertIsNone(r['start_district_id'])
                self.assertEqual(r['reserved_affiliation'], r['affiliation_1546']['house_id'])
            elif r['affiliation_1546'].get('reference_placement_only'):
                self.assertIsNone(r['start_affiliation'])
                self.assertIsNone(r['start_district_id'])
                self.assertEqual(r['reference_district_id'], r['affiliation_1546']['district_key'])
            else:
                self.assertEqual(r['start_affiliation'],r['affiliation_1546']['house_id'])
            self.assertIsNone(r['start_settlement_id'])
            self.assertEqual(r['start_service_status'],'not_born' if r['temporal_status']=='unborn' or r['affiliation_1546'].get('future_placement_reserved') else 'unassigned')

    def test_source_collision_is_retained_outside_roster(self):
        self.assertNotIn('Q17192875',self.records)
        self.assertIn('Q1036482',self.records)
        self.assertEqual(self.records['Q5994890']['birth_year_range'],[1536,1536])

    def test_scores_and_source_references(self):
        sources={s['id'] for s in self.data['sources']}
        for r in self.records.values():
            a=r['assessment']
            self.assertEqual(a['basis'],'lifetime')
            self.assertEqual(set(a['scores']),set(roster.ATTRS))
            for value in a['scores'].values():
                self.assertTrue(value is None or type(value) is int and 1<=value<=30)
            self.assertTrue(set(a['source_refs'])<=sources)
            if a['status']=='unrated':self.assertTrue(all(v is None for v in a['scores'].values()))

    def test_major_sixty_are_fully_rated(self):
        self.assertEqual(self.data['score_scale'],{'min':1,'max':30,'step':1,'unknown':None})
        people=[r for r in self.records.values() if r['assessment'].get('cohort')=='major_60']
        self.assertEqual(len(people),60)
        self.assertEqual(self.data['stats']['fully_assessed_people'],1598)
        self.assertEqual(self.data['stats']['assessed_people'],1598)
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            self.assertEqual(set(a['score_reasons']),set(roster.ATTRS))
            self.assertEqual(set(a['score_confidence']),set(roster.ATTRS))
            for k in roster.ATTRS:
                self.assertIs(type(a['scores'][k]),int)
                self.assertTrue(a['score_reasons'][k])
        self.assertTrue(any(r['assessment']['scores']['command']%5 for r in people))
        self.assertEqual(len(self.records),1598)

    def test_second_cohort_and_new_scoring_policy(self):
        people=[r for r in self.records.values() if r['assessment'].get('cohort')=='next_60']
        self.assertEqual(len(people),60)
        selection=json.loads((ROOT/'data/master/officers/next_60_selection.json').read_text(encoding='utf-8'))
        self.assertEqual({r['external_id'] for r in people},{r['external_id'] for r in selection['officers']})
        for r in people:
            a=r['assessment']
            self.assertEqual(set(a['score_basis']),set(roster.ATTRS))
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertIs(type(a['scores'][k]),int)
                self.assertTrue(a['score_reasons'][k])
                if a['score_basis'][k]=='no_record':self.assertTrue(11<=a['scores'][k]<=13)
                if a['score_basis'][k]=='failure_only':self.assertTrue(4<=a['scores'][k]<=6)
                if a['score_basis'][k]=='participation_standard':self.assertTrue(14<=a['scores'][k]<=22)
        previous={r['external_id']:r['assessment'] for r in self.records.values() if r['assessment'].get('cohort')=='major_60'}
        digest=hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
        self.assertEqual(digest,selection['original_major_60_sha256'])

    def test_third_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/third_60_selection.json').read_text(encoding='utf-8'))
        people=[r for r in self.records.values() if r['assessment'].get('cohort')=='third_60']
        self.assertEqual(len(people),60)
        self.assertEqual({r['external_id'] for r in people},{r['external_id'] for r in selection['officers']})
        self.assertEqual(sorted(r['assessment']['selection_rank'] for r in people),list(range(1,61)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60')}
        digest=hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
        self.assertEqual(digest,selection['previous_120_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_fourth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/fourth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='fourth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60')}
        self.assertEqual(len(previous),180)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_180_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_fifth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/fifth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='fifth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100')}
        self.assertEqual(len(previous),280)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_280_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_sixth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/sixth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='sixth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100')}
        self.assertEqual(len(previous),380)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_380_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_seventh_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/seventh_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='seventh_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100')}
        self.assertEqual(len(previous),480)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_480_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_eighth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/eighth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='eighth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100')}
        self.assertEqual(len(previous),580)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_580_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_ninth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/ninth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='ninth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100')}
        self.assertEqual(len(previous),680)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_680_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_tenth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/tenth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='tenth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100')}
        self.assertEqual(len(previous),780)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_780_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_eleventh_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/eleventh_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='eleventh_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100')}
        self.assertEqual(len(previous),880)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_880_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_twelfth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/twelfth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='twelfth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100')}
        self.assertEqual(len(previous),980)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_980_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_thirteenth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/thirteenth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='thirteenth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100')}
        self.assertEqual(len(previous),1080)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_1080_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_fourteenth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/fourteenth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='fourteenth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100')}
        self.assertEqual(len(previous),1180)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_1180_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_fifteenth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/fifteenth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='fifteenth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100')}
        self.assertEqual(len(previous),1280)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_1280_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_total_ability_including_unknown(self):
        self.assertEqual(roster.total_ability(dict.fromkeys(roster.ATTRS,30)),150)
        self.assertEqual(roster.total_ability(dict.fromkeys(roster.ATTRS,1)),5)
        self.assertIsNone(roster.total_ability({'command':30}))
        for r in self.records.values():
            scores=r['assessment']['scores']
            expected=sum(scores.values()) if all(v is not None for v in scores.values()) else None
            self.assertEqual(r['total_ability'],expected)
        self.assertEqual(self.records['Q311183']['total_ability'],132)
        self.assertEqual(self.records['Q11392554']['total_ability'],60)

    def test_unborn_notable_officers_are_registered_not_deployed(self):
        for q,year in [('Q467417',1548),('Q311183',1567)]:
            r=self.records[q]
            self.assertEqual(r['birth_year_range'],[year,year])
            self.assertEqual(r['temporal_status'],'unborn')
            self.assertFalse(r['start_present'])
            self.assertEqual(r['life_stage'],'unborn')
            self.assertEqual(r['start_service_status'],'not_born')
            self.assertIsNone(r['age_range_at_start'])
        m=json.loads((ROOT/'data/master/officers/notable_registration.json').read_text(encoding='utf-8'))
        self.assertEqual(m['missing'],[])
        self.assertEqual(len(m['officers']),353)
        for r in m['officers']:self.assertIn(r['external_id'],self.records)
        self.assertNotIn('Q11383478',self.records)
        self.assertNotIn('Q11383431',self.records)
        self.assertIn('Q1133798',self.records)
        self.assertIn('Q1071525',self.records)
        self.assertNotEqual(self.records['Q1188704']['display_name'],self.records['Q115596114']['display_name'])
        self.assertTrue(all(not r['start_present'] and r['age_range_at_start'] is None for r in self.records.values() if r['temporal_status']=='unborn'))

    def test_fourteenth_registration_is_unborn_and_assessed(self):
        manifest=json.loads((ROOT/'data/master/officers/fourteenth_registration.json').read_text(encoding='utf-8'))
        self.assertEqual(len(manifest['officers']),60)
        self.assertEqual(len({r['external_id'] for r in manifest['officers']}),60)
        for item in manifest['officers']:
            r=self.records[item['external_id']]
            self.assertEqual(r['assessment']['cohort'],'fourteenth_100')
            self.assertEqual(r['temporal_status'],'unborn')
            self.assertFalse(r['start_present'])
            self.assertEqual(r['start_service_status'],'not_born')
            self.assertTrue(r['decision']['source_urls'])

    def test_fifteenth_registration_identity_and_temporal_separation(self):
        manifest=json.loads((ROOT/'data/master/officers/fifteenth_registration.json').read_text(encoding='utf-8'))
        self.assertEqual(len(manifest['officers']),100)
        self.assertEqual(len({r['external_id'] for r in manifest['officers']}),100)
        for item in manifest['officers']:
            r=self.records[item['external_id']]
            self.assertEqual(r['assessment']['cohort'],'fifteenth_100')
            self.assertTrue(r['decision']['source_urls'])
            if r['temporal_status']=='unborn':
                self.assertFalse(r['start_present'])
                self.assertEqual(r['start_service_status'],'not_born')
        self.assertEqual(self.records['Q193344']['temporal_status'],'unborn')
        self.assertEqual(self.records['Q193344']['total_ability'],86)
        self.assertEqual(self.records['Q193344']['assessment']['score_basis']['tactics'],'participation_standard')
        titles={r['wikipedia_title'] for r in manifest['officers']}
        self.assertIn('島津忠長 (宮之城家)',titles)
        self.assertIn('真田幸昌',titles)
        self.assertIn('長岡休無',titles)

    def test_sixteenth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/sixteenth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='sixteenth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100','fifteenth_100')}
        self.assertEqual(len(previous),1380)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_1380_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_sixteenth_registration_identity_and_temporal_separation(self):
        manifest=json.loads((ROOT/'data/master/officers/sixteenth_registration.json').read_text(encoding='utf-8'))
        self.assertEqual(len(manifest['officers']),100)
        self.assertEqual(len({r['external_id'] for r in manifest['officers']}),100)
        for item in manifest['officers']:
            r=self.records[item['external_id']]
            self.assertEqual(r['assessment']['cohort'],'sixteenth_100')
            self.assertTrue(r['decision']['source_urls'])
            if r['temporal_status']=='unborn':
                self.assertFalse(r['start_present'])
                self.assertEqual(r['start_service_status'],'not_born')
        self.assertEqual(self.records['Q8081582']['temporal_status'],'unborn')
        self.assertEqual(self.records['Q8081582']['total_ability'],101)
        self.assertEqual(self.records['Q8081582']['assessment']['score_basis']['tactics'],'participation_standard')
        titles={r['wikipedia_title'] for r in manifest['officers']}
        self.assertIn('酒井忠勝 (出羽国庄内藩主)',titles)
        self.assertIn('伊達宗実 (亘理伊達家)',titles)
        self.assertIn('伊達宗清 (吉岡伊達家)',titles)

        self.assertNotIn('伊達宗綱',titles)
        self.assertIn('松平清善',titles)

    def test_seventeenth_cohort_and_previous_scores_preserved(self):
        selection=json.loads((ROOT/'data/master/officers/seventeenth_100_selection.json').read_text(encoding='utf-8'))
        people=sorted((r for r in self.records.values() if r['assessment'].get('cohort')=='seventeenth_100'),key=lambda r:r['assessment']['selection_rank'])
        self.assertEqual(len(people),100)
        self.assertEqual([r['external_id'] for r in people],[r['external_id'] for r in selection['officers']])
        self.assertEqual([r['assessment']['selection_rank'] for r in people],list(range(1,101)))
        previous={q:r['assessment'] for q,r in self.records.items() if r['assessment'].get('cohort') in ('major_60','next_60','third_60','fourth_100','fifth_100','sixth_100','seventh_100','eighth_100','ninth_100','tenth_100','eleventh_100','twelfth_100','thirteenth_100','fourteenth_100','fifteenth_100','sixteenth_100')}
        self.assertEqual(len(previous),1480)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),selection['previous_1480_sha256'])
        for r in people:
            a=r['assessment']
            self.assertTrue(a['source_refs'])
            for k in roster.ATTRS:
                self.assertTrue(a['score_reasons'][k])
                bounds={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                self.assertTrue(bounds[0]<=a['scores'][k]<=bounds[1],(r['display_name'],k))

    def test_seventeenth_only_rates_existing_unrated_people(self):
        base=json.loads((ROOT/'data/master/officers/seventeenth_100_baseline.json').read_text(encoding='utf-8'))
        selected={q for q,r in self.records.items() if r['assessment'].get('cohort')=='seventeenth_100'}
        review=json.loads((ROOT/'data/master/officers/remaining_40_review.json').read_text(encoding='utf-8'))
        remaining={r['external_id'] for r in review}
        moved={r['external_id'] for r in review if r['outcome']!='rated'}
        self.assertEqual(set(self.records)|moved,set(base['roster_ids']))
        self.assertEqual(len(selected),100)
        self.assertEqual(len(remaining),40)
        self.assertFalse(selected & remaining)
        self.assertEqual(selected | remaining,set(base['unrated_ids']))
        self.assertFalse(any(r['assessment']['status']=='unrated' for r in self.records.values()))
        for q in ['Q11457027','Q7677166','Q11606011','Q108781100']:
            self.assertFalse(self.records[q]['start_present'])
            self.assertIsNone(self.records[q]['age_range_at_start'])
        self.assertEqual(self.records['Q108781100']['temporal_status'],'unborn')

    def test_remaining_review_preserves_scores_and_separates_scope(self):
        master=ROOT/'data/master/officers'
        base=json.loads((master/'remaining_40_baseline.json').read_text(encoding='utf-8'))
        review=json.loads((master/'remaining_40_review.json').read_text(encoding='utf-8'))
        assessments=json.loads((master/'assessments.json').read_text(encoding='utf-8'))
        excluded={r['external_id']:r for r in json.loads((ROOT/'docs/officers/excluded_candidates.json').read_text(encoding='utf-8'))}
        previous={q:a for q,a in assessments.items() if a.get('cohort')!='remaining_40'}
        self.assertEqual(len(previous),1580)
        self.assertEqual(hashlib.sha256(json.dumps(previous,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),base['previous_1580_sha256'])
        self.assertEqual({r['external_id'] for r in review},set(base['unrated_ids']))
        self.assertEqual(len(review),40)
        self.assertEqual([sum(r['outcome']==kind for r in review) for kind in ['rated','reference','not_applicable']],[18,16,6])
        moved={r['external_id'] for r in review if r['outcome']!='rated'}
        self.assertEqual(set(self.records)|moved,set(base['roster_ids']))
        for item in review:
            q=item['external_id'];a=assessments[q]
            self.assertTrue(item['reason'] and item['source_refs'])
            if item['outcome']!='rated':
                self.assertNotIn(q,self.records)
                self.assertFalse(excluded[q]['start_present'])
            if item['outcome']=='not_applicable':
                self.assertEqual(a['status'],'not_applicable')
                self.assertTrue(all(v is None for v in a['scores'].values()))
            else:
                for k in roster.ATTRS:
                    lo,hi={'no_record':(11,13),'failure_only':(4,6),'participation_standard':(14,24)}.get(a['score_basis'][k],(1,30))
                    self.assertIs(type(a['scores'][k]),int)
                    self.assertTrue(lo<=a['scores'][k]<=hi)
                    self.assertTrue(a['score_reasons'][k])
        self.assertEqual(self.data['stats']['unrated_people'],0)
        for q in ['Q5507616','Q1191579','Q1077696']:
            self.assertFalse(self.records[q]['start_present'])
            self.assertIsNone(self.records[q]['age_range_at_start'])

    def test_all_candidates_accounted_for_and_exported(self):
        index=json.loads((ROOT/'data/sources/officers/candidate_index.json').read_text(encoding='utf-8'))
        excluded=json.loads((ROOT/'docs/officers/excluded_candidates.json').read_text(encoding='utf-8'))
        excluded_ids={r['external_id'] for r in excluded}
        self.assertEqual(set(index),set(self.records)|excluded_ids)
        self.assertFalse(set(self.records)&excluded_ids)
        config=(ROOT/'export_presets.cfg').read_text(encoding='utf-8')
        for line in config.splitlines():
            if line.startswith('include_filter='):
                self.assertIn('data/derived/officers/*.json',line)
                self.assertIn('data/derived/scenarios/*.json',line)

    def test_map_year_is_independent(self):
        scenario=json.loads((ROOT/'data/derived/scenarios/default_scenario.json').read_text(encoding='utf-8'))
        self.assertEqual(scenario['start_year'],1546)
        self.assertEqual(scenario['map_reference_year'],1582)
        self.assertIsNone(scenario['start_day'])
        sites=json.loads((ROOT/'data/derived/settlements/settlements_1582.json').read_text(encoding='utf-8'))
        self.assertEqual(sites['target_year'],1582)

if __name__=='__main__':unittest.main()
