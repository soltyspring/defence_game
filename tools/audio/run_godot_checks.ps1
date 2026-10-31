# 05-audio Godot checks in an ISOLATED copy of the project. Owner: 05-audio.
# Never touches the shared .godot cache, the real project.godot or the shared user:// directory:
# the copy's project.godot gets a custom user dir (defence_audio_sandbox) so Save writes stay in the sandbox.
#
# Usage (workspace root):
#   pwsh tools/audio/run_godot_checks.ps1               # import + parse + standalone audio selftest
#   pwsh tools/audio/run_godot_checks.ps1 -Integration  # + simulated 02 request A1 (Audio autoload, exact line),
#                                                       #   02 global selftest, leak attribution, bounded real battle
# Exit code 0 = all pass. Integration report: tools/audio/_render/integration/*.json (git-ignored via .gdignore dir)
param([switch]$Integration, [int]$BattleSeconds = 95, [switch]$Record, [int]$RecordSeconds = 60, [switch]$EngineSelftest, [string]$RecordRound = 'r02', [switch]$RecordUntilEnd, [string]$InjectEnd = '', [int]$InjectAt = -1, [string]$RecordTag = '', [switch]$SkipIntegrationBattle, [string]$ProbeArgs = '', [switch]$Lifecycle, [string]$RecordSeeds = '')
if ($Record) { $Integration = $true }
$ErrorActionPreference = 'Continue'   # Godot writes diagnostics to stderr; judge by exit codes
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godot = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) { Write-Error "Godot console not found: $godot"; exit 2 }
$sb = Join-Path ([IO.Path]::GetTempPath()) 'defence_audio_sandbox'
# Double isolation (10 isolated_godot.ps1 method): Godot builds user:// from the APPDATA environment variable, so
# every Godot child of this script gets a PRIVATE APPDATA. Together with config/custom_user_dir_name below, user://
# can never resolve to the real player folder (%APPDATA%\Godot\app_userdata\Lane Defence).
$realAppData = $env:APPDATA
$realSave = Join-Path $realAppData 'Godot\app_userdata\Lane Defence\save.json'
$realSaveHash0 = if (Test-Path $realSave) { (Get-FileHash $realSave).Hash } else { '' }
$env:APPDATA = Join-Path ([IO.Path]::GetTempPath()) 'defence_audio_appdata'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$userDir = Join-Path $env:APPDATA 'defence_audio_sandbox'
# Clean sandbox + its user dir. Files can be briefly held (antivirus/indexer, a previous run still exiting):
# retry, and refuse to run on a dirty sandbox instead of silently mixing old and new files.
foreach ($d in @($sb, $userDir)) {
  for ($i = 0; $i -lt 20 -and (Test-Path $d); $i++) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue; if (Test-Path $d) { Start-Sleep -Milliseconds 500 } }
  if (Test-Path $d) { Write-Error "could not clean $d (files held open); not running on a dirty sandbox"; exit 2 }
}
New-Item -ItemType Directory -Path $sb | Out-Null
$outDir = Join-Path $root 'tools\audio\_render\integration'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# --- project copy (read-only use of other owners' files)
# Foreign files come from the COMMITTED HEAD (git archive), not the live worktree: other workers' in-progress
# edits (e.g. a half-written src/core/app.gd) otherwise break the sandbox. 05-owned paths (src/audio,
# assets/audio, tools/audio) are then overlaid from the worktree so the code under test is the current one.
$headSha = (& git -C $root rev-parse --short HEAD).Trim()
$tar = Join-Path ([IO.Path]::GetTempPath()) 'defence_audio_sandbox_head.tar'
& git -C $root archive --format=tar -o $tar HEAD -- project.godot src data scenes assets $(if (Test-Path (Join-Path $root 'icon.svg')) { 'icon.svg' })
if ($LASTEXITCODE -ne 0) { Write-Error 'git archive failed'; exit 2 }
& tar -xf $tar -C $sb
Remove-Item $tar -Force
foreach ($d in @('src\audio', 'assets\audio')) {
  $dst = Join-Path $sb $d
  if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  Copy-Item (Join-Path $root $d) $dst -Recurse
}
"foreign files from HEAD $headSha; 05 paths from worktree"
$proj = Get-Content (Join-Path $sb 'project.godot') -Raw
$proj = $proj -replace '(\[application\]\r?\n)', "`$1config/use_custom_user_dir=true`nconfig/custom_user_dir_name=""defence_audio_sandbox""`n"
if ($Integration) {
  if ($proj -notmatch '(?m)^Audio=') {
    # exact line requested from 02 in coordination/requests/05-audio-to-02-engine.md A1 (after Save, before App)
    $proj = $proj -replace '(?m)^(App="\*res://src/core/app\.gd")', "Audio=""*res://src/audio/audio_manager.gd""`n`$1"
  }
  $proj = $proj -replace '(?m)^(App="\*res://src/core/app\.gd")\r?$', "`$1`nAudioProbe=""*res://tools/audio/integration_probe.gd"""
}
Set-Content (Join-Path $sb 'project.godot') $proj -NoNewline -Encoding utf8
New-Item -ItemType Directory -Path (Join-Path $sb 'tools\audio') -Force | Out-Null
foreach ($f in @('audio_selftest.gd', 'integration_probe.gd', 'leak_probe.gd', 'lifecycle_probe.gd')) { Copy-Item (Join-Path $root "tools\audio\$f") (Join-Path $sb 'tools\audio') }
Get-ChildItem $sb -Recurse -Filter '*.import' | Remove-Item -Force
"sandbox=$sb userdir=$userDir integration=$Integration"
"autoloads: " + ((Get-Content (Join-Path $sb 'project.godot') | Select-String '^\w+="\*res://') -join ' | ')

$fail = 0
# Every Godot call has a hard wall-clock limit. On timeout ONLY this call's own process tree is killed
# (the console wrapper and its child Godot, found by parent PID); other workers' Godot processes are untouched.
function Run([string]$label, [string[]]$a, [int]$timeoutSec = 180) {
  $log = Join-Path $outDir "$label.log"
  $errf = "$log.err"
  $q = $a | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
  $p = Start-Process -FilePath $godot -ArgumentList $q -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError $errf
  $null = $p.Handle   # keep a handle so ExitCode is available after exit
  $timedOut = -not $p.WaitForExit($timeoutSec * 1000)
  if ($timedOut) {
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    $p.WaitForExit(5000) | Out-Null
  }
  $o = @(Get-Content $log -ErrorAction SilentlyContinue) + @(Get-Content $errf -ErrorAction SilentlyContinue)
  Set-Content $log ($o -join "`n") -Encoding utf8
  Remove-Item $errf -ErrorAction SilentlyContinue
  $c = if ($timedOut) { 124 } else { $p.ExitCode }
  if ($timedOut) { "TIMEOUT $label after ${timeoutSec}s: killed own process tree PID $($p.Id)" | Write-Host }
  return @{ code = $c; out = $o; timeout = $timedOut }
}
$r = Run 'import' @('--headless', '--path', $sb, '--import') 300
"import exit=$($r.code)"
foreach ($s in @('res://src/audio/audio_manager.gd', 'res://src/audio/audio_event_bridge.gd', 'res://tools/audio/audio_selftest.gd', 'res://tools/audio/integration_probe.gd', 'res://tools/audio/leak_probe.gd', 'res://tools/audio/lifecycle_probe.gd')) {
  $r = Run ('parse_' + [IO.Path]::GetFileNameWithoutExtension($s)) @('--headless', '--path', $sb, '--check-only', '--script', $s)
  if ($r.code -ne 0) { $fail++; "PARSE FAIL $s"; $r.out | Select-Object -Last 10 } else { "PARSE OK $s" }
}
$r = Run 'audio_selftest' @('--headless', '--path', $sb, '-s', 'res://tools/audio/audio_selftest.gd')
if ($r.code -ne 0) { $fail++ }
$r.out | Select-String -Pattern 'FAIL|SELFTEST|audio_autoload|"leak' | ForEach-Object { "selftest: $_" }
$sl = ($r.out | Select-String -Pattern '(\d+) ObjectDB instances were leaked' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ''
"selftest exit_leaked_objects=$(if($sl){$sl}else{0})"
if ($sl) { $fail++ }

if ($Integration) {
  # 02 global selftest (compiles every script under res://src incl. src/audio) — read-only use of 02's test.
  # Opt-in (-EngineSelftest): it now runs multi-round balance sims for > 3 min; QUOTA_POLICY asks not to rerun
  # heavy suites needlessly. Audio scripts are parse-checked above on every run.
  if (-not $EngineSelftest) { "engine selftest SKIPPED (use -EngineSelftest)" } else {
  $r = Run 'engine_selftest' @('--headless', '--path', $sb, '-s', 'res://src/core/diag/selftest.gd') 900
  $rep = Join-Path $userDir 'selftest_report.json'
  if (Test-Path $rep) {
    $j = Get-Content $rep -Raw | ConvertFrom-Json
    $audioFails = @($j.failures | Where-Object { $_ -match 'audio' })
    "engine selftest exit=$($r.code) scripts_ok=$($j.scripts_ok)/$($j.scripts_total) audio_failures=$($audioFails.Count) all_failures=$(@($j.failures).Count)"
    if ($audioFails.Count -gt 0) { $fail++; $audioFails }
    Copy-Item $rep (Join-Path $outDir 'engine_selftest_report.json')
  } else { "engine selftest produced no report (exit=$($r.code))"; $fail++ }
  }
  if ($SkipIntegrationBattle) { "leak probes + integration battle SKIPPED (-SkipIntegrationBattle)" } else {
  # leak attribution: baseline vs audio vs repeated create/free
  foreach ($m in @('empty', 'audio', 'cycle', 'quit_direct', 'quit_prepared')) {
    $r = Run "leak_$m" @('--headless', '--path', $sb, '-s', 'res://tools/audio/leak_probe.gd', '--', "--mode=$m")
    $leak = ($r.out | Select-String -Pattern '(\d+) ObjectDB instances were leaked' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ''
    $res = ($r.out | Select-String -Pattern '(\d+) resources still in use' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ''
    $probe = ($r.out | Select-String -Pattern '^LEAK_PROBE ' | Select-Object -First 1)
    "leak_$m exit=$($r.code) leaked_objects=$(if($leak){$leak}else{0}) resources_in_use=$(if($res){$res}else{0}) $probe"
    if ($m -eq 'cycle' -and $r.code -ne 0) { $fail++ }
    if ($m -in @('empty', 'audio', 'cycle', 'quit_prepared') -and ([int]"0$leak" -gt 0 -or [int]"0$res" -gt 0)) { $fail++; "  ^ unexpected exit leak" }
  }
  # bounded real battle through main scene (no --autoplay: App pauses on focus loss like a player build)
  $r = Run 'battle' @('--headless', '--verbose', '--path', $sb, '--', "--round=r02", "--quit-after=$BattleSeconds") ($BattleSeconds + 60)
  $bl = ($r.out | Select-String -Pattern '(\d+) ObjectDB instances were leaked' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ''
  # classify: audio classes are ours; GDScript/RefCounted leaks reproduce WITHOUT the Audio autoload
  # (engine-side, reported to 02 as A8), so they are reported but do not fail the audio gate
  $lk = @($r.out | Select-String -Pattern 'Leaked instance: (\w+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
  $audioLk = @($lk | Where-Object { $_ -match 'Audio|Ogg' })
  if ($r.timeout) { $fail++; "  ^ battle run TIMED OUT (hung quit path?)" }
  "battle exit=$($r.code) exit_leaked_objects=$(if($bl){$bl}else{0}) audio_class_leaks=$($audioLk.Count) foreign_classes=$((@($lk | Where-Object { $_ -notmatch 'Audio|Ogg' }) | Sort-Object -Unique) -join ',')"
  if ($audioLk.Count -gt 0) { $fail++; "  ^ audio objects leaked at exit: $($audioLk -join ',')" }
  $ir = Join-Path $userDir 'audio_integration_report.json'
  if (Test-Path $ir) {
    Copy-Item $ir (Join-Path $outDir 'audio_integration_report.json'); "integration report: $(Join-Path $outDir 'audio_integration_report.json')"
    $ij = Get-Content $ir -Raw | ConvertFrom-Json
    "battle evidence: battles_started=$($ij.battles_started) cues_played=$($ij.audio_snapshot.played) same_frame_dups=$(@($ij.same_frame_duplicates).Count) max_sfx=$($ij.max_active_sfx) max_music_players=$($ij.max_music_playing)"
    # A battle that never started proves nothing about audio integration (e.g. a foreign script mid-edit).
    if ([int]$ij.battles_started -lt 1) { $fail++; "  ^ INVALID RUN: no battle started (see battle log; foreign compile errors are reported, not audio failures)" }
    if (@($ij.same_frame_duplicates).Count -gt 0) { $fail++; "  ^ duplicate cues in one frame" }
    if ([int]$ij.max_active_sfx -gt 12 -or [int]$ij.max_music_playing -gt 2) { $fail++; "  ^ voice/player bound exceeded" }
    $cc = $ij.cue_counts
    $combat = 0; foreach ($k in 'hit_melee','hit_arrow','hit_mold','hit_bread','shoot_arrow','shoot_rock','shoot_spit','death_enemy','death_ally','hit_base','hit_base_mold','explosion') { if ($cc.$k) { $combat += [int]$cc.$k } }
    "battle combat cues=$combat kills=$($ij.engine_truth.kills) deploy cues=$($cc.deploy)/engine $($ij.engine_truth.deployed) skill cues=$([int]$cc.skill_slam + [int]$cc.skill_rally + [int]$cc.skill_barrage + [int]$cc.skill_heal + [int]$cc.skill_cast)/engine $($ij.engine_truth.skills_cast) dropped_offscreen=$($ij.audio_snapshot.dropped_offscreen) attenuated=$($ij.audio_snapshot.attenuated_offscreen)"
    if ($ij.events_has_sfx -and [int]$ij.engine_truth.kills -gt 0 -and $combat -eq 0) { $fail++; "  ^ combat happened but no combat cue was audible" }
    if ([int]$cc.deploy -ne [int]$ij.engine_truth.deployed) { $fail++; "  ^ deploy cue count != engine deployed" }
    # v3.3: 02 A9 (09508b1) sends target_side on hit cues -> victim-material cues must replace the neutral fallback
    "hits: hit_mold=$([int]$cc.hit_mold) hit_bread=$([int]$cc.hit_bread) fallback hit_melee=$([int]$cc.hit_melee) hit_arrow=$([int]$cc.hit_arrow)"
    if ([int]$ij.engine_truth.kills -gt 0 -and ([int]$cc.hit_mold + [int]$cc.hit_bread) -eq 0) { $fail++; "  ^ no hit_mold/hit_bread: target_side is not reaching the bridge" }
    $wce = [int]$ij.wave_cleared_events; $wcc = [int]$cc.wave_cleared
    "wave_cleared: events=$wce cues=$wcc indices=$(@($ij.wave_cleared_index) -join ',')"
    if ($wcc -ne $wce) { $fail++; "  ^ wave_cleared cue count != wave_cleared events (missing or duplicated)" }
    $ur = @($ij.upgrade_replies)
    $uc = [int]$cc.ui_upgrade_ok + [int]$cc.ui_upgrade_no_coins + [int]$cc.ui_upgrade_max + [int]$cc.ui_upgrade_save_failed
    $expect = @($ur | Where-Object { $_ -ne 'already_applied' -and $_ -ne '' }).Count
    "upgrade: engine replies=[$($ur -join ',')] upgrade cues=$uc (ok=$([int]$cc.ui_upgrade_ok) no_coins=$([int]$cc.ui_upgrade_no_coins)) expected=$expect"
    if ($ur.Count -lt 3) { $fail++; "  ^ upgrade engine path not exercised (replies $($ur.Count))" }
    elseif ($uc -ne $expect) { $fail++; "  ^ upgrade cue count != non-silent engine replies (missing or duplicated)" }
    $hd = [int]$ij.engine_truth.hero_deaths
    "hero: engine deaths=$hd (injected=$($ij.hero_death_injected)) hero_death cues=$([int]$cc.hero_death) hero_respawn cues=$([int]$cc.hero_respawn)"
    if ($hd -lt 1) { $fail++; "  ^ no hero death happened; hero cues unverified" }
    elseif ([int]$cc.hero_death -ne $hd) { $fail++; "  ^ hero_death cues != engine hero deaths" }
    if ($hd -ge 1 -and [int]$cc.hero_respawn -lt 1) { $fail++; "  ^ hero died but no hero_respawn cue (respawn may not have elapsed before quit)" }
  } else { "NO integration report"; $fail++ }
  $r.out | Select-String -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' | Select-Object -First 15 | ForEach-Object { "battle log: $_" }
  }
}
if ($Record) {
  # 60 s real-mix recording of one clean battle (no pause/focus/retry phases). Post-limiter Master + pre-fader stems.
  # -RecordSeeds "11,23,37": several seeded recordings in the SAME sandbox (one import), strictly one after another;
  # outputs go to tools/audio/_render/recording_<RecordTag>_s<seed>.
  $seedList = @(if ($RecordSeeds) { $RecordSeeds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } } else { '' })
  foreach ($sd in $seedList) {
  $q = $RecordSeconds + 4
  $ra = @('--headless', '--verbose', '--path', $sb, '--', "--round=$RecordRound", "--quit-after=$q", '--probe-mode=record', "--record-seconds=$RecordSeconds")
  if ($RecordUntilEnd) { $ra += '--record-until-end' }
  if ($InjectEnd -ne '' -and $InjectAt -ge 0) { $ra += "--inject-end=$InjectEnd"; $ra += "--inject-at=$InjectAt" }
  if ($ProbeArgs) { $ra += ($ProbeArgs -split ' ' | Where-Object { $_ }) }
  if ($sd -ne '') { $ra += "--probe-seed=$sd" }
  foreach ($fn in @('rec_master.wav', 'rec_sfx.wav', 'rec_ui.wav', 'rec_music.wav', 'rec_meta.json', 'audio_integration_report.json')) { Remove-Item (Join-Path $userDir $fn) -ErrorAction SilentlyContinue }
  $r = Run ('record' + $(if ($sd) { "_s$sd" } else { '' })) $ra ($q + 60)
  $tag = $RecordTag + $(if ($sd) { $(if ($RecordTag) { "_s$sd" } else { "s$sd" }) } else { '' })
  $recOut = Join-Path $root ('tools\audio\_render\recording' + $(if ($tag) { "_$tag" } else { '' }))
  $rl = @($r.out | Select-String -Pattern 'Leaked instance: (\w+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
  $ral = @($rl | Where-Object { $_ -match 'Audio|Ogg' })
  "record$(if ($sd) { " seed $sd" }) exit leaks: audio_class=$($ral.Count) [$($ral -join ',')] foreign=$((@($rl | Where-Object { $_ -notmatch 'Audio|Ogg' }) | Sort-Object -Unique) -join ',')"
  if ($ral.Count -gt 0) { $fail++; "  ^ audio objects leaked at exit in record run" }
  New-Item -ItemType Directory -Path $recOut -Force | Out-Null
  $n = 0
  foreach ($fn in @('rec_master.wav', 'rec_sfx.wav', 'rec_ui.wav', 'rec_music.wav', 'rec_meta.json', 'audio_integration_report.json')) {
    $src = Join-Path $userDir $fn
    if (Test-Path $src) { Copy-Item $src $recOut -Force; $n++ }
  }
  if ($r.timeout) { $fail++; "  ^ record run TIMED OUT" }
  "record exit=$($r.code) files_copied=$n -> $recOut"
  if ($n -lt 5) { $fail++; "  ^ recording missing" }
  }
}
if ($Lifecycle) {
  # Release-facing behaviour: app background/return, pause screen, settings persistence across restart, zero output.
  # Runs with LifecycleProbe INSTEAD of AudioProbe (they would fight over the battle), same sandbox user dir, so the
  # settings_read run is a real second process reading the save that settings_write left behind.
  $pf = Join-Path $sb 'project.godot'
  $origProj = Get-Content $pf -Raw
  $lcProj = $origProj -replace '(?m)^AudioProbe=.*\r?\n?', ''
  $lcProj = $lcProj -replace '(?m)^(App="\*res://src/core/app\.gd")\r?$', "`$1`nLifecycleProbe=""*res://tools/audio/lifecycle_probe.gd"""
  Set-Content $pf $lcProj -NoNewline -Encoding utf8
  foreach ($m in @('lifecycle', 'settings_write', 'settings_read')) {
    $la = @('--headless', '--path', $sb, '--')
    if ($m -eq 'lifecycle') { $la += '--round=r02' }
    $la += "--lc-mode=$m"
    $r = Run "lc_$m" $la 120
    $rf = Join-Path $userDir "audio_lifecycle_$m.json"
    if ($r.timeout) { $fail++; "  ^ lifecycle $m TIMED OUT" }
    if (Test-Path $rf) {
      Copy-Item $rf $outDir -Force
      $lj = Get-Content $rf -Raw | ConvertFrom-Json
      $bad = @($lj.checks.PSObject.Properties | Where-Object { -not $_.Value } | ForEach-Object { $_.Name })
      "lifecycle ${m}: pass=$($lj.pass) checks=$(@($lj.checks.PSObject.Properties).Count) failed=[$($bad -join ',')] values=$($lj.values | ConvertTo-Json -Compress -Depth 4)"
      if (-not $lj.pass) { $fail++ }
    } else { $fail++; "  ^ lifecycle $m produced no report (exit $($r.code))" }
  }
  Set-Content $pf $origProj -NoNewline -Encoding utf8
}$isoProof = Test-Path (Join-Path $userDir 'logs')
$realSaveHash1 = if (Test-Path $realSave) { (Get-FileHash $realSave).Hash } else { '' }
"isolation: private APPDATA=$($env:APPDATA) user_dir_logs_present=$isoProof real_save_changed_during_run=$($realSaveHash0 -ne $realSaveHash1) (other workers may write it; this script never points Godot at it)"
$env:APPDATA = $realAppData
"GODOT AUDIO CHECKS " + $(if ($fail -eq 0) { 'PASS' } else { "FAIL ($fail)" })
exit $fail
