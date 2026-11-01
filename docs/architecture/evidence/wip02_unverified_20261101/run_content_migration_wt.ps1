# Driver for probe_content_migration.gd (10-research-systems). Read-only for the repository:
# it exports HEAD with `git archive` into %TEMP%, mutates data ONLY inside throwaway copies, and runs the probe
# against a save fixture under %TEMP%. The real data/** and the real user save are never touched.
# Usage (workspace root):  powershell -NoProfile -File docs/research/systems/probes/run_content_migration.ps1
$ErrorActionPreference = 'Continue'   # native Godot stderr must not abort the run (Windows PowerShell 5)
$godot = (Resolve-Path 'tools/engine/Godot_v4.7.2-stable_win64_console.exe').Path
$sha = (git rev-parse HEAD).Trim()
$root = Join-Path $env:TEMP "probe10_mig_wt02"
# v0.29: every Godot child runs with a PRIVATE APPDATA (user:// can never be the real player folder, §9.17)
$realAppData = $env:APPDATA
$env:APPDATA = Join-Path $env:TEMP "probe10_mig_appdata_$($sha.Substring(0,7))"
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
try {
$u8 = New-Object Text.UTF8Encoding($false)
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
New-Item -ItemType Directory $root | Out-Null
$base = Join-Path $root 'base'
New-Item -ItemType Directory $base | Out-Null
git archive --format=zip -o "$root/head.zip" HEAD
Expand-Archive "$root/head.zip" -DestinationPath $base
Remove-Item "$root/head.zip"
# 02 overlay (local copy in build/, not 10's file): uncommitted working-tree engine files
$root02 = (Resolve-Path '.').Path
foreach ($f in @('src/core/app.gd','src/core/content.gd','src/core/save.gd','src/core/events.gd','src/gameplay/fallback_ui.gd')) { $w = Join-Path $root02 ('build/wip02/' + $f); $src = if (Test-Path $w) { $w } else { Join-Path $root02 $f }; Copy-Item $src "$base/$f" -Force }
"overlay: app content save events fallback_ui (build/wip02 first, else working tree)"
$pg = [IO.File]::ReadAllText("$base/project.godot") -replace 'config/name="[^"]*"', 'config/name="Probe10 Snapshot"'
[IO.File]::WriteAllText("$base/project.godot", $pg, $u8)
New-Item -ItemType Directory -Force "$base/docs/research/systems/probes" | Out-Null
Copy-Item docs/research/systems/probes/probe_content_migration.gd "$base/docs/research/systems/probes/"
& $godot --headless --path $base --import --quit-after 3000 2>&1 | Out-Null

function J($d, $p) { [IO.File]::ReadAllText("$d/$p", [Text.Encoding]::UTF8) | ConvertFrom-Json }
function W($d, $p, $o) { [IO.File]::WriteAllText("$d/$p", ($o | ConvertTo-Json -Depth 20), $u8) }
function Reindex($d) {
  $o = J $d 'data/rounds/order.json'; $i = 0
  foreach ($rid in $o.rounds) { $i++; $r = J $d "data/rounds/$rid.json"; $r.index = $i; W $d "data/rounds/$rid.json" $r }
}
function Run($d, $mode, $fixture, $label) {
  $line = & $godot --headless --path $d -s res://docs/research/systems/probes/probe_content_migration.gd --quit-after 900 -- "--mode=$mode" "--fixture=$fixture" "--label=$label" 2>&1 |
    ForEach-Object { "$_" } | Where-Object { $_ -like 'PROBE10_MIGRATION *' -or $_ -like '*SCRIPT ERROR*' }
  $line
}

$fixture = (Join-Path $root 'fixture.json').Replace('\', '/')
Run $base 'make' $fixture 'M0_make'

$mut = [ordered]@{
  'M0_baseline'          = { param($d) }
  'M1_remove_r03'        = { param($d) $o = J $d 'data/rounds/order.json'; $o.rounds = @($o.rounds | Where-Object { $_ -ne 'r03' }); W $d 'data/rounds/order.json' $o; Remove-Item "$d/data/rounds/r03.json"; Reindex $d }
  'M2_insert_r02b'       = { param($d) $r = J $d 'data/rounds/r02.json'; $r.id = 'r02b'; W $d 'data/rounds/r02b.json' $r; $o = J $d 'data/rounds/order.json'; $n = @(); foreach ($x in $o.rounds) { $n += $x; if ($x -eq 'r02') { $n += 'r02b' } }; $o.rounds = $n; W $d 'data/rounds/order.json' $o; Reindex $d }
  'M3_swap_r04_r05'      = { param($d) $o = J $d 'data/rounds/order.json'; $n = @($o.rounds); $a = [array]::IndexOf($n, 'r04'); $b = [array]::IndexOf($n, 'r05'); $n[$a] = 'r05'; $n[$b] = 'r04'; $o.rounds = $n; W $d 'data/rounds/order.json' $o; Reindex $d }
  'M4_melee_max_level_3' = { param($d) $m = J $d 'data/meta.json'; $u = $m.upgrades | Where-Object id -eq 'up_melee_basic'; $u.max_level = 3; $u.costs = @($u.costs[0], $u.costs[1]); W $d 'data/meta.json' $m }
  'M5a_unit_id_rename'   = { param($d) $uj = J $d 'data/units/units.json'; ($uj.units | Where-Object id -eq 'melee_basic').id = 'toast_knight'; W $d 'data/units/units.json' $uj
                             foreach ($f in Get-ChildItem "$d/data/rounds" -Filter 'r*.json') { $r = J $d "data/rounds/$($f.Name)"; if ($r.cards) { $r.cards = @($r.cards | ForEach-Object { if ($_ -eq 'melee_basic') { 'toast_knight' } else { $_ } }) }; W $d "data/rounds/$($f.Name)" $r }
                             $m = J $d 'data/meta.json'; ($m.upgrades | Where-Object id -eq 'up_melee_basic').target = 'unit:toast_knight'; W $d 'data/meta.json' $m }
  'M5b_upgrade_id_rename'= { param($d) $m = J $d 'data/meta.json'; ($m.upgrades | Where-Object id -eq 'up_melee_basic').id = 'up_toast_knight'; W $d 'data/meta.json' $m }
}
foreach ($k in $mut.Keys) {
  $d = Join-Path $root $k
  Copy-Item -Recurse $base $d
  & $mut[$k] $d
  $fx = (Join-Path $root "fixture_$k.json").Replace('\', '/')
  Copy-Item ($fixture.Replace('/', '\')) ($fx.Replace('/', '\'))
  Run $d 'load' $fx $k
  Remove-Item -Recurse -Force $d
}
Remove-Item -Recurse -Force $root
"HEAD=$sha"
"isolation: private APPDATA=$($env:APPDATA) logs_present=$(Test-Path (Join-Path $env:APPDATA 'Godot\app_userdata\Probe10 Snapshot\logs'))"
} finally {
  $priv = $env:APPDATA
  $env:APPDATA = $realAppData
  Remove-Item -Recurse -Force $priv -ErrorAction SilentlyContinue
}
