# 06-services: run every service suite headless (for 02 / 07). Owner: 06-services.
# Usage (workspace root):  pwsh -File tests/services/run_services_suites.ps1 [-SimulateIntegration]
# Exit: 0 = all pass and the game binding is integrated
#       2 = all pass, integration BLOCKED (02 S1/S2 not done)  <- expected until 02 integrates
#       1 = any failure
# Runs Godot sequentially (no parallel engines). Mocks only; nothing contacts a network.
param([switch]$SimulateIntegration)
$ErrorActionPreference = 'Continue'   # Godot writes warnings to stderr; 'Stop' would abort the run
Set-Location (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
$G = '.\tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $G)) { Write-Output "Godot console binary not found at $G"; exit 1 }
$suites = @('test_services', 'test_services_m2', 'test_services_m3', 'test_services_listing', 'test_services_m8', 'test_services_integration')
$worst = 0
foreach ($s in $suites) {
  $extra = @()
  if ($s -eq 'test_services_integration' -and $SimulateIntegration) { $extra = @('--', '--simulate-integration') }
  $out = & $G --headless --path . -s "res://tests/services/$s.gd" @extra 2>&1 | ForEach-Object { "$_" -replace '\x1b\[[0-9;]*m', '' }
  $code = $LASTEXITCODE
  $summary = ($out | Select-String -Pattern '^\[test_services' | Select-Object -Last 1).Line
  Write-Output ("{0,-28} exit={1}  {2}" -f $s, $code, $summary)
  $out | Select-String -Pattern '^FAIL \[|BLOCKED:' | ForEach-Object { Write-Output "    $($_.Line.Trim())" }
  if ($code -eq 1 -or ($code -ne 0 -and $code -ne 2)) { $worst = 1 }
  elseif ($code -eq 2 -and $worst -eq 0) { $worst = 2 }
}
Write-Output ("OVERALL exit={0} ({1})" -f $worst, @('PASS_INTEGRATED', 'FAIL', 'BLOCKED_NOT_INTEGRATED')[$worst])
exit $worst
