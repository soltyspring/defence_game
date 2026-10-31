# Android home-screen (launcher) label check against user decision Q4. Owner: 04-client.
# Q4 (2026-10-31 17:19 KST): launcher name ko "빵집 기사단", en "Bakery Knights". In-game and store titles
# keep the full working title; the final store name waits for the KIPRIS check.
#
# What it checks (no Godot run needed, so it is safe during quiet measurement windows):
#   1. Config (02-owned files, read only): export_presets.cfg `package/name` of every Android preset and
#      project.godot `config/name_localized`. Godot 4.7.2 _fix_resources (platform/android/export/
#      export_plugin.cpp) writes the default label from package/name (else config/name), and each
#      template locale label (godot-project-name-<lang>) from name_localized[lang], else the default.
#   2. Real APKs: `aapt2 dump badging` labels (application-label / application-label-<lang>).
# Verdict per item: OK (matches Q4) | WAITING (still the old "Lane Defence" everywhere, i.e. not changed
# or built before 02's change) | MISMATCH (anything else: typo, full title, missing ko, mixed) | NONE.
# Exit: 0 = all OK; 3 = nothing wrong but something is WAITING / no APK; 1 = any MISMATCH; 2 = tool error.
#
# Usage: .\tools\build\check_launcher_label.ps1 [-Apk a.apk,b.apk] [-Json out.json] [-SelfTest]
param(
    [string[]]$Apk = @(),
    [string]$Json = '',
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Expected = @{ ko = '빵집 기사단'; en = 'Bakery Knights' }
$Old = 'Lane Defence'

function Get-BadgingLabels([string]$Badging) {
    $out = [ordered]@{}
    foreach ($m in [regex]::Matches($Badging, "(?m)^application-label(?:-([A-Za-z0-9_-]+))?:'([^']*)'")) {
        $k = if ($m.Groups[1].Success -and $m.Groups[1].Value) { $m.Groups[1].Value } else { 'default' }
        $out[$k] = $m.Groups[2].Value
    }
    return $out
}

## labels: hashtable {default, ko, en, ...}. Missing ko/en fall back to default (Android resource fallback).
function Get-LabelVerdict($Labels) {
    if ($null -eq $Labels -or $Labels.Count -eq 0) { return 'NONE' }
    $allOld = $true
    foreach ($v in $Labels.Values) { if ($v -ne $Old) { $allOld = $false } }
    if ($allOld) { return 'WAITING' }
    foreach ($v in $Labels.Values) { if ($v -eq $Old) { return 'MISMATCH' } }   # mixed old/new (e.g. default still old)
    $ko = if ($Labels.Contains('ko')) { $Labels['ko'] } else { $Labels['default'] }
    $en = if ($Labels.Contains('en')) { $Labels['en'] } else { $Labels['default'] }
    if ($ko -ceq $Expected.ko -and $en -ceq $Expected.en) { return 'OK' }
    return 'MISMATCH'
}

## Effective labels the exporter will write, from the config files (mirrors _fix_resources).
function Get-ConfigLabels([string]$PresetText, [string]$ProjectText) {
    $results = @()
    $cfgName = ''
    if ($ProjectText -match '(?m)^config/name="((?:[^"\\]|\\.)*)"') { $cfgName = $Matches[1] }
    $loc = [ordered]@{}
    $mm = [regex]::Match($ProjectText, '(?ms)^config/name_localized=\{(.*?)\}')
    if ($mm.Success) {
        foreach ($p in [regex]::Matches($mm.Groups[1].Value, '"([A-Za-z_]+)"\s*:\s*"((?:[^"\\]|\\.)*)"')) { $loc[$p.Groups[1].Value] = $p.Groups[2].Value }
    }
    # Split presets: [preset.N] header, then options in [preset.N.options]
    $sections = [regex]::Split($PresetText, '(?m)^(?=\[preset\.\d+\]\s*$)') | Where-Object { $_ -match '^\[preset\.\d+\]' }
    foreach ($s in $sections) {
        if ($s -notmatch '(?m)^platform="Android"') { continue }
        $pname = if ($s -match '(?m)^name="([^"]*)"') { $Matches[1] } else { '?' }
        $pkg = if ($s -match '(?m)^package/name="((?:[^"\\]|\\.)*)"') { $Matches[1] } else { '' }
        $default = if ($pkg) { $pkg } elseif ($cfgName) { $cfgName } else { 'Godot Engine' }
        $labels = [ordered]@{ default = $default }
        foreach ($k in $loc.Keys) { $labels[$k] = $loc[$k] }
        $results += [pscustomobject]@{ preset = $pname; package_name = $pkg; config_name = $cfgName; name_localized = $loc; labels = $labels; verdict = (Get-LabelVerdict $labels) }
    }
    return ,$results
}

function Find-Aapt2 {
    $sdk = @($env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk", $env:ANDROID_HOME) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'build-tools')) } | Select-Object -First 1
    if (-not $sdk) { return '' }
    $c = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]($_.Name -replace '[^\d.].*$', '') } -Descending |
        ForEach-Object { Join-Path $_.FullName 'aapt2.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
    return [string]$c
}

function Get-ApkBadging([string]$Aapt2, [string]$ApkPath) {
    # aapt2 prints UTF-8; read it as UTF-8 so Korean labels survive. Its stderr warnings are not errors.
    $prev = [Console]::OutputEncoding
    $ErrorActionPreference = 'Continue'
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $txt = (& $Aapt2 dump badging $ApkPath 2>$null) -join "`n"
        if ($LASTEXITCODE -ne 0) { return $null }
        return $txt
    } finally { [Console]::OutputEncoding = $prev }
}

if ($SelfTest) {
    $fails = 0
    $cases = @(
        @("application-label:'Lane Defence'`napplication-label-ko:'Lane Defence'", 'WAITING'),
        @("application-label:'Bakery Knights'`napplication-label-ko:'빵집 기사단'`napplication-label-en:'Bakery Knights'", 'OK'),
        @("application-label:'Bakery Knights'`napplication-label-ko:'빵집 기사단'", 'OK'),
        @("application-label:'Bakery Knights'`napplication-label-en:'Bakery Knights'", 'MISMATCH'),
        @("application-label:'Bakery Knights: Mold Defense'`napplication-label-ko:'빵집 기사단: 곰팡이 디펜스'", 'MISMATCH'),
        @("application-label:'Bakery Knight'`napplication-label-ko:'빵집 기사단'", 'MISMATCH'),
        @("application-label:'bakery knights'`napplication-label-ko:'빵집 기사단'", 'MISMATCH'),
        @("application-label:'Lane Defence'`napplication-label-ko:'빵집 기사단'", 'MISMATCH'),
        @("", 'NONE')
    )
    foreach ($c in $cases) {
        $got = Get-LabelVerdict (Get-BadgingLabels $c[0])
        if ($got -ne $c[1]) { $fails++; Write-Output "FAIL badging '$($c[0] -replace "`n",' | ')' -> expected $($c[1]) got $got" }
    }
    $presetOld = "[preset.0]`nname=`"Android`"`nplatform=`"Android`"`n[preset.0.options]`npackage/name=`"Lane Defence`"`n"
    $presetNew = $presetOld -replace 'package/name="Lane Defence"', 'package/name="Bakery Knights"'
    $presetEmpty = $presetOld -replace 'package/name="Lane Defence"', 'package/name=""'
    $projOld = "[application]`nconfig/name=`"Lane Defence`"`n"
    $projLoc = "[application]`nconfig/name=`"Lane Defence`"`nconfig/name_localized={`n`"en`": `"Bakery Knights`",`n`"ko`": `"빵집 기사단`"`n}`n"
    $projLocKoOnly = "[application]`nconfig/name=`"Bakery Knights`"`nconfig/name_localized={`n`"ko`": `"빵집 기사단`"`n}`n"
    $cfgCases = @(
        @($presetOld, $projOld, 'WAITING', 'unchanged'),
        @($presetNew, $projLoc, 'OK', 'package/name + name_localized ko/en'),
        @($presetEmpty, $projLocKoOnly, 'OK', 'empty package/name falls back to config/name, ko from name_localized'),
        @($presetNew, $projOld, 'MISMATCH', 'no ko entry: ko launcher would show Bakery Knights'),
        @($presetOld, $projLoc, 'MISMATCH', 'default still Lane Defence (non-ko/en locales)')
    )
    foreach ($c in $cfgCases) {
        $r = Get-ConfigLabels $c[0] $c[1]
        $got = if ($r.Count -gt 0) { $r[0].verdict } else { 'NO_PRESET' }
        if ($got -ne $c[2]) { $fails++; Write-Output "FAIL config case '$($c[3])' -> expected $($c[2]) got $got" }
    }
    $total = $cases.Count + $cfgCases.Count
    Write-Output ("[launcher_label selftest] passed={0} failed={1}" -f ($total - $fails), $fails)
    exit ([int]($fails -gt 0))
}

try {
    $report = [ordered]@{ expected = $Expected; old = $Old; config = @(); apks = @(); aapt2 = '' }
    $presetText = Get-Content (Join-Path $Root 'export_presets.cfg') -Raw -Encoding UTF8
    $projText = Get-Content (Join-Path $Root 'project.godot') -Raw -Encoding UTF8
    $report.config = Get-ConfigLabels $presetText $projText
    foreach ($c in $report.config) {
        Write-Output ("config preset '{0}': package/name='{1}' config/name='{2}' name_localized={3} -> {4}" -f $c.preset, $c.package_name, $c.config_name, (($c.name_localized.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','), $c.verdict)
    }
    if (-not $Apk -or $Apk.Count -eq 0) {
        $Apk = @('build/qa/apk_head', 'build/android', 'build/release') | ForEach-Object { Join-Path $Root $_ } | Where-Object { Test-Path $_ } |
            ForEach-Object { Get-ChildItem $_ -Filter *.apk -File } | ForEach-Object { $_.FullName }
    }
    $aapt2 = Find-Aapt2
    $report.aapt2 = $aapt2
    foreach ($a in $Apk) {
        $item = [ordered]@{ apk = $a; built = (Get-Item $a).LastWriteTime.ToString('s'); labels = $null; verdict = 'NONE' }
        if ($aapt2) {
            $b = Get-ApkBadging $aapt2 $a
            if ($null -ne $b) { $item.labels = Get-BadgingLabels $b; $item.verdict = Get-LabelVerdict $item.labels }
        }
        $report.apks += [pscustomobject]$item
        $lab = if ($item.labels) {
            $l = $item.labels
            $distinct = ($l.Values | Group-Object | ForEach-Object { "'$($_.Name)'x$($_.Count)" }) -join ', '
            "default='$($l['default'])' ko='$($l['ko'])' en='$($l['en'])' ($($l.Count) labels: $distinct)"
        } else { '(no labels)' }
        Write-Output ("apk {0} (built {1}): {2} -> {3}" -f $a, $item.built, $lab, $item.verdict)
    }
    if (-not $aapt2) { Write-Output 'aapt2 not found: APK labels not read' }
    $all = @($report.config | ForEach-Object { $_.verdict }) + @($report.apks | ForEach-Object { $_.verdict })
    $overall = if ($all -contains 'MISMATCH') { 'MISMATCH' } elseif ($report.apks.Count -eq 0 -or $all -contains 'WAITING' -or $all -contains 'NONE') { 'WAITING' } else { 'OK' }
    $report.overall = $overall
    if ($Json) { $report | ConvertTo-Json -Depth 6 | Set-Content -Path $Json -Encoding UTF8 }
    Write-Output "LAUNCHER_LABEL $overall"
    exit $(switch ($overall) { 'OK' { 0 } 'WAITING' { 3 } default { 1 } })
} catch {
    Write-Output "LAUNCHER_LABEL ERROR $($_.Exception.Message)"
    exit 2
}
