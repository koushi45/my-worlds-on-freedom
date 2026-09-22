"""Freeze explicitly approved regional candidates and combine approved registries."""
import argparse
import json
import shutil
from datetime import datetime, timezone
import geopandas as gpd
import pyogrio
import build_chugoku_shikoku_registration as reg
from verify_chugoku_shikoku_registration import verify

ROOT=reg.ROOT
RUNTIME=ROOT/'data/derived/political/approved_western'

def read(path):return json.loads(path.read_text(encoding='utf-8'))

def publish(approve=False):
    registries={'kyushu':read(ROOT/'data/derived/political/approved_kyushu/political_registry.json')}
    approvals={}
    versions={'shikoku':'1.0.0'}
    current=read(ROOT/'data/master/political/chugoku/status.json')
    if current['status']=='approved': versions['chugoku']=current['current_version']
    honshu_status=ROOT/'data/master/political/honshu/status.json'
    if honshu_status.exists() and read(honshu_status)['status']=='approved': versions['honshu']=read(honshu_status)['current_version']
    for name,version in versions.items():
        master=ROOT/f'data/master/political/{name}/{version}'
        manifest_path=master/'political_master_manifest.json'
        if approve and not manifest_path.exists():
            verify(name)
            master.mkdir(parents=True,exist_ok=True)
            frozen=master/'political_regions_master.gpkg'
            if frozen.exists():raise RuntimeError('Incomplete publication: '+str(master))
            work=reg.WORK/name
            for layer,_ in pyogrio.list_layers(work/'political_candidate.gpkg'):
                frame=gpd.read_file(work/'political_candidate.gpkg',layer=layer)
                if 'review_status' in frame:frame['review_status']='accepted'
                frame.to_file(frozen,layer=layer,driver='GPKG')
            reg.core.p2.normalize_gpkg(frozen)
            data=read(work/'review_layer.json');data.pop('raster',None)
            data.update(status='approved',version='1.0.0',license='CC-BY-SA-4.0')
            for b in data['boundaries']:b['review_status']='accepted'
            reg.core.save_json(master/'political_registry_master.json',data)
            shutil.copyfile(work/'registration_report.json',master/'approved_registration_report.json')
            report=read(work/'registration_report.json')
            manifest={'status':'approved','version':'1.0.0','scope':name,
                'approval':{'approved_by':'user','recorded_at_utc':datetime.now(timezone.utc).isoformat(),
                            'instruction':'画像の桃色線と水色線を確認しましたが、問題ありませんでしたので本番反映をお願いします。'},
                'limitations':['Mainland provinces only; offshore ownership unresolved. Historical certainty remains probable.'],
                'candidate_sha256':reg.core.digest(work/'political_candidate.gpkg'),
                'canonical_hashes':report['immutable_before'],
                'files':{p.name:reg.core.digest(p) for p in [frozen,master/'political_registry_master.json',master/'approved_registration_report.json']}}
            reg.core.save_json(manifest_path,manifest)
        if not manifest_path.exists():raise RuntimeError('Explicit approval required: '+name)
        manifest=read(manifest_path)
        for p,h in manifest['files'].items():assert reg.core.digest(master/p)==h,p
        for p,h in manifest['canonical_hashes'].items():assert reg.core.digest(ROOT/p)==h,p
        registries[name]=read(master/'political_registry_master.json');approvals[name]=manifest
    combined={'status':'approved','version':'1.0.0','scope':'approved_western_mainlands','coastlines':{},'boundaries':[],
              'coastline_references':[],'boundary_references':[],'regions':[],'regional_bounds':{},'license':'CC-BY-SA-4.0'}
    for name,data in registries.items():
        assert data['status']=='approved'
        combined['regional_bounds'][name]=data['bounds']
        for id,points in data['coastlines'].items():
            if id in combined['coastlines']:assert combined['coastlines'][id]==points
            combined['coastlines'][id]=points
        combined['boundaries'].extend(data['boundaries'])
        combined['regions'].extend(data['regions'])
        combined['boundary_references'].extend(data.get('boundary_references',[]))
        for ref in data['coastline_references']:combined['coastline_references'].append({**ref,'arc_id':name+':'+ref['arc_id']})
    for key,id in [('regions','region_id'),('boundaries','boundary_id'),('coastline_references','arc_id')]:
        assert len({r[id] for r in combined[key]})==len(combined[key]),key
    assert len(combined['regions'])==(66 if 'honshu' in registries else 24 if 'chugoku' in registries else 13)
    bounds=list(combined['regional_bounds'].values())
    combined['bounds']=[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)]
    RUNTIME.mkdir(parents=True,exist_ok=True)
    reg.core.save_json(RUNTIME/'political_registry.json',combined)
    reg.core.save_json(RUNTIME/'approval.json',{'status':'approved','regions':approvals,'kyushu_manifest_sha256':reg.core.digest(ROOT/'data/master/political/kyushu/1.0.0/political_master_manifest.json')})
    shutil.copyfile(ROOT/'data/sources/political_reference/LICENSE-CC-BY-SA-4.0.txt',RUNTIME/'LICENSE-CC-BY-SA-4.0.txt')
    print('Published',len(combined['regions']),'approved provinces:',RUNTIME)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--approve',action='store_true')
    publish(parser.parse_args().approve)
