# C11 quiet-window runner (owner: 08-performance). Never stops, pauses or touches any other process.
# Checks the number of foreign Godot/emulator processes at fixed times (default every 5 min from -Start to -End). At the first check
# with 0 foreign processes, it runs in order:
#   (a) A/B of 02's target search: ab_retest.ps1 -BaseRev <linear blob> -FixRev HEAD -Files src/gameplay/battle_sim.gd -Pairs 3 -RequireQuiet
#   (b) frame probe on a clean git-archive snapshot of HEAD: r06 autoplay + stress, sim_trace verdict (STEPPING?)
#   (c) frame probe view A/B (uncapped) and UI A/B on the same snapshot (H1/H2/H15)
#   (c2) UI A/B on a snapshot of -UiBeforeRev (before 04's 1d1e4e3) for comparison
#   (d) battle-start cost: perf_bench.gd --only=setup on the HEAD snapshot (+ battle_start frames from b)
#   (e) first wave-cleared banner frames: r01 plain autoplay (no stress) on the HEAD snapshot
#   (f) targeting_equivalence.gd on the HEAD snapshot, only if time remains
# Every run is monitored once per second; any foreign Godot/emulator process seen during a run labels that run CONTAMINATED.
# If no check finds 0 processes by -End, nothing is run and the log says NOT_RUN.
# Output: build/perf/c11_<stamp>/ (git-ignored): checks.json, runs.json, summary.md, per-run logs/json.
param(
    [string]$Start = '17:00', [string]$End = '17:25', [int]$EveryMin = 5,
    [string]$LinearBlob = 'd4d7c13', [int]$Pairs = 3, [switch]$DryRun,
    [string]$Deadline = '18:30',          # no new step starts after this time; unstarted steps are recorded NOT_RUN
    [string]$UiBeforeRev = '1d1e4e3~1'    # 04 redraw-on-change fix 1d1e4e3: UI A/B before vs HEAD
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\c11_$stamp"
New-Item -ItemType Directory -Force $Out | Out-Null
. (Join-Path $PSScriptRoot 'perf_isolation.ps1')
# Inside the machine-wide lock no other heavy run starts, so use -Start/-End = now (do not hold the lock while waiting for a slot).
if (-not $DryRun) { Assert-HeavyRun 'c11_window.ps1' }
$PerfAppData = New-PerfAppData $Root 'c11_window'   # private user:// (10 v0.26 P1)
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
    Enter-PerfAppData $PerfAppData
    try { $p = Start-Process -FilePath $Godot -ArgumentList $ArgList -RedirectStandardOutput $so -RedirectStandardError $se -PassThru -WindowStyle Hidden } finally { Exit-PerfAppData }
    $null = $p.Handle; $seen = @{}
    while (-not $p.HasExited) {
        $own = @($p.Id) + @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.ProcessId })
        foreach ($f in (Get-Foreign $own)) { if (-not $seen.ContainsKey($f.pid)) { $seen[$f.pid] = [ordered]@{ pid = $f.pid; cmd = $f.cmd; first_seen_s = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1) } } }
        Start-Sleep -Milliseconds 1000
    }
    $p.WaitForExit()
    $state = if ($seen.Count -gt 0) { 'CONTAMINATED' } else { 'CLEAN' }
    $r = [ordered]@{ name = $Name; start = $t0.ToString('HH:mm:ss'); end = (Get-Date).ToString('HH:mm:ss'); exit = $p.ExitCode; state = $state; foreign_seen = @($seen.Values); isolation_proof_log = (Test-PerfIsolation $PerfAppData $t0) }
    Log "$Name exit=$($p.ExitCode) $state foreign_seen=$($seen.Count)"
    return $r
}

$dl = [datetime]::Parse("$today $Deadline")
function Time-Left([string]$step) { if ((Get-Date) -gt $dl) { Log "NOT_RUN $step (deadline $Deadline passed)"; $script:runs += [ordered]@{ name = $step; state = 'NOT_RUN'; reason = "deadline $Deadline" }; return $false }; return $true }
function New-Snap([string]$rev, [string]$label) {
    $sha = (& git rev-parse --short $rev).Trim()
    $snap = Join-Path $Out "snap_${label}_$sha"
    New-Item -ItemType Directory -Force $snap | Out-Null
    $paths = @('project.godot', 'icon.svg', 'src', 'scenes', 'data', 'assets') | Where-Object { & git cat-file -e "${sha}:$_" 2>$null; $LASTEXITCODE -eq 0 }
    & git archive --format=tar -o "$snap.tar" $sha $paths; & tar -xf "$snap.tar" -C $snap
    New-Item -ItemType Directory -Force (Join-Path $snap 'tests\performance') | Out-Null
    foreach ($f in 'perf_frame_probe.gd', 'perf_bench.gd', 'targeting_equivalence.gd') { Copy-Item (Join-Path $Root "tests\performance\$f") (Join-Path $snap 'tests\performance\') }
    New-Item -ItemType Directory -Force (Join-Path $snap '.godot') | Out-Null
    Copy-Item (Join-Path $Root '.godot\imported') (Join-Path $snap '.godot\') -Recurse
    Copy-Item (Join-Path $Root '.godot\global_script_class_cache.cfg'), (Join-Path $Root '.godot\uid_cache.bin') (Join-Path $snap '.godot\')
    Log "snapshot $label = $sha -> $snap"
    return @{ dir = $snap; sha = $sha }
}

$head = New-Snap 'HEAD' 'head'
$snap = $head.dir; $sha = $head.sha

# (0) parse check of the 08 scripts inside the snapshot (1-2 s each, monitored)
foreach ($s in 'perf_frame_probe', 'perf_bench') {
    $runs += Invoke-Monitored "0_check_$s" @('--headless', '--path', $snap, '--check-only', '-s', "res://tests/performance/$s.gd")
}

# (a) A/B (ab_retest has its own per-second monitor and -RequireQuiet)
if (Time-Left 'a_ab_retest') {
    Log '(a) A/B target search start'
    $abLog = Join-Path $Out 'a_ab_retest.log'
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & (Join-Path $Root 'tools\perf\ab_retest.ps1') -BaseRev $LinearBlob -FixRev HEAD -Files src/gameplay/battle_sim.gd -Pairs $Pairs -RequireQuiet -QuietWaitSec 120 *> $abLog
    $abExit = $LASTEXITCODE; $ErrorActionPreference = $prev
    $abDir = (Get-Content $abLog | Select-String '\[ab\] output (.+)$' | Select-Object -Last 1)
    $runs += [ordered]@{ name = 'a_ab_retest'; exit = $abExit; output = $(if ($abDir) { $abDir.Matches[0].Groups[1].Value.Trim() } else { '' }) }
    Log "(a) A/B exit=$abExit output=$($runs[-1].output)"
}

Add-Type -AssemblyName System.Windows.Forms
$scr = @([System.Windows.Forms.Screen]::AllScreens); $sec = $scr | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $sec) { Log 'BLOCKED_NO_SECONDARY_MONITOR: visible steps skipped'; $idx = -1 } else { $idx = [array]::IndexOf($scr, $sec) }
$win = @('--screen', "$idx", '--resolution', '1280x720')
function Probe([string]$dir, [string[]]$extra) { @('--path', $dir, '-s', 'res://tests/performance/perf_frame_probe.gd', '--', '--perf-contended=0') + $extra }

if ($idx -ge 0) {
    if (Time-Left 'b_stepping') { $runs += Invoke-Monitored 'b_stepping' ($win + (Probe $snap @('--autoplay', '--round=r06', '--perf-stress', '--perf-seconds=12', '--perf-warmup=4', "--perf-out=$Out\b_stepping.json"))) }
    if (Time-Left 'c_view_ab') { $runs += Invoke-Monitored 'c_view_ab' ($win + (Probe $snap @('--autoplay', '--round=r06', '--perf-stress', '--perf-seconds=20', '--perf-warmup=30', '--perf-uncapped', '--perf-ab-view', "--perf-out=$Out\c_view_ab.json"))) }
    if (Time-Left 'c_ui_ab') { $runs += Invoke-Monitored 'c_ui_ab' ($win + (Probe $snap @('--autoplay', '--round=r06', '--perf-stress', '--perf-seconds=20', '--perf-warmup=30', '--perf-uncapped', '--perf-ab-ui', "--perf-out=$Out\c_ui_ab.json"))) }
    if (Time-Left 'c2_ui_ab_before') {
        $old = New-Snap $UiBeforeRev 'uibefore'
        $runs += Invoke-Monitored 'c2_ui_ab_before' ($win + (Probe $old.dir @('--autoplay', '--round=r06', '--perf-stress', '--perf-seconds=20', '--perf-warmup=30', '--perf-uncapped', '--perf-ab-ui', "--perf-out=$Out\c2_ui_ab_before.json")))
        $runs[-1].rev = $old.sha
    }
}
if (Time-Left 'd_setup') { $runs += Invoke-Monitored 'd_setup' @('--headless', '--path', $snap, '-s', 'res://tests/performance/perf_bench.gd', '--', '--only=setup', '--contended=0', "--out=$Out\d_setup.json") }
if ($idx -ge 0 -and (Time-Left 'e_banner')) { $runs += Invoke-Monitored 'e_banner' ($win + (Probe $snap @('--autoplay', '--round=r01', '--perf-seconds=45', '--perf-warmup=2', "--perf-out=$Out\e_banner.json"))) }
if (Time-Left 'f_equivalence') { $runs += Invoke-Monitored 'f_equivalence' @('--headless', '--path', $snap, '-s', 'res://tests/performance/targeting_equivalence.gd', '--', "--out=$Out\f_equivalence.json") }
$runs | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'runs.json') -Encoding utf8

# ---- 3. summary (facts + validity only; no phone claims) ----
$s = @("# C11 $stamp (HEAD $sha)", "Started at the check $($checks[-1].planned) ($($checks[-1].at)) with 0 foreign processes. Desktop debug binary; not phone evidence.", '')
$s += '| step | state | exit | foreign seen (pid: cmd) |'; $s += '|---|---|---|---|'
foreach ($r in $runs) { $s += "| $($r.name) | $($r.state) | $($r.exit) | $((@($r.foreign_seen) | ForEach-Object { "$($_.pid): $($_.cmd)" }) -join '<br>') |" }
$ab = $runs | Where-Object { $_.name -eq 'a_ab_retest' }
if ($ab -and $ab.output -and (Test-Path (Join-Path $ab.output 'ab_summary.md'))) { $s += ''; $s += Get-Content (Join-Path $ab.output 'ab_summary.md') }
foreach ($n in 'b_stepping', 'c_view_ab', 'c_ui_ab', 'c2_ui_ab_before', 'e_banner') {
    $p = Join-Path $Out "$n.json"
    if (Test-Path $p) {
        $j = Get-Content $p -Raw | ConvertFrom-Json; $r = $runs | Where-Object { $_.name -eq $n }
        $s += ''; $s += "## $n ($($r.state), exit $($r.exit))"
        $s += "sim_trace verdict=$($j.sim_trace.verdict) steps=$($j.sim_trace.steps_total) paused_frames=$($j.sim_trace.frames_paused); stress_reach ally $($j.stress_reach.ally_max) / enemy $($j.stress_reach.enemy_max)"
        $s += "frame ms p50/p95: $($j.frame_ms.p50)/$($j.frame_ms.p95); draw calls p50/p95 $($j.draw_calls.p50)/$($j.draw_calls.p95); battle loop p50 $($j.battle_loop_ms.p50)"
        if ($j.ab.target) { $s += "A/B $($j.ab.target): frame avg shown $($j.ab.frame_ms_shown.avg) ms vs hidden $($j.ab.frame_ms_hidden.avg) ms" }
        foreach ($k in 'battle_start', 'wave_cleared') { foreach ($e in @($j.event_frames.$k)) { if ($e) { $s += "$k @ $($e.probe_t) s: frames $(@($e.frames_ms) -join ', ') ms (baseline $($e.baseline_median_ms), spike +$($e.spike_over_baseline_ms))" } } }
    }
}
$dj = Join-Path $Out 'd_setup.json'
if (Test-Path $dj) { $j = Get-Content $dj -Raw | ConvertFrom-Json; $s += ''; $s += '## d_setup'; foreach ($r in $j.setup.rows) { $s += "$($r.round): setup p50 $($r.p50_ms) / max $($r.max_ms) ms, objects created $($r.objects_created_by_setup), static +$($r.static_mem_delta_bytes) B, pools $($r.pools_after_setup | ConvertTo-Json -Compress)" } }
$fj = Join-Path $Out 'f_equivalence.json'
if (Test-Path $fj) { $j = Get-Content $fj -Raw | ConvertFrom-Json; $s += ''; $s += "## f_equivalence: verdict=$($j.verdict) diverged=$($j.diverged_runs)/$($j.runs) winner_changed=$($j.winner_changed_runs)" }
$s | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
Log "done: $Out"
exit 0