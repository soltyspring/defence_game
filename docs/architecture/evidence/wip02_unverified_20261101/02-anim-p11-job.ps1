# 02 job (one queue slot). Start: & .\coordination\heavy_run_detached.ps1 -Label '02-anim-p11' -ScriptFile build\heavy\02-anim-p11-job.ps1
# Clean HEAD snapshot + 02's WIP copy (build/wip02/**; the shared tree is NOT used for the experiment).
# Headless checks first. Only if all pass: ONE visible comparison on DISPLAY2 (07's fixed set, ko_1x 800x360), run twice
# in the same snapshot: A = data as is, B = the biome "sky" layers flagged `opaque: true` (test copy only) -> pixel diff.
$ErrorActionPreference = 'Continue'
$root = 'Z:\.solty\dev\appintoss\defence'
Set-Location $root
$ev = Join-Path $root 'build\save_evidence\anim02'
if (Test-Path $ev) { Remove-Item -Recurse -Force $ev }
New-Item -ItemType Directory -Force $ev | Out-Null
$godot = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$snap = Join-Path $env:TEMP 'snap02_anim'
if (Test-Path $snap) { Remove-Item -Recurse -Force $snap }
New-Item -ItemType Directory -Force $snap | Out-Null
$sha = (& git rev-parse --short HEAD).Trim()
& git archive --format=zip -o "$snap.zip" HEAD
Expand-Archive "$snap.zip" $snap -Force
Remove-Item "$snap.zip"
$wip = Join-Path $root 'build\wip02'
$files = Get-ChildItem $wip -Recurse -File | ForEach-Object { $_.FullName.Substring($wip.Length + 1) }
foreach ($f in $files) { $d = Join-Path $snap $f; New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null; Copy-Item (Join-Path $wip $f) $d -Force }
"STEP snapshot HEAD=$sha overlay=$($files -join ',')"
$env:APPDATA = Join-Path $env:TEMP 'snap02_anim_appdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
function G([string]$name, [string[]]$gargs, [int]$sec) {
  $log = Join-Path $ev "$name.log"
  $p = Start-Process -FilePath $godot -ArgumentList $gargs -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
  $null = $p.Handle
  if (-not $p.WaitForExit($sec * 1000)) { try { $p.Kill() } catch {}; "STEP $name TIMEOUT"; return }
  "STEP $name exit=$($p.ExitCode)"
}
G 'import' @('--headless', '--path', $snap, '--import') 900
G 'selftest' @('--headless', '--path', $snap, '-s', 'res://src/core/diag/selftest.gd') 600
G 'anim' @('--headless', '--path', $snap, '-s', 'res://src/core/diag/anim_display_probe.gd', '--', '--rounds=r06,r08') 600
G 'text' @('--headless', '--path', $snap, '-s', 'res://src/core/diag/text_overlap_probe.gd', '--', '--round=r08', '--seconds=185') 300
G 'ui' @('--headless', '--path', $snap, '-s', 'res://tests/integration/test_ui_integration.gd') 600
$qa = Join-Path $ev 'qa07'
New-Item -ItemType Directory -Force $qa | Out-Null
G 'qa07' @('--headless', '--path', $snap, '-s', 'res://tests/acceptance/acceptance.gd', '--', "--qa-out=$($qa.Replace('\','/'))", '--only=sim,flow,save,faults') 900
# ---- 10 v0.34 round re-lock cases on this snapshot (10's probe_relock.gd + relock_variants.py, read-only; private APPDATA)
$wrap = Join-Path $root 'docs\research\systems\probes\isolated_godot.ps1'
$varpy = Join-Path $root 'docs\research\systems\probes\relock_variants.py'
New-Item -ItemType Directory -Force (Join-Path $snap 'docs\research\systems\probes') | Out-Null
Copy-Item (Join-Path $root 'docs\research\systems\probes\probe_relock.gd') (Join-Path $snap 'docs\research\systems\probes\') -Force
$rl = Join-Path $env:TEMP 'snap02_relock'
if (Test-Path $rl) { Remove-Item -Recurse -Force $rl }
New-Item -ItemType Directory -Force (Join-Path $rl 'seeds') | Out-Null
$dataBak = Join-Path $rl 'data_orig'
Copy-Item -Recurse (Join-Path $snap 'data') $dataBak
$rlog = Join-Path $ev 'relock.log'
function UD($iso) { Join-Path $iso 'appdata\Godot\app_userdata\Lane Defence\save.json' }
function Boot($label, $mode, $iso, $seed) {
  $a = @('--headless', '--path', $snap, '-s', 'res://docs/research/systems/probes/probe_relock.gd', '--', "--mode=$mode")
  if ($seed) { Remove-Item -Recurse -Force $iso -ErrorAction SilentlyContinue; $rr = & $wrap -GodotArgs $a -WorkDir $iso -Keep -TimeoutSec 120 -SeedSave $seed }
  else { $rr = & $wrap -GodotArgs $a -WorkDir $iso -Keep -TimeoutSec 120 }
  "RUN $label " + (($rr | Where-Object { $_ -like 'PROBE10_RELOCK *' }) -replace '^PROBE10_RELOCK ', '') | Out-File $rlog -Append -Encoding utf8
  $rr | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|ISOLATED_GODOT' } | ForEach-Object { "LOG $label | $_" } | Out-File $rlog -Append -Encoding utf8
}
function Restore() { Remove-Item -Recurse -Force (Join-Path $snap 'data'); Copy-Item -Recurse $dataBak (Join-Path $snap 'data') }
function Mut($v) { python $varpy $snap $v | ForEach-Object { "MUT $v | $_" } | Out-File $rlog -Append -Encoding utf8 }
foreach ($m in 'make_mid', 'make_complete', 'make_incons') {
  Boot "SEED_$m" $m (Join-Path $rl "iso_$m") $null
  Copy-Item (UD (Join-Path $rl "iso_$m")) (Join-Path $rl "seeds\$m.json")
}
$mid = Join-Path $rl 'seeds\make_mid.json'; $cmp = Join-Path $rl 'seeds\make_complete.json'; $inc = Join-Path $rl 'seeds\make_incons.json'
$iso = Join-Path $rl 'iso_x'
Boot 'mid_nochange' 'report' $iso $mid
foreach ($k in 'cap4', 'remove_r03', 'insert1', 'insert2', 'move_r03_end', 'rename2', 'rename2_map') {
  Restore; Mut $k
  Boot "mid_$k" 'report' $iso $mid
  if ($k -eq 'insert1') { Mut 'insert1b'; Boot 'mid_chain2_insert1b' 'report' $iso $null }
}
Restore; Mut 'bytes_only'
Boot 'mid_bytes_only' 'report' $iso $mid
Boot 'complete_bytes_only' 'report' $iso $cmp
Boot 'complete_bytes_only_2nd_boot' 'report' $iso $null
Boot 'incons_bytes_only' 'report' $iso $inc
Restore; Mut 'cap4'
Boot 'incons_cap4' 'report' $iso $inc
Restore
"STEP relock done ($((Get-Content $rlog | Where-Object { $_ -like 'RUN *' }).Count) runs)"
# ---- 10 run_content_migration M0-M5b (local runner copy, 02 files from build/wip02 overlaid on HEAD)
& (Join-Path $root 'build\run_content_migration_wt.ps1') *> (Join-Path $ev 'content_migration.log')
"STEP content_migration done"
$ok = (Select-String -Path (Join-Path $ev 'selftest.log') -Pattern 'SELFTEST PASS' -Quiet) -and
      (Select-String -Path (Join-Path $ev 'ui.log') -Pattern 'failed=0' -Quiet) -and
      (Select-String -Path (Join-Path $ev 'qa07.log') -Pattern 'FAIL=0' -Quiet)
if (-not $ok) { "STEP headless checks FAILED: no visible run"; exit 0 }
"STEP headless checks PASS"
# ---- one visible comparison (07 fixed set), A then B in the same snapshot
$launch = Join-Path $root 'tools\build\visible_launch.ps1'
$outA = Join-Path $ev 'fixed_A'
$outB = Join-Path $ev 'fixed_B'
New-Item -ItemType Directory -Force $outA, $outB | Out-Null
$ua = @('--tag=ko_1x', '--locale=ko', '--safe=34,0,34,0', '--target=44')
& $launch -ProjectPath $snap -Script 'res://tests/acceptance/capture_art_baseline.gd' -Resolution 800x360 -EvidenceDir $outA -TimeoutSec 400 -UserArgs (@("--out=$($outA.Replace('\','/'))") + $ua) *> (Join-Path $ev 'fixed_A.log')
"STEP fixed_A exit=$LASTEXITCODE"
python (Join-Path $root 'build\wip02_tools\set_opaque.py') (Join-Path $snap 'assets\manifest.json')
& $launch -ProjectPath $snap -Script 'res://tests/acceptance/capture_art_baseline.gd' -Resolution 800x360 -EvidenceDir $outB -TimeoutSec 400 -UserArgs (@("--out=$($outB.Replace('\','/'))") + $ua) *> (Join-Path $ev 'fixed_B.log')
"STEP fixed_B exit=$LASTEXITCODE"
python (Join-Path $root 'build\wip02_tools\png_diff.py') $outA $outB
"STEP done $(Get-Date -Format s)"
exit 0
