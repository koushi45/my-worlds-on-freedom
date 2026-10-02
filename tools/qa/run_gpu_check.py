"""Run a GPU test with a deadline and collect Windows process memory/CPU."""
import ctypes
import json
import re
import shutil
import subprocess
import sys
import time
from ctypes import wintypes
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
folder = ROOT / "builds/performance_800"
folder.mkdir(parents=True, exist_ok=True)
script, label, *args = sys.argv[1:]
release = "--release" in args
args = [a for a in args if a != "--release"]
engine = str(ROOT / "builds/windows-latest/MyWorldsOnFreedom.exe") if release else shutil.which("godot_console")
command = [engine, "--path", str(ROOT), "--script", str(ROOT / script), "--", *args]
if release:
    command = [engine, "--script", str(ROOT / script), "--", *args]

class Memory(ctypes.Structure):
    _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [
        (n, ctypes.c_size_t) for n in ("PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage")]

k = ctypes.WinDLL("kernel32", use_last_error=True)
k.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
k.OpenProcess.restype = wintypes.HANDLE
k.CloseHandle.argtypes = [wintypes.HANDLE]
k.GetProcessTimes.argtypes = [wintypes.HANDLE, *([ctypes.POINTER(wintypes.FILETIME)] * 4)]
k.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
p = ctypes.WinDLL("psapi")
p.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Memory), wintypes.DWORD]
log_path = folder / (label + ".log")
peak_working = peak_private = 0
samples = []
actual_pid = None
handle = None
start = time.monotonic()
timed_out = False
with log_path.open("w", encoding="utf-8") as log:
    proc = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    while proc.poll() is None:
        contents = log_path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"map_diagnostics_(\d+)\.jsonl", contents)
        pid = int(match[1]) if match else proc.pid
        if pid != actual_pid:
            if handle: k.CloseHandle(handle)
            actual_pid = pid
            handle = k.OpenProcess(0x410, False, pid)
        m = Memory(); m.cb = ctypes.sizeof(m)
        if handle and p.GetProcessMemoryInfo(handle, ctypes.byref(m), m.cb):
            peak_working = max(peak_working, m.WorkingSetSize)
            peak_private = max(peak_private, m.PagefileUsage)
            times = [wintypes.FILETIME() for _ in range(4)]
            if k.GetProcessTimes(handle, *[ctypes.byref(t) for t in times]):
                cpu = sum((t.dwHighDateTime << 32) | t.dwLowDateTime for t in times[2:]) / 1e7
                samples.append({"wall_seconds":time.monotonic()-start,"cpu_seconds":cpu,"working_bytes":m.WorkingSetSize,"private_bytes":m.PagefileUsage})
        errors = any(line.startswith(("SCRIPT ERROR:","ERROR:","FAIL:")) for line in contents.splitlines())
        if time.monotonic()-start > 240 or errors:
            timed_out = time.monotonic()-start > 240
            termination = k.OpenProcess(1, False, pid)
            if termination: k.TerminateProcess(termination, 1); k.CloseHandle(termination)
            proc.wait(timeout=15)
            break
        time.sleep(.1)
    if handle: k.CloseHandle(handle)
errors = [l for l in log_path.read_text(encoding="utf-8",errors="replace").splitlines() if l.startswith(("SCRIPT ERROR:","ERROR:","FAIL:"))]
report = {"command":command,"pid":actual_pid,"exit_code":proc.returncode,"errors":errors,"timed_out":timed_out,"peak_working_set_bytes":peak_working,"peak_private_bytes":peak_private,"samples":samples}
(folder / (label + "_process.json")).write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps({k:v for k,v in report.items() if k!="samples"}))
sys.exit(1 if errors or timed_out or proc.returncode else 0)
