# 08-performance desktop perf run (DESKTOP PROXY evidence only). Owner: 08-performance.
# Usage (workspace root):
#   .\tools\perf\run_perf.ps1                 # inventory + full headless CPU/memory bench (~2-3 min)
#   .\tools\perf\run_perf.ps1 -Quick          # inventory + quick bench (~30 s)
#   .\tools\perf\run_perf.ps1 -Frame          # + windowed frame probes (opens a game window ~2 min)
#   .\tools\perf\run_perf.ps1 -Strict         # exit 1 when a provisional budget check fails
#   .\tools\perf\run_perf.ps1 -Frame -SkipBench  # visible probes only (secondary monitor)
#   .\tools\perf\run_perf.ps1 -Font -SkipBench   # Galmuri glyph-cache memory + first-use hitch probe (secondary monitor)
# Output: build/perf/<timestamp>/ (git-ignored) + build/perf/latest/ copy. Never imports, never opens the editor,
# never touches the real save (bench uses user://perf/). Records concurrently running Godot processes because
# other workers' editors/builds distort timing.
param([switch]$Quick, [switch]$Frame, [switch]$Strict, [switch]$SkipBench, [switch]$Font, [int]$FontReps = 3, [string]$Round = 'r06', [int]$Seconds = 20)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $Godot)) { throw "MISSING Godot console binary: $Godot (02-engine installs it)" }
if (-not (Test-Path (Join-Path $Root '.godot'))) { throw 'Project not imported (.godot missing). This script never imports; ask 02/04 to run the import.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\$stamp"
New-Item -ItemType Directory -Force $Out | Out-Null
. (Join-Path $PSScriptRoot 'perf_isolation.ps1')
if (-not $SkipBench -or $Frame -or $Font) { Assert-HeavyRun 'run_perf.ps1' }   # machine-wide lock (coordination/heavy_run.ps1)
$PerfAppData = New-PerfAppData $Root 'run_perf'   # private user:// (10 v0.26 P1)
$t0Run = Get-Date
$sha = (& git rev-parse --short HEAD 2>$null)
$dirty = @(& git status --porcelain -- src scenes data assets project.godot 2>$null).Count
$others = @(Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Select-Object Id, ProcessName, StartTime)
$meta = [ordered]@{
    evidence_class = 'DESKTOP_PROXY'; time = (Get-Date).ToString('s'); git = $sha; dirty_runtime_files = $dirty
    machine = $env:COMPUTERNAME; cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    ram_gb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    concurrent_godot_processes = $others.Count; quick = [bool]$Quick; frame = [bool]$Frame
}
if ($others.Count -gt 0) { Write-Warning "$($others.Count) other Godot process(es) running: timings include contention." }

$fail = @()
# Visible windows only on the SECONDARY monitor (coordination/QUALITY_REVIEW.md). Detected dynamically.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Namespace PerfWin -Name Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool GetWindowRect(System.IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool IsWindowVisible(System.IntPtr h); public struct RECT { public int L; public int T; public int R; public int B; }'
$screens = @([System.Windows.Forms.Screen]::AllScreens)
$secondary = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1
# Godot --position ignores negative (left-of-primary) X on this setup (verified 2026-10-31: window landed at x=0);
# --screen <index> centres the window on that monitor. Index = order of EnumDisplayMonitors (same as Screen.AllScreens).
$secondaryIndex = if ($secondary) { [array]::IndexOf($screens, $secondary) } else { -1 }
$meta.windows = @()
function Invoke-GodotVisible([string]$Name, [string[]]$GodotArgs) {
    Write-Host "=== $Name (visible, secondary monitor) ==="
    $pos = "--screen $secondaryIndex"
    $all = @('--screen', "$secondaryIndex", '--resolution', '1280x720') + $GodotArgs + @("--perf-contended=$($others.Count)")
    $so = Join-Path $Out "$Name.log"; $se = Join-Path $Out "$Name.err.log"
    Enter-PerfAppData $PerfAppData
    try { $proc = Start-Process -FilePath $Godot -ArgumentList $all -RedirectStandardOutput $so -RedirectStandardError $se -PassThru -WindowStyle Hidden } finally { Exit-PerfAppData }
    $null = $proc.Handle
    $rect = $null; $winTitle = ''; $until = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $until -and -not $proc.HasExited) {
        # the _console.exe wrapper starts the GUI binary as a child process that owns the game window
        $cands = @($proc) + @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($proc.Id)" -ErrorAction SilentlyContinue | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue })
        foreach ($c in $cands) {
            if ($c -and $c.MainWindowHandle -ne [IntPtr]::Zero -and [PerfWin.Native]::IsWindowVisible($c.MainWindowHandle)) {
                $r = New-Object PerfWin.Native+RECT
                if ([PerfWin.Native]::GetWindowRect($c.MainWindowHandle, [ref]$r)) { $rect = $r; $winTitle = $c.MainWindowTitle }
            }
        }
        if ($rect) { break }
        Start-Sleep -Milliseconds 250
    }
    $onSecondary = $false
    if ($rect) {
        $cx = ($rect.L + $rect.R) / 2; $cy = ($rect.T + $rect.B) / 2
        $b = $secondary.Bounds
        $onSecondary = $cx -ge $b.Left -and $cx -lt $b.Right -and $cy -ge $b.Top -and $cy -lt $b.Bottom
        Write-Host "[window] $Name title='$winTitle' rect=($($rect.L),$($rect.T))-($($rect.R),$($rect.B)) on_secondary=$onSecondary monitor=$($secondary.DeviceName) $($b)"
    } else { Write-Host "[window] $Name window rect not observed" }
    $script:meta.windows += [ordered]@{ run = $Name; screen_arg = $pos; rect = $(if ($rect) { "$($rect.L),$($rect.T),$($rect.R),$($rect.B)" } else { '' }); on_secondary = $onSecondary; monitor = $secondary.DeviceName; monitor_bounds = "$($secondary.Bounds)" }
    if ($rect -and -not $onSecondary) { Write-Warning "$Name window is not on the secondary monitor" }
    $proc.WaitForExit()
    $code = $proc.ExitCode
    Get-Content $so -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\[frame_probe\]|^\[font_summary\]|SCRIPT ERROR' } | ForEach-Object { Write-Host $_.TrimEnd() }
    Write-Host "=== $Name exit=$code ==="
    return $code
}
function Invoke-Godot([string]$Name, [string[]]$GodotArgs) {
    Write-Host "=== $Name ==="
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'   # Godot logs warnings to stderr
    Enter-PerfAppData $PerfAppData
    try { $log = & $Godot @GodotArgs 2>&1 | Out-String } finally { Exit-PerfAppData }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    Set-Content -Path (Join-Path $Out "$Name.log") -Value $log -Encoding utf8
    $log -split "`n" | Where-Object { $_ -match '^\[perf\]|^\[frame_probe\]|PERF_BENCH|SCRIPT ERROR' } | ForEach-Object { Write-Host $_.TrimEnd() }
    Write-Host "=== $Name exit=$code ==="
    return $code
}

Write-Host '=== inventory ==='
& python (Join-Path $Root 'tools\perf\budget_inventory.py') --out $Out
if ($LASTEXITCODE -ne 0) { $fail += 'inventory' }

$benchArgs = @('--headless', '--path', '.', '-s', 'res://tests/performance/perf_bench.gd', '--', "--out=$Out\bench.json", "--git=$sha", "--contended=$($others.Count)")
if ($Quick) { $benchArgs += '--quick' }
if ($Strict) { $benchArgs += '--strict' }
if (-not $SkipBench) { if ((Invoke-Godot 'bench' $benchArgs) -ne 0) { $fail += 'bench' } }

# Shared import/export lock (07 QA-R2): never measure while 02/04 import or export.
$lockPath = Join-Path $Root 'build\.godot-import.lock'
function Test-ImportLockHeld {
    if (-not (Test-Path $lockPath)) { return $false }
    try { $fs = [IO.File]::Open($lockPath, 'Open', 'Read', 'None'); $fs.Dispose(); return $false } catch { return $true }
}
$waited = 0
while ((Test-ImportLockHeld) -and $waited -lt 300) { if ($waited -eq 0) { Write-Host '[run_perf] build/.godot-import.lock held: waiting (max 300 s)' }; Start-Sleep -Seconds 5; $waited += 5 }
$meta.import_lock_wait_s = $waited
if (Test-ImportLockHeld) { Write-Host 'BLOCKED_IMPORT_LOCK: import/export still running after 300 s; visible probes skipped.'; $Frame = $false; $Font = $false; $meta.blocked = 'import lock' }
$meta.godot_processes_at_visible_start = @(Get-Process | Where-Object { $_.ProcessName -like 'Godot*' }).Count

if (($Frame -or $Font) -and -not $secondary) {
    Write-Host 'BLOCKED_NO_SECONDARY_MONITOR: visible frame probes skipped (user rule: visible tests on secondary monitor only).'
    $meta.frame_blocked = 'no secondary monitor'
} else {
  if ($Font) {
    if ((Invoke-GodotVisible 'font' @('--path', '.', '-s', 'res://tests/performance/perf_font_probe.gd', '--', "--font-out=$Out\font.json", "--font-reps=$FontReps")) -ne 0) { $fail += 'font' }
  }
  if ($Frame) {
    $probe = @('--path', '.', '-s', 'res://tests/performance/perf_frame_probe.gd', '--', '--autoplay', "--round=$Round")
    if ((Invoke-GodotVisible 'frame_paced' ($probe + @("--perf-seconds=$Seconds", '--perf-warmup=5', "--perf-out=$Out\frame_paced.json"))) -ne 0) { $fail += 'frame_paced' }
    if ((Invoke-GodotVisible 'frame_stress_ab_view' ($probe + @("--perf-seconds=$Seconds", '--perf-warmup=6', '--perf-stress', '--perf-uncapped', '--perf-ab-view', "--perf-out=$Out\frame_stress_ab_view.json"))) -ne 0) { $fail += 'frame_stress_ab_view' }
    if ((Invoke-GodotVisible 'frame_menu_uncapped' @('--path', '.', '-s', 'res://tests/performance/perf_frame_probe.gd', '--', '--perf-seconds=8', '--perf-warmup=3', '--perf-uncapped', "--perf-out=$Out\frame_menu_uncapped.json")) -ne 0) { $fail += 'frame_menu_uncapped' }
  }
}

# ---- summary ----
$s = @("# Perf run $stamp (DESKTOP PROXY, not phone evidence)", "git $sha, dirty runtime files: $dirty, concurrent Godot processes: $($others.Count)", '')
$bj = Join-Path $Out 'bench.json'
if (Test-Path $bj) {
    $b = Get-Content $bj -Raw | ConvertFrom-Json
    $s += "Evidence class: $($b.evidence_class). Harness: $($b.harness). Budgets (PROVISIONAL): $($b.budgets) ($($b.budget_fails) failed: $($b.failed_checks -join ', ')). harness=OK with budgets=FAIL is NOT a pass."
    $s += "Noise floor p50/p99: $($b.noise.p50_ms)/$($b.noise.p99_ms) ms (p99/p50 = $($b.noise.p99_over_p50))"
    $s += "Rounds (bot) step avg/p95/p99: $($b.rounds_all_steps.avg_ms)/$($b.rounds_all_steps.p95_ms)/$($b.rounds_all_steps.p99_ms) ms"
    $cap = $b.scaling.clash[-1]
    $s += "Cap clash $($cap.n_per_side)/side step avg/p50/p95: $($cap.avg_ms)/$($cap.p50_ms)/$($cap.p95_ms) ms; find_target share: $($b.sections.find_target_all_units.avg_ms) ms of $($b.sections.step_total_avg_ms) ms"
    $s += "Save p50/p95: $($b.save.save.p50_ms)/$($b.save.save.p95_ms) ms; load p50: $($b.save.load.p50_ms) ms; content load first: $($b.content_load.first_ms) ms"
    $s += ''; $s += '| check | value | budget | result |'; $s += '|---|---|---|---|'
    foreach ($c in $b.checks) { $s += "| $($c.id) | $($c.value) | $($c.budget) | $($c.result) |" }
}
foreach ($f in 'frame_paced', 'frame_stress_ab_view', 'frame_menu_uncapped') {
    $p = Join-Path $Out "$f.json"
    if (Test-Path $p) {
        $j = Get-Content $p -Raw | ConvertFrom-Json
        $s += ''; $s += "## $f"
        $s += "frame ms p50/p95/p99: $($j.frame_ms.p50)/$($j.frame_ms.p95)/$($j.frame_ms.p99); gpu p95 $($j.render_gpu_ms.p95); draw calls p95 $($j.draw_calls.p95); units max $($j.peak.units); tex mem peak $([math]::Round($j.peak.tex_mem/1MB,2)) MiB"
        if ($j.ab.target) { $s += "A/B $($j.ab.target): frame avg shown $($j.ab.frame_ms_shown.avg) ms vs hidden $($j.ab.frame_ms_hidden.avg) ms" }
    }
}
$fj = Join-Path $Out 'font.json'
if (Test-Path $fj) {
    $fo = Get-Content $fj -Raw | ConvertFrom-Json
    $s += ''; $s += "## font ($($fo.evidence_class), reps $($fo.reps))"
    $s += '| case | allowed size | shape cold ms | warm ms | first frame ms | warm-label frame ms | glyph hitch ms | idle ms | cache pages | cache bytes | load ms |'; $s += '|---|---|---|---|---|---|---|---|---|---|---|'
    foreach ($r in $fo.summary) { $s += "| $($r.case) | $($r.allowed_size) | $($r.shape_cold_ms_med) | $($r.shape_warm_ms_med) | $($r.first_frame_ms_med) | $($r.warm_label_frame_ms_med) | $($r.glyph_hitch_ms_med) | $($r.idle_ms_med) | $($r.cache_pages) | $($r.cache_bytes) | $($r.load_ms_med) |" }
}
$meta.failures = $fail
$meta.private_appdata = $PerfAppData
$meta.isolation_proof_log = Test-PerfIsolation $PerfAppData $t0Run
if (-not $meta.isolation_proof_log) { Write-Warning 'no godot log under the private APPDATA: user:// isolation NOT proven for this run' }
$meta | ConvertTo-Json | Set-Content (Join-Path $Out 'meta.json') -Encoding utf8
$s | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
$latest = Join-Path $Root 'build\perf\latest'
if (Test-Path $latest) { Remove-Item -LiteralPath $latest -Recurse -Force }
Copy-Item -LiteralPath $Out -Destination $latest -Recurse
$s | ForEach-Object { Write-Host $_ }
Write-Host "[run_perf] output $Out"
if ($fail.Count -gt 0) { Write-Host "[run_perf] FAILED: $($fail -join ', ')"; exit 1 }
exit 0
