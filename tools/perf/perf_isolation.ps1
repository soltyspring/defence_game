# 08-performance: run Godot with a PRIVATE %APPDATA% so user:// never resolves to the player's real folder
# (%APPDATA%\Godot\app_userdata\<config/name>). Request: 10-research-systems-to-08-performance.md v0.26 P1. Godot 4.7.2 on Windows
# builds user:// from the APPDATA environment variable, and the Save autoload loads (and may rewrite) user://save.json at boot of any
# run with autoloads, before a probe can redirect it.
# Usage (dot-source):  . (Join-Path $PSScriptRoot 'perf_isolation.ps1')
#   $pa = New-PerfAppData $Root 'run_perf'      # build\perf\appdata\<tag>, save files removed, shader cache kept
#   Enter-PerfAppData $pa; try { <start Godot> } finally { Exit-PerfAppData }
#   $proof = Test-PerfIsolation $pa $t0         # path of a godot*.log written under the private folder since $t0, or ''
# A child started by Start-Process / & copies the environment at spawn time, so restoring right after the spawn is safe.
# Owner: 08-performance.

function New-PerfAppData([string]$Root, [string]$Tag) {
    $d = Join-Path $Root "build\perf\appdata\$Tag"
    New-Item -ItemType Directory -Force $d | Out-Null
    # fresh save every run (reproducible; earlier runs used whatever the real save held), keep the shader cache (fewer first-use hitches)
    Get-ChildItem -Path (Join-Path $d 'Godot\app_userdata') -Recurse -Filter 'save.json*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    return $d
}

function Enter-PerfAppData([string]$Dir) {
    if ($null -eq $script:PerfOldAppData) { $script:PerfOldAppData = $env:APPDATA }
    $env:APPDATA = $Dir
}

function Exit-PerfAppData {
    if ($null -ne $script:PerfOldAppData) { $env:APPDATA = $script:PerfOldAppData; $script:PerfOldAppData = $null }
}

function Test-PerfIsolation([string]$Dir, [datetime]$Since) {
    $l = Get-ChildItem -Recurse -Filter 'godot*.log' (Join-Path $Dir 'Godot\app_userdata') -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $Since.AddSeconds(-2) } | Select-Object -First 1
    if ($l) { return $l.FullName }
    return ''
}

# Machine-wide heavy-run lock (coordination/heavy_run.ps1, rule since the 23:09 blue screen): every Godot / emulator / long measurement
# must run inside it. heavy_run.ps1 runs the script block in the same pwsh process and logs "START <label> pid=<PID>" / "END ... pid=<PID>",
# so "inside" = the last START/END line for this $PID is a START. Tools call Assert-HeavyRun before their first heavy step.
function Test-InHeavyRun {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $log = Join-Path $root 'coordination\.runtime\heavy_run.log'
    if (-not (Test-Path $log)) { return $false }
    $mine = @(Get-Content -LiteralPath $log -Tail 400 -Encoding utf8 -ErrorAction SilentlyContinue | Where-Object { $_ -match " (START|END) .* pid=$PID( |$)" })
    if ($mine.Count -eq 0) { return $false }
    return ($mine[-1] -match ' START ')
}

function Assert-HeavyRun([string]$Tool) {
    if (Test-InHeavyRun) { return }
    Write-Host "NOT_LOCKED: $Tool starts Godot/emulator work. Run it via: & .\coordination\heavy_run.ps1 -Label '08-<task>' -Script { & .\tools\perf\$Tool ... }"
    exit 4
}
