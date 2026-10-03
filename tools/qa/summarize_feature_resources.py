"""Summarize PID-specific Windows counters; percentages use all logical CPUs."""
import json
import os
import statistics
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'builds/performance_800'

def summarize(label):
    read = lambda suffix: json.loads((OUT / (label + suffix)).read_text(encoding='utf-8-sig'))
    proc, gpu = read('_process.json'), read('_gpu.json')
    try:
        bench = read('.json')
    except json.JSONDecodeError:
        # Earlier harness kept the last checkpoint file handle alive until exit,
        # overwriting part of the final rows. Each complete row is also logged.
        raw = (OUT/(label+'.json')).read_text(encoding='utf-8-sig')
        log = (OUT/(label+'.log')).read_text(encoding='utf-8-sig')
        assert 'FEATURE_PROBE_COMPLETE' in log
        bench = json.loads(raw.split('  "rows":')[0]+'"rows": []}')
        bench['rows'] = [json.loads(line.removeprefix('FEATURE_RESULT ')) for line in log.splitlines() if line.startswith('FEATURE_RESULT ')]
        assert len(bench['rows']) == 15 and bench['complete']
        bench['recovery_source'] = label+'.log (FEATURE_RESULT), metadata/events from final JSON prefix'
        (OUT/(label+'_recovered.json')).write_text(json.dumps(bench,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert proc['exit_code'] == 0 and not proc['errors'] and not proc['timed_out']
    result = {'label': label, 'logical_cpus': os.cpu_count(), 'pid': proc['pid'], 'rows': [], 'events': bench['events'], 'recovery_source':bench.get('recovery_source')}
    samples = proc['samples']
    for row in bench['rows']:
        phase = row['phase']
        phase_start = min(s['wall_seconds'] for s in samples if s['phase']==phase)
        # A scene transition can load synchronously before printing a new phase.
        # Restrict to the measured duration, excluding the last 150ms margin.
        intervals = [(a,b) for a,b in zip(samples,samples[1:]) if a['phase']==phase and b['phase']==phase and b['wall_seconds']>a['wall_seconds'] and b['wall_seconds']-phase_start<row['seconds']-0.15]
        assert intervals, phase
        cpu = sum(b['cpu_seconds']-a['cpu_seconds'] for a,b in intervals)
        seconds = sum(b['wall_seconds']-a['wall_seconds'] for a,b in intervals)
        phase_gpu = [r for r in gpu if r['Phase']==phase and r['PhaseAfter']==phase]
        gpu_start = datetime.fromisoformat(phase_gpu[0]['Time']) if phase_gpu else None
        gs = [r for r in phase_gpu[2:] if (datetime.fromisoformat(r['Time'])-gpu_start).total_seconds()<row['seconds']-1.0]
        engines = lambda r: r['Engines'] if isinstance(r['Engines'],list) else [r['Engines']] if r['Engines'] else []
        memory = lambda r: r['Memory'] if isinstance(r['Memory'],list) else [r['Memory']] if r['Memory'] else []
        utilization = [max(e['UtilizationPercentage'] for e in engines(r) if 'engtype_3D' in e['Name']) for r in gs if any('engtype_3D' in e['Name'] for e in engines(r))]
        vram = [sum(m['DedicatedUsage'] for m in memory(r))/1024**2 for r in gs if memory(r)]
        shared = [sum(m['SharedUsage'] for m in memory(r))/1024**2 for r in gs if memory(r)]
        ram = [b['working_bytes']/1024**2 for a,b in intervals]
        commit = [b['private_bytes']/1024**2 for a,b in intervals]
        result['rows'].append(dict(row, cpu_percent=cpu/seconds*100/os.cpu_count(), cpu_core_equivalent=cpu/seconds,
                                  resident_ram_mib=statistics.mean(ram), resident_ram_peak_mib=max(ram),
                                  private_commit_mib=statistics.mean(commit), gpu_percent=statistics.mean(utilization) if utilization else None,
                                  vram_mib=statistics.mean(vram) if vram else None, shared_gpu_ram_mib=statistics.mean(shared) if shared else None,
                                  cpu_samples=len(intervals), gpu_samples=len(utilization)))
    (OUT/(label+'_summary.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for row in result['rows']:
        print(row['phase'], 'CPU',round(row['cpu_percent'],2),'RAM',round(row['resident_ram_mib']), 'GPU',row['gpu_percent'],'VRAM',row['vram_mib'], 'FPS',round(row['fps'],1))
    print(result['events'])
    return result

if __name__ == '__main__':
    summarize(sys.argv[1] if len(sys.argv)>1 else 'feature_resources_20261003')
