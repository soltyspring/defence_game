# Runs 05-audio Godot checks in an ISOLATED copy of the project so this worker never touches the
# shared .godot import cache or competes with other workers' editors/imports. Owner: 05-audio.
# Usage (workspace root):  pwsh tools/audio/run_godot_checks.ps1
# Exit code 0 = parser checks + import + audio selftest pass.
$ErrorActionPreference = 'Continue'   # Godot writes diagnostics to stderr; judge by exit codes
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godot = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) { Write-Error "Godot console not found: $godot"; exit 2 }
$sb = Join-Path ([IO.Path]::GetTempPath()) 'defence_audio_sandbox'
if (Test-Path $sb) { Remove-Item -LiteralPath $sb -Recurse -Force }
New-Item -ItemType Directory -Path $sb | Out-Null
Copy-Item (Join-Path $root 'project.godot') $sb
if (Test-Path (Join-Path $root 'icon.svg')) { Copy-Item (Join-Path $root 'icon.svg') $sb }
foreach ($d in @('src', 'data', 'scenes', 'assets\audio')) {
  $src = Join-Path $root $d
  if (Test-Path $src) {
    $dst = Join-Path $sb $d
    New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
    Copy-Item $src $dst -Recurse
  }
}
New-Item -ItemType Directory -Path (Join-Path $sb 'tools\audio') -Force | Out-Null
Copy-Item (Join-Path $root 'tools\audio\audio_selftest.gd') (Join-Path $sb 'tools\audio')
# strip foreign .import files/caches copied from the workspace; the sandbox imports fresh
Get-ChildItem $sb -Recurse -Filter '*.import' | Remove-Item -Force
$fail = 0
& $godot --headless --path $sb --import 2>&1 | Select-String -Pattern 'ERROR|error|audio' | Select-Object -First 20 | ForEach-Object { "import: $_" }
foreach ($s in @('res://src/audio/audio_manager.gd', 'res://src/audio/audio_event_bridge.gd', 'res://tools/audio/audio_selftest.gd')) {
  $out = & $godot --headless --path $sb --check-only --script $s 2>&1
  if ($LASTEXITCODE -ne 0) { $fail++; "PARSE FAIL $s"; $out | Select-Object -Last 15 } else { "PARSE OK $s" }
}
$out = & $godot --headless --path $sb -s res://tools/audio/audio_selftest.gd 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { "$_" }
if ($code -ne 0) { $fail++ }
# import evidence: what Godot decided for our files
$imp = Get-ChildItem (Join-Path $sb 'assets\audio') -Recurse -Filter '*.import' | Measure-Object
"imported_files=$($imp.Count)"
Get-ChildItem (Join-Path $sb 'assets\audio\sfx') -Filter 'ui_tap.wav.import' | ForEach-Object { Get-Content $_.FullName | Select-String 'compress|importer|edit/' }
Get-ChildItem (Join-Path $sb 'assets\audio\music') -Filter '*.import' | Select-Object -First 1 | ForEach-Object { Get-Content $_.FullName | Select-String 'importer|loop' }
"GODOT AUDIO CHECKS " + $(if ($fail -eq 0) { 'PASS' } else { "FAIL ($fail)" })
exit $fail
