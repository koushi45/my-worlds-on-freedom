"""Partition each polygon's interior into disjoint distance bands; never extrude outside."""
import json
import hashlib
from pathlib import Path
import numpy as np
import shapely
from shapely.geometry import Polygon

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'data/derived/scenarios/territory_fades'

def main():
    districts = json.loads((ROOT / 'data/derived/scenarios/independent_districts_1546.json').read_text(encoding='utf-8'))['regions']
    countries = json.loads((ROOT / 'data/derived/political/approved_western/political_registry.json').read_text(encoding='utf-8'))['regions']
    records = [('district:' + k, [Polygon(p[0], p[1:]) for p in r['polygons']]) for k, r in districts.items()]
    records += [('country:' + r['region_id'], [Polygon(p) for p in r['polygons']]) for r in countries]
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {}
    triangle_count = 0
    for key, polygons in records:
        output = bytearray()
        for polygon in polygons:
            polygon = shapely.make_valid(polygon)
            previous = polygon
            area = 0.0
            for depth in [0.5, 1, 2, 3, 4.5, 6, 9, 12, 18, 20]:
                inner = polygon.buffer(-depth, quad_segs=4)
                band = previous.difference(inner)
                triangles = shapely.get_parts(shapely.constrained_delaunay_triangles(band))
                if len(triangles):
                    # Audit the actual emitted triangles, not just their edge normals.
                    union = shapely.union_all(triangles)
                    assert union.difference(polygon).area < 1e-6, key
                    assert band.symmetric_difference(union).area < 1e-5, key
                    assert abs(sum(t.area for t in triangles) - band.area) < 1e-5, key
                    area += band.area
                    coords = np.array([list(t.exterior.coords)[:3] for t in triangles]).reshape(-1, 2)
                    distances = shapely.distance(shapely.points(coords), polygon.boundary)
                    data = np.column_stack((coords, distances)).astype('<f4')
                    output.extend(data.tobytes())
                    triangle_count += len(triangles)
                previous = inner
            expected = polygon.difference(polygon.buffer(-20, quad_segs=4)).area
            assert abs(area - expected) < 1e-5, key
        name = hashlib.sha256(key.encode()).hexdigest()[:24] + '.bin'
        (DEST / name).write_bytes(output)
        manifest[key] = 'res://data/derived/scenarios/territory_fades/' + name
    (DEST / 'index.json').write_text(json.dumps(manifest, separators=(',', ':')), encoding='utf-8')
    print(f'Validated {len(records)} regions; {triangle_count} non-overlapping interior triangles', flush=True)

if __name__ == '__main__':
    main()
