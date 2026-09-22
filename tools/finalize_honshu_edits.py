"""Clean explicitly approved Honshu edits and build their planar regions."""
import json
from pathlib import Path
import numpy as np
import shapely
from shapely.geometry import LineString,Point,Polygon
from shapely.ops import unary_union,nearest_points,polygonize_full,linemerge,substring
from prepare_kinki_editor import ROOT,digest

OUT=ROOT/'data/work/political/honshu_final'
SOURCE=Path('C:/Users/nanoa/Documents/honshu_border_edits.json')

def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def parts(g):
    if g.geom_type=='LineString':return [g] if not g.is_empty else []
    return [p for x in getattr(g,'geoms',[]) for p in parts(x)]

def run():
    d=read(SOURCE);seed=read(ROOT/'data/derived/editor/honshu/editor_draft.json')
    locked=read(ROOT/'data/derived/political/approved_western/political_registry.json')
    assert d['scope']=='honshu' and d['source_draft_sha256']==seed['source_draft_sha256']
    for p,h in d['reference_hashes'].items():assert digest(ROOT/p)==h,p
    outlines=[];removed=0
    for b in d['boundaries']:
        coords=[]
        for p in b['points']:
            if not coords or Point(coords[-1]).distance(Point(p))>.001:coords.append(p)
            else:removed+=1
        assert len(coords)>=2
        outlines.append(list(LineString(coords).coords))
    count=len(outlines)
    shared=[b for b in locked['boundaries'] if b['boundary_id'] in {r['boundary_id'] for r in d['shared_boundary_references']}]
    outlines += [list(LineString(b['points']).coords) for b in shared]
    outlines += [list(LineString(p).coords) for p in seed['coastlines'].values()]
    changes=[]
    for i in range(count):
        for end in [0,-1]:
            p=Point(outlines[i][end])
            distance,target=min((LineString(l).distance(p),j) for j,l in enumerate(outlines) if i!=j)
            assert distance<1,(i,end,distance)
            line=outlines[target];q=nearest_points(p,LineString(line))[1]
            if target<count:
                endpoint=min([line[0],line[-1]],key=lambda xy:Point(xy).distance(p))
                if Point(endpoint).distance(p)<.003:q=Point(endpoint)
            xy=q.coords[0]
            segment=min(range(len(line)-1),key=lambda j:LineString(line[j:j+2]).distance(q))
            if xy not in [line[segment],line[segment+1]]:line.insert(segment+1,xy)
            outlines[i][end]=xy
            if p.distance(q)>1e-8:changes.append({'line':i,'end':end,'from':list(p.coords[0]),'to':list(xy),'distance':p.distance(q)})
    network=unary_union([shapely.set_precision(LineString(l),1e-5) for l in outlines])
    faces,cuts,dangles,invalid=polygonize_full(network)
    protected=unary_union([Polygon(p) for r in locked['regions'] for p in r['polygons']])
    mainland=Polygon(next(iter(seed['coastlines'].values())))
    polygons=[f for f in faces.geoms if f.intersection(protected).area<f.area*.01 and f.area>.01 and mainland.covers(f.representative_point())]
    polygons.sort(key=lambda f:(f.centroid.y,f.centroid.x))
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'input_edits.json').write_bytes(SOURCE.read_bytes())
    save(OUT/'faces.json',{'faces':[{'index':i,'area':f.area,'center':list(f.representative_point().coords[0]),'polygons':[list(f.exterior.coords)],'holes':[list(r.coords) for r in f.interiors]} for i,f in enumerate(polygons)]})
    save(OUT/'clean_lines.json',{'lines':outlines[:count]})
    save(OUT/'cleanup_report.json',{'input_sha256':digest(SOURCE),'merged_consecutive_points':removed,'endpoint_changes':changes,
          'max_endpoint_move':max(c['distance'] for c in changes),'face_count':len(polygons),
          'all_face_areas':sorted(f.area for f in faces.geoms),'cut_length':cuts.length,'dangle_length':dangles.length,'invalid_length':invalid.length})
    print('Faces',len(polygons),'all',len(faces.geoms),'cuts',cuts.length,'dangles',dangles.length,'maxmove',max(c['distance'] for c in changes),flush=True)

if __name__=='__main__':run()
