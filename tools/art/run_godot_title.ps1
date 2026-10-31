# 03-art: render title logos (1/2/3x, 360-px-wide view) + check app-icon PNGs import, then
# measure: pixel-exact match vs the source (nearest upscale), width fit in 360, icon legibility.
# Window on the SECONDARY monitor (check.gd). Isolated temp project.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$G = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$tmp = Join-Path $env:TEMP 'defence_art_title'
$out = Join-Path $root 'docs\art\evidence\branding'
$ud = Join-Path $env:APPDATA 'Godot\app_userdata\defence-art-check\title'
foreach ($d in $tmp, $ud) { if (Test-Path $d) { Remove-Item -Recurse -Force $d } }
New-Item -ItemType Directory -Force "$tmp\assets\atlases", "$tmp\branding", $out | Out-Null
Copy-Item "$PSScriptRoot\godot_check\*" $tmp
Copy-Item "$root\assets\manifest.json" "$tmp\assets\"
Copy-Item "$root\assets\atlases\*" "$tmp\assets\atlases\" -Exclude *.import
Copy-Item "$root\docs\art\branding\app_icon_candidate_*.png" "$tmp\branding\"
& $G --headless --path $tmp --import 2>&1 | Out-Null
& $G --path $tmp --rendering-driver opengl3 --resolution 320x180 -- --title-sheet 2>&1 | ForEach-Object { "$_".TrimEnd() } | Out-File -Encoding utf8 "$out\godot_run.log"
Copy-Item "$ud\*" $out -Force
python (Join-Path $PSScriptRoot 'branding_check.py') $out
