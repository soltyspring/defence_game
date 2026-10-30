# Visible game/editor launcher that ONLY uses a secondary (non-primary) monitor. Owner: 04-client.
# User rule (coordination/QUALITY_REVIEW.md): visible tests never open on the main monitor.
# Steps: enumerate monitors (per-monitor DPI aware) -> pick a non-primary work area -> start Godot
# with --position/--resolution inside it -> find the real HWND -> verify MonitorFromWindow == chosen
# monitor (move once if needed, else kill only the game process and fail) -> write evidence JSON.
# No other windows are moved. Exit codes: 0 ok, 3 no secondary monitor (BLOCKED), 4 placement failed,
# 5 game exited non-zero, 6 window not found.
#
# Examples:
#   .\tools\build\visible_launch.ps1 -Scene res://scenes/ui/ui_preview.tscn -UserArgs '--capture=build/qa/screens','--tag=sub'
#   .\tools\build\visible_launch.ps1 -UserArgs '--round=r01','--shots=2,6','--shot-dir=build/qa/visible','--quit-after=8'
#   .\tools\build\visible_launch.ps1 -ListOnly
param(
    [string]$Scene = '',                  # empty = project main scene (real game)
    [string]$Script = '',                 # optional: run a SceneTree script (-s res://...) visibly, e.g. the real-engine UI integration test
    [string]$Resolution = '1280x720',     # window client size; must fit the secondary work area
    [string[]]$UserArgs = @(),            # passed after `--` to the game (OS.get_cmdline_user_args)
    [int]$TimeoutSec = 120,
    [switch]$ListOnly,
    [switch]$NoWait,
    [double[]]$ScreenCaptureAt = @(),   # seconds after placement: OS-level grab of the window rect on the secondary display
    [string]$EvidenceDir = ''
)
. "$PSScriptRoot\common.ps1"
$ErrorActionPreference = 'Stop'
if (-not $EvidenceDir) { $EvidenceDir = Join-Path $Root 'build\qa\visible' }
New-Item -ItemType Directory -Force $EvidenceDir | Out-Null

if (-not ('DefWin.Native' -as [type])) {
Add-Type -Namespace DefWin -Name Native -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct MONITORINFOEX {
  public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szDevice; }
public delegate bool MonitorEnumProc(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr data);
public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
[DllImport("user32.dll")] public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc cb, IntPtr data);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr hMon, ref MONITORINFOEX mi);
[DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
[DllImport("shcore.dll")] public static extern int GetDpiForMonitor(IntPtr hmon, int type, out uint dx, out uint dy);
'@
}
# Per-monitor DPI aware v2 (-4) so coordinates are physical pixels, matching Godot's.
[void][DefWin.Native]::SetProcessDpiAwarenessContext([IntPtr](-4))

function Get-Monitors {
    $list = New-Object System.Collections.ArrayList
    $cb = [DefWin.Native+MonitorEnumProc]{
        param($h, $hdc, [ref]$r, $d)
        $mi = New-Object DefWin.Native+MONITORINFOEX
        $mi.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($mi)
        [void][DefWin.Native]::GetMonitorInfo($h, [ref]$mi)
        $dx = [uint32]0; $dy = [uint32]0
        [void][DefWin.Native]::GetDpiForMonitor($h, 0, [ref]$dx, [ref]$dy)
        [void]$list.Add([pscustomobject]@{
            Handle = $h; Device = $mi.szDevice; Primary = (($mi.dwFlags -band 1) -ne 0)
            Bounds = @($mi.rcMonitor.Left, $mi.rcMonitor.Top, $mi.rcMonitor.Right, $mi.rcMonitor.Bottom)
            Work = @($mi.rcWork.Left, $mi.rcWork.Top, $mi.rcWork.Right, $mi.rcWork.Bottom)
            Dpi = $dx; Scale = [math]::Round($dx / 96.0, 2)
        })
        return $true
    }
    [void][DefWin.Native]::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $cb, [IntPtr]::Zero)
    return $list
}

$mons = Get-Monitors
$mons | ForEach-Object { Write-Host ("monitor {0} primary={1} bounds={2} work={3} dpi={4} (x{5})" -f $_.Device, $_.Primary, ($_.Bounds -join ','), ($_.Work -join ','), $_.Dpi, $_.Scale) }
$sec = $mons | Where-Object { -not $_.Primary } | Sort-Object { ($_.Work[2]-$_.Work[0]) * ($_.Work[3]-$_.Work[1]) } -Descending | Select-Object -First 1
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidence = [ordered]@{ time = (Get-Date).ToString('o'); monitors = @($mons | Select-Object Device, Primary, Bounds, Work, Dpi, Scale); chosen = $null; window = $null; result = '' }
if ($ListOnly) { $evidence.result = 'list_only'; $evidence | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceDir "monitors_$stamp.json") -Encoding utf8; exit 0 }
if (-not $sec) {
    $evidence.result = 'BLOCKED_NO_SECONDARY_MONITOR'
    $evidence | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceDir "launch_$stamp.json") -Encoding utf8
    Write-Host 'BLOCKED: no secondary monitor; visible tests are not allowed on the primary monitor.'
    exit 3
}
$evidence.chosen = $sec.Device
Assert-File $GodotGui 'Godot GUI editor'
$w = [int]($Resolution.Split('x')[0]); $h = [int]($Resolution.Split('x')[1])
$work = $sec.Work
$ww = $work[2] - $work[0]; $wh = $work[3] - $work[1]
if ($w + 16 -gt $ww -or $h + 40 -gt $wh) {   # leave room for borders/title bar
    $k = [math]::Min(($ww - 16) / $w, ($wh - 40) / $h)
    $w = [int]([math]::Floor($w * $k / 2) * 2); $h = [int]([math]::Floor($h * $k / 2) * 2)
    Write-Host "resolution reduced to ${w}x${h} to fit secondary work area"
}
$x = [int]($work[0] + ($ww - $w) / 2); $y = [int]($work[1] + [math]::Max(32, ($wh - $h) / 2))
# Godot treats a negative "--position -1600,330" value as an unknown flag (observed: window opened at
# 0,330 on the PRIMARY monitor). Use --screen <index> (Godot enumerates monitors in EnumDisplayMonitors
# order, same as $mons) so the window is created on the secondary display; exact rect fixed below.
$screenIdx = [array]::IndexOf(@($mons | ForEach-Object { $_.Device }), $sec.Device)
$logFile = Join-Path $EvidenceDir "godot_$stamp.log"   # GUI exe has no console: keep stdout/stderr as evidence
$gargs = @('--path', $Root, '--screen', "$screenIdx", '--resolution', "${w}x${h}", '--log-file', $logFile)
if ($Script) { $gargs += @('-s', $Script) }
if ($Scene) { $gargs += $Scene }
if ($UserArgs.Count -gt 0) { $gargs += '--'; $gargs += $UserArgs }
Write-Host "launch: $GodotGui $($gargs -join ' ')"
$p = Start-Process -FilePath $GodotGui -ArgumentList ($gargs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -PassThru -WorkingDirectory $Root

# find the game's top-level visible window by PID
$hwnd = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds(20)
while ($hwnd -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline -and -not $p.HasExited) {
    Start-Sleep -Milliseconds 250
    $found = [IntPtr]::Zero
    $cb = [DefWin.Native+EnumWindowsProc]{ param($hw, $l) $pid2 = [uint32]0; [void][DefWin.Native]::GetWindowThreadProcessId($hw, [ref]$pid2); if ($pid2 -eq $p.Id -and [DefWin.Native]::IsWindowVisible($hw)) { $script:found = $hw; return $false }; return $true }
    [void][DefWin.Native]::EnumWindows($cb, [IntPtr]::Zero)
    $hwnd = $script:found
}
if ($hwnd -eq [IntPtr]::Zero) {
    $evidence.result = if ($p.HasExited) { "EXITED_BEFORE_WINDOW code=$($p.ExitCode)" } else { 'WINDOW_NOT_FOUND' }
    $evidence | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceDir "launch_$stamp.json") -Encoding utf8
    Write-Host $evidence.result
    if (-not $p.HasExited) { Stop-Process -Id $p.Id }   # only the game process this script started
    exit 6
}
function Test-OnSecondary {
    $r = New-Object DefWin.Native+RECT
    [void][DefWin.Native]::GetWindowRect($hwnd, [ref]$r)
    $mon = [DefWin.Native]::MonitorFromWindow($hwnd, 2)
    return [pscustomobject]@{ Rect = @($r.Left, $r.Top, $r.Right, $r.Bottom); OnChosen = ($mon -eq $sec.Handle) }
}
$st = Test-OnSecondary
$firstSeen = [ordered]@{ rect = $st.Rect; on_secondary = $st.OnChosen }
if (-not $st.OnChosen) {
    Write-Host "window at $($st.Rect -join ',') is not on $($sec.Device); moving it once"
    [void][DefWin.Native]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001 -bor 0x0004)   # NOSIZE|NOZORDER
    Start-Sleep -Milliseconds 300
    $st = Test-OnSecondary
}
$evidence.log = $logFile
$evidence.window = [ordered]@{ hwnd = $hwnd.ToInt64(); pid = $p.Id; first_seen = $firstSeen; rect = $st.Rect; on_secondary = $st.OnChosen; requested = @($x, $y, $w, $h); screen_index = $screenIdx }
if ($st.OnChosen) { [void][DefWin.Native]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001 -bor 0x0004); Start-Sleep -Milliseconds 200; $st = Test-OnSecondary; $evidence.window.rect = $st.Rect }
if (-not $st.OnChosen) {
    $evidence.result = 'PLACEMENT_FAILED'
    $evidence | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceDir "launch_$stamp.json") -Encoding utf8
    Stop-Process -Id $p.Id
    Write-Host 'FAIL: game window not on secondary monitor; game process stopped.'
    exit 4
}
# Bring ONLY the game window to the front: Windows' foreground lock ignores SetForegroundWindow from a
# background script (observed: worker terminals stayed on top), so make the game window TOPMOST for the
# run. Other windows are not moved or resized; topmost ends when the game exits (or -NoWait caller closes it).
[void][DefWin.Native]::SetWindowPos($hwnd, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002 -bor 0x0010)   # HWND_TOPMOST, NOSIZE|NOMOVE|NOACTIVATE
[void][DefWin.Native]::SetForegroundWindow($hwnd)
$evidence.window.topmost = $true
Write-Host "OK: window $($st.Rect -join ',') on $($sec.Device) (dpi $($sec.Dpi))"
if ($ScreenCaptureAt.Count -gt 0) {
    Add-Type -AssemblyName System.Drawing
    $t0 = Get-Date
    $evidence.screen_captures = @()
    foreach ($s in ($ScreenCaptureAt | Sort-Object)) {
        $wait = $s - ((Get-Date) - $t0).TotalSeconds
        if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]($wait * 1000)) }
        if ($p.HasExited) { break }
        $st = Test-OnSecondary
        $r = $st.Rect
        $bmp = New-Object System.Drawing.Bitmap ($r[2] - $r[0]), ($r[3] - $r[1])
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($r[0], $r[1], 0, 0, $bmp.Size)
        $png = Join-Path $EvidenceDir ("screen_{0}_{1:000}s.png" -f $stamp, [int]$s)
        $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
        $evidence.screen_captures += [ordered]@{ at = $s; file = $png; rect = $r; on_secondary = $st.OnChosen }
        Write-Host "screen capture $png rect=$($r -join ',') on_secondary=$($st.OnChosen)"
    }
}
if ($NoWait) { $evidence.result = 'RUNNING'; $evidence | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceDir "launch_$stamp.json") -Encoding utf8; exit 0 }
if (-not $p.WaitForExit($TimeoutSec * 1000)) { Stop-Process -Id $p.Id; $evidence.result = 'TIMEOUT_STOPPED' } else { $evidence.result = "EXIT_$($p.ExitCode)" }
$evidence | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceDir "launch_$stamp.json") -Encoding utf8
Write-Host "result: $($evidence.result)  evidence: $(Join-Path $EvidenceDir "launch_$stamp.json")"
if ($evidence.result -eq 'EXIT_0') { exit 0 } else { exit 5 }
