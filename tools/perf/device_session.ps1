# 08-performance: one-shot PHONE measurement session. When a person plugs in ONE phone, this captures everything 08 needs
# in one go: device facts, perf APK install (02 P10), fixed scenes r01 / r08 caps / r10 with zoom off and on, and optionally a
# 15-20 min thermal soak. Per scene it collects SurfaceFlinger present times of the game's SurfaceView (Godot frames),
# dumpsys gfxinfo + framestats (HWUI; Godot draws to a SurfaceView, so gfxinfo mostly sees the Android UI layer), dumpsys meminfo,
# battery temperature / level / current, thermal status, CPU, and the game's own once-per-second [perf08] log lines.
# Everything goes to one folder with summary.json, summary.md and a PASS / FAIL / NOT_MEASURED table against
# tools/perf/device_criteria.json (numbers fixed before measuring; assumptions are marked).
#
# Safety rules built in:
#  - Runs only when EXACTLY ONE device is attached and authorised. 0 or >= 2 attached -> exit 2, nothing chosen, nothing touched.
#  - Refuses an emulator (exit 2) unless -AllowEmulator (then labelled EMULATOR, never phone evidence).
#  - Refuses the release package id (a player's save could be on this phone) unless -AllowReleasePackage.
#  - A scene whose args the game did not confirm ("[perf08] args applied: ...") is INVALID and never judged.
#  - Battery drain is only judged without USB power (use wireless adb); otherwise NOT_MEASURED.
#  - A real device session (> 1 min) must run inside coordination/heavy_run.ps1 (start it detached:
#    coordination/heavy_run_detached.ps1 -Label '08-device' -ScriptFile <job>). The fake-adb self-test does not need the lock.
#
# Usage (workspace root):
#   & .\tools\perf\device_session.ps1 [-Apk build\android\defence-perf.apk] [-Only r08_caps_zoom_off,r08_caps_zoom_on] [-Soak]
#       [-Tier low|mid|high] [-NoInstall] [-Interval 5]
# Exit: 0 session ran (verdicts in summary) / 1 error / 2 not run (device count, emulator, package, APK) / 4 not inside heavy_run.
# Output: build/perf/device/<model>_<serial>/<stamp>_session/ (git-ignored).
# Test: tests/performance/test_device_session.ps1 drives this with tests/performance/fixtures/device_fake/fake_adb.ps1.
# Owner: 08-performance.
param(
    [string]$Adb = '',
    [string]$Apk = '',
    [string]$Package = 'com.soltyspring.lanedefence.perf',
    [string]$Activity = 'com.godot.game.GodotAppLauncher',
    [string]$ScenesFile = '',
    [string[]]$Only = @(),
    [switch]$Soak,
    [double]$SoakMinutes = -1,
    [double]$SoakWindow = -1,
    [double]$Interval = 5,
    [string]$Tier = '',
    [string]$OutRoot = '',
    [string]$CriteriaFile = '',
    [switch]$NoInstall,
    [switch]$AllowEmulator,
    [switch]$AllowReleasePackage,
    [double]$TimeScale = 1.0
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
if (-not $ScenesFile) { $ScenesFile = Join-Path $PSScriptRoot 'device_scenes.json' }
if (-not $CriteriaFile) { $CriteriaFile = Join-Path $PSScriptRoot 'device_criteria.json' }
if (-not $Apk) { $Apk = Join-Path $Root 'build\android\defence-perf.apk' }
if (-not $OutRoot) { $OutRoot = Join-Path $Root 'build\perf\device' }
$ReleasePackage = 'com.soltyspring.lanedefence'
$fixture = $false
if (-not $Adb) {
    $sdk = @($env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk')) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'platform-tools\adb.exe')) } | Select-Object -First 1
    if (-not $sdk) { Write-Host 'NO_ADB: Android platform-tools not found. Nothing measured.'; exit 2 }
    $Adb = Join-Path $sdk 'platform-tools\adb.exe'
} elseif ($Adb -like '*.ps1') { $fixture = $true }
$script:adbRetries = 0
$script:Serial = ''

function Nap([double]$s) { $ms = [int]([math]::Max(0, $s * $TimeScale * 1000)); if ($ms -gt 0) { Start-Sleep -Milliseconds $ms } }
function A([string[]]$a) {
    $o = ''
    for ($k = 0; $k -lt 4; $k++) {
        $o = try { (& $Adb @a 2>&1 | Out-String) } catch { "ADB_ERROR: $_" }
        if ($o -notmatch "daemon not running|ADB_ERROR|no devices/emulators found|device '.*' not found") { return $o }
        $script:adbRetries++
        Nap 3
    }
    return $o
}
function Sh([string]$cmd) { A @('-s', $script:Serial, 'shell', $cmd) }
function NowS([datetime]$t0) { ((Get-Date) - $t0).TotalSeconds / $TimeScale }
function Pct([double[]]$arr, [double]$q) {
    if (-not $arr -or $arr.Count -eq 0) { return $null }
    $s = @($arr | Sort-Object)
    return [math]::Round($s[[math]::Min($s.Count - 1, [int][math]::Floor($s.Count * $q))], 3)
}
function Mean([double[]]$arr) { if (-not $arr -or $arr.Count -eq 0) { return $null }; return [math]::Round(($arr | Measure-Object -Average).Average, 3) }

# ---------------------------------------------------------------- 1. exactly one device
$dl = A @('devices')
$attached = @($dl -split "`r?`n" | Where-Object { $_ -match '^(\S+)\t(.+)$' } | ForEach-Object { [pscustomobject]@{ serial = $Matches[1]; state = $Matches[2].Trim() } })
if ($attached.Count -ne 1) {
    Write-Host "NOT_ONE_DEVICE: $($attached.Count) device(s) attached ($(($attached | ForEach-Object { "$($_.serial)=$($_.state)" }) -join ', ')). Connect exactly one phone; nothing was chosen or touched."
    exit 2
}
$script:Serial = $attached[0].serial
if ($attached[0].state -ne 'device') { Write-Host "DEVICE_NOT_READY: $($script:Serial) state=$($attached[0].state) (authorise USB debugging on the phone). Nothing touched."; exit 2 }

# ---------------------------------------------------------------- 2. device facts
$props = @{}
foreach ($l in ((Sh 'getprop') -split "`r?`n")) { if ($l -match '^\[([^\]]+)\]: \[(.*)\]$') { $props[$Matches[1]] = $Matches[2] } }
function P([string]$k) { if ($props.ContainsKey($k)) { $props[$k] } else { '' } }
$isEmu = (P 'ro.kernel.qemu') -eq '1' -or (P 'ro.hardware') -match 'ranchu|goldfish' -or (P 'ro.product.model') -match '^sdk_'
if ($isEmu -and -not $AllowEmulator) { Write-Host "EMULATOR_REFUSED: $($script:Serial) is an emulator ($((P 'ro.product.model'))). This session needs a phone; use -AllowEmulator only for a function check (never phone evidence)."; exit 2 }
if ($Package -eq $ReleasePackage -and -not $AllowReleasePackage) { Write-Host "RELEASE_PACKAGE_REFUSED: $Package is the release id; a player's save on this phone could be touched. The perf APK must use its own id (02 P10: $ReleasePackage.perf)."; exit 2 }
$sizeTxt = Sh 'wm size'
$phys = [regex]::Match($sizeTxt, 'Physical size:\s*(\d+)x(\d+)')
$ovr = [regex]::Match($sizeTxt, 'Override size:\s*(\d+)x(\d+)')
$sz = if ($ovr.Success) { $ovr } else { $phys }
$w = if ($sz.Success) { [int]$sz.Groups[1].Value } else { 0 }; $h = if ($sz.Success) { [int]$sz.Groups[2].Value } else { 0 }
$short = [math]::Min($w, $h)
$canvasScale = if ($short -gt 0) { [int][math]::Floor($short / 360) } else { 0 }   # project base 640x360, integer stretch, landscape
$memKb = [double]([regex]::Match((Sh 'cat /proc/meminfo'), 'MemTotal:\s+(\d+)')).Groups[1].Value
$memGib = [math]::Round($memKb / 1MB, 2)
$criteria = Get-Content -LiteralPath $CriteriaFile -Raw | ConvertFrom-Json
if (-not $Tier) { $Tier = ($criteria.tiers | Where-Object { $memGib -le $_.memtotal_max_gib } | Select-Object -First 1).tier }
function Battery {
    $b = Sh 'dumpsys battery'
    $g = { param($k) $m = [regex]::Match($b, "(?m)^\s*$([regex]::Escape($k)):\s*(.+)$"); if ($m.Success) { $m.Groups[1].Value.Trim() } else { '' } }
    $cur = (Sh 'cat /sys/class/power_supply/battery/current_now').Trim()
    [ordered]@{ level = [int](& $g 'level'); temp_c = $(if (& $g 'temperature') { [double](& $g 'temperature') / 10.0 } else { $null })
        voltage_mv = $(if (& $g 'voltage') { [int](& $g 'voltage') } else { $null }); status = (& $g 'status')
        ac = (& $g 'AC powered') -eq 'true'; usb = (& $g 'USB powered') -eq 'true'; wireless = (& $g 'Wireless powered') -eq 'true'
        current_ua = $(if ($cur -match '^-?\d+$') { [long]$cur } else { $null }) }
}
function Thermal {
    $t = Sh 'dumpsys thermalservice'
    $st = [regex]::Match($t, 'Thermal Status:\s*(\d+)')
    $r = [ordered]@{ status = $(if ($st.Success) { [int]$st.Groups[1].Value } else { $null }) }
    foreach ($m in [regex]::Matches($t, 'mValue=([\d.]+), mType=(\d+), mName=([^,]+)')) {
        $kind = @{ '0' = 'cpu'; '1' = 'gpu'; '2' = 'battery'; '3' = 'skin' }[$m.Groups[2].Value]
        if ($kind) { $v = [double]$m.Groups[1].Value; $key = "temp_${kind}_c"; if (-not $r.Contains($key) -or $v -gt $r[$key]) { $r[$key] = $v } }
    }
    return $r
}
$facts = [ordered]@{
    evidence_class = $(if ($fixture) { 'FIXTURE (fake adb self-test; NOT device evidence)' } elseif ($isEmu) { 'EMULATOR (not phone evidence)' } else { 'DEVICE' })
    serial = $script:Serial; manufacturer = (P 'ro.product.manufacturer'); model = (P 'ro.product.model'); device = (P 'ro.product.device')
    soc = (@((P 'ro.soc.manufacturer'), (P 'ro.soc.model')) -join ' ').Trim(); board = (P 'ro.board.platform'); hardware = (P 'ro.hardware')
    android = (P 'ro.build.version.release'); sdk = (P 'ro.build.version.sdk'); abi = (P 'ro.product.cpu.abi'); fingerprint = (P 'ro.build.fingerprint')
    screen = "${w}x${h}"; density = ([regex]::Match((Sh 'wm density'), 'Physical density:\s*(\d+)')).Groups[1].Value
    canvas_scale = $canvasScale; memtotal_gib = $memGib; tier = $Tier; tier_forced = [bool]$PSBoundParameters.ContainsKey('Tier')
    battery_start = (Battery); thermal_start = (Thermal); package = $Package; time = (Get-Date).ToString('s')
}
$model = ($facts.model -replace '[^A-Za-z0-9_-]', '_')
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $OutRoot "${model}_$($script:Serial -replace '[^A-Za-z0-9_.-]', '_')\${stamp}_session"
New-Item -ItemType Directory -Force $Out | Out-Null
function Save([string]$name, $text) { Set-Content -LiteralPath (Join-Path $Out $name) -Value $text -Encoding utf8 }
Write-Host "[device] $($facts.manufacturer) $($facts.model) soc=$($facts.soc)/$($facts.board) android=$($facts.android) screen=$($facts.screen) scale=$canvasScale mem=$memGib GiB tier=$Tier class=$($facts.evidence_class)"

# real devices: > 1 min measurement -> must hold the machine-wide lock
if (-not $fixture) {
    . (Join-Path $PSScriptRoot 'perf_isolation.ps1')
    Assert-HeavyRun 'device_session.ps1'
}

# ---------------------------------------------------------------- 3. install the perf APK
if (-not $NoInstall) {
    if (-not (Test-Path -LiteralPath $Apk)) { Write-Host "NO_PERF_APK: $Apk not found (02 P10 builds it). Nothing installed."; Save 'facts.json' ($facts | ConvertTo-Json -Depth 5); exit 2 }
    $inst = A @('-s', $script:Serial, 'install', '-r', '--no-incremental', $Apk)
    Save 'install.txt' $inst
    if ($inst -notmatch 'Success') { Write-Host "INSTALL_FAILED: $($inst.Trim())"; exit 1 }
}
if ((Sh "pm path $Package") -notmatch 'package:') { Write-Host "PACKAGE_MISSING: $Package is not installed on $($script:Serial)."; exit 2 }
$facts.apk = $(if ($NoInstall) { '(not installed by this run)' } else { $Apk })
Save 'facts.json' ($facts | ConvertTo-Json -Depth 5)

# ---------------------------------------------------------------- 4. scenes
$sceneDef = Get-Content -LiteralPath $ScenesFile -Raw | ConvertFrom-Json
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })   # -File passes 'a,b' as one string
$settle = [double]$sceneDef.settle_s
# 'plus_one' = 02's game/camera/world_zoom_plus_one: camera zoom (k+1)/k for canvas scale k
function ExpZoom($z) { if ("$z" -eq 'plus_one') { if ($canvasScale -gt 0) { return [math]::Round(($canvasScale + 1) / $canvasScale, 4) } else { return $null } } return [double]$z }
$plan = @()
if ($Soak) {
    $sid = $sceneDef.soak.scene
    $sc = $sceneDef.scenes | Where-Object { $_.id -eq $sid } | Select-Object -First 1
    $mins = if ($SoakMinutes -gt 0) { $SoakMinutes } else { [double]$sceneDef.soak.minutes }
    $win = if ($SoakWindow -gt 0) { $SoakWindow } else { [double]$sceneDef.soak.window_s }
    $plan += [pscustomobject]@{ id = "soak_$sid"; args = $sc.args; seconds = $mins * 60; zoom = (ExpZoom $sc.zoom); soak = $true; interval = [math]::Max($Interval, [double]$sceneDef.soak.interval_s); window = $win }
} else {
    foreach ($sc in $sceneDef.scenes) {
        if ($Only.Count -gt 0 -and $Only -notcontains $sc.id) { continue }
        $plan += [pscustomobject]@{ id = $sc.id; args = $sc.args; seconds = [double]$sc.seconds; zoom = (ExpZoom $sc.zoom); soak = $false; interval = $Interval; window = 0 }
    }
}
if ($plan.Count -eq 0) { Write-Host "NO_SCENES: -Only $($Only -join ',') matched nothing in $ScenesFile"; exit 1 }

# ---------------------------------------------------------------- blank-screen guards (a frame count alone can PASS on a blank screen)
# 1) logcat: shader compile / link failures and GL errors (real sample: 10's emulator run, Godot 4.7.2 + SwiftShader:
#    "ERROR: SceneShaderGLES3: Program linking failed:" / "Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)").
#    "WARNING: Failed to load cached shader, recompiling." is a normal cache miss and is ignored.
$GlesErrorPattern = '(?i)(ShaderGLES3: (Program linking|Vertex shader compilation|Fragment shader compilation|Shader compilation) failed|shader (compilation|compile|link|linking) failed|uniforms exceed GL_MAX_\w+|GL ERROR|GL_INVALID_(ENUM|VALUE|OPERATION|FRAMEBUFFER_OPERATION)|GL_OUT_OF_MEMORY|EGL_BAD_\w+|eglCreate\w+ failed|Vulkan.*failed|Couldn''t create.*(context|surface))'
function Gles-Errors([string]$log) {
    return @($log -split "`r?`n" | Where-Object { $_ -match $GlesErrorPattern -and $_ -notmatch 'Failed to load cached shader' })
}
# 2) one screenshot per scene: unique colours and luma spread on a 1/8 grid. Blank = <= 2 colours or luma std < 2.
#    Calibration (real emulator frames): blank SwiftShader frame 1 colour / std 0; the pixel-art menu 19 colours / std 34.
function Screen-Stats([string]$png) {
    Add-Type -AssemblyName System.Drawing
    $bmp = [System.Drawing.Bitmap]::new($png)
    try {
        $rect = [System.Drawing.Rectangle]::new(0, 0, $bmp.Width, $bmp.Height)
        $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $bytes = New-Object byte[] ($bd.Stride * $bmp.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
        $bmp.UnlockBits($bd)
        $set = New-Object 'System.Collections.Generic.HashSet[int]'
        $n = 0; $sum = 0.0; $sq = 0.0
        for ($y = 0; $y -lt $bmp.Height; $y += 8) {
            $row = $y * $bd.Stride
            for ($x = 0; $x -lt $bmp.Width; $x += 8) {
                $i = $row + 4 * $x
                $b = $bytes[$i]; $g = $bytes[$i + 1]; $r = $bytes[$i + 2]
                [void]$set.Add(($r -shl 16) -bor ($g -shl 8) -bor $b)
                $l = 0.299 * $r + 0.587 * $g + 0.114 * $b
                $n++; $sum += $l; $sq += $l * $l
            }
        }
        $mean = $sum / $n
        return [ordered]@{ width = $bmp.Width; height = $bmp.Height; unique_colors = $set.Count; luma_mean = [math]::Round($mean, 1)
            luma_std = [math]::Round([math]::Sqrt([math]::Max(0, $sq / $n - $mean * $mean)), 2) }
    } finally { $bmp.Dispose() }
}

function Find-Layer {
    $list = (Sh 'dumpsys SurfaceFlinger --list') -split "`r?`n" | Where-Object { $_ -match 'SurfaceView' -and $_ -match [regex]::Escape($Package) -and $_ -notmatch 'Background' } |
        Sort-Object { if ($_ -match '\(BLAST\)') { 0 } else { 1 } } | Select-Object -First 1
    if (-not $list) { return '' }
    $l = $list.Trim()
    $m = [regex]::Match($l, '^RequestedLayerState\{(.+?)(\s+parentId=.*)?\}$')   # Android 14+ list format
    if ($m.Success) { $l = $m.Groups[1].Value }
    return $l
}

function Run-Scene($sc) {
    $dir = Join-Path $Out $sc.id
    New-Item -ItemType Directory -Force $dir | Out-Null
    $r = [ordered]@{ id = $sc.id; args = ($sc.args -join ' '); zoom_requested = $sc.zoom; soak = $sc.soak; planned_s = $sc.seconds }
    # args file -> /data/local/tmp -> app's files/perf_args.txt (debuggable perf APK, run-as)
    $tmp = Join-Path $dir 'perf_args.txt'
    [IO.File]::WriteAllText($tmp, (($sc.args -join "`n") + "`n"))
    $null = A @('-s', $script:Serial, 'push', $tmp, '/data/local/tmp/defence_perf_args.txt')
    $null = Sh "run-as $Package mkdir -p files"
    $null = Sh "run-as $Package cp /data/local/tmp/defence_perf_args.txt files/perf_args.txt"
    $rb = (Sh "run-as $Package cat files/perf_args.txt") -replace "`r", ''
    $r.args_file_ok = ($rb.Trim() -eq ($sc.args -join "`n"))
    $null = Sh "am force-stop $Package"
    $null = A @('-s', $script:Serial, 'logcat', '-c')
    $null = Sh "dumpsys gfxinfo $Package reset"
    $start = Sh "am start -S -W -n $Package/$Activity"
    Set-Content -LiteralPath (Join-Path $dir 'am_start.txt') -Value $start -Encoding utf8
    $tt = [regex]::Match($start, 'TotalTime:\s+(\d+)'); $r.cold_start_ms = $(if ($tt.Success) { [int]$tt.Groups[1].Value } else { $null })
    # wait for the game's confirmation (max 30 s)
    $t0 = Get-Date; $ack = ''
    while ((NowS $t0) -lt 30) {
        $lg = A @('-s', $script:Serial, 'logcat', '-d', '-s', 'godot:V')
        $m = [regex]::Match($lg, '\[perf08\] args applied: (.+)')
        if ($m.Success) { $ack = $m.Groups[1].Value.Trim(); break }
        Nap 1
    }
    $r.args_ack = $ack
    $r.args_applied = [bool]$ack -and (@($sc.args | Where-Object { $ack -notmatch [regex]::Escape($_) }).Count -eq 0)
    # settle, then measure
    $t1 = Get-Date
    while ((NowS $t1) -lt $settle) { Nap 1 }
    # one screenshot after settle (shell screencap + pull: binary-safe for real adb and for the fake)
    $shot = Join-Path $dir 'screen.png'
    $null = Sh 'screencap -p /sdcard/perf08_screen.png'
    $null = A @('-s', $script:Serial, 'pull', '/sdcard/perf08_screen.png', $shot)
    $null = Sh 'rm /sdcard/perf08_screen.png'
    $r.screen = $null
    if (Test-Path -LiteralPath $shot) { try { $r.screen = Screen-Stats $shot } catch { $r.screen = [ordered]@{ error = "$_" } } }
    $r.blank_screen = $(if ($r.screen -and $r.screen.Contains('unique_colors')) { $r.screen.unique_colors -le 2 -or $r.screen.luma_std -lt 2 } else { $null })
    $null = Sh "dumpsys gfxinfo $Package reset"
    $layer = ''; $refreshNs = 0
    $presents = New-Object 'System.Collections.Generic.SortedSet[long]'
    $samples = New-Object System.Collections.Generic.List[object]
    $t2 = Get-Date; $nextSample = 0.0
    while ($true) {
        $now = NowS $t2
        if ($now -ge $sc.seconds) { break }
        if (-not $layer) { $layer = Find-Layer }
        if ($layer) {
            $lat = (Sh "dumpsys SurfaceFlinger --latency '$layer'") -split "`r?`n"
            if ($lat.Count -gt 1 -and $lat[0].Trim() -match '^\d+$') { $refreshNs = [long]$lat[0].Trim() }
            foreach ($l in ($lat | Select-Object -Skip 1)) {
                $p = $l.Trim() -split '\s+'
                if ($p.Count -ge 3) { $v = [long]$p[1]; if ($v -gt 0 -and $v -lt [long]::MaxValue) { [void]$presents.Add($v) } }
            }
        }
        if ($now -ge $nextSample) {
            $row = [ordered]@{ t_s = [math]::Round($now, 1) }
            $pidv = (Sh "pidof $Package").Trim()
            $row.pid = $pidv
            if ($pidv) {
                $mi = Sh "dumpsys meminfo $Package"
                foreach ($k in 'Native Heap', 'Graphics', 'GL mtrack', 'TOTAL PSS') {
                    $mm = [regex]::Match($mi, "(?m)^\s*$([regex]::Escape($k)):?\s+(\d+)")
                    if ($mm.Success) { $row[($k -replace ' ', '_').ToLower() + '_kb'] = [long]$mm.Groups[1].Value }
                }
                $cpu = ((Sh "top -b -n 1 -p $pidv -o %CPU") -split "`r?`n" | Where-Object { $_ -match '^\s*[\d.]+\s*$' } | Select-Object -Last 1)
                if ($cpu) { $row.cpu_pct = [double]$cpu.Trim() }
            }
            $b = Battery; $th = Thermal
            $row.battery_level = $b.level; $row.battery_temp_c = $b.temp_c; $row.current_ua = $b.current_ua; $row.usb_powered = ($b.usb -or $b.ac -or $b.wireless)
            foreach ($k in $th.Keys) { $row["thermal_$k"] = $th[$k] }
            $samples.Add([pscustomobject]$row)
            $nextSample += $sc.interval
        }
        Nap 1
    }
    $r.measured_s = [math]::Round((NowS $t2), 1)
    Set-Content -LiteralPath (Join-Path $dir 'gfxinfo_framestats.txt') -Value (Sh "dumpsys gfxinfo $Package framestats") -Encoding utf8
    Set-Content -LiteralPath (Join-Path $dir 'meminfo_final.txt') -Value (Sh "dumpsys meminfo $Package -d") -Encoding utf8
    $lgAll = A @('-s', $script:Serial, 'logcat', '-d', '-s', 'godot:V')
    Set-Content -LiteralPath (Join-Path $dir 'logcat_godot.txt') -Value $lgAll -Encoding utf8
    $null = Sh "am force-stop $Package"
    $samples | Export-Csv -LiteralPath (Join-Path $dir 'samples.csv') -NoTypeInformation -Encoding utf8
    @($presents) -join "`n" | Set-Content -LiteralPath (Join-Path $dir 'presents_ns.txt') -Encoding utf8

    # ---- frame stats from SurfaceFlinger present times
    $ts = @($presents)
    $iv = New-Object System.Collections.Generic.List[double]
    for ($i = 1; $i -lt $ts.Count; $i++) { $d = ($ts[$i] - $ts[$i - 1]) / 1e6; if ($d -gt 0 -and $d -lt 1000) { $iv.Add($d) } }
    $period = if ($refreshNs -gt 0) { $refreshNs / 1e6 } else { 16.667 }
    $r.layer = $layer; $r.refresh_ms = [math]::Round($period, 3); $r.frames = $iv.Count
    $r.frame_interval_p50_ms = Pct $iv 0.5; $r.frame_interval_p95_ms = Pct $iv 0.95; $r.frame_interval_p99_ms = Pct $iv 0.99
    $r.janky_share = $(if ($iv.Count) { [math]::Round(@($iv | Where-Object { $_ -gt 1.5 * $period }).Count / $iv.Count, 4) } else { $null })
    $span = if ($ts.Count -gt 1) { ($ts[-1] - $ts[0]) / 1e9 } else { 0 }
    $r.fps_mean = $(if ($span -gt 0) { [math]::Round(($ts.Count - 1) / $span, 2) } else { $null })
    $r.frame_coverage = $(if ($sc.seconds -gt 0 -and $period -gt 0) { [math]::Round($iv.Count / ($sc.seconds * 1000 / $period), 3) } else { $null })
    $gfx = Get-Content -LiteralPath (Join-Path $dir 'gfxinfo_framestats.txt') -Raw
    $gj = [regex]::Match($gfx, 'Janky frames:\s*(\d+)\s*\(([\d.]+)%\)'); $gt = [regex]::Match($gfx, 'Total frames rendered:\s*(\d+)')
    $r.hwui_frames = $(if ($gt.Success) { [int]$gt.Groups[1].Value } else { $null }); $r.hwui_janky_pct = $(if ($gj.Success) { [double]$gj.Groups[2].Value } else { $null })
    # ---- memory, battery, thermal, cpu
    $pss = @($samples | Where-Object { $_.total_pss_kb } | ForEach-Object { [double]$_.total_pss_kb })
    $r.samples = $samples.Count
    $r.app_running_samples = @($samples | Where-Object { $_.pid }).Count
    $r.pss_max_mb = $(if ($pss.Count) { [math]::Round(($pss | Measure-Object -Maximum).Maximum / 1024, 1) } else { $null })
    $gr = @($samples | Where-Object { $_.graphics_kb } | ForEach-Object { [double]$_.graphics_kb })
    $r.graphics_max_mb = $(if ($gr.Count) { [math]::Round(($gr | Measure-Object -Maximum).Maximum / 1024, 1) } else { $null })
    $r.cpu_pct_mean = Mean @($samples | Where-Object { $_.cpu_pct -ne $null } | ForEach-Object { [double]$_.cpu_pct })
    $bt = @($samples | Where-Object { $_.battery_temp_c -ne $null })
    $r.battery_temp_start_c = $(if ($bt.Count) { $bt[0].battery_temp_c }); $r.battery_temp_end_c = $(if ($bt.Count) { $bt[-1].battery_temp_c })
    $r.battery_temp_rise_c = $(if ($bt.Count -gt 1) { [math]::Round($bt[-1].battery_temp_c - $bt[0].battery_temp_c, 2) } else { $null })
    $r.thermal_status_max = $(if (@($samples | Where-Object { $_.thermal_status -ne $null }).Count) { (@($samples | ForEach-Object { $_.thermal_status }) | Measure-Object -Maximum).Maximum } else { $null })
    $r.usb_powered_any = [bool](@($samples | Where-Object { $_.usb_powered }).Count)
    $cur = @($samples | Where-Object { $_.current_ua -ne $null } | ForEach-Object { [double]$_.current_ua })
    $r.current_ma_mean = $(if ($cur.Count) { [math]::Round((($cur | Measure-Object -Average).Average) / 1000, 1) } else { $null })
    $lv = @($samples | Where-Object { $_.battery_level -ne $null })
    if ($lv.Count -gt 1 -and $r.measured_s -gt 0) {
        $drop = $lv[0].battery_level - $lv[-1].battery_level
        $r.battery_pct_drop = $drop
        $r.battery_pct_per_30min = $(if ($r.usb_powered_any) { $null } else { [math]::Round($drop / ($r.measured_s / 1800), 2) })
        $r.battery_note = $(if ($r.usb_powered_any) { 'NOT_MEASURED: USB/AC/wireless power present (use wireless adb on battery)' } else { 'on battery' })
    }
    # ---- the game's own monitor lines: [perf08] t=.. fps=.. frame_ms=.. dc=.. gpu_ms=.. rcpu_ms=.. tex_mib=.. scale=.. zoom=.. units=..
    $pl = @([regex]::Matches($lgAll, '\[perf08\] (t=[^\r\n]+)') | ForEach-Object { $kv = @{}; foreach ($p in ($_.Groups[1].Value -split '\s+')) { if ($p -match '^(\w+)=([-\d.]+)$') { $kv[$Matches[1]] = [double]$Matches[2] } }; [pscustomobject]$kv })
    $r.game_lines = $pl.Count
    if ($pl.Count) {
        $r.game_dc_p95 = Pct @($pl | Where-Object { $_.dc -ne $null } | ForEach-Object { $_.dc }) 0.95
        $r.game_gpu_ms_p50 = Pct @($pl | Where-Object { $_.gpu_ms -ne $null } | ForEach-Object { $_.gpu_ms }) 0.5
        $r.game_gpu_ms_p95 = Pct @($pl | Where-Object { $_.gpu_ms -ne $null } | ForEach-Object { $_.gpu_ms }) 0.95
        $r.game_rcpu_ms_p95 = Pct @($pl | Where-Object { $_.rcpu_ms -ne $null } | ForEach-Object { $_.rcpu_ms }) 0.95
        $r.game_tex_mib_max = (@($pl | Where-Object { $_.tex_mib -ne $null } | ForEach-Object { $_.tex_mib }) | Measure-Object -Maximum).Maximum
        $r.game_scale = (@($pl | Where-Object { $_.scale -ne $null } | ForEach-Object { $_.scale }) | Select-Object -First 1)
        $zs = @($pl | Where-Object { $_.zoom -ne $null } | ForEach-Object { $_.zoom })
        $r.game_zoom = $(if ($zs.Count) { $zs[-1] })
        $r.game_units_max = (@($pl | Where-Object { $_.units -ne $null } | ForEach-Object { $_.units }) | Measure-Object -Maximum).Maximum
    }
    $r.zoom_applied = $(if ($r.game_zoom -ne $null -and $sc.zoom -ne $null) { [math]::Abs([double]$r.game_zoom - [double]$sc.zoom) -lt 0.01 } else { $null })
    $r.valid = [bool]$r.args_applied -and ($r.zoom_applied -ne $false) -and $r.frames -gt 0
    $ge = Gles-Errors $lgAll
    $r.gles_errors = $ge.Count
    $r.gles_error_first = $(if ($ge.Count) { ($ge[0] -replace '^.*?: ', '').Trim() } else { '' })
    $reasons = @()
    if (-not $r.args_applied) { $reasons += 'ARGS_NOT_APPLIED' }
    if ($r.zoom_applied -eq $false) { $reasons += 'ZOOM_NOT_APPLIED' }
    if ($r.frames -le 0) { $reasons += 'NO_FRAMES' }
    if ($ge.Count -gt 0) { $reasons += 'GLES_SHADER_ERROR' }
    if ($r.blank_screen -eq $true) { $reasons += 'BLANK_SCREEN' }
    if ($r.blank_screen -eq $null) { $reasons += 'NO_SCREENCAP' }
    $r.valid = $r.valid -and $ge.Count -eq 0 -and $r.blank_screen -eq $false
    $r.invalid_reason = $reasons -join ','
    # ---- soak windows (device present-time based)
    if ($sc.soak -and $ts.Count -gt 2 -and $sc.window -gt 0) {
        $wins = @()
        $w0 = $ts[0]; $wl = [long]($sc.window * 1e9)
        $groups = $ts | Group-Object { [math]::Floor(($_ - $w0) / $wl) }
        foreach ($g in ($groups | Sort-Object { [int]$_.Name })) {
            $gt2 = @($g.Group); if ($gt2.Count -lt 3) { continue }
            $giv = New-Object System.Collections.Generic.List[double]
            for ($i = 1; $i -lt $gt2.Count; $i++) { $d = ($gt2[$i] - $gt2[$i - 1]) / 1e6; if ($d -gt 0 -and $d -lt 1000) { $giv.Add($d) } }
            $wins += [ordered]@{ window = [int]$g.Name; frames = $giv.Count; p95_ms = (Pct $giv 0.95); fps = [math]::Round(($gt2.Count - 1) / (($gt2[-1] - $gt2[0]) / 1e9), 2)
                span_s = [math]::Round(($gt2[-1] - $gt2[0]) / 1e9, 2) }
        }
        $r.soak_windows = $wins
        # compare only full windows: a trailing partial window (< half the window length) has edge-biased fps / p95
        $full = @($wins | Where-Object { $_.span_s -ge 0.5 * $sc.window })
        if ($full.Count -ge 2) {
            $r.soak_fps_last_over_first = [math]::Round($full[-1].fps / $full[0].fps, 3)
            $r.soak_p95_last_over_first = [math]::Round($full[-1].p95_ms / $full[0].p95_ms, 3)
        }
    }
    Write-Host ("[scene] {0,-22} valid={1} {2} frames={3} p95={4} ms janky={5} fps={6} pss_max={7} MB dc_p95={8} gpu_p95={9} temp {10}->{11} C" -f $r.id, $r.valid, $r.invalid_reason, $r.frames, $r.frame_interval_p95_ms, $r.janky_share, $r.fps_mean, $r.pss_max_mb, $r.game_dc_p95, $r.game_gpu_ms_p95, $r.battery_temp_start_c, $r.battery_temp_end_c)
    return $r
}

$results = @()
foreach ($sc in $plan) { $results += (Run-Scene $sc) }

# ---------------------------------------------------------------- 5. criteria
$verdicts = @()
foreach ($c in $criteria.criteria) {
    if (@($c.tiers) -notcontains $Tier) { continue }
    $pool = switch ($c.scenes) {
        'battle' { @($results | Where-Object { -not $_.soak }) }
        'soak' { @($results | Where-Object { $_.soak }) }
        default { @($results) }
    }
    $sk = ''
    if ($c.PSObject.Properties.Name -contains 'when_scale' -and [int]$c.when_scale -ne $canvasScale) { $sk = "device canvas scale is $canvasScale" }
    $vals = @($pool | Where-Object { $_.valid -and $_[$c.metric] -ne $null } | ForEach-Object { [double]$_[$c.metric] })
    $worst = $null; $res = 'NOT_MEASURED'
    if ($sk) { $res = 'NOT_APPLICABLE' }
    elseif ($vals.Count) {
        $worst = if ($c.op -in @('<=', '<')) { ($vals | Measure-Object -Maximum).Maximum } else { ($vals | Measure-Object -Minimum).Minimum }
        $ok = switch ($c.op) { '<=' { $worst -le $c.value } '<' { $worst -lt $c.value } '>=' { $worst -ge $c.value } '>' { $worst -gt $c.value } }
        $res = if ($ok) { 'PASS' } else { 'FAIL' }
    }
    $verdicts += [ordered]@{ id = $c.id; metric = $c.metric; op = $c.op; limit = $c.value; worst = $worst; result = $res; assumption = [bool]$c.assumption; source = $c.source; note = $sk }
}
$summary = [ordered]@{
    evidence_class = $facts.evidence_class; device = $facts; scenes = $results; criteria = $verdicts; adb_retries = $script:adbRetries
    note = 'Frame metrics are from SurfaceFlinger present times of the game SurfaceView (all Godot frames). gfxinfo/framestats cover the HWUI layer only. Desktop results never replace these.'
}
$summary | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Out 'summary.json') -Encoding utf8
$md = @("# Device session ${stamp}: $($facts.manufacturer) $($facts.model) ($($facts.evidence_class))",
    "SoC $($facts.soc) / $($facts.board), Android $($facts.android) (SDK $($facts.sdk)), screen $($facts.screen) -> canvas scale $canvasScale, MemTotal $memGib GiB -> tier **$Tier**$(if ($facts.tier_forced) { ' (forced)' }), package $Package", '',
    '| scene | valid | frames | fps | frame p50/p95/p99 ms | janky | PSS max MB | GPU mem MB | CPU % | cold start ms | game dc p95 | game GPU ms p50/p95 | tex MiB | temp C start->end | current mA | battery |',
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
foreach ($r in $results) {
    $md += "| $($r.id) | $(if ($r.valid) { 'yes' } else { 'NO ' + $r.invalid_reason }) | $($r.frames) | $($r.fps_mean) | $($r.frame_interval_p50_ms)/$($r.frame_interval_p95_ms)/$($r.frame_interval_p99_ms) | $($r.janky_share) | $($r.pss_max_mb) | $($r.graphics_max_mb) | $($r.cpu_pct_mean) | $($r.cold_start_ms) | $($r.game_dc_p95) | $($r.game_gpu_ms_p50)/$($r.game_gpu_ms_p95) | $($r.game_tex_mib_max) | $($r.battery_temp_start_c)->$($r.battery_temp_end_c) | $($r.current_ma_mean) | $(if ($r.battery_note) { $r.battery_note } else { '' }) |"
}
$soakR = @($results | Where-Object { $_.soak })
foreach ($r in $soakR) {
    $md += ''; $md += "Soak $($r.id): windows of $($plan[0].window) s"; $md += '| window | frames | fps | p95 ms |'; $md += '|---|---|---|---|'
    foreach ($wv in $r.soak_windows) { $md += "| $($wv.window) | $($wv.frames) | $($wv.fps) | $($wv.p95_ms) |" }
}
$md += ''; $md += "Criteria (tools/perf/device_criteria.json, tier $Tier; ASSUMPTION = no project source):"
$md += '| id | metric | limit | worst | result | basis |'; $md += '|---|---|---|---|---|---|'
foreach ($v in $verdicts) { $md += "| $($v.id) | $($v.metric) | $($v.op) $($v.limit) | $($v.worst) | **$($v.result)** | $(if ($v.assumption) { 'ASSUMPTION' } else { 'source' }): $($v.source)$(if ($v.note) { " ($($v.note))" }) |" }
$md | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
$md | ForEach-Object { Write-Host $_ }
Write-Host "[device] session $Out"
exit 0
