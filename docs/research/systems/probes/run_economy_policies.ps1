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
# v0.29: the Godot child gets a PRIVATE APPDATA (user:// can never be the real player folder, §9.17)
$realAppData = $env:APPDATA
$env:APPDATA = Join-Path $tmp 'appdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
try {
  if ($Rev) {
    Push-Location $root; git -c core.autocrlf=false -c core.eol=lf archive --format=zip -o "$tmp\d.zip" $Rev data; Pop-Location   # v0.34: LF
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
  foreach ($p in 'P0_none', 'P1_first_clear', 'P2_max', 'P3_opt') {
    "== $p"
    "round | coins_at_entry | bought_now | left | levels_total | card_hp_mult | hero | enemy_hp | card-enemy | levels"
    $rows | Where-Object { $_.policy -eq $p -and $_.row.round -notlike 'after_*' } | ForEach-Object { $r = $_.row; "$($r.round) | $($r.coins_at_entry) | $($r.bought_now) | $($r.left_after) | $($r.levels_total) | $($r.card_hp_mult_mean) | $($r.hero_mult) | $($r.enemy_hp) | $($r.card_minus_enemy_hp) | $($r.levels)" }
    $rows | Where-Object { $_.policy -eq $p -and $_.row.round -like 'after_*' } | ForEach-Object { $r = $_.row; "$($r.round) result screen: coins $($r.coins_at_entry) -> bought $($r.bought_now), left $($r.left_after), levels $($r.levels_total), remaining $($r.remaining_to_max), deficit $($r.deficit), replays to max 30/40/50%: $($r.replays_to_max.'30'.replays)/$($r.replays_to_max.'40'.replays)/$($r.replays_to_max.'50'.replays)" }
  }
  # Cross-check against 01's docs/design/balance/upgrade_budgets.json (same revision): P1 = low, P3 = opt.
  if ($Rev) { Push-Location $root; $bj = git show "${Rev}:docs/design/balance/upgrade_budgets.json" 2>$null; Pop-Location } else { $bj = Get-Content (Join-Path $root 'docs\design\balance\upgrade_budgets.json') -Raw -Encoding UTF8 }
  if ($bj) {
    $b = ($bj -join "`n") | ConvertFrom-Json
    foreach ($pair in @(@('P1_first_clear', 'low'), @('P3_opt', 'opt'))) {
      $diffs = @()
      foreach ($x in ($rows | Where-Object { $_.policy -eq $pair[0] -and $_.row.round -notlike 'after_*' })) {
        $rid = $x.row.round; $ref = $b.($pair[1]).$rid
        if ($null -eq $ref) { $diffs += "$rid missing in budgets"; continue }
        $mine = ($x.row.levels_map.PSObject.Properties | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ','
        $theirs = ($ref.levels.PSObject.Properties | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ','
        if ($mine -ne $theirs -or [int]$x.row.left_after -ne [int]$ref.leftover) { $diffs += "$rid mine[$mine left $($x.row.left_after)] budgets[$theirs left $($ref.leftover)]" }
      }
      "budgets check $($pair[0]) vs $($pair[1]): rounds $(@($rows | Where-Object { $_.policy -eq $pair[0] -and $_.row.round -notlike 'after_*' }).Count), diffs $($diffs.Count)"
      $diffs
    }
  } else { "budgets check: upgrade_budgets.json not found" }
  $out | Where-Object { $_ -like 'PROBE10_ECON_POLICIES*' -or $_ -like '*SCRIPT ERROR*' }
} finally {
  $env:APPDATA = $realAppData
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
