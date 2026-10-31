# 01-director balance sweep helper. Runs multi_seed_sim.gd.txt once per override file and prints the summary table.
# Usage: .\docs\design\balance\sweep.ps1 -Overrides a.json,b.json -Rounds r02,r03 -Budgets none,low,opt -Seeds 1,2,3,4,5
param([string[]]$Overrides, [string]$Rounds = 'all', [string]$Budgets = 'none,low,opt', [string]$Seeds = '1,2,3,4,5', [string]$OutDir = $env:TEMP)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
Copy-Item (Join-Path $PSScriptRoot 'multi_seed_sim.gd.txt') (Join-Path $env:TEMP 'multi_seed_sim.gd') -Force
$godot = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
foreach ($ov in $Overrides) {
  $name = [IO.Path]::GetFileNameWithoutExtension($ov)
  $out = Join-Path $OutDir "sweep_$name.json"
  $p = Start-Process -FilePath $godot -ArgumentList '--headless','--path',$root,'-s',(Join-Path $env:TEMP 'multi_seed_sim.gd'),'--',$out,$ov,$Budgets,$Seeds,$Rounds,'45' -NoNewWindow -RedirectStandardOutput (Join-Path $env:TEMP "sweep_$name.log") -PassThru
  $p.WaitForExit(1500000) | Out-Null
  "=== $name"
  $env:PYTHONIOENCODING = 'utf-8'
  python (Join-Path $PSScriptRoot 'summarize_multi_seed.py') $out | Select-String -NotMatch 'warnings|^\|---|kind \| budget'
}
