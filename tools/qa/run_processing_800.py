"""Serial ablations against the same release pack. Never overlap GPU tests."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'builds/performance_800'
GROUPS = {
    'markers': ['baseline','no_crests','no_text','no_occlusion','no_markers','baseline_end'],
    'geometry': ['baseline','no_hex_lines','no_roads','freeze_near','no_near','no_shadows','no_3d','baseline_end'],
    'materials': ['baseline','no_detail_normal','no_detail_albedo','simple_surface','constant_surface','baseline_end'],
    'atlas': ['baseline','atlas_half','no_source_layers','freeze_atlas','baseline_end'],
    'confirm': ['baseline','no_markers','no_crests','simple_surface','no_3d','baseline_end'],
}

for name in sys.argv[1:] or list(GROUPS):
    label = 'processing800_'+name+'_r1'
    command = [sys.executable,'tools/qa/run_gpu_check.py','tests/base_map/godot/probe_processing_800.gd',label,'--pack','--variants='+','.join(GROUPS[name]),'--output='+str(OUT/(label+'.json'))]
    print('START',label,flush=True)
    subprocess.run(command,cwd=ROOT,check=True)
    data = json.loads((OUT/(label+'.json')).read_text(encoding='utf-8'))
    assert len(data['rows']) == len(GROUPS[name])*2
    assert 'PROCESSING_COMPLETE' in (OUT/(label+'.log')).read_text(encoding='utf-8')
    print('COMPLETE',label,flush=True)
