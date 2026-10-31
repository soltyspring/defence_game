# 06-services: install a test AAB on an Android emulator and check launch, title, crash, labels, save persistence.
# Owner: 06-services. ONLY inside the PC-wide lock:
#   & .\coordination\heavy_run.ps1 -Label '06-emu-check' -Script { pwsh -NoProfile -File tests/services/emu_install_check.ps1 -Aab <aab> -OutDir <dir> }
# Emulator: uses an already running device if there is one (never stops it). Otherwise it starts
# build/avd LaneDefence_Phone itself with -no-window -no-snapshot-save -read-only (the AVD files are not
# changed) and stops only that instance with `adb emu kill` at the end.
# EMULATOR EVIDENCE ONLY: not a real-phone check, and nothing about real payments (Q2 deferred: ads and
# billing disabled). Debug key; nothing is uploaded.
param([Parameter(Mandatory)][string]$Aab, [Parameter(Mandatory)][string]$OutDir, [int]$Port = 5590,
      [string]$JavaHome = "$env:LOCALAPPDATA\svc06_tools\jdk-17.0.20.1+1", [string]$Bundletool = "$env:LOCALAPPDATA\svc06_tools\bundletool-all-1.18.3.jar")
$ErrorActionPreference = 'Continue'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root
. (Join-Path $PSScriptRoot 'svc06_isolation.ps1')
Assert-SvcHeavyLock
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emu = Join-Path $sdk 'emulator\emulator.exe'
$aapt2 = Join-Path $sdk 'build-tools\36.1.0\aapt2.exe'
$java = Join-Path $JavaHome 'bin\java.exe'
$ks = Join-Path $Root 'tools\engine\editor_data\keystores\debug.keystore'
$pkg = 'com.soltyspring.lanedefence'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$work = Join-Path $env:TEMP ("svc06_emu_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $work | Out-Null
$R = [ordered]@{ started_at = (Get-Date).ToString('s'); aab = $Aab; aab_sha256 = (Get-FileHash $Aab).Hash; evidence_kind = 'emulator only (not a real phone, no real payments)' }
function A { & $adb -s $script:serial @args 2>&1 }
function Note($k, $v) { $script:R[$k] = $v; Write-Output ("{0}: {1}" -f $k, ($v | Out-String).Trim()) }

# ---- 1. device
& $adb start-server *> $null
$devs = @(& $adb devices | Select-String '^(emulator-\d+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
$mine = $false
$emuProc = $null
if ($devs.Count -gt 0) { $script:serial = $devs[0]; Note 'emulator' "already running: $serial (not started by 06; will not be stopped)" }
else {
  $env:ANDROID_AVD_HOME = Join-Path $Root 'build\avd'
  $emuProc = Start-Process -FilePath $emu -ArgumentList @('-avd', 'LaneDefence_Phone', '-no-window', '-no-snapshot-save', '-no-snapshot-load', '-read-only', '-no-audio', '-no-boot-anim', '-gpu', 'host', '-port', "$Port") -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $work 'emu_out.txt') -RedirectStandardError (Join-Path $work 'emu_err.txt')
  $mine = $true; $script:serial = "emulator-$Port"
  Note 'emulator' "started by 06: LaneDefence_Phone on $serial (-no-window -no-snapshot-save -no-snapshot-load -read-only), pid $($emuProc.Id)"
}
function FatalReport([string[]]$lines, [string]$tag) {
  # Attribute crash lines to processes: Java "FATAL EXCEPTION" (+ "Process: x"), native tombstones
  # ("F DEBUG ... >>> x <<<"), "Fatal signal ... (x)"; ANR "ANR in x".
  $procs = @{}
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match 'FATAL EXCEPTION') { $p = 'unknown'; for ($j = $i; $j -lt [Math]::Min($i + 4, $lines.Count); $j++) { if ($lines[$j] -match 'Process: ([\w\.:]+)') { $p = $Matches[1]; break } }; $procs["java:$p"] = 1 + [int]$procs["java:$p"] }
    elseif ($l -match '>>> ([^ ]+) <<<') { $procs["native:$($Matches[1])"] = 1 + [int]$procs["native:$($Matches[1])"] }
    elseif ($l -match 'Fatal signal .*\(([^)]+)\)\s*$') { $procs["signal:$($Matches[1])"] = 1 + [int]$procs["signal:$($Matches[1])"] }
    elseif ($l -match 'ANR in ([\w\.:]+)') { $procs["anr:$($Matches[1])"] = 1 + [int]$procs["anr:$($Matches[1])"] }
  }
  $sel = @($lines | Select-String -Pattern 'FATAL EXCEPTION|Fatal signal|F DEBUG|>>> .* <<<|ANR in|Process: ' | ForEach-Object { $_.Line })
  $sel | Set-Content (Join-Path $OutDir "logcat_fatal_$tag.txt") -Encoding utf8
  $appHits = @($procs.Keys | Where-Object { $_ -match 'com\.soltyspring' })
  return [ordered]@{ matching_lines = @($lines | Select-String -Pattern 'FATAL EXCEPTION|Fatal signal|F DEBUG').Count;
    events_by_process = ($procs.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', ';
    app_crash_or_anr_events = $appHits.Count }
}
$t0 = Get-Date; $booted = $false
while (((Get-Date) - $t0).TotalSeconds -lt 420) {
  $b = (A shell getprop sys.boot_completed | Out-String).Trim()
  if ($b -eq '1') { $booted = $true; break }
  Start-Sleep 5
}
Note 'boot_seconds' ([int]((Get-Date) - $t0).TotalSeconds)
Note 'booted' $booted
if (-not $booted) {
  Note 'adb_devices_at_timeout' ((& $adb devices | Out-String).Trim() -replace "`r?`n", ' | ')
  if ($mine) { Get-Content (Join-Path $work 'emu_out.txt'), (Join-Path $work 'emu_err.txt') -Tail 40 -ErrorAction SilentlyContinue | Set-Content (Join-Path $OutDir 'emu_boot_fail_log.txt') -Encoding utf8 }
}
try {
  if (-not $booted) { throw 'device did not finish booting' }
  Note 'device' ((A shell getprop ro.product.model | Out-String).Trim() + ' / Android ' + (A shell getprop ro.build.version.release | Out-String).Trim() + ' / API ' + (A shell getprop ro.build.version.sdk | Out-String).Trim() + ' / abi ' + (A shell getprop ro.product.cpu.abi | Out-String).Trim())
  # ---- 2. device APK set from the AAB (device spec + ko so the ko language split is included)
  $specJson = Join-Path $work 'spec.json'; $specKo = Join-Path $work 'spec_ko.json'; $setApks = Join-Path $work 'set.apks'; $apksDir = Join-Path $work 'apks'
  $gds = & $java -jar $Bundletool get-device-spec "--adb=$adb" "--device-id=$serial" "--output=$specJson" --overwrite 2>&1 | Out-String
  $spec = $null
  if (Test-Path (Join-Path $work 'spec.json')) { $spec = Get-Content (Join-Path $work 'spec.json') -Raw | ConvertFrom-Json }
  if ($null -eq $spec -or $null -eq $spec.sdkVersion) {
    # Fallback: same fields from the device's own properties (bundletool device-spec JSON format).
    Note 'get_device_spec' ("failed, built from getprop instead: " + ($gds.Trim() -split "`n" | Select-Object -Last 1))
    $abis = @((A shell getprop ro.product.cpu.abilist | Out-String).Trim() -split ',' | Where-Object { $_ })
    $dens = [int]((A shell getprop ro.sf.lcd_density | Out-String).Trim())
    if (-not $dens) { $dens = [int](((A shell wm density | Out-String) -replace '[^0-9]', '')) }
    $spec = [pscustomobject]@{ supportedAbis = $abis; supportedLocales = @('en-US'); screenDensity = $dens; sdkVersion = [int]((A shell getprop ro.build.version.sdk | Out-String).Trim()) }
  }
  $spec | Add-Member -NotePropertyName supportedLocales -NotePropertyValue (@(@($spec.supportedLocales) + @('ko-KR') | Where-Object { $_ } | Select-Object -Unique)) -Force
  $spec | ConvertTo-Json -Depth 6 | Set-Content $specKo -Encoding utf8
  Note 'device_spec_locales' ($spec.supportedLocales -join ',')
  & $java -jar $Bundletool build-apks "--bundle=$Aab" "--output=$setApks" "--device-spec=$specKo" "--ks=$ks" --ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android --overwrite 2>&1 | Out-File (Join-Path $work 'bt_build.txt')
  & $java -jar $Bundletool extract-apks "--apks=$setApks" "--device-spec=$specKo" "--output-dir=$apksDir" 2>&1 | Out-Null
  $apks = @(Get-ChildItem $apksDir -Filter *.apk -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($apks.Count -eq 0) { throw ('bundletool produced no APKs: ' + ((Get-Content (Join-Path $work 'bt_build.txt') -ErrorAction SilentlyContinue | Select-Object -Last 2) -join ' ')) }
  Note 'apk_set' (($apks | ForEach-Object { "{0} ({1} B)" -f $_.Name, $_.Length }) -join '; ')
  $pre = (A shell pm list packages $pkg | Out-String).Trim()
  Note 'package_before' $(if ($pre) { 'installed' } else { 'absent' })
  if ($pre -and $mine) { A uninstall $pkg | Out-Null; Note 'pre_uninstall' 'removed old install on the read-only instance (AVD files unchanged)' }
  $ins = (A install-multiple -r ($apks | ForEach-Object { $_.FullName }) | Out-String).Trim()
  Note 'install' $ins
  # labels of the installed package (pulled from the device)
  $paths = @(A shell pm path $pkg | ForEach-Object { "$_".Trim() -replace '^package:', '' } | Where-Object { $_ })
  Note 'installed_paths' ($paths -join '; ')
  $pulled = Join-Path $work 'pulled'; New-Item -ItemType Directory $pulled | Out-Null
  foreach ($p in $paths) { A pull $p (Join-Path $pulled (Split-Path $p -Leaf)) | Out-Null }
  $base = Join-Path $pulled 'base.apk'
  $badg = & $aapt2 dump badging $base 2>$null
  Note 'installed_target_sdk' (($badg | Select-String "^targetSdkVersion" | ForEach-Object { $_.Line }) -join '')
  Note 'installed_label_default' (($badg | Select-String "^application-label:" | ForEach-Object { $_.Line }) -join '')
  $labels = @()
  foreach ($f in Get-ChildItem $pulled -Filter *.apk) {
    $vals = & $aapt2 dump strings $f.FullName 2>$null | Out-String
    if ($vals -match '빵집 기사단') { $labels += "$($f.Name): contains '빵집 기사단'" }
  }
  Note 'installed_ko_label' $(if ($labels) { $labels -join '; ' } else { 'ko label string not found in installed splits' })
  # ---- 3. first launch
  A logcat -c | Out-Null
  A shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
  Start-Sleep 25
  $pid1 = (A shell pidof $pkg | Out-String).Trim()
  Note 'first_launch_pid' $(if ($pid1) { $pid1 } else { 'NOT RUNNING' })
  cmd /c "`"$adb`" -s $serial exec-out screencap -p > `"$OutDir\emu_first_launch.png`""
  $g1 = @(A logcat -d -s godot:V | ForEach-Object { "$_" })
  $g1 | Set-Content (Join-Path $OutDir 'logcat_godot_first_launch.txt') -Encoding utf8
  Note 'first_boot_line' (($g1 | Select-String '\[App\] boot ok' | Select-Object -First 1 | ForEach-Object { $_.Line.Substring($_.Line.IndexOf('[App]')) }) -join '')
  $all1 = @(A logcat -d -v threadtime | ForEach-Object { "$_" })
  Note 'first_fatal' (FatalReport $all1 'first_launch' | ConvertTo-Json -Compress)
  Note 'first_anr' @($all1 | Select-String -Pattern 'ANR in').Count
  Note 'first_godot_errors' @($g1 | Select-String -Pattern 'ERROR|SCRIPT ERROR').Count
  # ---- 4. save persistence: seed a valid save, let the game rewrite it, force-stop, relaunch
  A shell am force-stop $pkg | Out-Null
  $payload = '{"version":1,"revision":7,"unlocked_round":2,"stars":{},"best_time":{},"coins":4321,"clears":1,"tutorial_done":[],"upgrades":{},"upgrade_paid":{},"applied_battles":[],"settings":{"fps_cap":60,"sfx":1.0,"music":0.8,"show_damage":true,"screen_shake":true}}'
  $sha = [Security.Cryptography.SHA256]::Create()
  $chk = (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)) | ForEach-Object { $_.ToString('x2') }) -join '')
  $env1 = [ordered]@{ version = 1; checksum = $chk; payload = $payload } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText((Join-Path $work 'seed.json'), $env1, (New-Object Text.UTF8Encoding($false)))
  A push (Join-Path $work 'seed.json') /data/local/tmp/svc06_seed.json | Out-Null
  A shell "run-as $pkg sh -c 'cp /data/local/tmp/svc06_seed.json files/save.json && ls -l files'" | Out-Null
  A shell rm /data/local/tmp/svc06_seed.json | Out-Null
  function ReadSave { $o = (A shell "run-as $pkg cat files/save.json" | Out-String); $o.Trim() }
  function SaveInfo($txt) {
    try { $e = $txt | ConvertFrom-Json; $p = $e.payload | ConvertFrom-Json; return [ordered]@{ sha = ((($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($txt))) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16); revision = $p.revision; coins = $p.coins; unlocked_round = $p.unlocked_round; content_version = $p.content_version } }
    catch { return [ordered]@{ sha = 'unreadable'; raw = $txt.Substring(0, [Math]::Min(80, $txt.Length)) } }
  }
  Note 'seed' (SaveInfo $env1 | ConvertTo-Json -Compress)
  A logcat -c | Out-Null
  A shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
  Start-Sleep 20
  $s1 = ReadSave
  $g2 = @(A logcat -d -s godot:V | ForEach-Object { "$_" })
  Note 'launch2_boot_line' (($g2 | Select-String '\[App\] boot ok' | Select-Object -First 1 | ForEach-Object { $_.Line.Substring($_.Line.IndexOf('[App]')) }) -join '')
  Note 'save_after_launch2 (game rewrote seed)' (SaveInfo $s1 | ConvertTo-Json -Compress)
  A shell am force-stop $pkg | Out-Null
  Note 'force_stop_pid_after' $(if ((A shell pidof $pkg | Out-String).Trim()) { 'still running' } else { 'stopped' })
  A logcat -c | Out-Null
  A shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
  Start-Sleep 20
  $s2 = ReadSave
  $g3 = @(A logcat -d -s godot:V | ForEach-Object { "$_" })
  $g3 | Set-Content (Join-Path $OutDir 'logcat_godot_relaunch.txt') -Encoding utf8
  Note 'launch3_boot_line' (($g3 | Select-String '\[App\] boot ok' | Select-Object -First 1 | ForEach-Object { $_.Line.Substring($_.Line.IndexOf('[App]')) }) -join '')
  Note 'save_after_forcestop_relaunch' (SaveInfo $s2 | ConvertTo-Json -Compress)
  Note 'save_kept_identical' ($s1 -eq $s2 -and $s1 -ne '')
  $all3 = @(A logcat -d -v threadtime | ForEach-Object { "$_" })
  Note 'relaunch_pid' $(if ((A shell pidof $pkg | Out-String).Trim()) { 'running' } else { 'NOT RUNNING' })
  Note 'relaunch_fatal' (FatalReport $all3 'relaunch' | ConvertTo-Json -Compress)
  Note 'relaunch_anr' @($all3 | Select-String -Pattern 'ANR in').Count
  cmd /c "`"$adb`" -s $serial exec-out screencap -p > `"$OutDir\emu_relaunch.png`""
  A shell am force-stop $pkg | Out-Null
  if ($mine) { A uninstall $pkg | Out-Null }
} catch { Note 'error' "$_" }
finally {
  if ($mine) {
    & $adb -s $serial emu kill 2>&1 | Out-Null
    if ($emuProc) { if (-not $emuProc.WaitForExit(90000)) { Note 'emulator_stop' 'did not exit in 90 s' } else { Note 'emulator_stop' "adb emu kill: exited ($($emuProc.ExitCode))" } }
  }
  Start-Sleep 3
  Note 'qemu_left' @(Get-Process -Name 'qemu-system*' -ErrorAction SilentlyContinue).Count
  Note 'gradle_java_left' @(Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'gradle-8\.11\.1|svc06_tools' }).Count
  $R | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'emu_check.json') -Encoding utf8
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
