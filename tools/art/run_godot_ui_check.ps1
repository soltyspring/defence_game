# 03-art: reproduce + verify the ui_main stale-import defect (04 R4) in an ISOLATED copy.
# Usage (workspace root): pwsh tools/art/run_godot_ui_check.ps1 [-StaleFrom <commit>]
#   STALE   : import ui_main from <StaleFrom> (old pixels), then drop in the current png/json
#             WITHOUT re-import  == the condition 04 saw (cache source_md5 != png md5).
#   FIXED   : same project after `--import` (cache refreshed).
# Each state renders the ui_main contact sheet through Godot (window on the secondary
# monitor, moved by check.gd) and reads back every frame of every page vs the raw PNG.
param([string]$StaleFrom = 'abd327d')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$G = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$tmp = Join-Path $env:TEMP 'defence_art_ui'
$out = Join-Path $root 'docs\art\evidence\ui_import'
$ud = Join-Path $env:APPDATA 'Godot\app_userdata\defence-art-check'
New-Item -ItemType Directory -Force $out | Out-Null
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force "$tmp\assets\atlases" | Out-Null
Copy-Item "$PSScriptRoot\godot_check\*" $tmp
Copy-Item "$root\assets\manifest.json" "$tmp\assets\"
Copy-Item "$root\assets\atlases\*" "$tmp\assets\atlases\"      # incl. committed .import (same uid/path)
# 1) old ui_main pixels + rects, import them
Push-Location $root
try {
  cmd /c "git show ${StaleFrom}:assets/atlases/ui_main.png > `"$tmp\assets\atlases\ui_main.png`""
  cmd /c "git show ${StaleFrom}:assets/atlases/ui_main.json > `"$tmp\assets\atlases\ui_main.json`""
} finally { Pop-Location }
& $G --headless --path $tmp --import 2>&1 | Out-Null
# 2) current png/json WITHOUT re-import  -> stale cache
Copy-Item "$root\assets\atlases\ui_main.png", "$root\assets\atlases\ui_main.json" "$tmp\assets\atlases\" -Force
function Run-State([string]$state) {
  Remove-Item "$ud\ui_sheet_report.json", "$ud\ui_main_godot_sheet.png", "$ud\ui_sheet_layout.json" -ErrorAction SilentlyContinue
  $md5file = Get-ChildItem "$tmp\.godot\imported\ui_main.png-*.md5" | Select-Object -First 1
  $cache = ((Get-Content $md5file.FullName) -match 'source_md5') -replace 'source_md5="(.*)"', '$1'
  $png = (Get-FileHash -Algorithm MD5 "$tmp\assets\atlases\ui_main.png").Hash.ToLower()
  # --editor-less run without auto-reimport: Godot re-imports changed sources only in editor/--import
  & $G --path $tmp --rendering-driver opengl3 --resolution 640x360 -- --ui-sheet 2>&1 | ForEach-Object { "$_".TrimEnd() } | Out-File -Encoding utf8 "$out\run_$state.log"
  $rep = [IO.File]::ReadAllText("$ud\ui_sheet_report.json", [Text.Encoding]::UTF8) | ConvertFrom-Json
  $rep | Add-Member -NotePropertyName state -NotePropertyValue $state
  $rep | Add-Member -NotePropertyName cache_source_md5 -NotePropertyValue "$cache"
  $rep | Add-Member -NotePropertyName png_md5 -NotePropertyValue $png
  $rep | ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 "$out\report_$state.json"
  Copy-Item "$ud\ui_main_godot_sheet.png" "$out\ui_main_godot_sheet_$state.png" -Force
  Copy-Item "$ud\ui_sheet_layout.json" "$out\ui_sheet_layout.json" -Force
  $ui = $rep.pages | Where-Object id -eq 'ui_main'
  $others = ($rep.pages | Where-Object id -ne 'ui_main' | Measure-Object mismatch -Sum).Sum
  "{0}: cache={1} png={2} ui_main mismatched frames={3}/{4} other pages mismatched={5} screen={6}/primary={7}" -f $state, $cache.Substring(0,8), $png.Substring(0,8), $ui.mismatch, $ui.frames, $others, $rep.window_screen, $rep.primary_screen
}
Run-State 'stale'
& $G --headless --path $tmp --import 2>&1 | Out-Null
Run-State 'fixed'
python (Join-Path $PSScriptRoot 'ui_sheet_compare.py') $out
