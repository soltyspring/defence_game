# 07-qa: capture 07's fixed graphics set at ONE commit and compare it with the baseline (docs/verification/ART_BASELINE.md).
# Owner: 07-qa. Anyone may run it (03, 06, 09, coordinator); the table is the same for everyone.
#   Step 1 (heavy, detached; returns at once):   .\tools\qa\art_compare.ps1 -Sha <commit> [-Tags ko_1x,en_1x,ko_2x,en_2x]
#           prints HEAVY_JOB_STARTED ... out=<log>; poll the log for '^HEAVY_JOB_DONE' in short calls.
#   Step 2 (light, after HEAVY_JOB_DONE):        .\tools\qa\art_compare.ps1 -Sha <commit> -Report [-Tags ...]
#           writes <out>\table.md and <out>\compare.json (rules, PASS/FAIL, BETTER/SAME/WORSE vs baseline, G1-G3 VOID).
# The job (inside coordination/heavy_run_detached.ps1 -> heavy_run.ps1 lock):
#   git archive <commit> -> %TEMP%\qa07_art_<short>; overlay 07's tests/acceptance/capture_art_baseline.gd(.uid) from this
#   checkout; Godot --import with a private APPDATA (import guard: every .import target must exist, else retry, else stop);
#   tests/acceptance/capture_art_baseline.gd through tools/build/visible_launch.ps1 (secondary monitor, isolated APPDATA)
#   for each tag, 393 dp condition; ko_1x also with --anim unless -NoAnim (UI-only commits).
# Default out: build\qa07\art_compare\<short>. Default baseline: docs\verification\evidence\art-baseline-ad47eda.
param([Parameter(Mandatory)][string]$Sha, [string[]]$Tags = @('ko_1x'), [switch]$Report, [string]$Out = '', [switch]$NoAnim,
      [string]$Baseline = '', [string]$BaseSha = '')   # -BaseSha: compare with another captured commit (e.g. the art commit's parent after a gameplay change)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
if ($Tags.Count -eq 1 -and $Tags[0] -match ',') { $Tags = $Tags[0].Split(',') }
$full = (& git rev-parse --verify "$Sha^{commit}" 2>$null)
if (-not $full) { Write-Host "unknown commit: $Sha"; exit 2 }
$short = $full.Substring(0, 7)
if (-not $Out) { $Out = Join-Path $Root "build\qa07\art_compare\$short" }
$Out = [IO.Path]::GetFullPath([IO.Path]::Combine($Root, $Out))   # absolute: Godot resolves a relative --out against its own folder (07 bug 07:14)
if (-not $Baseline) { $Baseline = Join-Path $Root 'docs\verification\evidence\art-baseline-ad47eda' }
$cap = Join-Path $Out 'cap'
if ($Report) {
    $py = 'python'
    & $py (Join-Path $Root 'tools\qa\art_metrics.py') --dir $cap --tags ($Tags -join ',') --out (Join-Path $Out 'art_metrics.json') --sheets (Join-Path $Out 'anim_sheets') | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host 'art_metrics.py failed'; exit 1 }
    $baseMetrics = Join-Path $Baseline 'art_metrics.json'; $baseDir = $Baseline
    if ($BaseSha) {
        $bs = (& git rev-parse --short=7 "$BaseSha^{commit}" 2>$null)
        $bo = Join-Path $Root "build\qa07\art_compare\$bs"
        if (-not (Test-Path (Join-Path $bo 'art_metrics.json'))) { Write-Host "no report for base $bs; run -Sha $bs then -Report first"; exit 2 }
        $baseMetrics = Join-Path $bo 'art_metrics.json'; $baseDir = Join-Path $bo 'cap'
    }
    & $py (Join-Path $Root 'tools\qa\art_compare.py') --new (Join-Path $Out 'art_metrics.json') --base $baseMetrics `
        --sha $short --out-md (Join-Path $Out 'table.md') --out-json (Join-Path $Out 'compare.json') --new-dir $cap --base-dir $baseDir --base-label $(if ($BaseSha) { $BaseSha } else { 'baseline ad47eda' })
    exit $LASTEXITCODE
}
New-Item -ItemType Directory -Force $cap | Out-Null
# one job per SHA: refuse if a job with the same label is still queued or running (any role may call this script)
foreach ($lg in Get-ChildItem (Join-Path $Root 'build\heavy') -Filter "07-art-compare-$short-*.log" -ErrorAction SilentlyContinue) {
    $txt = Get-Content $lg.FullName -Raw
    if ($txt -match 'HEAVY_JOB_DONE') { continue }
    if ($txt -match 'HEAVY_JOB_QUEUED \S+ label=\S+ pid=(\d+)' -and (Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue)) {
        Write-Host "ALREADY QUEUED: $($lg.Name) (pid $($Matches[1]) alive). Not queuing a second job for $short; poll that log."; exit 0
    }
}
$job = Join-Path $Out 'job.ps1'
$tagList = ($Tags | ForEach-Object { "'$_'" }) -join ','
@"
`$ErrorActionPreference = 'Continue'
Set-Location '$Root'
`$Godot = '$Root\tools\engine\Godot_v4.7.2-stable_win64_console.exe'
`$snap = Join-Path `$env:TEMP 'qa07_art_$short'
`$cap = '$cap'
"art_compare job sha=$full out=$Out"
if (Test-Path `$snap) { Remove-Item -Recurse -Force `$snap }
New-Item -ItemType Directory -Force `$snap | Out-Null
& git archive --format=zip -o "`$snap.zip" $full
Expand-Archive "`$snap.zip" `$snap -Force; Remove-Item "`$snap.zip"
Copy-Item '$Root\tests\acceptance\capture_art_baseline.gd' (Join-Path `$snap 'tests\acceptance') -Force
if (Test-Path '$Root\tests\acceptance\capture_art_baseline.gd.uid') { Copy-Item '$Root\tests\acceptance\capture_art_baseline.gd.uid' (Join-Path `$snap 'tests\acceptance') -Force }
"capture script sha256=" + (Get-FileHash '$Root\tests\acceptance\capture_art_baseline.gd' -Algorithm SHA256).Hash.ToLower()
# harness identity independent of the checkout's line ends (G2): BOM dropped, CRLF -> LF, sha256; plus git's blob id
`$hs = '$Root\tests\acceptance\capture_art_baseline.gd'
`$ht = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes(`$hs)).TrimStart([char]0xFEFF).Replace("``r``n", "``n")
`$hc = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes(`$ht)))).Replace('-', '').ToLower()
`$hg = (& git hash-object `$hs).Trim()
New-Item -ItemType Directory -Force `$cap | Out-Null
@{ capture_script = 'tests/acceptance/capture_art_baseline.gd'; canonical_sha256 = `$hc; git_blob = `$hg; commit_under_test = '$full' } | ConvertTo-Json | Set-Content (Join-Path `$cap 'harness.json') -Encoding utf8
"harness canonical_sha256=`$hc git_blob=`$hg"
`$prevApp = `$env:APPDATA
`$env:APPDATA = '$Out\import_appdata'
New-Item -ItemType Directory -Force `$env:APPDATA | Out-Null
& `$Godot --headless --path `$snap --import 2>&1 | Out-Null
`$missing = @()
for (`$pass = 1; `$pass -le 3; `$pass++) {
    `$missing = @()
    foreach (`$imp in Get-ChildItem `$snap -Recurse -Filter '*.import' -File | Where-Object { `$_.FullName -notmatch '\\\.godot\\' }) {
        foreach (`$m in Select-String -Path `$imp.FullName -Pattern '^path(\.[a-z0-9_]+)?="res://(\.godot/imported/[^"]+)"') {
            if (-not (Test-Path (Join-Path `$snap `$m.Matches[0].Groups[2].Value))) { `$missing += `$m.Matches[0].Groups[2].Value }
        }
    }
    if (`$missing.Count -eq 0) { break }
    "import incomplete (pass `$pass): `$(`$missing.Count) missing; re-importing"
    & `$Godot --headless --path `$snap --import 2>&1 | Out-Null
}
`$env:APPDATA = `$prevApp
"import_missing_after_guard=`$(`$missing.Count)"
if (`$missing.Count -gt 0) { 'SNAPSHOT IMPORT INCOMPLETE: no capture'; exit 3 }
`$dry = & '$Root\docs\research\systems\probes\isolated_godot.ps1' -TimeoutSec 300 -GodotArgs @('--headless', '--path', `$snap, '-s', 'res://tests/acceptance/capture_art_baseline.gd', '--', "--out=`$(`$cap.Replace('\','/'))/dry", '--tag=dry', '--dry', '--anim', '--locale=ko', '--safe=34,0,34,0', '--target=44')
`$dry | Where-Object { `$_ -match '^\[art\]|SCRIPT ERROR|Parse Error|ISOLATED_GODOT' } | ForEach-Object { "dry: `$_" }
if (-not (`$dry | Where-Object { `$_ -match '^\[art\] ' })) { 'DRY RUN FAILED: no [art] line; no visible capture'; exit 4 }
foreach (`$t in @($tagList)) {
    `$res = if (`$t -like '*_2x') { '1600x720' } else { '800x360' }
    `$loc = `$t.Split('_')[0]
    `$ua = @("--out=`$(`$cap.Replace('\','/'))", "--tag=`$t", "--locale=`$loc", '--safe=34,0,34,0', '--target=44')
    if (`$t -eq 'ko_1x' -and '$([bool]$NoAnim)' -ne 'True') { `$ua += '--anim' }   # -NoAnim: UI-only commits skip the pose pass (fewer GPU frames)
    & '$Root\tools\build\visible_launch.ps1' -ProjectPath `$snap -Script res://tests/acceptance/capture_art_baseline.gd -Resolution `$res -TimeoutSec 420 -EvidenceDir `$cap -UserArgs `$ua
    "visible `$t exit=`$LASTEXITCODE"
}
"art_compare capture done; next: .\tools\qa\art_compare.ps1 -Sha $short -Report -Tags $($Tags -join ',')"
"@ | Set-Content -Path $job -Encoding utf8
& (Join-Path $Root 'coordination\heavy_run_detached.ps1') -Label "07-art-compare-$short" -ScriptFile $job
Write-Host "after HEAVY_JOB_DONE: .\tools\qa\art_compare.ps1 -Sha $short -Report -Tags $($Tags -join ',')"
