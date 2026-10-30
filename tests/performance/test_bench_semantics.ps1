# Regression check for 08 perf harness exit/status semantics (coordinator C10). Owner: 08-performance.
# Harness completion and budget verdicts must never be conflated:
#   default : exit 0 whether budgets pass or fail, verdict printed as harness=OK budgets=PASS|FAIL
#   --strict: exit 1 when any budget check fails, exit 0 when all pass
# Uses perf_bench.gd --selfcheck=pass|fail (no measurements, ~2 s per case) and budget_inventory.py --strict.
# Usage: .\tests\performance\test_bench_semantics.ps1   (exit 0 = all cases behave as specified)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Godot = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$tmp = Join-Path $Root 'build\perf\semantics'
New-Item -ItemType Directory -Force $tmp | Out-Null
$cases = @(
    @{ name = 'pass_default'; sc = 'pass'; strict = $false; exit = 0; budgets = 'PASS' },
    @{ name = 'fail_default'; sc = 'fail'; strict = $false; exit = 0; budgets = 'FAIL' },
    @{ name = 'pass_strict'; sc = 'pass'; strict = $true; exit = 0; budgets = 'PASS' },
    @{ name = 'fail_strict'; sc = 'fail'; strict = $true; exit = 1; budgets = 'FAIL' }
)
$bad = 0
foreach ($c in $cases) {
    $a = @('--headless', '--path', '.', '-s', 'res://tests/performance/perf_bench.gd', '--', "--selfcheck=$($c.sc)", "--out=$tmp\$($c.name).json", '--contended=0')
    if ($c.strict) { $a += '--strict' }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $Godot @a 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $line = ($out -split "`n" | Where-Object { $_ -match '^PERF_BENCH ' } | Select-Object -Last 1)
    $j = Get-Content "$tmp\$($c.name).json" -Raw | ConvertFrom-Json
    $ok = ($code -eq $c.exit) -and ($line -match "harness=OK budgets=$($c.budgets)") -and ($j.budgets -eq $c.budgets) -and ($j.harness -eq 'OK')
    if (-not $ok) { $bad++ }
    Write-Host ("[semantics] {0,-4} {1,-13} exit={2} (want {3}) line='{4}'" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $c.name, $code, $c.exit, ($line -replace '\s+$', ''))
}
# inventory: current static budgets pass, so --strict must exit 0; a missing manifest path must exit 1 is not testable
# without touching 03's files, so only the strict-pass path is checked here.
& python (Join-Path $Root 'tools\perf\budget_inventory.py') --out $tmp --strict | Out-Null
$ic = $LASTEXITCODE
$inv = Get-Content "$tmp\inventory.json" -Raw | ConvertFrom-Json
$invFails = @($inv.checks | Where-Object { $_.result -eq 'FAIL' }).Count
$want = if ($invFails -gt 0) { 1 } else { 0 }
$iok = $ic -eq $want
if (-not $iok) { $bad++ }
Write-Host ("[semantics] {0,-4} inventory_strict exit={1} (want {2}, budget fails={3})" -f $(if ($iok) { 'PASS' } else { 'FAIL' }), $ic, $want, $invFails)
Write-Host "[semantics] $(if ($bad -eq 0) { 'ALL PASS' } else { "$bad FAILED" })"
exit $(if ($bad -eq 0) { 0 } else { 1 })
