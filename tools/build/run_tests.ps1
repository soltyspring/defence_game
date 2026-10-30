# Runs 04 headless UI tests and (if present) 02's engine self-test. Exit code 0 = all pass.
# Usage: .\tools\build\run_tests.ps1 [-SkipEngine]
param([switch]$SkipEngine)
. "$PSScriptRoot\common.ps1"
Assert-File $GodotConsole 'Godot console editor'
Set-Location $Root
$results = @()
function Invoke-Suite([string]$Name, [string[]]$GodotArgs) {
    Write-Host "=== $Name ==="
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'   # Godot writes warnings to stderr
    $out = & $GodotConsole @GodotArgs 2>&1 | Out-String
    $ErrorActionPreference = $prev
    $code = $LASTEXITCODE
    # print summary lines and failures only (full log kept in build/qa/)
    $out -split "`n" | Where-Object { $_ -match '^\[|FAIL|SCRIPT ERROR|Parse Error|passed=' } | Select-Object -Unique | Select-Object -First 40 | ForEach-Object { Write-Host $_.TrimEnd() }
    New-Item -ItemType Directory -Force (Join-Path $Root 'build\qa') | Out-Null
    Set-Content -Path (Join-Path $Root "build\qa\$Name.log") -Value $out -Encoding utf8
    Write-Host "=== $Name exit=$code ==="
    return [pscustomobject]@{ Suite = $Name; Exit = $code }
}
$results += Invoke-Suite 'ui_tests' @('--headless', '--path', '.', '-s', 'res://tests/ui/test_ui.gd')
if (-not $SkipEngine -and (Test-Path (Join-Path $Root 'src\core\diag\selftest.gd'))) {
    $results += Invoke-Suite 'engine_selftest' @('--headless', '--path', '.', '-s', 'res://src/core/diag/selftest.gd')
}
if (Test-Path (Join-Path $Root 'tests\integration\test_ui_integration.gd')) {
    $results += Invoke-Suite 'ui_integration' @('--headless', '--path', '.', '-s', 'res://tests/integration/test_ui_integration.gd')
}
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($results | Where-Object { $_.Exit -ne 0 }) { exit 1 } else { exit 0 }
