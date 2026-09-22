"""Research-only district comparisons and shared boundary networks, stage C.

No write to runtime, base maps, castles, roads or the stage A/B snapshot.
fetch: cache original provider GeoJSON. build: project and node shared edges.
"""
from pathlib import Path
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from urllib.request import urlopen
from datetime import datetime, timezone
import argparse
import hashlib
import json
import math
import numpy as np
from shapely.geometry import shape, Polygon, LineString, mapping
from shapely.ops import unary_union, transform, polygonize
from shapely.validation import explain_validity
from pyproj import Transformer

ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'data/sources/districts/stage_c'
WORK=ROOT/'data/work/districts/stage_c'
EDITOR=ROOT/'data/editorial/districts/stage_c'
BASE='https://geoshape.ex.nii.ac.jp/kg/geojson/'
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,obj):
    p=ROOT/p;p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(obj,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
def fetch_one(gid):
    p=RAW/'kg'/f'{gid}.geojson';meta=p.with_suffix('.source.json')
    if p.exists() and meta.exists():
        r=read(meta);assert sha(p)==r['sha256'];return r
    url=BASE+gid+'.geojson'
    with urlopen(url,timeout=45) as response:
        content=response.read()
    data=json.loads(content)
    assert data['type']=='FeatureCollection' and all(x['properties']['id']==gid for x in data['features'])
    p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(content)
    r=dict(source_id='kg-geometry-'+gid,url=url,file=p.relative_to(ROOT).as_posix(),sha256=sha(p),
        fetched_at_utc=datetime.now(timezone.utc).isoformat(),license='CC-BY-NC-4.0',
        license_url='https://geoshape.ex.nii.ac.jp/kg/index.html.ja#license',
        credit='旧国・旧郡境界データセット（CODH）／幕末明治地勢地図境界データ（人間文化研究機構）を加工 doi:10.20676/00000454',
        temporal_basis='later_comparison; includes modern subdivisions',export_allowed=False)
    write(meta,r);return r
def fetch():
    ids=sorted({d['external_ids']['district_id'] for d in read('data/editorial/districts/districts.json')['districts'] if d['external_ids']})
    with ThreadPoolExecutor(max_workers=4) as pool:
        records=[]
        for item in pool.map(fetch_one,ids):
            records.append(item)
            if len(records)%100==0: print('Fetched/verified',len(records),'of',len(ids),flush=True)
    write(RAW/'geometry_sources.json',dict(sources=records));print('Complete:',len(records),flush=True)
def transforms():
    m=read('data/base/japan_land_manifest.json')['game_transform']
    f=Transformer.from_crs('EPSG:4326',m['projection'],always_xy=True)
    inv=Transformer.from_crs(m['projection'],'EPSG:4326',always_xy=True)
    bx,by,_,_=m['projected_scope_bounds_m'];s=m['uniform_scale_px_per_m']
    def xy(lon,lat,z=None):
        x,y=f.transform(lon,lat)
        return m['offset_x_px']+(np.asarray(x)-bx)*s,m['offset_y_px']+m['content_height_px']-(np.asarray(y)-by)*s
    def ll(x,y):
        return inv.transform(bx+(np.asarray(x)-m['offset_x_px'])/s,by+(m['content_height_px']-np.asarray(y)+m['offset_y_px'])/s)
    return m,xy,ll
def polygon_parts(g):
    return [g] if g.geom_type=='Polygon' else list(g.geoms)
def key(a,b): return (a,b) if a<b else (b,a)
def network(geometries,xy):
    """Keep exact provider vertices; merge only identical undirected segments.

    Group degree-two chains by ownership, split at every global junction.
    No distance snap, densification, smoothing, river/coast fitting or gap fill.
    """
    edges=defaultdict(set)
    for gid,g in geometries.items():
        for p in polygon_parts(g):
            for ring in [p.exterior,*p.interiors]:
                coords=[tuple(c[:2]) for c in ring.coords]
                for a,b in zip(coords,coords[1:]):
                    if a!=b: edges[key(a,b)].add(gid)
    graph=defaultdict(set);groups=defaultdict(set)
    for e,owners in edges.items():
        a,b=e;graph[a].add(b);graph[b].add(a);groups[tuple(sorted(owners))].add(e)
    arcs=[]
    for owners,group in sorted(groups.items()):
        links=defaultdict(set)
        for a,b in group: links[a].add(b);links[b].add(a)
        cuts={a for a in links if len(links[a])!=2 or len(graph[a])!=2}
        unused=set(group)
        def walk(a,b):
            points=[a,b];unused.remove(key(a,b))
            while b not in cuts:
                options=[c for c in links[b] if key(b,c) in unused]
                if not options: break
                c=sorted(options)[0];unused.remove(key(b,c));points.append(c);a,b=b,c
            return points
        chains=[]
        for a in sorted(cuts):
            for b in sorted(links[a]):
                if key(a,b) in unused: chains.append(walk(a,b))
        while unused:
            a,b=min(unused);chains.append(walk(a,b))
        for points in chains:
            raw=np.asarray(points);x,y=xy(raw[:,0],raw[:,1]);world=np.column_stack([x,y]).tolist()
            aid='arc-'+hashlib.sha256(json.dumps([owners,points],separators=(',',':')).encode()).hexdigest()[:16]
            arcs.append(dict(boundary_id=aid,owners=list(owners),source_lonlat=points,points=world,
                boundary_kind='shared' if len(owners)==2 else 'source_outer_or_unmatched' if len(owners)==1 else 'nonmanifold',
                uncertainty=dict(positional_half_width_m=None,historical_half_width_m=None,
                    display_half_width_world=2,display_width_is_not_accuracy=True,
                    note='提供形状の位置精度・1582年との差は未定量。2座標単位の帯は未確認区間を示す表示記号で、測量誤差ではない。'),
                temporal_basis='later_comparison',adoption_status='held'))
    return arcs,len(edges)
def build():
    m,xy,ll=transforms()
    ledger=read('data/editorial/districts/districts.json')['districts']
    scope=read('data/editorial/districts/scope.json')
    registry=read('data/derived/political/approved_western/political_registry.json')
    parents={r['region_id']:unary_union([Polygon(p) for p in r['polygons']]) for r in registry['regions']}
    summaries=[]
    for parent in scope['parents']:
        rid=parent['parent_region_id']
        entries=[d for d in ledger if rid in d['candidate_parent_region_ids']]
        geoms={};records=[];issues=[]
        for entry in entries:
            if not entry['external_ids']: continue
            gid=entry['external_ids']['district_id'];source=RAW/'kg'/f'{gid}.geojson'
            data=read(source)
            geom=unary_union([shape(f['geometry']) for f in data['features']])
            if not geom.is_valid:
                issues.append(dict(id=gid,type='invalid_source_geometry',reason=explain_validity(geom)));continue
            geoms[gid]=geom
        arcs,edge_count=network(geoms,xy)
        arc_lines={a['boundary_id']:LineString(a['points']) for a in arcs}
        max_error=0.0
        for gid,g in geoms.items():
            w=transform(xy,g)
            entry=next(d for d in entries if d['external_ids'].get('district_id')==gid)
            refs=[a['boundary_id'] for a in arcs if gid in a['owners']]
            faces=list(polygonize([arc_lines[a] for a in refs]))
            reconstructed=unary_union([p for p in faces if w.covers(p.representative_point())])
            error=w.symmetric_difference(reconstructed).area;max_error=max(max_error,error)
            if error>1e-4: issues.append(dict(id=gid,type='network_reconstruction_difference',area_world2=error))
            records.append(dict(candidate_id=entry['district_entity_id'],external_id=gid,
                candidate_name=entry['candidate_display_name'],historical_province_id=entry['historical_province_id'],
                source_ref='kg-geometry-'+gid,source_locator=gid+'.geojson / features[*]',
                source_sha256=sha(RAW/'kg'/f'{gid}.geojson'),boundary_refs=refs,
                polygon_geometry=mapping(reconstructed),polygon_is_derived=True,
                label_point=list(w.representative_point().coords[0]),
                target_adoption_status=entry['adoption_status'],temporal_basis='later_comparison',
                note='国の全郡を同じ共有辺網で扱う。親国での切断・被覆・1582年採用は未実施。'))
        for a in arcs:
            a['source_refs']=['kg-geometry-'+x for x in a['owners']]
            if len(a['owners'])>2: issues.append(dict(id=a['boundary_id'],type='nonmanifold'))
        world_geoms=[transform(xy,g) for g in geoms.values()]
        union=unary_union(world_geoms)
        overlap=sum(g.area for g in world_geoms)-union.area
        if overlap>1e-4: issues.append(dict(type='source_overlap_preserved',area_world2=overlap))
        # Numeric roundtrip is a transform test, explicitly NOT empirical map accuracy.
        sample=np.asarray([a['source_lonlat'][0] for a in arcs])
        x,y=xy(sample[:,0],sample[:,1]);lon,lat=ll(x,y)
        roundtrip=float(np.max(np.abs(np.column_stack([lon,lat])-sample)))
        summary=dict(parent_region_id=rid,name=parent['display_name'],geometry_candidates=len(records),
            unlocated_candidate_ids=[d['district_entity_id'] for d in entries if not d['external_ids']],
            unique_atomic_edges=edge_count,shared_arcs=sum(len(a['owners'])==2 for a in arcs),arcs=len(arcs),
            network_reconstruction_max_area_error_world2=max_error,coordinate_roundtrip_error_degrees=roundtrip,
            source_overlap_world2=overlap,source_outside_current_parent_world2=union.difference(parents[rid]).area,
            current_parent_without_source_world2=parents[rid].difference(union).area,
            raster_registration='pilot_izumi_only' if rid=='izumi' else 'not_performed; input_already_georeferenced',
            empirical_georeferencing_accuracy_m=None,issues=issues,
            status='comparison_network_review_required',target_year=1582,target_geometry_accepted=False)
        payload=dict(schema_version=1,parent_region_id=rid,world_size=[8192,8192],coordinate_system='existing_game_transform',
            canonical_edit_layer='boundaries',polygons_are_reconstructed_derivatives=True,
            export_allowed=False,boundaries=arcs,candidates=records,qa=summary)
        write(WORK/rid/'network.json',payload);summaries.append(summary)
        print(rid,len(records),'candidates;',len(arcs),'arcs; issues',len(issues),flush=True)
    write(EDITOR/'national_inventory.json',dict(schema_version=1,parents=summaries,scope='66 existing parent research buckets',
        original_geometry_folder=RAW.relative_to(ROOT).as_posix(),work_folder=WORK.relative_to(ROOT).as_posix(),
        source_epoch='later_comparison',not_a_1582_boundary_dataset=True))
    write(EDITOR/'input_manifest.json',dict(files=[dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)) for p in
        [ROOT/'data/editorial/districts/districts.json',ROOT/'data/editorial/districts/scope.json',ROOT/'data/base/japan_land_manifest.json',ROOT/'data/derived/political/approved_western/political_registry.json']],
        generator_sha256=sha(Path(__file__)),source_manifest_sha256=sha(RAW/'geometry_sources.json')))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['fetch','build']);a=p.parse_args();globals()[a.action]()
