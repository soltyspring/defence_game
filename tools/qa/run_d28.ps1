# 07-qa: D28 balance rows, one round per isolated Godot process, each under the machine-wide heavy-run lock.
# Owner: 07-qa. Needs the clean HEAD snapshot made by `run_acceptance.ps1 -Head` (%TEMP%\qa07_head, imported).
# Usage: .\tools\qa\run_d28.ps1 -Rounds r01,r03,r06 [-Seeds 10] [-TimeoutSec 420] [-Tag head] [-Budgets d28|low,low2r,none]
# Per round: coordination/heavy_run.ps1 -> docs/research/systems/probes/isolated_godot.ps1 (private APPDATA) ->
#   tests/acceptance/probe_balance.gd --d28 --rows. Output: build/qa07/d28_<tag>_<round>.txt (git-ignored).
# The lock is taken per round, so other workers can run between rounds. By default only the budget each D28 row needs
# runs (heavy-run rule: only necessary combinations); r10 runs low2r first, so a timeout still leaves the D28 row.
# isolated_godot keeps the lines printed before a timeout (exit 124).
param([string[]]$Rounds = @('r01', 'r03', 'r06', 'r07', 'r08', 'r09', 'r10'), [int]$Seeds = 10, [int]$TimeoutSec = 420,
      [string]$Tag = 'head', [string]$Project = (Join-Path $env:TEMP 'qa07_head'),
      [string]$Budgets = 'd28')   # 'd28' = only the budget each round's D28 row needs (low; r05 low,low2r; r10 low2r,low)
$ErrorActionPreference = 'Continue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
if (-not (Test-Path (Join-Path $Project 'project.godot'))) { Write-Host "no snapshot at $Project; run run_acceptance.ps1 -Head first"; exit 3 }
$out = Join-Path $Root 'build\qa07'
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($r in $Rounds) {
    # PowerShell names are case-insensitive: a local "$budgets" would overwrite the -Budgets parameter (07 bug at 00:09,
    # every round after the first ran 'low' only, so r10 low2r was skipped). Use a distinct name.
    $bsel = if ($Budgets -ne 'd28') { $Budgets } elseif ($r -eq 'r10') { 'low2r,low' } elseif ($r -eq 'r05') { 'low,low2r' } else { 'low' }
    $file = Join-Path $out "d28_${Tag}_$r.txt"
    $ga = @('--headless', '--path', $Project, '-s', 'res://tests/acceptance/probe_balance.gd', '--', "--rounds=$r", "--seeds=$Seeds", "--budgets=$bsel", '--d28', '--rows')
    $t0 = Get-Date
    $iso_ps = Join-Path $Root 'docs\research\systems\probes\isolated_godot.ps1'
    $tsec = $TimeoutSec
    $job = { & $iso_ps -TimeoutSec $tsec -GodotArgs $ga }.GetNewClosure()   # bind values; heavy_run has its own $root
    & (Join-Path $Root 'coordination\heavy_run.ps1') -Label "07-d28-$r" -WaitMinutes 45 -Script $job *>&1 | Out-File -FilePath $file -Encoding utf8
    $d = Select-String -Path $file -Pattern '^\[d28\] \{' | ForEach-Object { $_.Line }
    $iso = Select-String -Path $file -Pattern '^ISOLATED_GODOT' | ForEach-Object { $_.Line }
    Write-Host ("[{0}] {1} done in {2:N0} s" -f (Get-Date -Format 'HH:mm:ss'), $r, ((Get-Date) - $t0).TotalSeconds)
    $d | ForEach-Object { Write-Host "  $_" }
    Write-Host "  $iso"
}
