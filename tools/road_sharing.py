"""Conservative, deterministic corridor sharing in ground coordinates.

No averaging: reuse a contiguous part of an existing line. The caller validates
every lateral connection against land, water and elevation, including intermediate
cross sections (so opposite river banks cannot be mistaken for one road).
"""
import math
import numpy as np
from shapely.geometry import LineString


def dense(points, step=2.0):
    result = [list(points[0])]
    for a, b in zip(points, points[1:]):
        n = max(1, math.ceil(math.dist(a, b) / step))
        result.extend([[a[k] + (b[k]-a[k])*i/n for k in (0, 1)] for i in range(1, n+1)])
    return result


def clean(points):
    out = []
    for p in points:
        p = list(p)
        if not out or math.dist(out[-1], p) > 1e-8:
            out.append(p)
    return out


def share(points, target, safe_link, *, distance=6., minimum=16., angle=25., protected=()):
    """Return rewritten line and audit entries. Endpoints and protected points survive."""
    p, q = np.asarray(points, dtype=float), np.asarray(target, dtype=float)
    if len(p) < 3 or len(q) < 3:
        return points, []
    # A windowed tangent avoids interpreting each raster stair as a 45-degree turn.
    def tangents(v):
        return np.array([v[min(len(v)-1, i+2)]-v[max(0, i-2)] for i in range(len(v))])
    pt, qt = tangents(p), tangents(q)
    ds = ((p[:, None, :]-q[None, :, :])**2).sum(axis=2)
    nearest = ds.argmin(axis=1)
    denom = np.linalg.norm(pt, axis=1)*np.linalg.norm(qt[nearest], axis=1)
    cosine = np.divide((pt*qt[nearest]).sum(axis=1), denom, out=np.zeros(len(p)), where=denom>0)
    good = (ds[np.arange(len(p)), nearest] <= distance**2) & (abs(cosine) >= math.cos(math.radians(angle)))
    protected = {tuple(x) for x in protected}
    for i in range(len(p)):
        if tuple(p[i]) in protected or not safe_link(p[i], q[nearest[i]]):
            good[i] = False
    runs = []
    start = None
    for i in range(len(p)+1):
        compatible = i < len(p) and good[i]
        if compatible and start is not None:
            delta = int(nearest[i])-int(nearest[i-1])
            compatible = delta*cosine[start] >= 0 and math.dist(q[nearest[i]], q[nearest[i-1]]) <= distance*2+math.dist(p[i],p[i-1])
        if not compatible and start is not None:
            runs.append((start, i-1)); start = None
        if i < len(p) and good[i] and start is None:
            start = i
    result, audit, cursor = [], [], 0
    for a, b in runs:
        u, v = int(nearest[a]), int(nearest[b])
        shared = target[min(u,v):max(u,v)+1]
        if u > v: shared = shared[::-1]
        if a >= b or len(shared) < 2: continue
        length = LineString(shared).length
        original_length = LineString(points[a:b+1]).length
        if min(length, original_length) < minimum or length > original_length*1.35: continue
        if max(ds[i,nearest[i]] for i in range(a,b+1)) < 1e-12: continue
        replacement = clean(dense([points[a], shared[0]]) + list(shared) + dense([shared[-1], points[b]]))
        trial = clean(result + points[cursor:a] + replacement + points[b+1:])
        if not LineString(trial).is_simple: continue
        result.extend(points[cursor:a]); result.extend(replacement); cursor = b+1
        audit.append(dict(start=list(points[a]), end=list(points[b]), shared_length_px=length,
                          max_offset_px=float(max(ds[i,nearest[i]] for i in range(a,b+1))**.5)))
    return clean(result+points[cursor:]), audit


class GroundGuard:
    def __init__(self, terrain):
        self.terrain = terrain
        self.cache = {}

    def __call__(self, a, b):
        if math.dist(a, b) < 1e-8: return True
        key = tuple(sorted((tuple(a), tuple(b))))
        if key in self.cache: return self.cache[key]
        t = self.terrain
        line = LineString([a,b])
        ok = t.land.covers(line) and not t.lakes.intersects(line) and len(t.tree.query(line, predicate='intersects')) == 0
        if ok:
            pts = dense([a,b], t.step/2)
            ok = all(abs(t.height(x)-t.height(y))/(math.dist(x,y)/t.scale) <= t.config['grade_review'] for x,y in zip(pts,pts[1:]))
        self.cache[key] = bool(ok)
        return bool(ok)


def normalize_connections(routes, terrain, parameters):
    guard, accepted, audit = GroundGuard(terrain), [], []
    # Longer validated roads supply the shared trunk; IDs break ties reproducibly.
    for route in sorted(routes, key=lambda r: (-LineString(r.get('original_points',r['points'])).length,r['id'])):
        route.setdefault('original_points', route['points'])
        points = route['original_points']
        protected = [points[0],points[-1]]+[v['point'] for v in route.get('fixed_waypoint_mapping',[])]
        for target in accepted:
            if LineString(points).distance(LineString(target['points'])) > parameters['distance']: continue
            changed, events = share(points,target['points'],guard,protected=protected,**parameters)
            if events:
                path = [tuple(v/terrain.step for v in p) for p in changed]
                if any(terrain.edge(a,b) is None for a,b in zip(path,path[1:])): continue
                metrics = terrain.metrics(path)
                if metrics['max_grade'] > terrain.config['grade_review']: continue
                points = changed
                audit.extend(dict(route_id=route['id'],target_id=target['id'],**e) for e in events)
        route['points'] = points
        route['bounds'] = list(LineString(points).bounds)
        accepted.append(route)
    terrain.used.clear()
    for route in routes:
        path = [tuple(v/terrain.step for v in p) for p in route['points']]
        route['metrics'] = terrain.metrics(path)
        terrain.used.update(tuple(sorted([a,b])) for a,b in zip(path,path[1:]))
    return audit
