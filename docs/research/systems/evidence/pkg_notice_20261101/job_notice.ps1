# Heavy job (10-research-systems, v0.33): (i) 04's test_migration_notice.gd once in a private APPDATA, (ii) 10's
# notice cases on REAL process boots. Run ONLY via coordination/heavy_run_detached.ps1. Variables prefixed p10.
$ErrorActionPreference = 'Continue'
$p10Root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
Set-Location -LiteralPath $p10Root
$p10Sha = 'eb8d5c43c48500399956a41786a66ac102ba1b2a'
$p10Li = $PSScriptRoot
$p10Wrap = Join-Path $p10Root 'docs\research\systems\probes\isolated_godot.ps1'
$p10U8 = New-Object Text.UTF8Encoding($false)
$p10A = Join-Path $p10Li 'nt_A'
Get-ChildItem $p10Li -Directory -Filter 'nt_*' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $p10A | Out-Null
git -c core.autocrlf=false -c core.eol=lf archive --format=zip -o "$p10A.zip" $p10Sha
Expand-Archive "$p10A.zip" -DestinationPath $p10A; Remove-Item "$p10A.zip"
Copy-Item (Join-Path $p10Root 'docs\research\systems\probes\probe_notice_cases.gd') "$p10A\docs\research\systems\probes\" -Force
"P10 snapshot $p10Sha (LF)"
$r = & $p10Wrap -GodotArgs @('--headless', '--path', $p10A, '--import', '--quit-after', '300') -WorkDir (Join-Path $p10Li 'nt_iso_import') -Keep -TimeoutSec 300
$r | Where-Object { $_ -like 'ISOLATED_GODOT*' }
# (i) 04's test as written, private APPDATA
$r = & $p10Wrap -GodotArgs @('--headless', '--path', $p10A, '-s', 'res://tests/integration/test_migration_notice.gd') -WorkDir (Join-Path $p10Li 'nt_iso_04') -Keep -TimeoutSec 120
"P10 04TEST exit=$LASTEXITCODE"
$r | Where-Object { $_ -match '^\s+ok |FAIL|\[migration_notice\]|SCRIPT ERROR|ISOLATED_GODOT' } | ForEach-Object { "04T| $_" }
$p10U04 = Join-Path $p10Li 'nt_iso_04\appdata\Godot\app_userdata'
Get-ChildItem -LiteralPath $p10U04 -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike 'godot*.log' } | ForEach-Object { "04F| " + $_.FullName.Substring($p10U04.Length) + " bytes=" + $_.Length }
# data builds: E1 = melee cap 4, E2 = melee cap 3 (byte edits, LF kept)
function P10Cap($dir, $cap) {
  $f = Join-Path $dir 'data\meta.json'; $t = [IO.File]::ReadAllText($f)
  $old = "`"id`": `"up_melee_basic`",`n      `"target`": `"unit:melee_basic`",`n      `"name_key`": `"upgrade.unit`",`n      `"max_level`": 5,`n      `"costs`": [`n        60,`n        100,`n        160,`n        190`n      ]"
  $new = if ($cap -eq 4) { "`"id`": `"up_melee_basic`",`n      `"target`": `"unit:melee_basic`",`n      `"name_key`": `"upgrade.unit`",`n      `"max_level`": 4,`n      `"costs`": [`n        60,`n        100,`n        160`n      ]" } else { "`"id`": `"up_melee_basic`",`n      `"target`": `"unit:melee_basic`",`n      `"name_key`": `"upgrade.unit`",`n      `"max_level`": 3,`n      `"costs`": [`n        60,`n        100`n      ]" }
  if (-not $t.Contains($old)) { throw "melee block not found in $f" }
  [IO.File]::WriteAllText($f, $t.Replace($old, $new), $p10U8)
}
$p10E1 = Join-Path $p10Li 'nt_E1_cap4'; Copy-Item -Recurse $p10A $p10E1; P10Cap $p10E1 4
$p10E2 = Join-Path $p10Li 'nt_E2_cap3'; Copy-Item -Recurse $p10A $p10E2; P10Cap $p10E2 3
function P10Step($label, $proj, $mode, $iso) {
  $r = & $p10Wrap -GodotArgs @('--headless', '--path', $proj, '-s', 'res://docs/research/systems/probes/probe_notice_cases.gd', '--quit-after', '600', '--', "--mode=$mode") -WorkDir $iso -Keep -TimeoutSec 120
  "STEP $label " + (($r | Where-Object { $_ -like 'PROBE10_NOTICE *' }) -replace '^PROBE10_NOTICE ', '')
  ($r | Where-Object { $_ -like 'ISOLATED_GODOT*' })
  $r | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|refund_unknown' }
}
$p10IsoS = Join-Path $p10Li 'nt_iso_stack'
P10Step 'K1_A_make' $p10A 'make' $p10IsoS
P10Step 'K2_E1_menu_no_ack' $p10E1 'menu' $p10IsoS
P10Step 'K3_E2_second_update_before_ack' $p10E2 'menu' $p10IsoS
P10Step 'K4_E2_pause_on_notice' $p10E2 'pause' $p10IsoS
P10Step 'K5_E2_real_restart' $p10E2 'menu' $p10IsoS
P10Step 'K6_E2_close_ack' $p10E2 'ack' $p10IsoS
P10Step 'K7_E2_after_ack' $p10E2 'menu' $p10IsoS
$p10IsoL = Join-Path $p10Li 'nt_iso_legacy'
P10Step 'L1_A_legacy_no_prices' $p10A 'legacy' $p10IsoL
P10Step 'L2_E2_refund0_menu' $p10E2 'menu' $p10IsoL
$p10Uid = Join-Path $p10A 'docs\research\systems\probes\probe_notice_cases.gd.uid'
if (Test-Path -LiteralPath $p10Uid) { Copy-Item -LiteralPath $p10Uid (Join-Path $p10Root 'docs\research\systems\probes\') -Force; "P10 uid copied: " + (Get-Content -LiteralPath $p10Uid -Raw).Trim() } else { 'P10 uid missing' }
Get-ChildItem $p10Li -Directory -Filter 'nt_*' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
$global:LASTEXITCODE = 0
