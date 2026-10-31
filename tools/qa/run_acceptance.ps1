# 07-qa acceptance runner. Owner: 07-qa.
# Usage (workspace root):  .\tools\qa\run_acceptance.ps1 [-Only data,assets,sim,save,faults,flow,release,services] [-WaitSeconds 180]
# Output (git-ignored):    build/qa07/<timestamp>/acceptance_report.{json,md}, godot.log, env.txt
# Exit code: 0 = no FAIL, 1 = FAIL present, 2 = watchdog/crash, 3 = engine busy (import/editor), missing,
#            incomplete snapshot import, or user:// isolation not proven.
# Coordination: never runs --import or the editor. Waits while a Godot import/editor/export is running
# or while build/.godot-import.lock is held by 02/04 (see coordination/requests/07-qa-to-02-engine.md).
# -Head: run against a clean `git archive HEAD` snapshot in %TEMP%\qa07_head (own .godot import) so other
#        workers' uncommitted WIP cannot contaminate results. Current tests/acceptance/** files are overlaid.
# user:// isolation (10 v0.26/v0.28): Godot 4.7.2 on Windows builds user:// from %APPDATA% + config/name, so every
#        Godot child here gets a PRIVATE APPDATA = build/qa07/<timestamp>/appdata. Proof = this run's own Godot log
#        under that folder; without it the run exits 3. env.txt also records whether the REAL qa07 folder changed.
# Retention: after the run, files > 1 MiB under the private APPDATA (TP-13's 50 MiB save and its quarantine copy)
#        are deleted and listed in env.txt; small files (saves, reports, logs) stay with the run as evidence.
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
$RealAppData = $env:APPDATA
try {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $out = Join-Path $base $stamp
    New-Item -ItemType Directory -Force $out | Out-Null
    $Iso = Join-Path $out 'appdata'
    New-Item -ItemType Directory -Force $Iso | Out-Null
    # Every Godot process of this run sees only the private APPDATA; git and adb keep the normal profile.
    function Invoke-IsoGodot([string[]]$GArgs) {
        $env:APPDATA = $Iso
        try { return (& $Godot @GArgs 2>&1 | Out-String) } finally { $env:APPDATA = $RealAppData }
    }
    $ErrorActionPreference = 'Continue'   # git/adb write progress to stderr
    $git = (& git rev-parse --short HEAD 2>$null)
    $dirty = (& git status --porcelain 2>$null | Measure-Object).Count
    $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    # `adb devices` starts the adb daemon when none runs; the daemon inherits our output pipe and a piped caller
    # then waits forever (02 report 20:25). Query only an already running server.
    $devices = if (-not (Test-Path $adb)) { 'adb not found' }
        elseif (@(Get-Process -Name adb -ErrorAction SilentlyContinue).Count -eq 0) { 'adb server not running; not started by this runner' }
        else { (& $adb devices 2>&1 | Out-String).Trim() }
    $realUser = Join-Path $RealAppData 'Godot\app_userdata\Lane Defence'
    function Get-RealState {
        $q = @(Get-ChildItem (Join-Path $realUser 'qa07') -Recurse -File -ErrorAction SilentlyContinue)
        $nw = $q | Sort-Object LastWriteTime | Select-Object -Last 1
        $h = foreach ($f in 'save.json', 'save.json.bak') { $p = Join-Path $realUser $f; if (Test-Path $p) { (Get-FileHash $p).Hash.Substring(0, 16) } else { '-' } }
        [pscustomobject]@{ qa07 = "$($q.Count) files, newest $(if ($nw) { $nw.LastWriteTime.ToString('s') } else { '-' })"; save = ($h -join '/') }
    }
    $real0 = Get-RealState
    $t0 = Get-Date
    @("timestamp=$stamp", "git_head=$git", "dirty_paths=$dirty", "godot=$((Invoke-IsoGodot @('--version')).Trim())", "user_appdata_private=$Iso", "adb_devices:", $devices) | Set-Content (Join-Path $out 'env.txt') -Encoding utf8
    $proj = '.'
    if ($Head) {
        $proj = Join-Path $env:TEMP 'qa07_head'
        if (Test-Path $proj) { Remove-Item -Recurse -Force $proj }
        New-Item -ItemType Directory -Force $proj | Out-Null
        & git archive --format=zip -o "$proj.zip" HEAD
        Expand-Archive "$proj.zip" $proj -Force; Remove-Item "$proj.zip"
        Copy-Item (Join-Path $Root 'tests\acceptance\*.gd') (Join-Path $proj 'tests\acceptance') -Force
        Invoke-IsoGodot @('--headless', '--path', $proj, '--import') | Out-Null
        # import guard: every .import must have its imported file, else re-import once, else refuse to run
        for ($pass = 1; $pass -le 3; $pass++) {
            $missing = @()
            foreach ($imp in Get-ChildItem $proj -Recurse -Filter '*.import' -File | ? { $_.FullName -notmatch '\\\.godot\\' }) {
                foreach ($m in Select-String -Path $imp.FullName -Pattern '^path(\.[a-z0-9_]+)?="res://(\.godot/imported/[^"]+)"') {
                    if (-not (Test-Path (Join-Path $proj $m.Matches[0].Groups[2].Value))) { $missing += $m.Matches[0].Groups[2].Value }
                }
            }
            if ($missing.Count -eq 0) { break }
            Write-Host "import incomplete (pass $pass): $($missing.Count) imported files missing; re-importing"
            Invoke-IsoGodot @('--headless', '--path', $proj, '--import') | Out-Null
        }
        Add-Content -Path (Join-Path $out 'env.txt') -Value "import_missing_after_guard=$($missing.Count)"
        if ($missing.Count -gt 0) { Write-Host "SNAPSHOT IMPORT INCOMPLETE: $($missing.Count) missing; not running (results would use fallbacks)"; exit 3 }
        Add-Content -Path (Join-Path $out 'env.txt') -Value "mode=HEAD snapshot $git (workspace WIP excluded; tests overlaid from workspace)"
    } else { Add-Content -Path (Join-Path $out 'env.txt') -Value 'mode=workspace (includes uncommitted WIP of all workers)' }
    $gargs = @('--headless', '--path', $proj, '-s', 'res://tests/acceptance/acceptance.gd', '--', "--qa-out=$($out.Replace('\','/'))")
    if ($Only.Count -gt 0) { $gargs += "--only=$($Only -join ',')" }
    $prev = 'Stop'
    $log = Invoke-IsoGodot $gargs
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
        $slog = Invoke-IsoGodot @('--headless', '--path', $proj, '-s', "res://tests/services/$s.gd")
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
    # user:// isolation proof and retention (see header)
    $pname = 'Lane Defence'
    $cfg = Select-String -Path (Join-Path $proj 'project.godot') -Pattern '^config/name="(.*)"' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cfg) { $pname = $cfg.Matches[0].Groups[1].Value }
    $ownLogs = @(Get-ChildItem (Join-Path $Iso "Godot\app_userdata\$pname\logs") -Filter 'godot*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $t0 }).Count
    $realLogs = @(Get-ChildItem (Join-Path $realUser 'logs') -Filter 'godot*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $t0 }).Count
    $real1 = Get-RealState
    $big = @(Get-ChildItem $Iso -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 1MB })
    $bigBytes = ($big | Measure-Object Length -Sum).Sum
    $envLines = @(
        "isolation_own_logs=$ownLogs (godot*.log under the private user dir since start; 0 = not proven)",
        "real_qa07_before=$($real0.qa07)", "real_qa07_after=$($real1.qa07)",
        "real_save_hashes_before_after=$($real0.save) -> $($real1.save) (any process may write these)",
        "real_new_logs_any_process=$realLogs",
        "pruned_private_files_over_1MiB=$($big.Count) bytes=$([long]$bigBytes)") + @($big | ForEach-Object { "  pruned $($_.FullName.Substring($Iso.Length)) $($_.Length)" })
    Add-Content -Path (Join-Path $out 'env.txt') -Value $envLines
    $big | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    Write-Host ("[isolation] private user dir={0} own_logs={1} real_qa07_changed={2} pruned={3} files ({4:N0} B)" -f $Iso, $ownLogs, ($real0.qa07 -ne $real1.qa07), $big.Count, [long]$bigBytes)
    if ($ownLogs -eq 0) { Write-Host 'ISOLATION NOT PROVEN (no Godot log under the private APPDATA): results not trusted'; $code = 3 }
    Write-Host "script_errors_in_log=$errs  exit=$code  report=$out"
    Set-Content -Path (Join-Path $base 'latest.txt') -Value $out -Encoding utf8
    exit $code
} finally { $env:APPDATA = $RealAppData; if ($lock) { $lock.Dispose() } }
