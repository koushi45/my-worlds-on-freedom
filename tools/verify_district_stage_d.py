"""Independent output checks plus adversarial partition fixtures."""
from collections import Counter
from itertools import combinations
from pathlib import Path
from shapely.geometry import box, Polygon, shape, mapping, LineString
from shapely.ops import unary_union, polygonize
from build_district_stage_c import read, write, sha, ROOT
from build_district_stage_d import partition, WORK, EDITOR, AREA_EPS, LENGTH_EPS, NEIGHBOR_MIN

def candidate(name,g,status='held'):
    return dict(candidate_id=name,polygon_geometry=mapping(g),target_adoption_status=status)

def fixtures():
    # Overlap is unresolved, source gap is not annexed; parent's hole survives.
    parent=Polygon([(0,0),(10,0),(10,10),(0,10)],holes=[[(7,7),(8,7),(8,8),(7,8)]])
    d,_=partition(parent,[candidate('a',box(-2,0,6,10)),candidate('b',box(4,0,9,10))])
    areas=Counter()
    for r in d['regions']: areas[r['reason']]+=r['area_world2']
    assert areas['source_overlap']==20 and areas['source_gap']==10
    assert abs(sum(r['area_world2'] for r in d['regions'])-99)<AREA_EPS
    d,_=partition(box(0,0,2,2),[candidate('a',box(0,0,1,1)),candidate('b',box(1,1,2,2))])
    assert any(a['kind']=='point_contact' and a['regions']==['candidate-a','candidate-b'] for a in d['adjacency'])
    d,_=partition(box(0,0,2,2),[candidate('a',box(0,0,1,2)),candidate('b',box(1,0,2,0.001)),candidate('c',box(1,0.001,2,2),'excluded')])
    assert any(a['kind']=='short_boundary' and a['regions']==['candidate-a','candidate-b'] for a in d['adjacency'])
    assert any(r['reason']=='excluded_at_target' for r in d['regions'])
    # T junction with different source segmentations must still share one graph.
    d,_=partition(box(0,0,2,2),[candidate('a',box(0,0,1,2)),candidate('b',box(1,0,2,1)),candidate('c',box(1,1,2,2))])
    assert len([a for a in d['adjacency'] if a['kind']=='shared_boundary'])==3
    return ['overlap and gap','parent hole','point-only contact','short positive boundary','excluded candidate','T junction']

def main():
    checked=fixtures();manifest=read(EDITOR/'input_manifest.json')
    for f in manifest['files']: assert sha(ROOT/f['path'])==f['sha256'],f['path']
    assert sha(ROOT/'tools/build_district_stage_d.py')==manifest['generator_sha256']
    inventory=read(EDITOR/'inventory.json')['parents']
    expected={r['region_id'] for r in read('data/derived/political/approved_western/political_registry.json')['regions']}
    assert expected=={r['parent_region_id'] for r in inventory}
    totals=Counter();maximum=Counter()
    for item in inventory:
        d=read(WORK/item['parent_region_id']/'partition.json');parent=shape(d['parent_geometry'])
        assert d['world_size']==[8192,8192] and not d['export_allowed']
        arcs={a['boundary_id']:a for a in d['boundaries']};assert len(arcs)==len(d['boundaries'])
        gs={r['region_id']:shape(r['polygon_geometry']) for r in d['regions']}
        seen=set()
        for a in arcs.values():
            assert 1<=len(a['owners'])<=2 and set(a['owners'])<=gs.keys()
            for p,q in zip(a['points'],a['points'][1:]):
                edge=tuple(sorted([tuple(p),tuple(q)]));assert edge not in seen;seen.add(edge)
        for r in d['regions']:
            g=gs[r['region_id']];assert g.is_valid
            refs={i for i,a in arcs.items() if r['region_id'] in a['owners']}
            assert refs==set(r['boundary_refs'])
            faces=polygonize([LineString(arcs[i]['points']) for i in refs])
            rebuilt=unary_union([p for p in faces if g.covers(p.representative_point())])
            assert rebuilt.symmetric_difference(g).area<AREA_EPS
        union=unary_union(list(gs.values()))
        assert parent.symmetric_difference(union).area<AREA_EPS
        assert abs(sum(g.area for g in gs.values())-union.area)<AREA_EPS
        outer=unary_union([LineString(a['points']) for a in arcs.values() if a['boundary_kind']=='parent_outer'])
        assert outer.hausdorff_distance(parent.boundary)<LENGTH_EPS
        pairs={tuple(a['regions']):a for a in d['adjacency']}
        for pair in combinations(sorted(gs),2):
            common=gs[pair[0]].boundary.intersection(gs[pair[1]].boundary)
            if common.is_empty: assert pair not in pairs
            elif common.length>0:
                a=pairs[pair];assert abs(a['shared_length_world']-common.length)<LENGTH_EPS
                assert a['kind']==('shared_boundary' if common.length>=NEIGHBOR_MIN else 'short_boundary')
            else: assert pairs[pair]['kind']=='point_contact'
        diff=read(WORK/item['parent_region_id']/'differences.json')
        source=read(ROOT/d['source_network']);source_union=unary_union([shape(c['polygon_geometry']) for c in source['candidates']])
        assert shape(diff['parent_minus_source']).symmetric_difference(parent.difference(source_union)).area<AREA_EPS
        assert shape(diff['source_minus_parent']).symmetric_difference(source_union.difference(parent)).area<AREA_EPS
        totals.update(regions=len(gs),arcs=len(arcs),unresolved_regions=sum(r['kind']=='unresolved' for r in d['regions']))
        totals.update(a['kind'] for a in d['adjacency'])
        for k in ['uncovered_world2','outside_world2','overlap_world2','outer_hausdorff_world']: maximum[k]=max(maximum[k],d['qa'][k])
    result=dict(status='passed',parents=len(inventory),totals=dict(totals),maximum_errors=dict(maximum),fixtures=checked,
        frozen_inputs=len(manifest['files']),historical_validity_not_asserted=True)
    write(EDITOR/'qa.json',result);print(result)

if __name__=='__main__': main()
