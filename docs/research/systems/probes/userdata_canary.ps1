# userdata_canary.ps1 (10-research-systems): one-shot, READ-ONLY check (a few seconds, no Godot) of whether any
# non-isolated Godot run booted in the REAL player folder since a given time. Replaces the continuous 30-min watch,
# which the 23:2x KST heavy-run rule would have to serialise (it would block everyone else's runs).
# Two independent signals:
#  1. Log rotation: every new run in a user dir renames logs/godot.log to godot<start time>.log. A rotated name newer
#     than -Since in the REAL logs folder = a run started then in the real folder (runs with --log-file are not seen).
#  2. Save canary: since R5 (7f2886c) a boot whose data content_version differs from the save's rewrites save.json
#     (X1, §9.17). If the real save's content_version differs from the current data and save.json is older than the
#     data commit, no non-isolated boot of the current data has happened since that commit.
# Usage: pwsh -NoProfile -File docs/research/systems/probes/userdata_canary.ps1 [-Since '2026-10-31 19:37'] [-Rev HEAD]
# Output: lines "CANARY ..." and a final "USERDATA_CANARY <json>". Exit 0.
param([string]$Since = '', [string]$Rev = 'HEAD', [string]$Folder = (Join-Path $env:APPDATA 'Godot\app_userdata\Lane Defence'))
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
Push-Location $root
$dataCommit = (git log -1 --format='%h %ad' --date=format:'%Y-%m-%d %H:%M:%S' $Rev -- data).Trim()
$dataTime = [datetime]::ParseExact(($dataCommit -split ' ', 2)[1], 'yyyy-MM-dd HH:mm:ss', $null)
if (-not $Since) { $sinceT = $dataTime } else { $sinceT = [datetime]$Since }
$cvLine = python (Join-Path $PSScriptRoot 'content_version.py') ($dataCommit -split ' ')[0] | Select-Object -Last 1
Pop-Location
$cv = ($cvLine -replace '^CONTENT_VERSION ', '') | ConvertFrom-Json
function ReadHead($p, $n) { try { $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite, Delete'); $sr = New-Object IO.StreamReader($fs); $o = @(); while (-not $sr.EndOfStream -and $o.Count -lt $n) { $l = $sr.ReadLine().Trim(); if ($l -and $l -notlike 'Godot Engine*') { $o += $l.Substring(0, [Math]::Min(120, $l.Length)) } }; $sr.Close(); $o -join ' / ' } catch { 'unreadable' } }
$rot = @()
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Folder 'logs') -Filter 'godot*.log' -File -ErrorAction SilentlyContinue) {
  $m = [regex]::Match($f.Name, 'godot(\d{4}-\d{2}-\d{2})T(\d{2})\.(\d{2})\.(\d{2})')
  if ($m.Success) { $t = [datetime]::ParseExact("$($m.Groups[1].Value) $($m.Groups[2].Value):$($m.Groups[3].Value):$($m.Groups[4].Value)", 'yyyy-MM-dd HH:mm:ss', $null); $rot += [pscustomobject]@{ start = $t; name = $f.Name; head = (ReadHead $f.FullName 2) } }
}
$live = Join-Path $Folder 'logs\godot.log'
$liveT = if (Test-Path -LiteralPath $live) { (Get-Item -LiteralPath $live).LastWriteTime } else { $null }
$newRuns = @($rot | Where-Object { $_.start -ge $sinceT } | Sort-Object start)
foreach ($r in ($rot | Sort-Object start)) { "CANARY log {0} {1}{2}" -f $r.start.ToString('HH:mm:ss'), $r.name, $(if ($r.start -ge $sinceT) { '  <-- after -Since' } else { '' }) + "  $($r.head)" }
"CANARY live godot.log last write {0}  {1}" -f $(if ($liveT) { $liveT.ToString('yyyy-MM-dd HH:mm:ss') }), (ReadHead $live 2)
$save = Join-Path $Folder 'save.json'
$sp = $null; $saveT = $null
if (Test-Path -LiteralPath $save) {
  $saveT = (Get-Item -LiteralPath $save).LastWriteTime
  try { $env0 = Get-Content -LiteralPath $save -Raw -Encoding UTF8 | ConvertFrom-Json; $sp = $env0.payload | ConvertFrom-Json } catch {}
}
$saveCv = if ($sp) { [string]$sp.content_version } else { '' }
$differs = $saveCv -and ($saveCv -ne $cv.crlf) -and ($saveCv -ne $cv.lf)
$canaryOk = $differs -and $saveT -and ($saveT -lt $dataTime)
"CANARY save.json mtime {0} content_version {1}; data {2} -> crlf {3} / lf {4}" -f $(if ($saveT) { $saveT.ToString('yyyy-MM-dd HH:mm:ss') }), $saveCv, $dataCommit, $cv.crlf, $cv.lf
$verdict = if ($newRuns.Count -gt 0) { "REAL-FOLDER RUNS since $($sinceT.ToString('HH:mm:ss')): $($newRuns.Count)" }
  elseif ($canaryOk) { "no real-folder run seen since $($sinceT.ToString('HH:mm:ss')), and no non-isolated Save boot of data $(($dataCommit -split ' ')[0]) since its commit" }
  else { "no rotated log since $($sinceT.ToString('HH:mm:ss')); save canary not usable (save content_version equals current data or save newer than the data commit)" }
"USERDATA_CANARY " + ([ordered]@{ checked_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); since = $sinceT.ToString('yyyy-MM-dd HH:mm:ss'); new_real_runs = $newRuns.Count;
  newest_rotated = $(if ($rot) { ($rot | Sort-Object start | Select-Object -Last 1).start.ToString('HH:mm:ss') }); save_mtime = $(if ($saveT) { $saveT.ToString('HH:mm:ss') });
  save_content_version = $saveCv; data_commit = $dataCommit; data_cv_crlf = $cv.crlf; data_cv_lf = $cv.lf; save_canary_valid = $canaryOk; verdict = $verdict } | ConvertTo-Json -Compress)
