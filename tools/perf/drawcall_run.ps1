# 08-performance draw-call breakdown runner (DESKTOP PROXY; counts are renderer-side, timings are not reported). Owner: 08-performance.
# 1. git-archive snapshot of -Rev in build/perf/dc_<sha> (+ tests/performance/*.gd), with its OWN --import, because the shared
#    .godot/imported can hold other roles' uncommitted textures (UiStyle then disables icons as "stale import").
# 2. tests/performance/perf_drawcall_probe.gd on the secondary monitor (autoplay + stress), then perf_batch_micro.gd.
# Every Godot call runs with a private APPDATA (perf_isolation.ps1, 10 v0.26 P1), so user:// never touches the real player folder.
# Usage: .\tools\perf\drawcall_run.ps1 [-Rev origin/main] [-Round r08] [-Warmup 35] [-Phase 2.5] [-SkipMicro]
# Output: build/perf/drawcalls_<round>_<sha>_<stamp>.json, build/perf/batch_micro_<sha>_<stamp>.json (git-ignored). Exit 0 / 1 error / 3 not isolated.
param([string]$Rev = 'origin/main', [string]$Round = 'r08', [double]$Warmup = 35, [double]$Phase = 2.5, [switch]$SkipMicro)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
. (Join-Path $PSScriptRoot 'perf_isolation.ps1')
$sha = (& git rev-parse --short $Rev).Trim()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$snap = Join-Path $Root "build\perf\dc_$sha"
$pa = New-PerfAppData $Root 'drawcall_run'
$t0 = Get-Date

function Invoke-G([string]$Name, [string[]]$GArgs) {
    $log = Join-Path $Root "build\perf\${Name}_${sha}_$stamp.log"
    Enter-PerfAppData $pa
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $Godot @GArgs *> $log } finally { $ErrorActionPreference = $prev; Exit-PerfAppData }
    $code = $LASTEXITCODE
    Write-Host "[dc_run] $Name exit=$code log=$log"
    return $code
}

if (-not (Test-Path (Join-Path $snap 'project.godot'))) {
    New-Item -ItemType Directory -Force $snap | Out-Null
    $tar = "$snap.tar"
    & git archive --format=tar -o $tar $sha project.godot icon.svg src scenes data assets
    if ($LASTEXITCODE -ne 0) { throw "git archive failed for $sha" }
    & tar -xf $tar -C $snap
    Remove-Item $tar
    # seed the import cache from the shared tree (speed only); the snapshot's own --import below re-imports every changed source
    New-Item -ItemType Directory -Force (Join-Path $snap '.godot') | Out-Null
    if (Test-Path (Join-Path $Root '.godot\imported')) { Copy-Item (Join-Path $Root '.godot\imported') (Join-Path $snap '.godot\') -Recurse }
}
New-Item -ItemType Directory -Force (Join-Path $snap 'tests\performance') | Out-Null
Copy-Item (Join-Path $Root 'tests\performance\*.gd') (Join-Path $snap 'tests\performance\') -Force
if ((Invoke-G 'dc_import' @('--headless', '--path', $snap, '--import')) -ne 0) { throw 'snapshot import failed' }

Add-Type -AssemblyName System.Windows.Forms
$screens = @([System.Windows.Forms.Screen]::AllScreens)
$secondary = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $secondary) { Write-Host 'BLOCKED_NO_SECONDARY_MONITOR: visible probe not run (user rule).'; exit 1 }
$idx = [array]::IndexOf($screens, $secondary)
$foreign = @(Get-Process | Where-Object { $_.ProcessName -like 'Godot*' }).Count
$out = Join-Path $Root "build\perf\drawcalls_${Round}_${sha}_$stamp.json"
$code = Invoke-G 'dc_probe' @('--screen', "$idx", '--resolution', '1280x720', '--path', $snap, '-s', 'res://tests/performance/perf_drawcall_probe.gd', '--',
    '--autoplay', "--round=$Round", "--dc-warmup=$Warmup", "--dc-phase=$Phase", '--dc-cycles=1', "--perf-contended=$foreign", "--dc-out=$out")
if ($code -ne 0) { exit 1 }
if (-not $SkipMicro) {
    $mo = Join-Path $Root "build\perf\batch_micro_${sha}_$stamp.json"
    if ((Invoke-G 'dc_micro' @('--screen', "$idx", '--resolution', '1280x720', '--path', $snap, '-s', 'res://tests/performance/perf_batch_micro.gd', '--', "--bm-out=$mo")) -ne 0) { exit 1 }
}
$proof = Test-PerfIsolation $pa $t0
$j = Get-Content $out -Raw | ConvertFrom-Json
$stale = Select-String -Path (Join-Path $Root "build\perf\dc_probe_${sha}_$stamp.log") -Pattern 'import is stale' -Quiet
Write-Host "[dc_run] rev=$sha foreign_godot_at_start=$foreign class=$($j.evidence_class) stale_import_warning=$stale isolation_log=$(if ($proof) { $proof.Replace($Root, '.') } else { 'NONE' })"
foreach ($r in $j.rows) {
    if ($r.phase -eq 'all' -or $r.phase -notmatch '#') {
        Write-Host ("[dc_run] {0,-26} median={1,4} delta={2,4} (vs {3}) runs real/row/m2/m1/row_m2={4}/{5}/{6}/{7}/{8}" -f $r.phase, $r.draw_calls_median, $r.delta_vs_ref, $r.ref,
            $r.unit_page_runs_median.real, $r.unit_page_runs_median.row, $r.unit_page_runs_median.merge2, $r.unit_page_runs_median.merge1, $r.unit_page_runs_median.row_merge2)
    }
}
$refs = @($j.rows | Where-Object { $_.phase -match '^(view_only|hud_only)#' } | Group-Object { $_.phase -replace '#\d+$', '' } | ForEach-Object { "{0} refs {1}-{2}" -f $_.Name, ($_.Group.draw_calls_median | Measure-Object -Minimum).Minimum, ($_.Group.draw_calls_median | Measure-Object -Maximum).Maximum })
Write-Host "[dc_run] $($refs -join '; ')"
foreach ($h in $j.hud_children) { Write-Host ("[dc_run] hud child {0,-12} {1,-30} {2}" -f $h.name, $h.script, $h.text) }
if ($stale) { Write-Warning 'UiStyle reported a stale import in the snapshot: HUD rows were measured without icons' }
if (-not $proof) { Write-Host 'NOT_ISOLATED: no godot log under the private APPDATA'; exit 3 }
exit 0
