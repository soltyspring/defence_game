# Controlled A/B retest of a COMMITTED engine fix (owner: 08-performance). DESKTOP PROXY evidence only.
# Builds two read-only snapshots from git (no checkout, no index change): "fix" = <FixRev> tree, "base" = the same tree with
# only <Files> replaced by their content at <BaseRev>. Same harness (current tests/performance/perf_bench.gd), same seeds,
# runs interleaved base/fix/base/fix... in one session so machine contention affects both sides alike. Other workers'
# uncommitted WIP in the shared checkout is never measured.
# Usage:
#   .\tools\perf\ab_retest.ps1 -BaseRev a4a549e -FixRev HEAD -Files src/gameplay/battle_sim.gd [-Pairs 2] [-Quick]
#   (BaseRev may be a commit or a blob id when exactly one file is given)
# Output: build/perf/ab_<stamp>/ (git-ignored): base_N.json, fix_N.json, ab_summary.json, ab_summary.md
param(
    [Parameter(Mandatory = $true)][string]$BaseRev,
    [string]$FixRev = 'HEAD',
    [Parameter(Mandatory = $true)][string[]]$Files,
    [int]$Pairs = 2,
    [switch]$Quick
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\ab_$stamp"
New-Item -ItemType Directory -Force $Out | Out-Null
$fixSha = (& git rev-parse --short $FixRev).Trim()

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

$runs = @()
for ($i = 1; $i -le $Pairs; $i++) {
    foreach ($side in @('base', 'fix')) {
        $w = 0; while ((Test-ImportLockHeld) -and $w -lt 300) { Start-Sleep 5; $w += 5 }
        $others = @(Get-Process | Where-Object { $_.ProcessName -like 'Godot*' }).Count
        $dir = if ($side -eq 'base') { $baseDir } else { $fixDir }
        $json = Join-Path $Out "${side}_$i.json"
        $a = @('--headless', '--path', $dir, '-s', 'res://tests/performance/perf_bench.gd', '--', "--out=$json", "--git=$fixSha+$side", "--contended=$others")
        if ($Quick) { $a += '--quick' }
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $log = & $Godot @a 2>&1 | Out-String
        $code = $LASTEXITCODE; $ErrorActionPreference = $prev
        Set-Content (Join-Path $Out "${side}_$i.log") $log -Encoding utf8
        $line = ($log -split "`n" | Where-Object { $_ -match '^PERF_BENCH ' } | Select-Object -Last 1)
        Write-Host "[ab] $side#$i other_godot=$others lock_wait=${w}s exit=$code $line"
        $runs += [ordered]@{ side = $side; pair = $i; json = $json; exit = $code; other_godot = $others }
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
$summary = [ordered]@{
    evidence_class = $(if ($maxOthers -gt 0) { 'CONTENDED_DESKTOP_PROXY' } else { 'DESKTOP_PROXY' })
    note = 'Same harness, same seeds (rounds 11/22/33, scaling seed 77), interleaved runs. Debug editor binary. Not phone evidence.'
    fix_rev = $fixSha; base_rev = $BaseRev; files = $diffs; pairs = $Pairs; quick = [bool]$Quick; runs = $runs
    metrics = $rows; determinism = $det; deterministic_outcomes_identical = (@($det | Where-Object { -not $_.identical }).Count -eq 0)
}
$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'ab_summary.json') -Encoding utf8
$md = @("# A/B retest $stamp ($($summary.evidence_class))", "fix $fixSha vs base $BaseRev for $($Files -join ', '); $Pairs interleaved pairs; max other Godot processes $maxOthers", '',
    '| metric | base median | fix median | delta % |', '|---|---|---|---|')
foreach ($r in $rows) { $md += "| $($r.metric) | $($r.base_median) | $($r.fix_median) | $($r.delta_pct) |" }
$md += ''; $md += "Deterministic round outcomes identical (won + end time per seed): $($summary.deterministic_outcomes_identical)"
$md | Set-Content (Join-Path $Out 'ab_summary.md') -Encoding utf8
$md | ForEach-Object { Write-Host $_ }
Write-Host "[ab] output $Out"
if (@($runs | Where-Object { $_.exit -ne 0 }).Count -gt 0) { exit 1 } else { exit 0 }
