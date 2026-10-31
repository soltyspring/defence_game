# Repeats tests/ui/test_ui.gd on a git-archive snapshot of one SHA to find non-deterministic failures.
# Owner: 04-client. Headless only. Logs every run to build/qa/flake/<sha>/run_<n>_<mode>.log and prints
# a summary of FAIL lines by frequency.
# Usage: .\tools\build\flake_probe.ps1 -Sha 1215516 -Runs 5 [-Parallel 3]
#   -Parallel N: additionally starts N runs AT THE SAME TIME (tests shared user:// / CPU contention).
param([string]$Sha = 'HEAD', [int]$Runs = 5, [int]$Parallel = 0, [string]$Suite = 'res://tests/ui/test_ui.gd')
. "$PSScriptRoot\common.ps1"
Set-Location $Root
$full = (& git rev-parse --short $Sha).Trim()
$snap = Join-Path $env:TEMP "ui04_flake_$full"
New-Item -ItemType Directory -Force $snap | Out-Null
$isoDir = Join-Path $snap ("appdata_{0}" -f $PID)   # user:// isolation (10 v0.26); runs keep per-process paths inside it
$prevAppData = Enter-IsolatedAppData $isoDir
$isoStart = Get-Date
if (-not (Test-Path (Join-Path $snap 'project.godot'))) {
    New-Item -ItemType Directory -Force $snap | Out-Null
    & git archive --format=zip -o "$snap.zip" $Sha
    Expand-Archive "$snap.zip" $snap -Force; Remove-Item "$snap.zip"
    $ErrorActionPreference = 'Continue'
    & $GodotConsole --headless --path $snap --import *> $null
}
$logDir = Join-Path $Root "build\qa\flake\$full"; New-Item -ItemType Directory -Force $logDir | Out-Null
$ErrorActionPreference = 'Continue'
$results = @()
for ($i = 1; $i -le $Runs; $i++) {
    $log = Join-Path $logDir ("run_{0:00}_seq.log" -f $i)
    & $GodotConsole --headless --path $snap -s $Suite *> $log
    $results += [pscustomobject]@{ run = "seq$i"; exit = $LASTEXITCODE; log = $log }
}
if ($Parallel -gt 0) {
    $procs = @()
    for ($j = 1; $j -le $Parallel; $j++) {
        $log = Join-Path $logDir ("run_{0:00}_par.log" -f $j)
        $procs += [pscustomobject]@{ p = (Start-Process -FilePath $GodotConsole -ArgumentList @('--headless', '--path', "`"$snap`"", '-s', $Suite, '--log-file', "`"$log`"") -PassThru -WindowStyle Hidden); log = $log; run = "par$j" }
    }
    foreach ($x in $procs) { $x.p.WaitForExit(); $results += [pscustomobject]@{ run = $x.run; exit = $x.p.ExitCode; log = $x.log } }
}
Exit-IsolatedAppData $prevAppData
$proof = Get-IsolationProof $isoDir $isoStart
Write-Host ("user:// isolated={0} own_logs={1} ({2})" -f $proof.isolated, $proof.own_logs, $isoDir)
$fails = @{}
foreach ($r in $results) {
    $txt = if (Test-Path $r.log) { Get-Content $r.log -Raw } else { '' }
    $m = [regex]::Match($txt, '\[test_ui\] passed=(\d+) failed=(\d+)')
    $r | Add-Member summary ($(if ($m.Success) { "passed=$($m.Groups[1].Value) failed=$($m.Groups[2].Value)" } else { 'no summary' }))
    foreach ($l in ($txt -split "`n" | Where-Object { $_ -match '^FAIL: ' })) { $k = $l.Trim(); $fails[$k] = 1 + [int]$fails[$k] }
}
$results | Format-Table run, exit, summary -AutoSize | Out-String | Write-Host
if ($fails.Count -gt 0) { Write-Host 'FAIL lines (count):'; $fails.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 30 | ForEach-Object { Write-Host ("  {0}x {1}" -f $_.Value, $_.Key) } }
else { Write-Host 'no FAIL lines in any run' }
