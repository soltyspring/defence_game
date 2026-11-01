param([Parameter(Mandatory)][string]$Role,[Parameter(Mandatory)][string]$Session,[Parameter(Mandatory)][string]$TextFile)
# Quota-stop delivery only. Works on an idle prompt or a working session (Kiro 'Type to steer').
# Refuses unless the 97% trigger exists or usage >= 97. Never sends when a draft is typed.
$ErrorActionPreference='Stop'
Set-Location -LiteralPath 'Z:\.solty\dev\appintoss\defence'
$env:PYTHONIOENCODING='utf-8'
$u=Get-Content coordination/.runtime/quota/usage.json -Raw | ConvertFrom-Json
if(-not ((Test-Path coordination/.runtime/quota/triggered.json) -or ($u.used/$u.cap) -ge 0.97)){throw 'NOT_AT_QUOTA_STOP'}
$p=@(Get-CimInstance Win32_Process -Filter "Name='kiro-cli.exe'" | Where-Object {$_.CommandLine -match [regex]::Escape($Session)})
if($p.Count -eq 0){
  # 11/12 were started without --resume-id: resolve via the session .lock pid (bun.exe) whose parent is the kiro-cli.exe window process.
  $lockFile="$env:USERPROFILE\.kiro\sessions\48374e8b85ea0326\$Session\.lock"
  if(Test-Path $lockFile){
    $lp=(Get-Content $lockFile -Raw | ConvertFrom-Json).pid
    $child=Get-CimInstance Win32_Process -Filter "ProcessId=$lp"
    if($child){ $p=@(Get-CimInstance Win32_Process -Filter "ProcessId=$($child.ParentProcessId) AND Name='kiro-cli.exe'") }
  }
}
if($p.Count -ne 1){throw "PROCESS_COUNT=$($p.Count)"}
$lines=@(python coordination/console_read.py $p[0].ProcessId)
$prompt=($lines | Where-Object { $_ -match '^\s*\u203a' } | Select-Object -Last 1)
if(-not $prompt){throw 'PROMPT_LINE_NOT_FOUND'}
$mode=if($prompt -match 'ask a question or describe a task'){'IDLE'}elseif($prompt -match '\u203a\s+Kiro is working'){'WORKING'}else{'DRAFT_OR_UNKNOWN'}
if($mode -eq 'DRAFT_OR_UNKNOWN'){throw "NOT_SENT prompt=$($prompt.Trim())"}
$log="$env:USERPROFILE\.kiro\sessions\48374e8b85ea0326\$Session\messages.jsonl"
$count=(Get-Content $log).Count
python coordination/console_send.py --pid $p[0].ProcessId --text-file $TextFile --result "coordination/.runtime/$Role-quota-delivery.json" --checkpoint-only | Out-Null
$ok=$false
for($i=0;$i -lt 8 -and -not $ok;$i++){
  Start-Sleep -Seconds 4
  $new=@(Get-Content $log | Select-Object -Skip $count | ForEach-Object {($_|ConvertFrom-Json).payload.type})
  $ok=($new -contains 'user')
}
$status=if($ok){'QUOTA_STOP_DELIVERED'}else{'QUOTA_STOP_UNCONFIRMED'}
$line="$(Get-Date -Format s) $Role PID=$($p[0].ProcessId) session=$Session mode=$mode $status new=$($new -join ',')"
Add-Content coordination/COORDINATOR_STATE.md -Value $line -Encoding UTF8
$line
