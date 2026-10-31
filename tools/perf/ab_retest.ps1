# Controlled A/B retest of a COMMITTED engine fix (owner: 08-performance). DESKTOP PROXY evidence only.
# Builds two read-only snapshots from git (no checkout, no index change): "fix" = <FixRev> tree, "base" = the same tree with
# only <Files> replaced by their content at <BaseRev>. Same harness (current tests/performance/perf_bench.gd), same seeds,
# runs interleaved base/fix/base/fix... in one session so machine contention affects both sides alike. Other workers'
# uncommitted WIP in the shared checkout is never measured.
# Usage:
#   .\tools\perf\ab_retest.ps1 -BaseRev a4a549e -FixRev HEAD -Files src/gameplay/battle_sim.gd [-Pairs 2] [-Quick]
#   (BaseRev may be a commit or a blob id when exactly one file is given)
#   -RequireQuiet: wait (max -QuietWaitSec) until no foreign Godot/emulator process runs, else exit 2 without measuring.
# Every run is monitored once per second; any foreign Godot/emulator process seen during a run marks it CONTAMINATED and the
# summary INVALID_CONTAMINATED. Only VALID_QUIET summaries may be used as pass/fail evidence for an owner's acceptance target.
# Output: build/perf/ab_<stamp>/ (git-ignored): base_N.json, fix_N.json, ab_summary.json, ab_summary.md
param(
    [Parameter(Mandatory = $true)][string]$BaseRev,
    [string]$FixRev = 'HEAD',
    [Parameter(Mandatory = $true)][string[]]$Files,
    [int]$Pairs = 2,
    [switch]$Quick,
    [switch]$RequireQuiet,          # refuse to measure unless no foreign Godot/emulator process runs (waits up to QuietWaitSec)
    [int]$QuietWaitSec = 600
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\ab_$stamp"
New-Item -ItemType Directory -Force $Out | Out-Null
$fixSha = (& git rev-parse --short $FixRev).Trim()
. (Join-Path $PSScriptRoot 'perf_isolation.ps1')
Assert-HeavyRun 'ab_retest.ps1'   # machine-wide lock (coordination/heavy_run.ps1)
$PerfAppData = New-PerfAppData $Root 'ab_retest'   # private user:// (10 v0.26 P1)
function New-Snapshot([string]$dir) {
    New-Item -ItemType Directory -Force $dir | Out-Null
    $tar = Join-Path $Out 'tree.tar'
    & git archive --format=tar -o $tar $FixRev src data project.godot
    if ($LASTEXITCODE -ne 0) { throw "git archive failed for $FixRev" }
    & tar -xf $tar -C $dir
    New-Item -ItemType Directory -Force (Join-Path $dir 'tests\performance') | Out-Null
    Copy-Item (Join-Path $Root 'tests\performance\perf_bench.gd') (Join-Path $dir 'tests\performance\')
}
$fixDir = Join-Path $Out 'fix'; $baseDir = Join-Path $Out 'base'
New-Snapshot $fixDir; New-Snapshot $baseDir
foreach ($f in $Files) {
    $spec = if ($BaseRev -match '^[0-9a-f]{7,40}$' -and $Files.Count -eq 1 -and ((& git cat-file -t $BaseRev) -eq 'blob')) { $BaseRev } else { "${BaseRev}:$f" }
    $content = & git show $spec | Out-String
    if ($LASTEXITCODE -ne 0) { throw "git show $spec failed" }
    [IO.File]::WriteAllText((Join-Path $baseDir $f), $content.TrimEnd("`r", "`n") + "`n")
}
$diffs = foreach ($f in $Files) { [ordered]@{ file = $f; base_sha256 = (Get-FileHash (Join-Path $baseDir $f)).Hash.Substring(0, 16); fix_sha256 = (Get-FileHash (Join-Path $fixDir $f)).Hash.Substring(0, 16) } }

$lockPath = Join-Path $Root 'build\.godot-import.lock'
function Test-ImportLockHeld { if (-not (Test-Path $lockPath)) { return $false }; try { $fs = [IO.File]::Open($lockPath, 'Open', 'Read', 'None'); $fs.Dispose(); return $false } catch { return $true } }

# Foreign-process monitor: every second during each run, list Godot/emulator processes that are not this run's process tree.
# Any foreign process seen at any time marks the run CONTAMINATED (coordinator notice 08:53: start-time counts are not enough).
function Get-ForeignHeavy([int[]]$own) {
    @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -like 'Godot*' -or $_.Name -like 'qemu-system*' -or $_.Name -like 'emulator*') -and ($own -notcontains [int]$_.ProcessId)
    } | ForEach-Object { [ordered]@{ pid = [int]$_.ProcessId; name = $_.Name; cmd = $(if ($_.CommandLine) { $_.CommandLine.Substring(0, [math]::Min(160, $_.CommandLine.Length)) } else { '' }) } })
}
if ($RequireQuiet) {
    $w0 = 0
    while (@(Get-ForeignHeavy @()).Count -gt 0 -and $w0 -lt $QuietWaitSec) { Start-Sleep 10; $w0 += 10 }
    $still = @(Get-ForeignHeavy @())
    if ($still.Count -gt 0) {
        Write-Host "BLOCKED_NOT_QUIET: $($still.Count) foreign Godot/emulator process(es) still running after ${QuietWaitSec}s; no measurement taken."
        $still | ForEach-Object { Write-Host "  $($_.pid) $($_.cmd)" }
        exit 2
    }
}
$runs = @()
for ($i = 1; $i -le $Pairs; $i++) {
    foreach ($side in @('base', 'fix')) {
        $w = 0; while ((Test-ImportLockHeld) -and $w -lt 300) { Start-Sleep 5; $w += 5 }
        $others = @(Get-ForeignHeavy @()).Count
        $dir = if ($side -eq 'base') { $baseDir } else { $fixDir }
        $json = Join-Path $Out "${side}_$i.json"
        $a = @('--headless', '--path', $dir, '-s', 'res://tests/performance/perf_bench.gd', '--', "--out=$json", "--git=$fixSha+$side", "--contended=$others")
        if ($Quick) { $a += '--quick' }
        $so = Join-Path $Out "${side}_$i.log"; $se = Join-Path $Out "${side}_$i.err.log"
        $t0 = Get-Date
        Enter-PerfAppData $PerfAppData
        try { $proc = Start-Process -FilePath $Godot -ArgumentList $a -RedirectStandardOutput $so -RedirectStandardError $se -PassThru -WindowStyle Hidden } finally { Exit-PerfAppData }
        $null = $proc.Handle
        $seen = @{}
        while (-not $proc.HasExited) {
            $own = @($proc.Id) + @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($proc.Id)" -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.ProcessId })
            foreach ($f in (Get-ForeignHeavy $own)) {
                if (-not $seen.ContainsKey($f.pid)) { $seen[$f.pid] = [ordered]@{ pid = $f.pid; cmd = $f.cmd; first_seen_s = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1) } }
            }
            Start-Sleep -Milliseconds 1000
        }
        $proc.WaitForExit()
        $code = $proc.ExitCode
        $log = (Get-Content $so -Raw -ErrorAction SilentlyContinue)
        $line = ($log -split "`n" | Where-Object { $_ -match '^PERF_BENCH ' } | Select-Object -Last 1)
        $foreign = @($seen.Values)
        $state = if ($foreign.Count -gt 0) { 'CONTAMINATED' } else { 'CLEAN' }
        Write-Host "[ab] $side#$i $state foreign_seen=$($foreign.Count) start_others=$others lock_wait=${w}s exit=$code $line"
        $runs += [ordered]@{ side = $side; pair = $i; json = $json; exit = $code; other_godot = $others; start = $t0.ToString('s');
            duration_s = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1); state = $state; foreign_seen = $foreign }
    }
}

function Med([double[]]$v) { $s = @($v | Sort-Object); if ($s.Count -eq 0) { return $null }; return $s[[int][math]::Floor(($s.Count - 1) / 2)] }
$metrics = [ordered]@{
    rounds_avg_ms = { param($j) $j.rounds_all_steps.avg_ms }
    rounds_p95_ms = { param($j) $j.rounds_all_steps.p95_ms }
    cap_clash_avg_ms = { param($j) $j.scaling.clash[-1].avg_ms }
    cap_clash_p50_ms = { param($j) $j.scaling.clash[-1].p50_ms }
    cap_clash_p95_ms = { param($j) $j.scaling.clash[-1].p95_ms }
    sections_units_avg_ms = { param($j) $j.sections.sections.units.avg_ms }
    sections_total_avg_ms = { param($j) $j.sections.step_total_avg_ms }
    noise_p99_ms = { param($j) $j.noise.p99_ms }
}
$data = @{ base = @(); fix = @() }
foreach ($r in $runs) { if (Test-Path $r.json) { $data[$r.side] += , (Get-Content $r.json -Raw | ConvertFrom-Json) } }
$rows = @()
foreach ($k in $metrics.Keys) {
    $b = Med @($data.base | ForEach-Object { & $metrics[$k] $_ }); $f = Med @($data.fix | ForEach-Object { & $metrics[$k] $_ })
    $rows += [ordered]@{ metric = $k; base_median = $b; fix_median = $f; delta_pct = $(if ($b) { [math]::Round(100 * ($f - $b) / $b, 1) } else { $null }) }
}
# determinism: identical seeds must give identical outcomes unless the fix intends a behaviour change
$det = @()
if ($data.base.Count -gt 0 -and $data.fix.Count -gt 0) {
    $b0 = $data.base[0]; $f0 = $data.fix[0]
    for ($i = 0; $i -lt $b0.rounds.Count; $i++) {
        $same = (($b0.rounds[$i].won -join ',') -eq ($f0.rounds[$i].won -join ',')) -and (($b0.rounds[$i].t -join ',') -eq ($f0.rounds[$i].t -join ','))
        $det += [ordered]@{ round = $b0.rounds[$i].round; base_t = ($b0.rounds[$i].t -join ','); fix_t = ($f0.rounds[$i].t -join ','); identical = $same }
    }
}
$maxOthers = ($runs | ForEach-Object { $_.other_godot } | Measure-Object -Maximum).Maximum
$contaminated = @($runs | Where-Object { $_.state -eq 'CONTAMINATED' }).Count
$summary = [ordered]@{
    evidence_class = $(if ($contaminated -gt 0 -or $maxOthers -gt 0) { 'CONTENDED_DESKTOP_PROXY' } else { 'DESKTOP_PROXY' })
    validity = $(if ($contaminated -gt 0) { "INVALID_CONTAMINATED ($contaminated of $($runs.Count) runs overlapped foreign Godot/emulator processes)" } else { 'VALID_QUIET (no foreign Godot/emulator process observed during any run)' })
    note = 'Same harness, same seeds (rounds 11/22/33, scaling seed 77), interleaved runs. Debug editor binary. Not phone evidence.'
    fix_rev = $fixSha; base_rev = $BaseRev; files = $diffs; pairs = $Pairs; quick = [bool]$Quick; runs = $runs
    metrics = $rows; determinism = $det; deterministic_outcomes_identical = (@($det | Where-Object { -not $_.identical }).Count -eq 0)
    private_appdata = $PerfAppData; isolation_proof_log = (Test-PerfIsolation $PerfAppData (Get-Date).AddHours(-6))
}
$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'ab_summary.json') -Encoding utf8
$md = @("# A/B retest $stamp ($($summary.evidence_class)) — $($summary.validity)", "fix $fixSha vs base $BaseRev for $($Files -join ', '); $Pairs interleaved pairs; max other Godot processes $maxOthers", '',
    '| metric | base median | fix median | delta % |', '|---|---|---|---|')
foreach ($r in $rows) { $md += "| $($r.metric) | $($r.base_median) | $($r.fix_median) | $($r.delta_pct) |" }
$md += ''; $md += "Deterministic round outcomes identical (won + end time per seed): $($summary.deterministic_outcomes_identical)"
$md | Set-Content (Join-Path $Out 'ab_summary.md') -Encoding utf8
$md | ForEach-Object { Write-Host $_ }
Write-Host "[ab] output $Out"
if (@($runs | Where-Object { $_.exit -ne 0 }).Count -gt 0) { exit 1 } else { exit 0 }
