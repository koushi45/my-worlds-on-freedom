import hashlib
import json
import unittest
from collections import Counter
from itertools import combinations
from pyproj import Geod
from pathlib import Path
from pyproj import Transformer

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))

class SettlementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = read('data/derived/settlements/settlements_1582.json')
        cls.master = read('data/editorial/settlements/settlements_1582.json')

    def test_provenance_and_adoption(self):
        d = self.data
        self.assertEqual(d['target_year'], 1582)
        sites = {s['id']: s for s in d['sites']}
        self.assertEqual(len(sites), len(d['sites']))
        sources = {s['id'] for s in d['sources']}
        for s in d['sites']:
            self.assertTrue(set(s['source_refs']) <= sources)
            for claims in s['claims'].values():
                self.assertTrue({c['source_ref'] for c in claims} <= sources)
            if s['adoption_status'] == 'accepted':
                self.assertNotEqual(s['temporal_status'], 'out_of_period')
                for field in ['roles', 'display_name', 'selection_reason', 'temporal_note', 'location_note', 'adoption_reason']:
                    self.assertTrue(s[field], (s['id'], field))
        self.assertEqual(sites['takaoka_castle_late']['adoption_status'], 'excluded')
        self.assertEqual(sites['tonokori_castle']['adoption_status'], 'deferred')

    def test_master_projection_and_inputs(self):
        d = self.data
        for path, expected in d['input_hashes'].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected, path)
        self.assertEqual(d['input_hashes']['data/base/japan_land.gpkg'], '258bae08b94ebc870de0cf59779780b4a623ca5b7d56e8539eec6cd749e12b59')
        m = read('data/base/japan_land_manifest.json')['game_transform']
        inv = Transformer.from_crs(m['projection'], 'EPSG:4326', always_xy=True)
        for master, built in zip(self.master['sites'], d['sites'], strict=True):
            for field in master:
                self.assertEqual(master[field], built[field])
            if not built['point']:
                continue
            x, y = built['point']
            east = (x - m['offset_x_px']) / m['uniform_scale_px_per_m'] + m['projected_scope_bounds_m'][0]
            north = (m['offset_y_px'] + m['content_height_px'] - y) / m['uniform_scale_px_per_m'] + m['projected_scope_bounds_m'][1]
            lon, lat = inv.transform(east, north)
            self.assertAlmostEqual(lon, master['lonlat'][0], places=7)
            self.assertAlmostEqual(lat, master['lonlat'][1], places=7)

    def test_reviews_cover_all_sites(self):
        self.assertEqual({s['id'] for s in self.data['sites']}, {r['site_id'] for r in self.data['review']})
        for review in self.data['review']:
            self.assertTrue(review['decision'])

    def test_regional_allocation_and_unique_places(self):
        policy=self.master['allocation_policy']
        reference=policy['reference_counts']
        self.assertEqual(sum(reference.values()),207)
        seats={k:v*249//207 for k,v in reference.items()}
        order=sorted(reference,key=lambda k:reference[k]*249%207,reverse=True)
        for k in order[:249-sum(seats.values())]:seats[k]+=1
        seats['hokkaido']=1
        self.assertEqual(seats,policy['base_targets'])
        for region,count in policy['user_additions'].items(): seats[region]+=count
        self.assertEqual(seats,policy['targets'])
        accepted=[s for s in self.data['sites'] if s['adoption_status']=='accepted']
        self.assertEqual(len(accepted),254)
        self.assertEqual(Counter('kyushu' if s['region_id']=='south_kyushu' else s['region_id'] for s in accepted),seats)
        self.assertEqual(len({s['site_group_id'] for s in accepted}),254)
        reviewed={tuple(r['site_ids']) for r in self.data['proximity_review']}
        geod=Geod(ellps='WGS84')
        for a,b in combinations(accepted,2):
            distance=geod.inv(*a['lonlat'],*b['lonlat'])[2]
            self.assertGreater(distance,1)
            if distance<3500:self.assertIn(tuple(sorted([a['id'],b['id']])),reviewed)

    def test_merged_places_keep_names_roles_and_road_references(self):
        lookup={s['id']:s for s in self.data['sites']}
        merged=[s for s in lookup.values() if s.get('merged_into')]
        self.assertEqual(len(merged),9)
        for child in merged:
            parent=lookup[child['merged_into']]
            self.assertEqual(child['adoption_status'],'excluded')
            self.assertEqual(parent['adoption_status'],'accepted')
            self.assertIn(child['id'],parent['aliases'])
            self.assertTrue(set(child['roles'])<=set(parent['roles']))
            self.assertTrue(set(child['source_refs'])<=set(parent['source_refs']))
            self.assertIn(child['id'],{c['id'] for c in parent['components']})

    def test_modern_coordinate_source_does_not_claim_1582_activity(self):
        for s in self.data['sites']:
            self.assertNotIn('nrct_poi_20250515',{c['source_ref'] for c in s['claims']['temporal']})
        lookup={s['id']:s for s in self.data['sites']}
        self.assertIn('茶臼山',lookup['site_1582_shinano_069']['location_note'])
        self.assertIn('隈本',lookup['site_1582_higo_199']['display_name'])

    def test_requested_kinki_castles(self):
        sites={s['id']:s for s in self.data['sites']}
        for sid,province in [('kishiwada_castle','izumi'),('ishiyama_honganji','settsu'),('takaya_castle','kawachi'),('tsutsui_castle','yamato')]:
            s=sites[sid]
            self.assertEqual(s['roles'],['castle'])
            self.assertEqual(s['province_id'],province)
            self.assertEqual(s['adoption_status'],'accepted')
            self.assertTrue(s['user_requested_addition'])
            if sid!='kishiwada_castle': self.assertEqual(s['temporal_status'],'scenario_override')

if __name__ == '__main__':
    unittest.main()
