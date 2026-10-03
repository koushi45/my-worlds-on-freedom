param([string]$Label = 'feature_resources_20261003', [string]$Script = 'tests/base_map/godot/probe_feature_resources.gd')
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskOut = Join-Path $taskRoot 'builds/performance_800'
$taskLog = Join-Path $taskOut ($Label + '.log')
$taskRows = [System.Collections.Generic.List[object]]::new()
$taskRunner = Start-Process python -ArgumentList @('tools/qa/run_gpu_check.py',$Script,$Label,'--pack',('--output='+($taskOut.Replace('\','/')+'/'+$Label+'.json'))) -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskOut ($Label+'_runner.log')) -RedirectStandardError (Join-Path $taskOut ($Label+'_runner_error.log'))
function Read-TaskLog {
    $taskStream = [System.IO.File]::Open($taskLog,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    $taskReader = [System.IO.StreamReader]::new($taskStream)
    try { return $taskReader.ReadToEnd() } finally { $taskReader.Dispose() }
}
$taskDeadline = (Get-Date).AddSeconds(300)
while (-not $taskRunner.HasExited -and (Get-Date) -lt $taskDeadline) {
    if (Test-Path -LiteralPath $taskLog) {
        $taskText = Read-TaskLog
        $taskMatch = [regex]::Match($taskText,'map_diagnostics_(\d+)\.jsonl')
        if ($taskMatch.Success) {
            $taskPid = [int]$taskMatch.Groups[1].Value
            $taskPhases = [regex]::Matches($taskText,'BENCH800_PHASE ([^\r\n]+)')
            $taskPhase = if ($taskPhases.Count) { $taskPhases[$taskPhases.Count-1].Groups[1].Value } else { 'startup' }
            $taskStart = Get-Date
            $taskEngines = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -Filter "Name LIKE 'pid_${taskPid}_%'" | Select-Object Name,UtilizationPercentage)
            $taskMemory = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -Filter "Name LIKE 'pid_${taskPid}_%'" | Select-Object Name,DedicatedUsage,SharedUsage)
            $taskTextAfter = Read-TaskLog
            $taskPhasesAfter = [regex]::Matches($taskTextAfter,'BENCH800_PHASE ([^\r\n]+)')
            $taskPhaseAfter = if ($taskPhasesAfter.Count) { $taskPhasesAfter[$taskPhasesAfter.Count-1].Groups[1].Value } else { 'startup' }
            $taskRows.Add([pscustomobject]@{Time=$taskStart.ToString('o');Pid=$taskPid;Phase=$taskPhase;PhaseAfter=$taskPhaseAfter;QueryMs=((Get-Date)-$taskStart).TotalMilliseconds;Engines=$taskEngines;Memory=$taskMemory})
        }
    }
    Start-Sleep -Milliseconds 500
    $taskRunner.Refresh()
}
$taskRows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskOut ($Label+'_gpu.json')) -Encoding UTF8
if (-not $taskRunner.HasExited) { throw 'Measurement exceeded deadline' }
$taskReport = Get-Content -LiteralPath (Join-Path $taskOut ($Label+'_process.json')) -Raw | ConvertFrom-Json
if ($taskReport.exit_code -ne 0 -or $taskReport.errors.Count) { throw "Probe failed: see $taskLog" }
Write-Output "FEATURE_MEASUREMENT_COMPLETE samples=$($taskRows.Count)"
