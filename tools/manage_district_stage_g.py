"""Country-scoped review snapshots, explicit adoption gate, immutable releases."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, json, hashlib, shutil, os
import numpy as np
import shapely
from shapely.geometry import shape, Point, LineString, Polygon
from shapely.ops import unary_union
from build_district_stage_c import ROOT, read, sha, write

EDITOR=ROOT/'data/editorial/districts/stage_g'
PACKAGES=ROOT/'data/work/districts/stage_g/packages'
RUNTIME=ROOT/'data/derived/districts/accepted'
MASTER=ROOT/'data/master/districts/releases'
ALLOWED={'accepted_game_estimate','accepted_unresolved_area'}

def digest(v): return hashlib.sha256(json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def utc(): return datetime.now(timezone.utc).isoformat()
def atomic(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True)
    tmp=path.with_suffix(path.suffix+'.tmp')
    tmp.write_text(json.dumps(obj,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8');os.replace(tmp,path)
def safe_id(pid):
    if not pid or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-_' for c in pid): raise ValueError('Invalid country/revision ID')
def initialize(runtime=RUNTIME):
    if not (runtime/'index.json').exists():
        atomic(runtime/'index.json',dict(schema_version=1,status='accepted_registry',world_size=[8192,8192],parents=[],regions=[],active_releases={}))

def country_qa(d,f,metadata):
    p=shape(d['parent_geometry']);gs=[shape(r['polygon_geometry']) for r in d['regions']]
    assert p.is_valid and all(g.is_valid for g in gs)
    merged=unary_union(gs)
    assert p.symmetric_difference(merged).area<1e-6
    assert abs(sum(g.area for g in gs)-merged.area)<1e-6
    expected={d['parent_region_id']+'/'+a['boundary_id']:a for a in d['boundaries'] if a['boundary_kind']=='internal_shared'}
    assert len(f['lines'])==len(expected)
    for a in f['lines']:
        assert a['points']==expected[a['id']]['points']
        assert a['owners']==[d['parent_region_id']+'/'+x for x in expected[a['id']]['owners']]
    meta={m['key']:m for m in metadata}
    polygons={r['key']:unary_union([Polygon(p[0],p[1:]) for p in r['polygons']]) for r in f['regions']}
    assert set(meta)=={d['parent_region_id']+'/'+r['region_id'] for r in d['regions']}
    triangles=0
    for r,g in zip(d['regions'],gs):
        m=meta[d['parent_region_id']+'/'+r['region_id']]
        assert polygons[m['key']].symmetric_difference(g).area<1e-6
        assert g.contains(Point(m['label']))
        raw=np.fromfile(ROOT/m['mesh_file'].removeprefix('res://'),dtype='<f4').astype(float).reshape((-1,3,2))
        assert np.isfinite(raw).all()
        assert shapely.covers(g.buffer(.001),shapely.points(raw.mean(axis=1))).all()
        a=raw[:,1]-raw[:,0];b=raw[:,2]-raw[:,0]
        assert abs((np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])/2).sum()-g.area)<max(.001,g.length*.001)
        cell=np.floor((raw.mean(axis=1)+1e-9)/16)*16
        assert ((raw.min(axis=1)>=cell-.001)&(raw.max(axis=1)<=cell+16.001)).all()
        diagonal=raw[:,:,0]+raw[:,:,1]-(cell[:,0]+cell[:,1]+16)[:,None]
        assert ((diagonal.max(axis=1)<=.001)|(diagonal.min(axis=1)>=-.001)).all()
        triangles+=len(raw)
    return dict(status='passed',regions=len(gs),internal_lines=len(expected),terrain_triangles=triangles,
        uncovered_area_world2=p.difference(merged).area,outside_area_world2=merged.difference(p).area,
        overlap_area_world2=max(0,sum(g.area for g in gs)-merged.area),historical_certification=False)

def prepare(pid):
    safe_id(pid)
    scope=next(p for p in read('data/editorial/districts/scope.json')['parents'] if p['parent_region_id']==pid)
    mapping=next(p for p in read('data/editorial/districts/province_mapping.json')['mappings'] if p['parent_region_id']==pid)
    ledger=[r for r in read('data/editorial/districts/districts.json')['districts'] if pid in r['candidate_parent_region_ids']]
    temporal=[r for r in read('data/editorial/districts/review_decisions.json')['decisions'] if set(r.get('district_entity_ids',[]))&{c['district_entity_id'] for c in ledger}]
    dpath=ROOT/f'data/work/districts/stage_d/{pid}/partition.json';d=read(dpath)
    fpath=ROOT/f'data/work/districts/stage_f/{pid}/geometry.json';f=read(fpath)
    fi=read('data/work/districts/stage_f/index.json')
    metadata=[r for r in fi['regions'] if r['parent']==pid]
    parent=next(r for r in fi['parents'] if r['id']==pid)
    differences=ROOT/f'data/work/districts/stage_d/{pid}/differences.json'
    relevant_sites=[s for s in read('data/work/districts/stage_e/site_assignments.json')['sites']
        if any(r['parent_region_id']==pid for r in s.get('containing_regions',[])+s.get('nearby_review_regions',[]))]
    qa=country_qa(d,f,metadata)
    candidate_files={f'{r["region_id"]}.bin':ROOT/f'data/work/districts/stage_f/{pid}/{r["region_id"]}.bin' for r in d['regions']}
    candidate_files.update({'geometry.json':fpath,'partition.json':dpath,'differences.json':differences,
        'review.svg':ROOT/f'data/work/districts/stage_d/{pid}/review.svg'})
    evidence=dict(scope=scope,mapping=mapping,temporal_decisions=temporal,district_candidates=ledger,site_comparisons=relevant_sites)
    inventory={n:sha(p) for n,p in candidate_files.items()}
    revision=digest(dict(files=inventory,metadata=metadata,parent=parent,evidence=evidence,qa=qa))[:20]
    dest=PACKAGES/pid/revision
    packet=dict(schema_version=1,parent=pid,revision=revision,source_files=inventory,metadata=metadata,parent_display=parent,
        evidence=evidence,qa=qa,region_ids=[r['region_id'] for r in d['regions']],
        region_kinds={r['region_id']:r['kind'] for r in d['regions']},status='held',export_allowed=False)
    if not dest.exists():
        dest.mkdir(parents=True)
        for n,p in candidate_files.items(): shutil.copyfile(p,dest/n)
        write(dest/'packet.json',packet)
    else:
        assert read(dest/'packet.json')==packet
        for n,h in inventory.items(): assert sha(dest/n)==h
    atomic(EDITOR/'countries'/f'{pid}.json',dict(parent=pid,revision=revision,package=str(dest.relative_to(ROOT)),qa=qa,status='review_prepared'))
    decision_path=EDITOR/'decisions'/f'{pid}.json'
    if not decision_path.exists():
        write(decision_path,dict(parent=pid,status='held',revision=revision,reason='国対応・時代差・未確定範囲の採用判断待ち',
            decision_ref=None,mapping_decision=None,temporal_decision=None,region_decisions={},distribution_scope=None))
    return packet,dest

def validate_decision(packet,decision):
    if decision.get('status')!='accepted': raise ValueError('Country is held; no adoption decision')
    if decision.get('parent')!=packet['parent'] or decision.get('revision')!=packet['revision']: raise ValueError('Decision is for a different country/revision')
    for field in ['reason','decision_ref','mapping_decision','temporal_decision']:
        if not isinstance(decision.get(field),str) or not decision[field].strip(): raise ValueError('Missing explicit '+field)
    if decision.get('distribution_scope')!='noncommercial': raise ValueError('Current CODH sources require a recorded noncommercial scope')
    if set(decision.get('region_decisions',{}))!=set(packet['region_ids']): raise ValueError('Every region, including unresolved areas, requires a disposition')
    for rid,choice in decision['region_decisions'].items():
        expected='accepted_unresolved_area' if packet['region_kinds'][rid]=='unresolved' else 'accepted_game_estimate'
        if choice!=expected: raise ValueError('Held/excluded or incompatible region disposition: '+rid)

def check_files(folder,manifest):
    for name,h in manifest.items():
        if Path(name).name!=name: raise ValueError('Unsafe file name')
        if sha(folder/name)!=h: raise ValueError('Snapshot hash mismatch: '+name)

def update_index(runtime,pid,release=None):
    initialize(runtime);index=read(runtime/'index.json')
    # Only selected parent is replaced; records for every other parent are preserved.
    index['parents']=[p for p in index['parents'] if p['id']!=pid]
    index['regions']=[r for r in index['regions'] if r['parent']!=pid]
    index['active_releases'].pop(pid,None)
    if release:
        index['parents'].append(release['parent_display']);index['regions'].extend(release['metadata'])
        index['active_releases'][pid]=dict(revision=release['release_id'],decision_sha256=release['decision_sha256'])
    index['parents'].sort(key=lambda p:p['id']);index['regions'].sort(key=lambda r:r['key'])
    atomic(runtime/'index.json',index)

def install_release(release,src,runtime):
    dest=runtime/'releases'/release['parent']/release['release_id']
    dest.mkdir(parents=True,exist_ok=True)
    for n,h in release['files'].items():
        if (dest/n).exists():
            if sha(dest/n)!=h: raise ValueError('Immutable runtime release modified')
        else: shutil.copyfile(src/n,dest/n)
    atomic(dest/'release.json',release)

def integrate(pid,decision,package,runtime=RUNTIME,master=MASTER):
    packet=read(package/'packet.json');validate_decision(packet,decision);check_files(package,packet['source_files'])
    if packet['parent']!=pid: raise ValueError('Requested parent differs from snapshot')
    expected_revision=digest(dict(files=packet['source_files'],metadata=packet['metadata'],parent=packet['parent_display'],evidence=packet['evidence'],qa=packet['qa']))[:20]
    if expected_revision!=packet['revision']: raise ValueError('Review packet altered after snapshot')
    assert packet['qa']['status']=='passed'
    # Also pin the current parent polygon. Other parents may legitimately change.
    current=next(r for r in read('data/derived/political/approved_western/political_registry.json')['regions'] if r['region_id']==pid)
    p=unary_union([Polygon(x) for x in current['polygons']])
    if not p.equals(shape(read(package/'partition.json')['parent_geometry'])): raise ValueError('Current parent geometry changed; rebuild review first')
    release_id=digest(dict(package_revision=packet['revision'],decision=decision))[:20]
    prefix=f'res://data/derived/districts/accepted/releases/{pid}/{release_id}/'
    metadata=json.loads(json.dumps(packet['metadata']))
    for r in metadata:
        rid=r['key'].split('/',1)[1]
        r['adoption']='採用（未確定領域を保持）' if r['kind']=='unresolved' else '採用（ゲーム用推定）'
        r['adoption_status']=decision['region_decisions'][rid]
        r['decision_ref']=decision['decision_ref'];r['mesh_file']=prefix+rid+'.bin'
    parent=dict(packet['parent_display']);parent.update(file=prefix+'geometry.json',adoption_status='accepted',release_id=release_id)
    files={n:h for n,h in packet['source_files'].items() if n=='geometry.json' or n.endswith('.bin')}
    release=dict(parent=pid,release_id=release_id,package_revision=packet['revision'],status='accepted',
        metadata=metadata,parent_display=parent,files=files,decision=decision,decision_sha256=digest(decision),
        parent_geometry_digest=digest(read(package/'partition.json')['parent_geometry']),credit='CODH / NIHU CC BY-NC 4.0')
    archive=master/pid/release_id;archive.mkdir(parents=True,exist_ok=True)
    for n,h in files.items():
        if not (archive/n).exists(): shutil.copyfile(package/n,archive/n)
        assert sha(archive/n)==h
    if (archive/'release.json').exists(): assert read(archive/'release.json')==release
    else: write(archive/'release.json',release)
    install_release(release,archive,runtime);update_index(runtime,pid,release)
    return release

def rollback(pid,revision,runtime=RUNTIME,master=MASTER):
    safe_id(pid)
    if revision=='none': update_index(runtime,pid);return
    safe_id(revision);src=master/pid/revision;release=read(src/'release.json')
    if release['parent']!=pid or release['status']!='accepted': raise ValueError('Not an adopted release')
    if digest(release['decision'])!=release['decision_sha256']: raise ValueError('Decision hash mismatch')
    check_files(src,release['files'])
    current=next(r for r in read('data/derived/political/approved_western/political_registry.json')['regions'] if r['region_id']==pid)
    from shapely.geometry import Polygon, mapping
    if digest(mapping(unary_union([Polygon(p) for p in current['polygons']])))!=release['parent_geometry_digest']:
        raise ValueError('Parent changed since release; rollback blocked without a new comparison')
    install_release(release,src,runtime);update_index(runtime,pid,release)

def verify(runtime=RUNTIME):
    index=read(runtime/'index.json');assert index['status']=='accepted_registry'
    assert {p['id'] for p in index['parents']}==set(index['active_releases'])
    expected=[]
    for p in index['parents']:
        ref=index['active_releases'][p['id']]
        folder=runtime/'releases'/p['id']/ref['revision'];r=read(folder/'release.json')
        assert r['status']=='accepted' and r['decision_sha256']==ref['decision_sha256']==digest(r['decision'])
        check_files(folder,r['files']);assert p==r['parent_display'];expected.extend(r['metadata'])
    assert sorted(expected,key=lambda r:r['key'])==index['regions']
    assert all(r['adoption_status'] in ALLOWED for r in index['regions'])
    return dict(status='passed',accepted_parents=len(index['parents']),runtime_regions=len(index['regions']))

def report():
    base=ROOT/'docs/districts/stage_g';base.mkdir(parents=True,exist_ok=True)
    active=read(RUNTIME/'index.json')['active_releases']
    rows=['# 工程G・国別の採用検討一覧','',f'実行時に採用中：{len(active)}領域。技術検査の通過は歴史的採用ではない。A案＝現行国を維持し、閉区画を後世資料に基づくゲーム推定として採用。B案＝保留して通常実行には郡を入れない。各国の未確定面・時代補正・国対応を比較して選ぶ。','','|現行国|閉区画|未確定率|採用検討資料|','|---|---:|---:|---|']
    for file in sorted((EDITOR/'countries').glob('*.json')):
        pointer=read(file);folder=ROOT/pointer['package'];p=read(folder/'packet.json');pid=p['parent']
        d=read(folder/'partition.json');diff=read(folder/'differences.json');e=p['evidence'];scope=e['scope']
        area=shape(d['parent_geometry']).area;unresolved=sum(r['area_world2'] for r in d['regions'] if r['kind']=='unresolved')
        rel='../../../'+folder.relative_to(ROOT).as_posix()
        adoption='採用中の版：`'+active[pid]['revision']+'`' if pid in active else '実行時への採用なし'
        lines=[f'# {scope["display_name"]}：工程Gの比較案','',f'親ID：`{pid}`。候補版：`{p["revision"]}`。候補原本は保留として保存。{adoption}。', '',
            f'[候補・差分図]({rel}/review.svg)／[既存国との差分面]({rel}/differences.json)／[入力・検査・時代補正の記録]({rel}/packet.json)','',
            f'閉区画 {len(d["regions"])}件、未確定領域の面積率 {100*unresolved/area:.2f}%。資料側だけの面積 {shape(diff["source_minus_parent"]).area:.3f}、現行国側だけの面積 {shape(diff["parent_minus_source"]).area:.3f}（ワールド単位²）。', '',
            '## 国対応','',f'史料上の対応候補：{scope["historical_province_name"]} (`{scope["historical_province_id"]}`)。{e["mapping"]["mapping_status"]}。関係：{e["mapping"]["relation"]}。', '',
            '表示範囲は現行親領域に固定する。対応が暫定の国を名前の一致で確定扱いしない。特に東北の後世の国区分は、陸奥・出羽の史料上の所属と現在の表示断片を区別する。', '',
            '## 比較案','',
            f'- **A案：ゲーム用推定として採用**。図の{len(d["regions"])}閉区画と未確定面{100*unresolved/area:.2f}%をそのまま保持。破線・年代未確定表示を継続し、所属拠点は確定扱いしない。対象年除外の区画を当時の郡として復活させない。',
            '- **B案：保留を継続**。通常実行は既存国だけとし、郡候補は比較表示で参照する。国境・道路・拠点に変更なし。',
            '- **国対応の変更案**。現行親領域自体を統合・改称する場合は別の国改訂案が必要。今回の国別成果を切り貼りして陸奥・出羽等を改訂済みにしない。','',
            '## 時代補正・採否の一覧','', '|候補|工程Bの採否|位置候補|', '|---|---|---|']
        for c in e['district_candidates']:
            lines.append(f'|{c["candidate_display_name"]}|{c["adoption_status"]}|'+('後世比較のみ' if c['external_ids'] else '位置未確定・面を追加しない')+'|')
        for t in e['temporal_decisions']:
            lines.extend(['',f'- {t["decision_id"]}：{t["decision"]}'])
        lines+=['','1582年への形状継続は未確認。上記の補正判断は名称・候補整理を含み、境界復元の完了を意味しない。','',
            '## 拠点の不一致・検査','',f'関連する拠点レコード {len(e["site_comparisons"])}件。通常変換の検査は passed。包含・重複・共有線・代表点・地表三角形を国単位で再検査した。']
        for s in e['site_comparisons']:
            if s['historical_comparison']=='conflict_requires_individual_review' or s.get('historical_lead_comparisons'):
                lines.append(f'- {s["display_name"]}：{s["historical_comparison"]}。登録座標を保持し、工程Eの個別判断を継承。')
        if pid=='izumi': lines+=['','元禄図の補正案はRMSE約1.75km、1点除外約6.15kmで保留。A案にも補正失敗のトレースは取り込まない。']
        lines+=['','## 採用に必要な判断','',
            '対象版、A/B案、国対応、年代差、各区画（未確定領域を含む）の扱いを国別採用台帳へ記録する。現在の原形状はheldのまま。採用時だけ、明示した版から採用済み派生版を作る。出典条件はCODH／人間文化研究機構、CC BY-NC 4.0（非商用）。']
        (base/f'{pid}.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
        rows.append(f'|{scope["display_name"]}|{len(d["regions"])}|{100*unresolved/area:.2f}%|[比較案・補正・検査](stage_g/{pid}.md)|')
    (ROOT/'docs/districts/STAGE_G_INDEX.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','regenerate','integrate','rollback','verify','report']);parser.add_argument('parent',nargs='?',default='all');parser.add_argument('--revision')
    args=parser.parse_args();initialize()
    if args.action=='regenerate':
        if args.parent=='all': raise ValueError('Regenerate requires one explicit parent')
        from build_district_stage_f import main as rebuild_display
        rebuild_display(args.parent);packet,_=prepare(args.parent);report();print('Regenerated only',args.parent,packet['revision'])
    elif args.action=='prepare':
        ids=[p['parent_region_id'] for p in read('data/editorial/districts/scope.json')['parents']] if args.parent=='all' else [args.parent]
        for pid in ids:
            packet,_=prepare(pid);print(pid,packet['revision'],flush=True)
        report()
    elif args.action=='integrate':
        safe_id(args.parent);decision=read(EDITOR/'decisions'/f'{args.parent}.json')
        package=PACKAGES/args.parent/str(decision['revision']);release=integrate(args.parent,decision,package)
        report();print('Accepted release',release['release_id'])
    elif args.action=='rollback':
        if not args.revision: raise ValueError('--revision accepted release ID or none is required')
        rollback(args.parent,args.revision);report();print('Rolled back only',args.parent)
    elif args.action=='verify': print(verify())
    else: report()

if __name__=='__main__': main()
