"""Freeze an explicitly approved candidate, then derive a production registry.

--approve is ONLY for an explicit user approval; ordinary reruns use the frozen
master, not mutable work files. Geometry and source certainty are preserved.
"""
import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
import sqlite3
import geopandas as gpd
import pyogrio
import build_kyushu_registration as reg
from verify_kyushu_registration import verify

ROOT=reg.ROOT
MASTER=ROOT/'data/master/political/kyushu/1.0.0'
RUNTIME=ROOT/'data/derived/political/approved_kyushu'

def publish(approve=False):
    manifest_path=MASTER/'political_master_manifest.json'
    if approve and not manifest_path.exists():
        verify()
        MASTER.mkdir(parents=True,exist_ok=True)
        frozen=MASTER/'political_regions_master.gpkg'
        if frozen.exists():raise RuntimeError('Incomplete previous publication; inspect master before retrying')
        source=reg.WORK/'kyushu_candidate.gpkg'
        for layer,_ in pyogrio.list_layers(source):
            frame=gpd.read_file(source,layer=layer)
            if 'review_status' in frame.columns:frame['review_status']='accepted'
            frame.to_file(frozen,layer=layer,driver='GPKG')
        reg.p2.normalize_gpkg(frozen)
        registry=json.loads((reg.WORK/'review_layer.json').read_text(encoding='utf-8'))
        registry.pop('raster',None)
        registry.update(status='approved',version='1.0.0',scope='kyushu_main_island',license='CC-BY-SA-4.0')
        for boundary in registry['boundaries']:boundary['review_status']='accepted'
        reg.save_json(MASTER/'political_registry_master.json',registry)
        report=json.loads((reg.WORK/'registration_report.json').read_text(encoding='utf-8'))
        reg.save_json(MASTER/'approved_registration_report.json',report)
        manifest={'schema_version':1,'version':'1.0.0','status':'approved',
                  'scope':'Kyushu main island, 9 provinces; offshore island ownership remains unconfirmed',
                  'approval':{'approved_by':'user','recorded_at_utc':datetime.now(timezone.utc).isoformat(),
                              'instruction':'問題ないので、本番マップに組み込み＆windowsビルドをお願いします。'},
                  'candidate_sha256':reg.digest(source),'candidate_spec_sha256':report['spec_sha256'],
                  'canonical_hashes':report['immutable_hashes_before'],
                  'files':{p.name:reg.digest(p) for p in [frozen,MASTER/'political_registry_master.json',MASTER/'approved_registration_report.json']}}
        reg.save_json(manifest_path,manifest)
    if not manifest_path.exists():raise RuntimeError('Explicit user approval required before publication')
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    for name,sha in manifest['files'].items():assert reg.digest(MASTER/name)==sha,name
    for name,sha in manifest['canonical_hashes'].items():assert reg.digest(ROOT/name)==sha,name
    RUNTIME.mkdir(parents=True,exist_ok=True)
    registry=json.loads((MASTER/'political_registry_master.json').read_text(encoding='utf-8'))
    reg.save_json(RUNTIME/'political_registry.json',registry)
    reg.save_json(RUNTIME/'approval.json',manifest)
    license_source=ROOT/'data/sources/political_reference/LICENSE-CC-BY-SA-4.0.txt'
    shutil.copyfile(license_source,RUNTIME/'LICENSE-CC-BY-SA-4.0.txt')
    print('Published approved Kyushu v1.0.0:',RUNTIME)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--approve',action='store_true')
    publish(parser.parse_args().approve)
