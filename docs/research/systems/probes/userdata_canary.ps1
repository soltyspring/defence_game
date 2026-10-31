# userdata_canary.ps1 (10-research-systems): one-shot, READ-ONLY check (seconds, no Godot) of whether anything wrote
# the REAL player folder since a recorded baseline. v0.32: X1 (52f9fa3) means a boot no longer rewrites save.json when
# nothing changed, so the old "content_version differs -> a boot would have rewritten it" signal is gone. The check is
# now purely hash/mtime/size based against a baseline file, plus the log-rotation signal for runs that booted there.
# Usage (workspace root):
#   pwsh -NoProfile -File docs/research/systems/probes/userdata_canary.ps1 -SaveBaseline [-Baseline <file>]
#   pwsh -NoProfile -File docs/research/systems/probes/userdata_canary.ps1 [-Baseline <file>]
#   pwsh -NoProfile -File docs/research/systems/probes/userdata_canary.ps1 -Manifest docs/research/systems/evidence/userdata_backup_20261031-191353/MANIFEST.tsv
# Default baseline file: docs/research/systems/.local_inspect/userdata_baseline.json (git-ignored, this PC only).
# It records, for the real folder: every file's relative path, size and mtime; SHA-256 of save.json / save.json.bak;
# the rotated log names in logs/. The watched folder is only read.
# Signals:
#  1. save.json / .bak SHA-256, size or mtime differ from the baseline  -> the player save was written.
#  2. any other file new / changed / removed                           -> something wrote the real user dir.
#  3. a rotated logs/godot<start>.log newer than the baseline           -> a Godot run started IN the real user dir
#     (runs with --log-file elsewhere are not seen by this signal; signal 1/2 still are).
# Output: "CANARY ..." lines and a final "USERDATA_CANARY <json>". Exit 0 (the verdict is in the JSON).
param([switch]$SaveBaseline, [string]$Baseline = '', [string]$Manifest = '',
      [string]$Folder = (Join-Path $env:APPDATA 'Godot\app_userdata\Lane Defence'))
$ErrorActionPreference = 'Continue'
$cRoot = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
if (-not $Baseline) { $Baseline = Join-Path $cRoot 'docs\research\systems\.local_inspect\userdata_baseline.json' }
function CSha($p) { try { (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash } catch { 'LOCKED' } }
function CSnap {
  $files = [ordered]@{}
  foreach ($f in Get-ChildItem -LiteralPath $Folder -Recurse -File -Force -ErrorAction SilentlyContinue) {
    $rel = $f.FullName.Substring($Folder.Length + 1).Replace('\', '/')
    $files[$rel] = [ordered]@{ bytes = $f.Length; mtime = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') }
  }
  $saves = [ordered]@{}
  foreach ($n in 'save.json', 'save.json.bak') {
    $p = Join-Path $Folder $n
    $saves[$n] = if (Test-Path -LiteralPath $p) { [ordered]@{ sha256 = (CSha $p); bytes = (Get-Item -LiteralPath $p -Force).Length; mtime = (Get-Item -LiteralPath $p -Force).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') } } else { $null }
  }
  $rot = @(Get-ChildItem -LiteralPath (Join-Path $Folder 'logs') -Filter 'godot*.log' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'godot.log' } | ForEach-Object Name | Sort-Object)
  [ordered]@{ taken_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); folder = $Folder; saves = $saves; files = $files; rotated_logs = $rot }
}
$now = CSnap
if ($SaveBaseline) {
  New-Item -ItemType Directory -Force (Split-Path $Baseline -Parent) | Out-Null
  [IO.File]::WriteAllText($Baseline, ($now | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
  "CANARY baseline saved $Baseline files=$($now.files.Count) save=$($now.saves.'save.json'.sha256.Substring(0, 16)) bak=$($now.saves.'save.json.bak'.sha256.Substring(0, 16))"
  "USERDATA_CANARY " + ([ordered]@{ mode = 'baseline'; baseline = $Baseline; taken_at = $now.taken_at; files = $now.files.Count } | ConvertTo-Json -Compress)
  exit 0
}
if ($Manifest) {   # historical baseline from a backup manifest (path, bytes, mtime, sha256): signals 1 and 2 only
  $base = [ordered]@{ taken_at = '(manifest) ' + $Manifest; saves = [ordered]@{}; files = [ordered]@{}; rotated_logs = @() }
  foreach ($l in Get-Content -LiteralPath $Manifest -Encoding UTF8) {
    if ($l -like '#*' -or $l -like 'path*') { continue }
    $c = $l -split "`t"
    $base.files[$c[0]] = [ordered]@{ bytes = [long]$c[1]; mtime = $c[2] }
    if ($c[0] -eq 'save.json' -or $c[0] -eq 'save.json.bak') { $base.saves[$c[0]] = [ordered]@{ sha256 = $c[3]; bytes = [long]$c[1]; mtime = $c[2] } }
  }
  $base.rotated_logs = @($base.files.Keys | Where-Object { $_ -like 'logs/godot2*' } | ForEach-Object { $_.Substring(5) })
} else {
  if (-not (Test-Path -LiteralPath $Baseline)) { "CANARY no baseline at $Baseline; run with -SaveBaseline first"; exit 0 }
  $base = Get-Content -LiteralPath $Baseline -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
}
$saveChanges = @()
foreach ($n in 'save.json', 'save.json.bak') {
  $b = $base.saves[$n]; $c = $now.saves[$n]
  if ($null -eq $b -and $null -eq $c) { continue }
  if ($null -eq $b -or $null -eq $c -or $b.sha256 -ne $c.sha256 -or [long]$b.bytes -ne [long]$c.bytes -or $b.mtime -ne $c.mtime) {
    $saveChanges += "$n sha $(if ($b) { $b.sha256.Substring(0, 16) } else { '-' })->$(if ($c) { $c.sha256.Substring(0, 16) } else { '-' }) mtime $(if ($b) { $b.mtime } else { '-' })->$(if ($c) { $c.mtime } else { '-' })"
  }
}
$other = @()
foreach ($k in $now.files.Keys) {
  if ($k -eq 'save.json' -or $k -eq 'save.json.bak' -or $k -eq 'logs/godot.log') { continue }
  $b = $base.files[$k]; $c = $now.files[$k]
  if ($null -eq $b) { $other += "new $k ($($c.mtime))" } elseif ([long]$b.bytes -ne [long]$c.bytes -or $b.mtime -ne $c.mtime) { $other += "changed $k ($($b.mtime)->$($c.mtime))" }
}
foreach ($k in $base.files.Keys) { if ($k -ne 'logs/godot.log' -and -not $now.files.Contains($k)) { $other += "removed $k" } }
$newRuns = @($now.rotated_logs | Where-Object { $base.rotated_logs -notcontains $_ })
foreach ($s in $saveChanges) { "CANARY SAVE CHANGED $s" }
foreach ($o in $other) { "CANARY FILE $o" }
foreach ($r in $newRuns) { "CANARY NEW REAL-DIR RUN log $r" }
$verdict = if ($saveChanges.Count) { 'PLAYER SAVE WRITTEN since baseline' } elseif ($newRuns.Count) { 'Godot run(s) started in the real user dir since baseline (save not written)' } elseif ($other.Count) { 'other files in the real user dir changed since baseline (save not written)' } else { 'no change since baseline' }
"USERDATA_CANARY " + ([ordered]@{ mode = 'compare'; checked_at = $now.taken_at; baseline_taken_at = $base.taken_at; save_changes = $saveChanges.Count;
  other_file_changes = $other.Count; new_real_dir_runs = $newRuns.Count;
  save_sha16 = $(if ($now.saves['save.json']) { $now.saves['save.json'].sha256.Substring(0, 16) }); save_mtime = $(if ($now.saves['save.json']) { $now.saves['save.json'].mtime });
  verdict = $verdict } | ConvertTo-Json -Compress)
