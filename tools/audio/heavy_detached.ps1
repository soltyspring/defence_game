# Detached heavy run for 05-audio. Owner: 05-audio.
# Why: the agent tool call has a 30-min limit; a long heavy_run lock wait plus recordings exceeded it, the tool killed
# the heavy_run wrapper and its Godot child kept running outside the lock (heavy_run.log NOTE 2026-11-01 01:47).
# This script is started as its own hidden process, so the tool limit cannot kill the wrapper; the lock stays held
# for the whole run and is released by heavy_run.ps1 itself.
# Start (workspace root, no visible window):
#   Start-Process pwsh -WindowStyle Hidden -WorkingDirectory . -ArgumentList '-NoProfile','-File','tools/audio/heavy_detached.ps1','-Label','05-audio-x','-ChecksArgs','"-Record -RecordTag rc"'
#   -Py '"tools/audio/same_bg_ab.py --tag=rb; tools/audio/repetition_check.py --tag=rd"' runs those Python measurements
#   (each longer than 1 min counts as heavy) one after another under the same lock instead of run_godot_checks.ps1.
# Poll: tools/audio/_render/detached_<Label>.log ; the last line is 'DETACHED_DONE <time> exit=<n>' when finished.
param([Parameter(Mandatory)][string]$Label, [string]$ChecksArgs = '', [string]$Py = '', [int]$WaitMinutes = 120)
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root
$log = Join-Path $root "tools\audio\_render\detached_$Label.log"
# arguments contain no spaces inside values (e.g. -RecordSeeds 11,23,37), so a whitespace split is exact
$argv = @($ChecksArgs -split '\s+' | Where-Object { $_ })
$pyCmds = @($Py -split ';' | ForEach-Object { , @($_.Trim() -split '\s+' | Where-Object { $_ }) } | Where-Object { $_.Count -gt 0 })
('DETACHED_START {0:s} pid={1} args={2} py={3}' -f (Get-Date), $PID, $ChecksArgs, $Py) | Out-File -LiteralPath $log -Encoding utf8
$code = 1
try {
  if ($pyCmds.Count -gt 0) {
    & .\coordination\heavy_run.ps1 -Label $Label -WaitMinutes $WaitMinutes -Script {
      $bad = 0
      foreach ($c in $pyCmds) { "=== python $($c -join ' ')"; & python @c; if ($LASTEXITCODE) { $bad++ } }
      $global:LASTEXITCODE = $bad
    } *>> $log
  } else {
    & .\coordination\heavy_run.ps1 -Label $Label -WaitMinutes $WaitMinutes -Script { pwsh -NoProfile -File tools/audio/run_godot_checks.ps1 @argv } *>> $log
  }
  $code = [int]$LASTEXITCODE
} catch { ('DETACHED_ERROR {0}' -f $_) | Out-File -LiteralPath $log -Append -Encoding utf8 }
('DETACHED_DONE {0:s} exit={1}' -f (Get-Date), $code) | Out-File -LiteralPath $log -Append -Encoding utf8
exit $code
