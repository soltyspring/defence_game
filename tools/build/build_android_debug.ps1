# Android debug APK from a git ref, exported in an ISOLATED copy (own .godot cache), plus release-hygiene
# checks. Owner: 04-client. Does not touch the shared working tree's .godot/imported (02 import lock),
# does not start or touch any emulator, opens no window (headless).
# Usage: .\tools\build\build_android_debug.ps1 [-Ref HEAD] [-OutDir build\qa\apk_head] [-ProbeQ4Label]
# -ProbeQ4Label: in the scratch copy ONLY (never the shared tree), set the launcher-name keys proposed to
#   02 for user decision Q4 (package/name="Bakery Knights", config/name_localized ko/en) to prove the
#   exported label before 02 changes its files. Use a separate -OutDir so the HEAD evidence is kept.
# Output: <OutDir>\defence-debug.apk, apk_report.json, badging.txt, permissions.txt, signing.txt,
#         repo_secrets.txt, export.log, launcher_label.json. Exit 0 = export ok and no FAIL in checks.
param([string]$Ref = 'HEAD', [string]$OutDir = '', [switch]$ProbeQ4Label)
. "$PSScriptRoot\common.ps1"
$ErrorActionPreference = 'Stop'
Set-Location $Root
if (-not $OutDir) { $OutDir = Join-Path $Root 'build\qa\apk_head' }
$OutDir = [IO.Path]::GetFullPath($OutDir)
Assert-File $GodotConsole 'Godot console editor'
Assert-File (Join-Path $TemplatesDir 'android_debug.apk') 'Godot Android debug template'
if (-not $AndroidSdk -or -not $BuildTools) { throw 'MISSING: Android SDK / build-tools' }
$sha = (& git rev-parse --short $Ref).Trim()
$work = Join-Path $OutDir 'src'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }   # only our own scratch copy under build/
New-Item -ItemType Directory -Force $work | Out-Null
$zip = Join-Path $OutDir "src_$sha.zip"
& git archive --format=zip -o $zip $Ref
if ($LASTEXITCODE -ne 0) { throw 'git archive failed' }
Expand-Archive -Path $zip -DestinationPath $work -Force
Remove-Item $zip
if ($ProbeQ4Label) {
    $pp = Join-Path $work 'project.godot'
    $pt = [IO.File]::ReadAllText($pp)
    if ($pt -notmatch '(?m)^config/name=') { throw 'probe: config/name not found' }
    $pt = [regex]::Replace($pt, '(?m)^(config/name=.*)$', "`$1`nconfig/name_localized={`n`"en`": `"Bakery Knights`",`n`"ko`": `"빵집 기사단`"`n}", 1)
    [IO.File]::WriteAllText($pp, $pt, (New-Object System.Text.UTF8Encoding $false))
    $ep = Join-Path $work 'export_presets.cfg'
    $et = [IO.File]::ReadAllText($ep)
    if ($et -notmatch '(?m)^package/name=') { throw 'probe: package/name not found' }
    $et = [regex]::Replace($et, '(?m)^package/name=.*$', 'package/name="Bakery Knights"')
    [IO.File]::WriteAllText($ep, $et, (New-Object System.Text.UTF8Encoding $false))
    Write-Host 'probe: scratch copy uses package/name="Bakery Knights" + config/name_localized {en, ko}'
}
$apk = Join-Path $OutDir 'defence-debug.apk'
if (Test-Path $apk) { Remove-Item $apk }
$log = Join-Path $OutDir 'export.log'
$ErrorActionPreference = 'Continue'
$t0 = Get-Date
$prevAppData = Enter-IsolatedAppData (Join-Path $OutDir 'appdata')   # user:// isolation (10 v0.26)
& $GodotConsole --headless --path $work --import *> (Join-Path $OutDir 'import.log')
& $GodotConsole --headless --path $work --export-debug 'Android' $apk *> $log
Exit-IsolatedAppData $prevAppData
$exportSec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $apk)) { Write-Host "EXPORT FAILED, see $log"; Get-Content $log -Tail 20; exit 2 }
Write-Host "exported $apk from $Ref ($sha) in $exportSec s"
$ErrorActionPreference = 'Continue'   # aapt2/apksigner/git write warnings to stderr
$aapt2 = Join-Path $BuildTools.FullName 'aapt2.exe'
$apksigner = Join-Path $BuildTools.FullName 'apksigner.bat'
& $aapt2 dump badging $apk 2>&1 | Out-File -Encoding utf8 (Join-Path $OutDir 'badging.txt')
& $aapt2 dump permissions $apk 2>&1 | Out-File -Encoding utf8 (Join-Path $OutDir 'permissions.txt')
$env:JAVA_HOME = $JavaHome
& $apksigner verify --verbose --print-certs $apk 2>&1 | Out-File -Encoding utf8 (Join-Path $OutDir 'signing.txt')
# signing material must not be in the repository (tracked files at the exported ref)
$tracked = @(& git ls-tree -r --name-only $Ref)
$keyFiles = $tracked | Where-Object { $_ -match '\.(keystore|jks|p12|pfx)$|(^|/)\.env($|\.)|export_credentials\.cfg$' -and $_ -notmatch '\.env\.example$' }
$presetLines = (& git show "${Ref}:export_presets.cfg") | Where-Object { $_ -match '^keystore/|password' }
$filledKeys = $presetLines | Where-Object { $_ -notmatch '=""\s*$' }
$secretHits = @(& git grep -I -n -E '(storePassword|keyPassword|keystore_pass(word)?\s*=\s*"[^"]+")' $Ref -- . ':!tools/build/*' 2>$null)
$sec = @("ref=$Ref ($sha)", "tracked key/env files: $($keyFiles.Count)") + $keyFiles + @("export_presets keystore/password lines with a value: $($filledKeys.Count)") + $filledKeys + @("password-like literals in tracked files: $($secretHits.Count)") + $secretHits
$sec | Out-File -Encoding utf8 (Join-Path $OutDir 'repo_secrets.txt')
$py = Get-Command python -ErrorAction SilentlyContinue
$inspect = 1
if ($py) { & python (Join-Path $PSScriptRoot 'inspect_apk.py') $apk (Join-Path $OutDir 'apk_report.json'); $inspect = $LASTEXITCODE }
$perm = (Get-Content (Join-Path $OutDir 'permissions.txt')) -join "`n"
$badge = Get-Content (Join-Path $OutDir 'badging.txt') | Select-String '^(package|sdkVersion|targetSdkVersion|native-code|uses-permission)' | ForEach-Object Line
$signOk = (Get-Content (Join-Path $OutDir 'signing.txt')) -match 'Verified using v2 scheme \(APK Signature Scheme v2\): true'
Write-Host '--- badging'; $badge | ForEach-Object { Write-Host $_ }
Write-Host "--- signing v2 verified: $([bool]$signOk)"; (Get-Content (Join-Path $OutDir 'signing.txt') | Select-String 'Signer #1 certificate DN') | ForEach-Object { Write-Host $_.Line }
Write-Host "--- repo secrets: key files=$($keyFiles.Count) filled preset keystore lines=$($filledKeys.Count) password literals=$($secretHits.Count)"
# Q4 launcher label (report only; WAITING until 02 changes the name keys). Reads this APK only.
& (Join-Path $PSScriptRoot 'check_launcher_label.ps1') -Apk $apk -Json (Join-Path $OutDir 'launcher_label.json') | Select-String '^apk |^LAUNCHER_LABEL' | ForEach-Object { Write-Host $_.Line }
$bad = ($inspect -ne 0) -or (-not $signOk) -or $keyFiles.Count -gt 0 -or $filledKeys.Count -gt 0 -or $secretHits.Count -gt 0
Remove-Item -Recurse -Force $work   # scratch copy no longer needed; evidence files stay
exit ([int]$bad)
