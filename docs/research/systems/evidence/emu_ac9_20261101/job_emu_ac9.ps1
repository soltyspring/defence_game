# Heavy job (10-research-systems, v0.34): AC9 emulator part. Install the eb8d5c4 debug APK (04 path, measured in v0.33)
# on build/avd LaneDefence_Phone started HERE with -no-window -read-only (AVD files unchanged), seed older-version saves
# through run-as, boot, and read back content_version / migration result / notice from the device files + logcat.
# EMULATOR EVIDENCE ONLY (not a real phone). Run ONLY via coordination/heavy_run_detached.ps1. Variables prefixed p10.
# Never stops an emulator it did not start: if qemu or an emulator device is already present it waits (max 10 min)
# and then gives up without touching it.
$ErrorActionPreference = 'Continue'
$p10Root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
Set-Location -LiteralPath $p10Root
$p10Apk = Join-Path $PSScriptRoot 'pkg_eb8d5c4\apk\defence-debug.apk'
$p10Out = Join-Path $PSScriptRoot 'emu_ac9'
$p10Sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$p10Adb = Join-Path $p10Sdk 'platform-tools\adb.exe'
$p10Emu = Join-Path $p10Sdk 'emulator\emulator.exe'
$p10Pkg = 'com.soltyspring.lanedefence'
$p10Port = 5594
$p10Serial = "emulator-$p10Port"
$p10U8 = New-Object Text.UTF8Encoding($false)
Remove-Item -Recurse -Force $p10Out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $p10Out | Out-Null
function P10Sha([string]$f) { if (Test-Path -LiteralPath $f) { (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.Substring(0, 16) } else { 'missing' } }
"P10 job start $(Get-Date -Format s) apk_sha16=$(P10Sha $p10Apk)"
# ---- 0. somebody else's emulator? wait, never stop it
$p10AdbWasRunning = @(Get-Process -Name 'adb' -ErrorAction SilentlyContinue).Count -gt 0
& $p10Adb start-server *> $null
$p10Waited = 0
while ($true) {
  $p10Q = @(Get-Process -Name 'qemu-system*' -ErrorAction SilentlyContinue)
  $p10D = @(& $p10Adb devices | Select-String '^(emulator-\d+)\s+(device|offline)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
  if ($p10Q.Count -eq 0 -and $p10D.Count -eq 0) { break }
  if ($p10Waited -ge 600) { "P10 EMU_BUSY qemu=$($p10Q.Count) devices=$($p10D -join ',') after ${p10Waited}s: not touched, job ends"; $global:LASTEXITCODE = 0; return }
  if ($p10Waited % 60 -eq 0) { "P10 waiting for a foreign emulator: qemu=$($p10Q.Count) devices=$($p10D -join ',')" }
  Start-Sleep 15; $p10Waited += 15
}
"P10 no foreign emulator (waited ${p10Waited}s)"
# ---- 1. start OUR instance (06's proven flags; own port)
$env:ANDROID_AVD_HOME = Join-Path $p10Root 'build\avd'
$p10EmuProc = Start-Process -FilePath $p10Emu -ArgumentList @('-avd', 'LaneDefence_Phone', '-no-window', '-no-snapshot-save', '-no-snapshot-load', '-read-only', '-no-audio', '-no-boot-anim', '-gpu', 'swiftshader_indirect', '-port', "$p10Port") -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $p10Out 'emu_out.txt') -RedirectStandardError (Join-Path $p10Out 'emu_err.txt')
"P10 emulator started pid=$($p10EmuProc.Id) serial=$p10Serial gpu=swiftshader_indirect (software; no host GPU after two BSODs)"
function P10A { & $p10Adb -s $p10Serial @args 2>&1 }
function P10Raw([string]$devPath, [string]$dst) { cmd /c "`"$p10Adb`" -s $p10Serial exec-out run-as $p10Pkg cat $devPath > `"$dst`" 2>nul" | Out-Null; return $dst }
function P10Files { ((P10A shell "run-as $p10Pkg ls -l files" | Out-String).Trim() -split "`r?`n" | Where-Object { $_ -match 'save' } | ForEach-Object { ($_ -split '\s+')[-1] + ':' + ($_ -split '\s+')[4] }) -join ' ' }
function P10Info([string]$tag) {
  $f = P10Raw 'files/save.json' (Join-Path $p10Out "save_$tag.json")
  $o = [ordered]@{ tag = $tag; sha16 = (P10Sha $f) }
  try {
    $e = [IO.File]::ReadAllText($f) | ConvertFrom-Json; $p = $e.payload | ConvertFrom-Json
    $o.revision = $p.revision; $o.content_version = $p.content_version; $o.coins = $p.coins; $o.unlocked_round = $p.unlocked_round
    $o.melee = $p.upgrades.up_melee_basic; $o.migration_notice = $p.migration_notice; $o.migrations_applied = $p.migrations_applied
    $o.snapshot_version = $p.content_snapshot.version
  } catch { $o.error = 'unreadable or missing' }
  $o.files = P10Files
  "P10 DEVICE " + ($o | ConvertTo-Json -Compress -Depth 6)
}
function P10Launch([string]$tag, [int]$wait = 25) {
  P10A logcat -c | Out-Null
  P10A shell monkey -p $p10Pkg -c android.intent.category.LAUNCHER 1 | Out-Null
  Start-Sleep $wait
  $pid1 = (P10A shell pidof $p10Pkg | Out-String).Trim()
  $g = @(P10A logcat -d -s godot:V | ForEach-Object { "$_" })
  [IO.File]::WriteAllLines((Join-Path $p10Out "logcat_godot_$tag.txt"), [string[]]$g, $p10U8)
  $all = @(P10A logcat -d -v brief | ForEach-Object { "$_" })
  $fatal = @($all | Select-String -Pattern 'FATAL EXCEPTION|Fatal signal|ANR in' | Where-Object { $_.Line -match 'soltyspring|godot' }).Count
  $boot = ($g | Select-String '\[App\] boot ok' | Select-Object -First 1 | ForEach-Object { $_.Line.Substring($_.Line.IndexOf('[App]')) -replace ' atlas=.*', '' })
  $warn = @($g | Select-String -Pattern 'WARNING|ERROR|\[Save\]|\[Content\]' | ForEach-Object { $_.Line.Trim() } | Select-Object -First 8)
  "P10 LAUNCH $tag pid=$(if ($pid1) { $pid1 } else { 'NOT_RUNNING' }) app_fatal_or_anr=$fatal boot=[$boot]"
  $warn | ForEach-Object { "P10 LOG $tag | $_" }
  cmd /c "`"$p10Adb`" -s $p10Serial exec-out screencap -p > `"$p10Out\screen_$tag.png`"" | Out-Null
}
function P10Seed([string]$tag, $payload) {
  P10A shell am force-stop $p10Pkg | Out-Null
  $txt = $payload | ConvertTo-Json -Compress -Depth 8
  $sha = [Security.Cryptography.SHA256]::Create()
  $chk = (($sha.ComputeHash($p10U8.GetBytes($txt)) | ForEach-Object { $_.ToString('x2') }) -join '')
  $env1 = [ordered]@{ version = 1; checksum = $chk; payload = $txt } | ConvertTo-Json -Compress
  $sf = Join-Path $p10Out "seed_$tag.json"
  [IO.File]::WriteAllText($sf, $env1, $p10U8)
  P10A push $sf /data/local/tmp/p10_seed.json | Out-Null
  P10A shell "run-as $p10Pkg sh -c 'rm -f files/save.json files/save.json.bak files/save.json.tmp files/save.pre-*.json; cp /data/local/tmp/p10_seed.json files/save.json'" | Out-Null
  P10A shell rm /data/local/tmp/p10_seed.json | Out-Null
  "P10 SEED $tag sha16=$(P10Sha $sf) cv=$($payload.content_version) files=$(P10Files)"
}
try {
  $t0 = Get-Date; $booted = $false
  while (((Get-Date) - $t0).TotalSeconds -lt 420) { if ((P10A shell getprop sys.boot_completed | Out-String).Trim() -eq '1') { $booted = $true; break }; Start-Sleep 5 }
  "P10 booted=$booted after $([int]((Get-Date) - $t0).TotalSeconds)s"
  if (-not $booted) { throw 'device did not finish booting' }
  "P10 device " + ((P10A shell getprop ro.product.model | Out-String).Trim() + ' / Android ' + (P10A shell getprop ro.build.version.release | Out-String).Trim() + ' / API ' + (P10A shell getprop ro.build.version.sdk | Out-String).Trim() + ' / ' + (P10A shell getprop ro.product.cpu.abi | Out-String).Trim())
  if ((P10A shell pm list packages $p10Pkg | Out-String).Trim()) { P10A uninstall $p10Pkg | Out-Null; 'P10 removed an earlier install on this read-only instance' }
  "P10 install " + ((P10A install -r $p10Apk | Out-String).Trim() -replace "`r?`n", ' ')
  $p10Dev = ((P10A shell pm path $p10Pkg | Out-String).Trim() -split "`r?`n" | Select-Object -First 1) -replace '^package:', ''
  $p10Pulled = Join-Path $p10Out 'installed_base.apk'
  P10A pull $p10Dev.Trim() $p10Pulled | Out-Null
  "P10 installed_apk_sha16=$(P10Sha $p10Pulled) local_apk_sha16=$(P10Sha $p10Apk)"
  Remove-Item -LiteralPath $p10Pulled -ErrorAction SilentlyContinue
  $p10Order = @('r01', 'r02', 'r03', 'r04', 'r05', 'r06', 'r07', 'r08', 'r09', 'r10')
  $p10Set = [ordered]@{ fps_cap = 60; sfx = 1.0; music = 0.8; show_damage = $true; screen_shake = $true }
  # ---- D0 fresh install: first launch, HOME (App saves on pause) -> the device's own content_version in the file
  P10Launch 'D0_first_launch'
  P10A shell input keyevent KEYCODE_HOME | Out-Null; Start-Sleep 4
  P10Info 'D0_after_home'
  # ---- E1 older version with melee max 6 and a paid L6 -> refund 250 + notice; restart before ack; BACK = ack; restart
  $snap6 = [ordered]@{ version = 'c1-0000000000e1'; order = $p10Order; upgrades = [ordered]@{ up_melee_basic = [ordered]@{ target = 'unit:melee_basic'; costs = @(60, 100, 160, 190, 250); max_level = 6 } } }
  $e1 = [ordered]@{ version = 1; revision = 7; unlocked_round = 6; stars = [ordered]@{ r01 = 3; r02 = 3; r03 = 2; r04 = 3; r05 = 1 }; best_time = [ordered]@{}; coins = 1000; clears = 5; tutorial_done = @(); upgrades = [ordered]@{ up_melee_basic = 6 }; upgrade_paid = [ordered]@{ up_melee_basic = [ordered]@{ '2' = 60; '3' = 100; '4' = 160; '5' = 190; '6' = 250 } }; applied_battles = @(); settings = $p10Set; content_version = 'c1-0000000000e1'; content_snapshot = $snap6 }
  P10Seed 'E1' $e1
  P10Launch 'E1_update_boot'
  P10Info 'E1_after_boot'
  P10Raw 'files/save.pre-c1-0000000000e1.json' (Join-Path $p10Out 'pre_E1.json') | Out-Null
  "P10 E1 pre_backup_sha16=$(P10Sha (Join-Path $p10Out 'pre_E1.json')) seed_sha16=$(P10Sha (Join-Path $p10Out 'seed_E1.json'))"
  P10A shell am force-stop $p10Pkg | Out-Null
  P10Launch 'E1b_restart_before_ack'
  P10Info 'E1b_after_restart'
  P10A shell input keyevent KEYCODE_BACK | Out-Null; Start-Sleep 4
  cmd /c "`"$p10Adb`" -s $p10Serial exec-out screencap -p > `"$p10Out\screen_E1c_after_back.png`"" | Out-Null
  P10Info 'E1c_after_back_ack'
  P10A shell am force-stop $p10Pkg | Out-Null
  P10Launch 'E1d_restart_after_ack'
  P10Info 'E1d_after_restart'
  # ---- E2 completionist (all 10 cleared, unlocked 11), data otherwise identical: does an update write?
  $snap5 = [ordered]@{ version = 'c1-0000000000e2'; order = $p10Order; upgrades = [ordered]@{ up_melee_basic = [ordered]@{ target = 'unit:melee_basic'; costs = @(60, 100, 160, 190); max_level = 5 } } }
  $st10 = [ordered]@{}; foreach ($r in $p10Order) { $st10[$r] = 2 }
  $e2 = [ordered]@{ version = 1; revision = 30; unlocked_round = 11; stars = $st10; best_time = [ordered]@{}; coins = 500; clears = 10; tutorial_done = @(); upgrades = [ordered]@{}; upgrade_paid = [ordered]@{}; applied_battles = @(); settings = $p10Set; content_version = 'c1-0000000000e2'; content_snapshot = $snap5 }
  P10Seed 'E2' $e2
  P10Launch 'E2_update_boot'
  P10Info 'E2_after_boot'
  # ---- E3 legacy: melee L6, no paid record, no snapshot -> refund_unknown warning in logcat, notice coins 0
  $e3 = [ordered]@{ version = 1; revision = 3; unlocked_round = 3; stars = [ordered]@{ r01 = 3; r02 = 3 }; best_time = [ordered]@{}; coins = 400; clears = 2; tutorial_done = @(); upgrades = [ordered]@{ up_melee_basic = 6 }; applied_battles = @(); settings = $p10Set; content_version = 'c1-0000000000e3' }
  P10Seed 'E3' $e3
  P10Launch 'E3_update_boot'
  P10Info 'E3_after_boot'
  P10A shell am force-stop $p10Pkg | Out-Null
  P10A uninstall $p10Pkg | Out-Null
} catch { "P10 ERROR $_" }
finally {
  & $p10Adb -s $p10Serial emu kill 2>&1 | Out-Null
  if ($p10EmuProc -and -not $p10EmuProc.WaitForExit(90000)) { "P10 emulator did not exit in 90 s pid=$($p10EmuProc.Id)" } else { 'P10 emulator stopped (adb emu kill)' }
  Start-Sleep 3
  "P10 qemu_left=$(@(Get-Process -Name 'qemu-system*' -ErrorAction SilentlyContinue).Count) devices=" + ((& $p10Adb devices | Out-String).Trim() -replace "`r?`n", ' | ')
  if (-not $p10AdbWasRunning) { & $p10Adb kill-server *> $null; 'P10 adb server stopped (this job started it)' } else { 'P10 adb server left running (it was running before this job)' }
  "P10 job end $(Get-Date -Format s)"
}
$global:LASTEXITCODE = 0
