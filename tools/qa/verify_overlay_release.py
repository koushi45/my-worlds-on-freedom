"""Check exported overlay behavior and launch the ordinary Windows release."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'builds/performance_800'

def main():
    subprocess.run(['python','tools/qa/run_gpu_check.py',
                    'tests/base_map/godot/test_near_overlay_probe.gd',
                    'overlay_exported_test','--pack'],cwd=ROOT,check=True)
    command = [str(ROOT/'builds/windows-latest/MyWorldsOnFreedom.exe'),'--quit-after','120']
    result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,
                            encoding='utf-8',errors='replace',timeout=60)
    log = result.stdout + result.stderr
    (OUT/'overlay_normal_startup.log').write_text(log,encoding='utf-8')
    errors = [line for line in log.splitlines() if line.startswith(('ERROR:','SCRIPT ERROR:'))]
    report = {'command':command,'exit_code':result.returncode,'errors':errors}
    (OUT/'overlay_normal_startup.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    assert result.returncode==0 and not errors

if __name__=='__main__': main()
