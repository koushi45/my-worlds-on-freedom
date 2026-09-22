"""Terrain-constrained game connections; uses independent estimated connection inputs.

The editorial plan fixes relationships. A* only estimates geometry between them.
All water tests use the full registry, not the display selection. No straight-line
fallback is permitted. Entrances are explicitly estimated areas, not named gates.
"""
import hashlib
import heapq
import json
import math
from collections import Counter, defaultdict, deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from pyproj import Transformer
from shapely import prepare
from shapely.geometry import LineString, Point, Polygon, shape
from shapely.ops import transform, unary_union, substring
from shapely.strtree import STRtree
from road_sharing import normalize_connections

ROOT=Path(__file__).resolve().parents[1]
EDIT=ROOT/'data/editorial/road_connections'
OUT=ROOT/'data/derived/road_connections'
DOC=ROOT/'docs/road_connections'

def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def digest(p): return hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
def lineparts(g):
    if g.is_empty: return []
    if g.geom_type=='LineString': return [g] if g.length>1e-8 else []
    return [p for c in getattr(g,'geoms',[]) for p in lineparts(c)]

class Terrain:
    def __init__(self, config):
        self.config=config
        self.m=read('data/base/japan_land_manifest.json')['game_transform']
        self.scale=self.m['uniform_scale_px_per_m']; self.step=config['grid_game_px']
        self.projection=Transformer.from_crs('EPSG:4326',self.m['projection'],always_xy=True)
        self.inverse=Transformer.from_crs(self.m['projection'],'EPSG:4326',always_xy=True)
        self.land=unary_union([transform(self.xy,shape(f['geometry'])) for f in read('data/base/japan_land.geojson')['features']])
        self.islands=list(self.land.geoms); prepare(self.land)
        water=read('data/derived/hydrography/water_registry.json')
        self.lakes=unary_union([Polygon(w['rings'][0],w['rings'][1:]) for w in water['lakes'] if int(w['source_type'])!=1]); prepare(self.lakes)
        self.water_ids=[]; self.water_shapes=[]
        for w in water['rivers']+water['lakes']:
            if 'points' in w: geom=LineString(w['points']).buffer(config['river_centerline_buffer_m']*self.scale)
            elif int(w['source_type'])==1: geom=Polygon(w['rings'][0],w['rings'][1:])
            else: continue
            self.water_ids.append(w['id']); self.water_shapes.append(geom)
        self.tree=STRtree(self.water_shapes)
        self.heights=np.asarray(Image.open(ROOT/config['source_dem']),dtype=float)
        self.node_cache={}; self.edge_cache={}; self.used=set()
        self.crossing_candidates={}
    def xy(self,lon,lat):
        x,y=self.projection.transform(lon,lat); m=self.m
        return (m['offset_x_px']+(x-m['projected_scope_bounds_m'][0])*self.scale,
                m['offset_y_px']+m['content_height_px']-(y-m['projected_scope_bounds_m'][1])*self.scale)
    def lonlat(self,p):
        m=self.m
        return list(self.inverse.transform(m['projected_scope_bounds_m'][0]+(p[0]-m['offset_x_px'])/self.scale,
              m['projected_scope_bounds_m'][1]+(m['offset_y_px']+m['content_height_px']-p[1])/self.scale))
    def point(self,n): return (n[0]*self.step,n[1]*self.step)
    def height(self,p):
        x=max(0,min(4095,p[0]/2-.5)); y=max(0,min(4095,p[1]/2-.5))
        ix,iy=int(x),int(y); fx,fy=x-ix,y-iy
        return float(self.heights[iy,ix]*(1-fx)*(1-fy)+self.heights[iy,min(ix+1,4095)]*fx*(1-fy)+self.heights[min(iy+1,4095),ix]*(1-fx)*fy+self.heights[min(iy+1,4095),min(ix+1,4095)]*fx*fy)
    def dry(self,n):
        if n not in self.node_cache:
            p=Point(self.point(n))
            self.node_cache[n]=self.land.covers(p) and not self.lakes.intersects(p) and len(self.tree.query(p,predicate='intersects'))==0
        return self.node_cache[n]
    def entrance(self,site):
        p=site['point']; center=(round(p[0]/self.step),round(p[1]/self.step))
        radius=math.ceil(self.config['entrance_search_m']*self.scale/self.step)
        # Separate the symbol from a low-side arrival area, without asserting a gate.
        opts=[]
        for dy in range(-radius,radius+1):
            for dx in range(-radius,radius+1):
                n=(center[0]+dx,center[1]+dy); q=self.point(n)
                dist=math.dist(p,q)/self.scale
                if dist>self.config['entrance_search_m'] or not self.dry(n): continue
                h=self.height(q)
                score=dist+(h*2.5 if 'castle' in site['roles'] else h*.3)
                opts.append((score,dist,n))
        if not opts: return None
        return min(opts)[2]
    def edge(self,a,b):
        key=tuple(sorted([a,b]))
        if key in self.edge_cache: return self.edge_cache[key]
        if not self.dry(b) or not self.dry(a): self.edge_cache[key]=None; return None
        line=LineString([self.point(a),self.point(b)])
        if not self.land.covers(line) or self.lakes.intersects(line): self.edge_cache[key]=None; return None
        hits=sorted(self.tree.query(line,predicate='intersects'))
        crossing=[]
        if hits:
            wet=unary_union([self.water_shapes[i] for i in hits])
            for part in lineparts(line.intersection(wet)):
                if part.length/self.scale>self.config['max_crossing_m']:
                    self.edge_cache[key]=None; return None
                ids=[self.water_ids[i] for i in hits if self.water_shapes[i].intersects(part)]
                crossing.append(dict(points=list(map(list,part.coords)),water_ids=ids,length_m=round(part.length/self.scale,2),
                                     method='unknown_game_crossing',status='inferred',bank_note='現代水域の境界。中心線のみの川は幅不明のため左右15mを検査帯とする。実際の川岸・橋台ではない。'))
        # Long grid moves are only eligible as a bounded river crossing candidate.
        if max(abs(a[0]-b[0]),abs(a[1]-b[1]))>1 and not crossing:
            self.edge_cache[key]=None; return None
        length=line.length/self.scale
        grade=abs(self.height(self.point(a))-self.height(self.point(b)))/length
        result=(length,grade,(self.height(self.point(a))+self.height(self.point(b)))/2,crossing)
        self.edge_cache[key]=result
        if crossing: self.crossing_candidates[key]=crossing  # registered before A* may traverse this edge
        return result
    def route(self,a,b,weight):
        if a==b: return [a]
        margin=math.ceil(self.config['search_margin_m']*self.scale/self.step)
        xmin=min(a[0],b[0])-margin; xmax=max(a[0],b[0])+margin
        ymin=min(a[1],b[1])-margin; ymax=max(a[1],b[1])+margin
        direct=math.dist(self.point(a),self.point(b))/self.scale
        queue=[(direct*.75,0.,a)]; best={a:0.}; prev={}; explored=0
        moves=[(x,y) for x in [-1,0,1] for y in [-1,0,1] if x or y]
        moves += [(2,0),(-2,0),(0,2),(0,-2),(2,2),(-2,2),(2,-2),(-2,-2)]
        while queue and explored<180000:
            _,cost,n=heapq.heappop(queue)
            if cost>best[n]+1e-7: continue
            if n==b:
                path=[b]
                while path[-1]!=a: path.append(prev[path[-1]])
                return path[::-1]
            explored+=1
            for dx,dy in moves:
                q=(n[0]+dx,n[1]+dy)
                if not xmin<=q[0]<=xmax or not ymin<=q[1]<=ymax: continue
                edge=self.edge(n,q)
                if edge is None: continue
                length,grade,h,cross=edge
                step=length*(1+weight*grade*grade+h*.00065)+(1000 if cross else 0)
                if tuple(sorted([n,q])) in self.used: step*=.8
                new=cost+step
                if new>=best.get(q,float('inf')): continue
                best[q]=new;prev[q]=n
                heapq.heappush(queue,(new+math.dist(self.point(q),self.point(b))/self.scale*.75,new,q))
        return None
    def metrics(self,path):
        pts=[self.point(n) for n in path]; hs=[self.height(p) for p in pts]
        lengths=[math.dist(a,b)/self.scale for a,b in zip(pts,pts[1:])]
        grades=[abs(b-a)/l for a,b,l in zip(hs,hs[1:],lengths)]
        return dict(length_m=round(sum(lengths),1),ascent_m=round(sum(max(0,b-a) for a,b in zip(hs,hs[1:])),1),
                    descent_m=round(sum(max(0,a-b) for a,b in zip(hs,hs[1:])),1),max_grade=round(max(grades,default=0),4),
                    steep_length_m=round(sum(l for l,g in zip(lengths,grades) if g>self.config['grade_review']),1),
                    water_crossings=sum(len(self.edge(a,b)[3]) for a,b in zip(path,path[1:])),
                    shared_length_m=round(sum(l for a,b,l in zip(path,path[1:],lengths) if tuple(sorted([a,b])) in self.used),1))

def build(reuse_routes=False, update_routes=False):
    plan=read('data/editorial/road_connections/plan.json')
    runtime=read('data/derived/settlements/settlements_1582.json')
    sites={s['id']:s for s in runtime['sites'] if s['adoption_status']=='accepted'}
    assert set(sites)==set(plan['target_sites'])
    terrain=Terrain(plan['parameters'])
    print('Terrain loaded; assigning estimated entrances',flush=True)
    entrances={i:terrain.entrance(s) for i,s in sites.items() if i not in plan['land_exemptions']}
    if reuse_routes:
        previous=read('data/derived/road_connections/connections_1582.json')
        assert previous['input_hashes']=={p:digest(p) for p in previous['input_hashes']}, 'Inputs changed; run a full build.'
        review=read('data/derived/road_connections/review.json')
        return finish(plan,runtime,sites,terrain,entrances,previous['routes'],review['comparisons'],review['held_routes'])
    cached={}; cached_comparisons={}
    if update_routes:
        previous=read('data/derived/road_connections/connections_1582.json')
        assert previous['parameters']==plan['parameters'], 'Routing parameters changed; run a full build.'
        mutable={'data/editorial/road_connections/plan.json','data/derived/settlements/settlements_1582.json'}
        assert all(digest(p)==h for p,h in previous['input_hashes'].items() if p not in mutable), 'Terrain or routing inputs changed; run a full build.'
        cached={r['id']:r for r in previous['routes']}
        cached_comparisons={r['route_id']:r for r in read('data/derived/road_connections/review.json')['comparisons']}
    routes=[]; comparisons=[]; failed=[]
    for index,p in enumerate(plan['plans']):
        a=entrances.get(p['from_site']); b=entrances.get(p['to_site'])
        if a is None or b is None:
            failed.append(dict(route_id=p['id'],reason='陸側の推定接続域が探索半径内に得られない')); continue
        controls=[]
        for v in p.get('via',[]):
            n=terrain.entrance(dict(point=terrain.xy(*v['lonlat']),roles=[]))
            if n is not None: controls.append((v,n))
        if len(controls)!=len(p.get('via',[])):
            failed.append(dict(route_id=p['id'],reason='固定した概略通過域の陸側位置が得られない'));continue
        old=cached.get(p['id'])
        if old and all(old.get(k)==v for k,v in p.items() if k not in ('adoption_status','source_refs')) and set(p['source_refs'])<=set(old['source_refs']):
            raw=old.get('original_points',old['points'])
            if list(terrain.point(a))==raw[0] and list(terrain.point(b))==raw[-1]:
                old['points']=raw
                routes.append(old);comparisons.append(cached_comparisons[p['id']])
                path=[tuple(v/terrain.step for v in pt) for pt in raw]
                terrain.used.update(tuple(sorted([x,y])) for x,y in zip(path,path[1:]))
                continue
        alternatives=[]
        for weight in ([55] if math.dist(a,b)*terrain.step/terrain.scale<2500 else [25,70]):
            stops=[a]+[n for _,n in controls]+[b]
            path=[a]
            for start,end in zip(stops,stops[1:]):
                part=terrain.route(start,end,weight)
                if part is None: path=None;break
                path.extend(part[1:])
            if path and len(path)>1:
                metrics=terrain.metrics(path)
                alternatives.append((metrics['length_m']+metrics['ascent_m']*10+metrics['steep_length_m']*3+metrics['water_crossings']*1000,weight,path,metrics))
        if not alternatives:
            failed.append(dict(route_id=p['id'],reason='海・湖・渡河長・探索範囲の制約内で陸路案が得られない。直線への代替なし。')); continue
        _,weight,path,metrics=min(alternatives,key=lambda v:v[0])
        if metrics['steep_length_m']>0:
            failed.append(dict(route_id=p['id'],reason='実標高で22%を超える区間が残る。登城道・峠の資料を要する。',metrics=metrics)); continue
        route=dict(p,adoption_status='accepted',points=[list(terrain.point(n)) for n in path],metrics=metrics,
                   selected_weight=weight,routable=False,source_refs=p['source_refs']+['dem:existing','water:existing'])
        route['bounds']=list(LineString(route['points']).bounds)
        route['fixed_waypoint_mapping']=[dict(waypoint_id=v['waypoint_id'],name=v['name'],point=list(terrain.point(n)),original_lonlat=v['lonlat']) for v,n in controls]
        routes.append(route)
        comparisons.append(dict(route_id=p['id'],selected_weight=weight,alternatives=[dict(weight=w,metrics=m) for _,w,_,m in alternatives],
            decision='距離＋累積上昇×10＋急勾配距離×3＋推定渡河数×1000のゲーム用比較値が小さい案。史実の勾配上限ではない。'))
        terrain.used.update(tuple(sorted([x,y])) for x,y in zip(path,path[1:]))
        if index%10==0: print(f'{index+1}/{len(plan["plans"])} plans; {len(routes)} adopted; {len(failed)} held',flush=True)
    return finish(plan,runtime,sites,terrain,entrances,routes,comparisons,failed)

def finish(plan,runtime,sites,terrain,entrances,routes,comparisons,failed):
    sharing_parameters=read('data/editorial/road_connections/sharing.json')
    print('Normalizing parallel corridors',flush=True)
    sharing=normalize_connections(routes,terrain,sharing_parameters)
    print(f'Shared {len(sharing)} parallel runs; noding roads and registering crossings',flush=True)
    # Unary union nodes every geometric intersection and removes overlapping strokes.
    merged=unary_union([LineString(r['points']) for r in routes])
    pieces=lineparts(merged)
    anchors={}; segments=[]; crossings=[]; coordinate_ids={}
    def anchor(p,kind='junction'):
        p=tuple(round(float(v),6) for v in p)
        if p not in coordinate_ids:
            aid=f'anchor_{len(anchors)+1:05}'
            coordinate_ids[p]=aid
            anchors[aid]=dict(id=aid,kind=kind,point=list(p),lonlat=terrain.lonlat(p),position_status='inferred',
                             name='推定分岐点',site_ids=[],source_refs=['method:editorial_relationships'])
        return coordinate_ids[p]
    for i,n in entrances.items():
        if n is None: continue
        aid=anchor(terrain.point(n),'site_entrance')
        anchors[aid]['site_ids'].append(i);anchors[aid]['name']=sites[i]['display_name']+'・推定接続域'
        anchors[aid]['selection_reason']='実標高・陸地・全水系を検査して低地側の接続域を選定。実在の門・登城口・船着場の比定ではない。'
        anchors[aid]['symbol_distance_m']=round(math.dist(sites[i]['point'],anchors[aid]['point'])/terrain.scale,1)
    route_lines=[LineString(r['points']) for r in routes]; rt=STRtree(route_lines)
    for piece in pieces:
        # Split wet spans into explicit crossing edges with shared bank node IDs.
        hits=sorted(terrain.tree.query(piece,predicate='intersects'))
        wet=unary_union([terrain.water_shapes[i] for i in hits]) if hits else None
        cuts={0.,piece.length}
        wetparts=lineparts(piece.intersection(wet)) if hits else []
        for part in wetparts:
            cuts.update([piece.project(Point(part.coords[0])),piece.project(Point(part.coords[-1]))])
        # Explicit entrances must remain graph nodes even on a straight shared road.
        for n in entrances.values():
            if n is not None:
                pt=Point(terrain.point(n))
                if piece.distance(pt)<1e-7: cuts.add(piece.project(pt))
        positions=sorted(cuts)
        for start,end in zip(positions,positions[1:]):
            if end-start<1e-7: continue
            line=substring(piece,start,end); midpoint=line.interpolate(.5,normalized=True)
            water_ids=[terrain.water_ids[i] for i in hits if terrain.water_shapes[i].covers(midpoint)]
            role='crossing' if water_ids else 'connector'
            ids=[routes[int(i)]['id'] for i in rt.query(midpoint.buffer(1e-5),predicate='intersects') if route_lines[int(i)].distance(midpoint)<1e-5]
            sid=f'segment_{len(segments)+1:05}'
            a=anchor(line.coords[0],'crossing_bank' if water_ids else 'junction'); b=anchor(line.coords[-1],'crossing_bank' if water_ids else 'junction')
            segments.append(dict(id=sid,from_anchor=a,to_anchor=b,points=[anchors[a]['point']]+[list(p) for p in list(line.coords)[1:-1]]+[anchors[b]['point']],
                role=role,adoption_status='accepted',basis='game_inferred_connection',year_status='unconfirmed',geometry_status='terrain_estimate',
                route_ids=ids,routable=False,source_refs=['method:editorial_relationships','dem:existing','water:existing']))
            if water_ids:
                crossings.append(dict(id=f'crossing_{len(crossings)+1:04}',segment_id=sid,bank_anchor_ids=[a,b],water_ids=water_ids,
                    length_m=round(line.length/terrain.scale,2),method='unknown_game_crossing',status='inferred',
                    note='ゲーム用の推定渡河。橋・渡しの1582年の存在は未確認。中心線のみは左右15mの検査帯で、実際の両岸幅ではない。'))
    adjacency=defaultdict(set)
    for s in segments:
        adjacency[s['from_anchor']].add(s['to_anchor']);adjacency[s['to_anchor']].add(s['from_anchor'])
    for s in segments:
        if s['role']=='crossing': continue
        if any(anchors[a]['site_ids'] and len(adjacency[a])==1 for a in [s['from_anchor'],s['to_anchor']]): s['role']='site_access'
        elif len(s['route_ids'])>1: s['role']='trunk'
    component={}; components=[]
    for aid in sorted(adjacency):
        if aid in component: continue
        number=len(components); queue=[aid]; nodes=[]
        while queue:
            n=queue.pop()
            if n in component: continue
            component[n]=number;nodes.append(n);queue.extend(adjacency[n]-component.keys())
        components.append(dict(id=number,node_count=len(nodes),site_ids=sorted({i for n in nodes for i in anchors[n]['site_ids']})))
    site_connections=[]
    for i,s in sites.items():
        n=entrances.get(i); aid=coordinate_ids.get(tuple(terrain.point(n))) if n is not None else None
        c=component.get(aid); links=[r['id'] for r in routes if i in [r['from_site'],r['to_site']]]
        if i in plan['land_exemptions']: status='land_exempt'; reason=plan['land_exemptions'][i]
        elif c is not None and len(components[c]['site_ids'])>1 and links: status='connected'; reason='共有IDの出入口から、採用区間だけで地域内の他拠点へ到達。既存の未精査回廊を到達判定に使用していない。'
        else: status='held'; reason='採用済み区間だけでは他拠点への連続した接続を確認できない。'
        site_connections.append(dict(site_id=i,name=s['display_name'],region_id=s['region_id'],anchor_id=aid,status=status,reason=reason,
            route_ids=links,component_id=c,remaining='山上の主郭までの登城道・門位置は未比定。接続済みは推定接続域まで。' if 'castle' in s['roles'] else '1582年の出入口・当時の水際の精密比定は未実施。'))
    for r in routes:
        r['segment_ids']=[s['id'] for s in segments if r['id'] in s['route_ids']]
        r['crossing_ids']=[c['id'] for c in crossings if c['segment_id'] in r['segment_ids']]
        # Ordered visible waypoints: endpoints plus selected bends at >5 km spacing.
        pts=r['points']; selected=[pts[0]]; distance=0.
        for a,b in zip(pts,pts[1:]):
            distance+=math.dist(a,b)/terrain.scale
            if distance>=5000: selected.append(b);distance=0
        if selected[-1]!=pts[-1]: selected.append(pts[-1])
        r['waypoints']=[dict(id=r['id']+'_via_'+hashlib.sha256(json.dumps(p).encode()).hexdigest()[:12],order=k+1,point=p,name=('推定接続域' if k in [0,len(selected)-1] else '推定通過点'),status='inferred') for k,p in enumerate(selected)]
        for waypoint in r.get('fixed_waypoint_mapping',[]):
            if not any(w['point']==waypoint['point'] for w in r['waypoints']):
                r['waypoints'].append(dict(id='fixed:'+waypoint['waypoint_id'],point=waypoint['point'],name=waypoint['name']+'※',status='inferred'))
        route_line=LineString(r['points'])
        r['waypoints'].sort(key=lambda w:route_line.project(Point(w['point'])))
        for k,w in enumerate(r['waypoints']): w['order']=k+1
    inputs=['data/editorial/road_connections/plan.json','data/editorial/road_connections/sources.json',
            'data/derived/settlements/settlements_1582.json',
            'data/editorial/road_connections/sharing.json',
            'data/derived/hydrography/water_registry.json','data/base/japan_land.gpkg',
            'data/base/japan_land.geojson','data/base/japan_land_manifest.json','assets/map/elevation/elevation_m.png']
    summary=dict(target_sites=len(sites),site_status_counts=dict(Counter(s['status'] for s in site_connections)),
                 adopted_routes=len(routes),held_routes=len(failed),segments=len(segments),crossings=len(crossings),
                 components=components,all_routes_routable=False,source_supported_new_routes=0,game_inferred_routes=len(routes))
    data=dict(schema_version=1,target_year=1582,summary=summary,routes=routes,segments=segments,anchors=list(anchors.values()),
              crossings=crossings,site_connections=site_connections,sources=read('data/editorial/road_connections/sources.json'),
              parameters=plan['parameters'],input_hashes={p:digest(p) for p in inputs})
    OUT.mkdir(parents=True,exist_ok=True)
    write(OUT/'connections_1582.json',data)
    write(OUT/'sharing_review.json',dict(parameters=sharing_parameters,connections=sharing))
    write(OUT/'review.json',dict(comparisons=comparisons,held_routes=failed,summary=summary))
    for name,records in [('anchors',list(anchors.values())),('segments',segments),('crossings',crossings),('site_connections',site_connections)]:
        write(EDIT/(name+'.json'),dict(status='generated_adoption_snapshot',editorial_master='plan.json',records=records))
    DOC.mkdir(parents=True,exist_ok=True)
    lines=['# 1582年・道路接続初版','', '250拠点の採否は維持。新規線形は全てゲーム用の推定連絡路。', '',
           f'対象 {len(sites)}、状態 {summary["site_status_counts"]}。採用路線 {len(routes)}、保留案 {len(failed)}、渡河区間 {len(crossings)}。', '',
           '## 地域別の接続', '', '|地方|接続済み|保留|陸路対象外|','|---|---:|---:|---:|']
    for region in runtime['regions']:
        count=Counter(s['status'] for s in site_connections if s['region_id']==region['id'])
        lines.append(f'|{region["name"]}|{count["connected"]}|{count["held"]}|{count["land_exempt"]}|')
    lines+=['','## 判断と限界','','約453mの実標高ラスタを使用。平滑化した表示用メッシュから勾配を計算していない。探索幅は各接続の外側18km、比較重み25/70、22%を超える案は保留。これはゲーム用検査値で、歴史上の通行限界ではない。',
        '出入口は最大1.8km以内の低地側推定域。代表点は移動しない。主郭までの登城道、門、船着場は未比定。',
        '海と湖は通行不可。非表示支流を含む全水系を検査。中心線しかない川の左右15mは検査帯であり実際の川幅ではない。全ての新規渡河は方法未確認。',
        'A*の通過候補は渡河検査を経てから使用。生成後は全交差を共有IDで分割し、共用区間は一本として描画する。ゲーム内移動機能の routable は false のまま。',
        '既存概略回廊を経由せず採用した新規地域網の探索で接続を判定。全国一成分になることは要求せず、海峡を陸路化しない。',
        '編集正本は plan.json（接続目的・対象・パラメータ）と sources.json。anchors/segments/crossings/site_connections は再生成した採用スナップショット。修正は正本に行う。',
        '再生成: `python tools/build_road_connections.py`。関係表の再初期化は `python tools/seed_road_connections.py`（編集後は実行しない）。',
        '', '## 拠点別の状態', '', '|拠点|状態|理由・残件|','|---|---|---|']
    names={'connected':'接続済み','held':'接続保留','land_exempt':'陸路対象外'}
    lines += [f'|{s["name"]}|{names[s["status"]]}|{s["reason"]} {s["remaining"]}|' for s in site_connections]
    lines += ['','## 保留した接続案','']+[f'- {f["route_id"]}: {f["reason"]}' for f in failed]
    (DOC/'CONNECTIONS_1582.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False),flush=True)
    from build_shared_road_display import build_display
    build_display(terrain)

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('--reuse-routes',action='store_true',help='Reuse unchanged A* inputs; normalize and rebuild the graph.')
    parser.add_argument('--update-routes',action='store_true',help='Preserve unchanged plans and entrances; route changed/new relationships only.')
    args=parser.parse_args()
    assert not (args.reuse_routes and args.update_routes)
    build(args.reuse_routes,args.update_routes)
