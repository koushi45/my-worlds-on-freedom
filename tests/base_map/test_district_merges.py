"""Verify actual merged display data against untouched Stage F geometry."""
import json
import sys
from pathlib import Path
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from report_district_areas import area_measure


def read(p): return json.loads(p.read_text(encoding='utf-8'))
def geom(r): return unary_union([Polygon(p[0],p[1:]) for p in r['polygons']])


def main():
    before=ROOT/'data/work/districts/stage_f'
    after=ROOT/'data/derived/districts/unconfirmed'
    original=read(before/'index.json');current=read(after/'index.json');report=read(after/'merge_report.json')
    _,measure=area_measure()
    records={r['key']:r for r in current['regions']}
    assert len(records)==709 and sum(r['kind']=='unresolved' for r in records.values())==75
    frozen=set()
    for op in report['operations']:
        if frozen.intersection(op['input_keys']):
            exception=op['explicit_exception']
            assert exception['source']=='hizen/candidate-district-candidate-g67002'
            assert exception['target']=='hizen/candidate-district-candidate-g67004'
            assert exception['source'] in op['member_keys'] and exception['target'] in op['member_keys']
        assert min(op['input_areas_km2'])<=35
        assert abs(sum(op['input_areas_km2'])-op['result_area_km2'])<.001
        largest=max(range(2),key=lambda i:op['input_areas_km2'][i])
        assert op['result_name']==op['input_names'][largest]
        assert op['shared_boundary_world_units']>1e-6
        assert all(k.startswith(op['parent']+'/') for k in op['member_keys'])
        if op['result_area_km2']>35:
            assert op['stopped'];frozen.add(op['result_key'])
    member_map=report['source_to_display']
    assert set(member_map)=={r['key'] for r in original['regions']}
    for parent in original['parents']:
        pid=parent['id'];old=read(before/pid/'geometry.json');new=read(after/pid/'geometry.json')
        oldg={r['key']:geom(r) for r in old['regions']};newg={r['key']:geom(r) for r in new['regions']}
        assert unary_union(list(oldg.values())).symmetric_difference(unary_union(list(newg.values()))).area<1e-6
        assert abs(sum(g.area for g in newg.values())-sum(g.area for g in oldg.values()))<1e-6
        for key,g in newg.items():
            r=records[key];members=sorted(k for k,v in member_map.items() if v==key)
            assert g.is_valid and g.contains(Point(r['label']))
            assert g.symmetric_difference(unary_union([oldg[k] for k in members])).area<1e-6
            # Merged terrain meshes reuse the exact, disjoint source triangles.
            assert (after/(key+'.bin')).read_bytes()==b''.join((before/(k+'.bin')).read_bytes() for k in members)
            if r['kind']=='unresolved':
                assert members==[key]
                assert next(x for x in old['regions'] if x['key']==key)==next(x for x in new['regions'] if x['key']==key)
                assert '（仮' in r['name'] and r['provisional_name']['geometry_changed']==False
                assert r['provisional_name']['donor_key'].startswith(pid+'/')
                assert r['sources'] and r['confidence']=='名称は便宜的な仮称・境界と所属は未確定'
            if r.get('merge_members'):
                assert abs(measure(g)-r['merge_area_km2'])<1e-6
        expected={line['id']:{**line,'owners':sorted({member_map[k] for k in line['owners']})} for line in old['lines'] if len({member_map[k] for k in line['owners']})>=2}
        assert {line['id']:{**line,'owners':sorted(line['owners'])} for line in new['lines']}==expected
    assert all(r['adoption_status']=='held' for r in records.values())
    assert read(ROOT/'data/derived/districts/accepted/index.json')['regions']==[]
    assert len(report['operations'])==39 and not report['leftovers']
    hizen=next(r for r in records.values() if r['parent']=='hizen' and r['name']=='神崎郡')
    assert {m['name'] for m in hizen['merge_members']}=={'養父郡','三根郡','神崎郡'}
    assert sum('provisional_name' in r for r in records.values())==75
    print('DISTRICT MERGE QA: PASS; 39 operations, 709 regions, 75 unknown shapes unchanged with explicitly provisional names; Yabu exception applied')


if __name__=='__main__':main()
