"""Summarize per-process CPU, resident RAM and WDDM GPU counters by action."""
import json
import math
import os
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'builds/performance_800'
GIB = 1024**3

def stats(values):
    assert values
    return {'average':statistics.mean(values),'min':min(values),'max':max(values),'samples':len(values)}

def summarize(limit):
    label = f'resources_800_{limit}fps'
    process = json.loads((OUT/(label+'_process.json')).read_text(encoding='utf-8'))
    assert process['exit_code']==0 and not process['errors'] and not process['timed_out']
    benchmark = json.loads((OUT/(label+'.json')).read_text(encoding='utf-8'))
    assert len(benchmark['results'])==9
    gpu = json.loads((OUT/(label+'_gpu.json')).read_text(encoding='utf-8-sig'))
    cpu_rows = []
    samples = process['samples']
    # Use differences only when both endpoints belong to the same action.
    for before,after in zip(samples,samples[1:]):
        if before['phase']!=after['phase']: continue
        wall = after['wall_seconds']-before['wall_seconds']
        used = after['cpu_seconds']-before['cpu_seconds']
        if wall<=0 or used<0: continue
        cpu_rows.append({'phase':after['phase'],'wall':wall,'cpu':used,
                         'cpu_percent':100*used/wall/os.cpu_count(),
                         'working_gib':after['working_bytes']/GIB,
                         'private_gib':after['private_bytes']/GIB})
    gpu_rows = []
    previous_phase = None
    stable_samples = 0
    for row in gpu:
        if row['Phase']!=previous_phase:
            previous_phase=row['Phase'];stable_samples=0
        stable_samples+=1
        # Counters are sampled by Windows over an earlier interval; omit the
        # first two readings per phase and queries crossing a phase boundary.
        if stable_samples<=2 or row['Phase']!=row['PhaseAfter']: continue
        engines = row['Engines'] or []
        if isinstance(engines,dict): engines=[engines]
        memory = row['Memory'] or []
        if isinstance(memory,dict): memory=[memory]
        graphics = [e['UtilizationPercentage'] for e in engines if 'engtype_3D' in e['Name']]
        if not graphics or not memory: continue
        gpu_rows.append({'phase':row['Phase'],'gpu_3d_percent':max(graphics),
                         'dedicated_gib':sum(m['DedicatedUsage'] for m in memory)/GIB,
                         'shared_gib':sum(m['SharedUsage'] for m in memory)/GIB})
    result = {'pid':process['pid'],'fps_limit':limit,'logical_processors':os.cpu_count(),
              'viewport':benchmark['viewport'],'modes':{},'locations':{}}
    for mode in ('pan','orbit'):
        cpu = [r for r in cpu_rows if r['phase'].endswith(' '+mode)]
        gpu_mode = [r for r in gpu_rows if r['phase'].endswith(' '+mode)]
        measured = [r for r in benchmark['results'] if r['mode']==mode]
        cpu_percent = 100*sum(r['cpu'] for r in cpu)/sum(r['wall'] for r in cpu)/os.cpu_count()
        result['modes'][mode] = {
            'cpu_percent_average':cpu_percent,
            'cpu_percent_peak_100ms':max(r['cpu_percent'] for r in cpu),
            'resident_ram_gib':stats([r['working_gib'] for r in cpu]),
            'private_commit_gib':stats([r['private_gib'] for r in cpu]),
            'gpu_3d_percent':stats([r['gpu_3d_percent'] for r in gpu_mode]),
            'dedicated_vram_gib':stats([r['dedicated_gib'] for r in gpu_mode]),
            'shared_gpu_ram_gib':stats([r['shared_gib'] for r in gpu_mode]),
            'fps':sum(r['frames'] for r in measured)/sum(r['frames']/r['fps'] for r in measured),
            'seconds_sampled':sum(r['wall'] for r in cpu)
        }
        for location in ('kinki','fuji','kanto'):
            phase = location+' '+mode
            loc_cpu = [r for r in cpu if r['phase']==phase]
            loc_gpu = [r for r in gpu_mode if r['phase']==phase]
            result['locations'][phase] = {
                'cpu_percent':100*sum(r['cpu'] for r in loc_cpu)/sum(r['wall'] for r in loc_cpu)/os.cpu_count(),
                'gpu_3d_percent':statistics.mean(r['gpu_3d_percent'] for r in loc_gpu) if loc_gpu else None,
                'gpu_samples':len(loc_gpu)
            }
    return result

def main():
    reports = [summarize(limit) for limit in (60,0)]
    (OUT/'game_resources_summary.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf-8')
    for report in reports:
        print('FPS LIMIT',report['fps_limit'])
        for mode,row in report['modes'].items():
            print(mode,json.dumps(row))

if __name__=='__main__': main()
