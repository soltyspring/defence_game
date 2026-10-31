param([Parameter(Mandatory)][string]$Role,[Parameter(Mandatory)][string]$Session,[Parameter(Mandatory)][string]$TextFile)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath 'Z:\.solty\dev\appintoss\defence'
$env:PYTHONIOENCODING='utf-8'
$u=Get-Content coordination/.runtime/quota/usage.json -Raw | ConvertFrom-Json
if((Test-Path coordination/.runtime/quota/triggered.json) -or ($u.used/$u.cap) -ge 0.97){throw 'QUOTA_HOLD'}
$p=@(Get-CimInstance Win32_Process -Filter "Name='kiro-cli.exe'" | Where-Object {$_.CommandLine -match [regex]::Escape($Session)})
if($p.Count -ne 1){throw "PROCESS_COUNT=$($p.Count)"}
$before=(python coordination/console_read.py $p[0].ProcessId) -join ' '
if($before -notmatch 'ask a question or describe a task'){throw 'PROMPT_NOT_EMPTY_OR_BUSY'}
$log="$env:USERPROFILE\.kiro\sessions\48374e8b85ea0326\$Session\messages.jsonl"
$count=(Get-Content $log).Count
python coordination/console_send.py --pid $p[0].ProcessId --text-file $TextFile --result "coordination/.runtime/$Role-delivery.json" | Out-Null
Start-Sleep -Seconds 8
$after=(python coordination/console_read.py $p[0].ProcessId) -join ' '
$new=@(Get-Content $log | Select-Object -Skip $count | ForEach-Object {($_|ConvertFrom-Json).payload.type})
$ok=($after -match 'Kiro is working') -and ($new -contains 'user') -and ($new -contains 'turn_start')
$status=if($ok){'START_CONFIRMED'}else{'START_UNCONFIRMED'}
$line="$(Get-Date -Format s) $Role PID=$($p[0].ProcessId) session=$Session $status new=$($new -join ',')"
Add-Content coordination/COORDINATOR_STATE.md -Value $line
$line