# 08-performance: RELATIVE GPU-fill / render cost of unit-size options at phone resolutions, on this desktop (no phone exists).
# DESKTOP PROXY only: desktop GPU ms are used for ratios between variants, never as phone values.
# Must run inside the machine-wide lock, started DETACHED (coordination/HEAVY_RUN.md 'Detached heavy runs'):
#   job file build\heavy\08-phone-fill-job.ps1:  & .\tools\perf\phone_fill_matrix.ps1 -Rev <sha> -PreRev <sha>
#   & .\coordination\heavy_run_detached.ps1 -Label '08-phone-fill' -ScriptFile build\heavy\08-phone-fill-job.ps1
# Steps (serial, one Godot at a time, each through 10's isolated_godot.ps1 with a 1 s foreign-process monitor):
#  1. git archive copies: base = <Rev>; draft = <Rev> + ART_DRAFT32=<Draft> art build (copy only; shipped assets checked unchanged);
#     pre = <PreRev> (optional: the commit before 04's HUD layering, for the HUD before/after).
#  2. asset_budget_check --tree for base and draft; --import per copy.
#  3. timing matrix, perf_drawcall_probe.gd --dc-set=units --dc-uncapped --dc-window=<W>x<H> (borderless, integer scale 3 at 1080 px
#     high; overflow off-screen, never on the primary monitor): for each window: base, draft, draft + --dc-zoom=<Zoom>; then base at
#     the first window again (drift check); then pre at the first window (HUD draw calls before 04's layering).
#  4. full draw-call breakdown of base at the first window (per HUD child), capped (counts do not depend on fps).
#  5. 04's mock UI capture (scenes/ui/ui_preview.tscn --capture) for base and pre, 1280x720, and a pixel diff per screen.
# Output: build/perf/phonefill_<sha>_<stamp>/ (git-ignored): run_*.json/.log, ui_*/, ui_diff.json, summary.json, summary.md.
# Exit 0 ran / 1 error / 3 isolation not proven / 4 not inside heavy_run.
param([Parameter(Mandatory)][string]$Rev, [string]$PreRev = '', [string]$Draft = 'D1FULL', [string[]]$Windows = @('2400x1080', '2340x1080'),
      [double]$Zoom = 1.3333333, [string]$Round = 'r08', [double]$Warmup = 35, [double]$Phase = 3, [int]$Cycles = 5)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
. (Join-Path $PSScriptRoot 'perf_isolation.ps1')
Assert-HeavyRun 'phone_fill_matrix.ps1'
$Iso10 = Join-Path $Root 'docs\research\systems\probes\isolated_godot.ps1'
if (-not (Test-Path $Iso10)) { throw "missing 10's isolation wrapper $Iso10" }
$sha = (& git rev-parse --short $Rev).Trim()
$preSha = if ($PreRev) { (& git rev-parse --short $PreRev).Trim() } else { '' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\phonefill_${sha}_$stamp"
New-Item -ItemType Directory -Force $Out | Out-Null
# snapshots on the LOCAL disk: Z: is a network share, and a --import there stalled for 15 min on 2026-11-01 02:41 (idle Godot after
# writing its .ctex files); %TEMP% is local and is what 04/06 use for HEAD copies
$snapRoot = Join-Path $env:TEMP "perf08_phonefill_$sha"
$dirs = [ordered]@{ base = (Join-Path $snapRoot 'base'); draft = (Join-Path $snapRoot "draft_$Draft") }
if ($preSha) { $dirs.pre = Join-Path $snapRoot "pre_$preSha" }
$revOf = @{ base = $sha; draft = $sha; pre = $preSha }
$pa = New-PerfAppData $Root 'phone_fill'
$isoWork = Join-Path $pa 'iso10'
function Log([string]$m) { $l = "[phonefill $(Get-Date -Format 'HH:mm:ss')] $m"; Write-Host $l; Add-Content -LiteralPath (Join-Path $Out 'phonefill.log') -Value $l -Encoding utf8 }

# ---- 1. snapshots ----
foreach ($k in $dirs.Keys) {
    $d = $dirs[$k]
    if (Test-Path $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    New-Item -ItemType Directory -Force $d | Out-Null
    $tar = Join-Path $Out "$k.tar"
    $paths = @('project.godot', 'icon.svg', 'src', 'scenes', 'data', 'assets')
    if ($k -eq 'draft') { $paths += @('tools/art', 'docs/art') }
    & git archive --format=tar -o $tar $revOf[$k] @paths
    if ($LASTEXITCODE -ne 0) { throw "git archive failed ($k)" }
    & tar -xf $tar -C $d
    Remove-Item $tar
    New-Item -ItemType Directory -Force (Join-Path $d 'tests\performance'), (Join-Path $d '.godot') | Out-Null
    Copy-Item (Join-Path $Root 'tests\performance\*.gd') (Join-Path $d 'tests\performance\') -Force
    if (Test-Path (Join-Path $Root '.godot\imported')) { Copy-Item (Join-Path $Root '.godot\imported') (Join-Path $d '.godot\') -Recurse }
    if ($k -eq 'draft') {
        # same draft art imported before (M16 art_variant_ab copy): seed it so the draft --import has nothing to re-import
        $prev = Get-ChildItem (Join-Path $Root 'build\perf') -Directory -Filter 'artab_*' -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName "draft_$Draft\.godot\imported" } | Where-Object { Test-Path $_ } | Select-Object -Last 1
        if ($prev) { Copy-Item (Join-Path $prev '*') (Join-Path $d '.godot\imported\') -Force; Log "draft import cache seeded from $prev" }
    }
}
Log "snapshots: base/draft=$sha pre=$preSha"
$hashBefore = (Get-ChildItem (Join-Path $Root 'assets\atlases') -File | Get-FileHash | ForEach-Object { $_.Hash }) -join ''
$prevDraft = $env:ART_DRAFT32; $env:ART_DRAFT32 = $Draft
$ErrorActionPreference = 'Continue'
try { $bo = & python (Join-Path $dirs.draft 'tools\art\build.py') 2>&1 | Out-String; $bcode = $LASTEXITCODE } finally { $env:ART_DRAFT32 = $prevDraft; $ErrorActionPreference = 'Stop' }
Set-Content -LiteralPath (Join-Path $Out 'draft_build.log') -Value $bo -Encoding utf8
$shippedUnchanged = $hashBefore -eq ((Get-ChildItem (Join-Path $Root 'assets\atlases') -File | Get-FileHash | ForEach-Object { $_.Hash }) -join '')
Log "draft build ART_DRAFT32=$Draft exit=$bcode; working-tree atlases unchanged=$shippedUnchanged"
if ($bcode -ne 0 -or -not $shippedUnchanged) { throw 'draft build failed or touched the working tree' }

# ---- 2. gate ----
$gate = [ordered]@{}
foreach ($k in @('base', 'draft')) {
    $ErrorActionPreference = 'Continue'
    $gl = & python (Join-Path $Root 'tools\perf\asset_budget_check.py') --tree $dirs[$k] --base $sha --out (Join-Path $Out "gate_$k") 2>&1 | Out-String
    $ErrorActionPreference = 'Stop'
    $gate[$k] = ($gl -split "`r?`n" | Where-Object { $_ -like 'ASSET_CHECK target=*' } | Select-Object -Last 1)
    Log "gate $k $($gate[$k])"
}

# ---- isolated, monitored Godot call ----
function Invoke-Iso([string]$Name, [string[]]$GArgs, [int]$TimeoutSec = 900) {
    $log = Join-Path $Out "$Name.log"
    Get-ChildItem -Path $isoWork -Recurse -Filter 'save.json*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $job = Start-ThreadJob -ArgumentList $PID -ScriptBlock {
        param($parent)
        $seen = @{}
        while ($true) {
            $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
            $own = New-Object System.Collections.Generic.HashSet[int]; [void]$own.Add([int]$parent)
            $grew = $true
            while ($grew) { $grew = $false; foreach ($p in $all) { if ($own.Contains([int]$p.ParentProcessId) -and $own.Add([int]$p.ProcessId)) { $grew = $true } } }
            foreach ($p in $all) {
                # ThreadCount 0 = already exited but still listed (e.g. pid 40304 after a timed-out import on 2026-11-01): no load, ignore it
                if (($p.Name -like 'Godot*' -or $p.Name -like 'qemu-system*' -or $p.Name -like 'emulator*' -or $p.Name -like 'java*') -and [int]$p.ThreadCount -gt 0 -and -not $own.Contains([int]$p.ProcessId) -and -not $seen.ContainsKey([int]$p.ProcessId)) {
                    $seen[[int]$p.ProcessId] = 1
                    Write-Output "$($p.ProcessId) $($p.Name) $(if ($p.CommandLine) { $p.CommandLine.Substring(0, [math]::Min(140, $p.CommandLine.Length)) })"
                }
            }
            Start-Sleep -Milliseconds 1000
        }
    }
    $t0 = Get-Date
    $ErrorActionPreference = 'Continue'
    try { $o = & $Iso10 -GodotArgs $GArgs -WorkDir $isoWork -Keep -TimeoutSec $TimeoutSec 2>&1 | Out-String; $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = 'Stop'; Stop-Job $job -ErrorAction SilentlyContinue }
    $foreign = @(Receive-Job $job -ErrorAction SilentlyContinue); Remove-Job $job -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $log -Value $o -Encoding utf8
    $line = ($o -split "`r?`n" | Where-Object { $_ -like 'ISOLATED_GODOT *' } | Select-Object -Last 1)
    $iso = if ($line) { $line.Substring(15) | ConvertFrom-Json } else { $null }
    $r = [ordered]@{ name = $Name; start = $t0.ToString('HH:mm:ss'); end = (Get-Date).ToString('HH:mm:ss'); exit = $code
        isolated = [bool]($iso -and $iso.isolated); real_save_changed_during_run = $(if ($iso) { $iso.real_save_changed_during_run } else { $null })
        state = $(if ($foreign.Count -gt 0) { 'CONTAMINATED' } else { 'CLEAN' }); foreign_seen = $foreign
        stale_import = [bool](Select-String -LiteralPath $log -Pattern 'import is stale' -Quiet) }
    Log "$Name exit=$code isolated=$($r.isolated) state=$($r.state) foreign=$($foreign.Count) stale_import=$($r.stale_import)"
    return $r
}
$runs = @()
foreach ($k in $dirs.Keys) { $runs += Invoke-Iso "import_$k" @('--headless', '--path', $dirs[$k], '--import') 300 }
if (@($runs | Where-Object { $_.exit -ne 0 }).Count -gt 0) { throw 'snapshot import failed' }

Add-Type -AssemblyName System.Windows.Forms
$screens = @([System.Windows.Forms.Screen]::AllScreens)
$secondary = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $secondary) { Log 'BLOCKED_NO_SECONDARY_MONITOR'; exit 1 }
$idx = [array]::IndexOf($screens, $secondary)

# ---- 3. timing matrix ----
$plan = @()
foreach ($w in $Windows) { $plan += @{ b = 'base'; w = $w; z = 1.0 }, @{ b = 'draft'; w = $w; z = 1.0 }, @{ b = 'draft'; w = $w; z = $Zoom } }
$plan += @{ b = 'base'; w = $Windows[0]; z = 1.0; tag = 'drift' }
if ($preSha) { $plan += @{ b = 'pre'; w = $Windows[0]; z = 1.0 } }
$probeRuns = @()
$n = 0
foreach ($p in $plan) {
    $n++
    $zt = if ([math]::Abs($p.z - 1.0) -gt 0.001) { 'zoom' } else { '' }
    $name = "run{0:d2}_{1}{2}_{3}{4}" -f $n, $p.b, $(if ($zt) { '_zoom' } else { '' }), $p.w, $(if ($p.tag) { "_$($p.tag)" } else { '' })
    $j = Join-Path $Out "$name.json"
    $a = @('--screen', "$idx", '--resolution', '1280x720', '--path', $dirs[$p.b], '-s', 'res://tests/performance/perf_drawcall_probe.gd', '--',
        '--autoplay', "--round=$Round", "--dc-warmup=$Warmup", "--dc-phase=$Phase", "--dc-cycles=$Cycles", '--dc-set=units', '--dc-uncapped',
        "--dc-window=$($p.w)", "--perf-contended=0", "--dc-out=$j")
    if ($zt) { $a += "--dc-zoom=$($p.z)" }
    $r = Invoke-Iso $name $a
    $r.build = $p.b; $r.window = $p.w; $r.zoom = $p.z; $r.json = $j; $r.tag = $p.tag
    $runs += $r; $probeRuns += $r
}
# ---- 4. full breakdown (HUD per child) of base at the first window ----
$fb = Join-Path $Out 'breakdown_base.json'
$runs += Invoke-Iso 'breakdown_base' @('--screen', "$idx", '--resolution', '1280x720', '--path', $dirs.base, '-s', 'res://tests/performance/perf_drawcall_probe.gd', '--',
    '--autoplay', "--round=$Round", "--dc-warmup=$Warmup", '--dc-phase=2.5', '--dc-cycles=1', "--dc-window=$($Windows[0])", '--perf-contended=0', "--dc-out=$fb")
# ---- 5. mock UI capture before/after 04's layering ----
$uiDiff = $null
if ($preSha) {
    foreach ($k in @('base', 'pre')) {
        $cd = Join-Path $Out "ui_$k"
        $runs += Invoke-Iso "ui_$k" @('--screen', "$idx", '--resolution', '1280x720', '--path', $dirs[$k], 'res://scenes/ui/ui_preview.tscn', '--', "--capture=$cd", "--tag=$k")
    }
    $py = @'
import json, os, sys
from PIL import Image, ImageChops
a, b, out = sys.argv[1], sys.argv[2], sys.argv[3]
res = []
for fa in sorted(os.listdir(a)):
    if not fa.endswith(".png"): continue
    label = fa.split("_", 1)[1]
    fb = [x for x in os.listdir(b) if x.endswith(label)]
    if not fb: res.append({"screen": label, "missing_in_pre": True}); continue
    ia = Image.open(os.path.join(a, fa)).convert("RGB"); ib = Image.open(os.path.join(b, fb[0])).convert("RGB")
    if ia.size != ib.size: res.append({"screen": label, "size_differs": [ia.size, ib.size]}); continue
    d = ImageChops.difference(ia, ib)
    bbox = d.getbbox()
    px = sum(1 for v in d.convert("L").getdata() if v > 0)
    res.append({"screen": label, "size": ia.size, "diff_px": px, "diff_bbox": bbox})
json.dump(res, open(out, "w"), indent=1)
print(json.dumps(res))
'@
    $pyf = Join-Path $Out 'ui_diff.py'; Set-Content -LiteralPath $pyf -Value $py -Encoding utf8
    $ErrorActionPreference = 'Continue'
    $dl = & python $pyf (Join-Path $Out 'ui_base') (Join-Path $Out 'ui_pre') (Join-Path $Out 'ui_diff.json') 2>&1 | Out-String
    $ErrorActionPreference = 'Stop'
    Log "ui diff: $($dl.Trim())"
    if (Test-Path (Join-Path $Out 'ui_diff.json')) { $uiDiff = Get-Content (Join-Path $Out 'ui_diff.json') -Raw | ConvertFrom-Json }
}

# ---- summary ----
$rows = @()
foreach ($r in $probeRuns) {
    if (-not (Test-Path $r.json)) { continue }
    $p = Get-Content $r.json -Raw | ConvertFrom-Json
    $all = $p.rows | Where-Object { $_.phase -eq 'all' } | Select-Object -First 1
    $ref = $p.rows | Where-Object { $_.phase -eq 'view_only#0' } | Select-Object -First 1
    $nou = $p.rows | Where-Object { $_.phase -eq 'view_only-units' } | Select-Object -First 1
    $rows += [ordered]@{ run = $r.name; build = $r.build; window = $r.window; zoom = $r.zoom; tag = $r.tag; state = $r.state; isolated = $r.isolated
        actual_window = "$($p.config.window.actual_window)"; view = "$($p.config.window.view_size)"; canvas_scale = $p.config.window.canvas_scale; max_fps_end = $p.config.max_fps
        dc_all = $all.draw_calls_median; dc_view = $ref.draw_calls_median
        frame_all_p50 = $all.frame_ms.p50; frame_all_p95 = $all.frame_ms.p95; frame_all_mean = $all.frame_ms.mean
        gpu_all_p50 = $all.render_gpu_ms.p50; gpu_all_p95 = $all.render_gpu_ms.p95; rcpu_all_p50 = $all.render_cpu_ms.p50; rcpu_all_p95 = $all.render_cpu_ms.p95
        gpu_view_p50 = $ref.render_gpu_ms.p50; gpu_view_no_units_p50 = $nou.render_gpu_ms.p50
        gpu_units_ms = [math]::Round([double]$ref.render_gpu_ms.mean - [double]$nou.render_gpu_ms.mean, 4)
        frame_units_ms = [math]::Round([double]$ref.frame_ms.mean - [double]$nou.frame_ms.mean, 3)
        unit_quad_px = $ref.unit_quad_px.p50; unit_bbox_px = $ref.unit_bbox_px.p50; unit_opaque_px = $ref.unit_opaque_px.p50
        on_quad_px = $ref.onscreen_quad_px.p50; on_bbox_px = $ref.onscreen_bbox_px.p50; on_opaque_px = $ref.onscreen_opaque_px.p50; units = $ref.units_median }
}
$contaminated = @($runs | Where-Object { $_.state -ne 'CLEAN' }).Count
$notIso = @($runs | Where-Object { -not $_.isolated -and $_.name -notlike 'import_*' }).Count
$sum = [ordered]@{
    evidence_class = $(if ($contaminated -gt 0) { 'CONTENDED_DESKTOP_PROXY' } else { 'DESKTOP_PROXY' })
    validity = $(if ($contaminated -gt 0) { "CONTENDED ($contaminated of $($runs.Count) runs saw a foreign heavy process)" } else { 'CLEAN (no foreign heavy process seen in any run)' })
    note = 'Desktop debug binary, GL Compatibility, RTX-class desktop GPU. GPU ms are for ratios between variants only; they are not phone values.'
    rev = $sha; pre_rev = $preSha; draft = $Draft; zoom = $Zoom; windows = $Windows; round = $Round; phase_s = $Phase; cycles = $Cycles
    gate = $gate; runs = $runs; rows = $rows; ui_diff = $uiDiff
}
$sum | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Out 'summary.json') -Encoding utf8
$md = @("# Phone-fill matrix ${stamp}: $sha (pre $preSha), draft $Draft, zoom $Zoom ($($sum.evidence_class); $($sum.validity))", $sum.note, '',
    '| run | state | window (actual) | view | dc all/view | frame p50/p95 ms | GPU all p50/p95 ms | render CPU p50/p95 ms | GPU units ms | unit px quad/bbox/opaque | on-screen world px quad/bbox/opaque |',
    '|---|---|---|---|---|---|---|---|---|---|---|')
foreach ($x in $rows) { $md += "| $($x.run) | $($x.state) | $($x.actual_window) | $($x.view) | $($x.dc_all)/$($x.dc_view) | $($x.frame_all_p50)/$($x.frame_all_p95) | $($x.gpu_all_p50)/$($x.gpu_all_p95) | $($x.rcpu_all_p50)/$($x.rcpu_all_p95) | $($x.gpu_units_ms) | $($x.unit_quad_px)/$($x.unit_bbox_px)/$($x.unit_opaque_px) | $($x.on_quad_px)/$($x.on_bbox_px)/$($x.on_opaque_px) |" }
$md += ''; $md += "Gate base: $($gate.base)"; $md += "Gate draft: $($gate.draft)"
$md | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
$md | ForEach-Object { Write-Host $_ }
Log "summary $Out"
if ($notIso -gt 0) { Log "NOT_ISOLATED: $notIso run(s) without isolation proof"; exit 3 }
exit 0
