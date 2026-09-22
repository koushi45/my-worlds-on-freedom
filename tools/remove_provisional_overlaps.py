"""Subtract all overlaps from provisional districts; report unranked normal pairs."""
import copy
import hashlib
import json
from pathlib import Path
from collections import Counter
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def parts(g):
    if g.geom_type=='Polygon': return [] if g.is_empty else [g]
    return [p for c in getattr(g,'geoms',[]) for p in parts(c)]
def pack(g): return [[list(p.exterior.coords)]+[list(h.coords) for h in p.interiors] for p in parts(g)]
EPS=1e-8 # Area tolerance for floating point residues, ~0.0005 m² in this projection.

def clean(data):
    meta={r['key']:r for r in read('data/derived/districts/unconfirmed/index.json')['regions']}
    extra=data['connectivity']['extra_districts']
    for k,r in extra.items():meta[k]=dict(meta[r['source_id']],name=r['name'],key=k)
    original={k:unary_union([Polygon(p[0],p[1:]) for p in r['polygons']]) for k,r in data['regions'].items()}
    keys=sorted(original);geoms=[original[k] for k in keys];tree=STRtree(geoms)
    provisional={k for k in keys if '（仮' in meta[k]['name'] or '(仮' in meta[k]['name']}
    scale=read('data/derived/land_masks/land_master_8192.json')['transform']['uniform_scale_px_per_m']
    factor=1/scale**2/1e6
    pairs=[];contacts={k:[] for k in keys}
    for i,a in enumerate(geoms):
        for jj in tree.query(a):
            j=int(jj)
            if j<=i:continue
            overlap=a.intersection(geoms[j])
            if overlap.area<=EPS:continue
            akey,bkey=keys[i],keys[j]
            contacts[akey].append(bkey);contacts[bkey].append(akey)
            n=int(akey in provisional)+int(bkey in provisional)
            pairs.append({'a':akey,'b':bkey,'a_name':meta[akey]['parent_name']+'・'+meta[akey]['name'],
               'b_name':meta[bkey]['parent_name']+'・'+meta[bkey]['name'],'area_km2':overlap.area*factor,
               'world_area':overlap.area,'provisional_count':n,'point':list(overlap.representative_point().coords)[0],
               'polygons':pack(overlap)})
    changed=[];remaining={};loose=[];pending=[];transfers=[]
    for key in keys:
        g=original[key]
        if key not in provisional:
            remaining[key]=g;continue
        cut=g.difference(unary_union([original[o] for o in contacts[key]])) if contacts[key] else g
        ps=sorted(parts(cut),key=lambda p:(-p.area,p.wkb_hex))
        changed.append({'id':key,'name':meta[key]['parent_name']+'・'+meta[key]['name'],
            'removed_km2':(g.area-cut.area)*factor,'before_area':g.area,'remaining_area':cut.area,
            'cut_parts':len(ps),'overlapped_ids':contacts[key]})
        if ps:
            if not ps[0].interiors:remaining[key]=ps[0]
            else:loose.append((key,ps[0]))
            loose.extend((key,p) for p in ps[1:])
    # Retain the prior connectivity rule: give residual fragments only to touching
    # recipients whose union is a single exterior; never bridge a gap or fill a hole.
    while loose:
        rkeys=sorted(remaining);rtree=STRtree([remaining[k] for k in rkeys]);rest=[];progress=0
        for source,p in loose:
            candidates=[rkeys[int(i)] for i in rtree.query(p)]
            candidates.sort(key=lambda k:(-remaining[k].boundary.intersection(p.boundary).length,k in provisional,k))
            target=None
            for k in candidates:
                if remaining[k].distance(p)>1e-9:continue
                ps=parts(remaining[k].union(p))
                if len(ps)==1 and not ps[0].interiors and ps[0].is_valid:
                    target=k;remaining[k]=ps[0];break
            if target is None:rest.append((source,p))
            else:
                transfers.append({'source':source,'target':target,'area_km2':p.area*factor})
                progress+=1
        loose=rest
        if not progress:break
    for key,p in loose:
        pending.append({'source':key,'name':meta[key]['parent_name']+'・'+meta[key]['name'],
            'reason':'削除後の分断・内周を解消する隣接統合先を一意に構成できないため保留',
            'area_km2':p.area*factor,'polygons':pack(p),'point':list(p.representative_point().coords)[0]})
    # Keep the previous overlap-cleaned layout for save migration. Retire only
    # near-total clipping remnants narrower than the source simplification
    # tolerance, not genuinely small islands or normal districts.
    overlap_layout_ids=sorted(remaining)
    retired_remnants=[]
    for k,g in list(remaining.items()):
        if k in provisional and g.area < original[k].area * .001 and g.buffer(-.15).is_empty:
            retired_remnants.append({'id':k,'name':meta[k]['parent_name']+'・'+meta[k]['name'],
                'area_km2':g.area*factor,'remaining_ratio':g.area/original[k].area,'polygons':pack(g)})
            del remaining[k]
    # No removed overlap may be filled back by connectivity repair.
    out={}
    for k,g in remaining.items():
        assert g.is_valid and g.geom_type=='Polygon' and not g.interiors
        r=copy.deepcopy(data['regions'][k]);r['polygons']=pack(g);r['bounds']=list(g.bounds);r['label']=list(g.representative_point().coords)[0]
        out[k]=r
    active=sorted(out);rtree=STRtree([remaining[k] for k in active]);after=[]
    for i,k in enumerate(active):
        for jj in rtree.query(remaining[k]):
            j=int(jj)
            if j<=i:continue
            area=remaining[k].intersection(remaining[active[j]]).area
            if area>EPS:
                assert k not in provisional and active[j] not in provisional,(k,active[j],area)
                after.append((k,active[j],area))
    # Normal-normal disputed land remains unchanged. Added fragments were outside
    # every original district, so they cannot create a new normal-normal overlap.
    before_normal={(p['a'],p['b']):p['world_area'] for p in pairs if p['provisional_count']==0}
    for a,b,area in after:assert abs(area-before_normal[(a,b)])<1e-5
    topology=data['connectivity']
    topology['previous_layout_ids']=keys
    topology['overlap_layout_ids']=overlap_layout_ids
    topology['active_district_ids']=active
    topology['retired_district_ids']=sorted(set(keys)-set(active))
    topology['extra_districts']={k:v for k,v in extra.items() if k in out}
    sites=read('data/derived/governance/governance_1546.json')['sites']
    topology['site_district_candidates']={id:sorted(active[int(i)] for i in rtree.query(Point(s['point'])) if remaining[active[int(i)]].covers(Point(s['point']))) for id,s in sites.items()}
    data['regions']=out
    counts=Counter(p['provisional_count'] for p in pairs)
    audit={'stats':{'before_districts':len(keys),'after_districts':len(out),'removed_districts':len(topology['retired_district_ids']),
      'normal_overlap_pairs':counts[0],'normal_overlap_pairs_over_001km2':sum(p['provisional_count']==0 and p['area_km2']>=.01 for p in pairs),
      'mixed_overlap_pairs':counts[1],'provisional_overlap_pairs':counts[2],
      'provisional_overlap_pairs_after':0,'pending_fragments':len(pending),'pending_area_km2':sum(p['area_km2'] for p in pending)},
      'area_note':'既存の投影・世界座標スケールからの概算km²。ペア面積は三重重複を含むため合算不可。',
      'retired_remnants':retired_remnants,
      'changes':changed,'transfers':transfers,'pending':pending,'pairs':sorted(pairs,key=lambda p:-p['area_km2']),
      'names':{k:meta[k]['parent_name']+'・'+meta[k]['name'] for k in keys}}
    data['overlap_cleanup']=audit['stats']
    dest=ROOT/'data/master/district_overlap_review.json';dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(audit,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    report(audit,original)
    from build_district_warning_overlay import build as build_warning_overlay
    build_warning_overlay()
    print(audit['stats'])
    return data

def report(audit,geoms):
    from html import escape
    dest=ROOT/'docs/districts/overlaps';dest.mkdir(parents=True,exist_ok=True)
    retired=['# 実体を失った仮称郡の削除','','重複除去後の残存面積が元の0.1%未満で、既存の形状簡略化精度0.15世界座標単位の内側に実体が残らない区画を削除。面積の小ささだけでは削除せず、小島を維持しています。','','|削除した区画|残片の概算 km²|','|---|---:|']
    for r in audit['retired_remnants']:retired.append(f"|{r['name']}|{r['area_km2']:.8f}|")
    (dest/'RETIRED_DISTRICTS.md').write_text('\n'.join(retired)+'\n',encoding='utf8')
    normal=[p for p in audit['pairs'] if p['provisional_count']==0]
    lines=['# 通常郡同士の重複：判断待ち','','面積は概算。通常郡同士は勝手に削除せず残しています。共有する線だけの接触は除外。','',
      '|郡A|郡B|重複面積 km²|ゲーム座標（重複内の一点）|','|---|---|---:|---|']
    for p in normal:lines.append(f"|{p['a_name']}|{p['b_name']}|{p['area_km2']:.6f}|{p['point'][0]:.2f}, {p['point'][1]:.2f}|")
    (dest/'NORMAL_OVERLAPS.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
    lines=['# 分断後の統合先が未確定の領域','',f"現在の保留は{len(audit['pending'])}片です。解消済みの形状と処理内容は data/master/district_overlap_review.json の pending_before_resolution / resolution.pending_actions に保存しています。",'','|元の郡|概算 km²|ゲーム座標|','|---|---:|---|']
    for p in audit['pending']:lines.append(f"|{p['name']}|{p['area_km2']:.8f}|{p['point'][0]:.3f}, {p['point'][1]:.3f}|")
    (dest/'PENDING_FRAGMENTS.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
    js=json.dumps({'pairs':normal,'shapes':{k:pack(g) for k,g in geoms.items() if any(k in (p['a'],p['b']) for p in normal)}},ensure_ascii=False).replace('</','<\\/')
    html='''<!doctype html><html lang="ja"><meta charset="utf-8"><title>郡の重複・判断待ち</title><style>body{font:16px system-ui;background:#152c35;color:#eee7cf;margin:24px}input,select{padding:10px;margin:5px;font:inherit;max-width:95%}svg{width:100%;height:55vh;background:#f0ebdc}button{padding:8px}p{line-height:1.7}</style><h1>通常郡同士の重複・判断待ち</h1><p>郡A：青、郡B：黄、重複：赤。面積は概算です。通常郡同士の領域は判断待ちとして維持しています。</p><input id="q" placeholder="国・郡名で検索"><label><input type="checkbox" id="major" checked>0.01 km²以上</label><select id="list"></select><p id="info"></p><svg id="map" role="img" aria-label="選択した二つの郡と重複範囲"></svg><script>const D='''+js+''';const q=document.querySelector('#q'),list=document.querySelector('#list'),map=document.querySelector('#map'),major=document.querySelector('#major');function path(ps){return ps.map(p=>p.map(r=>'M'+r.map(x=>x.join(',')).join('L')+'Z').join('')).join('')}function show(){const p=D.pairs[+list.value];if(!p){map.innerHTML='';return}const shapes=[D.shapes[p.a],D.shapes[p.b]],pts=shapes.flat(2);let xs=pts.map(p=>p[0]),ys=pts.map(p=>p[1]);let x=Math.min(...xs),y=Math.min(...ys),w=Math.max(...xs)-x,h=Math.max(...ys)-y;map.setAttribute('viewBox',[x-10,y-10,w+20,h+20].join(' '));map.innerHTML=shapes.map((s,i)=>'<path d="'+path(s)+'" fill="'+(i?'#dba53555':'#298dcc55')+'" stroke="'+(i?'#9f6b00':'#086d9d')+'" stroke-width="1.5" vector-effect="non-scaling-stroke" fill-rule="evenodd"/>').join('')+'<path d="'+path(p.polygons)+'" fill="#ef3b3b" fill-rule="evenodd"/>';document.querySelector('#info').textContent=p.a_name+' × '+p.b_name+'　約 '+p.area_km2.toFixed(6)+' km²　ゲーム座標 '+p.point.map(x=>x.toFixed(2)).join(', ')}function filter(){list.innerHTML='';D.pairs.forEach((p,i)=>{if((!major.checked||p.area_km2>=.01)&&(p.a_name+p.b_name).includes(q.value)){let o=document.createElement('option');o.value=i;o.textContent=p.a_name+' × '+p.b_name+' ('+p.area_km2.toFixed(4)+' km²)';list.append(o)}});show()}q.oninput=filter;major.onchange=filter;list.onchange=show;filter();</script></html>'''
    (dest/'review.html').write_text(html,encoding='utf8')

if __name__=='__main__':
    from build_independent_districts import build
    build()
