# 06-services: try a debug-signed test AAB from a clean snapshot. Owner: 06-services.
# Usage (workspace root): pwsh -NoProfile -File tests/services/try_debug_aab.ps1 [-Ref HEAD] [-TimeoutSec 480]
# Scratch only: git archive <Ref> into %TEMP%, then IN THE SCRATCH COPY set use_gradle_build=true and
# export_format=1 (AAB), install Godot's Android build template there, and export with the debug
# keystore from the editor settings. 02's export_presets.cfg and 04's tools/build/* are never changed.
# No upload key is created and nothing is uploaded. Output: %TEMP%\svc06_aab_<sha>\out\ + export.log.
param([string]$Ref = 'HEAD', [int]$TimeoutSec = 480)
$ErrorActionPreference = 'Continue'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root
$G = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$sha = (git rev-parse --short $Ref).Trim()
$snap = Join-Path $env:TEMP "svc06_aab_$sha"
Remove-Item $snap -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $snap | Out-Null
git archive --format=zip -o "$snap.zip" $Ref; Expand-Archive "$snap.zip" -DestinationPath $snap -Force; Remove-Item "$snap.zip"
$ep = Join-Path $snap 'export_presets.cfg'
$t = [IO.File]::ReadAllText($ep)
$t = $t -replace '(?m)^gradle_build/use_gradle_build=.*$', 'gradle_build/use_gradle_build=true'
$t = $t -replace '(?m)^gradle_build/export_format=.*$', 'gradle_build/export_format=1'
[IO.File]::WriteAllText($ep, $t, (New-Object System.Text.UTF8Encoding($false)))
$out = Join-Path $snap 'out'; New-Item -ItemType Directory $out | Out-Null
$log = Join-Path $snap 'export.log'
"== import" | Out-File $log
& $G --headless --path $snap --import *>> $log
"== install build template" | Out-File $log -Append
& $G --headless --path $snap --install-android-build-template --quit *>> $log
if (-not (Test-Path (Join-Path $snap 'android\build'))) {
  # Same layout the editor's "Install Android Build Template" creates (scratch copy only).
  $tpl = Join-Path $Root 'tools\engine\editor_data\export_templates\4.7.2.stable\android_source.zip'
  New-Item -ItemType Directory -Force (Join-Path $snap 'android\build') | Out-Null
  Expand-Archive $tpl -DestinationPath (Join-Path $snap 'android\build') -Force
  [IO.File]::WriteAllText((Join-Path $snap 'android\.build_version'), '4.7.2.stable')
  [IO.File]::WriteAllText((Join-Path $snap 'android\build\.gdignore'), '')
  "manual template install from android_source.zip" | Out-File $log -Append
}
"install exit $LASTEXITCODE; android/build exists: $(Test-Path (Join-Path $snap 'android\build'))" | Out-File $log -Append
"== export (timeout $TimeoutSec s)" | Out-File $log -Append
$aab = Join-Path $out 'defence-debug.aab'
$p = Start-Process -FilePath $G -ArgumentList @('--headless', '--verbose', '--path', $snap, '--export-debug', 'Android', $aab) -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $snap 'export_stdout.log') -RedirectStandardError (Join-Path $snap 'export_stderr.log')
if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill($true); "TIMEOUT after $TimeoutSec s (process tree killed)" | Out-File $log -Append }
else { "export exit $($p.ExitCode)" | Out-File $log -Append }
Get-Content (Join-Path $snap 'export_stdout.log'), (Join-Path $snap 'export_stderr.log') -ErrorAction SilentlyContinue | Out-File $log -Append
"AAB present: $(Test-Path $aab)" | Out-File $log -Append
Write-Output "snapshot: $snap"
Get-Content $log | Select-String -Pattern 'exit|TIMEOUT|AAB present|ERROR|error:|FAILURE|What went wrong|Unsupported|major version|Java|JDK|Gradle|NDK|license|BUILD' | Select-Object -First 40 | ForEach-Object { $_.Line.Trim() }
