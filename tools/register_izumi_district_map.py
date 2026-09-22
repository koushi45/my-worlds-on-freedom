"""Reproducible low-order registration of the Genroku Izumi comparison map.

Points and sparse traces are editorial observations, not survey coordinates.
All source pixels refer to the unmodified IIIF response (1410 x 3000), not
the larger virtual canvas advertised by its manifest (8915 x 18971).
"""
import json
from pathlib import Path
from urllib.request import urlopen
from datetime import datetime, timezone
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from shapely.geometry import Polygon, MultiPoint
from shapely.ops import unary_union
from build_district_stage_c import ROOT, RAW, WORK, EDITOR, read, write, sha, transforms

SERVICE='https://www.digital.archives.go.jp/api/content/item/da12/C100189194000/iiif/010_izumi.jp2'
POINTS=[
    ('C1','大鳥大明神 → 大鳥大社',[330,680],[135.460861111,34.536777778],
     'https://kojiki.kokugakuin.ac.jp/jinjya/otoritaisha/','緯度/経度 北緯34°32′12.4″ 東経135°27′39.1″','大鳥大明神の社殿記号群の代表点'),
    ('C2','槇尾山 → 施福寺',[866,890],[135.5115409,34.392987],
     'https://mapfan.com/spots/SCC4I%2CJ%2CWT','世界測地系 Degree形式','槇尾山の寺院記号。山頂ではなく施福寺を候補とする。比定は暫定'),
    ('C3','岸和田城',[303,1290],[135.370786,34.458760],
     'local:settlements_1582','sites[id=kishiwada_castle].lonlat','城を示す白四角の中心。天守の測量点とは異なる'),
    ('C4','久米田寺',[502,1195],[135.411667,34.459461],
     'https://geoshape.ex.nii.ac.jp/nrct-poi/resource/28/280000454300.html','基本情報 緯度経度、ジャパンナレッジID280000454300','久米田池に接する寺院の記号群。池岸そのものは基準点にしない'),
    ('C5','水間寺',[721,1580],[135.385727,34.398853],
     'https://geoshape.ex.nii.ac.jp/nrct-poi/resource/28/280000460500.html','基本情報 緯度経度、ジャパンナレッジID280000460500','水間寺と読める寺院記号群。原図中の縮尺・位置の図式化を含む'),
]
TRACES=[
 ('genroku-otori-izumi',['G04001','G04002'],[[161,867],[229,878],[258,882],[290,875],[340,850],[357,825],[365,800],[390,791],[434,804],[475,829],[524,872],[572,904],[623,924],[679,934],[727,945],[755,950],[816,940],[867,927],[913,905],[946,880],[986,847]]),
 ('genroku-izumi-minami',['G04002','G04003'],[[190,1096],[230,1092],[256,1095],[286,1104],[331,1115],[392,1125],[437,1127],[497,1114],[556,1110],[603,1110],[640,1127],[680,1163],[720,1194],[777,1220],[814,1241],[841,1273],[875,1307],[907,1355],[938,1408],[971,1465],[996,1490],[1033,1545],[1080,1585]]),
 ('genroku-minami-hine',['G04003','G04004'],[[240,1422],[330,1434],[388,1430],[444,1435],[481,1452],[525,1488],[568,1524],[624,1554],[678,1592],[728,1620],[770,1645],[807,1654],[839,1656],[893,1650],[926,1656],[949,1664],[966,1683]]),
]

def main():
    out=WORK/'izumi'/'genroku';out.mkdir(parents=True,exist_ok=True)
    raw=RAW/'izumi';original=raw/'original.jpg'
    im=Image.open(original).convert('RGB');assert im.size==(1410,3000)
    metadata=[]
    for filename,suffix in [('original.jpg','/full/max/0/native.jpg'),('overview.jpg','/full/1400,/0/native.jpg'),
        ('north.jpg','/900,3000,5000,3600/2500,/0/native.jpg'),('central.jpg','/900,6500,5300,4200/2500,/0/native.jpg'),('south.jpg','/600,10800,4200,4500/2500,/0/native.jpg')]:
        p=raw/filename
        metadata.append(dict(file=p.relative_to(ROOT).as_posix(),sha256=sha(p),url=SERVICE+suffix,actual_size=Image.open(p).size,
            role='unmodified_server_response',retrieved_on='2026-09-12'))
    write(raw/'image_sources.json',dict(source_id='nai-genroku-izumi-image',title='元禄国絵図和泉国',
        reference_code='特083－0001-0010',archive_item='764247',image_identifier='C100189194000 / 010_izumi.jp2',
        manifest_file=(raw/'manifest.json').relative_to(ROOT).as_posix(),manifest_sha256=sha(raw/'manifest.json'),
        virtual_canvas=[8915,18971],server_max_dimension=3000,
        note='full/max response is 1410x3000. Never label it as a full-resolution 8915x18971 raster. Regional responses were inspected separately.',
        metadata_date='16960000',copy_date=None,temporal_basis='later_comparison',images=metadata,
        license_url='https://www.digital.archives.go.jp/secondary-use',
        reuse_basis='提供元の二次利用案内をwebで確認。デジタルコンテンツ・目録の複製・改変・再配布が可能。出典:国立公文書館。解説文章の条件とは区別。',
        export_allowed=False))
    references=[]
    for cid,name,pixel,lonlat,url,locator,note in POINTS:
        if url.startswith('https:'):
            dest=raw/'reference_pages'/f'{cid}.html';dest.parent.mkdir(exist_ok=True)
            try:
                if not dest.exists(): dest.write_bytes(urlopen(url,timeout=30).read())
                cache=dict(path=dest.relative_to(ROOT).as_posix(),sha256=sha(dest))
            except Exception as e: cache=dict(status='web_reviewed_local_cache_failed',error=str(e))
        else:
            path=ROOT/'data/derived/settlements/settlements_1582.json'
            actual=next(s for s in read(path)['sites'] if s['id']=='kishiwada_castle')
            assert actual['lonlat']==lonlat
            cache=dict(path=path.relative_to(ROOT).as_posix(),sha256=sha(path))
        references.append(dict(source_id='gcp-reference-'+cid,title=name,url=url,locator=locator,cache=cache,
            reuse='CC-BY-4.0; CODH POI doi:10.20676/00000456' if 'nrct-poi' in url else '個別利用条件未確認・調査用のみ',
            use='現代の位置を比較点として使用。歴史的建物の同位置を測量で証明したものではない。'))
    write(EDITOR/'registration_sources.json',dict(sources=references))
    m,xy,ll=transforms();scale=m['uniform_scale_px_per_m']
    p=np.array([r[2] for r in POINTS]);lonlat=np.array([r[3] for r in POINTS]);x,y=xy(lonlat[:,0],lonlat[:,1]);target=np.c_[x,y]
    design=np.c_[p,np.ones(len(p))];fit=np.linalg.lstsq(design,target,rcond=None)[0]
    predicted=design@fit;err=np.linalg.norm(predicted-target,axis=1)/scale
    loo=[]
    for i in range(len(p)):
        mask=np.arange(len(p))!=i
        f=np.linalg.lstsq(design[mask],target[mask],rcond=None)[0]
        loo.append(float(np.linalg.norm(design[i]@f-target[i])/scale))
    rmse=float(np.sqrt(np.mean(err**2)));loo_rmse=float(np.sqrt(np.mean(np.array(loo)**2)))
    controls=[]
    for i,row in enumerate(POINTS):
        cid,name,pixel,lonlat,url,locator,note=row
        controls.append(dict(control_id=cid,label=name,source_pixel=pixel,source_image_sha256=sha(original),
            source_locator=dict(image_identifier='010_izumi.jp2',pixel_system='1410x3000 unmodified response',label=note),
            target_lonlat=lonlat,target_world=target[i].tolist(),reference_source_ref='gcp-reference-'+cid,
            identity_status='manual_tentative_landmark_match',pixel_pick_half_width_px=12,
            pixel_pick_note='記号の中心読み取りの作業上の幅。歴史的位置精度ではない。',
            residual_vector_world=(predicted[i]-target[i]).tolist(),residual_m=float(err[i]),leave_one_out_m=loo[i],
            role='fit_and_leave_one_out_check'))
    registration=dict(schema_version=1,source_image=original.relative_to(ROOT).as_posix(),
        source_size=list(im.size),controls=controls,model='global_affine_least_squares',matrix_pixel_row_to_world=fit.tolist(),
        fit_rmse_m=rmse,leave_one_out_rmse_m=loo_rmse,fit_max_residual_m=float(max(err)),
        control_hull_world=mapping_hull(target),
        independent_holdout_count=0,leave_one_out_is_not_independent_validation=True,
        gate=dict(fit_rmse_limit_m=500,loo_rmse_limit_m=1000,limit_basis='比較案の実用性を判定する暫定作業閾値。史料の精度規格ではない。'),
        status='held_registration_accuracy_insufficient' if rmse>500 or loo_rmse>1000 else 'provisional_review',
        fit_constraints='No coastline/river constraints, no spline/rubber-sheet warping. Do not force source geography to modern geography.',
        extrapolation_note='対応点は北部〜中央に偏る。点群外、特に日根郡南部への外挿は未検証。',
        rejected_control_leads=[dict(label='信太明神',reason='信太森神社と聖神社の比定を混同するおそれがあるため今回の基準点から除外。海岸・河口も変遷未確認のため不採用。')])
    write(EDITOR/'izumi_registration.json',registration)
    traced=[]
    singular=np.linalg.svd(fit[:2],compute_uv=False)
    for bid,owners,points in TRACES:
        world=(np.c_[np.asarray(points),np.ones(len(points))]@fit).tolist()
        traced.append(dict(boundary_id=bid,owners=['district-candidate-'+x.lower() for x in owners],source_pixels=points,points=world,
            source_ref='nai-genroku-izumi-image',source_locator='010_izumi.jp2 / 黒い郡境線と青・桃・黄・薄桃の村名色区分',
            registration_ref='data/editorial/districts/stage_c/izumi_registration.json',
            status='held; alternative comparison to kg network, never auto-merged',
            uncertainty=dict(visible_stroke_width_px_range=[2,5],manual_trace_half_width_px=4,
                tracing_half_width_world_range=(4*np.sort(singular)).tolist(),registration_rmse_m=rmse,
                combined_display_half_width_world=rmse*scale+4*float(max(singular)),
                historical_boundary_half_width_m=None,confidence_probability=None,
                note='帯は読取幅と位置合わせ残差を示す。統計的信頼区間でも1582年の郡境精度でもない。'),
            trace_method='手動で主要な曲がりだけを読取。線幅内の細部・400%用の屈曲は追加しない。',
            endpoint_status='source_coast_or_province_edge_tentative; not snapped to current parent'))
    write(out/'shared_trace_network.json',dict(boundaries=traced,
        districts=[dict(candidate_id='district-candidate-'+gid.lower(),boundary_refs=[b['boundary_id'] for b in traced if 'district-candidate-'+gid.lower() in b['owners']],
                        outer_boundary_status='untraced; no artificial closure in stage C') for gid in ['G04001','G04002','G04003','G04004']],
        closed_polygons=None,temporal_basis='Genroku comparison; not 1582',source_and_registration_inputs_preserved=True))
    annotated=im.copy();draw=ImageDraw.Draw(annotated)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
    for row in controls:
        x,y=row['source_pixel'];draw.ellipse((x-10,y-10,x+10,y+10),outline='#e72020',width=4)
        draw.text((x+14,y-22),row['control_id'],font=font,fill='#111111',stroke_width=2,stroke_fill='white')
    for b in traced: draw.line([tuple(p) for p in b['source_pixels']],fill='#ef2a64',width=3)
    annotated.save(out/'source_annotations.png')
    invfit=np.linalg.inv(fit[:2])
    def warp(bounds,width,height):
        xmin,ymin,xmax,ymax=bounds;k=min(width/(xmax-xmin),height/(ymax-ymin))
        width=int(np.ceil((xmax-xmin)*k));height=int(np.ceil((ymax-ymin)*k))
        offset=(np.array([xmin,ymin])-fit[2])@invfit
        coeff=(invfit[0,0]/k,invfit[1,0]/k,offset[0],invfit[0,1]/k,invfit[1,1]/k,offset[1])
        result=im.convert('RGBA').transform((width,height),Image.Transform.AFFINE,coeff,Image.Resampling.BICUBIC,fillcolor=(0,0,0,0))
        return result,k
    corners=np.array([[0,0,1],[1410,0,1],[1410,3000,1],[0,3000,1]])@fit
    bounds=[*corners.min(axis=0),*corners.max(axis=0)]
    corrected,k=warp(bounds,1800,2400);corrected.save(out/'registered.png')
    write(out/'registered_image.json',dict(bounds_world=[float(v) for v in bounds],pixel_size_world=1/k,
        image_size=corrected.size,georeferencing='existing 8192 game coordinates; y down',
        pixel_center_origin=[bounds[0]+0.5/k,bounds[1]+0.5/k],registration_status=registration['status']))
    (out/'registered.pgw').write_text('\n'.join(map(str,[1/k,0,0,1/k,bounds[0]+0.5/k,bounds[1]+0.5/k]))+'\n',encoding='ascii')
    parent=next(r for r in read('data/derived/political/approved_western/political_registry.json')['regions'] if r['region_id']=='izumi')
    poly=unary_union([Polygon(p) for p in parent['polygons']]);xmin,ymin,xmax,ymax=poly.bounds
    bounds=[xmin-15,ymin-15,xmax+15,ymax+15];layer,k=warp(bounds,1400,1700)
    background=Image.new('RGBA',layer.size,'#f1f4f4');layer.putalpha(layer.getchannel('A').point(lambda a:int(a*.5)));background.alpha_composite(layer)
    def screen(points):return [((p[0]-bounds[0])*k,(p[1]-bounds[1])*k) for p in points]
    bands=Image.new('RGBA',layer.size);bd=ImageDraw.Draw(bands)
    for b in traced: bd.line(screen(b['points']),fill=(240,30,70,35),width=max(2,int(2*b['uncertainty']['combined_display_half_width_world']*k)))
    background.alpha_composite(bands);dd=ImageDraw.Draw(background)
    for polygon in parent['polygons']:dd.line(screen(polygon+[polygon[0]]),fill='#111111',width=3)
    for b in read(WORK/'izumi'/'network.json')['boundaries']:
        if len(b['owners'])==2:dd.line(screen(b['points']),fill='#087e89',width=3)
    for b in traced:dd.line(screen(b['points']),fill='#d02c63',width=3)
    for i,row in enumerate(controls):
        actual=screen([row['target_world']])[0];pred=screen([predicted[i]])[0]
        dd.line([actual,pred],fill='#bb3f00',width=2)
        x,y=actual;dd.ellipse((x-5,y-5,x+5,y+5),fill='#04874c');dd.text((x+7,y),row['control_id'],fill='black',font=font)
        x,y=pred;dd.line([(x-6,y-6),(x+6,y+6)],fill='#d02c63',width=2);dd.line([(x-6,y+6),(x+6,y-6)],fill='#d02c63',width=2)
    dd.rectangle((0,0,background.width,100),fill='white')
    small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    for y,text in [(8,'IZUMI | registration comparison (held)'),(34,f'Affine RMSE {rmse:.0f} m / leave-one-out {loo_rmse:.0f} m'),(60,'Black: current parent | Teal: later vector | Pink: Genroku trace + uncertainty')]:
        dd.text((14,y),text,font=small,fill='#172b37')
    background.convert('RGB').save(out/'comparison.png')
    print(json.dumps(dict(fit_rmse_m=rmse,loo_rmse_m=loo_rmse,status=registration['status']),ensure_ascii=False))

def mapping_hull(target):
    return list(MultiPoint(target).convex_hull.exterior.coords)

if __name__=='__main__':main()
