"""Game-display grouping only. Preserve historical source partitions and unknowns."""
from pathlib import Path
import copy
import hashlib
import json
from collections import defaultdict
from shapely.geometry import Polygon, LineString, Point
from shapely.ops import unary_union
from report_district_areas import area_measure

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT/'data/editorial/districts/display_merge_policy.json'


def write(p, v):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(v, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')


def unique(items):
    return list({json.dumps(x, sort_keys=True, ensure_ascii=False):x for x in items}.values())


def apply_merges(dest):
    policy = json.loads(CONFIG.read_text(encoding='utf-8'))
    threshold = policy['threshold_km2']
    _, measure = area_measure()
    index_path = dest/'index.json'
    index = json.loads(index_path.read_text(encoding='utf-8'))
    original_records = {r['key']:copy.deepcopy(r) for r in index['regions']}
    output, operations, leftovers = [], [], []
    before = len(index['regions'])
    for parent in index['parents']:
        pid = parent['id']; path = dest/pid/'geometry.json'
        source = json.loads(path.read_text(encoding='utf-8'))
        geoms = {r['key']:unary_union([Polygon(p[0], p[1:]) for p in r['polygons']]) for r in source['regions']}
        groups = {key:dict(key=key, members=[key], name=original_records[key]['name'], g=g,
            area=measure(g), frozen=False, kind=original_records[key]['kind'], label=original_records[key]['label']) for key,g in geoms.items()}
        # Shared edges, not proximity or point contact, establish neighbors.
        edges = defaultdict(float)
        for line in source['lines']:
            if len(line['owners']) == 2:
                edges[tuple(sorted(line['owners']))] += LineString(line['points']).length
        while True:
            owner = {member:key for key,g in groups.items() for member in g['members']}
            neighbors = defaultdict(lambda:defaultdict(float))
            for (a,b),length in edges.items():
                a,b = owner[a],owner[b]
                if a!=b and length>1e-6:
                    neighbors[a][b]+=length;neighbors[b][a]+=length
            chosen = None
            small = sorted((g for g in groups.values() if g['kind']=='candidate' and not g['frozen'] and g['area']<=threshold),key=lambda g:(g['area'],g['key']))
            for a in small:
                options = [groups[k] for k in neighbors[a['key']] if groups[k]['kind']=='candidate' and not groups[k]['frozen']]
                if options:
                    # Most shared border, then larger area, then stable key.
                    b = min(options,key=lambda g:(-neighbors[a['key']][g['key']],-g['area'],g['key']))
                    chosen = a,b,neighbors[a['key']][b['key']];break
            exception = None
            if chosen is None:
                for rule in policy.get('forced_merges',[]):
                    if rule['source'] not in owner or rule['target'] not in owner: continue
                    a,b=groups[owner[rule['source']]],groups[owner[rule['target']]]
                    if a['key']==b['key']: continue
                    shared=neighbors[a['key']].get(b['key'],0)
                    if shared<=1e-6: raise ValueError('Explicit merge is not edge-adjacent')
                    chosen=a,b,shared;exception=rule;break
            if chosen is None: break
            a,b,shared = chosen
            leader = min([a,b],key=lambda g:(-g['area'],g['key']))
            members = sorted(a['members']+b['members'])
            key = pid+'/merged-'+hashlib.sha256('\n'.join(members).encode()).hexdigest()[:16]
            geom = unary_union([a['g'],b['g']]);area = measure(geom)
            assert geom.is_valid and abs(area-a['area']-b['area'])<.001
            merged = dict(key=key,members=members,name=leader['name'],g=geom,area=area,
                frozen=area>threshold,kind='candidate',label=leader['label'])
            assert geom.contains(Point(merged['label']))
            operations.append(dict(parent=pid,country=original_records[members[0]]['parent_name'],
                input_keys=[a['key'],b['key']],input_names=[a['name'],b['name']],input_areas_km2=[a['area'],b['area']],
                result_key=key,result_name=leader['name'],result_area_km2=area,shared_boundary_world_units=shared,
                stopped=merged['frozen'],member_keys=members,explicit_exception=exception))
            del groups[a['key']];del groups[b['key']];groups[key]=merged
        owner = {member:key for key,g in groups.items() for member in g['members']}
        for g in groups.values():
            if g['kind']=='candidate' and g['area']<=threshold:
                adjacent = {owner[b] if owner[a]==g['key'] else owner[a] for a,b in edges if owner[a]!=owner[b] and g['key'] in [owner[a],owner[b]]}
                reason = '境界を共有する郡候補がない（国境・海・郡未確定で隔てられている）'
                if any(groups[k]['kind']=='candidate' for k in adjacent): reason='隣接候補は合併後35 km²超で停止済み'
                leftovers.append(dict(key=g['key'],country=original_records[g['members'][0]]['parent_name'],name=g['name'],area_km2=g['area'],reason=reason))
        # An untouched parent keeps its exact bytes, including all unresolveds.
        if all(len(g['members'])==1 for g in groups.values()):
            output.extend(original_records[k] for k in groups);continue
        payload = dict(regions=[],lines=[])
        for g in sorted(groups.values(),key=lambda g:g['key']):
            members = [original_records[k] for k in g['members']]
            if len(members)==1:
                meta=members[0]
                payload['regions'].append(next(r for r in source['regions'] if r['key']==g['key']))
            else:
                meta=copy.deepcopy(members[0]);meta.update(key=g['key'],name=g['name'],bounds=list(g['g'].bounds),label=g['label'],
                    merge_members=[dict(key=r['key'],name=r['name']) for r in members],
                    search_aliases=' '.join(r['name'] for r in members),sources=unique([s for r in members for s in r['sources']]),
                    sites=unique([dict(s,original_district_key=r['key']) for r in members for s in r['sites']]),
                    merge_area_km2=g['area'],merge_stopped=g['frozen'])
                meta['remaining']='ゲーム表示用に35 km²以下の郡を合併。史料上の郡を統合した判断ではありません。\n'+meta['remaining']
                meta['mesh_file']='res://data/derived/districts/unconfirmed/'+g['key']+'.bin'
                (dest/(g['key']+'.bin')).write_bytes(b''.join((ROOT/r['mesh_file'].removeprefix('res://')).read_bytes() for r in members))
                parts=[g['g']] if g['g'].geom_type=='Polygon' else g['g'].geoms
                payload['regions'].append(dict(key=g['key'],polygons=[[list(p.exterior.coords)]+[list(h.coords) for h in p.interiors] for p in parts]))
            output.append(meta)
        for line in source['lines']:
            owners=sorted({owner[k] for k in line['owners']})
            if len(owners)<2:continue
            result=copy.deepcopy(line);result['owners']=owners;payload['lines'].append(result)
        assert unary_union([g['g'] for g in groups.values()]).symmetric_difference(unary_union(list(geoms.values()))).area<1e-6
        write(path,payload)
    index['regions']=sorted(output,key=lambda r:r['key'])
    index['display_merge_policy']=policy
    write(index_path,index)
    report=dict(policy=policy,before_regions=before,after_regions=len(output),operations=operations,leftovers=leftovers,
        unresolved_unchanged=all(original_records[r['key']]==r for r in output if r['kind']=='unresolved'),
        source_to_display={m['key']:r['key'] for r in output for m in r.get('merge_members',[dict(key=r['key'])])})
    assert report['unresolved_unchanged']
    assert len(report['source_to_display'])==before
    write(dest/'merge_report.json',report)
    manifest_path=dest/'manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    inventory=['index.json','merge_report.json']+[p['id']+'/geometry.json' for p in index['parents']]+[r['key']+'.bin' for r in output]
    manifest.update(regions=len(output),original_regions=before,merge_operations=len(operations),files={n:hashlib.sha256((dest/n).read_bytes()).hexdigest() for n in inventory})
    write(manifest_path,manifest)
    print(f'MERGED: {len(operations)} operations; {before} -> {len(output)} regions; {len(leftovers)} small regions remain')


if __name__=='__main__':
    from build_district_unconfirmed import build
    build()
