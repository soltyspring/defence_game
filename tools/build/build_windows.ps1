# Build a Windows x64 preview from a committed Git ref, without using gameplay WIP.
# Run inside coordination/heavy_run_detached.ps1 on this shared development PC.
param(
    [string]$Ref = 'HEAD',
    [string]$Godot = '',
    [string]$OutDir = '',
    [string]$PresetFile = ''
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
Set-Location -LiteralPath $root
if (-not $Godot) { $Godot = Join-Path $root 'tools/engine/Godot_v4.7.2-stable_win64_console.exe' }
$Godot = (Resolve-Path -LiteralPath $Godot).Path
if (-not $OutDir) { $OutDir = Join-Path $root ('build/windows/' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$OutDir = [IO.Path]::GetFullPath($OutDir)
if (Test-Path -LiteralPath $OutDir) { throw 'Choose a new output directory; existing builds are preserved.' }
New-Item -ItemType Directory -Path $OutDir | Out-Null
$sha = (& git rev-parse --verify "$Ref^{commit}").Trim()
if ($LASTEXITCODE -ne 0) { throw 'Invalid Git ref.' }
$work = Join-Path $OutDir 'source'
$package = Join-Path $OutDir 'BakeryKnights-Windows-x64'
New-Item -ItemType Directory -Path $work, $package | Out-Null
$archive = Join-Path $OutDir 'source.zip'
& git -c core.autocrlf=false -c core.eol=lf archive --format=zip -o $archive $sha project.godot export_presets.cfg icon.svg src scenes assets data tests
if ($LASTEXITCODE -ne 0) { throw 'Cannot archive source.' }
Expand-Archive -LiteralPath $archive -DestinationPath $work
Remove-Item -LiteralPath $archive
if ($PresetFile) { Copy-Item -LiteralPath (Resolve-Path -LiteralPath $PresetFile).Path -Destination (Join-Path $work 'export_presets.cfg') }
if ([IO.File]::ReadAllText((Join-Path $work 'export_presets.cfg')) -notmatch 'name="Windows Desktop"') { throw 'The selected ref has no Windows Desktop preset.' }
$previousAppData = $env:APPDATA
$env:APPDATA = Join-Path $OutDir 'appdata'
New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
try {
    $version = (& $Godot --version | Out-String).Trim()
    # Native stderr is captured as evidence; judge by exit status and log, not PS error records.
    $ErrorActionPreference = 'Continue'
    & $Godot --headless --language en --path $work --import *> (Join-Path $OutDir 'import.log')
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) { throw 'Import failed. See import.log.' }
    # Obtain notices from this exact engine rather than a different online version.
    $licenseProbe = Join-Path $work '_windows_license_probe.gd'
    $probe = @'
extends SceneTree
func _initialize():
    var output = OS.get_environment("BAKERY_LICENSE_DIR")
    var f = FileAccess.open(output.path_join("GODOT_LICENSE.txt"), FileAccess.WRITE)
    f.store_string(Engine.get_license_text())
    f.close()
    f = FileAccess.open(output.path_join("GODOT_THIRD_PARTY.json"), FileAccess.WRITE)
    f.store_string(JSON.stringify({"copyright": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "  "))
    f.close()
    quit()
'@
    $notices = Join-Path $package 'licenses'
    New-Item -ItemType Directory -Path $notices | Out-Null
    [IO.File]::WriteAllText($licenseProbe, $probe, [Text.UTF8Encoding]::new($false))
    $env:BAKERY_LICENSE_DIR = $notices.Replace('\','/')
    try {
        $ErrorActionPreference = 'Continue'
        & $Godot --headless --language en --path $work -s $licenseProbe *> (Join-Path $OutDir 'licenses.log')
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0) { throw 'License extraction failed.' }
    } finally {
        Remove-Item -LiteralPath $licenseProbe
        Remove-Item Env:BAKERY_LICENSE_DIR -ErrorAction SilentlyContinue
    }
    Copy-Item -LiteralPath (Join-Path $work 'assets/fonts/OFL-Galmuri.txt') -Destination $notices
    $exe = Join-Path $package 'BakeryKnights.exe'
    $ErrorActionPreference = 'Continue'
    & $Godot --headless --language en --path $work --export-release 'Windows Desktop' $exe *> (Join-Path $OutDir 'export.log')
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { throw 'Export failed. See export.log.' }
    # Test the shipped executable from a directory with no project source or PCK beside it.
    $menuLog = Join-Path $OutDir 'exe-menu.log'
    $battleLog = Join-Path $OutDir 'exe-battle.log'
    $run = Start-Process -FilePath $exe -ArgumentList @('--headless','--log-file',('"' + $menuLog + '"'),'--','--quit-after=2') -WorkingDirectory $package -WindowStyle Hidden -Wait -PassThru
    if ($run.ExitCode -ne 0) { throw 'Exported EXE menu smoke test failed.' }
    $run = Start-Process -FilePath $exe -ArgumentList @('--headless','--log-file',('"' + $battleLog + '"'),'--','--round=r01','--autoplay','--quit-after=6') -WorkingDirectory $package -WindowStyle Hidden -Wait -PassThru
    if ($run.ExitCode -ne 0) { throw 'Exported EXE battle smoke test failed.' }
    foreach ($name in 'exe-menu.log','exe-battle.log') {
        $text = [IO.File]::ReadAllText((Join-Path $OutDir $name))
        if ($text -match 'SCRIPT ERROR|Parse Error|ERROR:|Failed loading|not found') { throw "Runtime errors in $name" }
        if ($text -notmatch '\[App\] boot ok') { throw "No boot evidence in $name" }
    }
    $hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
    $info = [ordered]@{ source_commit=$sha; engine=$version; platform='Windows x86_64'; embedded_pck=$true; sha256=$hash; smoke_tests=@('menu','r01 autoplay'); signed=$false }
    $info | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $package 'BUILD_INFO.json') -Encoding utf8
    "$hash  BakeryKnights.exe" | Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Encoding ascii
    if (Test-Path -LiteralPath (Join-Path $root 'README.md')) { Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination (Join-Path $package 'README.md') }
    Compress-Archive -LiteralPath $package -DestinationPath (Join-Path $OutDir 'BakeryKnights-Windows-x64.zip')
    Write-Output ('WINDOWS_BUILD_OK ' + (Join-Path $OutDir 'BakeryKnights-Windows-x64.zip'))
    Write-Output ($info | ConvertTo-Json -Compress)
} finally { $env:APPDATA = $previousAppData }
