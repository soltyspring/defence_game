<#
Start a heavy run in a DETACHED hidden pwsh, so the agent tool-call time limit (30 min) cannot kill the process that
holds the PC-wide lock. Added 2026-11-01 01:5x KST after 01:46-01:50: 05, 01 and 10 tool calls hit the 30-min limit while
waiting in or just after taking the lock; a killed wrapper released the mutex while its Godot child kept running, so
heavy runs overlapped (heavy_run.log NOTE lines).

Usage (workspace root). Put the heavy command(s) with all arguments in one small .ps1 job file, then:
  & .\coordination\heavy_run_detached.ps1 -Label '03-import' -ScriptFile build\heavy\03-import-job.ps1
It returns at once and prints:  HEAVY_JOB_STARTED pid=<pid> out=<log file>
The log file ends with  HEAVY_JOB_DONE exit=<n> at <time>  when the job has finished.
Poll it in SHORT tool calls (each well under 30 minutes), e.g.:
  Select-String -LiteralPath <log file> -Pattern '^HEAVY_JOB_DONE'
Rules: never wait for the lock or run Godot/Gradle/emulator commands in the foreground of a tool call that can pass
30 minutes; do not queue a second job for the same task while the first is queued or running; never kill a job process.
#>
param(
  [Parameter(Mandatory)][string]$Label,
  [Parameter(Mandatory)][string]$ScriptFile,
  [string]$OutFile = '',
  [int]$WaitMinutes = 180,
  [string]$HeavyRunPath = ''
)
$ErrorActionPreference = 'Stop'
$hrdRoot = Split-Path $PSScriptRoot -Parent
if (-not $HeavyRunPath) { $HeavyRunPath = Join-Path $PSScriptRoot 'heavy_run.ps1' }
$hrdHeavy = (Resolve-Path -LiteralPath $HeavyRunPath).Path
$hrdScript = (Resolve-Path -LiteralPath $ScriptFile).Path
if (-not $OutFile) {
  $hrdSafe = $Label -replace '[^\w.-]', '_'
  $OutFile = Join-Path (Join-Path $hrdRoot 'build\heavy') ('{0}-{1:yyyyMMdd-HHmmss}.log' -f $hrdSafe, (Get-Date))
}
$OutFile = [IO.Path]::GetFullPath($OutFile)
New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null
$hrdJob = Join-Path $PSScriptRoot 'heavy_run_job.ps1'
$hrdArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $hrdJob),
  '-Label', ('"{0}"' -f $Label), '-ScriptFile', ('"{0}"' -f $hrdScript), '-OutFile', ('"{0}"' -f $OutFile),
  '-WaitMinutes', $WaitMinutes, '-HeavyRunPath', ('"{0}"' -f $hrdHeavy))
$hrdProc = Start-Process -FilePath 'pwsh' -ArgumentList $hrdArgs -WorkingDirectory $hrdRoot -WindowStyle Hidden -PassThru
'HEAVY_JOB_STARTED pid={0} out={1}' -f $hrdProc.Id, $OutFile
