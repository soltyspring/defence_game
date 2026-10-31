# 01-director balance sweep helper. Runs multi_seed_sim.gd.txt once per override file and prints the summary table.
# ISOLATED (10 v0.26/v0.28): every run goes through docs/research/systems/probes/isolated_godot.ps1, which gives the
# child its own APPDATA, so user:// can never resolve to the real player folder (%APPDATA%\Godot\app_userdata\Lane Defence).
# The wrapper prints "ISOLATED_GODOT {...}" with the isolation proof; this script fails if that line is missing.
# Usage (workspace root):
#   .\docs\design\balance\sweep.ps1 -Overrides a.json,b.json -Rounds r02,r03 -Budgets none,low -Seeds 1,2,3,4,5 -Policies competent,casual
#   Use -Overrides '-' to run the current data without overrides. Manual single runs: use this script, not Godot directly.
param([string[]]$Overrides = @('-'), [string]$Rounds = 'all', [string]$Budgets = 'none,low,opt', [string]$Seeds = '1,2,3,4,5',
      [string]$Policies = 'competent', [string]$LateDelay = '45', [string]$OutDir = $env:TEMP, [int]$TimeoutSec = 1500)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$sim = Join-Path $env:TEMP 'multi_seed_sim.gd'
Copy-Item (Join-Path $PSScriptRoot 'multi_seed_sim.gd.txt') $sim -Force
$iso = Join-Path $root 'docs\research\systems\probes\isolated_godot.ps1'
$env:PYTHONIOENCODING = 'utf-8'
foreach ($ov in $Overrides) {
  $name = if ($ov -eq '-') { 'data' } else { [IO.Path]::GetFileNameWithoutExtension($ov) }
  $out = Join-Path $OutDir "sweep_$name.json"
  $log = & $iso -TimeoutSec $TimeoutSec -GodotArgs @('--headless', '--path', $root, '-s', $sim, '--', $out, $ov, $Budgets, $Seeds, $Rounds, $LateDelay, $Policies) 2>&1 | ForEach-Object { "$_" }
  $proof = $log | Where-Object { $_ -like 'ISOLATED_GODOT*' }
  if (-not $proof) { throw "isolation proof missing for $name; result discarded" }
  "=== $name  ($($proof.Substring(0, [Math]::Min(160, $proof.Length))))"
  python (Join-Path $PSScriptRoot 'summarize_multi_seed.py') $out | Select-String -NotMatch 'warnings|^\|---|kind \| budget'
}
