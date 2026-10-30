# 08-performance Android device capture (DEVICE evidence; only real readings, nothing synthesised). Owner: 08-performance.
# Procedure and interpretation: docs/performance/ANDROID_PROFILING.md.
# Usage (workspace root, phone connected with USB debugging, debug or release APK already installed by 04's pipeline):
#   .\tools\perf\android_capture.ps1 [-Serial <id>] [-Seconds 300] [-Interval 5] [-Label r06_autoplay] [-SimulateUnplug] [-NoLaunch]
# Steps: device facts -> cold start (am start -S -W) -> periodic samples (dumpsys meminfo PSS breakdown, top CPU%,
# thermal status/temperatures, battery level/temperature, SurfaceFlinger present timestamps) -> batterystats,
# gfxinfo, logcat -> summary.json. Output: build/perf/device/<model>_<serial>/<stamp>/ (git-ignored).
# Exit: 0 captured, 2 = no device / package not installed (NO phone evidence produced), 1 = error.
param(
    [string]$Serial = '',
    [string]$Package = '',
    [int]$Seconds = 300,
    [int]$Interval = 5,
    [string]$Label = 'session',
    [switch]$SimulateUnplug,
    [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Sdk = @($env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk')) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'platform-tools\adb.exe')) } | Select-Object -First 1
if (-not $Sdk) { Write-Host 'NO_ADB: Android platform-tools not found. No device evidence.'; exit 2 }
$Adb = Join-Path $Sdk 'platform-tools\adb.exe'
if ($Package -eq '') {
    $m = Select-String -Path (Join-Path $Root 'export_presets.cfg') -Pattern '^package/unique_name="([^"]+)"' -ErrorAction SilentlyContinue | Select-Object -First 1
    $Package = if ($m) { $m.Matches[0].Groups[1].Value } else { 'com.soltyspring.lanedefence' }
}

$devs = @(& $Adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' } | ForEach-Object { ($_ -split "`t")[0] })
if ($devs.Count -eq 0) { Write-Host 'NO_DEVICE: adb lists no authorised device. No phone evidence captured.'; exit 2 }
if ($Serial -eq '') { $Serial = $devs[0] }
if ($devs -notcontains $Serial) { Write-Host "NO_DEVICE: serial $Serial not attached ($($devs -join ', '))."; exit 2 }

function Sh([string]$cmd) { (& $Adb -s $Serial shell $cmd 2>&1 | Out-String) }
function Prop([string]$k) { (Sh "getprop $k").Trim() }

$isEmu = (Prop 'ro.kernel.qemu') -eq '1' -or (Prop 'ro.hardware') -match 'ranchu|goldfish'
$model = (Prop 'ro.product.model') -replace '[^A-Za-z0-9_-]', '_'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\device\${model}_$Serial\$stamp`_$Label"
New-Item -ItemType Directory -Force $Out | Out-Null
function Save([string]$name, [string]$text) { Set-Content -LiteralPath (Join-Path $Out $name) -Value $text -Encoding utf8 }

if (-not ((Sh "pm list packages $Package") -match [regex]::Escape("package:$Package"))) {
    Write-Host "NO_PACKAGE: $Package is not installed on $Serial. Install the APK first (04 pipeline)."; exit 2
}

# ---- device facts ----
$memTotalKb = [int](([regex]::Match((Sh 'cat /proc/meminfo'), 'MemTotal:\s+(\d+)')).Groups[1].Value)
$facts = [ordered]@{
    evidence_class = $(if ($isEmu) { 'EMULATOR (not phone evidence)' } else { 'DEVICE' })
    serial = $Serial; manufacturer = Prop 'ro.product.manufacturer'; model = Prop 'ro.product.model'; device = Prop 'ro.product.device'
    soc_model = Prop 'ro.soc.model'; soc_manufacturer = Prop 'ro.soc.manufacturer'; board = Prop 'ro.board.platform'; hardware = Prop 'ro.hardware'
    android = Prop 'ro.build.version.release'; sdk = Prop 'ro.build.version.sdk'; fingerprint = Prop 'ro.build.fingerprint'
    abi = Prop 'ro.product.cpu.abi'; ram_mb = [math]::Round($memTotalKb / 1024)
    screen = (Sh 'wm size').Trim(); density = (Sh 'wm density').Trim()
    gles = ([regex]::Match((Sh 'dumpsys SurfaceFlinger'), 'GLES: [^\r\n]+')).Value
    package = $Package; package_version = ([regex]::Match((Sh "dumpsys package $Package"), 'versionName=(\S+)')).Groups[1].Value
    label = $Label; seconds = $Seconds; interval = $Interval; started = (Get-Date).ToString('s'); simulate_unplug = [bool]$SimulateUnplug
}
Save 'device.json' ($facts | ConvertTo-Json)
Write-Host "[device] $($facts.manufacturer) $($facts.model) soc=$($facts.soc_model)/$($facts.board) android=$($facts.android) ram=$($facts.ram_mb)MB class=$($facts.evidence_class)"

$samples = New-Object System.Collections.Generic.List[object]
$presents = New-Object System.Collections.Generic.HashSet[long]
$refreshNs = 0
try {
    if ($SimulateUnplug) { Sh 'dumpsys battery unplug' | Out-Null }
    Sh 'dumpsys batterystats --reset' | Out-Null
    Save 'battery_before.txt' (Sh 'dumpsys battery')
    Save 'thermal_before.txt' (Sh 'dumpsys thermalservice')
    & $Adb -s $Serial logcat -c 2>$null

    # ---- cold start ----
    if (-not $NoLaunch) {
        $comp = ((Sh "cmd package resolve-activity --brief $Package") -split "`n" | Where-Object { $_ -match '/' } | Select-Object -Last 1).Trim()
        $start = Sh "am start -S -W -n $comp"
        Save 'cold_start.txt' $start
        $facts.cold_start_total_ms = [int](([regex]::Match($start, 'TotalTime:\s+(\d+)')).Groups[1].Value)
        $facts.cold_start_wait_ms = [int](([regex]::Match($start, 'WaitTime:\s+(\d+)')).Groups[1].Value)
        Write-Host "[device] cold start TotalTime=$($facts.cold_start_total_ms) ms ($comp)"
    }
    Sh "dumpsys gfxinfo $Package reset" | Out-Null

    # ---- sampling ----
    $t0 = Get-Date
    $layer = ''
    while (((Get-Date) - $t0).TotalSeconds -lt $Seconds) {
        $pidv = (Sh "pidof $Package").Trim()
        $row = [ordered]@{ t_s = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1); pid = $pidv }
        if ($pidv) {
            $mi = Sh "dumpsys meminfo $Package"
            foreach ($k in 'Java Heap', 'Native Heap', 'Code', 'Stack', 'Graphics', 'Private Other', 'System', 'TOTAL PSS') {
                $mm = [regex]::Match($mi, "(?m)^\s*$([regex]::Escape($k)):\s+(\d+)")
                if ($mm.Success) { $row[($k -replace ' ', '_').ToLower() + '_kb'] = [int]$mm.Groups[1].Value }
            }
            if (-not $row.Contains('total_pss_kb')) { $mm = [regex]::Match($mi, '(?m)^\s*TOTAL\s+(\d+)'); if ($mm.Success) { $row.total_pss_kb = [int]$mm.Groups[1].Value } }
            $gl = [regex]::Match($mi, '(?m)^\s*GL mtrack\s+(\d+)'); if ($gl.Success) { $row.gl_mtrack_kb = [int]$gl.Groups[1].Value }
            $top = Sh "top -b -n 1 -p $pidv -o %CPU"
            $cpu = ($top -split "`n" | Where-Object { $_ -match '^\s*[\d.]+\s*$' } | Select-Object -Last 1)
            if ($cpu) { $row.cpu_pct = [double]$cpu.Trim() }
        }
        $th = Sh 'dumpsys thermalservice'
        $st = [regex]::Match($th, 'Thermal Status:\s*(\d+)'); if ($st.Success) { $row.thermal_status = [int]$st.Groups[1].Value }
        $temps = [regex]::Matches($th, 'mValue=([\d.]+), mType=(\d+), mName=([^,]+)')
        foreach ($type in @(@(0, 'cpu'), @(1, 'gpu'), @(2, 'battery'), @(3, 'skin'))) {
            $v = @($temps | Where-Object { [int]$_.Groups[2].Value -eq $type[0] } | ForEach-Object { [double]$_.Groups[1].Value })
            if ($v.Count -gt 0) { $row["temp_$($type[1])_max_c"] = ($v | Measure-Object -Maximum).Maximum }
        }
        $bat = Sh 'dumpsys battery'
        $lv = [regex]::Match($bat, 'level:\s*(\d+)'); if ($lv.Success) { $row.battery_level = [int]$lv.Groups[1].Value }
        $bt = [regex]::Match($bat, 'temperature:\s*(\d+)'); if ($bt.Success) { $row.battery_temp_c = [int]$bt.Groups[1].Value / 10.0 }
        # SurfaceFlinger present timestamps of the game's SurfaceView (Godot renders to a SurfaceView, not HWUI)
        if ($layer -eq '') {
            $layer = ((Sh 'dumpsys SurfaceFlinger --list') -split "`n" | Where-Object { $_ -match 'SurfaceView' -and $_ -match [regex]::Escape($Package) } | Where-Object { $_ -notmatch 'Background' } | Select-Object -First 1)
            if ($layer) { $layer = $layer.Trim() }
        }
        if ($layer) {
            $lat = (& $Adb -s $Serial shell dumpsys SurfaceFlinger --latency "`"$layer`"" 2>&1 | Out-String) -split "`n"
            if ($lat.Count -gt 1 -and $lat[0].Trim() -match '^\d+$') { $refreshNs = [long]$lat[0].Trim() }
            foreach ($l in ($lat | Select-Object -Skip 1)) {
                $p = $l.Trim() -split '\s+'
                if ($p.Count -ge 3) { $a = [long]$p[1]; if ($a -gt 0 -and $a -lt [long]::MaxValue) { [void]$presents.Add($a) } }
            }
        }
        $samples.Add([pscustomobject]$row)
        Write-Host ("[sample] t={0}s pss={1}KB gfx={2}KB cpu={3}% thermal={4} cpu_t={5} bat={6}%/{7}C frames={8}" -f $row.t_s, $row.total_pss_kb, $row.graphics_kb, $row.cpu_pct, $row.thermal_status, $row.temp_cpu_max_c, $row.battery_level, $row.battery_temp_c, $presents.Count)
        Start-Sleep -Seconds $Interval
    }

    # ---- post ----
    Save 'meminfo_final.txt' (Sh "dumpsys meminfo $Package -d")
    Save 'gfxinfo_framestats.txt' (Sh "dumpsys gfxinfo $Package framestats")
    Save 'batterystats.txt' (Sh "dumpsys batterystats $Package")
    Save 'battery_after.txt' (Sh 'dumpsys battery')
    Save 'thermal_after.txt' (Sh 'dumpsys thermalservice')
    Save 'logcat_godot.txt' (& $Adb -s $Serial logcat -d -s godot:V 2>&1 | Out-String)
} finally {
    if ($SimulateUnplug) { Sh 'dumpsys battery reset' | Out-Null }
}

$samples | Export-Csv -LiteralPath (Join-Path $Out 'samples.csv') -NoTypeInformation -Encoding utf8
# frame intervals from present timestamps
$ts = @($presents | Sort-Object)
$iv = @(); for ($i = 1; $i -lt $ts.Count; $i++) { $d = ($ts[$i] - $ts[$i - 1]) / 1e6; if ($d -gt 0 -and $d -lt 1000) { $iv += $d } }
function Pct($arr, [double]$q) { if ($arr.Count -eq 0) { return $null }; $s = @($arr | Sort-Object); return [math]::Round($s[[math]::Min($s.Count - 1, [int]($s.Count * $q))], 2) }
$pss = @($samples | Where-Object { $_.total_pss_kb } | ForEach-Object { $_.total_pss_kb })
$summary = [ordered]@{
    device = $facts
    samples = $samples.Count
    pss_kb = @{ max = ($pss | Measure-Object -Maximum).Maximum; avg = [math]::Round(($pss | Measure-Object -Average).Average) }
    graphics_kb_max = (@($samples | ForEach-Object { $_.graphics_kb }) | Measure-Object -Maximum).Maximum
    cpu_pct_avg = [math]::Round((@($samples | Where-Object { $_.cpu_pct -ne $null } | ForEach-Object { $_.cpu_pct }) | Measure-Object -Average).Average, 1)
    thermal_status_max = (@($samples | ForEach-Object { $_.thermal_status }) | Measure-Object -Maximum).Maximum
    temp_cpu_max_c = (@($samples | ForEach-Object { $_.temp_cpu_max_c }) | Measure-Object -Maximum).Maximum
    battery_level_start = $samples[0].battery_level; battery_level_end = $samples[$samples.Count - 1].battery_level
    surfaceflinger = @{ layer = $layer; refresh_ns = $refreshNs; frames = $iv.Count; interval_ms_p50 = (Pct $iv 0.5); p95 = (Pct $iv 0.95); p99 = (Pct $iv 0.99)
        over_16_7ms = @($iv | Where-Object { $_ -gt 16.7 * 1.5 }).Count; over_33_3ms = @($iv | Where-Object { $_ -gt 33.4 * 1.5 }).Count
        note = 'SurfaceFlinger --latency keeps only the last ~128 frames; capture coverage = frames / (Seconds*fps). Intervals > 1.5x period counted as janks.' }
}
$summary | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Out 'summary.json') -Encoding utf8
Write-Host "[device] summary $Out\summary.json"
exit 0
