# 07-qa: remove 07's own leftover test files from the REAL player user folder. Owner: 07-qa.
# Why: before the runner used a private APPDATA (10 v0.26/v0.28), 07 suites wrote user://qa07/** into
#   %APPDATA%\Godot\app_userdata\<config/name>\qa07. TP-13 left 19 x 52 MB quarantine copies there (996 MB).
# Scope: ONLY the qa07\ subtree. save.json, save.json.bak and every other folder are never touched.
# Safety: dry run by default (lists what would go). -Apply deletes only files that also exist with the same size in
#   the backup folder (10's read-only copy), and refuses if any qa07 file changed in the last 10 minutes.
# Usage: .\tools\qa\clean_real_qa07.ps1            # dry run
#        .\tools\qa\clean_real_qa07.ps1 -Apply     # delete (only after the user approved it)
param([switch]$Apply,
      [string]$Backup = (Join-Path $env:LOCALAPPDATA 'defence_userdata_backup\20261031-191353\Lane Defence\qa07'),
      [string]$ProjectName = 'Lane Defence')
$ErrorActionPreference = 'Stop'
$real = Join-Path $env:APPDATA "Godot\app_userdata\$ProjectName\qa07"
if (-not (Test-Path $real)) { Write-Host "nothing to clean: $real does not exist"; exit 0 }
$files = @(Get-ChildItem $real -Recurse -File)
$bytes = [long](($files | Measure-Object Length -Sum).Sum)
$noBackup = @($files | Where-Object {
    $b = Join-Path $Backup $_.FullName.Substring($real.Length)
    -not (Test-Path $b) -or (Get-Item $b).Length -ne $_.Length })
$recent = @($files | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-10) })
Write-Host ("real qa07: {0} files, {1:N0} bytes; without matching backup: {2}; changed in last 10 min: {3}" -f $files.Count, $bytes, $noBackup.Count, $recent.Count)
$files | Group-Object { $_.Directory.FullName.Substring($real.Length) } | ForEach-Object {
    Write-Host ("  {0,-12} {1,4} files {2,15:N0} B" -f ($(if ($_.Name) { $_.Name } else { '\' })), $_.Count, [long](($_.Group | Measure-Object Length -Sum).Sum)) }
if (-not $Apply) { Write-Host 'DRY RUN: nothing deleted. Re-run with -Apply after approval.'; exit 0 }
if ($recent.Count -gt 0) { Write-Host 'REFUSED: qa07 files changed in the last 10 minutes (a run may be writing there).'; exit 2 }
if ($noBackup.Count -gt 0) { Write-Host 'REFUSED: some files have no same-size copy in the backup:'; $noBackup | ForEach-Object { Write-Host "  $($_.FullName)" }; exit 2 }
$logDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'build\qa07'
New-Item -ItemType Directory -Force $logDir | Out-Null
$log = Join-Path $logDir ("clean_real_qa07_{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$files | ForEach-Object { "{0}`t{1}`t{2:s}" -f $_.FullName, $_.Length, $_.LastWriteTime } | Set-Content $log -Encoding utf8
foreach ($f in $files) { Remove-Item -LiteralPath $f.FullName -Force }
Get-ChildItem $real -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object { if (-not (Get-ChildItem $_.FullName -Force)) { Remove-Item -LiteralPath $_.FullName -Force } }
if (-not (Get-ChildItem $real -Force)) { Remove-Item -LiteralPath $real -Force }
Write-Host ("DELETED {0} files ({1:N0} bytes) from {2}; list: {3}" -f $files.Count, $bytes, $real, $log)
