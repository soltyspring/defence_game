# Renders every 04 UI screen against the mock adapter at several phone/tablet shapes and saves PNGs
# to build/qa/screens/ (git-ignored). Requires a GPU/desktop session and a secondary monitor (exit 3 otherwise).
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
    # Visible windows must open on the SECONDARY monitor only (QUALITY_REVIEW.md) → route via visible_launch.ps1.
    $ua = @('--capture=build/qa/screens', "--tag=$($p[1])")
    if ($p[2]) { $ua += $p[2] }
    $ErrorActionPreference = 'Continue'
    $evid = Join-Path $Root 'build\qa\screens'
    $null = & (Join-Path $PSScriptRoot 'visible_launch.ps1') -Scene 'res://scenes/ui/ui_preview.tscn' -Resolution $p[0] -UserArgs $ua -TimeoutSec 60 -EvidenceDir $evid 6>&1
    if ($LASTEXITCODE -eq 3) { Write-Host 'BLOCKED: no secondary monitor'; exit 3 }
    $log = Get-ChildItem $evid -Filter 'godot_*.log' | Sort-Object LastWriteTime | Select-Object -Last 1
    $out = if ($log) { Get-Content $log.FullName -Raw } else { '' }
    $shots = ($out -split "`n" | Where-Object { $_ -match '^\[capture\].*err=0' }).Count
    Write-Host ("{0,-14} {1,-10} screens={2}" -f $p[1], $p[0], $shots)
    if ($shots -lt 6) { $fail++; Write-Host $out }
}
Write-Host "Output: $(Join-Path $Root 'build\qa\screens')"
exit $fail
