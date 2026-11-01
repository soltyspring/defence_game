<#
Machine-wide lock for heavy local processes (Godot headless/visible, import/export, Gradle/AAB/APK builds, emulator, long benchmarks).
Only ONE heavy run at a time across all ten workers. Added 2026-10-31 after a 23:09 KST blue screen (bugcheck 0x50).
Usage (from pwsh, workspace root):
  & .\coordination\heavy_run.ps1 -Label '03-import' -Script { & .\tools\engine\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import }
The mutex is released when the script ends or its process dies (abandoned mutex is taken over safely).
2026-11-01 01:20 KST: caller-safe scoping installed from 10's proposal (DATA_AND_BACKEND_ANALYSIS §9.23). Internal variables are
$private:hr*, no script-wide ErrorActionPreference, LASTEXITCODE reset before the block, END always written (status=ok|exception).
Verified with docs/research/systems/probes/heavy_run_scope_test.ps1: 4/4 PASS (previous version 0/4). Log line format unchanged
except the trailing status= field; 02:10 KST log lines are written with an exclusive append handle (Write-HrLine), so START/END ... pid= parsers (tools/perf/perf_isolation.ps1, tests/services/svc06_isolation.ps1) keep working.
#>
param(
  [Parameter(Mandatory)][string]$Label,
  [Parameter(Mandatory)][scriptblock]$Script,
  [int]$WaitMinutes = 45
)
# $private: = invisible to the caller's script block (it runs in a child scope), so a caller's $log/$root/... is never
# shadowed and the mutex cannot be touched from the block. No script-wide $ErrorActionPreference: a preference set here IS
# inherited by the block even with $private: (tested), so errors are made terminating per call with -ErrorAction Stop.
# Log lines are written through an exclusive append handle with retry. Add-Content from several processes at once loses
# lines (measured 01-11-01 02:08: 3 writers x 200 lines kept 307/600 with Add-Content, 600/600 with this function), which is
# how START/END lines went missing (10-v032-c END, 23:53 04 START without END).
function private:Write-HrLine([string]$hrPath, [string]$hrText) {
  $hrBytes = [Text.Encoding]::UTF8.GetBytes($hrText + [Environment]::NewLine)
  $hrT0 = Get-Date
  while ($true) {
    try {
      $hrFs = [IO.File]::Open($hrPath, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::Read)
      try { $hrFs.Write($hrBytes, 0, $hrBytes.Length); $hrFs.Flush($true) } finally { $hrFs.Dispose() }
      return
    } catch [IO.IOException] {
      if (((Get-Date) - $hrT0).TotalSeconds -gt 30) { throw }
      Start-Sleep -Milliseconds 25
    }
  }
}
$private:hrLog = Join-Path (Split-Path $PSScriptRoot -Parent) 'coordination\.runtime\heavy_run.log'
$private:hrMutex = New-Object System.Threading.Mutex($false, 'Local\defence_heavy_run')
$private:hrGot = $false
$private:hrStart = Get-Date
$private:hrStatus = 'exception'
$private:hrCode = 1
try {
  try { $hrGot = $hrMutex.WaitOne([TimeSpan]::FromMinutes($WaitMinutes)) } catch [System.Threading.AbandonedMutexException] { $hrGot = $true }
  if (-not $hrGot) { throw "heavy_run: lock busy for $WaitMinutes min ($Label). Retry later; do not bypass." }
  $private:hrWaited = [int]((Get-Date) - $hrStart).TotalSeconds
  Write-HrLine $hrLog ("{0:s} START {1} pid={2} waited={3}s" -f (Get-Date), $Label, $PID, $hrWaited)
  Write-Host "heavy_run: lock acquired for $Label after $hrWaited s"
  $global:LASTEXITCODE = 0          # no stale exit code from before the block
  & $Script
  $hrCode = [int]$LASTEXITCODE
  $hrStatus = 'ok'
} finally {
  if ($hrGot) {
    Write-HrLine $hrLog ("{0:s} END {1} pid={2} exit={3} status={4}" -f (Get-Date), $Label, $PID, $hrCode, $hrStatus)
    $hrMutex.ReleaseMutex()
  }
  $hrMutex.Dispose()
}
if ($hrCode) { exit $hrCode }

