# Pre-push gate for 04-client (added after the 38b4d9d regression: a test file was pushed with a parse error).
# 1. git archive HEAD into a scratch dir, 2. overlay ONLY the listed working-tree files, 3. own --import,
# 4. run tests/ui/test_ui.gd and tests/integration/test_ui_integration.gd there, with a private APPDATA (user://
#    never resolves to the real player folder; 10 v0.26) and a proof that the runs logged under it,
# 5. call coordination/Publish-Task.ps1 only if both exit 0 with passed>0 and failed=0.
# Peers' uncommitted WIP in the shared tree therefore can neither break nor mask the result.
# Usage: .\tools\build\verify_and_publish.ps1 -Type Fix -Subject '...' -Paths @('src/ui/hud.gd', ...) [-DryRun]
param(
    [Parameter(Mandatory = $true)][string]$Type,
    [Parameter(Mandatory = $true)][string]$Subject,
    [Parameter(Mandatory = $true)][string[]]$Paths,
    [switch]$DryRun
)
. "$PSScriptRoot\common.ps1"
Set-Location $Root
# Unique scratch dir per run (17:01: a fixed dir was half-deleted while another process held a file in
# it, so tests were "File not found"). Old gate dirs are removed best-effort.
Get-ChildItem $env:TEMP -Directory -Filter 'ui04_gate_*' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } | ForEach-Object { Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue }
$snap = Join-Path $env:TEMP ("ui04_gate_{0}_{1}" -f (Get-Date -Format 'HHmmss'), $PID)
New-Item -ItemType Directory $snap | Out-Null
& git -c core.autocrlf=false -c core.eol=lf archive --format=zip -o "$snap.zip" HEAD   # LF, byte-identical to the repo (06/10)
Expand-Archive "$snap.zip" $snap -Force; Remove-Item "$snap.zip"
foreach ($req in @('project.godot', 'tests\ui\test_ui.gd', 'tests\integration\test_ui_integration.gd')) {
    if (-not (Test-Path (Join-Path $snap $req))) { Write-Host "GATE FAILED: snapshot incomplete ($req missing) — environment, not a test result."; exit 2 }
}
foreach ($p in $Paths) {
    $src = Join-Path $Root $p; $dst = Join-Path $snap $p
    if (Test-Path $src) { New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null; Copy-Item $src $dst -Force }
    elseif (Test-Path $dst) { Remove-Item $dst }   # deleted in the working tree
}
$ErrorActionPreference = 'Continue'
# user:// isolation (10 v0.26/v0.28: this gate wrote the REAL save.json at 19:25:58). Private APPDATA inside the
# scratch snapshot for import + both suites; restored before Publish-Task (git must see the normal profile).
$isoDir = Join-Path $snap 'appdata'
$isoStart = Get-Date
$prevAppData = Enter-IsolatedAppData $isoDir
# Import must be COMPLETE before testing: the one unexplained 14-failure run (1215516) was reproduced
# exactly by skipping --import (fonts fall back). Verify every font/atlas import output exists; retry.
function Test-Imported([string]$dir) {
    $missing = @()
    foreach ($imp in Get-ChildItem (Join-Path $dir 'assets') -Recurse -Filter '*.import' | Where-Object { $_.Name -match '\.(ttf|png)\.import$' }) {
        $p = (Select-String -Path $imp.FullName -Pattern '^path="res://(.+)"' | Select-Object -First 1)
        if ($p) { $dest = Join-Path $dir ($p.Matches[0].Groups[1].Value -replace '/', '\'); if (-not (Test-Path $dest)) { $missing += $imp.Name } }
    }
    return $missing
}
$miss = @('not run')
for ($attempt = 1; $attempt -le 3 -and $miss.Count -gt 0; $attempt++) {
    & $GodotConsole --headless --path $snap --import *> (Join-Path $snap "import_$attempt.log")
    $miss = @(Test-Imported $snap)
    Write-Host ("gate import attempt {0}: exit={1} missing={2}" -f $attempt, $LASTEXITCODE, $miss.Count)
}
if ($miss.Count -gt 0) { Exit-IsolatedAppData $prevAppData; Write-Host "GATE FAILED: import incomplete ($($miss -join ', ')) — environment, not a test result."; exit 2 }
$ok = $true
foreach ($suite in @(@('ui', 'res://tests/ui/test_ui.gd', '\[test_ui\] passed=(\d+) failed=(\d+)'), @('integration', 'res://tests/integration/test_ui_integration.gd', '\[ui_integration\] passed=(\d+) failed=(\d+)'))) {
    $out = & $GodotConsole --headless --path $snap -s $suite[1] 2>&1 | Out-String
    $code = $LASTEXITCODE
    $logDir = Join-Path $Root 'build\qa\gate'; New-Item -ItemType Directory -Force $logDir | Out-Null
    $logPath = Join-Path $logDir ("{0}_{1}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $suite[0])
    Set-Content -Path $logPath -Value $out -Encoding utf8   # full log kept: a non-reproducible 14-failure run at 1215516 had no evidence
    $m = [regex]::Match($out, $suite[2])
    $pass = if ($m.Success) { [int]$m.Groups[1].Value } else { 0 }
    $fail = if ($m.Success) { [int]$m.Groups[2].Value } else { -1 }
    Write-Host ("gate {0}: exit={1} passed={2} failed={3}" -f $suite[0], $code, $pass, $fail)
    ($out -split "`n" | Where-Object { $_ -match '^FAIL|SCRIPT ERROR|Parse Error' } | Select-Object -Unique -First 10) | ForEach-Object { Write-Host "  $_" }
    if ($code -ne 0 -or $pass -le 0 -or $fail -ne 0) { $ok = $false }
}
Exit-IsolatedAppData $prevAppData
$proof = Get-IsolationProof $isoDir $isoStart
Write-Host ("gate user:// isolated={0} own_logs={1} (private APPDATA {2}); new logs in the real folder from any process: {3}" -f $proof.isolated, $proof.own_logs, $isoDir, $proof.real_new_logs_any_process)
if (-not $proof.isolated) { Write-Host 'GATE FAILED: no Godot log under the private APPDATA, so isolation is not proven — environment, not a test result.'; exit 2 }
if (-not $ok) { Write-Host 'GATE FAILED: nothing published.'; exit 1 }
if ($DryRun) { Write-Host 'GATE PASSED (dry run, not published).'; exit 0 }
Write-Host 'GATE PASSED: publishing.'
& (Join-Path $Root 'coordination\Publish-Task.ps1') -Role 04-client -Type $Type -Subject $Subject -Paths $Paths
exit $LASTEXITCODE
