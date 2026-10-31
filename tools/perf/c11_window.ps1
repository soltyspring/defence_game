# C11 quiet-window runner (owner: 08-performance). Never stops, pauses or touches any other process.
# Checks the number of foreign Godot/emulator processes at fixed times (default every 5 min from -Start to -End). At the first check
# with 0 foreign processes, it runs in order:
#   (a) A/B of 02's target search: ab_retest.ps1 -BaseRev <linear blob> -FixRev HEAD -Files src/gameplay/battle_sim.gd -Pairs 3 -RequireQuiet
#   (b) frame probe on a clean git-archive snapshot of HEAD: r06 autoplay + stress, sim_trace verdict (STEPPING?)
#   (c) frame probe view A/B (uncapped) and UI A/B on the same snapshot (H1/H2/H15)
#   (d) targeting_equivalence.gd on the same snapshot
# Every run is monitored once per second; any foreign Godot/emulator process seen during a run labels that run CONTAMINATED.
# If no check finds 0 processes by -End, nothing is run and the log says NOT_RUN.
# Output: build/perf/c11_<stamp>/ (git-ignored): checks.json, runs.json, summary.md, per-run logs/json.
param(
    [string]$Start = '17:00', [string]$End = '17:25', [int]$EveryMin = 5,
    [string]$LinearBlob = 'd4d7c13', [int]$Pairs = 3, [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\c11_$stamp"
New-Item -ItemType Directory -Force $Out | Out-Null
function Log([string]$m) { $l = "[c11 $(Get-Date -Format 'HH:mm:ss')] $m"; Write-Host $l; Add-Content -LiteralPath (Join-Path $Out 'c11.log') -Value $l -Encoding utf8 }
function Get-Foreign([int[]]$own) {
    @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -like 'Godot*' -or $_.Name -like 'qemu-system*' -or $_.Name -like 'emulator*') -and ($own -notcontains [int]$_.ProcessId)
    } | ForEach-Object { [ordered]@{ pid = [int]$_.ProcessId; cmd = $(if ($_.CommandLine) { $_.CommandLine.Substring(0, [math]::Min(150, $_.CommandLine.Length)) } else { '' }) } })
}

# ---- 1. scheduled checks ----
$today = Get-Date -Format 'yyyy-MM-dd'
$t = [datetime]::Parse("$today $Start"); $tEnd = [datetime]::Parse("$today $End")
$checks = @(); $go = $false
while ($t -le $tEnd) {
    $wait = ($t - (Get-Date)).TotalSeconds
    if ($wait -gt 0) { Start-Sleep -Seconds ([int][math]::Ceiling($wait)) }
    $f = Get-Foreign @()
    $checks += [ordered]@{ planned = $t.ToString('HH:mm'); at = (Get-Date).ToString('HH:mm:ss'); foreign = $f.Count; cmds = @($f | ForEach-Object { $_.cmd }) }
    Log "check $($t.ToString('HH:mm')): foreign Godot/emulator processes = $($f.Count)"
    if ($f.Count -eq 0) { $go = $true; break }
    $t = $t.AddMinutes($EveryMin)
}
$checks | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'checks.json') -Encoding utf8
if (-not $go) {
    Log "NOT_RUN: no check between $Start and $End found 0 foreign processes"
    @("# C11 ${stamp}: NOT_RUN", "No scheduled check between $Start and $End KST had 0 foreign Godot/emulator processes.", '',
      '| planned | at | foreign |', '|---|---|---|') + ($checks | ForEach-Object { "| $($_.planned) | $($_.at) | $($_.foreign) |" }) | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
    exit 3
}
if ($DryRun) { Log 'DryRun: quiet moment found, not running'; exit 0 }

# ---- 2. runs ----
$runs = @()
function Invoke-Monitored([string]$Name, [string[]]$ArgList, [switch]$Visible) {
    $so = Join-Path $Out "$Name.log"; $se = Join-Path $Out "$Name.err.log"
    $t0 = Get-Date
    $p = Start-Process -FilePath $Godot -ArgumentList $ArgList -RedirectStandardOutput $so -RedirectStandardError $se -PassThru -WindowStyle Hidden
    $null = $p.Handle; $seen = @{}
    while (-not $p.HasExited) {
        $own = @($p.Id) + @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.ProcessId })
        foreach ($f in (Get-Foreign $own)) { if (-not $seen.ContainsKey($f.pid)) { $seen[$f.pid] = [ordered]@{ pid = $f.pid; cmd = $f.cmd; first_seen_s = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1) } } }
        Start-Sleep -Milliseconds 1000
    }
    $p.WaitForExit()
    $state = if ($seen.Count -gt 0) { 'CONTAMINATED' } else { 'CLEAN' }
    $r = [ordered]@{ name = $Name; start = $t0.ToString('HH:mm:ss'); end = (Get-Date).ToString('HH:mm:ss'); exit = $p.ExitCode; state = $state; foreign_seen = @($seen.Values) }
    Log "$Name exit=$($p.ExitCode) $state foreign_seen=$($seen.Count)"
    return $r
}

# (a) A/B (ab_retest has its own per-second monitor and -RequireQuiet)
Log '(a) A/B target search start'
$abLog = Join-Path $Out 'a_ab_retest.log'
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& (Join-Path $Root 'tools\perf\ab_retest.ps1') -BaseRev $LinearBlob -FixRev HEAD -Files src/gameplay/battle_sim.gd -Pairs $Pairs -RequireQuiet -QuietWaitSec 120 *> $abLog
$abExit = $LASTEXITCODE; $ErrorActionPreference = $prev
$abDir = (Get-Content $abLog | Select-String '\[ab\] output (.+)$' | Select-Object -Last 1)
$runs += [ordered]@{ name = 'a_ab_retest'; exit = $abExit; output = $(if ($abDir) { $abDir.Matches[0].Groups[1].Value.Trim() } else { '' }) }
Log "(a) A/B exit=$abExit output=$($runs[-1].output)"

# snapshot for (b)-(d): clean HEAD tree + current 08 probes + import cache copy
$sha = (& git rev-parse --short HEAD).Trim()
$snap = Join-Path $Out "snap_$sha"
New-Item -ItemType Directory -Force $snap | Out-Null
$paths = @('project.godot', 'icon.svg', 'src', 'scenes', 'data', 'assets') | Where-Object { & git cat-file -e "HEAD:$_" 2>$null; $LASTEXITCODE -eq 0 }
& git archive --format=tar -o "$snap.tar" HEAD $paths; & tar -xf "$snap.tar" -C $snap
New-Item -ItemType Directory -Force (Join-Path $snap 'tests\performance') | Out-Null
Copy-Item (Join-Path $Root 'tests\performance\perf_frame_probe.gd'), (Join-Path $Root 'tests\performance\targeting_equivalence.gd') (Join-Path $snap 'tests\performance\')
New-Item -ItemType Directory -Force (Join-Path $snap '.godot') | Out-Null
Copy-Item (Join-Path $Root '.godot\imported') (Join-Path $snap '.godot\') -Recurse
Copy-Item (Join-Path $Root '.godot\global_script_class_cache.cfg'), (Join-Path $Root '.godot\uid_cache.bin') (Join-Path $snap '.godot\')
Log "snapshot $snap (HEAD $sha)"

Add-Type -AssemblyName System.Windows.Forms
$scr = @([System.Windows.Forms.Screen]::AllScreens); $sec = $scr | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $sec) { Log 'BLOCKED_NO_SECONDARY_MONITOR: (b)/(c) skipped'; $idx = -1 } else { $idx = [array]::IndexOf($scr, $sec) }
$probe = @('--path', $snap, '-s', 'res://tests/performance/perf_frame_probe.gd', '--', '--autoplay', '--round=r06', '--perf-stress', '--perf-contended=0')
if ($idx -ge 0) {
    $runs += Invoke-Monitored 'b_stepping' (@('--screen', "$idx", '--resolution', '1280x720') + $probe + @('--perf-seconds=12', '--perf-warmup=4', "--perf-out=$Out\b_stepping.json"))
    $runs += Invoke-Monitored 'c_view_ab' (@('--screen', "$idx", '--resolution', '1280x720') + $probe + @('--perf-seconds=20', '--perf-warmup=30', '--perf-uncapped', '--perf-ab-view', "--perf-out=$Out\c_view_ab.json"))
    $runs += Invoke-Monitored 'c_ui_ab' (@('--screen', "$idx", '--resolution', '1280x720') + $probe + @('--perf-seconds=20', '--perf-warmup=30', '--perf-uncapped', '--perf-ab-ui', "--perf-out=$Out\c_ui_ab.json"))
}
$runs += Invoke-Monitored 'd_equivalence' @('--headless', '--path', $snap, '-s', 'res://tests/performance/targeting_equivalence.gd', '--', "--out=$Out\d_equivalence.json")
$runs | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Out 'runs.json') -Encoding utf8

# ---- 3. summary (no verdicts on performance targets; just facts + validity) ----
$s = @("# C11 $stamp (HEAD $sha)", "Started at the check $($checks[-1].planned) ($($checks[-1].at)) with 0 foreign processes.", '')
if ($runs[0].output -and (Test-Path (Join-Path $runs[0].output 'ab_summary.md'))) { $s += Get-Content (Join-Path $runs[0].output 'ab_summary.md') }
foreach ($n in 'b_stepping', 'c_view_ab', 'c_ui_ab') {
    $p = Join-Path $Out "$n.json"
    if (Test-Path $p) {
        $j = Get-Content $p -Raw | ConvertFrom-Json; $r = $runs | Where-Object { $_.name -eq $n }
        $s += ''; $s += "## $n ($($r.state), exit $($r.exit))"
        $s += "sim_trace verdict=$($j.sim_trace.verdict) steps=$($j.sim_trace.steps_total) paused_frames=$($j.sim_trace.frames_paused); stress_reach ally $($j.stress_reach.ally_max)/enemy $($j.stress_reach.enemy_max)"
        $s += "frame ms p50/p95: $($j.frame_ms.p50)/$($j.frame_ms.p95); draw calls p95 $($j.draw_calls.p95); battle loop p50 $($j.battle_loop_ms.p50)"
        if ($j.ab.target) { $s += "A/B $($j.ab.target): frame avg shown $($j.ab.frame_ms_shown.avg) ms vs hidden $($j.ab.frame_ms_hidden.avg) ms" }
    }
}
$d = Join-Path $Out 'd_equivalence.json'
if (Test-Path $d) { $j = Get-Content $d -Raw | ConvertFrom-Json; $r = $runs | Where-Object { $_.name -eq 'd_equivalence' }; $s += ''; $s += "## d_equivalence ($($r.state)): verdict=$($j.verdict) diverged=$($j.diverged_runs)/$($j.runs) winner_changed=$($j.winner_changed_runs)" }
$s | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
Log "done: $Out"
exit 0
