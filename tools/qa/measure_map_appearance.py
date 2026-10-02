"""Capture map appearance and measure real Windows process memory.

Usage: python tools/qa/measure_map_appearance.py STAGE [--pack] [--view-angle]
Stage names label comparison artifacts; --pack tests the Windows release PCK.
GPU allocation values in the Godot report are renderer estimates, not driver totals.
"""
import ctypes,subprocess,sys,time,json,shutil,re
from pathlib import Path
from ctypes import wintypes
from windows_gpu_memory import GpuMemory
gpu=GpuMemory();gpu_peak={}
class Memory(ctypes.Structure):
    _fields_=[("cb",wintypes.DWORD),("PageFaultCount",wintypes.DWORD)]+[(n,ctypes.c_size_t) for n in ["PeakWorkingSetSize","WorkingSetSize","QuotaPeakPagedPoolUsage","QuotaPagedPoolUsage","QuotaPeakNonPagedPoolUsage","QuotaNonPagedPoolUsage","PagefileUsage","PeakPagefileUsage"]]
root=Path(__file__).resolve().parents[2]
stage=sys.argv[1]
folder=root/('builds/qa/map_view_angle' if '--view-angle' in sys.argv else 'builds/qa/map_appearance')
test_script=root/('tests/base_map/godot/test_map_view_angle.gd' if '--view-angle' in sys.argv else 'tests/base_map/godot/test_map_appearance.gd')
folder.mkdir(parents=True,exist_ok=True)
command=[shutil.which('godot_console'),'--path',str(root),'--script',str(test_script),'--','--stage='+stage,'--qa-output='+folder.as_posix(),'--source-root='+root.as_posix()]
if '--pack' in sys.argv:command=[shutil.which('godot_console'),'--main-pack',str(root/'builds/windows-latest/MyWorldsOnFreedom.pck'),'--script',str(test_script),'--','--stage='+stage,'--qa-output='+folder.as_posix(),'--source-root='+root.as_posix()]
kernel=ctypes.WinDLL('kernel32',use_last_error=True)
kernel.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD];kernel.OpenProcess.restype=wintypes.HANDLE
kernel.CloseHandle.argtypes=[wintypes.HANDLE]
psapi=ctypes.WinDLL('psapi',use_last_error=True)
psapi.GetProcessMemoryInfo.argtypes=[wintypes.HANDLE,ctypes.POINTER(Memory),wintypes.DWORD]
with (folder/(stage+'_game.log')).open('w',encoding='utf-8') as log:
    process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
    actual_pid=process.pid
    handle=kernel.OpenProcess(0x410,False,actual_pid)
    peak=0;private_peak=0;samples=0
    deadline=time.monotonic()+180
    while process.poll() is None:
        if time.monotonic()>deadline:
            termination=kernel.OpenProcess(0x1,False,actual_pid)
            if termination:
                kernel.TerminateProcess.argtypes=[wintypes.HANDLE,wintypes.UINT]
                kernel.TerminateProcess(termination,1);kernel.CloseHandle(termination)
            process.wait(timeout=10)
            break
        match=re.search(r"map_diagnostics_(\d+)\.jsonl",(folder/(stage+"_game.log")).read_text(encoding="utf-8",errors="replace"))
        if match and int(match.group(1))!=actual_pid:
            if handle:kernel.CloseHandle(handle)
            actual_pid=int(match.group(1));handle=kernel.OpenProcess(0x410,False,actual_pid)
        for label,value in gpu.sample(actual_pid).items():gpu_peak[label]=max(gpu_peak.get(label,0),value)
        m=Memory();m.cb=ctypes.sizeof(m)
        if handle and psapi.GetProcessMemoryInfo(handle,ctypes.byref(m),m.cb):
            peak=max(peak,m.WorkingSetSize);private_peak=max(private_peak,m.PagefileUsage);samples+=1
        time.sleep(.1)
    if handle:kernel.CloseHandle(handle)
errors=[line for line in (folder/(stage+'_game.log')).read_text(encoding='utf-8',errors='replace').splitlines() if line.startswith(('SCRIPT ERROR:','ERROR:','FAIL:'))]
exit_code=process.returncode or (1 if errors else 0)
report={'pid':actual_pid,'exit_code':exit_code,'errors':errors,'peak_working_set_bytes':peak,'peak_private_commit_bytes':private_peak,'samples':samples,'sample_interval_seconds':.1,'windows_gpu_process_peak_bytes':gpu_peak,'gpu_source':'Windows GPU Process Memory dedicated/shared counters; empty means unavailable'}
gpu.close()
(folder/(stage+'_process_memory.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report));sys.exit(exit_code)
