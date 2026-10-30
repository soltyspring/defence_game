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
