# heavy_run_scope_test.ps1 (10-research-systems): checks a heavy_run.ps1 implementation for caller-scope hazards.
# It copies -Target into a private temp folder, swaps the mutex name for a test name and runs four tiny blocks
# (no Godot, a few seconds). The real lock and the real coordination/.runtime/heavy_run.log are never used.
# Usage: pwsh -NoProfile -File docs/research/systems/probes/heavy_run_scope_test.ps1 [-Target coordination/heavy_run.ps1]
# Output: "HRT <hazard> PASS|FAIL <detail>" lines and "HEAVY_RUN_SCOPE_TEST <json>". Exit 0.
#   H1 log_shadow   a caller's $log inside the block must be the caller's value (else Tee/Set-Content hit the shared log)
#   H2 eap_leak     the block must see the caller's $ErrorActionPreference, and a non-terminating error must not abort it
#   H3 end_on_error a block that throws must still produce an END line
#   H4 stale_exit   a block with only cmdlets must not inherit an old native exit code
param([string]$Target = 'coordination/heavy_run.ps1')
$ErrorActionPreference = 'Continue'
$src = (Resolve-Path $Target).Path
$tmp = Join-Path $env:TEMP ("hrt_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force (Join-Path $tmp 'coordination\.runtime') | Out-Null
$copy = Join-Path $tmp 'coordination\heavy_run_under_test.ps1'
$text = [IO.File]::ReadAllText($src)
$mutexes = [regex]::Matches($text, "'Local\\[^']+'")
if ($mutexes.Count -ne 1) { "HRT setup FAIL expected one 'Local\...' mutex name, found $($mutexes.Count)"; exit 0 }
[IO.File]::WriteAllText($copy, $text.Replace($mutexes[0].Value, "'Local\hrt_$([guid]::NewGuid().ToString('N').Substring(0,8))'"), (New-Object Text.UTF8Encoding($false)))
$hl = Join-Path $tmp 'coordination\.runtime\heavy_run.log'
Set-Content -LiteralPath $hl -Value 'PRIOR LINE' -Encoding UTF8
$caller = Join-Path $tmp 'caller_out.txt'
function Run($cmd) { (pwsh -NoProfile -Command $cmd 2>&1 | ForEach-Object { "$_" }) -join ' / ' }
$res = [ordered]@{}
# H1
$o1 = Run "`$ErrorActionPreference='Continue'; `$log='$caller'; & '$copy' -Label 'H1' -Script { 'x' | Set-Content -LiteralPath `$log; `$global:LASTEXITCODE = 0 }"
$h1 = (Test-Path $caller) -and ((Get-Content -LiteralPath $hl) -contains 'PRIOR LINE')
$res.log_shadow = $h1; "HRT H1 log_shadow $(if ($h1) {'PASS'} else {'FAIL'}) caller_file=$(Test-Path $caller) shared_log_prior_kept=$((Get-Content -LiteralPath $hl) -contains 'PRIOR LINE')"
Set-Content -LiteralPath $hl -Value 'PRIOR LINE' -Encoding UTF8
# H2
$o2 = Run "`$ErrorActionPreference='Continue'; & '$copy' -Label 'H2' -Script { 'EAP=' + `$ErrorActionPreference; Get-Item 'Z:\hrt\no\such\file'; 'REACHED'; `$global:LASTEXITCODE = 0 }"
$h2 = ($o2 -match 'EAP=Continue') -and ($o2 -match 'REACHED')
$res.eap_leak = $h2; "HRT H2 eap_leak $(if ($h2) {'PASS'} else {'FAIL'}) $($o2 -replace '\s+', ' ')"
# H3
$o3 = Run "`$ErrorActionPreference='Continue'; try { & '$copy' -Label 'H3' -Script { throw 'boom' } } catch { 'caught' }"
$h3 = @(Get-Content -LiteralPath $hl | Where-Object { $_ -match ' END H3 ' }).Count -eq 1
$res.end_on_error = $h3; "HRT H3 end_on_error $(if ($h3) {'PASS'} else {'FAIL'}) end_lines=$(@(Get-Content -LiteralPath $hl | Where-Object { $_ -match ' END H3 ' }).Count)"
# H4
$o4 = Run "`$ErrorActionPreference='Continue'; cmd /c exit 3; & '$copy' -Label 'H4' -Script { Get-Date | Out-Null }; 'code=' + `$LASTEXITCODE"
$endH4 = Get-Content -LiteralPath $hl | Where-Object { $_ -match ' END H4 ' } | Select-Object -First 1
$h4 = ($o4 -match 'code=0') -and ($endH4 -match 'exit=0')
$res.stale_exit = $h4; "HRT H4 stale_exit $(if ($h4) {'PASS'} else {'FAIL'}) $o4 | $endH4"
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
"HEAVY_RUN_SCOPE_TEST " + ([ordered]@{ target = $Target; target_sha256 = (Get-FileHash $src).Hash.Substring(0, 16); pass = @($res.Values | Where-Object { $_ }).Count; checked = $res.Count; results = $res } | ConvertTo-Json -Compress)
