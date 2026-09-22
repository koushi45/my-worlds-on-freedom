"""Audit all intersections in the estimated connection graph."""
import json
from collections import Counter
from pathlib import Path
from shapely.geometry import LineString, Point
from shapely.strtree import STRtree

ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def main():
    d=read('data/derived/road_connections/connections_1582.json')
    # Every intersection within the new network must resolve to a graph node,
    # except coincident geometry which is already represented by one segment.
    anchors={a['id']:a for a in d['anchors']}
    segments=d['segments']; lines=[LineString(s['points']) for s in segments]; newtree=STRtree(lines)
    unresolved=[]
    for i,line in enumerate(lines):
        for j in newtree.query(line,predicate='intersects'):
            j=int(j)
            if j<=i: continue
            hit=line.intersection(lines[j])
            if hit.is_empty: continue
            common={segments[i]['from_anchor'],segments[i]['to_anchor']} & {segments[j]['from_anchor'],segments[j]['to_anchor']}
            if hit.geom_type=='Point' and any(Point(anchors[a]['point']).distance(hit)<1e-5 for a in common): continue
            # Tiny numerical overlap at rounded endpoints has no separate crossing.
            if common and hit.length<1e-5: continue
            unresolved.append(dict(a=segments[i]['id'],b=segments[j]['id'],geometry=hit.geom_type))
    report=dict(
                unresolved_new_network_intersections=unresolved,
                role_counts=dict(Counter(s['role'] for s in segments)))
    (ROOT/'data/derived/road_connections/topology_review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Unresolved connection intersections: {len(unresolved)}')
    assert not unresolved, unresolved[:5]

if __name__=='__main__': main()
