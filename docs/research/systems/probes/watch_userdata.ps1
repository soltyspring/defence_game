# watch_userdata.ps1 (10-research-systems): READ-ONLY regression watch of the real Godot user folder.
# It never deletes, moves or writes anything in the watched folder. It only lists files, hashes save.json/.bak,
# reads the first lines of NEW log files (shared read), and samples running Godot processes via CIM.
# Every -FileIntervalSec it snapshots the folder (path, size, mtime; SHA-256 for save.json/.bak) and diffs it with
# the previous snapshot. Every -ProcIntervalSec it records Godot processes (pid, start, command line, parent and
# grandparent command lines) so short runs between snapshots are still seen. Changed/new files are attributed to
# processes whose lifetime overlaps the file's mtime, with an owner guess from the command lines.
# Usage:  pwsh -NoProfile -File docs/research/systems/probes/watch_userdata.ps1 -DurationMin 30 -FileIntervalSec 300 -OutDir <dir>
# Rule since 2026-10-31 23:2x KST: a run longer than 1 minute is a "long measurement" and must go through
# coordination/heavy_run.ps1, which would block every other worker's Godot run for its whole length. For routine
# checks use the one-shot probes/userdata_canary.ps1 instead. Limit: processes are sampled every -ProcIntervalSec,
# so a run shorter than that can rotate the real logs without being sampled; a start-time match is then only a
# coincidence (the 19:29:02 case in §9.19 was withdrawn for this reason).
# Output: <OutDir>\watch_events.jsonl (one JSON per event) and <OutDir>\watch_summary.md; last line "WATCH_USERDATA <json>".
param([int]$DurationMin = 30, [int]$FileIntervalSec = 300, [int]$ProcIntervalSec = 5, [string]$OutDir = '',
      [string]$Folder = (Join-Path $env:APPDATA 'Godot\app_userdata\Lane Defence'))
$ErrorActionPreference = 'Continue'
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot "..\.local_inspect\watch_$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$ev = Join-Path $OutDir 'watch_events.jsonl'
function Emit($o) { Add-Content -Path $ev -Value ($o | ConvertTo-Json -Compress -Depth 6) -Encoding UTF8 }

function Owner([string]$cmd, [string]$parents = '') {
  # 1) the project path / script of the Godot command itself, 2) only then the launching scripts
  $rules = @(
    @('qa07|tests/acceptance|tools\\qa|tools/qa|run_acceptance', '07-qa'),
    @('svc06|tests/services|tests\\services|run_services', '06-services'),
    @('art03|defence_art|tools\\art|tools/art', '03-art'),
    @('defence_audio|tools\\audio|tools/audio', '05-audio'),
    @('bd02|it02|src/core/diag|src\\core\\diag|selftest\.gd|build_android', '02-engine'),
    @('perf08|tests/performance|tests\\performance|tools\\perf|tools/perf|perf_bench|c11_window|ab_retest|run_perf', '08-performance'),
    @('multi_seed_sim|paired_sim|low_budget_sim|confirm_sim|probe_sim|verify_files|docs\\design\\balance|docs/design/balance|sweep\.ps1|d\d\d_r\d\d', '01-director'),
    @('probe10|research\\systems|research/systems|godot_iso_', '10-research-systems'),
    @('ui04|tests/ui|tests\\ui|tests/integration|tests\\integration|run_tests\.ps1|flake_probe|verify_and_publish|visible_launch|capture_ui', '04-client'))
  foreach ($src in @($cmd, $parents)) {
    $t = $src.ToLower()
    foreach ($r in $rules) { if ($t -match $r[0]) { return $r[1] } }
  }
  return 'unknown'
}

function Snap {
  $m = @{}
  if (Test-Path -LiteralPath $Folder) {
    foreach ($f in Get-ChildItem -LiteralPath $Folder -Recurse -File -Force -ErrorAction SilentlyContinue) {
      $rel = $f.FullName.Substring($Folder.Length + 1).Replace('\', '/')
      $h = ''
      if ($rel -eq 'save.json' -or $rel -eq 'save.json.bak') {
        try { $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.Substring(0, 16) } catch { $h = 'LOCKED' }
      }
      $m[$rel] = [pscustomobject]@{ bytes = $f.Length; mtime = $f.LastWriteTime; hash = $h }
    }
  }
  return $m
}

function HeadLines([string]$path, [int]$n = 6) {
  try {
    $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite, Delete')
    $sr = New-Object IO.StreamReader($fs)
    $out = @(); while (-not $sr.EndOfStream -and $out.Count -lt $n) { $l = $sr.ReadLine().Trim(); if ($l) { $out += $l.Substring(0, [Math]::Min(200, $l.Length)) } }
    $sr.Close(); return $out
  } catch { return @("unreadable: $($_.Exception.Message)") }
}

$procs = @{}   # pid -> record
function SampleProcs {
  $now = Get-Date
  $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
  $byId = @{}; foreach ($p in $all) { $byId[[int]$p.ProcessId] = $p }
  foreach ($p in $all | Where-Object { $_.Name -like 'Godot*' }) {
    $id = [int]$p.ProcessId
    if (-not $procs.ContainsKey($id)) {
      $par = $byId[[int]$p.ParentProcessId]; $gp = if ($par) { $byId[[int]$par.ParentProcessId] } else { $null }
      $cl = [string]$p.CommandLine; $pcl = if ($par) { [string]$par.CommandLine } else { '' }; $gcl = if ($gp) { [string]$gp.CommandLine } else { '' }
      $procs[$id] = [pscustomobject]@{ pid = $id; name = $p.Name; start = $p.CreationDate; first_seen = $now; last_seen = $now;
        cmd = $cl; parent = $pcl; grandparent = $gcl; owner = (Owner $cl "$pcl $gcl") }
      Emit ([ordered]@{ type = 'proc'; time = $now.ToString('HH:mm:ss'); pid = $id; start = $p.CreationDate.ToString('HH:mm:ss');
        owner = $procs[$id].owner; cmd = $cl; parent = $pcl.Substring(0, [Math]::Min(300, $pcl.Length)); grandparent = $gcl.Substring(0, [Math]::Min(300, $gcl.Length)) })
    } else { $procs[$id].last_seen = $now }
  }
}

function Attribute([datetime]$t) {
  $c = @()
  foreach ($r in $procs.Values) {
    $s = if ($r.start) { [datetime]$r.start } else { $r.first_seen }
    if ($s.AddSeconds(-2) -le $t -and $r.last_seen.AddSeconds($ProcIntervalSec + 3) -ge $t) { $c += "$($r.owner) pid=$($r.pid)$(if ($realRuns.ContainsKey($r.pid)) { ' [real-dir run]' })" }
  }
  if ($c.Count -eq 0) { return 'unattributed (no Godot process seen overlapping; run shorter than sampling or not Godot)' }
  return ($c -join '; ')
}

# Godot's RotatedFileLogger renames user://logs/godot.log to godot<YYYY-MM-DDTHH.MM.SS>.log when a NEW run starts
# (the timestamp is that start time). So each new rotated name in the REAL logs folder = one run that used the real
# user dir. Matching it to a process whose CreationDate is within 2 s gives the exact run (and its command line).
$seenLogs = @{}; $realRuns = @{}; $runEvents = @(); $saveEvents = @()
function ScanLogs([bool]$init = $false) {
  $ld = Join-Path $Folder 'logs'
  foreach ($f in Get-ChildItem -LiteralPath $ld -Filter 'godot*.log' -File -ErrorAction SilentlyContinue) {
    if ($f.Name -eq 'godot.log' -or $seenLogs.ContainsKey($f.Name)) { continue }
    $seenLogs[$f.Name] = $true
    $m = [regex]::Match($f.Name, 'godot(\d{4}-\d{2}-\d{2})T(\d{2})\.(\d{2})\.(\d{2})')
    if (-not $m.Success) { continue }
    $T = [datetime]::ParseExact("$($m.Groups[1].Value) $($m.Groups[2].Value):$($m.Groups[3].Value):$($m.Groups[4].Value)", 'yyyy-MM-dd HH:mm:ss', $null)
    $match = @()
    foreach ($r in $procs.Values) {
      if ($r.start -and [Math]::Abs((([datetime]$r.start) - $T).TotalSeconds) -le 2) { $match += $r; $realRuns[$r.pid] = $T }
    }
    # at start-up only report rotated logs that belong to a run that is STILL running (long runs started earlier)
    if ($init -and $match.Count -eq 0) { continue }
    $o = [ordered]@{ type = 'real_dir_run'; time = (Get-Date).ToString('HH:mm:ss'); run_start = $T.ToString('HH:mm:ss'); rotated_log = $f.Name; pre_existing = $init;
      matched = @($match | ForEach-Object { [ordered]@{ pid = $_.pid; owner = $_.owner; cmd = $_.cmd.Substring(0, [Math]::Min(300, $_.cmd.Length)); parent = $_.parent.Substring(0, [Math]::Min(300, $_.parent.Length)) } });
      current_log_head = (HeadLines (Join-Path $ld 'godot.log') 4) }
    if ($match.Count -eq 0) { $o.note = 'no process with that start time was sampled (shorter than the sampling interval)' }
    Emit $o
    $script:runEvents += [pscustomobject]$o
  }
}
$lastSave = $null; $lastBak = $null
function CheckSave {
  foreach ($n in 'save.json', 'save.json.bak') {
    $p = Join-Path $Folder $n
    $mt = if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p -Force).LastWriteTime } else { $null }
    $prevMt = if ($n -eq 'save.json') { $script:lastSave } else { $script:lastBak }
    if ($null -ne $prevMt -and $mt -ne $prevMt) {
      $alive = @($procs.Values | Where-Object { $_.last_seen -ge (Get-Date).AddSeconds( - ($ProcIntervalSec + 3)) } | ForEach-Object { "$($_.owner) pid=$($_.pid)$(if ($realRuns.ContainsKey($_.pid)) { ' [real-dir run]' })" })
      $se = [ordered]@{ type = 'save_write'; time = (Get-Date).ToString('HH:mm:ss'); file = $n; mtime = $(if ($mt) { $mt.ToString('HH:mm:ss') }); godot_alive = $alive }
      Emit $se
      $script:saveEvents += [pscustomobject]$se
    }
    if ($n -eq 'save.json') { $script:lastSave = $mt } else { $script:lastBak = $mt }
  }
}

$t0 = Get-Date; $end = $t0.AddMinutes($DurationMin)
SampleProcs
ScanLogs $true
CheckSave
$prev = Snap
Emit ([ordered]@{ type = 'start'; time = $t0.ToString('HH:mm:ss'); folder = $Folder; files = $prev.Count;
  save = $(if ($prev['save.json']) { $prev['save.json'].hash } else { '' }); bak = $(if ($prev['save.json.bak']) { $prev['save.json.bak'].hash } else { '' }) })
$nextSnap = $t0.AddSeconds($FileIntervalSec)
$tick = 0; $changes = @()
while ((Get-Date) -lt $end) {
  Start-Sleep -Seconds $ProcIntervalSec
  SampleProcs
  ScanLogs
  CheckSave
  if ((Get-Date) -ge $nextSnap -or (Get-Date) -ge $end) {
    $tick++; $cur = Snap; $now = Get-Date
    foreach ($k in $cur.Keys) {
      $c = $cur[$k]; $p = $prev[$k]
      $kind = if (-not $p) { 'new' } elseif ($p.bytes -ne $c.bytes -or $p.mtime -ne $c.mtime -or $p.hash -ne $c.hash) { 'changed' } else { '' }
      if ($kind) {
        $e = [ordered]@{ type = 'file'; tick = $tick; time = $now.ToString('HH:mm:ss'); kind = $kind; path = $k; bytes = $c.bytes; mtime = $c.mtime.ToString('HH:mm:ss'); hash = $c.hash; attributed = (Attribute $c.mtime) }
        if ($k -like 'logs/godot*.log' -and $kind -eq 'new') { $e.head = HeadLines (Join-Path $Folder $k) }
        Emit $e; $changes += [pscustomobject]$e
      }
    }
    foreach ($k in $prev.Keys) { if (-not $cur.ContainsKey($k)) { $e = [ordered]@{ type = 'file'; tick = $tick; time = $now.ToString('HH:mm:ss'); kind = 'removed'; path = $k }; Emit $e; $changes += [pscustomobject]$e } }
    Emit ([ordered]@{ type = 'tick'; tick = $tick; time = $now.ToString('HH:mm:ss'); files = $cur.Count; changed = @($changes | Where-Object tick -eq $tick).Count;
      save = $(if ($cur['save.json']) { $cur['save.json'].hash } else { '' }); bak = $(if ($cur['save.json.bak']) { $cur['save.json.bak'].hash } else { '' }) })
    $prev = $cur; $nextSnap = $now.AddSeconds($FileIntervalSec)
  }
}
# summary
$md = @("# watch_userdata summary ($($t0.ToString('yyyy-MM-dd HH:mm:ss')) .. $((Get-Date).ToString('HH:mm:ss')))", "Folder: $Folder (read-only)", "",
  "## Runs that used the REAL user dir (new rotated log in logs/, matched to a process by start time ±2 s)",
  "| run start | owner guess | command line | parent | first log lines of the live godot.log |", "|---|---|---|---|---|")
foreach ($r in $runEvents) {
  if (@($r.matched).Count -eq 0) { $md += "| $($r.run_start) | (not sampled) | | | $((@($r.current_log_head) -join ' / ').Replace('|', '/')) |" }
  foreach ($m in @($r.matched)) { $md += "| $($r.run_start) | $($m.owner) | $($m.cmd.Replace('|', '/')) | $($m.parent.Replace('|', '/').Substring(0, [Math]::Min(160, $m.parent.Length))) | $((@($r.current_log_head) -join ' / ').Replace('|', '/')) |" }
}
$md += ""; $md += "## save.json / .bak writes (checked every $ProcIntervalSec s)"; $md += "| seen at | file | mtime | Godot processes alive ([real-dir run] = confirmed by log rotation) |"; $md += "|---|---|---|---|"
foreach ($s in $saveEvents) { $md += "| $($s.time) | $($s.file) | $($s.mtime) | $((@($s.godot_alive) -join '; ')) |" }
$md += ""; $md += "## Folder diffs every $FileIntervalSec s"
$md += "| tick | time | kind | file | mtime | save/bak hash | attributed to |"; $md += "|---|---|---|---|---|---|---|"
foreach ($c in $changes) { $md += "| $($c.tick) | $($c.time) | $($c.kind) | $($c.path) | $($c.mtime) | $($c.hash) | $($c.attributed) |" }
$md += ""; $md += "| pid | owner guess | start | last seen | command line |"; $md += "|---|---|---|---|---|"
foreach ($r in ($procs.Values | Sort-Object first_seen)) { $md += "| $($r.pid) | $($r.owner) | $(if ($r.start) { ([datetime]$r.start).ToString('HH:mm:ss') }) | $($r.last_seen.ToString('HH:mm:ss')) | $($r.cmd.Replace('|', '/').Substring(0, [Math]::Min(220, $r.cmd.Length))) |" }
[IO.File]::WriteAllLines((Join-Path $OutDir 'watch_summary.md'), $md, (New-Object Text.UTF8Encoding($false)))
"WATCH_USERDATA " + ([ordered]@{ out = $OutDir; ticks = $tick; file_events = $changes.Count; godot_processes_seen = $procs.Count;
  real_dir_runs = $runEvents.Count; real_dir_runs_by_owner = (@($runEvents | ForEach-Object { @($_.matched) | Select-Object -First 1 } | Group-Object owner | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ',');
  save_writes = @($saveEvents | Where-Object { $_.file -eq 'save.json' }).Count; bak_writes = @($saveEvents | Where-Object { $_.file -eq 'save.json.bak' }).Count } | ConvertTo-Json -Compress)
