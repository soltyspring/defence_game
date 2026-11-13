# Normalize an ImageGen chapter plate to the game tile's exact raster contract.
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Output,
    [Parameter(Mandatory)][int]$GroundRow
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$logical = [System.Drawing.Bitmap]::new(1024,176)
$original = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $Source).Path)
try {
    if ($GroundRow -lt 1 -or $GroundRow -ge $original.Height) { throw 'GroundRow must be inside the source image.' }
    $painter = [System.Drawing.Graphics]::FromImage($logical)
    try {
        $ground = $original.GetPixel([int]($original.Width / 2), $original.Height - 8)
        $painter.Clear($ground)
        $painter.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $painter.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        # Keep landmark proportions; gain width from the quiet outer scenery.
        $edge = [int]($original.Width * 0.04)
        $center = [Math]::Min(1022,[int](($original.Width - 2*$edge) * 140 / $GroundRow))
        $leftWidth = [int][Math]::Floor((1024-$center)/2)
        $rightX = $leftWidth + $center
        $painter.DrawImage($original,[System.Drawing.Rectangle]::new(0,0,$leftWidth,140),[System.Drawing.Rectangle]::new(0,0,$edge,$GroundRow),[System.Drawing.GraphicsUnit]::Pixel)
        $painter.DrawImage($original,[System.Drawing.Rectangle]::new($leftWidth,0,$center,140),[System.Drawing.Rectangle]::new($edge,0,$original.Width-2*$edge,$GroundRow),[System.Drawing.GraphicsUnit]::Pixel)
        $painter.DrawImage($original,[System.Drawing.Rectangle]::new($rightX,0,1024-$rightX,140),[System.Drawing.Rectangle]::new($original.Width-$edge,0,$edge,$GroundRow),[System.Drawing.GraphicsUnit]::Pixel)
    } finally { $painter.Dispose() }
    # Join the quiet end strips through one shared edge profile. Leave the
    # landmarks in the center intact; do not flip any tiles.
    for ($y = 0; $y -lt 140; $y++) {
        $left = $logical.GetPixel(0,$y)
        $right = $logical.GetPixel(1023,$y)
        for ($i = 0; $i -lt 24; $i++) {
            $t = (1 - $i / 24.0) / 2
            foreach ($side in 0,1) {
                $x = if ($side) { 1023 - $i } else { $i }
                $here = $logical.GetPixel($x,$y)
                $other = if ($side) { $left } else { $right }
                $logical.SetPixel($x,$y,[System.Drawing.Color]::FromArgb(
                    [int]($here.R * (1-$t) + $other.R*$t),
                    [int]($here.G * (1-$t) + $other.G*$t),
                    [int]($here.B * (1-$t) + $other.B*$t)))
            }
        }
    }
    # Weighted median cut. Quantize once, on the logical pixels, with no dither.
    $counts = @{}
    for ($y = 0; $y -lt 176; $y++) {
        for ($x = 0; $x -lt 1024; $x++) {
            $c = $logical.GetPixel($x,$y)
            $key = ([int]$c.R -shl 16) -bor ([int]$c.G -shl 8) -bor $c.B
            $counts[$key]++
        }
    }
    $entries = @(foreach ($key in $counts.Keys) {
        [pscustomobject]@{ Key=$key; R=($key -shr 16); G=(($key -shr 8) -band 255); B=($key -band 255); Count=$counts[$key] }
    })
    $boxes = [System.Collections.Generic.List[object]]::new()
    $boxes.Add($entries)
    while ($boxes.Count -lt 32) {
        $best = -1
        $score = 0
        for ($i = 0; $i -lt $boxes.Count; $i++) {
            if ($boxes[$i].Count -lt 2) { continue }
            foreach ($axis in 'R','G','B') {
                $stats = $boxes[$i] | Measure-Object -Property $axis -Minimum -Maximum
                $range = $stats.Maximum - $stats.Minimum
                if ($range -gt $score) { $score=$range; $best=$i; $channel=$axis }
            }
        }
        if ($best -lt 0) { break }
        $sorted = @($boxes[$best] | Sort-Object $channel,Key)
        $half = ($sorted | Measure-Object Count -Sum).Sum / 2
        $cum = 0
        $split = 0
        do { $cum += $sorted[$split++].Count } while ($cum -lt $half -and $split -lt $sorted.Count - 1)
        $boxes[$best] = $sorted[0..($split-1)]
        $boxes.Add($sorted[$split..($sorted.Count-1)])
    }
    $palette = @(foreach ($box in $boxes) {
        $r=0.0; $g=0.0; $b=0.0; $n=0
        foreach ($c in $box) { $r+=$c.R*$c.Count; $g+=$c.G*$c.Count; $b+=$c.B*$c.Count; $n+=$c.Count }
        [System.Drawing.Color]::FromArgb([int]($r/$n),[int]($g/$n),[int]($b/$n))
    })
    $mapping = @{}
    foreach ($c in $entries) {
        $distance = [double]::MaxValue
        foreach ($swatch in $palette) {
            $dr=$c.R-$swatch.R; $dg=$c.G-$swatch.G; $db=$c.B-$swatch.B
            $d=3*$dr*$dr+4*$dg*$dg+2*$db*$db
            if ($d -lt $distance) { $distance=$d; $mapping[$c.Key]=$swatch }
        }
    }
    for ($y = 0; $y -lt 176; $y++) {
        for ($x = 0; $x -lt 1024; $x++) {
            $c = $logical.GetPixel($x,$y)
            $key = ([int]$c.R -shl 16) -bor ([int]$c.G -shl 8) -bor $c.B
            $logical.SetPixel($x,$y,$mapping[$key])
        }
    }
    $png = [System.Drawing.Bitmap]::new(4096,704,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $painter = [System.Drawing.Graphics]::FromImage($png)
        try {
            $painter.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $painter.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
            $painter.DrawImage($logical,[System.Drawing.Rectangle]::new(0,0,4096,704),[System.Drawing.Rectangle]::new(0,0,1024,176),[System.Drawing.GraphicsUnit]::Pixel)
        } finally { $painter.Dispose() }
        $png.Save([IO.Path]::GetFullPath((Join-Path (Get-Location) $Output)),[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $png.Dispose() }
} finally { $logical.Dispose(); $original.Dispose() }
