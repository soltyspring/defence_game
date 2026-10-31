# 07-qa: read the launcher label(s) an Android APK actually ships (Q4: ko "빵집 기사단", en "Bakery Knights").
# Usage: .\tools\qa\check_apk_label.ps1 [-Apk build/android/defence-debug.apk] [-ExpectKo '빵집 기사단'] [-ExpectEn 'Bakery Knights']
# Uses the Android SDK aapt2 "dump badging" (no device needed). Prints the default label, every localized
# label, the package id, and PASS/FAIL per expectation. Exit 0 = both expectations met, 1 = mismatch,
# 3 = APK or aapt2 missing. A desktop read of the APK, not an on-device launcher check. Owner: 07-qa.
param(
    [string]$Apk = 'build/android/defence-debug.apk',
    [string]$ExpectKo = '빵집 기사단',
    [string]$ExpectEn = 'Bakery Knights'
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$apkPath = if ([IO.Path]::IsPathRooted($Apk)) { $Apk } else { Join-Path $Root $Apk }
if (-not (Test-Path $apkPath)) { Write-Host "APK not found: $apkPath"; exit 3 }
$bt = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
$aapt = Get-ChildItem $bt -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'aapt2.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $aapt) { Write-Host 'aapt2.exe not found under Android SDK build-tools'; exit 3 }
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'
$lines = & $aapt dump badging $apkPath 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = 'Stop'
$pkg = ($lines | Where-Object { $_ -like 'package:*' } | Select-Object -First 1)
$default = ($lines | Where-Object { $_ -match "^application-label:'(.*)'$" } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
$loc = @{}
foreach ($l in $lines) { if ($l -match "^application-label-([A-Za-z\-]+):'(.*)'$") { $loc[$Matches[1]] = $Matches[2] } }
$info = Get-Item $apkPath
Write-Host "apk=$($info.FullName) bytes=$($info.Length) modified=$($info.LastWriteTime.ToString('s'))"
Write-Host "aapt2=$aapt"
Write-Host "$pkg"
Write-Host "label(default)='$default'"
$others = @($loc.Keys | Where-Object { $loc[$_] -ne $default })
Write-Host "localized labels: $($loc.Count) locales; differing from default: $(($others | Sort-Object | ForEach-Object { "$_='$($loc[$_])'" }) -join ', ')"
$ko = if ($loc.ContainsKey('ko')) { $loc['ko'] } else { $default }
$en = if ($loc.ContainsKey('en')) { $loc['en'] } else { $default }
$okKo = $ko -eq $ExpectKo
$okEn = $en -eq $ExpectEn
Write-Host ("ko: shown='{0}' expected='{1}' -> {2}" -f $ko, $ExpectKo, $(if ($okKo) { 'PASS' } else { 'FAIL' }))
Write-Host ("en: shown='{0}' expected='{1}' -> {2}" -f $en, $ExpectEn, $(if ($okEn) { 'PASS' } else { 'FAIL' }))
if ($okKo -and $okEn) { exit 0 } else { exit 1 }
