extends Node
## SANDBOX-ONLY autoload for release-facing audio behaviour (05-audio, v3.5). Never in the real project.godot.
## Modes (user arg --lc-mode=...), run by `tools/audio/run_godot_checks.ps1 -Lifecycle`:
##   lifecycle      : r02 battle; app background/return (APPLICATION_PAUSED/RESUMED and FOCUS_OUT/IN, delivered
##                    through the real notification path to every node incl. App and Audio), pause-screen leak check.
##   settings_write : sets music 0.3 / sfx 0.0 through the real Events.cmd_set_setting (App -> Save writes save.json).
##   settings_read  : NEW process, same sandbox user dir: checks the saved values are applied at boot, then sets
##                    music 0 and records the Master output while cues are triggered: must be digital silence.
## Notification delivery here is simulated (propagate_notification); a real Android pause also suspends the
## process and the audio driver, which this cannot reproduce. Report: user://audio_lifecycle_<mode>.json

var A: Node
var E: Node
var mode := ""
var t := 0.0
var bt := 0.0
var phase := "wait"
var phase_t := 0.0
var rep := {"checks": {}, "values": {}}
var sfx_plays := 0
var ui_plays := 0
var music_plays := 0
var _rec: AudioEffectRecord = null
var _done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lc-mode="): mode = a.get_slice("=", 1)
	A = get_node_or_null("/root/Audio")
	E = get_node_or_null("/root/Events")
	if mode == "" or A == null or E == null:
		set_process(false)
		return
	rep.mode = mode
	A.cue_played.connect(_on_cue)
	E.hud_snapshot.connect(func(h): _hud = h)

var _last_voice := -1

func _on_cue(cue: StringName, _v: int) -> void:
	_last_voice = _v
	var bus := str(A.cues.get(cue, {}).get("bus", ""))
	if bus == "SFX": sfx_plays += 1
	elif bus == "UI": ui_plays += 1
	else: music_plays += 1

func _ok(name: String, v: bool) -> void:
	rep.checks[name] = v

func _music_player() -> AudioStreamPlayer:
	return A._music[A._music_cur] if A._music_cur >= 0 else null

func _bus(n: StringName) -> int:
	return AudioServer.get_bus_index(n)

func _notify(what: int) -> void:
	get_tree().root.propagate_notification(what)

func _goto(p: String) -> void:
	phase = p
	phase_t = 0.0

func _finish() -> void:
	if _done: return
	_done = true
	rep.values.sfx_plays_total = sfx_plays
	rep.pass = not rep.checks.values().has(false) and not rep.checks.is_empty()
	var f := FileAccess.open("user://audio_lifecycle_%s.json" % mode, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(rep, " "))
	print("AUDIO_LIFECYCLE ", JSON.stringify(rep))
	A.prepare_quit()
	get_tree().create_timer(0.4, true, false, true).timeout.connect(func(): get_tree().quit(0 if rep.pass else 4))

func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	if t > 80.0 and not _done:
		_ok("finished_in_time", false)
		_finish()
		return
	match mode:
		"lifecycle": _lifecycle(delta)
		"settings_write": _settings_write()
		"settings_read": _settings_read()

# ------------------------------------------------------------------ lifecycle
var _p0 := 0.0
var _tv: AudioStreamPlayer = null
var _tv0 := 0.0
var _tv1 := 0.0
var _p1 := 0.0
var _sfx0 := 0
var _ui0 := 0

func _app() -> Node:
	return get_node_or_null("/root/App")

func _sim_paused() -> bool:
	var app := _app()
	var b = app.get("battle") if app else null
	return b != null and is_instance_valid(b) and b.sim != null and bool(b.sim.paused)

var _next_deploy := 1.0
var _hud: Dictionary = {}
var _cards: Array = []

## Keep a fight going (the scripted player deploys every 1.5 s of battle time) so there are live combat voices.
func _deploy_tick() -> void:
	if _sim_paused(): return
	if _cards.is_empty():
		var app := _app()
		var b = app.get("battle") if app else null
		if b != null and is_instance_valid(b) and b.sim != null: _cards = Array(b.sim.card_ids)
	if bt >= _next_deploy and not _hud.is_empty():
		_next_deploy = bt + 1.0
		for c in _hud.get("cards", []):
			if bool(c.get("ready", false)) and bool(c.get("affordable", false)):
				E.cmd_deploy_unit.emit(str(c.id))
				break

func _lifecycle(delta: float) -> void:
	var app := _app()
	var in_battle := app != null and app.get("battle") != null and is_instance_valid(app.get("battle"))
	if in_battle and not _sim_paused(): bt += delta
	match phase:
		"wait":
			_deploy_tick()
			if in_battle and bt >= 15.0 and _music_player() != null:
				# a long SFX that is certainly playing when the app goes to background (boss warning, 1.8 s)
				_ok("bg_probe_voice_started", A.play(&"boss_incoming"))
				_tv = A._sfx[_last_voice] if _last_voice >= 0 else null
				_p0 = _music_player().get_playback_position()
				_sfx0 = sfx_plays
				_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
				_ok("bg_audio_suspended", A.has_method("is_suspended") and A.is_suspended())
				_ok("bg_master_muted", AudioServer.is_bus_mute(0))
				_ok("bg_battle_paused_by_app", _sim_paused())
				_ok("bg_music_stream_paused", _music_player().stream_paused)
				# only players with an active playback can be paused (Godot reports idle players as not paused)
				var active := 0
				var unpaused := 0
				for p in A._sfx + A._ui:
					if A._voice_busy(p):   # manager bookkeeping; Godot reports a stream_paused player as not playing
						active += 1
						if not p.stream_paused: unpaused += 1
				rep.values.active_players_at_bg = active
				_ok("bg_all_active_sfx_ui_paused", active >= 1 and unpaused == 0)
				_tv0 = _tv.get_playback_position() if _tv else -1.0
				_ok("bg_new_sfx_refused", not A.play(&"hit_mold"))
				_ok("bg_new_ui_refused", not A.play(&"ui_tap"))
				_goto("background")
		"background":
			if phase_t >= 2.0:
				_p1 = _music_player().get_playback_position()
				rep.values.music_pos_before_bg = snappedf(_p0, 0.001)
				rep.values.music_pos_after_2s_bg = snappedf(_p1, 0.001)
				_ok("bg_music_did_not_advance", absf(_p1 - _p0) < 0.15)
				_ok("bg_no_sfx_started", sfx_plays == _sfx0)
				_ok("bg_sfx_voice_held", _tv != null and _tv.stream_paused and absf(_tv.get_playback_position() - _tv0) < 0.1)
				_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
				_ok("resume_master_unmuted", not AudioServer.is_bus_mute(0))
				_ok("resume_music_playing", not _music_player().stream_paused and _music_player().playing)
				_ok("resume_battle_still_paused", _sim_paused())   # App design: player taps resume
				var sfx_held := true
				for p in A._sfx: if A._voice_busy(p) and not p.stream_paused: sfx_held = false
				_ok("resume_sfx_held_while_battle_paused", sfx_held)
				_sfx0 = sfx_plays
				_ui0 = ui_plays
				_goto("pause_screen")
		"pause_screen":
			if phase_t >= 1.0 and not rep.values.has("music_pos_after_1s_resume"):
				var p2 := _music_player().get_playback_position()
				rep.values.music_pos_after_1s_resume = snappedf(p2, 0.001)
				_ok("resume_music_continues_from_same_point", p2 >= _p1 and p2 - _p1 < 1.6)
				A.play(&"ui_tap")   # pause-menu button tap must still sound
			if phase_t >= 2.5:
				_ok("pause_screen_no_sfx_leak", sfx_plays == _sfx0)
				_ok("pause_screen_ui_works", ui_plays > _ui0)
				rep.values.sfx_during_pause_screen = sfx_plays - _sfx0
				E.cmd_set_paused.emit(false)
				_ok("unpause_battle_running", not _sim_paused())
				var running := true
				for p in A._sfx: if A._voice_busy(p) and p.stream_paused: running = false
				_ok("unpause_sfx_players_unpaused", running)
				_tv1 = _tv.get_playback_position() if _tv else -1.0
				rep.values.held_voice_pos_at_unpause = snappedf(_tv1, 0.001)
				_sfx0 = sfx_plays
				_goto("after_unpause")
		"after_unpause":
			_deploy_tick()
			if phase_t >= 0.3 and not rep.checks.has("unpause_held_voice_continues"):
				# the boss warning that was cut by the background continues from where it stopped
				_ok("unpause_held_voice_continues", _tv != null and (not _tv.playing or _tv.get_playback_position() > _tv1))
				rep.values.held_voice_pos_0_3s_after = snappedf(_tv.get_playback_position(), 0.001) if _tv else -1.0
			if phase_t >= 8.0 or (phase_t >= 1.0 and sfx_plays > _sfx0):
				rep.values.sfx_after_unpause = sfx_plays - _sfx0
				rep.values.seconds_until_first_sfx_after_unpause = snappedf(phase_t, 0.1)
				_ok("unpause_combat_sounds_again", sfx_plays > _sfx0)
				_p0 = _music_player().get_playback_position()
				_notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
				_ok("focus_out_suspended", A.has_method("is_suspended") and A.is_suspended() and AudioServer.is_bus_mute(0))
				_ok("focus_out_battle_paused", _sim_paused())
				_goto("focus_out")
		"focus_out":
			if phase_t >= 1.0:
				_ok("focus_out_music_held", absf(_music_player().get_playback_position() - _p0) < 0.15)
				_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				_ok("focus_in_unmuted", not AudioServer.is_bus_mute(0) and not (A.has_method("is_suspended") and A.is_suspended()))
				E.cmd_set_paused.emit(false)
				_ok("focus_in_resume_ok", not _sim_paused())
				_finish()

# ------------------------------------------------------------------ settings
func _settings_write() -> void:
	if t < 1.5 or _done: return
	E.cmd_set_setting.emit("music", 0.3)
	E.cmd_set_setting.emit("sfx", 0.0)
	var save := get_node_or_null("/root/Save")
	rep.values.saved_settings = save.progress.settings.duplicate() if save else {}
	_ok("write_music_applied", absf(AudioServer.get_bus_volume_db(_bus(&"Music")) - linear_to_db(0.09)) < 0.05)
	_ok("write_sfx_muted", AudioServer.is_bus_mute(_bus(&"SFX")) and AudioServer.is_bus_mute(_bus(&"UI")))
	_ok("write_save_has_values", save != null and absf(float(save.progress.settings.get("music", -1)) - 0.3) < 1e-6 and float(save.progress.settings.get("sfx", -1)) == 0.0)
	_finish()

func _settings_read() -> void:
	match phase:
		"wait":
			if t < 1.5: return
			var save := get_node_or_null("/root/Save")
			rep.values.loaded_settings = save.progress.settings.duplicate() if save else {}
			rep.values.music_bus_db = snappedf(AudioServer.get_bus_volume_db(_bus(&"Music")), 0.01)
			_ok("read_music_volume_restored", absf(float(A.get_volume("music")) - 0.3) < 1e-6)
			_ok("read_music_bus_db", absf(AudioServer.get_bus_volume_db(_bus(&"Music")) - linear_to_db(0.09)) < 0.05)
			_ok("read_sfx_restored_muted", float(A.get_volume("sfx")) == 0.0 and AudioServer.is_bus_mute(_bus(&"SFX")) and AudioServer.is_bus_mute(_bus(&"UI")))
			# now music 0 too: the whole output must be digital silence while cues are triggered
			E.cmd_set_setting.emit("music", 0.0)
			_ok("zero_music_bus_muted", AudioServer.is_bus_mute(_bus(&"Music")))
			_rec = AudioEffectRecord.new()
			AudioServer.add_bus_effect(0, _rec)
			_rec.set_recording_active(true)
			for c in [&"ui_tap", &"deploy", &"hit_mold", &"stinger_win"]:
				A.play(c)
			_goto("rec")
		"rec":
			if phase_t >= 0.4 and phase_t < 0.45:
				for c in [&"ui_confirm", &"boss_incoming"]: A.play(c)
			if phase_t >= 2.0:
				_rec.set_recording_active(false)
				var w := _rec.get_recording()
				var peak := 0
				var n := 0
				if w:
					var d := w.data
					n = d.size() / 2
					for i in n:
						var v := d.decode_s16(i * 2)
						if absi(v) > peak: peak = absi(v)
				rep.values.zero_volume_recorded_samples = n
				rep.values.zero_volume_peak_abs = peak
				_ok("zero_volume_output_is_silent", n > 1000 and peak == 0)
				for e in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
					if AudioServer.get_bus_effect(0, e) == _rec: AudioServer.remove_bus_effect(0, e)
				_finish()
