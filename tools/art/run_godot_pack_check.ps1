# 03-art: prove atlases (and fonts) load from an EXPORTED pack, where raw source PNGs/TTFs
# are absent and only imported .ctex/.fontdata + include_filter json exist.
# Usage (workspace root): pwsh tools/art/run_godot_pack_check.ps1
# Headless only (no window). Uses a throwaway copy in %TEMP%; never touches the main .godot cache.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$G = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (!(Test-Path $G)) { throw "Godot not found at $G (installed by 02-engine)" }
$tmp = Join-Path $env:TEMP 'defence_art_pack'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force "$tmp\assets\atlases", "$tmp\out" | Out-Null
Copy-Item "$PSScriptRoot\godot_check\*" $tmp
Copy-Item "$root\assets\manifest.json" "$tmp\assets\"
Copy-Item "$root\assets\atlases\*" "$tmp\assets\atlases\" -Exclude *.import
if (Test-Path "$root\assets\fonts") {
  New-Item -ItemType Directory -Force "$tmp\assets\fonts" | Out-Null
  Copy-Item "$root\assets\fonts\*" "$tmp\assets\fonts\" -Exclude *.import
}
$out = Join-Path $root 'docs\art\evidence'
New-Item -ItemType Directory -Force $out | Out-Null
$imp = & $G --headless --path $tmp --import 2>&1
$exp = & $G --headless --path $tmp --export-pack "PackCheck" "$tmp\out\check.pck" 2>&1
($imp + $exp) | ForEach-Object { "$_".TrimEnd() } | Out-File -Encoding utf8 "$out\pack_export.log"
if (!(Test-Path "$tmp\out\check.pck")) { throw "export-pack failed; see $out\pack_export.log" }
# list what is inside the pack (file names only)
$runDir = Join-Path $tmp 'run'
New-Item -ItemType Directory -Force $runDir | Out-Null
Push-Location $runDir
try { $log = & $G --headless --main-pack "$tmp\out\check.pck" -- --pack-check 2>&1 } finally { Pop-Location }
$line = $log | Where-Object { "$_" -like 'ART_PACK_JSON *' } | Select-Object -Last 1
$log | ForEach-Object { "$_".TrimEnd() } | Out-File -Encoding utf8 "$out\pack_run.log"
if (!$line) { throw "no ART_PACK_JSON line; see $out\pack_run.log" }
$json = "$line".Substring(14)
$pck = Get-Item "$tmp\out\check.pck"
$rep = $json | ConvertFrom-Json
$rep | Add-Member -NotePropertyName pck_bytes -NotePropertyValue $pck.Length
$rep | ConvertTo-Json -Depth 6 | Out-File -Encoding utf8 "$out\pack_check.json"
Write-Output ($rep | ConvertTo-Json -Depth 6)
