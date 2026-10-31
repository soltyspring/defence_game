# 06-services: try a debug-signed test AAB from a clean snapshot. Owner: 06-services.
# Usage (workspace root): pwsh -NoProfile -File tests/services/try_debug_aab.ps1 [-Ref HEAD] [-TimeoutSec 480]
# Scratch only: git archive <Ref> into %TEMP%, then IN THE SCRATCH COPY set use_gradle_build=true and
# export_format=1 (AAB), install Godot's Android build template there, and export with the debug
# keystore from the editor settings. 02's export_presets.cfg and 04's tools/build/* are never changed.
# No upload key is created and nothing is uploaded. Output: %TEMP%\svc06_aab_<sha>\out\ + export.log.
param([string]$Ref = 'HEAD', [int]$TimeoutSec = 480, [string]$JavaHome = '', [string]$Bundletool = '')
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
$null = $p.Handle
# Godot finishes the export step in about a minute, but may not exit afterwards; cap it separately.
$godotCap = [Math]::Min($TimeoutSec, 240)
if (-not $p.WaitForExit($godotCap * 1000)) { $p.Kill($true); "Godot did not exit within $godotCap s (process tree killed; export step result is in the log)" | Out-File $log -Append }
else { "export exit $($p.ExitCode)" | Out-File $log -Append }
Get-Content (Join-Path $snap 'export_stdout.log'), (Join-Path $snap 'export_stderr.log') -ErrorAction SilentlyContinue | Out-File $log -Append
"AAB present: $(Test-Path $aab)" | Out-File $log -Append
# -JavaHome: Godot always sets JAVA_HOME from the editor setting (JDK 25 here), which Gradle 8.11.1
# cannot run on. Re-run Godot's own Gradle command with JAVA_HOME set for THIS process only
# (no system PATH, JAVA_HOME, registry or editor-settings change).
if (-not (Test-Path $aab) -and $JavaHome -ne '') {
  $lines = Get-Content (Join-Path $snap 'export_stdout.log')
  $i = [array]::IndexOf($lines, ($lines | Where-Object { $_ -match 'Build Android project using gradle command' } | Select-Object -First 1))
  if ($i -ge 0) {
    $cmd = $lines[$i + 1].Trim()
    $exe = $cmd.Substring(0, $cmd.IndexOf(' ')).Replace('/', '\')
    $args2 = $cmd.Substring($cmd.IndexOf(' ') + 1)
    $env:JAVA_HOME = $JavaHome
    $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    "== gradle rerun with JAVA_HOME=$JavaHome (process only)" | Out-File $log -Append
    # cmd /c treats forward-slash paths as switches; run from a temp .cmd with a backslash exe path.
    $bat = Join-Path $snap 'svc06_gradle.cmd'
    [IO.File]::WriteAllText($bat, "@echo off`r`nset `"JAVA_HOME=$JavaHome`"`r`ncall `"$exe`" $args2 --no-daemon`r`n")
    $gp = Start-Process -FilePath $bat -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $snap 'gradle_stdout.log') -RedirectStandardError (Join-Path $snap 'gradle_stderr.log')
    $null = $gp.Handle
    if (-not $gp.WaitForExit($TimeoutSec * 1000)) { $gp.Kill($true); "GRADLE TIMEOUT after $TimeoutSec s" | Out-File $log -Append } else { "gradle exit $($gp.ExitCode)" | Out-File $log -Append }
    Get-Content (Join-Path $snap 'gradle_stdout.log'), (Join-Path $snap 'gradle_stderr.log') -ErrorAction SilentlyContinue | Select-String -Pattern 'BUILD|What went wrong|FAILURE|error:|> ' | Select-Object -First 30 | ForEach-Object { $_.Line } | Out-File $log -Append
    $built = Get-ChildItem (Join-Path $snap 'android\build\build\outputs\bundle') -Recurse -Filter *.aab -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($built) { Copy-Item $built.FullName $aab; "AAB from gradle: $($built.FullName) $($built.Length) B" | Out-File $log -Append }
  } else { "no gradle command found in the Godot log" | Out-File $log -Append }
}
"AAB present (final): $(Test-Path $aab)" | Out-File $log -Append
# -Bundletool: per-device APKs and checks (debug keystore from the editor settings, test only).
if ((Test-Path $aab) -and $Bundletool -ne '' -and $JavaHome -ne '') {
  $java = Join-Path $JavaHome 'bin\java.exe'
  $ks = Join-Path $Root 'tools\engine\editor_data\keystores\debug.keystore'
  $apks = Join-Path $out 'defence-debug.apks'
  "== bundletool" | Out-File $log -Append
  & $java -jar $Bundletool dump config --bundle=$aab *>> (Join-Path $out 'bt_config.txt')
  & $java -jar $Bundletool dump manifest --bundle=$aab *>> (Join-Path $out 'bt_manifest.xml')
  & $java -jar $Bundletool build-apks --bundle=$aab --output=$apks --ks=$ks --ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android --overwrite *>> $log
  & $java -jar $Bundletool get-size total --apks=$apks --dimensions=ABI,SDK *>> (Join-Path $out 'bt_size.csv')
  & $java -jar $Bundletool build-apks --bundle=$aab --output=(Join-Path $out 'universal.apks') --mode=universal --ks=$ks --ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android --overwrite *>> $log
  Expand-Archive (Join-Path $out 'universal.apks') -DestinationPath (Join-Path $out 'universal') -Force
  Expand-Archive $apks -DestinationPath (Join-Path $out 'split') -Force
  "bundletool done; outputs in $out" | Out-File $log -Append
}
Write-Output "snapshot: $snap"
Get-Content $log | Select-String -Pattern 'exit|TIMEOUT|AAB present|ERROR|error:|FAILURE|What went wrong|Unsupported|major version|Java|JDK|Gradle|NDK|license|BUILD' | Select-Object -First 40 | ForEach-Object { $_.Line.Trim() }
