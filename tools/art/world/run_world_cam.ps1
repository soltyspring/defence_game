# 09-art-world: import a project snapshot (private APPDATA) and run world_cam.gd once on the secondary monitor.
# Must run INSIDE the machine-wide heavy-run lock, detached (coordination/HEAVY_RUN.md): put this call in a job file and start it with
#   & .\coordination\heavy_run_detached.ps1 -Label '09-world-cam' -ScriptFile build\heavy\09-world-cam-job.ps1
# It opens a visible window (GPU): use it only when a real capture is needed.
# Steps: copy world_cam.gd to <snapshot>\art09_check\, `--headless --import` through 10's isolated_godot.ps1, check every
# font/atlas import output exists, then 04's visible_launch.ps1 (DISPLAY2 only, APPDATA isolated by default) at 640x360.
param([Parameter(Mandatory)][string]$Snapshot, [Parameter(Mandatory)][string]$Out,
      [string]$Plan = 'r01:30,60;r06:46,75;r10:60,110', [string]$Resolution = '640x360', [switch]$SkipImport, [switch]$Bases)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$snap = (Resolve-Path $Snapshot).Path
New-Item -ItemType Directory -Force (Join-Path $snap 'art09_check'), $Out | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'world_cam.gd') (Join-Path $snap 'art09_check\world_cam.gd') -Force
if (-not $SkipImport) {
    $log = Join-Path $Out 'import.log'
    & (Join-Path $root 'docs\research\systems\probes\isolated_godot.ps1') -GodotArgs @('--headless', '--path', $snap, '--import') -TimeoutSec 900 *> $log
    Write-Host "import exit=$LASTEXITCODE log=$log"
    $missing = @()
    foreach ($imp in Get-ChildItem (Join-Path $snap 'assets') -Recurse -Filter '*.import' | Where-Object { $_.Name -match '\.(ttf|png)\.import$' }) {
        $p = Select-String -Path $imp.FullName -Pattern '^path="res://(.+)"' | Select-Object -First 1
        if ($p -and -not (Test-Path (Join-Path $snap ($p.Matches[0].Groups[1].Value -replace '/', '\')))) { $missing += $imp.Name }
    }
    Write-Host "import outputs missing: $($missing.Count) $($missing -join ',')"
    if ($missing.Count -gt 0) { exit 2 }
}
$ua = @("--shot-dir=$($Out -replace '\\', '/')/shots", "--plan=$Plan")
if ($Bases) { $ua += '--bases' }
& (Join-Path $root 'tools\build\visible_launch.ps1') -ProjectPath $snap -Script 'res://art09_check/world_cam.gd' -Resolution $Resolution `
    -TimeoutSec 300 -EvidenceDir $Out -UserArgs $ua
exit $LASTEXITCODE
