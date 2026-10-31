# FAKE adb for tests/performance/test_device_session.ps1 (08-performance). NOT a device: every value below is a fixed,
# hand-made sample so the summary maths can be checked exactly. Never cite these numbers as measurements.
# Environment:
#   FAKE_ADB_MODE  = none | one | two | unauthorized | emulator     (what `adb devices` shows)
#   FAKE_ADB_STATE = directory for call counters and "pushed" files (created by the test)
#   FAKE_ADB_ZOOM_SUPPORTED = 1 -> the fake game honours --world-zoom-plus-one (zoom 4/3 at scale 3); otherwise it reports zoom=1
#   FAKE_ADB_USB   = 1 -> dumpsys battery says USB powered
# Fixed samples: screen 1080x2400 (canvas scale 3), MemTotal 3794000 kB (low tier), frame intervals 9 x 16.667 ms + 1 x 33.333 ms
# repeating (p50 16.667, p95 33.333, janky share 0.1), TOTAL PSS 185432 kB, Graphics 41000 kB, CPU 45 %, battery temperature
# 30.0 C + 0.5 C per dumpsys battery call in a scene, level 100 - (call / 4), current -350000 uA, thermal status 1, cold start
# TotalTime 1850 ms, game lines dc=58 gpu_ms 4.0-6.0 tex_mib 12.5 scale=3 units=73.
$mode = if ($env:FAKE_ADB_MODE) { $env:FAKE_ADB_MODE } else { 'one' }
$state = $env:FAKE_ADB_STATE
if (-not $state) { $state = Join-Path $env:TEMP 'fake_adb_state' }
New-Item -ItemType Directory -Force $state | Out-Null
function Counter([string]$name) {
    $f = Join-Path $state "$name.count"
    $n = if (Test-Path $f) { [int](Get-Content $f -Raw) } else { 0 }
    Set-Content -LiteralPath $f -Value ($n + 1) -NoNewline
    return $n
}
function Reset([string]$name) { Remove-Item -LiteralPath (Join-Path $state "$name.count") -ErrorAction SilentlyContinue }
$pkg = 'com.soltyspring.lanedefence.perf'
$a = @($args)
if ($a.Count -ge 1 -and $a[0] -eq 'devices') {
    "List of devices attached"
    switch ($mode) {
        'none' { }
        'one' { "FAKE0001`tdevice" }
        'emulator' { "emulator-5580`tdevice" }
        'two' { "FAKE0001`tdevice"; "FAKE0002`tdevice" }
        'unauthorized' { "FAKE0001`tunauthorized" }
    }
    ""
    return
}
if ($a.Count -ge 2 -and $a[0] -eq '-s') { $a = $a[2..($a.Count - 1)] }
$verb = $a[0]
if ($verb -eq 'install') { "Performing Streamed Install"; "Success"; return }
if ($verb -eq 'push') { Copy-Item -LiteralPath $a[1] -Destination (Join-Path $state 'pushed_args.txt') -Force; "$($a[1]): 1 file pushed, 0 skipped."; return }
if ($verb -eq 'logcat') {
    if ($a -contains '-c') { Reset 'logcat'; Reset 'battery'; return }
    $n = Counter 'logcat'
    $argsTxt = if (Test-Path (Join-Path $state 'app_args.txt')) { ((Get-Content (Join-Path $state 'app_args.txt')) | Where-Object { $_ }) -join ' ' } else { '' }
    $z = 1.0
    if ($env:FAKE_ADB_ZOOM_SUPPORTED -eq '1' -and $argsTxt -match '--world-zoom-plus-one') { $z = 1.3333 }   # (k+1)/k at the fake's canvas scale 3
    "--------- beginning of main"
    if ($argsTxt) { "11-01 09:00:00.100  4321  4350 I godot   : [perf08] args applied: $argsTxt" }
    $lines = [math]::Min(40, 2 + 2 * $n)
    for ($i = 0; $i -lt $lines; $i++) {
        $gpu = 4.0 + ($i % 3)   # 4, 5, 6
        "11-01 09:00:{0:d2}.000  4321  4350 I godot   : [perf08] t={1} fps=54.5 frame_ms=18.3 dc=58 gpu_ms={2:0.0} rcpu_ms=1.2 tex_mib=12.5 scale=3 zoom={3} units=73" -f ($i % 60), ($i + 1), $gpu, $z
    }
    return
}
if ($verb -ne 'shell') { "fake adb: unsupported '$($a -join ' ')'"; return }
$cmd = ($a[1..($a.Count - 1)] -join ' ')
switch -Regex ($cmd) {
    '^getprop$' {
        $q = if ($mode -eq 'emulator') { '1' } else { '0' }
        $model = if ($mode -eq 'emulator') { 'sdk_gphone64_x86_64' } else { 'FAKE-PHONE-1080' }
        "[ro.product.manufacturer]: [FakeMaker]"; "[ro.product.model]: [$model]"; "[ro.product.device]: [fake1080]"
        "[ro.soc.manufacturer]: [FakeSoC]"; "[ro.soc.model]: [FS-610]"; "[ro.board.platform]: [fake]"; "[ro.hardware]: [fakehw]"
        "[ro.build.version.release]: [13]"; "[ro.build.version.sdk]: [33]"; "[ro.product.cpu.abi]: [arm64-v8a]"
        "[ro.kernel.qemu]: [$q]"; "[ro.build.fingerprint]: [FakeMaker/fake1080/fake1080:13/FAKE/1:user/release-keys]"
        break
    }
    '^wm size$' { "Physical size: 1080x2400"; break }
    '^wm density$' { "Physical density: 420"; break }
    '^cat /proc/meminfo$' { "MemTotal:        3794000 kB"; "MemFree:          812000 kB"; break }
    '^dumpsys battery$' {
        $n = Counter 'battery'
        $usb = if ($env:FAKE_ADB_USB -eq '1') { 'true' } else { 'false' }
        "Current Battery Service state:"; "  AC powered: false"; "  USB powered: $usb"; "  Wireless powered: false"
        "  status: 3"; "  level: $(100 - [int][math]::Floor($n / 4))"; "  voltage: 3950"; "  temperature: $(300 + 5 * $n)"
        break
    }
    '^cat /sys/class/power_supply/battery/current_now$' { "-350000"; break }
    '^dumpsys thermalservice$' {
        "IsStatusOverride: false"; "Thermal Status: 1"
        "Current temperatures from HAL:"
        "	Temperature{mValue=41.5, mType=0, mName=cpu0, mStatus=1}"
        "	Temperature{mValue=38.0, mType=1, mName=gpu, mStatus=0}"
        "	Temperature{mValue=35.0, mType=3, mName=skin, mStatus=0}"
        break
    }
    "^pm path $([regex]::Escape($pkg))$" { "package:/data/app/~~fake==/$pkg-fake==/base.apk"; break }
    "^run-as $([regex]::Escape($pkg)) mkdir -p files$" { break }
    "^run-as $([regex]::Escape($pkg)) cp /data/local/tmp/defence_perf_args.txt files/perf_args.txt$" { Copy-Item (Join-Path $state 'pushed_args.txt') (Join-Path $state 'app_args.txt') -Force; break }
    "^run-as $([regex]::Escape($pkg)) cat files/perf_args.txt$" { Get-Content (Join-Path $state 'app_args.txt') -Raw; break }
    "^am force-stop" { Remove-Item (Join-Path $state 'running') -ErrorAction SilentlyContinue; break }
    "^am start -S -W" { Set-Content (Join-Path $state 'running') '1'; Reset 'sf'; "Starting: Intent { cmp=$pkg/com.godot.game.GodotAppLauncher }"; "Status: ok"; "LaunchState: COLD"; "TotalTime: 1850"; "WaitTime: 1870"; "Complete"; break }
    "^pidof " { if (Test-Path (Join-Path $state 'running')) { "4321" }; break }
    "^dumpsys meminfo" {
        "Applications Memory Usage (in Kilobytes):"; "** MEMINFO in pid 4321 [$pkg] **"
        "  Native Heap:    61000"; "  Graphics:    41000"; "  GL mtrack:    38000"; "  TOTAL PSS:   185432            TOTAL RSS:   290000"
        break
    }
    "^top " { "  PID USER  %CPU"; " 45.0"; break }
    "^dumpsys gfxinfo .* reset$" { break }
    "^dumpsys gfxinfo .* framestats$" { "Total frames rendered: 42"; "Janky frames: 3 (7.14%)"; "---PROFILEDATA---"; break }
    "^dumpsys SurfaceFlinger --list$" {
        "RequestedLayerState{1a2b ActivityRecord{fake u0 $pkg/com.godot.game.GodotApp}#10 parentId=2}"
        "RequestedLayerState{Background for 3c4d SurfaceView[$pkg/com.godot.game.GodotApp]#13 parentId=12}"
        "RequestedLayerState{3c4d SurfaceView[$pkg/com.godot.game.GodotApp](BLAST)#14 parentId=12}"
        break
    }
    "^dumpsys SurfaceFlinger --latency" {
        # the last 128 frames; each call advances 60 frames (one second at 60 Hz). Interval pattern: frame i ends a 33.333 ms gap
        # when i % 10 == 9, else 16.667 ms, so present(i) = T0 + i * 16666667 + floor((i + 1) / 10) * 16666666
        $n = Counter 'sf'
        $last = 127 + 60 * $n
        "16666667"
        $T0 = 1000000000000
        for ($i = $last - 127; $i -le $last; $i++) {
            $p = $T0 + [long]$i * 16666667 + [long][math]::Floor(($i + 1) / 10) * 16666666
            "{0}`t{1}`t{2}" -f ($p - 8000000), $p, ($p - 4000000)
        }
        break
    }
    default { "" }
}
