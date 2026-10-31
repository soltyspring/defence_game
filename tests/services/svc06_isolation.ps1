# 06-services: keep every Godot run of the services tooling out of the real player folder. Owner: 06-services.
# Dot-source it:  . (Join-Path $PSScriptRoot 'svc06_isolation.ps1')
# Godot 4.7.2 on Windows resolves user:// to %APPDATA%\Godot\app_userdata\<application/config/name>
# (10-research-systems, DATA_AND_BACKEND_ANALYSIS.md §9.17; same approach as
# docs/research/systems/probes/isolated_godot.ps1). Every run with autoloads boots Save, which can rewrite
# the real user://save.json, and the suites write report files to user://. So the runner gives this
# PowerShell process (and every Godot child, incl. the m3/integration grandchildren) a private APPDATA.
#   Enter-SvcIsolation   -> sets $env:APPDATA to a private %TEMP% folder, hashes the real save first
#   Exit-SvcIsolation    -> restores APPDATA, proves isolation (a godot*.log of this run under the private
#                           folder and none new in the real folder), re-hashes the real save, prints one
#                           "SVC06_ISOLATION {json}" line, deletes the private folder unless -Keep
# The real folder is only READ (hashes and log timestamps). Returns $true when isolation is proven.
$script:SvcIso = $null

function Get-SvcRealUserDir { Join-Path $script:SvcIso.realAppdata 'Godot\app_userdata\Lane Defence' }

function Get-SvcRealHashes {
  $h = [ordered]@{}
  foreach ($f in 'save.json', 'save.json.bak') {
    $p = Join-Path (Get-SvcRealUserDir) $f
    $h[$f] = if (Test-Path $p) { (Get-FileHash $p).Hash.Substring(0, 16) } else { '' }
  }
  $h
}

function Enter-SvcIsolation([string]$Tag = 'run') {
  $realAppdata = $env:APPDATA
  $dir = Join-Path $env:TEMP ("svc06_iso_{0}_{1}" -f $Tag, [guid]::NewGuid().ToString('N').Substring(0, 8))
  $appdata = Join-Path $dir 'appdata'
  New-Item -ItemType Directory -Force (Join-Path $appdata 'Godot\app_userdata') | Out-Null
  $script:SvcIso = [ordered]@{ dir = $dir; appdata = $appdata; realAppdata = $realAppdata; t0 = Get-Date;
    others = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' }).Count }
  $script:SvcIso.before = Get-SvcRealHashes
  $env:APPDATA = $appdata
  Write-Host ("isolation: APPDATA for Godot = {0} (real folder only read)" -f $appdata)
}

function Exit-SvcIsolation([switch]$Keep) {
  if ($null -eq $script:SvcIso) { return $false }
  $env:APPDATA = $script:SvcIso.realAppdata
  $t0 = $script:SvcIso.t0.AddSeconds(-2)
  $priv = @(Get-ChildItem -Recurse -Filter 'godot*.log' (Join-Path $script:SvcIso.appdata 'Godot\app_userdata') -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $t0 })
  $realLogs = @(Get-ChildItem -Filter 'godot*.log' (Join-Path (Get-SvcRealUserDir) 'logs') -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $t0 })
  $realReports = @(Get-ChildItem -File (Get-SvcRealUserDir) -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'services_*' -and $_.LastWriteTime -ge $t0 })
  $after = Get-SvcRealHashes
  $changed = ($script:SvcIso.before['save.json'] -ne $after['save.json']) -or ($script:SvcIso.before['save.json.bak'] -ne $after['save.json.bak'])
  $proven = ($priv.Count -gt 0) -and ($realReports.Count -eq 0)
  $sum = [ordered]@{ isolated = $proven; private_logs = $priv.Count; new_services_reports_in_real_folder = $realReports.Count;
    new_godot_logs_in_real_folder_any_process = $realLogs.Count; real_save_changed_during_run = $changed;
    other_godot_processes_at_start = $script:SvcIso.others; private_dir = $script:SvcIso.dir;
    note = if ($changed -and $script:SvcIso.others -gt 0) { 'real save changed while other Godot processes ran; not attributable to this isolated run' } elseif ($changed) { 'real save changed with no other Godot process seen: investigate' } else { '' } }
  Write-Host ("SVC06_ISOLATION " + ($sum | ConvertTo-Json -Compress))
  if (-not $Keep) { Remove-Item -Recurse -Force $script:SvcIso.dir -ErrorAction SilentlyContinue }
  $script:SvcIso = $null
  return $proven
}

# Heavy-run rule (coordinator, after the 23:09 KST blue screen): Godot, Gradle/AAB/APK builds, emulator and
# long measurements run one at a time PC-wide, only inside
#   & .\coordination\heavy_run.ps1 -Label '06-<name>' -Script { pwsh -NoProfile -File tests/services/<runner>.ps1 }
# Assert-SvcHeavyLock refuses to start unless the machine-wide lock is held by one of this process's
# ancestors (the heavy_run.ps1 process that launched us). It never takes or releases the lock itself.
function Assert-SvcHeavyLock {
  $logPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'coordination\.runtime\heavy_run.log'
  $anc = @()
  $cur = $PID
  for ($i = 0; $i -lt 6 -and $cur; $i++) {
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$cur" -ErrorAction SilentlyContinue
    if (-not $p) { break }
    $cur = [int]$p.ParentProcessId
    $anc += $cur
  }
  $open = @{}
  if (Test-Path $logPath) {
    foreach ($line in Get-Content $logPath -Tail 400) {
      if ($line -match ' START (\S+) pid=(\d+)') { $open[[int]$Matches[2]] = $Matches[1] }
      elseif ($line -match ' END (\S+) pid=(\d+)') { $open.Remove([int]$Matches[2]) }
    }
  }
  foreach ($a in $anc) {
    if ($open.ContainsKey($a)) { Write-Host ("heavy_run lock held by ancestor pid {0} ({1})" -f $a, $open[$a]); return }
  }
  Write-Host 'REFUSED: run this only inside coordination\heavy_run.ps1 (one heavy run at a time PC-wide). Example:'
  Write-Host "  & .\coordination\heavy_run.ps1 -Label '06-services-suites' -Script { pwsh -NoProfile -File tests/services/run_services_suites.ps1 }"
  exit 4
}
