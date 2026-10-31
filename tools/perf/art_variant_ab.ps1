# 08-performance: performance A/B of an unshipped art variant (e.g. 03's ART_DRAFT32=D1FULL 32 px roster) against the same commit.
# DESKTOP PROXY only (debug binary, GL Compatibility, this PC's GPU). It is never a phone measurement.
# Must run inside the machine-wide lock:
#   & .\coordination\heavy_run.ps1 -Label '08-art-d1-ab' -Script { & .\tools\perf\art_variant_ab.ps1 -Rev HEAD -Draft D1FULL }
# Steps (all serial, one Godot at a time):
#  1. git archive <Rev> into build/perf/artab_<sha>/base and .../draft_<Draft> (+ tools/art, docs/art, tests/performance/*.gd).
#  2. In the DRAFT copy only: ART_DRAFT32=<Draft> python tools/art/build.py (writes that copy's assets/; the shipped assets in the
#     working tree are checked unchanged before/after). The base copy keeps the committed assets.
#  3. asset_budget_check.py --tree <copy> --base <Rev> for both copies (static GPU residency: worst battle, all pages, menu).
#  4. --import in each copy (10's isolated_godot.ps1).
#  5. -Pairs interleaved runs base, draft, base, draft ... of perf_drawcall_probe.gd --dc-set=units --dc-uncapped on the secondary
#     monitor (autoplay <Round> + stress caps; the round seed is the data's deterministic default, so both builds use the same seed).
#     Each run goes through isolated_godot.ps1 while a thread job lists foreign Godot/emulator processes every second; any foreign
#     process marks the run CONTAMINATED and the summary CONTENDED.
# Output: build/perf/artab_<sha>_<Draft>_<stamp>/ (git-ignored): gate_*.json, run_*.json/.log, summary.json, summary.md.
# Exit 0 ran / 1 error / 3 isolation not proven / 4 not inside heavy_run.
param([string]$Rev = 'HEAD', [string]$Draft = 'D1FULL', [int]$Pairs = 2, [string]$Round = 'r08', [double]$Warmup = 35,
      [double]$Phase = 3, [int]$Cycles = 6)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
. (Join-Path $PSScriptRoot 'perf_isolation.ps1')
Assert-HeavyRun 'art_variant_ab.ps1'
$Iso10 = Join-Path $Root 'docs\research\systems\probes\isolated_godot.ps1'
if (-not (Test-Path $Iso10)) { throw "missing 10's isolation wrapper $Iso10" }
$sha = (& git rev-parse --short $Rev).Trim()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "build\perf\artab_${sha}_${Draft}_$stamp"
New-Item -ItemType Directory -Force $Out | Out-Null
$snapRoot = Join-Path $Root "build\perf\artab_$sha"
$dirs = [ordered]@{ base = (Join-Path $snapRoot 'base'); draft = (Join-Path $snapRoot "draft_$Draft") }
$pa = New-PerfAppData $Root 'art_variant_ab'
$isoWork = Join-Path $pa 'iso10'
function Log([string]$m) { $l = "[artab $(Get-Date -Format 'HH:mm:ss')] $m"; Write-Host $l; Add-Content -LiteralPath (Join-Path $Out 'artab.log') -Value $l -Encoding utf8 }

# ---- 1. snapshots ----
foreach ($k in $dirs.Keys) {
    $d = $dirs[$k]
    if (Test-Path $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    New-Item -ItemType Directory -Force $d | Out-Null
    $tar = Join-Path $Out "$k.tar"
    & git archive --format=tar -o $tar $sha project.godot icon.svg src scenes data assets tools/art docs/art
    if ($LASTEXITCODE -ne 0) { throw "git archive failed ($k)" }
    & tar -xf $tar -C $d
    Remove-Item $tar
    New-Item -ItemType Directory -Force (Join-Path $d 'tests\performance'), (Join-Path $d '.godot') | Out-Null
    Copy-Item (Join-Path $Root 'tests\performance\*.gd') (Join-Path $d 'tests\performance\') -Force
    if (Test-Path (Join-Path $Root '.godot\imported')) { Copy-Item (Join-Path $Root '.godot\imported') (Join-Path $d '.godot\') -Recurse }
}
Log "snapshots of $sha ready: $($dirs.Values -join ', ')"

# ---- 2. draft art build (draft copy only) ----
$shippedBefore = (& git status --porcelain -- assets) -join "`n"
$hashBefore = (Get-ChildItem (Join-Path $Root 'assets\atlases') -File | Get-FileHash | ForEach-Object { $_.Hash }) -join ''
$prevDraft = $env:ART_DRAFT32
$env:ART_DRAFT32 = $Draft
$prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
try { $bo = & python (Join-Path $dirs.draft 'tools\art\build.py') 2>&1 | Out-String; $bcode = $LASTEXITCODE } finally { $env:ART_DRAFT32 = $prevDraft; $ErrorActionPreference = $prevEap }
Set-Content -LiteralPath (Join-Path $Out 'draft_build.log') -Value $bo -Encoding utf8
$shippedAfter = (& git status --porcelain -- assets) -join "`n"
$hashAfter = (Get-ChildItem (Join-Path $Root 'assets\atlases') -File | Get-FileHash | ForEach-Object { $_.Hash }) -join ''
$shippedUnchanged = ($shippedBefore -eq $shippedAfter) -and ($hashBefore -eq $hashAfter)
Log "draft build ART_DRAFT32=$Draft exit=$bcode; working-tree assets unchanged=$shippedUnchanged"
if ($bcode -ne 0) { throw "draft art build failed (see draft_build.log)" }
if (-not $shippedUnchanged) { throw 'working-tree assets changed during the draft build: stop' }
$pageDiff = @(Get-ChildItem (Join-Path $dirs.draft 'assets\atlases') -Filter '*.png' | ForEach-Object {
    $b = Join-Path $dirs.base "assets\atlases\$($_.Name)"
    [ordered]@{ page = $_.BaseName; changed = (-not (Test-Path $b)) -or ((Get-FileHash $b).Hash -ne (Get-FileHash $_.FullName).Hash) } })
Log "pages changed by the draft: $((@($pageDiff | Where-Object { $_.changed } | ForEach-Object { $_.page })) -join ', ')"

# ---- 3. static gate ----
$gate = [ordered]@{}
foreach ($k in $dirs.Keys) {
    $go = Join-Path $Out "gate_$k"
    $ErrorActionPreference = 'Continue'
    $gl = & python (Join-Path $Root 'tools\perf\asset_budget_check.py') --tree $dirs[$k] --base $sha --out $go 2>&1 | Out-String
    $gcode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Set-Content -LiteralPath (Join-Path $Out "gate_$k.log") -Value $gl -Encoding utf8
    $line = ($gl -split "`r?`n" | Where-Object { $_ -like 'ASSET_CHECK target=*' } | Select-Object -Last 1)
    $gate[$k] = [ordered]@{ exit = $gcode; line = $line }
    Log "gate $k exit=$gcode $line"
}

# ---- 4/5. isolated Godot runs ----
function Invoke-Iso([string]$Name, [string[]]$GArgs, [int]$TimeoutSec = 900) {
    $log = Join-Path $Out "$Name.log"
    Get-ChildItem -Path $isoWork -Recurse -Filter 'save.json*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $parent = $PID
    # foreign-process monitor: Godot/emulator processes that are not descendants of this pwsh
    $job = Start-ThreadJob -ArgumentList $parent -ScriptBlock {
        param($parent)
        $seen = @{}
        while ($true) {
            $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
            $own = New-Object System.Collections.Generic.HashSet[int]; [void]$own.Add([int]$parent)
            $grew = $true
            while ($grew) { $grew = $false; foreach ($p in $all) { if ($own.Contains([int]$p.ParentProcessId) -and $own.Add([int]$p.ProcessId)) { $grew = $true } } }
            foreach ($p in $all) {
                if (($p.Name -like 'Godot*' -or $p.Name -like 'qemu-system*' -or $p.Name -like 'emulator*') -and -not $own.Contains([int]$p.ProcessId) -and -not $seen.ContainsKey([int]$p.ProcessId)) {
                    $seen[[int]$p.ProcessId] = "$($p.ProcessId) $(if ($p.CommandLine) { $p.CommandLine.Substring(0, [math]::Min(140, $p.CommandLine.Length)) })"
                    Write-Output $seen[[int]$p.ProcessId]
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
        state = $(if ($foreign.Count -gt 0) { 'CONTAMINATED' } else { 'CLEAN' }); foreign_seen = $foreign }
    Log "$Name exit=$code isolated=$($r.isolated) state=$($r.state) foreign=$($foreign.Count)"
    return $r
}
$runs = @()
foreach ($k in $dirs.Keys) { $runs += Invoke-Iso "import_$k" @('--headless', '--path', $dirs[$k], '--import') }
if (@($runs | Where-Object { $_.exit -ne 0 }).Count -gt 0) { throw 'snapshot import failed' }

Add-Type -AssemblyName System.Windows.Forms
$screens = @([System.Windows.Forms.Screen]::AllScreens)
$secondary = $screens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $secondary) { Log 'BLOCKED_NO_SECONDARY_MONITOR: visible probes not run (user rule)'; exit 1 }
$idx = [array]::IndexOf($screens, $secondary)
$probe = @()
for ($i = 1; $i -le $Pairs; $i++) {
    foreach ($k in $dirs.Keys) {
        $j = Join-Path $Out "run_${k}_$i.json"
        $n0 = @(Get-Process | Where-Object { $_.ProcessName -like 'Godot*' }).Count
        $r = Invoke-Iso "run_${k}_$i" @('--screen', "$idx", '--resolution', '1280x720', '--path', $dirs[$k], '-s', 'res://tests/performance/perf_drawcall_probe.gd', '--',
            '--autoplay', "--round=$Round", "--dc-warmup=$Warmup", "--dc-phase=$Phase", "--dc-cycles=$Cycles", '--dc-set=units', '--dc-uncapped',
            "--perf-contended=$n0", "--dc-out=$j")
        $r.build = $k; $r.pair = $i; $r.json = $j
        $runs += $r; $probe += $r
        $stale = Select-String -Path (Join-Path $Out "run_${k}_$i.log") -Pattern 'import is stale' -Quiet
        if ($stale) { Log "WARNING run_${k}_${i}: UiStyle reported a stale import" }
    }
}

# ---- summary ----
function Med($a) { $s = @($a | Where-Object { $_ -ne $null } | Sort-Object); if ($s.Count -eq 0) { return $null }; return $s[[int][math]::Floor($s.Count / 2)] }
$rows = @()
foreach ($r in $probe) {
    if (-not (Test-Path $r.json)) { continue }
    $p = Get-Content $r.json -Raw | ConvertFrom-Json
    $get = { param($ph) $p.rows | Where-Object { $_.phase -eq $ph } | Select-Object -First 1 }
    $all = & $get 'all'; $ref = & $get 'view_only#0'; $nou = & $get 'view_only-units'
    $rows += [ordered]@{ build = $r.build; pair = $r.pair; state = $r.state; isolated = $r.isolated
        dc_all = $all.draw_calls_median; dc_view = $ref.draw_calls_median; dc_view_no_units = $nou.draw_calls_median
        frame_all_p50 = $all.frame_ms.p50; frame_all_mean = $all.frame_ms.mean; frame_all_p95 = $all.frame_ms.p95
        frame_view_p50 = $ref.frame_ms.p50; frame_view_no_units_p50 = $nou.frame_ms.p50
        frame_units_ms = [math]::Round($ref.frame_ms.mean - $nou.frame_ms.mean, 3)
        view_draw_us_p50 = $ref.view_draw_us.p50; unit_draw_us_p50 = $ref.unit_draw_us.p50
        gpu_view_p50 = $ref.render_gpu_ms.p50; gpu_view_no_units_p50 = $nou.render_gpu_ms.p50; unit_quad_px_p50 = $ref.unit_quad_px.p50
        max_fps_end = $p.config.max_fps; uncap_resets = $p.config.uncap_resets; units = $ref.units_median; frames = $ref.frames }
}
$agg = [ordered]@{}
foreach ($k in $dirs.Keys) {
    $g = @($rows | Where-Object { $_.build -eq $k })
    $a = [ordered]@{}
    foreach ($f in 'dc_all', 'dc_view', 'dc_view_no_units', 'frame_all_p50', 'frame_all_mean', 'frame_all_p95', 'frame_units_ms', 'view_draw_us_p50', 'unit_draw_us_p50', 'gpu_view_p50', 'gpu_view_no_units_p50', 'unit_quad_px_p50', 'max_fps_end', 'units') {
        $a[$f] = Med ($g | ForEach-Object { $_[$f] })
    }
    $agg[$k] = $a
}
$contaminated = @($runs | Where-Object { $_.state -ne 'CLEAN' }).Count
$notIso = @($runs | Where-Object { -not $_.isolated -and $_.name -notlike 'import_*' }).Count
$sum = [ordered]@{
    evidence_class = $(if ($contaminated -gt 0) { 'CONTENDED_DESKTOP_PROXY' } else { 'DESKTOP_PROXY' })
    validity = $(if ($contaminated -gt 0) { "CONTENDED ($contaminated of $($runs.Count) runs saw a foreign Godot/emulator process)" } else { 'CLEAN (no foreign Godot/emulator process seen in any run)' })
    note = 'Desktop debug binary, GL Compatibility, this PC. Not a phone measurement; phone GPU/CPU costs are unmeasured.'
    rev = $sha; draft = $Draft; round = $Round; pairs = $Pairs; phase_s = $Phase; cycles = $Cycles
    working_tree_assets_unchanged = $shippedUnchanged; draft_pages = $pageDiff; gate = $gate; runs = $runs; rows = $rows; median_by_build = $agg
}
$sum | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Out 'summary.json') -Encoding utf8
$md = @("# Art variant A/B ${stamp}: $sha base vs ART_DRAFT32=$Draft ($($sum.evidence_class), $($sum.validity))", $sum.note, '',
    '| metric (median over pairs) | base | draft | draft - base |', '|---|---|---|---|')
foreach ($f in $agg.base.Keys) { $b = $agg.base[$f]; $d = $agg.draft[$f]; $md += "| $f | $b | $d | $(if ($b -ne $null -and $d -ne $null) { [math]::Round([double]$d - [double]$b, 3) }) |" }
$md += ''; $md += "Gate base: $($gate.base.line)"; $md += "Gate draft: $($gate.draft.line)"
$md | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
$md | ForEach-Object { Write-Host $_ }
Log "summary $Out"
if ($notIso -gt 0) { Log "NOT_ISOLATED: $notIso probe run(s) without isolation proof"; exit 3 }
exit 0
