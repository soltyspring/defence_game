# 05-audio Godot checks in an ISOLATED copy of the project. Owner: 05-audio.
# Never touches the shared .godot cache, the real project.godot or the shared user:// directory:
# the copy's project.godot gets a custom user dir (defence_audio_sandbox) so Save writes stay in the sandbox.
#
# Usage (workspace root):
#   pwsh tools/audio/run_godot_checks.ps1               # import + parse + standalone audio selftest
#   pwsh tools/audio/run_godot_checks.ps1 -Integration  # + simulated 02 request A1 (Audio autoload, exact line),
#                                                       #   02 global selftest, leak attribution, bounded real battle
# Exit code 0 = all pass. Integration report: tools/audio/_render/integration/*.json (git-ignored via .gdignore dir)
param([switch]$Integration, [int]$BattleSeconds = 95)
$ErrorActionPreference = 'Continue'   # Godot writes diagnostics to stderr; judge by exit codes
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$godot = Join-Path $root 'tools\engine\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) { Write-Error "Godot console not found: $godot"; exit 2 }
$sb = Join-Path ([IO.Path]::GetTempPath()) 'defence_audio_sandbox'
$userDir = Join-Path $env:APPDATA 'defence_audio_sandbox'
foreach ($d in @($sb, $userDir)) { if (Test-Path $d) { Remove-Item -LiteralPath $d -Recurse -Force } }
New-Item -ItemType Directory -Path $sb | Out-Null
$outDir = Join-Path $root 'tools\audio\_render\integration'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# --- project copy (read-only use of other owners' files)
$proj = Get-Content (Join-Path $root 'project.godot') -Raw
$proj = $proj -replace '(\[application\]\r?\n)', "`$1config/use_custom_user_dir=true`nconfig/custom_user_dir_name=""defence_audio_sandbox""`n"
if ($Integration) {
  if ($proj -notmatch '(?m)^Audio=') {
    # exact line requested from 02 in coordination/requests/05-audio-to-02-engine.md A1 (after Save, before App)
    $proj = $proj -replace '(?m)^(App="\*res://src/core/app\.gd")', "Audio=""*res://src/audio/audio_manager.gd""`n`$1"
  }
  $proj = $proj -replace '(?m)^(App="\*res://src/core/app\.gd")\r?$', "`$1`nAudioProbe=""*res://tools/audio/integration_probe.gd"""
}
Set-Content (Join-Path $sb 'project.godot') $proj -NoNewline -Encoding utf8
if (Test-Path (Join-Path $root 'icon.svg')) { Copy-Item (Join-Path $root 'icon.svg') $sb }
foreach ($d in @('src', 'data', 'scenes', 'assets')) {
  $src = Join-Path $root $d
  if (Test-Path $src) { Copy-Item $src (Join-Path $sb $d) -Recurse }
}
New-Item -ItemType Directory -Path (Join-Path $sb 'tools\audio') -Force | Out-Null
foreach ($f in @('audio_selftest.gd', 'integration_probe.gd', 'leak_probe.gd')) { Copy-Item (Join-Path $root "tools\audio\$f") (Join-Path $sb 'tools\audio') }
Get-ChildItem $sb -Recurse -Filter '*.import' | Remove-Item -Force
"sandbox=$sb userdir=$userDir integration=$Integration"
"autoloads: " + ((Get-Content (Join-Path $sb 'project.godot') | Select-String '^\w+="\*res://') -join ' | ')

$fail = 0
function Run([string]$label, [string[]]$a, [int]$expect = 0) {
  $o = & $godot @a 2>&1 | ForEach-Object { "$_" }
  $c = $LASTEXITCODE
  Set-Content (Join-Path $outDir "$label.log") ($o -join "`n") -Encoding utf8
  return @{ code = $c; out = $o }
}
$r = Run 'import' @('--headless', '--path', $sb, '--import')
"import exit=$($r.code)"
foreach ($s in @('res://src/audio/audio_manager.gd', 'res://src/audio/audio_event_bridge.gd', 'res://tools/audio/audio_selftest.gd', 'res://tools/audio/integration_probe.gd', 'res://tools/audio/leak_probe.gd')) {
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
  # 02 global selftest (compiles every script under res://src incl. src/audio) — read-only use of 02's test
  $r = Run 'engine_selftest' @('--headless', '--path', $sb, '-s', 'res://src/core/diag/selftest.gd')
  $rep = Join-Path $userDir 'selftest_report.json'
  if (Test-Path $rep) {
    $j = Get-Content $rep -Raw | ConvertFrom-Json
    $audioFails = @($j.failures | Where-Object { $_ -match 'audio' })
    "engine selftest exit=$($r.code) scripts_ok=$($j.scripts_ok)/$($j.scripts_total) audio_failures=$($audioFails.Count) all_failures=$(@($j.failures).Count)"
    if ($audioFails.Count -gt 0) { $fail++; $audioFails }
    Copy-Item $rep (Join-Path $outDir 'engine_selftest_report.json')
  } else { "engine selftest produced no report (exit=$($r.code))"; $fail++ }
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
  $r = Run 'battle' @('--headless', '--verbose', '--path', $sb, '--', "--round=r02", "--quit-after=$BattleSeconds")
  $bl = ($r.out | Select-String -Pattern '(\d+) ObjectDB instances were leaked' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join ''
  # classify: audio classes are ours; GDScript/RefCounted leaks reproduce WITHOUT the Audio autoload
  # (engine-side, reported to 02 as A8), so they are reported but do not fail the audio gate
  $lk = @($r.out | Select-String -Pattern 'Leaked instance: (\w+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
  $audioLk = @($lk | Where-Object { $_ -match 'Audio|Ogg' })
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
    $combat = 0; foreach ($k in 'hit_melee','hit_arrow','shoot_arrow','shoot_rock','shoot_spit','death_enemy','death_ally','hit_base','explosion') { if ($cc.$k) { $combat += [int]$cc.$k } }
    "battle combat cues=$combat kills=$($ij.engine_truth.kills) deploy cues=$($cc.deploy)/engine $($ij.engine_truth.deployed) skill cues=$([int]$cc.skill_slam + [int]$cc.skill_rally + [int]$cc.skill_barrage + [int]$cc.skill_heal + [int]$cc.skill_cast)/engine $($ij.engine_truth.skills_cast) dropped_offscreen=$($ij.audio_snapshot.dropped_offscreen) attenuated=$($ij.audio_snapshot.attenuated_offscreen)"
    if ($ij.events_has_sfx -and [int]$ij.engine_truth.kills -gt 0 -and $combat -eq 0) { $fail++; "  ^ combat happened but no combat cue was audible" }
    if ([int]$cc.deploy -ne [int]$ij.engine_truth.deployed) { $fail++; "  ^ deploy cue count != engine deployed" }
  } else { "NO integration report"; $fail++ }
  $r.out | Select-String -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' | Select-Object -First 15 | ForEach-Object { "battle log: $_" }
}
"GODOT AUDIO CHECKS " + $(if ($fail -eq 0) { 'PASS' } else { "FAIL ($fail)" })
exit $fail
