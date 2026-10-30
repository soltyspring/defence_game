# 03-art: import the real atlas pages in a throwaway Godot project and measure them.
# Usage (workspace root): pwsh tools/art/run_godot_check.ps1
# Writes docs/art/evidence/godot_check.json + screenshots. Never touches the main project or its .godot cache.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$G = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (!(Test-Path $G)) { throw "Godot not found at $G (installed by 02-engine)" }
$tmp = Join-Path $env:TEMP 'defence_art_check'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force "$tmp\assets\atlases" | Out-Null
Copy-Item "$PSScriptRoot\godot_check\*" $tmp
Copy-Item "$root\assets\manifest.json" "$tmp\assets\"
Copy-Item "$root\assets\atlases\*" "$tmp\assets\atlases\" -Exclude *.import
$out = Join-Path $root 'docs\art\evidence'
New-Item -ItemType Directory -Force $out | Out-Null
& $G --headless --path $tmp --import 2>&1 | Out-File -Encoding utf8 "$out\godot_import.log"
# Visible run MUST be on the secondary monitor (coordination/QUALITY_REVIEW.md).
Add-Type -AssemblyName System.Windows.Forms
$sec = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (!$sec) { throw 'BLOCKED: no secondary monitor detected; visible Godot check not run.' }
$wa = $sec.WorkingArea
$px = $wa.X + [int](($wa.Width - 1280) / 2); $py = $wa.Y + [int](($wa.Height - 720) / 2)
"monitor=$($sec.DeviceName) work_area=$($wa.X),$($wa.Y),$($wa.Width)x$($wa.Height) (Windows coords); window is moved by check.gd to Godot's non-primary screen" | Out-File -Encoding utf8 "$out\godot_window.txt"
$log = & $G --path $tmp --rendering-driver opengl3 --resolution 1280x720 2>&1
$log | Out-File -Encoding utf8 "$out\godot_run.log"
$line = $log | Where-Object { "$_" -like 'ART_CHECK_JSON *' } | Select-Object -Last 1
if (!$line) { throw "no ART_CHECK_JSON line; see $out\godot_run.log" }
$json = "$line".Substring(15)
$json | Out-File -Encoding utf8 "$out\godot_check.json"
$rep = $json | ConvertFrom-Json
Copy-Item (Join-Path $rep.user_dir 'battle_cap_1x.png') $out -Force
Copy-Item (Join-Path $rep.user_dir 'battle_cap_zoom4_fractional.png') $out -Force
# imported size inside the throwaway cache (proxy for PCK texture payload)
$ctex = Get-ChildItem "$tmp\.godot\imported" -Filter *.ctex
"imported_ctex_bytes=" + (($ctex | Measure-Object Length -Sum).Sum) | Out-File -Append -Encoding utf8 "$out\godot_check.json"
$ctex | Select-Object Name, Length | Format-Table | Out-String | Out-File -Encoding utf8 "$out\godot_ctex_sizes.txt"
Write-Output $json
