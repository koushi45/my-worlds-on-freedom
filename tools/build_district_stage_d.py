"""Close review partitions inside unchanged current parents, from noded shared edges."""
from itertools import combinations
from collections import defaultdict
import hashlib
import json
from html import escape
from pathlib import Path
from shapely.geometry import Polygon, LineString, mapping, shape
from shapely.ops import unary_union, polygonize
from shapely.strtree import STRtree
from build_district_stage_c import ROOT, read, write, sha, network

WORK=ROOT/'data/work/districts/stage_d'
EDITOR=ROOT/'data/editorial/districts/stage_d'
AREA_EPS=1e-6  # validation tolerance only; never an automatic historical-area deletion rule
LENGTH_EPS=1e-8
NEIGHBOR_MIN=0.01  # world units, classification only; short positive contacts are retained

def parts(g):
    if g.geom_type=='Polygon': return [g] if not g.is_empty else []
    return [p for child in getattr(g,'geoms',[]) for p in parts(child)]

def ident(prefix,value):
    return prefix+hashlib.sha256(value.encode()).hexdigest()[:16]

def partition(parent, candidates):
    assert parent.is_valid
    gs=[shape(c['polygon_geometry']) for c in candidates]
    assert all(g.is_valid for g in gs)
    # GEOS nodes crossings and T junctions; no precision grid or proximity snapping.
    # Node original lines with the parent once; pre-clipping each polygon separately
    # would round shared intersections independently and create tiny open slivers.
    linework=unary_union([parent.boundary]+[g.boundary for g in gs if not g.is_empty and g.area>0])
    faces=[p for p in polygonize(linework) if parent.covers(p.representative_point())]
    tree=STRtree(gs); groups=defaultdict(list); reasons={}; face_groups={}; face_geoms={}
    for f in faces:
        point=f.representative_point()
        indices=sorted(int(i) for i in tree.query(point) if gs[int(i)].covers(point))
        owners=[candidates[i]['candidate_id'] for i in indices]
        if len(indices)==1 and candidates[indices[0]]['target_adoption_status']!='excluded':
            rid='candidate-'+owners[0];reason='later_comparison_clipped'
        else:
            reason='source_gap' if not indices else 'excluded_at_target' if len(indices)==1 else 'source_overlap'
            rid=ident('unresolved-',reason+json.dumps(owners))
        fid=ident('face-',f.wkb_hex)
        face_geoms[fid]=f;face_groups[fid]=rid;groups[rid].append(f)
        reasons[rid]=(reason,owners)
    raw_arcs,_=network(face_geoms,lambda x,y:(x,y))
    arcs=[]
    for a in raw_arcs:
        original_owners=a['owners'];owners=sorted({face_groups[f] for f in original_owners})
        if len(original_owners)==2 and len(owners)==1: continue
        assert len(owners)<=2
        a.pop('source_lonlat');a['owners']=owners
        a['boundary_id']=ident('edge-',json.dumps([owners,a['points']],separators=(',',':')))
        a['boundary_kind']='parent_outer' if len(original_owners)==1 else 'internal_shared'
        a['origin']='current_parent_boundary' if len(original_owners)==1 else 'stage_c_comparison_boundary'
        a['uncertainty']['note']='親領域の外周は現行形状を再利用。内部線は後世比較資料に由来し1582年未確定。'
        arcs.append(a)
    regions=[];rebuilt={}
    for rid,fs in sorted(groups.items()):
        refs=[a['boundary_id'] for a in arcs if rid in a['owners']]
        source=unary_union(fs)
        loops=polygonize([LineString(a['points']) for a in arcs if rid in a['owners']])
        g=unary_union([p for p in loops if source.covers(p.representative_point())])
        assert g.is_valid and source.symmetric_difference(g).area<AREA_EPS
        rebuilt[rid]=g;reason,owners=reasons[rid]
        regions.append(dict(region_id=rid,kind='unresolved' if rid.startswith('unresolved') else 'candidate',
            reason=reason,candidate_refs=owners,boundary_refs=refs,polygon_geometry=mapping(g),
            polygon_is_derived=True,area_world2=g.area,adoption_status='held',historical_geometry_confirmed=False))
    lengths=defaultdict(float);edge_refs=defaultdict(list)
    for a in arcs:
        if len(a['owners'])==2:
            pair=tuple(a['owners']);lengths[pair]+=LineString(a['points']).length;edge_refs[pair].append(a['boundary_id'])
    # Point contact comes from vertices of the very same graph, never bbox proximity.
    vertices=defaultdict(set)
    for a in arcs:
        for p in a['points']: vertices[tuple(p)].update(a['owners'])
    touches=defaultdict(list)
    for p,owners in vertices.items():
        for pair in combinations(sorted(owners),2):
            if pair not in lengths: touches[pair].append(p)
    adjacency=[dict(regions=list(pair),kind='shared_boundary' if n>=NEIGHBOR_MIN else 'short_boundary',
        shared_length_world=n,boundary_refs=edge_refs[pair]) for pair,n in sorted(lengths.items())]
    adjacency += [dict(regions=list(pair),kind='point_contact',shared_length_world=0,boundary_refs=[],points=pts) for pair,pts in sorted(touches.items())]
    union=unary_union(list(rebuilt.values()))
    outer=unary_union([LineString(a['points']) for a in arcs if a['boundary_kind']=='parent_outer'])
    qa=dict(uncovered_world2=parent.difference(union).area,outside_world2=union.difference(parent).area,
        overlap_world2=max(0,sum(g.area for g in rebuilt.values())-union.area),
        outer_hausdorff_world=outer.hausdorff_distance(parent.boundary),
        regions=len(regions),unresolved_regions=sum(r['kind']=='unresolved' for r in regions),
        unresolved_area_world2=sum(r['area_world2'] for r in regions if r['kind']=='unresolved'),
        arcs=len(arcs),adjacency_counts={k:sum(a['kind']==k for a in adjacency) for k in ['shared_boundary','short_boundary','point_contact']})
    assert max(qa[k] for k in ['uncovered_world2','outside_world2','overlap_world2'])<AREA_EPS,qa
    assert qa['outer_hausdorff_world']<LENGTH_EPS,qa
    return dict(boundaries=arcs,regions=regions,adjacency=adjacency,qa=qa),gs

def build():
    regpath=ROOT/'data/derived/political/approved_western/political_registry.json'
    registry=read(regpath);inputs=[dict(path=regpath.relative_to(ROOT).as_posix(),sha256=sha(regpath))];summary=[]
    for parent in registry['regions']:
        rid=parent['region_id'];path=ROOT/f'data/work/districts/stage_c/{rid}/network.json';source=read(path)
        inputs.append(dict(path=path.relative_to(ROOT).as_posix(),sha256=sha(path)))
        p=unary_union([Polygon(r) for r in parent['polygons']])
        d,gs=partition(p,source['candidates']);total=unary_union(gs)
        differences=[]
        for c,g in zip(source['candidates'],gs):
            outside=g.difference(p)
            differences.append(dict(candidate_id=c['candidate_id'],external_id=c['external_id'],source_ref=c['source_ref'],
                source_sha256=c['source_sha256'],outside_geometry=mapping(outside),outside_area_world2=outside.area,
                retained_area_world2=g.intersection(p).area,reason='clip_to_unchanged_current_parent',
                historical_boundary_move=False))
        diff=dict(parent_minus_source=mapping(p.difference(total)),source_minus_parent=mapping(total.difference(p)),
            candidate_clips=differences,reason='ゲームの現行親領域で表示候補を閉じる。史料側の国形状を修正したという判断ではない。',
            numeric_policy=dict(grid_snap=None,sliver_deletion=False,automatic_repair=False,
                validation_area_epsilon_world2=AREA_EPS,validation_length_epsilon_world=LENGTH_EPS,
                note='微小面も削除・吸着しない。許容値は検証の浮動小数点演算差にのみ使用。'),
            pending_regions=[r['region_id'] for r in d['regions'] if r['kind']=='unresolved'])
        d.update(schema_version=1,parent_region_id=rid,world_size=[8192,8192],export_allowed=False,
            status='closed_comparison_partition_review_required',canonical_edit_layer='boundaries',
            source_network=path.relative_to(ROOT).as_posix(),parent_source=regpath.relative_to(ROOT).as_posix(),
            parent_geometry=mapping(p),candidates=source['candidates'],
            adjacency_policy=dict(min_shared_length_world=NEIGHBOR_MIN,short_positive_edges_preserved=True),
            excluded_sources=['izumi_genroku_held_registration; not promoted to closing geometry'])
        for a in d['boundaries']:
            a['source_network']=d['source_network']
            a['parent_region_id']=rid
        write(WORK/rid/'partition.json',d);write(WORK/rid/'differences.json',diff)
        summary.append(dict(parent_region_id=rid,**d['qa']))
        print(rid,d['qa'],flush=True)
    write(EDITOR/'input_manifest.json',dict(files=inputs,generator_sha256=sha(Path(__file__))))
    write(EDITOR/'inventory.json',dict(parents=summary,export_allowed=False,historical_geometry_confirmed=False))

if __name__=='__main__': build()
