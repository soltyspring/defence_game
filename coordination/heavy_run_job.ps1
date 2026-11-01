<#
Internal: started by coordination/heavy_run_detached.ps1 in a detached hidden pwsh. Takes the PC-wide lock through
heavy_run.ps1, runs one job file inside it, writes all output to -OutFile and ends it with HEAVY_JOB_DONE exit=<n>.
Do not call this directly from an agent tool call.
#>
param(
  [Parameter(Mandatory)][string]$Label,
  [Parameter(Mandatory)][string]$ScriptFile,
  [Parameter(Mandatory)][string]$OutFile,
  [int]$WaitMinutes = 180,
  [Parameter(Mandatory)][string]$HeavyRunPath
)
$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
('HEAVY_JOB_QUEUED {0:s} label={1} pid={2} script={3}' -f (Get-Date), $Label, $PID, $ScriptFile) |
  Out-File -LiteralPath $OutFile -Encoding utf8
$hrjCode = 1
$hrjFile = $ScriptFile
try {
  & $HeavyRunPath -Label $Label -WaitMinutes $WaitMinutes -Script ({ & $hrjFile }.GetNewClosure()) *>&1 |
    Out-File -LiteralPath $OutFile -Append -Encoding utf8
  $hrjCode = [int]$LASTEXITCODE
} catch {
  ('HEAVY_JOB_ERROR {0}' -f $_) | Out-File -LiteralPath $OutFile -Append -Encoding utf8
}
('HEAVY_JOB_DONE exit={0} at {1:s}' -f $hrjCode, (Get-Date)) | Out-File -LiteralPath $OutFile -Append -Encoding utf8
exit $hrjCode
