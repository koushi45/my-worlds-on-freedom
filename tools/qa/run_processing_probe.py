"""Reuse the Windows process sampler, adding per-thread CPU and GPU clock data."""
import os
import random

# Reuse its command construction and Windows structures without starting its loop.
from pathlib import Path
exec(compile((Path(__file__).with_name('run_gpu_check.py')).read_text(encoding='utf-8').split('log_path = folder')[0], 'run_gpu_check_common', 'exec'))

class ThreadEntry(ctypes.Structure):
    _fields_ = [('dwSize',wintypes.DWORD),('cntUsage',wintypes.DWORD),('th32ThreadID',wintypes.DWORD),('th32OwnerProcessID',wintypes.DWORD),('tpBasePri',wintypes.LONG),('tpDeltaPri',wintypes.LONG),('dwFlags',wintypes.DWORD)]

k.CreateToolhelp32Snapshot.argtypes=[wintypes.DWORD,wintypes.DWORD]
k.CreateToolhelp32Snapshot.restype=wintypes.HANDLE
k.Thread32First.argtypes=[wintypes.HANDLE,ctypes.POINTER(ThreadEntry)]
k.Thread32Next.argtypes=[wintypes.HANDLE,ctypes.POINTER(ThreadEntry)]
k.OpenThread.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD]
k.OpenThread.restype=wintypes.HANDLE
k.GetThreadTimes.argtypes=[wintypes.HANDLE,*([ctypes.POINTER(wintypes.FILETIME)]*4)]
k.GetThreadDescription.argtypes=[wintypes.HANDLE,ctypes.POINTER(ctypes.c_wchar_p)]
k.LocalFree.argtypes=[wintypes.HANDLE]
k.LocalFree.restype=wintypes.HANDLE

class MemoryBasicInfo(ctypes.Structure):
    _fields_=[('BaseAddress',ctypes.c_void_p),('AllocationBase',ctypes.c_void_p),('AllocationProtect',wintypes.DWORD),('RegionSize',ctypes.c_size_t),('State',wintypes.DWORD),('Protect',wintypes.DWORD),('Type',wintypes.DWORD)]
k.VirtualQueryEx.argtypes=[wintypes.HANDLE,ctypes.c_void_p,ctypes.POINTER(MemoryBasicInfo),ctypes.c_size_t]
k.VirtualQueryEx.restype=ctypes.c_size_t
p.GetModuleFileNameExW.argtypes=[wintypes.HANDLE,wintypes.HANDLE,wintypes.LPWSTR,wintypes.DWORD]
k.SuspendThread.argtypes=[wintypes.HANDLE]; k.SuspendThread.restype=wintypes.DWORD
k.ResumeThread.argtypes=[wintypes.HANDLE]; k.ResumeThread.restype=wintypes.DWORD
k.GetThreadContext.argtypes=[wintypes.HANDLE,ctypes.c_void_p]
module_cache={}

def sample_main_module(pid,main_tid,process_handle):
    """Briefly sample the instruction pointer of our own QA process only."""
    handle=k.OpenThread(0x4A,False,main_tid)
    if not handle: return None
    raw=ctypes.create_string_buffer(1250)
    address=(ctypes.addressof(raw)+15)&~15
    ctypes.c_uint32.from_address(address+48).value=0x10000B
    begin=time.perf_counter_ns()
    suspended=False
    ip=None
    try:
        suspended=k.SuspendThread(handle)!=0xFFFFFFFF
        if suspended and k.GetThreadContext(handle,ctypes.c_void_p(address)):
            ip=ctypes.c_uint64.from_address(address+248).value
    finally:
        if suspended: k.ResumeThread(handle)
        k.CloseHandle(handle)
    elapsed=(time.perf_counter_ns()-begin)/1000
    if not ip: return None
    memory=MemoryBasicInfo()
    if not k.VirtualQueryEx(process_handle,ctypes.c_void_p(ip),ctypes.byref(memory),ctypes.sizeof(memory)): return None
    base=memory.AllocationBase
    if base not in module_cache:
        name=ctypes.create_unicode_buffer(2048)
        found=p.GetModuleFileNameExW(process_handle,base,name,len(name))
        module_cache[base]=Path(name.value).name if found else '<anonymous>'
    return {'module':module_cache[base],'suspend_us':elapsed}

def thread_snapshot(pid):
    snapshot=k.CreateToolhelp32Snapshot(4,0)
    entry=ThreadEntry(); entry.dwSize=ctypes.sizeof(entry)
    result=[]
    more=k.Thread32First(snapshot,ctypes.byref(entry))
    while more:
        if entry.th32OwnerProcessID==pid:
            handle=k.OpenThread(0x800,False,entry.th32ThreadID)
            if handle:
                times=[wintypes.FILETIME() for _ in range(4)]
                if k.GetThreadTimes(handle,*[ctypes.byref(t) for t in times]):
                    numbers=[((t.dwHighDateTime<<32)|t.dwLowDateTime)/1e7 for t in times]
                    desc=ctypes.c_wchar_p()
                    name=''
                    if k.GetThreadDescription(handle,ctypes.byref(desc))==0 and desc:
                        name=desc.value or ''; k.LocalFree(ctypes.cast(desc,wintypes.HANDLE))
                    result.append({'id':entry.th32ThreadID,'name':name,'created':numbers[0],'kernel':numbers[2],'user':numbers[3]})
                k.CloseHandle(handle)
        more=k.Thread32Next(snapshot,ctypes.byref(entry))
    k.CloseHandle(snapshot)
    return result

log_path=folder/(label+'.log')
samples=[]; thread_samples=[]; clocks=[]; native_samples=[]
start=time.monotonic(); actual_pid=None; handle=None
peak_working=peak_private=0; timed_out=False
last_phase=None; last_threads=-1; last_clock=-1; main_tid=None
native_enabled='--native-sample' in sys.argv
with log_path.open('w',encoding='utf-8') as log:
    proc=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    while proc.poll() is None:
        contents=log_path.read_text(encoding='utf-8',errors='replace')
        match=re.search(r'map_diagnostics_(\d+)\.jsonl',contents)
        pid=int(match[1]) if match else proc.pid
        if pid!=actual_pid:
            if handle: k.CloseHandle(handle)
            actual_pid=pid; handle=k.OpenProcess(0x410,False,pid); main_tid=None; module_cache.clear()
        phases=re.findall(r'BENCH800_PHASE ([^\r\n]+)',contents)
        phase=phases[-1] if phases else 'startup'
        wall=time.monotonic()-start
        m=Memory(); m.cb=ctypes.sizeof(m)
        if handle and p.GetProcessMemoryInfo(handle,ctypes.byref(m),m.cb):
            peak_working=max(peak_working,m.WorkingSetSize); peak_private=max(peak_private,m.PagefileUsage)
            times=[wintypes.FILETIME() for _ in range(4)]
            if k.GetProcessTimes(handle,*[ctypes.byref(t) for t in times]):
                cpu=sum((t.dwHighDateTime<<32)|t.dwLowDateTime for t in times[2:])/1e7
                samples.append({'wall_seconds':wall,'cpu_seconds':cpu,'working_bytes':m.WorkingSetSize,'private_bytes':m.PagefileUsage,'phase':phase})
        if phase!=last_phase or wall-last_threads>=.5:
            threads=thread_snapshot(pid)
            thread_samples.append({'wall_seconds':wall,'phase':phase,'threads':threads})
            if threads and main_tid is None: main_tid=min(threads,key=lambda t:t['created'])['id']
            last_threads=wall; last_phase=phase
        if wall-last_clock>=1:
            gpu=subprocess.run(['nvidia-smi','--query-gpu=clocks.current.graphics,clocks.current.memory,pstate,temperature.gpu,utilization.gpu','--format=csv,noheader,nounits'],capture_output=True,text=True,creationflags=0x08000000)
            clocks.append({'wall_seconds':time.monotonic()-start,'phase':phase,'gpu_clock_csv':gpu.stdout.strip()})
            last_clock=wall
        errors=any(line.startswith(('SCRIPT ERROR:','ERROR:','FAIL:')) for line in contents.splitlines())
        if wall>240 or errors:
            timed_out=wall>240
            termination=k.OpenProcess(1,False,pid)
            if termination: k.TerminateProcess(termination,1); k.CloseHandle(termination)
            proc.wait(timeout=15); break
        if native_enabled and main_tid and handle:
            native=sample_main_module(pid,main_tid,handle)
            if native: native_samples.append(dict(native,phase=phase,wall_seconds=time.monotonic()-start))
        time.sleep(random.uniform(.01,.035) if native_enabled else .1)
    if handle: k.CloseHandle(handle)
errors=[line for line in log_path.read_text(encoding='utf-8',errors='replace').splitlines() if line.startswith(('SCRIPT ERROR:','ERROR:','FAIL:'))]
report={'command':command,'pid':actual_pid,'exit_code':proc.returncode,'errors':errors,'timed_out':timed_out,'peak_working_set_bytes':peak_working,'peak_private_bytes':peak_private,'samples':samples,'thread_samples':thread_samples,'gpu_clocks':clocks,'native_samples':native_samples}
(folder/(label+'_process.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({key:value for key,value in report.items() if key not in ('samples','thread_samples','gpu_clocks','native_samples')}))
sys.exit(1 if errors or timed_out or proc.returncode else 0)
