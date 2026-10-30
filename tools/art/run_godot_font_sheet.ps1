# 03-art: render shipped fonts with the real Godot renderer (device-emulating SubViewports).
# Usage (workspace root): pwsh tools/art/run_godot_font_sheet.ps1
# Window (small) opens on the SECONDARY monitor only (check.gd moves it); isolated temp project.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$G = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$tmp = Join-Path $env:TEMP 'defence_art_fonts'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force "$tmp\assets\atlases", "$tmp\assets\fonts", "$tmp\data\text" | Out-Null
Copy-Item "$PSScriptRoot\godot_check\*" $tmp
Copy-Item "$root\assets\manifest.json" "$tmp\assets\"
Copy-Item "$root\assets\atlases\*" "$tmp\assets\atlases\" -Exclude *.import
Copy-Item "$root\assets\fonts\*" "$tmp\assets\fonts\" -Exclude *.import
Copy-Item "$root\data\text\ko.json" "$tmp\data\text\"
$out = Join-Path $root 'docs\art\evidence\fonts'
New-Item -ItemType Directory -Force $out | Out-Null
& $G --headless --path $tmp --import 2>&1 | ForEach-Object { "$_".TrimEnd() } | Out-File -Encoding utf8 "$out\font_import.log"
$log = & $G --path $tmp --rendering-driver opengl3 --resolution 320x180 -- --font-sheet 2>&1
$log | ForEach-Object { "$_".TrimEnd() } | Out-File -Encoding utf8 "$out\font_run.log"
$line = $log | Where-Object { "$_" -like 'ART_FONT_JSON *' } | Select-Object -Last 1
if (!$line) { throw "no ART_FONT_JSON; see $out\font_run.log" }
$json = "$line".Substring(14)
$rep = $json | ConvertFrom-Json
Copy-Item "$($rep.out_dir)\*.png" $out -Force
$rep | ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 "$out\font_report.json"
python (Join-Path $PSScriptRoot 'font_contact.py') $out
Write-Output "font sheet written to $out"
