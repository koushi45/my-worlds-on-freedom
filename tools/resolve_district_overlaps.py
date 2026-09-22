"""Apply user priorities and deterministic cleanup of microscopic intersections."""
import copy
import json
from pathlib import Path
from shapely.geometry import Polygon, Point, LineString
from shapely.ops import unary_union, nearest_points
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[1]
EPS=1e-8
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))
def parts(g):
    if g.geom_type=='Polygon':return [] if g.is_empty else [g]
    return [p for c in getattr(g,'geoms',[]) for p in parts(c)]
def pack(g):return [[list(p.exterior.coords)]+[list(h.coords) for h in p.interiors] for p in parts(g)]

def resolve(data):
    audit=read('data/master/district_overlap_review.json')
    names=audit['names']
    factor=1/read('data/derived/land_masks/land_master_8192.json')['transform']['uniform_scale_px_per_m']**2/1e6
    geoms={k:Polygon(r['polygons'][0][0]) for k,r in data['regions'].items()}
    initial=copy.copy(geoms)
    operations=[]; discarded=[]; reassigned=[]
    def tiny(g):return g.area*factor<=.01 or (g.area*factor<=.1 and g.buffer(-.15).is_empty)
    def cut(key,mask,reason,max_detached_km2=0,detached_targets=()):
        result=geoms[key].difference(mask)
        # Tiny interior intersections need a subpixel slit to the exterior to
        # keep a single outline, rather than filling the removed overlap back in.
        for _ in range(100):
            holed=next((p for p in parts(result) if p.interiors),None)
            if holed is None:break
            a,b=nearest_points(holed.interiors[0],holed.exterior)
            slit=LineString([a,b]).buffer(.00001)
            if slit.area*factor>.01:return False
            result=result.difference(slit)
        ps=sorted(parts(result),key=lambda p:-p.area)
        if not ps or ps[0].interiors:
            return False
        target_backups={}; reassigned_len=len(reassigned); discarded_len=len(discarded)
        for p in ps[1:]:
            if tiny(p) or p.area*factor<=max_detached_km2:
                discarded.append({'source':key,'area_km2':p.area*factor,'polygons':pack(p)})
                continue
            candidates=sorted(set(detached_targets),key=lambda k:(-geoms[k].boundary.intersection(p.boundary).length,geoms[k].distance(p),k))
            accepted=False
            for target in candidates:
                if geoms[target].distance(p)>1e-7:continue
                proposal=geoms[target].union(p)
                filled_holes_km2=0
                if proposal.geom_type=='Polygon' and proposal.interiors:
                    holes=[Polygon(h) for h in proposal.interiors]
                    if all(h.area*factor<=.1 for h in holes):
                        filled_holes_km2=sum(h.area*factor for h in holes)
                        proposal=Polygon(proposal.exterior)
                valid=True
                for _ in range(100):
                    holed=next((q for q in parts(proposal) if q.interiors),None)
                    if holed is None:break
                    a,b=nearest_points(holed.interiors[0],holed.exterior)
                    slit=LineString([a,b]).buffer(.00001)
                    if slit.area*factor>.01:valid=False;break
                    proposal=proposal.difference(slit)
                proposal_parts=parts(proposal)
                if not valid or len(proposal_parts)!=1 or proposal_parts[0].interiors:continue
                proposal=proposal_parts[0]
                target_backups.setdefault(target,geoms[target]);geoms[target]=proposal
                reassigned.append({'source':key,'target':target,'reason':reason,'area_km2':p.area*factor,'filled_holes_km2':filled_holes_km2,'polygons':pack(p)})
                accepted=True;break
            if not accepted:
                for target,backup in target_backups.items():geoms[target]=backup
                del reassigned[reassigned_len:]
                del discarded[discarded_len:]
                return False
        removed=geoms[key].area-ps[0].area
        geoms[key]=ps[0]
        if removed>EPS:operations.append({'loser':key,'reason':reason,'area_km2':removed*factor})
        return True
    decisions=read('data/master/district_overlap_decisions.json')['priorities']
    def key_for(name,explicit=None):
        if explicit is not None:
            assert explicit in geoms and names[explicit].split('・')[-1]==name
            return explicit
        matches=[k for k in geoms if names[k].split('・')[-1]==name]
        assert len(matches)==1,(name,matches)
        return matches[0]
    resolved=[]
    masks={}
    for d in decisions:
        loser,winner=key_for(d['loser'],d.get('loser_id')),key_for(d['winner'],d.get('winner_id'))
        area=geoms[loser].intersection(geoms[winner]).area*factor
        masks.setdefault(loser,[]).append(winner)
        resolved.append(dict(d,loser_id=loser,winner_id=winner,area_km2=area))
    # Apply all winners for one losing district together. Sequential clipping
    # can strand land that a later priority already assigns to another winner.
    for loser,targets in masks.items():
        assert cut(loser,unary_union([geoms[k] for k in targets]),'指定優先: '+', '.join(names[p['winner_id']] for p in resolved if p['loser_id']==loser),.1,targets),loser
    # The red circles marked unassigned fragments, not overlapping districts.
    # Remove microscopic remnants; join the substantial ones to a touching
    # district, filling only tiny seam holes and trimming those seams elsewhere.
    pending_actions=[]
    for p in audit['pending']:
        g=unary_union([Polygon(q[0],q[1:]) for q in p['polygons']])
        if tiny(g):
            pending_actions.append(dict(p,action='微細残片を削除'));continue
        candidates=sorted(geoms,key=lambda k:(geoms[k].distance(g),-geoms[k].boundary.intersection(g.boundary).length,k))
        accepted=False
        for k in candidates[:12]:
            if geoms[k].distance(g)>1e-7:continue
            union=geoms[k].union(g)
            if union.geom_type!='Polygon':continue
            holes=[Polygon(h) for h in union.interiors]
            if any(h.area*factor>.1 for h in holes):continue
            proposal=Polygon(union.exterior)
            added=proposal.difference(geoms[k])
            impacted=[j for j in geoms if j!=k and geoms[j].intersection(added).area>EPS]
            # Do not turn a small seam repair into a decision on a large dispute.
            if any(geoms[j].intersection(added).area*factor>.1 for j in impacted):continue
            backup=copy.copy(geoms); op_len=len(operations); drop_len=len(discarded)
            if not all(cut(j,added,'未確定片の接続境界整理') for j in impacted):
                geoms.clear();geoms.update(backup);del operations[op_len:];del discarded[drop_len:];continue
            geoms[k]=proposal
            pending_actions.append(dict(p,action='隣接郡へ統合',target=k));accepted=True;break
        assert accepted,('pending fragment not resolved',p['name'],p['area_km2'])
    # Explicit priorities have already been applied. Other microscopic overlaps
    # use stable ID ordering, trying the other side when connectivity requires it.
    keys=sorted(geoms);tree=STRtree([geoms[k] for k in keys])
    pairs=sorted({(keys[i],keys[int(j)]) for i,k in enumerate(keys) for j in tree.query(geoms[k]) if int(j)>i})
    for _ in range(20):
        changed=False
        for a,b in pairs:
            small=[p for p in parts(geoms[a].intersection(geoms[b])) if p.area>EPS and tiny(p)]
            if not small:continue
            mask=unary_union(small)
            assert cut(b,mask,'微細重複の自動整理') or cut(a,mask,'微細重複の自動整理'),(a,b)
            changed=True
        if not changed:break
    after=[];tree=STRtree([geoms[k] for k in keys])
    for i,a in enumerate(keys):
        for jj in tree.query(geoms[a]):
            j=int(jj)
            if j<=i:continue
            b=keys[j];overlap=geoms[a].intersection(geoms[b])
            if overlap.area<=EPS:continue
            assert not any(tiny(p) for p in parts(overlap) if p.area>EPS),(a,b)
            after.append({'a':a,'b':b,'a_name':names[a],'b_name':names[b],
                'area_km2':overlap.area*factor,'world_area':overlap.area,'provisional_count':0,
                'point':list(overlap.representative_point().coords)[0],'polygons':pack(overlap)})
    for d in resolved:assert geoms[d['loser_id']].intersection(geoms[d['winner_id']]).area<=EPS
    for k,g in geoms.items():
        assert g.is_valid and g.geom_type=='Polygon' and not g.interiors,k
        data['regions'][k].update(polygons=pack(g),bounds=list(g.bounds),label=list(g.representative_point().coords)[0])
    sites=read('data/derived/governance/governance_1546.json')['sites']
    data['connectivity']['site_district_candidates']={id:sorted(keys[int(i)] for i in tree.query(Point(s['point'])) if geoms[keys[int(i)]].covers(Point(s['point']))) for id,s in sites.items()}
    audit['before_resolution_pairs']=audit['pairs'];audit['pending_before_resolution']=audit['pending']
    audit['pairs']=sorted(after,key=lambda p:-p['area_km2']);audit['pending']=[]
    audit['resolution']={'priorities':resolved,'operations':operations,'discarded_fragments':discarded,'reassigned_fragments':reassigned,'pending_actions':pending_actions}
    audit['stats'].update(normal_overlap_pairs=len(after),normal_overlap_pairs_over_001km2=sum(p['area_km2']>=.01 for p in after),pending_fragments=0,pending_area_km2=0)
    data['overlap_cleanup']=audit['stats']
    (ROOT/'data/master/district_overlap_review.json').write_text(json.dumps(audit,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    from remove_provisional_overlaps import report
    report(audit,geoms)
    from build_district_warning_overlay import build
    build()
    lines=['# 指定優先・微細重複の整理','','「南岩手川」は南岩手郡、「西〇井」は西磐井郡として処理。「丸森・豆理」は丸森側の伊具郡・亘理郡と解釈しました。郡全体の合併ではなく、重複部分の優先指定です。','','|削る郡|残す郡|処理前の重複 km²|','|---|---|---:|']
    for p in resolved:lines.append(f"|{p['loser']}|{p['winner']}|{p['area_km2']:.6f}|")
    lines += ['', '微細判定は、交差部分ごとに0.01 km²以下、または0.1 km²以下かつ幅が形状簡略化精度程度（0.15世界座標単位の内側に実体なし）のもの。面積は概算です。飛び地となる微細残片は削除します。指定優先によって生じる孤立片に限り0.1 km²以下を削除対象とし、それより大きな分離片は境界を共有する優先側へ移管します。通常の自動整理基準は変更していません。内周ができる場合は目視できない幅の切れ目を外周へ通して外周1本を維持しています。', '',f"通常郡の重複は{len(after)}組が判断待ちとして残り、赤塗りを継続しています。指定以外の大きな重複に優先順位は付けていません。",'',f'指定優先で生じた0.1 km²超の分離片は{len(reassigned)}片を優先側へ移管しました。']
    if reassigned:
        lines += ['', '|分離元|移管先|概算 km²|継ぎ目穴の補完 km²|','|---|---|---:|---:|']
        for p in reassigned:lines.append(f"|{names[p['source']]}|{names[p['target']]}|{p['area_km2']:.8f}|{p['filled_holes_km2']:.8f}|")
    lines += ['', '赤丸で示していた14片の処理：','','|元の郡|処理|概算 km²|','|---|---|---:|']
    for p in pending_actions:lines.append(f"|{p['name']}|{names[p['target']]+'へ統合' if 'target' in p else p['action']}|{p['area_km2']:.8f}|")
    lines+=['',f'全{len(geoms)}郡の有効な単一外周、指定{len(resolved)}組の非重複、微細重複の解消、赤塗りデータとの一致を検証しています。']
    (ROOT/'docs/districts/overlaps/RESOLVED_PRIORITIES.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
    print('Resolved:',len(resolved),'priorities;',len(operations),'cuts;',len(pending_actions),'pending fragments;',len(after),'remaining overlap pairs')
    return data
