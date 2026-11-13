<# Run this script inside coordination/heavy_run_detached.ps1 on the shared PC.
   All saves/logs are confined to this checkout's ignored build directory.
#>
param([Parameter(Mandatory)][string]$Godot, [switch]$Balance)
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$Godot = (Resolve-Path -LiteralPath $Godot).Path
Set-Location -LiteralPath $taskRoot
$output = Join-Path $taskRoot 'build/campaign100'
New-Item -ItemType Directory -Force $output | Out-Null
$oldAppData = $env:APPDATA
$env:APPDATA = Join-Path $output ('verify-appdata-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
try {
    $failedChecks = @()
    & $Godot --headless --language en --path $taskRoot --import *> (Join-Path $output 'verify-import.log')
    if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText((Join-Path $output 'verify-import.log')) -match 'SCRIPT ERROR|Parse Error') { throw 'Import failed. See verify-import.log.' }
    foreach ($mode in @('normal','preview')) {
        $runArgs = @('--headless','--language','en','--path',$taskRoot,'-s','tests/acceptance/test_campaign100.gd')
        if ($mode -eq 'preview') { $runArgs += @('--','--gold-shop-preview') }
        $log = Join-Path $output "verify-$mode.log"
        & $Godot @runArgs *> $log
        $contents = [IO.File]::ReadAllText($log)
        if ($LASTEXITCODE -ne 0 -or $contents -match 'SCRIPT ERROR|Parse Error|ERROR:|FAIL ' -or $contents -notmatch '\[campaign100\] checks=\d+ failures=0') { $failedChecks += $log }
    }
    foreach ($test in @('tests/acceptance/test_campaign30.gd','tests/acceptance/test_challenge_core.gd','tests/acceptance/test_frost_nest_core.gd','tests/integration/test_ui_integration.gd','tests/services/test_services_upgrade.gd')) {
        $log = Join-Path $output (([IO.Path]::GetFileNameWithoutExtension($test)) + '.log')
        & $Godot --headless --language en --path $taskRoot -s $test *> $log
        $contents = [IO.File]::ReadAllText($log)
        if ($LASTEXITCODE -ne 0 -or $contents -match 'SCRIPT ERROR|Parse Error|ERROR:|FAIL ') { $failedChecks += $log }
    }
    if ($failedChecks.Count -gt 0) { throw ('Checks failed: ' + ($failedChecks -join ', ')) }
    if ($Balance) {
        & $Godot --headless --language en --path $taskRoot -s tests/acceptance/validate_campaign100_balance.gd *> (Join-Path $output 'final-balance.log')
        if ($LASTEXITCODE -ne 0) { throw 'Balance validation failed.' }
        & $Godot --headless --language en --path $taskRoot -s tests/acceptance/journey_campaign100.gd *> (Join-Path $output 'journey.log')
        if ($LASTEXITCODE -ne 0) { throw 'Continuous journey did not reach round 100. See journey.log.' }
        python tools/build/report_campaign100.py
        if ($LASTEXITCODE -ne 0) { throw 'Balance report failed.' }
    }
    Write-Output 'CAMPAIGN100_VERIFIED'
} finally { $env:APPDATA = $oldAppData }
