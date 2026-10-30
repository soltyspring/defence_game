param(
 [Parameter(Mandatory=$true)][ValidateSet('01-director','02-engine','03-art','04-client','05-audio','06-services','07-qa','08-performance','09-research-product','10-research-systems')][string]$Role,
 [Parameter(Mandatory=$true)][ValidateSet('Feat','Fix','Design','!BREAKING CHANGE','!HOTFIX','Style','Refactor','Comment','Docs','Test','Chore','Rename','Remove')][string]$Type,
 [Parameter(Mandatory=$true)][string]$Subject,
 [Parameter(Mandatory=$true)][string[]]$Paths
)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if ([string]::IsNullOrWhiteSpace($Subject) -or $Subject.Contains("`n") -or $Subject.Contains("`r")) { throw 'Use a single nonempty subject line.' }
$rules = @{
 '01-director'=@('docs/design/','data/');
 '02-engine'=@('src/core/','src/gameplay/','scenes/gameplay/','docs/contracts/','docs/architecture/');
 '03-art'=@('assets/','tools/art/','docs/art/');
 '04-client'=@('src/ui/','scenes/ui/','tools/build/','tests/','docs/qa/','docs/mobile/');
 '05-audio'=@('assets/audio/','src/audio/','tools/audio/','docs/audio/');
 '06-services'=@('src/services/','docs/services/','tests/services/');
 '07-qa'=@('tests/acceptance/','tools/qa/','docs/verification/');
 '08-performance'=@('tools/perf/','tests/performance/','docs/performance/');
 '09-research-product'=@('docs/research/product/');
 '10-research-systems'=@('docs/research/systems/')
}
$allowedRoot=@('project.godot','export_presets.cfg','.gitignore','icon.svg','README.md')
$clean=@()
foreach($p in $Paths){
 $p=$p.Replace('\','/').Trim()
 if($p -match '(^/|^[A-Za-z]:|(^|/)\.\.(/|$)|[*?\[\]]|^:)' -or $p -eq '.' -or $p.EndsWith('/')){throw "Explicit relative file path required: $p"}
 if(Test-Path -LiteralPath $p -PathType Container){throw "Specify files, not directories: $p"}
 $ok=$false
 foreach($prefix in $rules[$Role]){if($p.StartsWith($prefix,[StringComparison]::Ordinal)){$ok=$true}}
 if($Role -eq '02-engine' -and $allowedRoot -contains $p){$ok=$true}
 if($p -eq "coordination/status/$Role.md" -or $p -eq "coordination/handoffs/$Role.md" -or $p.StartsWith("coordination/requests/$Role-to-")){$ok=$true}
 if($Role -eq '01-director' -and $p -eq 'coordination/requests/USER_QUESTION.md'){$ok=$true}
 if($Role -eq '03-art' -and $p.StartsWith('assets/audio/')){$ok=$false}
 if($Role -eq '04-client' -and ($p.StartsWith('tests/services/') -or $p.StartsWith('tests/acceptance/') -or $p.StartsWith('tests/performance/'))){$ok=$false}
 if(!$ok){throw "Path is outside $Role ownership: $p"}
 if($p -match '(^|/)(\.env($|\.)|[^/]+\.(keystore|jks|p12|pfx|apk|aab|exe|zip|tpz)$)' -and $p -notmatch '\.env\.example$'){throw "Excluded secret/build artifact: $p"}
 $clean+=$p
}
$lock=$null
try {
 $until=(Get-Date).AddSeconds(45)
 while($null -eq $lock){
  try{$lock=[IO.File]::Open((Join-Path (Get-Location) '.git/task-publish.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
  catch [IO.IOException]{if((Get-Date) -gt $until){throw 'Git publisher busy. Retry later; do not bypass lock.'};Start-Sleep -Milliseconds 500}
 }
 $branch=(& git branch --show-current).Trim(); if($LASTEXITCODE -ne 0 -or $branch -ne 'main'){throw 'Expected main branch.'}
 $staged=@(& git diff --cached --name-only); if($LASTEXITCODE -ne 0 -or $staged.Count -gt 0){throw 'Index is not empty. Ask coordinator; do not modify other staged files.'}
 & git fetch origin main; if($LASTEXITCODE -ne 0){throw 'Fetch failed; check authentication/network.'}
 & git merge-base --is-ancestor origin/main HEAD; if($LASTEXITCODE -ne 0){throw 'Remote diverged. Ask coordinator; no rebase/reset/force.'}
 & git add -- $clean; if($LASTEXITCODE -ne 0){throw 'Staging failed; inspect index before retry.'}
 & git diff --cached --quiet
 if($LASTEXITCODE -eq 0){Write-Output 'No changes for these paths; no new commit.';exit 0}
 if($LASTEXITCODE -ne 1){throw 'Cannot inspect staged diff.'}
 & git diff --cached --check; if($LASTEXITCODE -ne 0){throw 'Staged diff check failed. Correct owned files and inspect index.'}
 & git commit -m "[$Type] $Subject"; if($LASTEXITCODE -ne 0){throw 'Commit failed; inspect index.'}
 $sha=(& git rev-parse HEAD).Trim()
 & git push origin HEAD:main; if($LASTEXITCODE -ne 0){throw "PUSH_PENDING $sha : local commit preserved; ask coordinator before retry."}
 Write-Output "PUSHED $sha origin/main"
} finally {if($null -ne $lock){$lock.Dispose()}}


