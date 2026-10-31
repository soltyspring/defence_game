# 03-art: battlefield readability renders + metrics (isolated temp project, own fresh import;
# independent of the main-tree .godot cache). Window on the SECONDARY monitor (check.gd).
# Usage (workspace root): pwsh tools/art/run_godot_readability.ps1 [-Tag before|after]
param([string]$Tag = 'run')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$G = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$tmp = Join-Path $env:TEMP 'defence_art_read'
$out = Join-Path $root "docs\art\evidence\readability\$Tag"
$ud = Join-Path $env:APPDATA 'Godot\app_userdata\defence-art-check\readability'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
if (Test-Path $ud) { Remove-Item -Recurse -Force $ud }
New-Item -ItemType Directory -Force "$tmp\assets\atlases", $out | Out-Null
Copy-Item "$PSScriptRoot\godot_check\*" $tmp
Copy-Item "$root\assets\manifest.json" "$tmp\assets\"
Copy-Item "$root\assets\atlases\*" "$tmp\assets\atlases\" -Exclude *.import
python (Join-Path $PSScriptRoot 'readability.py') spec $out
Copy-Item "$out\scenes.json" "$tmp\scenes.json"
& $G --headless --path $tmp --import 2>&1 | Out-Null
& $G --path $tmp --rendering-driver opengl3 --resolution 320x180 -- --readability 2>&1 | ForEach-Object { "$_".TrimEnd() } | Out-File -Encoding utf8 "$out\godot_run.log"
Copy-Item "$ud\*" $out -Force
python (Join-Path $PSScriptRoot 'readability.py') measure $out $Tag
