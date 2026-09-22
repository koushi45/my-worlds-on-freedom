"""Package the verified Windows build with the adapted-data notices."""
import shutil
import json
import zipfile
from datetime import datetime, timezone
from pathlib import Path
import build_kyushu_registration as reg

ROOT=reg.ROOT
folder=ROOT/'builds/windows'
shutil.copyfile(ROOT/'data/derived/political/approved_western/political_registry.json', folder/'political_registry.json')
honshu_version=json.loads((ROOT/'data/master/political/honshu/status.json').read_text(encoding='utf-8'))['current_version']
shutil.copyfile(ROOT/f'data/master/political/honshu/{honshu_version}/name_review.json',folder/'name_review.json')
names=['name_review.json','MyWorldsOnFreedom.exe','MyWorldsOnFreedom.pck','README.txt',
       'ATTRIBUTION.md','LICENSE-CC-BY-SA-4.0.txt','political_registry.json']
for name in names:assert (folder/name).is_file(),name
master=ROOT/'data/master/political/kyushu/1.0.0/political_master_manifest.json'
approval=json.loads(master.read_text(encoding='utf-8'))
for path,sha in approval['canonical_hashes'].items():assert reg.digest(ROOT/path)==sha
for path,sha in approval['files'].items():assert reg.digest(master.parent/path)==sha
assert reg.digest(folder/'political_registry.json')==reg.digest(ROOT/'data/derived/political/approved_western/political_registry.json')
log=(ROOT/'builds/qa/windows_smoke.log').read_text(encoding='utf-8')
assert 'ERROR' not in log and 'SCRIPT ERROR' not in log
pack_log=(ROOT/'builds/qa/windows_pack.log').read_text(encoding='utf-8')
assert 'PASS: exported Windows pack' in pack_log and 'ERROR' not in pack_log
registry=json.loads((folder/'political_registry.json').read_text(encoding='utf-8'))
assert len(registry['regions'])==66 and 'chugoku' in registry['regional_bounds']
chugoku_master=ROOT/'data/master/political/chugoku/1.1.0/political_master_manifest.json'
chugoku_manifest=json.loads(chugoku_master.read_text(encoding='utf-8'))
for path,sha in chugoku_manifest['files'].items():assert reg.digest(chugoku_master.parent/path)==sha
for path,sha in chugoku_manifest['canonical_hashes'].items():assert reg.digest(ROOT/path)==sha
honshu_master=ROOT/f'data/master/political/honshu/{honshu_version}/political_master_manifest.json'
honshu_manifest=json.loads(honshu_master.read_text(encoding='utf-8'))
for p,h in honshu_manifest['files'].items():assert reg.digest(honshu_master.parent/p)==h
archive=ROOT/f'builds/MyWorldsOnFreedom-Windows-HonshuApproved-v{honshu_version}.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name in names:z.write(folder/name,arcname=f'MyWorldsOnFreedom/{name}')
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
report={'built_at_utc':datetime.now(timezone.utc).isoformat(),'platform':'Windows x86_64',
        'godot':'4.7.2.stable','political_version':f'Honshu {honshu_version}; Chugoku 1.1.0; Kyushu/Shikoku 1.0.0','scope':'66 approved regions; all names resolved',
        'approval_manifest_sha256':{'kyushu':reg.digest(master),'chugoku':reg.digest(chugoku_master),'honshu':reg.digest(honshu_master)},
        'checks':['master hashes unchanged','production click/5 LOD/culling test passed',
                  'exported PCK loading/tiles/selection/no-review-assets test passed',
                  '66 region frames and shared Chugoku intervals verified',
                  'Windows EXE smoke exit 0; error-free log','ZIP CRC passed'],
        'files':{name:{'bytes':(folder/name).stat().st_size,'sha256':reg.digest(folder/name)} for name in names},
        'zip':{'path':str(archive.relative_to(ROOT)),'bytes':archive.stat().st_size,'sha256':reg.digest(archive)}}
reg.save_json(ROOT/'builds/windows_build_report.json',report)
print(json.dumps(report['zip'],indent=2))
