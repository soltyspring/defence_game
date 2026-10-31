# Heavy job (10-research-systems, v0.34): round re-lock after content updates. Real boots of a clean LF snapshot,
# data variants made only in throwaway copies (probes/relock_variants.py), every boot in a private APPDATA
# (probes/isolated_godot.ps1). Headless only: one --headless import of the base, then data-only copies (JSON is read
# with FileAccess, so copies need no re-import). Unpatched f606801 code only. Run ONLY via heavy_run_detached. Prefix p10.
$ErrorActionPreference = 'Continue'
$p10Root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
Set-Location -LiteralPath $p10Root
$p10Sha = 'f606801bbe115f92a8adaf6be6ee932e7a1c4a1d'
$p10Li = $PSScriptRoot
$p10W = Join-Path $p10Li 'rl'
$p10Wrap = Join-Path $p10Root 'docs\research\systems\probes\isolated_godot.ps1'
$p10Var = Join-Path $p10Root 'docs\research\systems\probes\relock_variants.py'
Remove-Item -Recurse -Force $p10W -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $p10W | Out-Null
$p10Base = Join-Path $p10W 'base'
New-Item -ItemType Directory $p10Base | Out-Null
git -c core.autocrlf=false -c core.eol=lf archive --format=zip -o "$p10Base.zip" $p10Sha
Expand-Archive "$p10Base.zip" -DestinationPath $p10Base; Remove-Item "$p10Base.zip"
Copy-Item (Join-Path $p10Root 'docs\research\systems\probes\probe_relock.gd') "$p10Base\docs\research\systems\probes\" -Force
"P10 snapshot $p10Sha (LF)"
$r = & $p10Wrap -GodotArgs @('--headless', '--path', $p10Base, '--import', '--quit-after', '300') -WorkDir (Join-Path $p10W 'iso_import') -Keep -TimeoutSec 300
$r | Where-Object { $_ -like 'ISOLATED_GODOT*' }
$p10Uid = Join-Path $p10Base 'docs\research\systems\probes\probe_relock.gd.uid'
if (Test-Path -LiteralPath $p10Uid) { Copy-Item -LiteralPath $p10Uid (Join-Path $p10Root 'docs\research\systems\probes\') -Force; "P10 uid " + (Get-Content -LiteralPath $p10Uid -Raw).Trim() }
function P10Ud($iso) { Join-Path $iso 'appdata\Godot\app_userdata\Lane Defence\save.json' }
# prints only (no return value)
function P10Boot($label, $proj, $mode, $iso, $seed) {
  $a = @('--headless', '--path', $proj, '-s', 'res://docs/research/systems/probes/probe_relock.gd', '--quit-after', '600', '--', "--mode=$mode")
  $ud = P10Ud $iso
  if ($seed) { Remove-Item -Recurse -Force $iso -ErrorAction SilentlyContinue }
  $pre = if ($seed) { (Get-FileHash -LiteralPath $seed).Hash.Substring(0, 12).ToLower() } elseif (Test-Path -LiteralPath $ud) { (Get-FileHash -LiteralPath $ud).Hash.Substring(0, 12).ToLower() } else { 'none' }
  if ($seed) { $rr = & $p10Wrap -GodotArgs $a -WorkDir $iso -Keep -TimeoutSec 120 -SeedSave $seed } else { $rr = & $p10Wrap -GodotArgs $a -WorkDir $iso -Keep -TimeoutSec 120 }
  "RUN $label sha_before=$pre " + (($rr | Where-Object { $_ -like 'PROBE10_RELOCK *' }) -replace '^PROBE10_RELOCK ', '')
  $iz = "$($rr | Where-Object { $_ -like 'ISOLATED_GODOT*' })"
  if ($iz -notmatch '"isolated":true' -or $iz -notmatch '"real_save_changed_during_run":false') { "P10 ISOLATION_PROBLEM $label $iz" } else { "P10 iso_ok $label" }
  $rr | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|refund_unknown|\[Content\]' } | ForEach-Object { "P10 LOG $label | $_" }
}
function P10Mut($dir, $variant) { python $p10Var $dir $variant | ForEach-Object { "P10 MUT $(Split-Path $dir -Leaf) | $_" } }
# ---- seeds (real record_result / buy_upgrade on unchanged data)
$p10Seeds = Join-Path $p10W 'seeds'; New-Item -ItemType Directory $p10Seeds | Out-Null
foreach ($m in 'make_mid', 'make_complete', 'make_incons') {
  P10Boot "SEED_$m" $p10Base $m (Join-Path $p10W "iso_$m") $null
  Copy-Item -LiteralPath (P10Ud (Join-Path $p10W "iso_$m")) (Join-Path $p10Seeds "$m.json")
  Remove-Item -Recurse -Force (Join-Path $p10W "iso_$m") -ErrorAction SilentlyContinue
}
$p10Mid = Join-Path $p10Seeds 'make_mid.json'; $p10Cmp = Join-Path $p10Seeds 'make_complete.json'; $p10Inc = Join-Path $p10Seeds 'make_incons.json'
# ---- one side only: the unpatched f606801 code (v0.34 resume after the 03:55 BSOD: no patched-code side, headless only)
foreach ($side in 'U') {
  $b = $p10Base
  P10Boot "${side}_mid_nochange" $b 'report' (Join-Path $p10W 'iso_x') $p10Mid
  foreach ($k in 'cap4', 'remove_r03', 'insert1', 'insert2', 'move_r03_end', 'rename2', 'rename2_map') {
    $d = Join-Path $p10W "${side}_$k"; Copy-Item -Recurse $b $d; P10Mut $d $k
    P10Boot "${side}_mid_$k" $d 'report' (Join-Path $p10W 'iso_x') $p10Mid
    if ($k -eq 'insert1') {
      P10Mut $d 'insert1b'   # second update on top of the first, same player file (no play in between)
      P10Boot "${side}_mid_chain2_insert1b" $d 'report' (Join-Path $p10W 'iso_x') $null
    }
    Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
  }
  $d = Join-Path $p10W "${side}_bytes_only"; Copy-Item -Recurse $b $d; P10Mut $d 'bytes_only'
  P10Boot "${side}_mid_bytes_only" $d 'report' (Join-Path $p10W 'iso_x') $p10Mid
  P10Boot "${side}_complete_bytes_only" $d 'report' (Join-Path $p10W 'iso_x') $p10Cmp
  P10Boot "${side}_complete_bytes_only_2nd_boot" $d 'report' (Join-Path $p10W 'iso_x') $null
  P10Boot "${side}_incons_bytes_only" $d 'report' (Join-Path $p10W 'iso_x') $p10Inc
  Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
  $d = Join-Path $p10W "${side}_cap4b"; Copy-Item -Recurse $b $d; P10Mut $d 'cap4'
  P10Boot "${side}_incons_cap4" $d 'report' (Join-Path $p10W 'iso_x') $p10Inc
  Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
}
$p10Ev = Join-Path $p10Root 'docs\research\systems\evidence\relock_20261101'
New-Item -ItemType Directory -Force $p10Ev | Out-Null
Copy-Item -LiteralPath (Join-Path $p10Seeds 'make_mid.json'), (Join-Path $p10Seeds 'make_complete.json'), (Join-Path $p10Seeds 'make_incons.json') -Destination $p10Ev -Force
Remove-Item -Recurse -Force $p10W -ErrorAction SilentlyContinue
"P10 job end $(Get-Date -Format s)"
$global:LASTEXITCODE = 0
