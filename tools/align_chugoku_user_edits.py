"""Node user-edited lines and derive matching draft province outlines."""
import argparse
import hashlib
import json
from pathlib import Path

from shapely import set_precision
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import linemerge, nearest_points, polygonize_full, substring, unary_union

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data/work/political/chugoku_user_edits'
TOLERANCE = 3.0
GRID = 1e-6


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def parts(geometry, kind='LineString'):
    if geometry.geom_type == kind:
        return [geometry] if not geometry.is_empty else []
    return [part for child in getattr(geometry, 'geoms', []) for part in parts(child, kind)]


def build(source):
    data = read(source)
    seed = read(ROOT / 'data/derived/editor/chugoku/editor_draft.json')
    master = read(ROOT / 'data/master/political/chugoku/1.0.0/political_registry_master.json')
    assert data['schema'] == 'my-worlds-chugoku-border-edits' and data['scope'] == 'chugoku'
    assert data['coordinate_system'] == seed['coordinate_system']
    original_hash = hashlib.sha256((ROOT / 'data/master/political/chugoku/1.0.0/political_registry_master.json').read_bytes()).hexdigest()
    assert data['source_draft_sha256'] in (seed['source_draft_sha256'], original_hash)
    for path, digest in data['reference_hashes'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
    lines = [list(LineString(b['points']).coords) for b in data['boundaries']]
    assert all(len(line) >= 2 for line in lines)
    count = len(lines)
    coast_ids = list(master['coastlines'])
    lines += [list(LineString(master['coastlines'][key]).coords) for key in coast_ids]
    adjustments = []
    # Move only editable endpoints. Insert the same point in the target line,
    # including a working copy of the canonical coast, for exact graph noding.
    for i in range(count):
        for end in (0, -1):
            p = Point(lines[i][end])
            distance, target = min((LineString(line).distance(p), j) for j, line in enumerate(lines) if j != i)
            if distance > TOLERANCE:
                raise ValueError(f'Unresolved endpoint: {i}, {end}, distance={distance}')
            target_line = lines[target]
            q = nearest_points(p, LineString(target_line))[1]
            # Float32 exports can differ from retained double endpoints.
            endpoint = min((target_line[0], target_line[-1]), key=lambda xy: Point(xy).distance(p))
            if target < count and Point(endpoint).distance(p) < 0.003:
                q = Point(endpoint)
            xy = q.coords[0]
            segment = min(range(len(target_line)-1), key=lambda k: LineString(target_line[k:k+2]).distance(q))
            if xy not in (target_line[segment], target_line[segment+1]):
                target_line.insert(segment+1, xy)
            lines[i][end] = xy
            if p.distance(q) > 1e-9:
                adjustments.append({'boundary_id': data['boundaries'][i]['boundary_id'], 'end': end,
                    'from': list(p.coords[0]), 'to': list(xy), 'distance_game_px': p.distance(q)})
    graph = unary_union([set_precision(LineString(line), GRID) for line in lines])
    faces, cuts, dangles, invalid = polygonize_full(graph)
    print('Graph:', len(faces.geoms), 'faces; cuts', cuts.length, 'dangles', dangles.length, flush=True)
    face_list = list(faces.geoms)
    slivers = []
    # Float32 editing over retained double coordinates can create a microscopic
    # duplicate-edge sliver. Merge only sub-0.001 px² faces along a shared edge.
    for tiny in [face for face in face_list if face.area < 0.001]:
        neighbors = [(tiny.boundary.intersection(face.boundary).length, i)
                     for i, face in enumerate(face_list) if face != tiny]
        shared_length, index = max(neighbors)
        assert shared_length > 0
        slivers.append({'area_game_px2': tiny.area, 'bounds': list(tiny.bounds)})
        face_list[index] = face_list[index].union(tiny)
        face_list.remove(tiny)
    regions = []
    used = set()
    for old in master['regions']:
        original = unary_union([Polygon(ring) for ring in old['polygons']])
        anchor = original.representative_point()
        matches = [(i, face) for i, face in enumerate(face_list) if face.covers(anchor)]
        if len(matches) != 1 or matches[0][0] in used:
            raise ValueError('No unique edited region: ' + old['region_id'])
        index, face = matches[0]
        assert face.is_valid and face.geom_type == 'Polygon' and not face.interiors
        used.add(index)
        regions.append({'region_id': old['region_id'], 'name_ja': old['name_ja'],
            'geometry': face, 'polygons': [list(face.exterior.coords)]})
    OUT.mkdir(parents=True, exist_ok=True)
    save(OUT / 'diagnostics.json', {'adjustments': adjustments, 'cuts': cuts.length,
        'dangles': dangles.length, 'invalid': invalid.length,
        'merged_numerical_slivers': slivers,
        'unassigned_face_areas': [f.area for i, f in enumerate(face_list) if i not in used]})
    assert invalid.is_empty
    # Only polygonized edges define the region outlines. Report tiny leftover
    # tails rather than allowing them to masquerade as a country boundary.
    borders = unary_union([r['geometry'].boundary for r in regions])
    edited = unary_union([set_precision(LineString(line), GRID) for line in lines[:count]])
    leftover = edited.difference(borders.buffer(0.0001))
    print('Unused edited lengths:', leftover.length, flush=True)
    if leftover.length > 5:
        raise ValueError('Review unused edited lines before finalizing draft')
    coast = unary_union([LineString(master['coastlines'][k]) for k in coast_ids])
    runs = []
    for line in parts(borders):
        for a, b in zip(line.coords, list(line.coords)[1:]):
            segment = LineString([a, b])
            if coast.distance(segment.interpolate(.5, normalized=True)) > 0.0001:
                runs.append(segment)
    merged = parts(linemerge(unary_union(runs)))
    output = {**seed, 'status': 'editor_draft_only', 'boundaries': [
        {'boundary_id': f'chugoku:aligned:{i:03d}', 'points': list(line.coords),
         'review_status': 'pending_polygonization', 'trace_method': 'user_edits_aligned'}
        for i, line in enumerate(merged)],
        'regions': [{k: v for k, v in r.items() if k != 'geometry'} for r in regions],
        'source_draft_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
    save(OUT / 'aligned_draft.json', output)
    (OUT / 'input_edits.json').write_bytes(source.read_bytes())
    report = {'status': 'aligned_draft_not_approved', 'input_sha256': output['source_draft_sha256'],
        'input_lines': count, 'aligned_lines': len(merged), 'regions': len(regions),
        'endpoint_adjustments': adjustments, 'max_endpoint_adjustment_game_px': max(a['distance_game_px'] for a in adjustments),
        'merged_numerical_slivers': slivers,
        'unused_tail_length_game_px': leftover.length}
    save(OUT / 'alignment_report.json', report)
    print('Saved:', OUT)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    build(parser.parse_args().source)
