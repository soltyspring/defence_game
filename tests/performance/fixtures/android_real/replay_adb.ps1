# REPLAY adb for tests/performance/test_device_session.ps1 (08-performance). Serves REAL outputs captured once from an Android
# emulator (02's LaneDefence_Phone AVD, -gpu swiftshader_indirect) so device_session.ps1's parsers are tested on real Android
# formats. EMULATOR format samples only: never performance evidence.
# Environment: REPLAY_DIR = folder with the captured files (see SOURCE.txt there); REPLAY_STATE = scratch folder.
$dir = $env:REPLAY_DIR
$state = if ($env:REPLAY_STATE) { $env:REPLAY_STATE } else { Join-Path $env:TEMP 'replay_adb_state' }
New-Item -ItemType Directory -Force $state | Out-Null
function F([string]$name) { $p = Join-Path $dir $name; if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllText($p) } else { '' } }
function Counter([string]$name) {
    $f = Join-Path $state "$name.count"; $n = if (Test-Path $f) { [int](Get-Content $f -Raw) } else { 0 }
    Set-Content -LiteralPath $f -Value ($n + 1) -NoNewline; return $n
}
$serial = (F 'serial.txt').Trim(); if (-not $serial) { $serial = 'emulator-5596' }
$pkg = (F 'package.txt').Trim(); if (-not $pkg) { $pkg = 'com.soltyspring.lanedefence' }
$a = @($args)
if ($a.Count -ge 1 -and $a[0] -eq 'devices') { "List of devices attached"; "$serial`tdevice"; ""; return }
if ($a.Count -ge 2 -and $a[0] -eq '-s') { $a = $a[2..($a.Count - 1)] }
$verb = $a[0]
if ($verb -eq 'install') { (F 'install.txt'); return }
if ($verb -eq 'push') { Copy-Item -LiteralPath $a[1] -Destination (Join-Path $state 'pushed.txt') -Force; "$($a[1]): 1 file pushed, 0 skipped."; return }
if ($verb -eq 'pull') { Copy-Item -LiteralPath (Join-Path $dir 'screen.png') -Destination $a[2] -Force; "$($a[1]): 1 file pulled"; return }
if ($verb -eq 'logcat') { if ($a -contains '-c') { return }; (F 'logcat_godot.txt'); return }
if ($verb -ne 'shell') { ''; return }
$cmd = ($a[1..($a.Count - 1)] -join ' ')
switch -Regex ($cmd) {
    '^getprop$' { F 'getprop.txt'; break }
    '^wm size$' { F 'wm_size.txt'; break }
    '^wm density$' { F 'wm_density.txt'; break }
    '^cat /proc/meminfo$' { F 'proc_meminfo.txt'; break }
    '^dumpsys battery$' { if ((Counter 'battery') -eq 0) { F 'battery_before.txt' } else { F 'battery_after.txt' }; break }
    '^cat /sys/class/power_supply/battery/current_now$' { F 'current_now.txt'; break }
    '^dumpsys thermalservice$' { F 'thermalservice.txt'; break }
    '^pm path ' { F 'pm_path.txt'; break }
    '^run-as .* cat files/perf_args.txt$' { if (Test-Path (Join-Path $state 'pushed.txt')) { Get-Content (Join-Path $state 'pushed.txt') -Raw }; break }
    '^run-as ' { ''; break }
    '^am start' { F 'am_start.txt'; break }
    '^am force-stop' { ''; break }
    '^pidof ' { F 'pidof.txt'; break }
    '^dumpsys meminfo .* -d$' { F 'meminfo_d.txt'; break }
    '^dumpsys meminfo ' { F 'meminfo.txt'; break }
    '^top ' { F 'top.txt'; break }
    '^dumpsys gfxinfo .* reset$' { ''; break }
    '^dumpsys gfxinfo .* framestats$' { F 'gfxinfo_framestats.txt'; break }
    '^dumpsys SurfaceFlinger --list$' { F 'sf_list.txt'; break }
    '^dumpsys SurfaceFlinger --latency' { $n = Counter 'sf'; F ("sf_latency_{0}.txt" -f (($n % 5) + 1)); break }
    '^screencap ' { ''; break }
    '^rm ' { ''; break }
    default { '' }
}
