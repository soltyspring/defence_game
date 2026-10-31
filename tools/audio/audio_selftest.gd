extends SceneTree
## Headless audio subsystem test. Owner: 05-audio.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/audio/audio_selftest.gd
## Exit 0 = pass. Uses the real Events script (src/core/events.gd, read-only) when no autoload exists.
## Headless uses the Dummy audio driver: this verifies logic (pools, limits, stealing, ducking,
## pause, settings, event mapping), NOT audible output or device latency.

const AudioS := preload("res://src/audio/audio_manager.gd")

var fails: PackedStringArray = []
var rep := {}
var A: Node
var E: Node

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)
		printerr("FAIL: ", msg)

var _done := false

func _initialize() -> void:
	E = root.get_node_or_null("Events")
	rep.events_autoload = E != null
	if E == null:
		E = (load("res://src/core/events.gd") as Script).new()
		E.name = "Events"
		root.add_child(E)
	A = root.get_node_or_null("Audio")
	rep.audio_autoload = A != null
	if A == null:
		A = AudioS.new()
		A.name = "Audio"
		root.add_child(A)

## Runs on the first frame, after the added nodes received _ready(). Then stops all audio and waits a few
## frames before quitting so AudioServer can release stopped playbacks (otherwise Godot reports them as
## "leaked at exit"; see leak_probe.gd).
var _quit_frames := -1
var _t_prep := 0

func _process(_delta: float) -> bool:
	if _quit_frames > 0:
		if Time.get_ticks_msec() - _t_prep < 300: return false   # mixer thread releases playbacks
		_quit_frames -= 1
		if _quit_frames == 0:
			if not rep.audio_autoload: A.free()
			if not rep.events_autoload: E.free()
			quit(0 if fails.is_empty() else 1)
		return false
	if _done: return false
	_done = true
	_run()
	rep.snapshot = A.snapshot()
	rep.failures = Array(fails)
	rep.pass = fails.is_empty()
	print(JSON.stringify(rep, " "))
	print("AUDIO SELFTEST ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	A.prepare_quit()
	_t_prep = Time.get_ticks_msec()
	_quit_frames = 1
	return false

func _bus(n: StringName) -> int:
	return AudioServer.get_bus_index(n)

func _run() -> void:
	# --- buses + manifest
	for b in [&"Music", &"SFX", &"UI"]:
		_ok(_bus(b) >= 0, "bus %s missing" % b)
		_ok(AudioServer.get_bus_send(_bus(b)) == &"Master", "bus %s not routed to Master" % b)
	_ok(A.load_errors.is_empty(), "load errors: %s" % str(A.load_errors))
	_ok(A.cues.size() >= 30, "cue count %d" % A.cues.size())
	_ok(A.music_defs.has(&"music_battle") and A.music_defs.has(&"music_menu"), "music defs")
	rep.imported = ResourceLoader.exists("res://assets/audio/sfx/ui_tap.wav")
	rep.resident_sfx_bytes = A.stats.resident_sfx_bytes
	_ok(A.stats.resident_sfx_bytes > 0 and A.stats.resident_sfx_bytes <= 2 * 1024 * 1024, "SFX resident budget")
	# --- every cue plays once
	for cue in A.cues:
		A.advance(5.0)
		_ok(A.play(cue), "cue %s did not start" % cue)
	A.advance(5.0)
	A.stop_all_sfx()
	# --- min gap
	_ok(A.play(&"hit_melee"), "hit_melee first")
	_ok(not A.play(&"hit_melee"), "hit_melee gap not enforced")
	# --- per-cue max instances (explosion: max=2, gap=0.12, ~0.7 s long)
	_ok(A.play(&"explosion"), "explosion 1")
	A.advance(0.13)
	_ok(A.play(&"explosion"), "explosion 2")
	A.advance(0.13)
	_ok(A.cue_instances(&"explosion") == 2, "explosion instances %d" % A.cue_instances(&"explosion"))
	_ok(not A.play(&"explosion"), "explosion max instances not enforced")
	A.advance(5.0)
	# --- pool cap + priority stealing (pool 12). Temporarily lift explosion's per-cue limits.
	var ex: Dictionary = A.cues[&"explosion"]
	var saved := [ex.max, ex.gap]
	ex.max = 99; ex.gap = 0.0
	for i in A.POOL_SFX:
		A.advance(0.001)
		_ok(A.play(&"explosion"), "fill voice %d" % i)
	_ok(A.active_voices() == A.POOL_SFX, "pool not full: %d" % A.active_voices())
	var dv0: int = A.stats.dropped_voices
	var st0: int = A.stats.stolen
	_ok(not A.play(&"gold_tick"), "low-priority cue must not steal (prio 2 < 5)")
	_ok(A.stats.dropped_voices == dv0 + 1, "dropped_voices not counted")
	_ok(A.play(&"skill_slam"), "high-priority cue must steal")
	_ok(A.stats.stolen == st0 + 1, "steal not counted")
	_ok(A.active_voices() == A.POOL_SFX, "pool exceeded after steal")
	_ok(A.play(&"ui_tap"), "UI pool must be independent of SFX pool")
	ex.max = saved[0]; ex.gap = saved[1]
	A.advance(5.0)
	# --- random combat stress: voice count stays within the pool
	var low := [&"hit_melee", &"hit_arrow", &"shoot_arrow", &"shoot_spit", &"death_enemy", &"death_ally", &"gold_tick"]
	var started := 0
	for i in 600:
		A.advance(0.004)
		if A.play(low[i % low.size()]): started += 1
		_ok(A.active_voices() <= A.POOL_SFX, "voices %d > pool" % A.active_voices())
	rep.stress = {"attempts": 600, "started": started, "peak_voices": A.stats.peak_voices}
	A.advance(5.0)
	# --- ducking
	A.advance(10.0)
	_ok(is_equal_approx(A.duck_db(), 0.0), "duck not idle: %f" % A.duck_db())
	A.play(&"boss_incoming")
	for i in 30: A.advance(1.0 / 60.0)
	_ok(A.duck_db() <= -7.5, "boss duck depth %f" % A.duck_db())
	for i in 600: A.advance(1.0 / 60.0)
	_ok(is_equal_approx(A.duck_db(), 0.0), "duck did not release: %f" % A.duck_db())
	# --- pause behaviour
	E.battle_paused.emit(true)
	_ok(A.is_battle_paused(), "battle_paused not applied")
	_ok(not A.play(&"deploy"), "SFX allowed while paused")
	A.advance(1.0)
	_ok(A.play(&"ui_tap"), "UI blocked while paused")
	var mi := _bus(&"Music")
	var lp_on := false
	for e in AudioServer.get_bus_effect_count(mi):
		if AudioServer.get_bus_effect(mi, e) is AudioEffectLowPassFilter and AudioServer.is_bus_effect_enabled(mi, e): lp_on = true
	_ok(lp_on, "music low-pass not enabled during pause")
	E.battle_paused.emit(false)
	_ok(not A.is_battle_paused(), "unpause")
	# --- settings via the real command signal (persistence is Save's job, 02)
	E.cmd_set_setting.emit("music", 0.0)
	_ok(AudioServer.is_bus_mute(mi), "music 0 should mute Music bus")
	E.cmd_set_setting.emit("music", 0.8)
	_ok(not AudioServer.is_bus_mute(mi), "music 0.8 unmute")
	E.cmd_set_setting.emit("sfx", 0.5)
	_ok(absf(AudioServer.get_bus_volume_db(_bus(&"SFX")) - linear_to_db(0.25)) < 0.05, "sfx 0.5 -> -12 dB taper")
	_ok(absf(AudioServer.get_bus_volume_db(_bus(&"UI")) - linear_to_db(0.25)) < 0.05, "UI follows sfx")
	E.cmd_set_setting.emit("sfx", 1.0)
	# --- focus loss mutes Master
	A._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_ok(AudioServer.is_bus_mute(0), "focus out should mute Master")
	A._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_ok(not AudioServer.is_bus_mute(0), "focus in should unmute Master")
	# --- event bridge mapping
	var br: Node = A.bridge
	_ok(br != null, "bridge missing")
	if br == null: return
	E.screen_changed.emit(&"menu", {})
	_ok(A.current_music() == &"music_menu", "menu music: %s" % A.current_music())
	E.screen_changed.emit(&"battle", {"round_id": "r01"})
	_ok(A.current_music() == &"music_battle", "battle music")
	A.advance(5.0)
	var p0: int = A.stats.played
	E.cmd_deploy_unit.emit("melee_basic")
	E.toast.emit("not_enough_gold", {})
	br._flush()
	_ok(A.stats.played == p0 + 1, "failed deploy should only play ui_error (played %d)" % (A.stats.played - p0))
	A.advance(5.0)
	p0 = A.stats.played
	E.cmd_deploy_unit.emit("melee_basic")
	br._flush()
	_ok(A.stats.played == p0 + 1, "successful deploy cue")
	_ok(br.skill_cue("skill_barrage") == &"skill_barrage", "skill kind mapping meteor->barrage: %s" % br.skill_cue("skill_barrage"))
	_ok(br.skill_cue("nope") == &"skill_cast", "unknown skill falls back to skill_cast")
	A.advance(5.0)
	var hud := {"t": 1.0, "gold": 100, "income": 6.0, "player_base": {"hp": 1500}, "enemy_base": {"hp": 1500},
		"army": {"player": 3, "enemy": 4}, "hero": {"alive": true}}
	E.hud_snapshot.emit(hud)
	p0 = A.stats.played
	var hud2 := hud.duplicate(true)
	hud2.t = 1.1; hud2.gold = 112; hud2.enemy_base.hp = 1400; hud2.army.enemy = 3
	E.hud_snapshot.emit(hud2)
	_ok(A.stats.played - p0 == 3, "hud deltas -> base hit + enemy death + gold (got %d)" % (A.stats.played - p0))
	# direct cue disables the derived category (no double playback after integration)
	if not E.has_signal("sfx"):
		E.add_user_signal("sfx", [{"name": "cue", "type": TYPE_STRING_NAME}, {"name": "params", "type": TYPE_DICTIONARY}])
	if not E.is_connected("sfx", br._on_direct): E.connect("sfx", br._on_direct)
	A.advance(5.0)
	E.emit_signal("sfx", &"death_enemy", {"x": 0.0})
	_ok(not br.derived.death, "direct death cue should disable derived deaths")
	_ok(br.resolve(&"shoot", {"projectile": "spit"}) == &"shoot_spit", "semantic shoot->spit")
	_ok(br.resolve(&"hit", {"kind": "ranged"}) == &"hit_arrow", "semantic hit ranged")
	_ok(br.resolve(&"death", {"side": "player"}) == &"death_ally", "semantic death player")
	_ok(br.resolve(&"skill", {"skill": "skill_rally"}) == &"skill_rally", "semantic skill rally")
	# theme v3: victim side picks the material; base side picks bakery tower vs mold hive
	_ok(br.resolve(&"hit", {"kind": "melee", "target_side": "enemy"}) == &"hit_mold", "hit on mold -> hit_mold")
	_ok(br.resolve(&"hit", {"kind": "ranged", "target_side": "player"}) == &"hit_bread", "hit on bread -> hit_bread")
	_ok(br.resolve(&"hit", {"kind": "melee"}) == &"hit_melee", "hit without side -> neutral fallback")
	_ok(br.resolve(&"base_hit", {"side": "enemy"}) == &"hit_base_mold", "enemy base -> hive")
	_ok(br.resolve(&"base_hit", {"side": "player"}) == &"hit_base", "player base -> bakery tower")
	for cue in [&"hit_mold", &"hit_bread", &"hit_base_mold"]:
		_ok(A.cues.has(cue), "manifest missing %s" % cue)
	# v3.1: upgrade results (04 codes) -> four distinct UI cues; unknown code -> ui_error
	var up := {"ok": &"ui_upgrade_ok", "not_enough_coins": &"ui_upgrade_no_coins", "max_level": &"ui_upgrade_max",
		"save_failed": &"ui_upgrade_save_failed", "zzz": &"ui_error"}
	for code in up:
		_ok(br.resolve(&"upgrade_result", {"code": code}) == up[code], "upgrade_result %s -> %s (got %s)" % [code, up[code], br.resolve(&"upgrade_result", {"code": code})])
	var ufiles := {}
	for code in ["ok", "not_enough_coins", "max_level", "save_failed"]:
		ufiles[str(A.cues[up[code]].files[0])] = true
	_ok(ufiles.size() == 4, "upgrade result cues must be 4 different files")
	_ok(br.resolve(&"upgrade_result", {"code": "already_applied"}) == &"", "already_applied must be silent")
	_ok(br.resolve(&"upgrade_result", {"code": "save_uncertain"}) == &"ui_upgrade_save_failed", "save_uncertain -> save_failed cue")
	if E.has_signal("upgrade_result"):
		A.advance(5.0)
		var u0 := int(A.stats.played)
		E.upgrade_result.emit({"id": "up_melee_basic", "to_level": 2, "code": "ok"})
		E.upgrade_result.emit({"id": "up_melee_basic", "to_level": 2, "code": "already_applied"})   # double tap
		_ok(int(A.stats.played) - u0 == 1, "upgrade ok + already_applied -> exactly 1 cue (got %d)" % (int(A.stats.played) - u0))
		A.advance(5.0)
		u0 = int(A.stats.played)
		E.upgrade_result.emit({"id": "up_melee_basic", "to_level": 3, "code": "not_enough_coins"})
		_ok(int(A.stats.played) - u0 == 1, "not_enough_coins -> 1 cue")
	# v3.1: wave_cleared -> exactly one cue per event, a same-frame duplicate emit plays nothing
	if E.has_signal("wave_cleared"):
		A.advance(5.0)
		var wc0 := int(A.stats.played)
		E.wave_cleared.emit({"index": 1, "t": 30.0})
		E.wave_cleared.emit({"index": 1, "t": 30.0})
		_ok(int(A.stats.played) - wc0 == 1, "wave_cleared x2 same frame -> 1 cue (got %d)" % (int(A.stats.played) - wc0))
	A.advance(5.0)
	p0 = A.stats.played
	E.emit_signal("sfx", &"skill", {"skill": "skill_slam"})
	_ok(A.stats.played == p0 + 1 and not br.derived.command, "direct skill plays and disables optimistic command cues")
	# v3.3: ranged/siege hits on faction cues get a pitch offset (ranged x1.15, siege x0.85; cue jitter +-0.08)
	var last := {"cue": &"", "voice": -1}
	var grab := func(cue: StringName, voice: int) -> void:
		last.cue = cue
		last.voice = voice
	A.cue_played.connect(grab)
	for case in [["ranged", 1.15], ["siege", 0.85], ["melee", 1.0]]:
		A.advance(5.0)
		E.emit_signal("sfx", &"hit", {"kind": case[0], "target_side": "enemy", "x": 0.0})
		var ps: float = A._sfx[last.voice].pitch_scale if last.voice >= 0 else -1.0
		_ok(last.cue == &"hit_mold" and absf(ps - case[1]) <= case[1] * 0.081 + 0.001,
			"%s hit on mold: cue %s pitch %.3f, expected %.2f +-8%%" % [case[0], last.cue, ps, case[1]])
	A.cue_played.disconnect(grab)
	if E.has_signal("upgrade_result"):
		A.advance(5.0)
		p0 = A.stats.played
		E.emit_signal("sfx", &"upgrade_result", {"code": "ok"})          # 04 direct path (C5)
		E.upgrade_result.emit({"id": "up_tank", "to_level": 2, "code": "ok"})   # engine reply in the same frame
		_ok(A.stats.played == p0 + 1 and not br.derived.upgrade, "direct upgrade_result disables derived: 1 cue, not 2 (got %d)" % (A.stats.played - p0))
	E.battle_ended.emit({"won": true})
	_ok(A.current_music() == &"", "music stops on battle end")
	# --- cost of play() (CPU proxy; desktop only)
	A.advance(10.0)
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		A.advance(0.002)
		A.play(&"hit_melee")
	rep.play_call_us = snappedf(float(Time.get_ticks_usec() - t0) / 2000.0, 0.01)
