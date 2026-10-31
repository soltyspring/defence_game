# Regression check for 08 perf harness exit/verdict semantics (coordinator C10). Owner: 08-performance.
# Harness completion and budget verdicts must never be conflated. Checks are tagged adopted|provisional.
#   default      : exit 0 whenever the harness ran; verdict printed as harness=OK budgets=PASS|FAIL
#   --strict     : exit 1 only if an ADOPTED check fails (contract invariants); provisional failures stay exit 0
#   --strict-all : exit 1 if ANY check fails
# Uses perf_bench.gd --selfcheck=pass|fail|fail_adopted (no measurements, ~2 s per case) and budget_inventory.py.
# Usage: .\tests\performance\test_bench_semantics.ps1   (exit 0 = all cases behave as specified)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$tmp = Join-Path $Root 'build\perf\semantics'
New-Item -ItemType Directory -Force $tmp | Out-Null
. (Join-Path $Root 'tools\perf\perf_isolation.ps1')
Assert-HeavyRun '..\..\tests\performance\test_bench_semantics.ps1'   # machine-wide lock (coordination/heavy_run.ps1)
$PerfAppData = New-PerfAppData $Root 'semantics'   # private user:// (10 v0.26 P1)
$t0Iso = Get-Date
# sc = selfcheck input, mode = strict flag, exit = expected exit, budgets = expected verdict, af/pf = expected adopted/provisional fails
$cases = @(
    @{ name = 'pass_default';          sc = 'pass';         mode = '';             exit = 0; budgets = 'PASS'; af = 0; pf = 0 },
    @{ name = 'prov_fail_default';     sc = 'fail';         mode = '';             exit = 0; budgets = 'FAIL'; af = 0; pf = 1 },
    @{ name = 'prov_fail_strict';      sc = 'fail';         mode = '--strict';     exit = 0; budgets = 'FAIL'; af = 0; pf = 1 },
    @{ name = 'prov_fail_strict_all';  sc = 'fail';         mode = '--strict-all'; exit = 1; budgets = 'FAIL'; af = 0; pf = 1 },
    @{ name = 'adopt_fail_default';    sc = 'fail_adopted'; mode = '';             exit = 0; budgets = 'FAIL'; af = 1; pf = 0 },
    @{ name = 'adopt_fail_strict';     sc = 'fail_adopted'; mode = '--strict';     exit = 1; budgets = 'FAIL'; af = 1; pf = 0 },
    @{ name = 'pass_strict_all';       sc = 'pass';         mode = '--strict-all'; exit = 0; budgets = 'PASS'; af = 0; pf = 0 }
)
$bad = 0
foreach ($c in $cases) {
    $a = @('--headless', '--path', '.', '-s', 'res://tests/performance/perf_bench.gd', '--', "--selfcheck=$($c.sc)", "--out=$tmp\$($c.name).json", '--contended=0')
    if ($c.mode) { $a += $c.mode }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    Enter-PerfAppData $PerfAppData
    try { $out = & $Godot @a 2>&1 | Out-String } finally { Exit-PerfAppData }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $line = ($out -split "`n" | Where-Object { $_ -match '^PERF_BENCH ' } | Select-Object -Last 1)
    $j = Get-Content "$tmp\$($c.name).json" -Raw | ConvertFrom-Json
    $ok = ($code -eq $c.exit) -and ($line -match "harness=OK budgets=$($c.budgets)") -and ($j.budgets -eq $c.budgets) -and
          ($j.harness -eq 'OK') -and ($j.adopted_fails -eq $c.af) -and ($j.provisional_fails -eq $c.pf) -and ($j.exit_code -eq $c.exit)
    if (-not $ok) { $bad++ }
    Write-Host ("[semantics] {0,-4} {1,-22} exit={2} (want {3}) af={4} pf={5} line='{6}'" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $c.name, $code, $c.exit, $j.adopted_fails, $j.provisional_fails, ($line -replace '\s+$', ''))
}
# inventory: expected exits are derived from the real current checks (no foreign files are modified)
foreach ($mode in @('', '--strict', '--strict-all')) {
    $args2 = @((Join-Path $Root 'tools\perf\budget_inventory.py'), '--out', $tmp)
    if ($mode) { $args2 += $mode }
    & python @args2 | Out-Null
    $ic = $LASTEXITCODE
    $inv = Get-Content "$tmp\inventory.json" -Raw | ConvertFrom-Json
    $all = @($inv.checks | Where-Object { $_.result -eq 'FAIL' }).Count
    $adopted = @($inv.checks | Where-Object { $_.result -eq 'FAIL' -and $_.status -eq 'adopted' }).Count
    $untagged = @($inv.checks | Where-Object { -not $_.status }).Count
    $want = switch ($mode) { '' { 0 } '--strict' { [int]($adopted -gt 0) } '--strict-all' { [int]($all -gt 0) } }
    $iok = ($ic -eq $want) -and ($untagged -eq 0)
    if (-not $iok) { $bad++ }
    Write-Host ("[semantics] {0,-4} inventory{1,-13} exit={2} (want {3}; fails={4} adopted={5} untagged={6})" -f $(if ($iok) { 'PASS' } else { 'FAIL' }), $(if ($mode) { $mode } else { '_default' }), $ic, $want, $all, $adopted, $untagged)
}
# isolation (10 v0.26 P1): the selfcheck runs above must have logged under the PRIVATE user dir
$proof = Test-PerfIsolation $PerfAppData $t0Iso
$isoOk = [bool]$proof
if (-not $isoOk) { $bad++ }
Write-Host ("[semantics] {0,-4} private_appdata        log={1}" -f $(if ($isoOk) { 'PASS' } else { 'FAIL' }), $(if ($proof) { $proof.Replace($Root, '.') } else { 'NONE (user:// not isolated)' }))
Write-Host "[semantics] $(if ($bad -eq 0) { 'ALL PASS' } else { "$bad FAILED" })"
exit $(if ($bad -eq 0) { 0 } else { 1 })
