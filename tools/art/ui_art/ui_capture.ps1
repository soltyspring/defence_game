# 06-art-ui before/after screen captures of the UI art. Owner: 06-art-ui.
# Run ONLY inside the machine-wide heavy lock:
#   & .\coordination\heavy_run.ps1 -Label '06-ui-capture' -Script { & .\tools\art\ui_art\ui_capture.ps1 }
# Steps (serial, one Godot at a time):
#  1. git archive HEAD (project.godot icon.svg src scenes data assets tests/acceptance) -> build/ui06/before.
#     Copy it to build/ui06/after and overlay ONLY the 06-art-ui pages (ui_main, ui_title_ko, ui_title_en png/json)
#     + assets/manifest.json from -AfterSource (see param). Other roles' WIP never enters a snapshot.
#  2. --import in each snapshot through 10's isolated_godot.ps1 (user:// cannot reach the real player folder).
#  3. 07's tests/acceptance/capture_visual.gd (menu, round select, settings, r01 HUD ~0/30/60 s, result) through
#     04's visible_launch.ps1 (secondary monitor only, APPDATA isolated by default) for every
#     snapshot x locale (ko, en) x scale: 800x360 (1x) and 1600x720 (2x) = the 393 dp class view (800x360 logical;
#     1080x2400 phone at k = 3, 04's tools/build/text_screen_size.py).
# Output: build/ui06/shots/<before|after>_<ko|en>_<1x|2x>_<shot>.png, *_report.json, run.json.
param([string[]]$Locales = @('ko', 'en'), [string[]]$Scales = @('1x', '2x'), [string[]]$Snaps = @('before', 'after'),
      # where the AFTER pages come from: default = %TEMP%\ui06_r1, a clean HEAD copy built with 06's ui.py/branding.py
      # AND 03's pending R1 line applied to that copy's build.py only (so the cards show their final state);
      # pass the workspace root to overlay the working-tree pages instead.
      [string]$AfterSource = (Join-Path $env:TEMP 'ui06_r1'),
      # 'visual' = 07 capture_visual.gd (menu, r01 HUD, result); 'narrow' = 07 capture_narrow.gd (r08 HUD: 5 cards + worker
      # + 3 skills, narrowest safe area 34,0,34,0, per-button truncated flags = label fit; r08 result)
      [ValidateSet('visual', 'narrow')][string]$Capture = 'visual')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
Set-Location $root
$base = Join-Path $root 'build\ui06'
$shots = Join-Path $base 'shots'
$sha = (git rev-parse --short HEAD).Trim()
$res = @{ '1x' = '800x360'; '2x' = '1600x720' }
$run = [ordered]@{ head = $sha; started = (Get-Date).ToString('s'); imports = @{}; captures = @() }
New-Item -ItemType Directory -Force $shots | Out-Null

foreach ($s in $Snaps) {
    $d = Join-Path $base $s
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
    New-Item -ItemType Directory -Force $d | Out-Null
}
$tar = Join-Path $base 'head.tar'
& git -c core.autocrlf=false archive --format=tar -o $tar HEAD project.godot icon.svg src scenes data assets tests/acceptance
if ($LASTEXITCODE -ne 0) { throw 'git archive failed' }
foreach ($s in $Snaps) { & tar -xf $tar -C (Join-Path $base $s) }
Remove-Item $tar
if ($Snaps -contains 'after') {
    $own = @('assets/atlases/ui_main.png', 'assets/atlases/ui_main.json', 'assets/atlases/ui_title_ko.png',
             'assets/atlases/ui_title_ko.json', 'assets/atlases/ui_title_en.png', 'assets/atlases/ui_title_en.json',
             'assets/manifest.json')
    foreach ($f in $own) { Copy-Item (Join-Path $AfterSource $f) (Join-Path $base "after\$f") -Force }
    $run['after_overlay'] = $own
    $run['after_source'] = $AfterSource
}
$iso = Join-Path $root 'docs\research\systems\probes\isolated_godot.ps1'
foreach ($s in $Snaps) {
    $d = Join-Path $base $s
    $out = & $iso -GodotArgs @('--headless', '--path', $d, '--import') -TimeoutSec 600 2>&1
    $code = $LASTEXITCODE
    $proof = ($out | Where-Object { "$_" -match '^ISOLATED_GODOT ' } | Select-Object -Last 1)
    $run.imports[$s] = @{ exit = $code; proof = "$proof" }
    Write-Host "import $s exit=$code $proof"
    if ($code -ne 0) { throw "import failed: $s" }
}
$vl = Join-Path $root 'tools\build\visible_launch.ps1'
$scriptRes = if ($Capture -eq 'narrow') { 'res://tests/acceptance/capture_narrow.gd' } else { 'res://tests/acceptance/capture_visual.gd' }
foreach ($s in $Snaps) {
    foreach ($loc in $Locales) {
        foreach ($k in $Scales) {
            $tag = if ($Capture -eq 'narrow') { "${s}_${loc}_${k}_narrow" } else { "${s}_${loc}_${k}" }
            $ev = Join-Path $base "ev_$tag"
            $ua = @("--shot-dir=$($shots -replace '\\','/')", "--locale=$loc", "--tag=$tag")
            if ($Capture -eq 'narrow') { $ua += '--insets=34,0,34,0' }
            $ErrorActionPreference = 'Continue'
            $null = & $vl -ProjectPath (Join-Path $base $s) -Script $scriptRes -Resolution $res[$k] `
                -UserArgs $ua -TimeoutSec 240 -EvidenceDir $ev 6>&1
            $code = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            $n = @(Get-ChildItem $shots -Filter "${tag}_*.png").Count
            $run.captures += @{ tag = $tag; resolution = $res[$k]; exit = $code; pngs = $n }
            Write-Host ("{0,-16} {1,-9} exit={2} pngs={3}" -f $tag, $res[$k], $code, $n)
            if ($code -eq 3) { Write-Host 'BLOCKED: no secondary monitor'; $run['blocked'] = 'no secondary monitor'; break }
        }
    }
}
$run['finished'] = (Get-Date).ToString('s')
$run | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 (Join-Path $shots "run_$Capture.json")
Write-Host "Output: $shots"
