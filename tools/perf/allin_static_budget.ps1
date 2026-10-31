# 08-performance: STATIC texture / APK budget when every pending art change lands together. No Godot, no emulator:
# git archive + the art build in Python + file reads only, so it needs no heavy-run lock.
# Scenarios (all from commit -Rev, never touching the working tree's shipped assets):
#   head   : the commit as is (03 one-page char_player, 06 HUD frames 02ec60f/adc0965 are already in it)
#   world  : head + 09-art-world's pages bases / biome_meadow / fx_combat (.png + .json) copied from the WORKING TREE (09 WIP)
#   d1     : head + ART_DRAFT32=<Draft> art build in the copy (03 A19 32 px roster)
#   allin  : d1 build, then 09's three pages copied over
# Each copy is checked with tools/perf/asset_budget_check.py --tree (caps from RETHEME_BUDGET: worst battle <= 12 MiB, all pages
# <= 14 MiB, menu <= 0.5 MiB, page side <= 1024). The VRAM table adds what-if import modes from the page sizes:
# mipmaps on (x 4/3), VRAM compression ETC2 / ASTC 4x4 (8 bits per pixel = x 1/4), and both. The project imports pixel art
# lossless with mipmaps off (ENGINE.md §8), so those rows are only what-ifs.
# APK delta: atlas PNG + JSON bytes. Godot exports the imported .ctex (lossless re-encode of the same pixels) instead of the PNG,
# so the PNG delta is an approximation; -CtexDir can point at an already-imported copy to report the real .ctex bytes.
# Usage: .\tools\perf\allin_static_budget.ps1 [-Rev HEAD] [-Draft D1FULL]
# Output: build/perf/allin_<sha>/ (git-ignored): gate_<scenario>/, pages_<scenario>.json, summary.json, summary.md. Owner: 08-performance.
param([string]$Rev = 'HEAD', [string]$Draft = 'D1FULL', [string[]]$WorldPages = @('bases', 'biome_meadow', 'fx_combat'))
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
$sha = (& git rev-parse --short $Rev).Trim()
$Out = Join-Path $Root "build\perf\allin_$sha"
New-Item -ItemType Directory -Force $Out | Out-Null
$snapRoot = Join-Path $env:TEMP "perf08_allin_$sha"
$sc = [ordered]@{ head = 'head'; world = 'world'; d1 = 'd1'; allin = 'allin' }
function Log([string]$m) { $l = "[allin $(Get-Date -Format 'HH:mm:ss')] $m"; Write-Host $l; Add-Content -LiteralPath (Join-Path $Out 'allin.log') -Value $l -Encoding utf8 }
$hashBefore = (Get-ChildItem (Join-Path $Root 'assets\atlases') -File | Get-FileHash | ForEach-Object { $_.Hash }) -join ''
# 09 WIP pages must exist in the working tree and differ from the commit, else the 'world' scenario equals 'head'
$wip = @()
foreach ($p in $WorldPages) {
    foreach ($ext in 'png', 'json') {
        $wt = Join-Path $Root "assets\atlases\$p.$ext"
        $same = $false
        $blob = (& git rev-parse "${sha}:assets/atlases/$p.$ext" 2>$null)
        if ($blob) { $same = ((& git hash-object $wt).Trim() -eq $blob.Trim()) }
        $wip += [ordered]@{ file = "assets/atlases/$p.$ext"; differs_from_commit = -not $same }
    }
}
Log "09 world pages in the working tree differ from ${sha}: $((@($wip | Where-Object { $_.differs_from_commit } | ForEach-Object { $_.file })) -join ', ')"
foreach ($k in $sc.Keys) {
    $d = Join-Path $snapRoot $k
    if (Test-Path $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    New-Item -ItemType Directory -Force $d | Out-Null
    $tar = Join-Path $snapRoot "$k.tar"
    & git archive --format=tar -o $tar $sha project.godot src scenes data assets tools/art docs/art
    if ($LASTEXITCODE -ne 0) { throw "git archive failed ($k)" }
    & tar -xf $tar -C $d
    Remove-Item $tar
}
foreach ($k in @('d1', 'allin')) {
    $prev = $env:ART_DRAFT32; $env:ART_DRAFT32 = $Draft
    $ErrorActionPreference = 'Continue'
    try { $bo = & python (Join-Path $snapRoot "$k\tools\art\build.py") 2>&1 | Out-String; $bc = $LASTEXITCODE } finally { $env:ART_DRAFT32 = $prev; $ErrorActionPreference = 'Stop' }
    Set-Content -LiteralPath (Join-Path $Out "build_$k.log") -Value $bo -Encoding utf8
    Log "art build $k ART_DRAFT32=$Draft exit=$bc"
    if ($bc -ne 0) { throw "art build failed ($k)" }
}
foreach ($k in @('world', 'allin')) {
    foreach ($p in $WorldPages) { foreach ($ext in 'png', 'json') { Copy-Item (Join-Path $Root "assets\atlases\$p.$ext") (Join-Path $snapRoot "$k\assets\atlases\$p.$ext") -Force } }
}
$unchanged = $hashBefore -eq ((Get-ChildItem (Join-Path $Root 'assets\atlases') -File | Get-FileHash | ForEach-Object { $_.Hash }) -join '')
Log "working-tree atlases unchanged=$unchanged"
if (-not $unchanged) { throw 'working-tree atlases changed: stop' }

$py = @'
import json, os, struct, sys
tree = sys.argv[1]
d = os.path.join(tree, "assets", "atlases")
pages = []
for f in sorted(os.listdir(d)):
    if not f.endswith(".json"):
        continue
    meta = json.load(open(os.path.join(d, f), encoding="utf-8"))
    png = os.path.join(d, meta.get("image", f[:-5] + ".png"))
    if not os.path.isfile(png):
        continue
    with open(png, "rb") as fh:
        head = fh.read(24)
    w, h = struct.unpack(">II", head[16:24])
    pages.append({"id": meta.get("atlas", f[:-5]), "w": w, "h": h, "rgba8": w * h * 4, "png": os.path.getsize(png),
                  "json": len(open(os.path.join(d, f), "rb").read().replace(b"\r", b"")),   # LF bytes: git archive may add CR (core.autocrlf) "group": meta.get("group", ""), "load_policy": meta.get("load_policy", ""),
                  "occupancy": meta.get("occupancy"), "padding": meta.get("padding"), "extrude": meta.get("extrude"),
                  "mipmaps": meta.get("mipmaps"), "gpu_format": meta.get("gpu_format", "")})
json.dump(pages, sys.stdout)
'@
$pyf = Join-Path $Out 'pages.py'; Set-Content -LiteralPath $pyf -Value $py -Encoding utf8
$res = [ordered]@{}
foreach ($k in $sc.Keys) {
    $tree = Join-Path $snapRoot $k
    $ErrorActionPreference = 'Continue'
    $gl = & python (Join-Path $Root 'tools\perf\asset_budget_check.py') --tree $tree --base $sha --out (Join-Path $Out "gate_$k") 2>&1 | Out-String
    $gc = $LASTEXITCODE
    $pj = & python $pyf $tree 2>&1 | Out-String
    $ErrorActionPreference = 'Stop'
    $line = ($gl -split "`r?`n" | Where-Object { $_ -like 'ASSET_CHECK target=*' } | Select-Object -Last 1)
    $rep = Get-ChildItem -LiteralPath (Join-Path $Out "gate_$k") -Recurse -Filter 'report.json' | Select-Object -First 1
    $rj = Get-Content -LiteralPath $rep.FullName -Raw | ConvertFrom-Json
    $row = @{}; foreach ($x in $rj.rows) { $row[$x.metric] = $x }
    $pages = $pj | ConvertFrom-Json
    Set-Content -LiteralPath (Join-Path $Out "pages_$k.json") -Value $pj -Encoding utf8
    $res[$k] = [ordered]@{ gate_exit = $gc; gate_line = $line; verdict = $rj.verdict
        worst_battle = [double]$row['atlas_worst_battle_gpu'].target; all_pages = [double]$row['atlas_all_pages_gpu'].target; menu = [double]$row['atlas_menu_gpu'].target
        max_side = $row['atlas_page_max_side_px'].target; png_total = [long](($pages | Measure-Object png -Sum).Sum); json_total = [long](($pages | Measure-Object json -Sum).Sum)
        pages = @($pages | ForEach-Object { "$($_.id) $($_.w)x$($_.h)" }); caps = $rj.caps }
    Log "gate $k exit=$gc $line"
}
$MiB = 1048576.0
$modes = [ordered]@{ 'lossless RGBA8, no mipmaps (project setting)' = 1.0; 'lossless + mipmaps (what-if)' = 4.0 / 3.0; 'VRAM compressed ETC2/ASTC 4x4, 8 bpp (what-if)' = 0.25; 'VRAM compressed + mipmaps (what-if)' = 1.0 / 3.0 }
$caps = $res.head.caps
$md = @("# All-in static texture / APK budget at $sha (STATIC; atlas pages only)", '',
    "Scenarios: head = commit as is; world = + 09-art-world WIP pages (bases, biome_meadow, fx_combat) from the working tree; d1 = + 03 ART_DRAFT32=$Draft; allin = both.", '',
    '| scenario | gate | pages (size) | worst battle MiB | all pages MiB | menu MiB | atlas PNG KiB | atlas JSON KiB (LF) | APK delta vs head (PNG+JSON) KiB |', '|---|---|---|---|---|---|---|---|---|')
foreach ($k in $res.Keys) {
    $x = $res[$k]
    $md += "| $k | $($x.verdict) | $($x.pages -join ', ') | $([math]::Round($x.worst_battle / $MiB, 2)) | $([math]::Round($x.all_pages / $MiB, 2)) | $([math]::Round($x.menu / $MiB, 3)) | $([math]::Round($x.png_total / 1024, 1)) | $([math]::Round($x.json_total / 1024, 1)) | $([math]::Round((($x.png_total + $x.json_total) - ($res.head.png_total + $res.head.json_total)) / 1024, 1)) |"
}
$md += ''; $md += "Caps: worst battle $([math]::Round($caps.atlas_worst_battle_gpu / $MiB, 2)) MiB, all pages $([math]::Round($caps.atlas_all_pages_gpu / $MiB, 2)) MiB, menu $([math]::Round($caps.atlas_menu_gpu / $MiB, 3)) MiB, page side $($caps.atlas_page_max_side_px) px."
$md += ''; $md += '| import mode | head worst / all / menu MiB | allin worst / all / menu MiB | allin over a cap? |'; $md += '|---|---|---|---|'
$whatif = @()
foreach ($m in $modes.Keys) {
    $f = $modes[$m]; $hh = $res.head; $aa = $res.allin
    $over = @()
    if ($aa.worst_battle * $f -gt $caps.atlas_worst_battle_gpu) { $over += 'worst battle' }
    if ($aa.all_pages * $f -gt $caps.atlas_all_pages_gpu) { $over += 'all pages' }
    if ($aa.menu * $f -gt $caps.atlas_menu_gpu) { $over += 'menu' }
    $md += "| $m | $([math]::Round($hh.worst_battle * $f / $MiB, 2)) / $([math]::Round($hh.all_pages * $f / $MiB, 2)) / $([math]::Round($hh.menu * $f / $MiB, 3)) | $([math]::Round($aa.worst_battle * $f / $MiB, 2)) / $([math]::Round($aa.all_pages * $f / $MiB, 2)) / $([math]::Round($aa.menu * $f / $MiB, 3)) | $(if ($over) { 'OVER: ' + ($over -join ', ') } else { 'no' }) |"
    $whatif += [ordered]@{ mode = $m; factor = $f; allin_over = $over }
}
$sum = [ordered]@{ evidence_class = 'STATIC'; rev = $sha; draft = $Draft; world_wip_files = $wip; scenarios = $res; what_if = $whatif; working_tree_atlases_unchanged = $unchanged }
$sum | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Out 'summary.json') -Encoding utf8
$md | Set-Content (Join-Path $Out 'summary.md') -Encoding utf8
$md | ForEach-Object { Write-Host $_ }
Log "summary $Out"
exit 0
