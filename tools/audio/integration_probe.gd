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
var _cue_log: Array = []       # [t_s, cue, vol_db_param]
var _gain_log: Array = []      # [t_s, music_bus_db, music_mute, master_mute]

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
	# sandbox save only (custom user dir): unlock r01-r03 so cmd_retry of the --round battle and
	# cmd_start_round work like for a player who reached them
	var save := get_node_or_null("/root/Save")
	if save: save.progress.unlocked_round = maxi(int(save.progress.unlocked_round), 3)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quit-after="): _report_at = float(a.get_slice("=", 1)) - 0.5
		if a == "--probe-mode=record": _record_mode = true
		if a.begins_with("--record-seconds="): _record_seconds = float(a.get_slice("=", 1))
	if _record_mode: _phase = "record"

func _on_toast(k: String, _a: Dictionary) -> void:
	rep.toasts[k] = int(rep.toasts.get(k, 0)) + 1

func _on_screen(s: StringName, _p: Dictionary) -> void:
	rep.screens.append(str(s))

func _on_battle_ended(r: Dictionary) -> void:
	in_battle = false
	rep.battles_ended += 1
	rep.results.append({"won": r.get("won"), "time": r.get("time")})

func _on_hud(s: Dictionary) -> void:
	hud = s

func _on_cue(cue: StringName, _voice: int) -> void:
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
		_cue_log.append([snappedf((Time.get_ticks_usec() - _rec_t0_us) / 1e6, 0.001), c])

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
			if in_battle: _drive()
			_record_step()

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
			if not in_battle or bt < 0.5: return
			for b in ["Master", "SFX", "UI", "Music"]:
				var r := AudioEffectRecord.new()
				r.format = AudioStreamWAV.FORMAT_16_BITS
				var bi := AudioServer.get_bus_index(b)
				AudioServer.add_bus_effect(bi, r)        # appended last: Master = post-limiter, stems = pre-fader
				_rec[b] = r
			for b in _rec: _rec[b].set_recording_active(true)
			_rec_t0_us = Time.get_ticks_usec()
			_rec_state = "recording"
		"recording":
			var ts := (Time.get_ticks_usec() - _rec_t0_us) / 1e6
			var mi := AudioServer.get_bus_index(&"Music")
			_gain_log.append([snappedf(ts, 0.001), snappedf(AudioServer.get_bus_volume_db(mi), 0.01),
				AudioServer.is_bus_mute(mi), AudioServer.is_bus_mute(0)])
			if ts >= _record_seconds:
				for b in _rec: _rec[b].set_recording_active(false)
				var files := {}
				for b in _rec:
					var w: AudioStreamWAV = _rec[b].get_recording()
					var p := "user://rec_%s.wav" % b.to_lower()
					if w: w.save_to_wav(p)
					files[b] = p if w else ""
				var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))
				var ui_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"UI"))
				var meta := {"seconds": ts, "mix_rate": AudioServer.get_mix_rate(), "files": files,
					"sfx_bus_db": sfx_db, "ui_bus_db": ui_db, "cues": _cue_log, "music_gain": _gain_log,
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
