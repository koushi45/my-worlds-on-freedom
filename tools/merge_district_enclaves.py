"""Transfer detached parts to nearest touching districts; islands get their own IDs."""
import copy
import hashlib
import json
from pathlib import Path
from collections import Counter
from shapely.geometry import Polygon, LineString, Point
from shapely.ops import unary_union, nearest_points
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf8'))
def polygon_parts(g):
    if g.geom_type=='Polygon': return [g]
    return [p for c in getattr(g,'geoms',[]) for p in polygon_parts(c)]
def single(g):
    assert g.geom_type=='Polygon' and g.is_valid
    return Polygon(g.exterior) # Administrative outline includes interior lakes / tiny holes.

def merge(data):
    metadata={r['key']:r for r in read('data/derived/districts/unconfirmed/index.json')['regions']}
    original=data['regions'];keys=sorted(original);cores={};pending=[];operations=[];extras={}
    for key in keys:
        pieces=sorted([Polygon(p[0],p[1:]) for p in original[key]['polygons']],key=lambda p:(-p.area,p.wkb_hex))
        cores[key]=single(pieces[0])
        pending.extend((key,i,single(p)) for i,p in enumerate(pieces[1:],1))
    land=read('data/derived/land_masks/land_master_8192.json')
    islands=[Polygon(land['coastlines'][part['exterior_coastline_id']]['points'])
             for feature in land['land_features'] for part in feature['parts']]
    island_tree=STRtree(islands)
    def land_id(g):
        matches=island_tree.query(g)
        best=max(((islands[int(i)].intersection(g).area,int(i)) for i in matches),default=(0,-1))
        return best[1] if best[0]>0 else -1
    def combine(a,b,gap):
        union=a.union(b)
        polygons=polygon_parts(union)
        if len(polygons)==1: return single(polygons[0]),0.0
        # Only sub-pixel comparison-coordinate seams may be joined here.
        if gap>0.3: return None,0.0
        a_id=land_id(a);b_id=land_id(b)
        if a_id<0 or a_id!=b_id: return None,0.0
        p,q=nearest_points(a,b)
        bridge=LineString([p,q]).buffer(.02 if gap==0 else .05)
        union=unary_union([a,b,bridge])
        polygons=polygon_parts(union)
        if len(polygons)!=1: return None,0.0
        return single(polygons[0]),bridge.difference(a.union(b)).area
    # Dynamic recipients are rebuilt after each pass so adjacent detached pieces
    # may join through pieces already transferred, without ever crossing a sea gap.
    while pending:
        ordered=sorted(cores);tree=STRtree([cores[k] for k in ordered]);remaining=[];progress=0
        for source,part,piece in pending:
            candidates=[ordered[int(i)] for i in tree.query(piece.buffer(.3))]
            candidates.sort(key=lambda k:(cores[k].distance(piece),-cores[k].intersection(piece).area,-cores[k].boundary.intersection(piece.boundary).length,k))
            target=None
            for candidate in candidates:
                gap=cores[candidate].distance(piece)
                joined,added=combine(cores[candidate],piece,gap)
                if joined is not None:
                    target=candidate;cores[target]=joined
                    operations.append({'source':source,'part':part,'target':target,'kind':'merge','distance':gap,'seam_area':added,'area':piece.area})
                    progress+=1;break
            if target is None: remaining.append((source,part,piece))
        pending=remaining
        if not progress: break
    # Each remaining physically separated component becomes a separate provisional
    # district. Later components touching that island are merged into that district.
    island_counts=Counter()
    while pending:
        source,part,piece=pending.pop(0)
        group=[(source,part,piece)];changed=True
        while changed:
            changed=False;rest=[]
            for origin,number,other in pending:
                gap=piece.distance(other)
                if gap<=.3:
                    joined,added=combine(piece,other,gap)
                    if joined is not None:
                        piece=joined;group.append((origin,number,other));changed=True;continue
                rest.append((origin,number,other))
            pending=rest
        candidates=sorted((k for k,g in cores.items() if g.distance(piece)<=.3),key=lambda k:(cores[k].distance(piece),-cores[k].intersection(piece).area,k))
        target=None
        for candidate in candidates:
            joined,added=combine(cores[candidate],piece,cores[candidate].distance(piece))
            if joined is not None:
                cores[candidate]=joined;target=candidate;break
        if target is not None:
            for origin,number,p in group:
                operations.append({'source':origin,'part':number,'target':target,'kind':'merge','distance':0,'area':p.area})
            continue
        digest=hashlib.sha256(json.dumps([(a,b) for a,b,_ in group]).encode()).hexdigest()[:12]
        key=source.split('/')[0]+'/island-'+digest
        island_counts[source]+=1
        name=metadata[source]['name'].replace('（仮）','')+'・島部%d郡（仮）'%island_counts[source]
        cores[key]=single(piece)
        extras[key]={'source_id':source,'name':name,'land_component':land_id(piece)}
        for origin,number,p in group:
            operations.append({'source':origin,'part':number,'target':key,'kind':'island','area':p.area})
    output={}
    for key,g in sorted(cores.items()):
        source=extras[key]['source_id'] if key in extras else key
        r=copy.deepcopy(original[source]);r['polygons']=[[list(g.exterior.coords)]]
        r['bounds']=list(g.bounds);r['label']=list(g.representative_point().coords)[0]
        output[key]=r
    data['regions']=output
    data['connectivity']={'version':1,'policy':'飛び地を近隣の郡へ移管。離島は別郡。全郡は内周なしの単一Polygon。',
       'original_ids':keys,'extra_districts':extras,'operations':operations,
       'stats':{'before':len(original),'after':len(output),'multipart_before':sum(len(r['polygons'])>1 for r in original.values()),
                'detached_parts':len(operations),'merged_parts':sum(o['kind']=='merge' for o in operations),
                'island_districts':len(extras),'multipart_after':0}}
    ordered=sorted(cores);tree=STRtree([cores[k] for k in ordered])
    sites=read('data/derived/governance/governance_1546.json')['sites']
    data['connectivity']['site_district_candidates']={id:sorted(ordered[int(i)] for i in tree.query(Point(s['point'])) if cores[ordered[int(i)]].covers(Point(s['point']))) for id,s in sites.items()}
    data['connectivity']['sources']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in [
        'data/derived/land_masks/land_master_8192.json','data/derived/districts/unconfirmed/index.json']}
    # Audit every detached component against its final receiver; no fragment is dropped.
    for op in operations:
        pieces=sorted([Polygon(p[0],p[1:]) for p in original[op['source']]['polygons']],key=lambda p:(-p.area,p.wkb_hex))
        op['uncovered_area']=pieces[op['part']].difference(cores[op['target']]).area
    assert sum(o['uncovered_area'] for o in operations)<1e-5
    return data

if __name__=='__main__':
    # Regenerate original independent shapes before merging, never merge twice.
    from build_independent_districts import build
    build()
