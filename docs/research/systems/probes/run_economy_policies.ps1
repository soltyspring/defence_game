# One-line rerun of probe_economy_policies.gd (10-research-systems). Read-only for the repository.
# Default: uses the CURRENT WORKING TREE data/** (so 01 can check edits before committing).
# -Rev <git rev>: uses that commit's data/** instead (e.g. -Rev HEAD).
# It copies data + the probe into a throwaway %TEMP% project without autoloads, runs headless (600 s cap),
# prints a table and deletes the temp project. Usage from the workspace root:
#   powershell -NoProfile -File docs/research/systems/probes/run_economy_policies.ps1
#   powershell -NoProfile -File docs/research/systems/probes/run_economy_policies.ps1 -Rev HEAD
param([string]$Rev = '')
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
$godot = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$tmp = Join-Path $env:TEMP ("p10pol_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $tmp | Out-Null
try {
  if ($Rev) {
    Push-Location $root; git archive --format=zip -o "$tmp\d.zip" $Rev data; Pop-Location
    Expand-Archive "$tmp\d.zip" -DestinationPath $tmp; Remove-Item "$tmp\d.zip"
    $label = "rev $Rev"
  } else {
    Copy-Item -Recurse (Join-Path $root 'data') (Join-Path $tmp 'data')
    $label = 'working tree'
  }
  [IO.File]::WriteAllText("$tmp\project.godot", "config_version=5`n[application]`nconfig/name=`"Probe10 Policies`"`n", (New-Object Text.UTF8Encoding($false)))
  New-Item -ItemType Directory -Force "$tmp\probe" | Out-Null
  Copy-Item (Join-Path $PSScriptRoot 'probe_economy_policies.gd') "$tmp\probe\"
  $out = & $godot --headless --path $tmp -s res://probe/probe_economy_policies.gd --quit-after 600 2>&1 | ForEach-Object { "$_" }
  "data: $label   exit: $LASTEXITCODE"
  $rows = $out | Where-Object { $_ -like 'EP *' } | ForEach-Object { $_.Substring(3) | ConvertFrom-Json }
  foreach ($p in 'P0_none', 'P1_first_clear', 'P2_max') {
    "== $p"
    "round | coins_at_entry | bought_now | left | levels_total | card_hp_mult | hero | enemy_hp | card-enemy | levels"
    $rows | Where-Object policy -eq $p | ForEach-Object { $r = $_.row; "$($r.round) | $($r.coins_at_entry) | $($r.bought_now) | $($r.left_after) | $($r.levels_total) | $($r.card_hp_mult_mean) | $($r.hero_mult) | $($r.enemy_hp) | $($r.card_minus_enemy_hp) | $($r.levels)" }
  }
  $out | Where-Object { $_ -like 'PROBE10_ECON_POLICIES*' -or $_ -like '*SCRIPT ERROR*' }
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force "$env:APPDATA\Godot\app_userdata\Probe10 Policies" -ErrorAction SilentlyContinue
}
