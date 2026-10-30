# Renders every 04 UI screen against the mock adapter at several phone/tablet shapes and saves PNGs
# to build/qa/screens/ (git-ignored). Requires a GPU/desktop session (not headless).
# Usage: .\tools\build\capture_ui.ps1
. "$PSScriptRoot\common.ps1"
Assert-File $GodotConsole 'Godot console editor'
Set-Location $Root
# window size, tag, safe insets L,T,R,B in logical px (640x360 base, canvas_items+expand)
$profiles = @(
    @('1280x720', '16x9', ''),
    @('1440x720', '18x9', ''),
    @('1600x720', '20x9_notch', '--safe=34,0,0,0'),
    @('1680x720', '21x9_both', '--safe=34,0,34,12'),
    @('1280x800', '16x10_tablet', ''),
    @('1024x768', '4x3_tablet', '')
)
$fail = 0
foreach ($p in $profiles) {
    $a = @('--path', '.', '--resolution', $p[0], 'res://scenes/ui/ui_preview.tscn', '--', '--capture=build/qa/screens', "--tag=$($p[1])")
    if ($p[2]) { $a += $p[2] }
    $ErrorActionPreference = 'Continue'
    $out = & $GodotConsole @a 2>&1 | Out-String
    $shots = ($out -split "`n" | Where-Object { $_ -match '^\[capture\].*err=0' }).Count
    Write-Host ("{0,-14} {1,-10} screens={2}" -f $p[1], $p[0], $shots)
    if ($shots -lt 6) { $fail++; Write-Host $out }
}
Write-Host "Output: $(Join-Path $Root 'build\qa\screens')"
exit $fail
