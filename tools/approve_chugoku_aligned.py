"""Freeze the explicitly approved aligned Chugoku draft as version 1.1.0."""
import json
from datetime import datetime, timezone
import geopandas as gpd
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import substring, unary_union
from prepare_kinki_editor import ROOT, digest


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def run():
    source = ROOT/'data/work/political/chugoku_user_edits/aligned_draft.json'
    draft = json.loads(source.read_text(encoding='utf-8'))
    assert draft == json.loads((ROOT/'data/derived/editor/chugoku/editor_draft.json').read_text(encoding='utf-8'))
    target = ROOT/'data/master/political/chugoku/1.1.0'
    if target.exists():
        manifest = json.loads((target/'political_master_manifest.json').read_text(encoding='utf-8'))
        assert manifest['candidate_sha256'] == digest(source)
        for name, sha in manifest['files'].items(): assert digest(target/name)==sha
        return
    faces = {r['region_id']:Polygon(r['polygons'][0]) for r in draft['regions']}
    boundaries = []
    for b in draft['boundaries']:
        line = LineString(b['points'])
        owners = [key for key, face in faces.items() if line.difference(face.boundary.buffer(1e-5)).length < 1e-5]
        assert len(owners) in (1,2), (b['boundary_id'],owners)
        boundaries.append({**b,'region_a':owners[0],'region_b':owners[1] if len(owners)==2 else 'outside_chugoku',
                           'review_status':'accepted','certainty':'probable'})
    refs = []
    for coast_id, points in draft['coastlines'].items():
        coast = LineString(points)
        cuts = sorted({round(coast.project(Point(p)),8) for b in boundaries for p in (b['points'][0],b['points'][-1])
                       if coast.distance(Point(p))<1e-5})
        assert len(cuts)>1
        for i,start in enumerate(cuts):
            end = cuts[(i+1)%len(cuts)]
            wrap = end < start
            arc = unary_union([substring(coast,start,coast.length),substring(coast,0,end)]) if wrap else substring(coast,start,end)
            owners = [key for key, face in faces.items() if arc.difference(face.boundary.buffer(1e-5)).length<1e-4]
            assert len(owners)<=1
            if owners:
                refs.append({'arc_id':f'coast:{i:02d}','coastline_id':coast_id,'start_distance':start,
                             'end_distance':end,'wrap':wrap,'region_id':owners[0]})
    registry = {'status':'approved','version':'1.1.0','scope':'chugoku','license':'CC-BY-SA-4.0',
                'bounds':draft['bounds'],'coastlines':draft['coastlines'],'boundaries':boundaries,
                'coastline_references':refs,'regions':draft['regions']}
    # Bidirectional coverage: every province frame must equal its owned lines
    # and canonical coastal intervals, with no omitted pieces or extra spurs.
    for key, face in faces.items():
        lines = [LineString(b['points']) for b in boundaries if key in (b['region_a'],b['region_b'])]
        for ref in refs:
            if ref['region_id']!=key: continue
            coast=LineString(draft['coastlines'][ref['coastline_id']]);a=ref['start_distance'];b=ref['end_distance']
            lines.extend([substring(coast,a,coast.length),substring(coast,0,b)] if ref['wrap'] else [substring(coast,a,b)])
        drawn=unary_union(lines)
        assert face.boundary.difference(drawn.buffer(1e-5)).length<1e-4,key
        assert drawn.difference(face.boundary.buffer(1e-5)).length<1e-4,key
    target.mkdir(parents=True)
    save(target/'political_registry_master.json',registry)
    gpkg=target/'political_regions_master.gpkg'
    gpd.GeoDataFrame([{**{k:v for k,v in b.items() if k!='points'},'geometry':LineString(b['points'])} for b in boundaries]).to_file(gpkg,layer='shared_boundaries_8192',driver='GPKG')
    gpd.GeoDataFrame([{'region_id':key,'review_status':'accepted','geometry':face} for key,face in faces.items()]).to_file(gpkg,layer='political_regions_8192',driver='GPKG')
    report=json.loads((source.parent/'alignment_report.json').read_text(encoding='utf-8'))
    save(target/'approved_alignment_report.json',report)
    manifest={'status':'approved','version':'1.1.0','scope':'chugoku','candidate_sha256':digest(source),
        'approval':{'approved_by':'user','recorded_at_utc':datetime.now(timezone.utc).isoformat(),
                    'instruction':'中国地方はこれで確定・ビルドをお願いします。'},
        'canonical_hashes':{p:digest(ROOT/p) for p in ['data/base/japan_land.gpkg','data/derived/coastline/coastline_master.gpkg']},
        'files':{p.name:digest(p) for p in target.iterdir() if p.is_file()}}
    save(target/'political_master_manifest.json',manifest)
    save(target.parent/'status.json',{'scope':'chugoku','status':'approved','current_version':'1.1.0',
         'approval_manifest':'1.1.0/political_master_manifest.json','requires_explicit_reapproval':False})
    print('Approved Chugoku 1.1.0:',len(faces),'regions',len(boundaries),'boundaries',len(refs),'coast arcs')


if __name__=='__main__':run()
