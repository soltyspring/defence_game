# Shared paths for 04-client build/QA scripts. Dot-source: . "$PSScriptRoot\common.ps1"
# Never put credentials here. Signing secrets come only from environment variables.
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$GodotConsole = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
$GodotGui = Join-Path $Root 'tools\engine\Godot_v4.7.2-stable_win64.exe'
$GodotVersionDir = '4.7.2.stable'
$TemplatesDir = Join-Path $Root "tools\engine\editor_data\export_templates\$GodotVersionDir"
# ANDROID_HOME on this machine points at the AVD folder, so the SDK is resolved explicitly.
$AndroidSdk = @($env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk')) |
    Where-Object { $_ -and (Test-Path (Join-Path $_ 'platform-tools\adb.exe')) } | Select-Object -First 1
$Adb = if ($AndroidSdk) { Join-Path $AndroidSdk 'platform-tools\adb.exe' } else { $null }
$BuildTools = if ($AndroidSdk) { Get-ChildItem (Join-Path $AndroidSdk 'build-tools') -Directory | Sort-Object { [version]($_.Name -replace '[^0-9.]','') } | Select-Object -Last 1 } else { $null }
$JavaHome = @($env:JAVA_HOME, 'C:\Program Files\Java\jdk-25.0.2') | Where-Object { $_ -and (Test-Path (Join-Path $_ 'bin\java.exe')) } | Select-Object -First 1

function Assert-File([string]$Path, [string]$What) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING: $What ($Path)" }
}

# ---- user:// isolation (10 d1cff3b, v0.26/v0.28) ----
# Godot 4.7.2 on Windows resolves user:// as %APPDATA%\Godot\app_userdata\<application/config/name>. Every run with
# autoloads boots Save, which reads and can rewrite the REAL player save.json. 04 runners therefore give each Godot
# child a private APPDATA (10's isolated_godot.ps1 method) and prove it by finding the run's own Godot log there.
$RealAppData = if ($env:UI04_REAL_APPDATA) { $env:UI04_REAL_APPDATA } else { $env:APPDATA }
$env:UI04_REAL_APPDATA = $RealAppData                 # nested 04 scripts keep the true value for the proof
$ProjectName = 'Lane Defence'
$cfgName = Select-String -Path (Join-Path $Root 'project.godot') -Pattern '^config/name="(.*)"' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cfgName) { $ProjectName = $cfgName.Matches[0].Groups[1].Value }

## Sets a private APPDATA for every Godot process started from now on; returns the previous value for Exit-IsolatedAppData.
function Enter-IsolatedAppData([string]$Dir) {
    New-Item -ItemType Directory -Force $Dir | Out-Null
    $prev = $env:APPDATA
    $env:APPDATA = (Resolve-Path $Dir).Path
    return $prev
}
function Exit-IsolatedAppData([string]$Prev) { $env:APPDATA = $Prev }

## Proof after a run: the run left a trace under the PRIVATE user folder — its own Godot file log (headless runs),
## any file written since $Since, or the user folder itself created since $Since (runs with --log-file write no
## user://logs). Also reports new logs in the REAL folder since $Since (other workers may write there).
function Get-IsolationProof([string]$Dir, [datetime]$Since) {
    $ud = Join-Path $Dir "Godot\app_userdata\$ProjectName"
    $own = Join-Path $ud 'logs'
    $real = Join-Path $RealAppData "Godot\app_userdata\$ProjectName\logs"
    $ownN = @(Get-ChildItem $own -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $Since }).Count
    $newFiles = @(Get-ChildItem $ud -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $Since }).Count
    $created = (Test-Path $ud) -and ((Get-Item $ud).CreationTime -ge $Since.AddSeconds(-1))
    $realN = @(Get-ChildItem $real -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $Since }).Count
    return [pscustomobject]@{ isolated = ($ownN -gt 0 -or $newFiles -gt 0 -or $created); own_logs = $ownN; own_new_files = $newFiles; user_dir_created = $created; real_new_logs_any_process = $realN; dir = $Dir }
}
