# Self-test for tools/perf/device_session.ps1 WITHOUT a phone (08-performance). Uses the fake adb in
# tests/performance/fixtures/device_fake/fake_adb.ps1, whose outputs are fixed hand-made samples, so every expected value
# below follows from that file. No Godot, no emulator, no real adb. A pass here proves the script logic, not any device number.
# Usage: .\tests\performance\test_device_session.ps1   (exit 0 = all cases behave as specified)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$Fake = Join-Path $PSScriptRoot 'fixtures\device_fake\fake_adb.ps1'
$Session = Join-Path $Root 'tools\perf\device_session.ps1'
$Work = Join-Path $Root 'build\perf\device_selftest'
if (Test-Path $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
New-Item -ItemType Directory -Force $Work | Out-Null
$apk = Join-Path $Work 'fake-perf.apk'; Set-Content -LiteralPath $apk -Value 'not an apk'
$bad = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
    if (-not $ok) { $script:bad++ }
    Write-Host ("[device_selftest] {0,-4} {1,-44} {2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, $detail)
}
function Run([string]$mode, [string[]]$extra, [hashtable]$envs = @{}) {
    $st = Join-Path $Work "state_${mode}_$([guid]::NewGuid().ToString('N').Substring(0,6))"
    $env:FAKE_ADB_MODE = $mode; $env:FAKE_ADB_STATE = $st
    foreach ($k in $envs.Keys) { Set-Item "env:$k" $envs[$k] }
    $out = Join-Path $Work "out_$mode"
    $a = @('-NoProfile', '-File', $Session, '-Adb', $Fake, '-OutRoot', $out, '-TimeScale', '0.005', '-Interval', '5') + $extra
    if ($extra -notcontains '-Apk') { $a += @('-Apk', $apk) }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'   # child stderr must not abort the test
    $log = & pwsh @a 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    foreach ($k in $envs.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $sum = Get-ChildItem -LiteralPath $out -Recurse -Filter 'summary.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    return [pscustomobject]@{ code = $code; log = $log; summary = $(if ($sum) { Get-Content -LiteralPath $sum.FullName -Raw | ConvertFrom-Json }); md = $(if ($sum) { Get-Content -LiteralPath (Join-Path $sum.DirectoryName 'summary.md') -Raw }); dir = $(if ($sum) { $sum.DirectoryName }) }
}

# ---- device-count and safety refusals: exit 2, no output folder, nothing installed
$r = Run 'none' @(); Check 'zero_devices_stops' ($r.code -eq 2 -and $r.log -match 'NOT_ONE_DEVICE: 0' -and -not $r.summary) "exit=$($r.code)"
$r = Run 'two' @(); Check 'two_devices_stops' ($r.code -eq 2 -and $r.log -match 'NOT_ONE_DEVICE: 2' -and -not $r.summary) "exit=$($r.code)"
$r = Run 'unauthorized' @(); Check 'unauthorized_stops' ($r.code -eq 2 -and $r.log -match 'DEVICE_NOT_READY' -and -not $r.summary) "exit=$($r.code)"
$r = Run 'emulator' @(); Check 'emulator_refused' ($r.code -eq 2 -and $r.log -match 'EMULATOR_REFUSED' -and -not $r.summary) "exit=$($r.code)"
$r = Run 'one' @('-Package', 'com.soltyspring.lanedefence'); Check 'release_package_refused' ($r.code -eq 2 -and $r.log -match 'RELEASE_PACKAGE_REFUSED') "exit=$($r.code)"
$r = Run 'one' @('-Apk', (Join-Path $Work 'missing.apk')); Check 'missing_apk_stops' ($r.code -eq 2 -and $r.log -match 'NO_PERF_APK' -and -not $r.summary) "exit=$($r.code)"

# ---- one fake device, two scenes (zoom off valid, zoom on invalid because the fake game has no zoom flag)
$r = Run 'one' @('-Only', 'r08_caps_zoom_off,r08_caps_zoom_on')
$s = $r.summary
Check 'one_device_runs' ($r.code -eq 0 -and $s -ne $null) "exit=$($r.code)"
if ($s) {
    $off = $s.scenes | Where-Object { $_.id -eq 'r08_caps_zoom_off' }; $on = $s.scenes | Where-Object { $_.id -eq 'r08_caps_zoom_on' }
    Check 'evidence_class_fixture' ($s.evidence_class -like 'FIXTURE*' -and $r.md -match 'FIXTURE') $s.evidence_class
    Check 'facts_parsed' ($s.device.model -eq 'FAKE-PHONE-1080' -and $s.device.screen -eq '1080x2400' -and $s.device.canvas_scale -eq 3 -and $s.device.tier -eq 'low' -and $s.device.android -eq '13' -and $s.device.soc -eq 'FakeSoC FS-610') "$($s.device.model) $($s.device.screen) scale=$($s.device.canvas_scale) tier=$($s.device.tier)"
    Check 'args_written_and_acked' ($off.args_file_ok -and $off.args_applied -and $off.args_ack -eq '--autoplay --round=r08 --perf-caps') "ack='$($off.args_ack)'"
    Check 'frame_p50_p95' ($off.frame_interval_p50_ms -eq 16.667 -and $off.frame_interval_p95_ms -eq 33.333) "p50=$($off.frame_interval_p50_ms) p95=$($off.frame_interval_p95_ms)"
    Check 'janky_share_0.1' ([math]::Abs($off.janky_share - 0.1) -lt 0.01) "janky=$($off.janky_share)"
    Check 'fps_mean_54.5' ([math]::Abs($off.fps_mean - 54.545) -lt 0.1) "fps=$($off.fps_mean)"
    Check 'frames_deduplicated' ($off.frames -gt 100 -and $off.frames -le (127 + 60 * 200)) "frames=$($off.frames)"
    Check 'pss_graphics' ($off.pss_max_mb -eq 181.1 -and $off.graphics_max_mb -eq 40) "pss=$($off.pss_max_mb) gfx=$($off.graphics_max_mb)"
    Check 'cold_start' ($off.cold_start_ms -eq 1850) "$($off.cold_start_ms)"
    Check 'battery_temp_rise' ($off.samples -ge 2 -and [math]::Abs($off.battery_temp_rise_c - 0.5 * ($off.samples - 1)) -lt 0.01) "samples=$($off.samples) rise=$($off.battery_temp_rise_c)"
    Check 'game_lines' ($off.game_dc_p95 -eq 58 -and $off.game_gpu_ms_p95 -eq 6 -and $off.game_gpu_ms_p50 -eq 5 -and $off.game_tex_mib_max -eq 12.5 -and $off.game_scale -eq 3) "dc=$($off.game_dc_p95) gpu p50/p95=$($off.game_gpu_ms_p50)/$($off.game_gpu_ms_p95)"
    Check 'hwui_gfxinfo_parsed' ($off.hwui_frames -eq 42 -and $off.hwui_janky_pct -eq 7.14) "$($off.hwui_frames) / $($off.hwui_janky_pct)"
    Check 'zoom_off_valid' ($off.valid -eq $true) "valid=$($off.valid)"
    Check 'zoom_on_invalid_without_flag' ($on.valid -eq $false -and $on.invalid_reason -match 'ZOOM_NOT_APPLIED') "reason=$($on.invalid_reason)"
    $v = @{}; foreach ($c in $s.criteria) { $v[$c.id] = $c }
    Check 'criterion_frame_p95_low_pass' ($v.frame_p95_low.result -eq 'PASS' -and $v.frame_p95_low.worst -eq 33.333) "$($v.frame_p95_low.result) worst=$($v.frame_p95_low.worst)"
    Check 'criterion_janky_fail' ($v.janky_share.result -eq 'FAIL') $v.janky_share.result
    Check 'criterion_pss_low_pass' ($v.pss_low.result -eq 'PASS') $v.pss_low.result
    Check 'criterion_dc_3x_pass_2x_na' ($v.draw_calls_3x.result -eq 'PASS' -and $v.draw_calls_2x.result -eq 'NOT_APPLICABLE') "3x=$($v.draw_calls_3x.result) 2x=$($v.draw_calls_2x.result)"
    Check 'criterion_mid_tier_not_judged' (-not $v.ContainsKey('frame_p95_mid')) 'low tier only'
    Check 'criterion_gpu_assumption_tagged' ($v.gpu_ms_p95.assumption -eq $true -and $r.md -match 'ASSUMPTION') "result=$($v.gpu_ms_p95.result)"
    Check 'criterion_soak_not_measured' ($v.soak_thermal_status.result -eq 'NOT_MEASURED') $v.soak_thermal_status.result
    Check 'files_written' ((Test-Path (Join-Path $r.dir 'r08_caps_zoom_off\samples.csv')) -and (Test-Path (Join-Path $r.dir 'r08_caps_zoom_off\gfxinfo_framestats.txt')) -and (Test-Path (Join-Path $r.dir 'r08_caps_zoom_off\logcat_godot.txt')) -and (Test-Path (Join-Path $r.dir 'facts.json'))) $r.dir.Replace($Root, '.')
}

# ---- zoom flag present -> zoom-on scene valid
$r = Run 'one' @('-Only', 'r08_caps_zoom_on') @{ FAKE_ADB_ZOOM_SUPPORTED = '1' }
$z = $r.summary.scenes | Where-Object { $_.id -eq 'r08_caps_zoom_on' }
Check 'zoom_on_valid_with_flag' ($r.code -eq 0 -and $z.valid -eq $true -and [math]::Abs($z.game_zoom - 1.3333) -lt 0.001) "zoom=$($z.game_zoom) valid=$($z.valid)"

# ---- soak mode (4 nominal minutes, 2-min windows), on battery
$r = Run 'one' @('-Soak', '-SoakMinutes', '4', '-SoakWindow', '4')
$k = $r.summary.scenes | Where-Object { $_.soak }
$v = @{}; foreach ($c in $r.summary.criteria) { $v[$c.id] = $c }
Check 'soak_runs' ($r.code -eq 0 -and $k.id -eq 'soak_r08_caps_zoom_off' -and $k.valid) "exit=$($r.code) id=$($k.id)"
Check 'soak_windows' (@($k.soak_windows).Count -ge 2 -and [math]::Abs($k.soak_fps_last_over_first - 1) -le 0.03 -and [math]::Abs($k.soak_p95_last_over_first - 1) -le 0.03) "windows=$(@($k.soak_windows).Count) fps_ratio=$($k.soak_fps_last_over_first) p95_ratio=$($k.soak_p95_last_over_first)"
Check 'soak_thermal_pass' ($v.soak_thermal_status.result -eq 'PASS' -and $v.soak_thermal_status.worst -eq 1) "$($v.soak_thermal_status.result) max=$($v.soak_thermal_status.worst)"
Check 'soak_temp_rise_judged_assumption' ($v.soak_temp_rise.result -eq $(if ($v.soak_temp_rise.worst -le 8) { 'PASS' } else { 'FAIL' }) -and $v.soak_temp_rise.assumption -and [math]::Abs($v.soak_temp_rise.worst - 0.5 * ($k.samples - 1)) -lt 0.01) "rise=$($v.soak_temp_rise.worst)"
Check 'soak_battery_rate' ($k.battery_pct_per_30min -ne $null -and $v.battery_drain.result -in @('PASS', 'FAIL')) "rate=$($k.battery_pct_per_30min) $($v.battery_drain.result)"

# ---- soak on USB power -> battery drain NOT_MEASURED
$r = Run 'one' @('-Soak', '-SoakMinutes', '4', '-SoakWindow', '4') @{ FAKE_ADB_USB = '1' }
$v = @{}; foreach ($c in $r.summary.criteria) { $v[$c.id] = $c }
$k = $r.summary.scenes | Where-Object { $_.soak }
Check 'usb_power_battery_not_measured' ($v.battery_drain.result -eq 'NOT_MEASURED' -and $k.battery_note -match 'NOT_MEASURED') "$($v.battery_drain.result)"

# ---- blank-screen guards with REAL emulator samples (fixtures/android_real; EMULATOR format samples, not performance)
$real = Join-Path $PSScriptRoot 'fixtures\android_real'
$r = Run 'one' @('-Only', 'r08_caps_zoom_off') @{ FAKE_ADB_LOGCAT_EXTRA = (Join-Path $real 'shader_fail_10\logcat_godot_D0_first_launch.txt'); FAKE_ADB_SCREEN = (Join-Path $real 'shader_fail_10\screen_D0_first_launch.png') }
$x = $r.summary.scenes | Where-Object { $_.id -eq 'r08_caps_zoom_off' }
$v = @{}; foreach ($c in $r.summary.criteria) { $v[$c.id] = $c }
Check 'shader_link_failure_invalid' ($x.valid -eq $false -and $x.invalid_reason -match 'GLES_SHADER_ERROR' -and $x.gles_errors -ge 2 -and $x.gles_error_first -match 'Program linking failed|uniforms exceed') "reason=$($x.invalid_reason) errors=$($x.gles_errors) first='$($x.gles_error_first)'"
Check 'shader_failure_screen_not_blank' ($x.blank_screen -eq $false -and $x.screen.unique_colors -gt 2) "colours=$($x.screen.unique_colors) std=$($x.screen.luma_std) (10's D0 frame shows the menu; only the log catches it)"
Check 'invalid_scene_not_judged' ($v.frame_p95_low.result -eq 'NOT_MEASURED' -and $v.janky_share.result -eq 'NOT_MEASURED') "frame_p95_low=$($v.frame_p95_low.result)"
$r = Run 'one' @('-Only', 'r08_caps_zoom_off') @{ FAKE_ADB_SCREEN = (Join-Path $real 'shader_fail_10\screen_E1_update_boot_blank.png') }
$x = $r.summary.scenes | Where-Object { $_.id -eq 'r08_caps_zoom_off' }
Check 'blank_screen_invalid' ($x.valid -eq $false -and $x.invalid_reason -match 'BLANK_SCREEN' -and $x.screen.unique_colors -le 2 -and $x.frames -gt 0) "reason=$($x.invalid_reason) colours=$($x.screen.unique_colors) std=$($x.screen.luma_std) frames=$($x.frames)"
Check 'good_screen_stats' ($off.screen.unique_colors -gt 2 -and $off.screen.luma_std -ge 2 -and $off.blank_screen -eq $false) "colours=$($off.screen.unique_colors) std=$($off.screen.luma_std)"

# ---- REAL Android formats replayed (emulator capture; EMULATOR format check only, not performance)
$emuDir = Join-Path $real 'emu_formats'
if (Test-Path (Join-Path $emuDir 'getprop.txt')) {
    $env:REPLAY_DIR = $emuDir; $env:REPLAY_STATE = Join-Path $Work 'replay_state'
    if (Test-Path $env:REPLAY_STATE) { Remove-Item $env:REPLAY_STATE -Recurse -Force }
    $replay = Join-Path $real 'replay_adb.ps1'
    $pkgR = (Get-Content (Join-Path $emuDir 'package.txt') -Raw).Trim()
    $out = Join-Path $Work 'out_replay'
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $log = & pwsh -NoProfile -File $Session -Adb $replay -OutRoot $out -TimeScale 0.005 -Interval 5 -Only r08_caps_zoom_off -NoInstall -AllowEmulator -AllowReleasePackage -Package $pkgR 2>&1 | Out-String
    $code = $LASTEXITCODE; $ErrorActionPreference = $prev
    $sj = Get-ChildItem -LiteralPath $out -Recurse -Filter 'summary.json' -ErrorAction SilentlyContinue | Select-Object -Last 1
    $s = if ($sj) { Get-Content $sj.FullName -Raw | ConvertFrom-Json }
    $x = if ($s) { $s.scenes | Select-Object -First 1 }
    Check 'real_replay_runs' ($code -eq 0 -and $s -ne $null) "exit=$code"
    if ($s) {
        $dv = $s.device
        Check 'real_getprop_wm_meminfo' ($dv.model -ne '' -and $dv.android -ne '' -and $dv.screen -match '^\d+x\d+$' -and $dv.canvas_scale -ge 1 -and $dv.memtotal_gib -gt 1) "model=$($dv.model) android=$($dv.android) screen=$($dv.screen) scale=$($dv.canvas_scale) mem=$($dv.memtotal_gib)"
        Check 'real_battery' ($dv.battery_start.temp_c -ne $null -and $dv.battery_start.level -gt 0 -and $dv.battery_start.status -ne '') "temp=$($dv.battery_start.temp_c) level=$($dv.battery_start.level) ac=$($dv.battery_start.ac) usb=$($dv.battery_start.usb) current=$($dv.battery_start.current_ua)"
        Check 'real_thermal' ($dv.thermal_start.status -ne $null) "status=$($dv.thermal_start.status) keys=$(($dv.thermal_start.PSObject.Properties.Name) -join ',')"
        Check 'real_cold_start' ($x.cold_start_ms -gt 0) "$($x.cold_start_ms) ms"
        Check 'real_meminfo_pss' ($x.pss_max_mb -gt 10 -and $x.app_running_samples -gt 0) "pss=$($x.pss_max_mb) MB gfx=$($x.graphics_max_mb) running=$($x.app_running_samples)/$($x.samples)"
        Check 'real_cpu_top' ($x.cpu_pct_mean -ne $null) "cpu=$($x.cpu_pct_mean)"
        Check 'real_surfaceflinger' ($x.layer -ne '' -and $x.frames -gt 10 -and $x.refresh_ms -gt 5 -and $x.frame_interval_p50_ms -gt 0) "layer='$($x.layer)' frames=$($x.frames) refresh=$($x.refresh_ms) p50=$($x.frame_interval_p50_ms)"
        Check 'real_gfxinfo_framestats' ($x.hwui_frames -ne $null) "hwui_frames=$($x.hwui_frames) janky=$($x.hwui_janky_pct)"
        Check 'real_screencap_stats' ($x.screen.unique_colors -ge 1 -and $x.blank_screen -ne $null) "colours=$($x.screen.unique_colors) std=$($x.screen.luma_std) blank=$($x.blank_screen)"
        Check 'real_emulator_scene_invalid' ($x.valid -eq $false -and $x.invalid_reason -match 'ARGS_NOT_APPLIED') "reason=$($x.invalid_reason) gles_errors=$($x.gles_errors)"
    }
    Remove-Item env:REPLAY_DIR, env:REPLAY_STATE -ErrorAction SilentlyContinue
} else { Write-Host '[device_selftest] SKIP real_replay (fixtures/android_real/emu_formats not captured yet)' }

# ---- real adb path without a phone (no fake): must also stop with exit 2 when nothing is attached
Write-Host "[device_selftest] $(if ($bad -eq 0) { 'ALL PASS' } else { "$bad FAILED" })"
Remove-Item env:FAKE_ADB_MODE, env:FAKE_ADB_STATE -ErrorAction SilentlyContinue
exit $(if ($bad -eq 0) { 0 } else { 1 })
