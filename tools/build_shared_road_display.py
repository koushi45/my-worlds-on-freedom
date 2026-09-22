"""One ground-space stroke network for estimated connections."""
from collections import defaultdict
from shapely.geometry import LineString
from shapely.ops import unary_union, linemerge
from shapely.strtree import STRtree


def build_display(terrain=None):
    from build_road_connections import read, write, OUT, digest, lineparts
    data=read('data/derived/road_connections/connections_1582.json')
    records=[dict(points=s['points'],connection_ids=s['route_ids'],role=s['role']) for s in data['segments']]
    lines=[LineString(r['points']) for r in records]
    tree=STRtree(lines)
    groups=defaultdict(list)
    for piece in lineparts(unary_union(lines)):
        mid=piece.interpolate(.5,normalized=True)
        owners=[records[int(i)] for i in tree.query(mid.buffer(1e-7)) if lines[int(i)].distance(mid)<1e-7]
        c=tuple(sorted({i for r in owners for i in r['connection_ids']}))
        roles={r['role'] for r in owners}
        role='crossing' if 'crossing' in roles else ('trunk' if 'trunk' in roles else ('connector' if 'connector' in roles else 'site_access'))
        groups[c,role].append(piece)
    strokes=[]
    for (c,role),pieces in sorted(groups.items()):
        # Join degree-two subdivisions with identical membership. One dash phase
        # then runs along the entire chain, regardless of the originating route.
        for line in lineparts(linemerge(pieces)):
            strokes.append(dict(id=f'shared_{len(strokes):05}',points=list(map(list,line.coords)),bounds=list(line.bounds),connection_ids=c,role=role))
    inputs=['data/derived/road_connections/connections_1582.json','data/editorial/road_connections/sharing.json']
    write(OUT/'shared_display.json',dict(schema_version=2,strokes=strokes,input_hashes={p:digest(p) for p in inputs}))
    report=read('data/derived/road_connections/sharing_review.json')
    report.pop('historical',None)
    report.pop('shared_layer_strokes',None)
    report['stroke_count']=len(strokes)
    write(OUT/'sharing_review.json',report)
    print(f'Estimated connection display: {len(strokes)} strokes',flush=True)


if __name__=='__main__': build_display()
