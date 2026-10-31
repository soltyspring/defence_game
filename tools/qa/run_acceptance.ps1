# 07-qa acceptance runner. Owner: 07-qa.
# Usage (workspace root):  .\tools\qa\run_acceptance.ps1 [-Only data,assets,sim,save,faults,flow,release,services] [-WaitSeconds 180]
# Output (git-ignored):    build/qa07/<timestamp>/acceptance_report.{json,md}, godot.log, env.txt
# Exit code: 0 = no FAIL, 1 = FAIL present, 2 = watchdog/crash, 3 = engine busy (import/editor) or missing.
# Coordination: never runs --import or the editor. Waits while a Godot import/editor/export is running
# or while build/.godot-import.lock is held by 02/04 (see coordination/requests/07-qa-to-02-engine.md).
# -Head: run against a clean `git archive HEAD` snapshot in %TEMP%\qa07_head (own .godot import) so other
#        workers' uncommitted WIP cannot contaminate results. Current tests/acceptance/** files are overlaid.
param([string[]]$Only = @(), [int]$WaitSeconds = 180, [switch]$Head)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $Godot)) { Write-Error "Godot console not found: $Godot"; exit 3 }

function Test-EngineBusy {
    $busy = @()
    try {
        $procs = Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" -ErrorAction Stop
        foreach ($p in $procs) {
            $cl = [string]$p.CommandLine
            $other = ($cl -match '--path\s+"?[A-Za-z]:\\') -and ($cl.IndexOf($Root, [StringComparison]::OrdinalIgnoreCase) -lt 0)
            if (-not $other -and $cl -match '(--import|\s-e(\s|$)|--editor|--export-(debug|release|pack))') { $busy += "pid $($p.ProcessId): $cl" }
        }
    } catch { }
    $lockPath = Join-Path $Root 'build\.godot-import.lock'
    if (Test-Path $lockPath) {
        try { $fs = [IO.File]::Open($lockPath, 'Open', 'Read', 'None'); $fs.Dispose() }
        catch { $busy += "build/.godot-import.lock held" }
    }
    return $busy
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ($true) {
    $busy = @(Test-EngineBusy)
    if ($busy.Count -eq 0) { break }
    if ((Get-Date) -gt $deadline) { Write-Host "ENGINE BUSY, not running acceptance:"; $busy | ForEach-Object { Write-Host "  $_" }; exit 3 }
    Write-Host "waiting for engine import/editor/export to finish..."; Start-Sleep -Seconds 5
}

$base = Join-Path $Root 'build\qa07'
New-Item -ItemType Directory -Force $base | Out-Null
$lock = $null
try { $lock = [IO.File]::Open((Join-Path $base '.run.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch { Write-Host 'another 07-qa acceptance run is in progress'; exit 3 }
try {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $out = Join-Path $base $stamp
    New-Item -ItemType Directory -Force $out | Out-Null
    $ErrorActionPreference = 'Continue'   # git/adb write progress to stderr
    $git = (& git rev-parse --short HEAD 2>$null)
    $dirty = (& git status --porcelain 2>$null | Measure-Object).Count
    $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    $devices = if (Test-Path $adb) { (& $adb devices 2>&1 | Out-String).Trim() } else { 'adb not found' }
    @("timestamp=$stamp", "git_head=$git", "dirty_paths=$dirty", "godot=$(& $Godot --version 2>$null)", "adb_devices:", $devices) | Set-Content (Join-Path $out 'env.txt') -Encoding utf8
    $proj = '.'
    if ($Head) {
        $proj = Join-Path $env:TEMP 'qa07_head'
        if (Test-Path $proj) { Remove-Item -Recurse -Force $proj }
        New-Item -ItemType Directory -Force $proj | Out-Null
        & git archive --format=zip -o "$proj.zip" HEAD
        Expand-Archive "$proj.zip" $proj -Force; Remove-Item "$proj.zip"
        Copy-Item (Join-Path $Root 'tests\acceptance\*.gd') (Join-Path $proj 'tests\acceptance') -Force
        & $Godot --headless --path $proj --import 2>&1 | Out-Null
        Add-Content -Path (Join-Path $out 'env.txt') -Value "mode=HEAD snapshot $git (workspace WIP excluded; tests overlaid from workspace)"
    } else { Add-Content -Path (Join-Path $out 'env.txt') -Value 'mode=workspace (includes uncommitted WIP of all workers)' }
    $gargs = @('--headless', '--path', $proj, '-s', 'res://tests/acceptance/acceptance.gd', '--', "--qa-out=$($out.Replace('\','/'))")
    if ($Only.Count -gt 0) { $gargs += "--only=$($Only -join ',')" }
    $prev = 'Stop'
    $log = & $Godot @gargs 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    Set-Content -Path (Join-Path $out 'godot.log') -Value $log -Encoding utf8
    $log -split "`n" | Where-Object { $_ -match '^\[acceptance\]|FAIL|BLOCKED|NOT_IMPLEMENTED|NOT_TESTED|SCRIPT ERROR|Parse Error' } | ForEach-Object { Write-Host $_.TrimEnd() }
    $errs = ([regex]::Matches($log, 'SCRIPT ERROR')).Count
    # 06-services suites (06-services-to-07-qa Q1): separate processes, counted in the exit code
    $svc = @()
    foreach ($s in @('test_services', 'test_services_m2')) {
        if (-not (Test-Path (Join-Path $Root "tests\services\$s.gd"))) { continue }
        if ($Only.Count -gt 0 -and -not ($Only -contains 'services')) { continue }
        $ErrorActionPreference = 'Continue'
        $slog = & $Godot --headless --path $proj -s "res://tests/services/$s.gd" 2>&1 | Out-String
        $scode = $LASTEXITCODE
        $ErrorActionPreference = $prev
        Set-Content -Path (Join-Path $out "$s.log") -Value $slog -Encoding utf8
        $svc += "$s exit=$scode"
        Write-Host "[services] $s exit=$scode"
        if ($scode -ne 0 -and $code -eq 0) { $code = 1 }
    }
    Add-Content -Path (Join-Path $out 'env.txt') -Value ("services: " + ($svc -join '; '))
    # Stale visual baselines: committed docs/**/*.png older than the newest commit touching the art
    # atlases, fonts or display text (e.g. the Q1 theme switch). Informational; not counted in exit code.
    $ErrorActionPreference = 'Continue'
    $base_c = (& git log -1 --format='%ct %h' -- assets/atlases assets/fonts data/text 2>$null)
    if ($base_c) {
        $bt = [long]($base_c.Split(' ')[0])
        $stale = @()
        foreach ($img in (& git ls-files 'docs/*.png' 2>$null)) {
            $ct = (& git log -1 --format='%ct' -- $img 2>$null)
            if ($ct -and [long]$ct -lt $bt) { $stale += $img }
        }
        @("baseline_commit=$($base_c.Split(' ')[1]) (newest change to assets/atlases|assets/fonts|data/text)", "stale_images=$($stale.Count)") + $stale | Set-Content (Join-Path $out 'stale_baselines.txt') -Encoding utf8
        Write-Host "[baselines] $($stale.Count) committed docs images predate visual baseline $($base_c.Split(' ')[1])"
    }
    $ErrorActionPreference = $prev
    Write-Host "script_errors_in_log=$errs  exit=$code  report=$out"
    Set-Content -Path (Join-Path $base 'latest.txt') -Value $out -Encoding utf8
    exit $code
} finally { if ($lock) { $lock.Dispose() } }
