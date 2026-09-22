"""Build an exact, hole-preserving red overlay from the unresolved audit geometry."""
import json
from pathlib import Path
from shapely import constrained_delaunay_triangles
from shapely.geometry import Polygon
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[1]

def build():
    audit = json.loads((ROOT/'data/master/district_overlap_review.json').read_text(encoding='utf8'))
    normal = [p for p in audit['pairs'] if p['provisional_count'] == 0]
    shapes = [Polygon(p[0], p[1:]) for r in normal + audit['pending'] for p in r['polygons']]
    combined = unary_union(shapes)
    triangles = list(constrained_delaunay_triangles(combined).geoms)
    assert abs(sum(t.area for t in triangles)-combined.area) < 1e-5
    assert unary_union(triangles).symmetric_difference(combined).area < 1e-5
    output = {'normal_pairs': len(normal), 'pending_count': len(audit['pending']),
              'triangles': [list(t.exterior.coords)[:3] for t in triangles],
              'pending_points': [p['point'] for p in audit['pending']]}
    target = ROOT/'data/derived/scenarios/district_warning_overlay_1546.json'
    target.write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')), encoding='utf8')
    print(f'{len(normal)} overlaps + {len(audit["pending"])} fragments; {len(triangles)} triangles')

if __name__ == '__main__': build()
