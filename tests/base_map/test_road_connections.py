"""Independent acceptance checks for the generated connection graph."""
import hashlib
import json
import unittest
from collections import defaultdict, deque
from pathlib import Path
from pyproj import Transformer
from shapely.geometry import LineString, Point, Polygon, shape
from shapely.ops import transform, unary_union
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[2]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))

class RoadConnections(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.d=read('data/derived/road_connections/connections_1582.json')
        cls.anchors={a['id']:a for a in cls.d['anchors']}
        cls.segments={s['id']:s for s in cls.d['segments']}
        cls.sites={s['id']:s for s in read('data/derived/settlements/settlements_1582.json')['sites'] if s['adoption_status']=='accepted'}

    def test_target_and_inputs(self):
        self.assertEqual(len(self.sites),254)
        self.assertEqual({s['site_id'] for s in self.d['site_connections']},set(self.sites))
        self.assertEqual(len(self.d['site_connections']),254)
        for p,h in self.d['input_hashes'].items():
            self.assertEqual(hashlib.sha256((ROOT/p).read_bytes()).hexdigest(),h,p)

    def test_shared_endpoints_and_reachability(self):
        self.assertEqual(len(self.anchors),len(self.d['anchors']))
        self.assertEqual(len(self.segments),len(self.d['segments']))
        graph=defaultdict(set)
        for s in self.segments.values():
            a,b=s['from_anchor'],s['to_anchor']
            self.assertEqual(s['points'][0],self.anchors[a]['point'])
            self.assertEqual(s['points'][-1],self.anchors[b]['point'])
            self.assertFalse(s['routable'])
            graph[a].add(b);graph[b].add(a)
        by_anchor=defaultdict(set)
        for site in self.d['site_connections']:
            if site['anchor_id']: by_anchor[site['anchor_id']].add(site['site_id'])
        for site in self.d['site_connections']:
            self.assertIn(site['status'],['connected','held','land_exempt'])
            if site['status']=='connected':
                seen=set();queue=[site['anchor_id']]; reachable=set()
                while queue:
                    a=queue.pop()
                    if a in seen: continue
                    seen.add(a);reachable.update(by_anchor[a]);queue.extend(graph[a]-seen)
                self.assertGreater(len(reachable-{site['site_id']}),0,site['site_id'])
                self.assertTrue(site['route_ids'])
            else: self.assertTrue(site['reason'])

    def test_new_castles_have_two_sided_connections(self):
        sites={s['site_id']:s for s in self.d['site_connections']}
        for sid in ['kishiwada_castle','ishiyama_honganji','takaya_castle','tsutsui_castle']:
            self.assertEqual(sites[sid]['status'],'connected')
            self.assertEqual(len(sites[sid]['route_ids']),2)
        pairs={frozenset([r['from_site'],r['to_site']]) for r in self.d['routes']}
        for a,b in [('site_1582_settsu_129','ishiyama_honganji'),('ishiyama_honganji','sakai_town'),('sakai_town','takaya_castle'),('takaya_castle','tsutsui_castle'),('tsutsui_castle','site_1582_yamato_145'),('sakai_town','kishiwada_castle'),('kishiwada_castle','saika_town')]:
            self.assertIn(frozenset([a,b]),pairs)
        for a,b in [('site_1582_settsu_129','sakai_town'),('sakai_town','site_1582_yamato_145'),('sakai_town','saika_town')]:
            self.assertNotIn(frozenset([a,b]),pairs)

    def test_no_sea_or_lake_and_registered_water(self):
        m=read('data/base/japan_land_manifest.json')['game_transform']; scale=m['uniform_scale_px_per_m']
        proj=Transformer.from_crs('EPSG:4326',m['projection'],always_xy=True)
        def xy(lon,lat):
            x,y=proj.transform(lon,lat)
            return m['offset_x_px']+(x-m['projected_scope_bounds_m'][0])*scale,m['offset_y_px']+m['content_height_px']-(y-m['projected_scope_bounds_m'][1])*scale
        land=unary_union([transform(xy,shape(f['geometry'])) for f in read('data/base/japan_land.geojson')['features']])
        water=read('data/derived/hydrography/water_registry.json')
        lakes=unary_union([Polygon(w['rings'][0],w['rings'][1:]) for w in water['lakes'] if int(w['source_type'])!=1])
        all_water=water['rivers']+water['lakes']; water_ids={w['id'] for w in all_water}
        crossing_ids={c['segment_id'] for c in self.d['crossings']}
        for c in self.d['crossings']:
            self.assertTrue(set(c['water_ids'])<=water_ids)
            self.assertLessEqual(c['length_m'],self.d['parameters']['max_crossing_m']+.02)
            self.assertEqual(c['bank_anchor_ids'],[self.segments[c['segment_id']]['from_anchor'],self.segments[c['segment_id']]['to_anchor']])
        for s in self.segments.values():
            line=LineString(s['points'])
            self.assertLess(line.difference(land.buffer(1e-5)).length,1e-5,s['id'])
            self.assertLess(line.intersection(lakes).length,1e-5,s['id'])
            self.assertEqual(s['role']=='crossing',s['id'] in crossing_ids)
        river_shapes=[LineString(w['points']) if 'points' in w else Polygon(w['rings'][0],w['rings'][1:]) for w in all_water]
        tree=STRtree(river_shapes)
        for s in self.segments.values():
            if s['role']=='crossing': continue
            line=LineString(s['points'])
            for i in tree.query(line,predicate='intersects'):
                hit=line.intersection(river_shapes[int(i)])
                self.assertLess(hit.length,1e-5,('unregistered wet segment',s['id']))
                if hit.geom_type=='Point':
                    self.assertLess(min(hit.distance(Point(line.coords[0])),hit.distance(Point(line.coords[-1]))),1e-5,('unregistered river crossing',s['id']))

    def test_derived_geometry_and_honest_evidence(self):
        refs={s['id'] for s in self.d['sources']}
        for r in self.d['routes']:
            self.assertEqual(r['basis'],'game_inferred_connection')
            self.assertEqual(r['year_status'],'unconfirmed')
            self.assertFalse(r['routable'])
            self.assertTrue(set(r['source_refs'])<=refs)
            self.assertTrue(set(r['segment_ids'])<=set(self.segments))
            selected=[self.segments[i] for i in r['segment_ids']]
            coverage=unary_union([LineString(s['points']) for s in selected])
            self.assertLess(LineString(r['points']).difference(coverage.buffer(1e-5)).length,1e-4,r['id'])
            graph=defaultdict(set)
            for s in selected:
                graph[s['from_anchor']].add(s['to_anchor']);graph[s['to_anchor']].add(s['from_anchor'])
            arrivals={s['site_id']:s['anchor_id'] for s in self.d['site_connections']}
            start=arrivals[r['from_site']];end=arrivals[r['to_site']]
            queue=[start];seen=set()
            while queue:
                n=queue.pop()
                if n in seen: continue
                seen.add(n);queue.extend(graph[n]-seen)
            self.assertIn(end,seen,r['id'])
            self.assertLessEqual(r['metrics']['max_grade'],.2201)
            self.assertEqual([w['order'] for w in r['waypoints']],list(range(1,len(r['waypoints'])+1)))

if __name__=='__main__': unittest.main()
