# Heavy job (10-research-systems, v0.35): round re-lock suite for ANY commit. Run ONLY via
#   & .\coordination\heavy_run_detached.ps1 -Label '10-relock-suite' -ScriptFile docs/research/systems/probes/relock_suite_job.ps1
# Target commit: the first non-comment line of docs/research/systems/probes/relock_target.txt (edit ONLY that line for
# 02's fix commit), or $env:P10_RELOCK_SHA. Cases: relock_cases.json (seeds, steps, expectations). Judge afterwards:
#   python docs/research/systems/probes/relock_eval.py <out dir printed as "P10 OUT">
# Headless only: one --headless import of a clean LF `git archive` snapshot; every step is a data-only copy
# (probes/relock_variants.py); every boot through probes/isolated_godot.ps1 (private APPDATA). Prefix p10.
$ErrorActionPreference = 'Continue'
$p10Root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
Set-Location -LiteralPath $p10Root
$p10Probes = Join-Path $p10Root 'docs\research\systems\probes'
$p10Sha = $env:P10_RELOCK_SHA
if (-not $p10Sha) { $p10Sha = (Get-Content -LiteralPath (Join-Path $p10Probes 'relock_target.txt') | Where-Object { $_ -and $_ -notmatch '^\s*#' } | Select-Object -First 1).Trim() }
$p10Sha = (git rev-parse --verify "$p10Sha^{commit}").Trim()
if (-not $p10Sha) { 'P10 ERROR target commit not found'; $global:LASTEXITCODE = 0; return }
$p10S7 = $p10Sha.Substring(0, 7)
$p10Li = Join-Path $p10Root 'docs\research\systems\.local_inspect'
$p10W = Join-Path $p10Li "rs_$p10S7"
$p10Out = Join-Path $p10Li "rs_out_$p10S7"
$p10Ev = Join-Path $p10Root 'docs\research\systems\evidence\relock_suite'
$p10Wrap = Join-Path $p10Probes 'isolated_godot.ps1'
$p10Var = Join-Path $p10Probes 'relock_variants.py'
$p10Cases = (Get-Content -LiteralPath (Join-Path $p10Probes 'relock_cases.json') -Raw -Encoding UTF8 | ConvertFrom-Json).cases
Remove-Item -Recurse -Force $p10W, $p10Out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $p10W, $p10Out, $p10Ev | Out-Null
"P10 TARGET $p10Sha"
"P10 OUT $p10Out"
$p10Base = Join-Path $p10W 'base'
New-Item -ItemType Directory $p10Base | Out-Null
git -c core.autocrlf=false -c core.eol=lf archive --format=zip -o "$p10Base.zip" $p10Sha
Expand-Archive "$p10Base.zip" -DestinationPath $p10Base; Remove-Item "$p10Base.zip"
New-Item -ItemType Directory -Force "$p10Base\docs\research\systems\probes" | Out-Null
Copy-Item (Join-Path $p10Probes 'probe_relock.gd'), (Join-Path $p10Probes 'probe_relock.gd.uid') "$p10Base\docs\research\systems\probes\" -Force
"P10 save.gd sha16=" + (Get-FileHash -LiteralPath "$p10Base\src\core\save.gd").Hash.Substring(0, 16)
$r = & $p10Wrap -GodotArgs @('--headless', '--path', $p10Base, '--import', '--quit-after', '300') -WorkDir (Join-Path $p10W 'iso_import') -Keep -TimeoutSec 300
$r | Where-Object { $_ -like 'ISOLATED_GODOT*' }
function P10Ud($iso) { Join-Path $iso 'appdata\Godot\app_userdata\Lane Defence\save.json' }
function P10H($f) { if (Test-Path -LiteralPath $f) { (Get-FileHash -LiteralPath $f).Hash.Substring(0, 12).ToLower() } else { 'none' } }
function P10Boot($label, $proj, $mode, $iso, $seed, $fresh) {
  $a = @('--headless', '--path', $proj, '-s', 'res://docs/research/systems/probes/probe_relock.gd', '--quit-after', '600', '--', "--mode=$mode")
  if ($fresh) { Remove-Item -Recurse -Force $iso -ErrorAction SilentlyContinue }
  $ud = P10Ud $iso
  if ($seed) { $before = $seed } else { $before = $ud }
  if (Test-Path -LiteralPath $before) { Copy-Item -LiteralPath $before (Join-Path $p10Out "$label.before.json") -Force }
  $pre = P10H $before
  if ($seed) { $rr = & $p10Wrap -GodotArgs $a -WorkDir $iso -Keep -TimeoutSec 120 -SeedSave $seed } else { $rr = & $p10Wrap -GodotArgs $a -WorkDir $iso -Keep -TimeoutSec 120 }
  if (Test-Path -LiteralPath $ud) { Copy-Item -LiteralPath $ud (Join-Path $p10Out "$label.after.json") -Force }
  $pb = @(Get-ChildItem -LiteralPath (Split-Path $ud) -Filter 'save.pre-*.json' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ','
  "RUN $label sha_before=$pre sha_after=$(P10H $ud) pre_backups=[$pb] " + (($rr | Where-Object { $_ -like 'PROBE10_RELOCK *' }) -replace '^PROBE10_RELOCK ', '')
  $iz = "$($rr | Where-Object { $_ -like 'ISOLATED_GODOT*' })"
  if ($iz -notmatch '"isolated":true' -or $iz -notmatch '"real_save_changed_during_run":false') { "P10 ISOLATION_PROBLEM $label $iz" } else { "P10 iso_ok $label" }
  $rr | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|refund_unknown|\[Content\]' } | ForEach-Object { "P10 LOG $label | $_" }
}
$p10Copies = @{}
function P10Variant([string[]]$vs) {
  $key = if ($vs.Count) { $vs -join '+' } else { 'none' }
  if ($p10Copies.ContainsKey($key)) { return $p10Copies[$key] }
  $d = Join-Path $p10W ('v' + $p10Copies.Count)
  Copy-Item -Recurse $p10Base $d
  if ($vs.Count) { python $p10Var $d @vs | ForEach-Object { "P10 MUT $key | $_" } | Out-Host }
  $p10Copies[$key] = $d
  return $d
}
# ---- seeds made with the TARGET commit's own Save (record_result / buy_upgrade / save_progress)
$p10Seeds = Join-Path $p10W 'seeds'; New-Item -ItemType Directory $p10Seeds | Out-Null
foreach ($m in 'make_mid', 'make_complete', 'make_new', 'make_incons') {
  $iso = Join-Path $p10W "iso_$m"
  P10Boot "SEED_$m" $p10Base $m $iso $null $true
  Copy-Item -LiteralPath (P10Ud $iso) (Join-Path $p10Seeds "$m.json")
  Remove-Item -Recurse -Force $iso -ErrorAction SilentlyContinue
}
$p10Fixed = Join-Path $p10Ev 'relocked_M_insert2_f606801.json'
foreach ($c in $p10Cases) {
  $iso = Join-Path $p10W "iso_$($c.id)"
  $n = 0
  foreach ($st in $c.steps) {
    $n++
    $vs = @($st | ForEach-Object { [string]$_ })
    $proj = P10Variant $vs
    $seed = $null
    if ($n -eq 1) {
      if ($c.seed -eq 'relocked') {
        if (-not (Test-Path -LiteralPath $p10Fixed)) { "P10 ERROR relocked seed missing ($p10Fixed); run at f606801 first"; break }
        $seed = $p10Fixed
      } elseif ($c.seed -ne 'none') { $seed = Join-Path $p10Seeds "$($c.seed).json" }
    }
    P10Boot "$($c.id)__s$n" $proj 'report' $iso $seed ($n -eq 1)
  }
  if ($c.id -eq 'M_insert2' -and $p10S7 -eq 'f606801' -and -not (Test-Path -LiteralPath $p10Fixed)) {
    Copy-Item -LiteralPath (P10Ud $iso) $p10Fixed; "P10 fixed relocked seed written: $(P10H $p10Fixed)"
  }
  Remove-Item -Recurse -Force $iso -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath (Join-Path $p10Seeds 'make_new.json') (Join-Path $p10Out 'seed_make_new.json') -Force
Remove-Item -Recurse -Force $p10W -ErrorAction SilentlyContinue
"P10 job end $(Get-Date -Format s)"
$global:LASTEXITCODE = 0
