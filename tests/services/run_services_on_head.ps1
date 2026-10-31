# 06-services: run every services suite on a clean snapshot of a commit (default HEAD). Owner: 06-services.
# Usage (workspace root):  pwsh -NoProfile -File tests/services/run_services_on_head.ps1 [-Ref HEAD] [-Keep]
# Why: the shared working tree can hold other roles' uncommitted edits (e.g. src/core). This runs the
# same suites as run_services_suites.ps1 on `git archive <Ref>` with its own `--import`, so the result
# belongs to that commit only. Existing APKs from build/ (untracked) are copied in so the Android
# checks read the same packages as in the shared tree. The `.uid` tracking group needs git and reports
# NOT_RUN in the snapshot (no .git). Exit codes as run_services_suites.ps1: 0 / 2 / 1.
param([string]$Ref = 'HEAD', [switch]$Keep)
$ErrorActionPreference = 'Continue'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root
$G = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $G)) { Write-Output "Godot console binary not found at $G"; exit 1 }
. (Join-Path $PSScriptRoot 'svc06_isolation.ps1')
Assert-SvcHeavyLock
Enter-SvcIsolation 'head'   # private APPDATA for the import and every suite (10 v0.26); the snapshot keeps config/name
$sha = (git rev-parse --short $Ref).Trim()
$snap = Join-Path $env:TEMP "svc06_head_$sha"
Remove-Item $snap -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $snap | Out-Null
git -c core.autocrlf=false -c core.eol=lf archive --format=zip -o "$snap.zip" $Ref
if ($LASTEXITCODE -ne 0) { Write-Output 'git archive failed'; exit 1 }
Expand-Archive "$snap.zip" -DestinationPath $snap -Force
Remove-Item "$snap.zip" -Force
# Line-ending gate: the snapshot must hold the committed LF data bytes (content_version depends on them).
. (Join-Path $PSScriptRoot 'svc06_content_version.ps1')
$crlfData = @(Get-ChildItem (Join-Path $snap 'data') -Recurse -Filter *.json -File | Where-Object { (Get-SvcEol ([IO.File]::ReadAllBytes($_.FullName))).crlf -gt 0 })
if ($crlfData.Count -gt 0) {
  Write-Output ("REFUSED: snapshot data has CRLF in {0} json files; not running" -f $crlfData.Count)
  $null = Exit-SvcIsolation; Remove-Item $snap -Recurse -Force -ErrorAction SilentlyContinue; exit 5
}
foreach ($d in @('build\qa\apk_head', 'build\android', 'build\release')) {
  $src = Join-Path $Root $d
  if (Test-Path $src) {
    New-Item -ItemType Directory -Force (Join-Path $snap $d) | Out-Null
    Get-ChildItem $src -Filter *.apk -File | Copy-Item -Destination (Join-Path $snap $d)
    Get-ChildItem $src -Filter *.aab -File -ErrorAction SilentlyContinue | Copy-Item -Destination (Join-Path $snap $d)
  }
}
& $G --headless --path $snap --import *> (Join-Path $snap 'svc06_import.log')
Write-Output ("snapshot {0} ({1}) at {2}; import exit {3}" -f $sha, $Ref, $snap, $LASTEXITCODE)
$suites = @('test_services', 'test_services_m2', 'test_services_m3', 'test_services_listing', 'test_services_m8', 'test_services_m10', 'test_services_android', 'test_services_upgrade', 'test_services_integration')
$worst = 0
try {
foreach ($s in $suites) {
  $out = & $G --headless --path $snap -s "res://tests/services/$s.gd" 2>&1 | ForEach-Object { "$_" -replace '\x1b\[[0-9;]*m', '' }
  $code = $LASTEXITCODE
  $summary = ($out | Select-String -Pattern '^\[test_services' | Select-Object -Last 1).Line
  Write-Output ("{0,-28} exit={1}  {2}" -f $s, $code, $summary)
  $out | Select-String -Pattern '^FAIL \[|BLOCKED:|launcher_label:|NOT_RUN' | ForEach-Object { Write-Output "    $($_.Line.Trim())" }
  if ($code -eq 1 -or ($code -ne 0 -and $code -ne 2)) { $worst = 1 }
  elseif ($code -eq 2 -and $worst -eq 0) { $worst = 2 }
}
} finally {
  $isolated = Exit-SvcIsolation
}
if (-not $isolated) { Write-Output 'ISOLATION NOT PROVEN: treating the run as FAIL'; $worst = 1 }
Write-Output ("OVERALL exit={0} ({1}) on {2}" -f $worst, @('PASS_INTEGRATED', 'FAIL', 'BLOCKED_NOT_INTEGRATED')[$worst], $sha)
if (-not $Keep) { Remove-Item $snap -Recurse -Force -ErrorAction SilentlyContinue }
exit $worst
