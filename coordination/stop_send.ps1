param([string]$Pid1,[string]$Role)
Set-Location 'Z:\.solty\dev\appintoss\defence'
$env:PYTHONIOENCODING='utf-8'
python coordination/console_send.py --pid $Pid1 --text-file coordination/prompts/all-stop.txt --result "coordination/.runtime/$Role-stop.json" | Out-Null
(Get-Content "coordination/.runtime/$Role-stop.json" -Raw | ConvertFrom-Json).delivery