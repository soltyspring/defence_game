# isolated_godot.ps1 (10-research-systems): run Godot so that user:// can NOT resolve to the real player folder.
# Why: Godot 4.7.2 on Windows builds user:// as %APPDATA%\Godot\app_userdata\<application/config/name>
# (platform/windows/os_windows.cpp get_config_path/get_data_path read the APPDATA environment variable;
# core/os/os.cpp OS::get_user_data_dir). Every run of this project with autoloads boots Save, whose _ready()
# loads user://save.json and, since R5 (7f2886c), rewrites it once after any data/** change.
# This wrapper gives the child process its own APPDATA, so user:// = <WorkDir>\appdata\Godot\app_userdata\<name>.
# It then PROVES isolation by finding the run's own Godot log under that private folder, and reports whether the
# real save.json / .bak hashes changed during the run (other workers may write them; the log proof is the signal).
#
# Usage, from a PowerShell session at the workspace root (call with & so the array binds):
#   & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @('--headless','--path','<proj>','-s','res://x.gd')
#   -WorkDir <dir>   private root (default: a new %TEMP%\godot_iso_<id>); -Keep keeps it; -TimeoutSec (default 600)
#   -SeedSave <file> copies a save.json into the private user dir before the run (to test boot behaviour)
# Output: child stdout/stderr, then one line "ISOLATED_GODOT <json>". Exit = child exit code, or 3 if the isolation
# proof is missing, or 124 on timeout.
param([string[]]$GodotArgs, [string]$WorkDir = '', [int]$TimeoutSec = 600, [switch]$Keep, [string]$SeedSave = '',
      [string]$ProjectName = 'Lane Defence')
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
$godot = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not $WorkDir) { $WorkDir = Join-Path $env:TEMP ("godot_iso_" + [guid]::NewGuid().ToString('N').Substring(0, 8)) }
$appdata = Join-Path $WorkDir 'appdata'
$userDir = Join-Path $appdata "Godot\app_userdata\$ProjectName"
New-Item -ItemType Directory -Force $userDir | Out-Null
if ($SeedSave) { Copy-Item $SeedSave (Join-Path $userDir 'save.json') -Force }
$real = Join-Path $env:APPDATA "Godot\app_userdata\$ProjectName"
function RealHashes { $h = [ordered]@{}; foreach ($f in 'save.json', 'save.json.bak') { $p = Join-Path $real $f; $h[$f] = if (Test-Path $p) { (Get-FileHash $p).Hash.Substring(0, 16) } else { '' } }; $h }
$before = RealHashes
$others = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' }).Count
$t0 = Get-Date
$psi = New-Object Diagnostics.ProcessStartInfo $godot
# Windows PowerShell 5.1 has no ArgumentList: quote each argument for CreateProcess
$psi.Arguments = ($GodotArgs | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' } else { $_ } }) -join ' '
$psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
$psi.EnvironmentVariables['APPDATA'] = $appdata
$p = [Diagnostics.Process]::Start($psi)
$so = $p.StandardOutput.ReadToEndAsync(); $se = $p.StandardError.ReadToEndAsync()
$code = 0
if (-not $p.WaitForExit($TimeoutSec * 1000)) { try { $p.Kill() } catch {}; $code = 124 } else { $code = $p.ExitCode }
$so.Result -split "\r?\n" | Where-Object { $_ -ne '' }; $se.Result -split "\r?\n" | Where-Object { $_ -ne '' }
# isolation proof: this run's own log file exists under the PRIVATE user dir (file logging is on by default)
$logs = @(Get-ChildItem -Recurse -Filter 'godot*.log' (Join-Path $appdata 'Godot\app_userdata') -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $t0.AddSeconds(-2) })
$after = RealHashes
$changed = ($before['save.json'] -ne $after['save.json']) -or ($before['save.json.bak'] -ne $after['save.json.bak'])
$isImport = $GodotArgs -contains '--import' -or $GodotArgs -contains '--export-pack' -or $GodotArgs -contains '--check-only'
$proof = ($logs.Count -gt 0) -or $isImport
$sum = [ordered]@{ exit = $code; private_user_dir = $userDir; isolation_proof_log = ($logs | Select-Object -First 1 | ForEach-Object { $_.FullName });
  isolated = $proof; real_save_changed_during_run = $changed; other_godot_processes_at_start = $others;
  note = if ($changed -and $others -gt 0) { 'real save changed while other Godot processes ran; with isolated=true this run could not have written it' } elseif ($changed) { 'real save changed and no other Godot process was seen: investigate' } else { '' } }
"ISOLATED_GODOT " + ($sum | ConvertTo-Json -Compress)
if (-not $Keep) { Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue }
if ($code -ne 0) { exit $code }
if (-not $proof) { exit 3 }
exit 0
