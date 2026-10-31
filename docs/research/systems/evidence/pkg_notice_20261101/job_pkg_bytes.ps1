# Heavy job (10-research-systems, v0.33): build the two package paths from ONE pinned commit and measure the packed
# data bytes. Run ONLY via: & .\coordination\heavy_run_detached.ps1 -Label 10-pkg-bytes -ScriptFile <this file>
# No install, no emulator, no device. Real user folder untouched (both scripts set a private APPDATA themselves).
$ErrorActionPreference = 'Continue'
$p10Root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
Set-Location -LiteralPath $p10Root
$p10Sha = 'eb8d5c43c48500399956a41786a66ac102ba1b2a'
$p10Out = Join-Path $PSScriptRoot 'pkg_eb8d5c4'
$p10Cv = Join-Path $p10Root 'docs\research\systems\probes\content_version.py'
$p10Jdk = Join-Path $env:LOCALAPPDATA 'svc06_tools\jdk-17.0.20.1+1'
$p10Bt = Join-Path $env:LOCALAPPDATA 'svc06_tools\bundletool-all-1.18.3.jar'
$p10T0 = Get-Date
Remove-Item -Recurse -Force $p10Out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $p10Out | Out-Null
"P10 job start $($p10T0.ToString('s')) sha=$p10Sha"
# --- (1) 04 path: tools/build/build_android_debug.ps1 (its own git archive, isolated APPDATA, --export-debug) ---
"P10 APK build start $(Get-Date -Format s)"
pwsh -NoProfile -File (Join-Path $p10Root 'tools\build\build_android_debug.ps1') -Ref $p10Sha -OutDir (Join-Path $p10Out 'apk') *>&1 | ForEach-Object { "APK| $_" }
"P10 APK build exit=$LASTEXITCODE $(Get-Date -Format s)"
$p10Apk = Join-Path $p10Out 'apk\defence-debug.apk'
# --- (2) 06 path: tests/services/try_debug_aab.ps1 with the private JDK 17 (exact command from 06 handoff) ---
"P10 AAB build start $(Get-Date -Format s)"
pwsh -NoProfile -File (Join-Path $p10Root 'tests\services\try_debug_aab.ps1') -Ref $p10Sha -TimeoutSec 900 -JavaHome $p10Jdk -Bundletool $p10Bt *>&1 | ForEach-Object { "AAB| $_" }
"P10 AAB build exit=$LASTEXITCODE $(Get-Date -Format s)"
$p10Snap = Get-ChildItem $env:TEMP -Directory -Filter 'svc06_aab_*' | Where-Object { $_.LastWriteTime -ge $p10T0 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$p10Aab = $null
if ($p10Snap) {
  $p10A = Get-ChildItem (Join-Path $p10Snap.FullName 'out') -Filter '*.aab' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p10A) { Copy-Item $p10A.FullName (Join-Path $p10Out 'defence-debug.aab'); $p10Aab = Join-Path $p10Out 'defence-debug.aab' }
  $p10Chk = Join-Path $p10Snap.FullName 'out\aab_data_check.txt'
  if (Test-Path $p10Chk) { Copy-Item $p10Chk (Join-Path $p10Out 'aab_data_check_06.txt') }
  "P10 AAB scratch $($p10Snap.FullName) aab=$([bool]$p10A)"
  Remove-Item -Recurse -Force $p10Snap.FullName -ErrorAction SilentlyContinue   # 06's documented cleanup of this run's own scratch copy
}
# Gradle daemons started by THIS job only (06 handoff cleanup rule)
Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -like '*svc06_tools*' -and $_.CreationDate -ge $p10T0 } |
  ForEach-Object { "P10 stopping this job's Gradle/java pid=$($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
# --- (3) measure packed bytes ---
foreach ($p10P in @($p10Apk, $p10Aab)) {
  if ($p10P -and (Test-Path $p10P)) { "P10 PKG " + (python $p10Cv --apk $p10P) } else { "P10 PKG MISSING $p10P" }
}
"P10 REPO " + (python $p10Cv $p10Sha)
"P10 job end $(Get-Date -Format s)"
$global:LASTEXITCODE = 0
