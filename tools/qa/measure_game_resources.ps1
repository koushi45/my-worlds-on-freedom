param([int]$FpsLimit = 60)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskLabel = "resources_800_${FpsLimit}fps"
$taskOut = Join-Path $taskRoot 'builds/performance_800'
$taskLog = Join-Path $taskOut ($taskLabel + '.log')
$taskRows = [System.Collections.Generic.List[object]]::new()
$taskExisting = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'python*' -and $_.CommandLine -like "*run_gpu_check.py*$taskLabel*" } | Select-Object -First 1
if ($taskExisting) { $taskRunner = Get-Process -Id $taskExisting.ProcessId }
else { $taskRunner = Start-Process python -ArgumentList @('tools/qa/run_gpu_check.py', 'tests/base_map/godot/benchmark_map_800.gd', $taskLabel, '--release', ('--stage=' + $taskLabel), ('--fps-limit=' + $FpsLimit), '--frames=600', '--production-overlays') -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskOut ($taskLabel+'_runner.log')) -RedirectStandardError (Join-Path $taskOut ($taskLabel+'_runner_error.log')) }
function Read-TaskLog {
    $taskStream = [System.IO.File]::Open($taskLog,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $taskReader = [System.IO.StreamReader]::new($taskStream)
    try { return $taskReader.ReadToEnd() } finally { $taskReader.Dispose() }
}
$taskDeadline = (Get-Date).AddSeconds(240)
while (-not $taskRunner.HasExited -and (Get-Date) -lt $taskDeadline) {
    if (Test-Path -LiteralPath $taskLog) {
        $taskText = Read-TaskLog
        $taskMatch = [regex]::Match($taskText, 'map_diagnostics_(\d+)\.jsonl')
        if ($taskMatch.Success) {
            $taskPid = [int]$taskMatch.Groups[1].Value
            $taskPhases = [regex]::Matches($taskText, 'BENCH800_PHASE ([^\r\n]+)')
            $taskPhase = if ($taskPhases.Count) { $taskPhases[$taskPhases.Count-1].Groups[1].Value } else { 'startup' }
            $taskStart = Get-Date
            $taskEngines = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -Filter "Name LIKE 'pid_${taskPid}_%'" | Select-Object Name,UtilizationPercentage)
            $taskMemory = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -Filter "Name LIKE 'pid_${taskPid}_%'" | Select-Object Name,DedicatedUsage,SharedUsage)
            $taskTextAfter = Read-TaskLog
            $taskPhasesAfter = [regex]::Matches($taskTextAfter, 'BENCH800_PHASE ([^\r\n]+)')
            $taskPhaseAfter = if ($taskPhasesAfter.Count) { $taskPhasesAfter[$taskPhasesAfter.Count-1].Groups[1].Value } else { 'startup' }
            $taskRows.Add([pscustomobject]@{Time=$taskStart.ToString('o');Pid=$taskPid;Phase=$taskPhase;PhaseAfter=$taskPhaseAfter;QueryMs=((Get-Date)-$taskStart).TotalMilliseconds;Engines=$taskEngines;Memory=$taskMemory})
        }
    }
    Start-Sleep -Milliseconds 800
    $taskRunner.Refresh()
}
$taskRows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskOut ($taskLabel+'_gpu.json')) -Encoding UTF8
if (-not $taskRunner.HasExited) { throw 'Resource measurement exceeded deadline' }
$taskReport = Get-Content -LiteralPath (Join-Path $taskOut ($taskLabel+'_process.json')) -Raw | ConvertFrom-Json
if ($taskReport.exit_code -ne 0 -or $taskReport.errors.Count) { throw 'Game resource test failed' }
Write-Output "RESOURCE_MEASUREMENT_COMPLETE GPU samples=$($taskRows.Count)"
