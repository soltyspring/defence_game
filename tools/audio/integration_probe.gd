extends Node
## SANDBOX-ONLY autoload used by `tools/audio/run_godot_checks.ps1 -Integration`. Owner: 05-audio.
## Never registered in the real project.godot. Plays a real headless battle like a player through the
## real Events command bus (HUD-style: taps only ready+affordable cards, plus a few deliberate
## unaffordable taps), then exercises pause, focus loss/resume, mid-battle retry (scene teardown),
## rapid menu<->battle switching, and compares audio cues with engine truth (BattleSim.stats, read-only).
## Report: user://audio_integration_report.json (sandbox user dir only).

var A: Node
var E: Node
var t := 0.0
var bt := 0.0                 # time in current battle segment
var in_battle := false
var cards: Array = []
var skills: Array = []
var hud: Dictionary = {}
var _next_cmd := 1.0
var _card_i := 0
var _phase := "battle1"
var _phase_t := 0.0
var _switches := 0
var _paused_done := false
var _focus_done := false
var _bad_taps := 0
var _sim = null
var _sim_last := {}
var _frame_cues := {}
var _frame := -1
var _round := "r02"
var _report_at := -1.0
var _reported := false
# --- hero policy (aggressive player: advance while hp > 40 %, retreat below) + hero cue checks
var _hero_dir := 0
var _hero_inject_done := false
# --- record mode (--probe-mode=record): one clean battle, no pause/focus/retry/switch phases
var _record_mode := false
var _record_seconds := 60.0
var _rec := {}                 # bus name -> AudioEffectRecord
var _rec_t0_us := 0
var _rec_state := "idle"       # idle | recording | saved
var _cue_log: Array = []       # [t_wall_s, cue, variant, pitch, vol_db, t_audio_s (v4.1: read before play()), voice, vol_jitter, offscreen, duck_at_start, cluster_db, prio, t_audio_after_play_s]
var _cluster_log: Array = []   # v3.9: [t_audio_s, new voice, lowered earlier voice, dB] per onset-cluster action on an earlier voice
var _duck_log: Array = []      # v3.9: [t_audio_s, owner voice, [[voice, extra dB], ...]] per danger-cue SFX duck
var _clock_player: AudioStreamPlayer = null   # v3.9: silent audio-clock voice (see _audio_now)
var _clock_log: Array = []     # v3.9: [t_wall_s, t_audio_s] each time the audio clock advanced (mix blocks)
var _gain_log: Array = []      # [t_s, music_bus_db, music_mute, master_mute]
var _record_until_end := false # --record-until-end: stop 4.5 s after battle_ended (stinger is <= 3 s)
var _ended_rec_ts := -1.0
# --inject-end=win|loss --inject-at=SEC: sandbox-only test injection that ends the battle through the real
# engine path (BattleSim._damage_base -> _end -> "ended" -> App result -> Events.battle_ended -> stinger),
# so win/defeat stingers can be recorded in bounded time. Reported as injected in the report/meta.
var _inject_end := ""
var _inject_at := -1.0
var _inject_done := false
var _upgrade_done := false
var _passive := false   # --probe-passive: record only; the player is App's --autoplay bot (02 bot_player, competent)

var rep := {
	"cue_counts": {}, "same_frame_duplicates": [], "commands": {"deploy": 0, "deploy_unaffordable": 0, "worker": 0, "skill": 0},
	"toasts": {}, "screens": [], "battles_started": 0, "battles_ended": 0, "results": [],
	"max_active_sfx": 0, "max_active_ui": 0, "max_music_playing": 0, "audio_children": [],
	"focus": {}, "pause": {}, "music_timeline": [], "errors": [], "phases": [],
	"engine_truth": {"deployed": 0, "workers_bought": 0, "skills_cast": 0, "kills": 0, "hero_deaths": 0}, "switch_check": {},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--round="): _round = a.get_slice("=", 1)
	A = get_node_or_null("/root/Audio")
	E = get_node_or_null("/root/Events")
	if A == null or E == null:
		rep.errors.append("Audio or Events autoload missing")
		return
	rep.audio_children.append(A.get_child_count())
	A.cue_played.connect(_on_cue)
	E.toast.connect(_on_toast)
	E.screen_changed.connect(_on_screen)
	E.battle_started.connect(_on_battle_started)
	E.battle_ended.connect(_on_battle_ended)
	E.hud_snapshot.connect(_on_hud)
	if E.has_signal("wave_cleared"): E.wave_cleared.connect(_on_wave_cleared)
	if E.has_signal("upgrade_result"): E.upgrade_result.connect(_on_upgrade_result)
	if E.has_signal("sfx"): E.sfx.connect(_on_engine_sfx)
	# sandbox save only (custom user dir): unlock r01-r03 so cmd_retry of the --round battle and
	# cmd_start_round work like for a player who reached them
	var save := get_node_or_null("/root/Save")
	if save: save.progress.unlocked_round = maxi(int(save.progress.unlocked_round), 3)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quit-after="): _report_at = float(a.get_slice("=", 1)) - 0.5
		if a == "--probe-mode=record": _record_mode = true
		if a.begins_with("--record-seconds="): _record_seconds = float(a.get_slice("=", 1))
		if a == "--record-until-end": _record_until_end = true
		if a.begins_with("--inject-end="): _inject_end = a.get_slice("=", 1)
		if a.begins_with("--inject-at="): _inject_at = float(a.get_slice("=", 1))
		if a == "--probe-passive": _passive = true
		if a.begins_with("--probe-seed="):
			seed(int(a.get_slice("=", 1)))   # App uses randi() for the battle seed outside autoplay: fix it for A/B runs
			rep.probe_seed = int(a.get_slice("=", 1))
		if a.begins_with("--hit-group-gap=") and A != null:
			A.group_gap["hit"] = float(a.get_slice("=", 1))   # A/B of the shared hit rate limit (0 = off)
			rep.hit_group_gap = A.group_gap["hit"]
		if a.begins_with("--offscreen-db=") and A != null:
			A.offscreen_max_atten_db = float(a.get_slice("=", 1))
			rep.offscreen_db = A.offscreen_max_atten_db
	if _record_mode: _phase = "record"

func _on_toast(k: String, _a: Dictionary) -> void:
	rep.toasts[k] = int(rep.toasts.get(k, 0)) + 1

func _on_screen(s: StringName, _p: Dictionary) -> void:
	rep.screens.append(str(s))

func _on_wave_cleared(info: Dictionary) -> void:
	rep.wave_cleared_events = int(rep.get("wave_cleared_events", 0)) + 1
	rep.wave_cleared_index = rep.get("wave_cleared_index", []) + [int(info.get("index", 0))]

## Engine-side truth for hit density: every semantic hit cue 02 emits (before any audio rate limiting).
func _on_engine_sfx(cue: StringName, params: Dictionary) -> void:
	if cue != &"hit": return
	var k := "hit_events_" + str(params.get("target_side", "none"))
	rep[k] = int(rep.get(k, 0)) + 1
	if _rec_state == "recording":
		rep[k + "_rec"] = int(rep.get(k + "_rec", 0)) + 1

func _on_upgrade_result(r: Dictionary) -> void:
	var c := str(r.get("code", ""))
	rep.upgrade_replies = rep.get("upgrade_replies", []) + [c]

## Real engine upgrade path (sandbox save only): double tap of an affordable level (ok + already_applied in
## the same frame), then an unaffordable next level (not_enough_coins). 02 App handles cmd_buy_upgrade
## synchronously and answers with Events.upgrade_result; the audio bridge plays from that reply.
func _upgrade_check() -> void:
	_upgrade_done = true
	var save := get_node_or_null("/root/Save")
	if save == null or not E.has_signal("cmd_buy_upgrade"):
		rep.upgrade_check = "skipped (no Save/cmd_buy_upgrade)"
		return
	var id := "up_melee_basic"
	var cur := int(save.upgrade_level(id)) if save.has_method("upgrade_level") else 0
	save.progress.coins = 100000
	E.cmd_buy_upgrade.emit(id, cur + 1)
	E.cmd_buy_upgrade.emit(id, cur + 1)        # same-frame repeat = double tap
	A.advance(0.0)
	save.progress.coins = 0
	get_tree().create_timer(0.6, true, false, true).timeout.connect(func(): E.cmd_buy_upgrade.emit(id, cur + 2))
	rep.upgrade_check = {"id": id, "from_level": cur}

func _on_battle_ended(r: Dictionary) -> void:
	if _rec_state == "recording" and _ended_rec_ts < 0.0:
		_ended_rec_ts = (Time.get_ticks_usec() - _rec_t0_us) / 1e6
	in_battle = false
	rep.battles_ended += 1
	rep.results.append({"won": r.get("won"), "time": r.get("time")})

func _on_hud(s: Dictionary) -> void:
	hud = s

func _on_cue(cue: StringName, _voice: int) -> void:   # _voice = index in A._sfx (-1 for UI/stinger)
	var c := str(cue)
	rep.cue_counts[c] = int(rep.cue_counts.get(c, 0)) + 1
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_frame_cues.clear()
	if _frame_cues.has(c):
		rep.same_frame_duplicates.append({"cue": c, "t": snappedf(t, 0.01)})
	_frame_cues[c] = true
	if _rec_state == "recording":
		# v3.8: also log WHICH file (variant index), pitch and volume, for repetition analysis
		# v3.9: + audio-clock start (the mix block the voice really starts in), voice index, and the parts of the
		# volume (jitter, off-screen, duck at start), so tools/audio/rerender.py can rebuild the SFX bus exactly
		var vi := int(A._last_variant.get(cue, 0))
		var pl: AudioStreamPlayer = A._sfx[_voice] if _voice >= 0 and _voice < A._sfx.size() else null
		var lp: Dictionary = A.get("last_play") if A.get("last_play") is Dictionary else {}
		var t_post := _audio_now()
		# v4.1: field 5 = audio clock read just BEFORE play() (manager hook); the v3.9 after-play read is kept as field 12
		var t_pre := float(lp.get("clk_pre", -1.0))
		_cue_log.append([snappedf((Time.get_ticks_usec() - _rec_t0_us) / 1e6, 0.001), c, vi,
			snappedf(pl.pitch_scale, 0.0001) if pl else 1.0, snappedf(pl.volume_db, 0.01) if pl else 0.0,
			snappedf(t_pre if t_pre >= 0.0 else t_post, 0.00001), _voice, snappedf(float(lp.get("vj", 0.0)), 0.01),
			snappedf(float(lp.get("off", 0.0)), 0.01), snappedf(float(lp.get("sd", 0.0)), 0.01),
			snappedf(float(lp.get("cl", 0.0)), 0.01), int(A.cues.get(cue, {}).get("prio", 1)), snappedf(t_post, 0.00001)])
		var lc = A.get("last_cluster")
		if lc is Array and (lc as Array).size() == 2:
			_cluster_log.append([snappedf(_audio_now(), 0.00001), _voice, int(lc[0]), float(lc[1])])
		var cd: Dictionary = A.cues.get(cue, {})
		if float(cd.get("duck_sfx", 0.0)) < 0.0 and A.get("last_duck") is Array:
			_duck_log.append([snappedf(_audio_now(), 0.00001), _voice, (A.last_duck as Array).duplicate(true)])

## v3.9: audio time = seconds of audio the mixer has produced since the recording started, read from a silent
## clock voice that started in the same mix block as the AudioEffectRecord capture. A voice started now begins at
## the next mix block, which is exactly this position in the recording (the cue log's wall time is not: the
## headless Dummy driver mixes 4096-frame blocks and falls behind the wall clock).
func _audio_now() -> float:
	return _clock_player.get_playback_position() if _clock_player and _clock_player.playing else -1.0

func _on_battle_started(info: Dictionary) -> void:
	in_battle = true
	bt = 0.0
	_next_cmd = 1.0
	_hero_dir = 0
	rep.battles_started += 1
	cards = []
	for c in info.get("cards", []): cards.append(str(c.id))
	skills = []
	for s in info.get("skills", []): skills.append(str(s.id))
	rep.audio_children.append(A.get_child_count())

## Accumulate BattleSim.stats per sim instance (engine truth for command cues), read-only.
func _track_sim() -> void:
	var app := get_node_or_null("/root/App")
	var b = app.get("battle") if app else null    # get(): no error spam if App failed to compile
	var s = b.sim if b and is_instance_valid(b) else null
	if s != _sim:
		_flush_sim()
		_sim = s
		_sim_last = {}
	if _sim != null:
		_sim_last = {"deployed": int(_sim.stats.get("deployed", 0)), "workers_bought": int(_sim.stats.get("workers_bought", 0)),
			"skills_cast": int(_sim.stats.get("skills_cast", 0)), "kills": int(_sim.kills), "hero_deaths": int(_sim.stats.get("hero_deaths", 0))}

func _flush_sim() -> void:
	for k in _sim_last:
		rep.engine_truth[k] = int(rep.engine_truth[k]) + maxi(0, int(_sim_last[k]))

func _music_playing() -> int:
	var mp := 0
	for c in A.get_children():
		if c is AudioStreamPlayer and str(c.name).begins_with("Music") and c.playing: mp += 1
	return mp

func _set_phase(p: String) -> void:
	_phase = p
	_phase_t = 0.0
	rep.phases.append({"t": snappedf(t, 0.1), "phase": p})

func _process(delta: float) -> void:
	if _reported:
		# Fallback: App normally quits at --quit-after. If it has not done so 4 s later (App broken or its
		# quit path hung), quit ourselves with code 3 so the harness sees a failure instead of a hang.
		t += delta
		if _report_at > 0.0 and t >= _report_at + 4.5:
			push_error("AudioProbe: App did not quit; probe fallback quit(3)")
			_report_at = -1.0
			get_tree().quit(3)
		return
	if A == null: return
	t += delta
	_phase_t += delta
	if _report_at > 0.0 and t >= _report_at:
		_write_report()
		A.prepare_quit()   # App quits ~0.5 s later; lets AudioServer release playbacks (no exit leak)
		return
	_track_sim()
	var snap: Dictionary = A.snapshot()
	rep.max_active_sfx = maxi(rep.max_active_sfx, int(snap.active_sfx))
	rep.max_active_ui = maxi(rep.max_active_ui, int(snap.active_ui))
	rep.max_music_playing = maxi(rep.max_music_playing, _music_playing())
	if rep.music_timeline.is_empty() or rep.music_timeline[-1].m != snap.music:
		rep.music_timeline.append({"t": snappedf(t, 0.1), "m": snap.music})
	if not _upgrade_done and t >= 1.0 and not _record_mode: _upgrade_check()
	match _phase:
		"battle1":
			if in_battle: _drive()
			if bt >= 30.0: _set_phase("retry")
		"retry":
			E.cmd_retry.emit()            # mid-battle teardown + rebuild while SFX/music are live
			rep.audio_children.append(A.get_child_count())
			_set_phase("battle2")
		"battle2":
			if in_battle: _drive()
			if _phase_t >= 12.0: _set_phase("switch")
		"switch":
			# rapid menu <-> battle switching every 0.25 s (10 switches) through real commands
			if _phase_t >= 0.25:
				_phase_t = 0.0
				_switches += 1
				if _switches % 2 == 1: E.cmd_open_screen.emit(&"round_select")
				else: E.cmd_start_round.emit(_round)
				if _switches >= 10: _set_phase("settle")
		"settle":
			if _phase_t >= 2.0:
				rep.switch_check = {"music": str(snap.music), "music_players_playing": _music_playing(),
					"in_battle_screen": in_battle, "children": A.get_child_count()}
				_set_phase("battle3")
		"battle3":
			if in_battle:
				_drive()
				_maybe_inject_hero_death()
		"record":
			if in_battle and _passive:
				bt += delta
			elif in_battle:
				_drive()
				if _inject_end != "" and not _inject_done and _inject_at >= 0.0 and bt >= _inject_at and _sim != null:
					_inject_done = true
					rep.end_injected = {"result": _inject_end, "at_battle_t": snappedf(bt, 0.01)}
					_sim._damage_base(_sim.SIDE_ENEMY if _inject_end == "win" else _sim.SIDE_PLAYER, 1e9)
			if in_battle or _rec_state == "recording": _record_step()

## Hero cue check: if the aggressive policy produced no natural hero death by battle3 + 4 s, set hero hp
## to 1 once (sandbox-only test injection, reported as such); the kill then goes through the real
## damage -> _kill -> "hero_dead" event -> Events.sfx path.
func _maybe_inject_hero_death() -> void:
	if _hero_inject_done or _phase_t < 1.0 or _sim == null: return
	_hero_inject_done = true
	if int(_sim.stats.get("hero_deaths", 0)) > 0 or int(rep.engine_truth.hero_deaths) > 0:
		rep.hero_death_injected = false
		return
	_sim.hero.hp = 1.0
	rep.hero_death_injected = true

func _hero_policy() -> void:
	var h: Dictionary = hud.get("hero", {})
	if h.is_empty(): return
	var want := 0
	if rep.get("hero_death_injected", false) and int(rep.engine_truth.hero_deaths) == 0 and _sim and int(_sim.stats.get("hero_deaths", 0)) == 0:
		want = 1   # walk the 1-hp hero into the enemy line so the real damage path kills it
		if want != _hero_dir:
			_hero_dir = want
			E.cmd_hero_move.emit(want)
		return
	if bool(h.get("alive", true)):
		want = 1 if float(h.get("hp", 1)) > 0.4 * float(h.get("hp_max", 1)) else -1
	if want != _hero_dir:
		_hero_dir = want
		E.cmd_hero_move.emit(want)

# ------------------------------------------------------------------ recording
func _record_step() -> void:
	match _rec_state:
		"idle":
			if bt < 0.5: return
			for b in ["Master", "SFX", "UI", "Music"]:
				var r := AudioEffectRecord.new()
				r.format = AudioStreamWAV.FORMAT_16_BITS
				var bi := AudioServer.get_bus_index(b)
				AudioServer.add_bus_effect(bi, r)        # appended last: Master = post-limiter, stems = pre-fader
				_rec[b] = r
			# v3.9 audio clock: 8-bit silence at 11025 Hz (= 4 output frames at 44.1 kHz), long enough for the whole
			# recording, at -80 dB on Master (all-zero data adds nothing to any stem). Started in the capture's frame.
			var cw := AudioStreamWAV.new()
			cw.format = AudioStreamWAV.FORMAT_8_BITS
			cw.mix_rate = 11025
			cw.stereo = false
			var zeros := PackedByteArray()
			zeros.resize(int((_record_seconds + 120.0) * 11025.0))
			zeros.fill(0)
			cw.data = zeros
			_clock_player = AudioStreamPlayer.new()
			_clock_player.process_mode = Node.PROCESS_MODE_ALWAYS
			_clock_player.stream = cw
			_clock_player.volume_db = -80.0
			_clock_player.bus = &"Master"
			add_child(_clock_player)
			_clock_player.play()
			if "pre_play_probe" in A: A.pre_play_probe = Callable(self, "_audio_now")   # v4.1: read the clock before play()
			for b in _rec: _rec[b].set_recording_active(true)
			_rec_t0_us = Time.get_ticks_usec()
			_rec_state = "recording"
		"recording":
			var ts := (Time.get_ticks_usec() - _rec_t0_us) / 1e6
			var ta := snappedf(_audio_now(), 0.00001)
			if _clock_log.is_empty() or ta != float(_clock_log[-1][1]): _clock_log.append([snappedf(ts, 0.0001), ta])
			var mi := AudioServer.get_bus_index(&"Music")
			_gain_log.append([snappedf(ts, 0.001), snappedf(AudioServer.get_bus_volume_db(mi), 0.01),
				AudioServer.is_bus_mute(mi), AudioServer.is_bus_mute(0)])
			if ts >= _record_seconds or (_record_until_end and _ended_rec_ts >= 0.0 and ts >= _ended_rec_ts + 4.5):
				for b in _rec: _rec[b].set_recording_active(false)
				var files := {}
				for b in _rec:
					var w: AudioStreamWAV = _rec[b].get_recording()
					var p := "user://rec_%s.wav" % b.to_lower()
					if w: w.save_to_wav(p)
					files[b] = p if w else ""
				var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))
				var ui_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"UI"))
				var meta := {"seconds": ts, "battle_ended_at": _ended_rec_ts, "results": rep.results, "end_injected": rep.get("end_injected", {}), "mix_rate": AudioServer.get_mix_rate(), "files": files,
					"sfx_bus_db": sfx_db, "ui_bus_db": ui_db, "cues": _cue_log, "music_gain": _gain_log,
					"log_format": 2, "cue_fields": ["t_wall", "cue", "variant", "pitch", "vol_db", "t_audio", "voice", "vol_jitter_db", "offscreen_db", "duck_at_start_db", "cluster_db", "prio", "t_audio_after_play"],
					"t_audio_source": "pre_play" if "pre_play_probe" in A else "after_play",
					"ducks": _duck_log, "clusters": _cluster_log, "clock": _clock_log, "audio_block_frames": _block_frames(),
					"onset_cluster": A.get("onset_cluster"), "audio_stats": (A.stats as Dictionary).duplicate(),
					"limiter": AudioServer.get_bus_effect(0, 0).get_class() if AudioServer.get_bus_effect_count(0) > 0 else "",
					"round": _round, "driver": "headless Dummy (software mix, real time)"}
				var f := FileAccess.open("user://rec_meta.json", FileAccess.WRITE)
				if f: f.store_string(JSON.stringify(meta))
				_rec_state = "saved"
				rep.recording = {"seconds": snappedf(ts, 0.01), "cues": _cue_log.size()}
				for b in _rec:
					var bi := AudioServer.get_bus_index(b)
					for e in range(AudioServer.get_bus_effect_count(bi) - 1, -1, -1):
						if AudioServer.get_bus_effect(bi, e) == _rec[b]: AudioServer.remove_bus_effect(bi, e)
				_rec.clear()
				if "pre_play_probe" in A: A.pre_play_probe = Callable()
				if _clock_player:
					_clock_player.stop()
					_clock_player.stream = null
					_clock_player.queue_free()
					_clock_player = null
				if _record_until_end:
					# done early: write the report, release audio, quit after 0.5 s wall clock (prepare_quit rule)
					_write_report()
					A.prepare_quit()
					get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): get_tree().quit(0))

## v3.9: the mixer's block size in output frames = the most common step of the audio clock (starts are quantised to it)
func _block_frames() -> int:
	var steps := {}
	for i in range(1, _clock_log.size()):
		var d := int(round((float(_clock_log[i][1]) - float(_clock_log[i - 1][1])) * AudioServer.get_mix_rate()))
		if d > 0: steps[d] = int(steps.get(d, 0)) + 1
	var best := 0
	for k in steps:
		if best == 0 or int(steps[k]) > int(steps[best]): best = k
	return best

func _drive() -> void:
	bt += get_process_delta_time()
	_hero_policy()
	if _record_mode:
		_paused_done = true
		_focus_done = true
	if not _paused_done and bt >= 10.0:
		_paused_done = true
		E.cmd_set_paused.emit(true)
		rep.pause.paused_flag = A.is_battle_paused()
		rep.pause.direct_sfx_while_paused = A.play(&"deploy")
		rep.pause.ui_while_paused = A.play(&"ui_back")
		E.cmd_set_paused.emit(false)
		rep.pause.resumed_flag = not A.is_battle_paused()
		return
	if not _focus_done and bt >= 18.0:
		_focus_done = true
		get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		rep.focus.master_muted_out = AudioServer.is_bus_mute(0)
		rep.focus.battle_paused_out = A.is_battle_paused()
		get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		rep.focus.master_muted_in = AudioServer.is_bus_mute(0)
		rep.focus.battle_still_paused_in = A.is_battle_paused()
		E.cmd_set_paused.emit(false)
		rep.focus.resumed = not A.is_battle_paused()
		return
	if A.is_battle_paused() or bt < _next_cmd or hud.is_empty(): return
	_next_cmd = bt + 0.7
	var gold := float(hud.get("gold", 0))
	for sk in hud.get("skills", []):
		if bool(sk.get("ready", false)):
			rep.commands.skill += 1
			E.cmd_hero_skill.emit(str(sk.id))
			return
	if int(hud.get("workers", 0)) < 4 and gold >= float(hud.get("worker_cost", 1e9)) + 30:
		rep.commands.worker += 1
		E.cmd_buy_worker.emit()
		return
	var hc: Array = hud.get("cards", [])
	if hc.is_empty(): return
	var c: Dictionary = hc[_card_i % hc.size()]
	_card_i += 1
	if bool(c.get("ready", false)) and bool(c.get("affordable", false)):
		rep.commands.deploy += 1
		E.cmd_deploy_unit.emit(str(c.id))
	elif _bad_taps < 5 and not bool(c.get("affordable", true)):
		_bad_taps += 1                       # deliberate failing tap: expect ui_error, no deploy cue
		rep.commands.deploy_unaffordable += 1
		E.cmd_deploy_unit.emit(str(c.id))

func _exit_tree() -> void:
	if A != null and not _reported: _write_report()

func _write_report() -> void:
	_reported = true
	_track_sim()
	_flush_sim()
	_sim = null          # drop the strong BattleSim (RefCounted) reference, else it leaks at exit
	_sim_last = {}
	rep.audio_snapshot = A.snapshot()
	rep.audio_children.append(A.get_child_count())
	rep.bridge_derived = A.bridge.derived.duplicate() if A.bridge else {}
	rep.events_has_sfx = E.has_signal("sfx")
	rep.t = snappedf(t, 0.1)
	var txt := JSON.stringify(rep, " ")
	var f := FileAccess.open("user://audio_integration_report.json", FileAccess.WRITE)
	if f: f.store_string(txt)
	print("AUDIO_INTEGRATION_REPORT ", JSON.stringify(rep))
