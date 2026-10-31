extends Node
## Audio subsystem: buses, pooled voices, voice limits/stealing, ducking, pause/focus handling,
## settings-driven volumes. Owner: 05-audio. Contract: docs/audio/AUDIO_CONTRACT.md.
## Intended autoload name: `Audio` (res://src/audio/audio_manager.gd) — wiring requested from 02.
## Works without the autoload too (instantiate + add_child); never crashes on missing files.

const MANIFEST := "res://assets/audio/audio_manifest.json"
const BridgeS := preload("res://src/audio/audio_event_bridge.gd")

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

## Mobile voice limits (contract §4). Pools are allocated once; no per-play node allocation.
const POOL_SFX := 12
const POOL_UI := 3
const POOL_STINGER := 1
const DUCK_ATTACK_DB_S := 60.0
const DUCK_RELEASE_DB_S := 14.0
const PAUSE_MUSIC_DB := -6.0
const PAUSE_LOWPASS_HZ := 900.0
const OFFSCREEN_MAX_ATTEN_DB := 5.0      # v3.1: was 9.0; at -9 dB off-screen fights sank under the music (BOSS_ROUND_REPORT A/B)
var offscreen_max_atten_db := OFFSCREEN_MAX_ATTEN_DB
const OFFSCREEN_DROP_SCREENS := 2.0

signal cue_played(cue: StringName, voice: int)

var cues: Dictionary = {}          # cue -> manifest entry (+ "streams": Array[AudioStream])
var music_defs: Dictionary = {}    # id -> manifest entry
var skill_kind_cue: Dictionary = {}
var projectile_cue: Dictionary = {}
var upgrade_result_cue: Dictionary = {}
var load_errors: PackedStringArray = []
var enabled := true

var _sfx: Array[AudioStreamPlayer] = []
var _ui: Array[AudioStreamPlayer] = []
var _stinger: AudioStreamPlayer
var _music: Array[AudioStreamPlayer] = []   # 2 players for crossfade
var _music_cur := -1
var _music_id: StringName = &""
var _music_fade: Array[Dictionary] = [{}, {}]   # per player: {from, to, t, dur, stop}

# per-voice bookkeeping (index aligned with pool arrays)
var _v_cue: Dictionary = {}     # AudioStreamPlayer -> StringName
var _v_prio: Dictionary = {}    # AudioStreamPlayer -> int
var _v_start: Dictionary = {}   # AudioStreamPlayer -> float (clock)
var _v_end: Dictionary = {}     # AudioStreamPlayer -> float (clock)
var _last_play: Dictionary = {} # cue -> clock
## Shared rate limit across related cues (v3.4): manifest "groups": {name: {"min_gap": s}}, cue "group": name.
## Example: hit_bread/hit_mold/hit_melee/hit_arrow share group "hit" so splitting hits by faction does not
## double the hit density. group_gap is a runtime copy (tests may override it).
var group_gap: Dictionary = {}   # group -> min seconds between ANY two cues of the group
var _group_last: Dictionary = {} # group -> clock
var _last_variant: Dictionary = {}

var _clock := 0.0
var _paused := false
var _pause_t0 := 0.0
var _duck_target := 0.0
var _duck_until := 0.0
var _duck_cur := 0.0
var _vol := {"master": 1.0, "sfx": 1.0, "music": 0.8}
var _focus_muted := false
var mute_on_focus_loss := true
var _rng := RandomNumberGenerator.new()
var _bus_idx := {}
var _lowpass_slot := -1
var bridge: Node = null

var stats := {"played": 0, "dropped_gap": 0, "dropped_max": 0, "dropped_voices": 0, "dropped_offscreen": 0, "attenuated_offscreen": 0, "dropped_group": 0,
	"stolen": 0, "missing": 0, "peak_voices": 0, "load_ms": 0, "resident_sfx_bytes": 0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 0x5A0D
	_ensure_buses()
	_build_pools()
	var t0 := Time.get_ticks_msec()
	_load_manifest()
	stats.load_ms = Time.get_ticks_msec() - t0
	_sync_settings_from_save()
	_apply_bus_volumes()
	if get_node_or_null("/root/Events") != null and bridge == null:
		bridge = BridgeS.new()
		bridge.name = "EventBridge"
		add_child(bridge)
		bridge.setup(self, get_node("/root/Events"))

# ---------------------------------------------------------------- setup
func _ensure_buses() -> void:
	for b in [BUS_MUSIC, BUS_SFX, BUS_UI]:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			AudioServer.add_bus()
			i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
		_bus_idx[b] = i
	_bus_idx[&"Master"] = 0
	# Music: low-pass used only while battle is paused (one cheap filter, disabled otherwise).
	var mi: int = _bus_idx[BUS_MUSIC]
	for e in AudioServer.get_bus_effect_count(mi):
		if AudioServer.get_bus_effect(mi, e) is AudioEffectLowPassFilter:
			_lowpass_slot = e
	if _lowpass_slot < 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = PAUSE_LOWPASS_HZ
		AudioServer.add_bus_effect(mi, lp)
		_lowpass_slot = AudioServer.get_bus_effect_count(mi) - 1
	AudioServer.set_bus_effect_enabled(mi, _lowpass_slot, false)
	# Master safety limiter: summed SFX bursts must not clip on device DACs.
	var has_lim := false
	for e in AudioServer.get_bus_effect_count(0):
		var fx := AudioServer.get_bus_effect(0, e)
		if fx != null and fx.get_class() in ["AudioEffectHardLimiter", "AudioEffectLimiter"]:
			has_lim = true
	if not has_lim and ClassDB.class_exists(&"AudioEffectHardLimiter"):
		var lim = ClassDB.instantiate(&"AudioEffectHardLimiter")
		lim.set("ceiling_db", -0.5)
		lim.set("pre_gain_db", 0.0)
		AudioServer.add_bus_effect(0, lim)

func _make_player(bus: StringName, n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p

func _build_pools() -> void:
	if not _sfx.is_empty(): return
	for i in POOL_SFX: _sfx.append(_make_player(BUS_SFX, "Sfx%d" % i))
	for i in POOL_UI: _ui.append(_make_player(BUS_UI, "Ui%d" % i))
	_stinger = _make_player(BUS_MUSIC, "Stinger")
	for i in 2: _music.append(_make_player(BUS_MUSIC, "Music%d" % i))

func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is AudioStream: return r
	# Dev fallback before Godot import has run (not used in exported builds).
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if path.ends_with(".wav"): return AudioStreamWAV.load_from_file(abs_path)
		if path.ends_with(".ogg"): return AudioStreamOggVorbis.load_from_file(abs_path)
	return null

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST):
		load_errors.append("manifest missing")
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(MANIFEST)) != OK or not (j.data is Dictionary):
		load_errors.append("manifest parse error")
		return
	var m: Dictionary = j.data
	skill_kind_cue = m.get("skill_kind_cue", {})
	projectile_cue = m.get("projectile_cue", {})
	for g in m.get("groups", {}):
		group_gap[str(g)] = float(m.groups[g].get("min_gap", 0.0))
	upgrade_result_cue = m.get("upgrade_result_cue", {})
	var pcm := 0
	for cue in m.get("cues", {}):
		var c: Dictionary = m.cues[cue].duplicate()
		var streams: Array[AudioStream] = []
		for f in c.get("files", []):
			var s := _load_stream(str(f))
			if s == null:
				load_errors.append("missing " + str(f))
				continue
			streams.append(s)
			if s is AudioStreamWAV: pcm += (s as AudioStreamWAV).data.size()
		c.streams = streams
		cues[StringName(cue)] = c
	for mid in m.get("music", {}):
		music_defs[StringName(mid)] = m.music[mid]
	stats.resident_sfx_bytes = pcm

# ---------------------------------------------------------------- settings / buses
func _sync_settings_from_save() -> void:
	var save := get_node_or_null("/root/Save")
	if save == null: return
	var p = save.get("progress")
	if p is Dictionary and p.get("settings") is Dictionary:
		apply_settings(p.settings)

## Accepts the Save settings dictionary (keys: sfx, music, optional master). Values 0..1 (bool tolerated).
func apply_settings(s: Dictionary) -> void:
	for k in ["sfx", "music", "master"]:
		if s.has(k): _vol[k] = _to_linear(s[k])
	_apply_bus_volumes()

func set_volume(kind: String, value: Variant) -> void:
	if not _vol.has(kind): return
	_vol[kind] = _to_linear(value)
	_apply_bus_volumes()

func get_volume(kind: String) -> float:
	return float(_vol.get(kind, 0.0))

static func _to_linear(v: Variant) -> float:
	if v is bool: return 1.0 if v else 0.0
	return clampf(float(v), 0.0, 1.0)

## Perceptual taper: slider value v -> gain v^2 (0.5 => -12 dB). 0 mutes the bus.
static func slider_to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v * v)

func _apply_bus_volumes() -> void:
	_set_bus(&"Master", slider_to_db(_vol.master), _vol.master <= 0.001 or _focus_muted)
	_set_bus(BUS_SFX, slider_to_db(_vol.sfx), _vol.sfx <= 0.001)
	_set_bus(BUS_UI, slider_to_db(_vol.sfx), _vol.sfx <= 0.001)
	var mdb := slider_to_db(_vol.music) + _duck_cur + (PAUSE_MUSIC_DB if _paused else 0.0)
	_set_bus(BUS_MUSIC, mdb, _vol.music <= 0.001)

func _set_bus(b: StringName, db: float, mute: bool) -> void:
	var i: int = _bus_idx.get(b, AudioServer.get_bus_index(b))
	if i < 0: return
	AudioServer.set_bus_volume_db(i, maxf(db, -80.0))
	AudioServer.set_bus_mute(i, mute)

# ---------------------------------------------------------------- SFX
func _voice_busy(p: AudioStreamPlayer) -> bool:
	if not _v_end.has(p): return false
	# Expected end time is authoritative (headless/dummy drivers never emit `finished`).
	return _clock < float(_v_end[p]) and (p.playing or _paused or p.stream_paused)

func active_voices(pool: StringName = BUS_SFX) -> int:
	var n := 0
	for p in (_ui if pool == BUS_UI else _sfx):
		if _voice_busy(p): n += 1
	return n

func cue_instances(cue: StringName) -> int:
	var n := 0
	for p in _v_cue:
		if _v_cue[p] == cue and _voice_busy(p): n += 1
	return n

## Play a one-shot cue. params: x (world px, optional distance attenuation), vol_db (additive),
## pitch (multiplier). Returns true if a voice started.
func play(cue: StringName, params: Dictionary = {}) -> bool:
	if not enabled: return false
	var c: Dictionary = cues.get(cue, {})
	if c.is_empty() or (c.streams as Array).is_empty():
		stats.missing += 1
		return false
	var bus: String = c.get("bus", "SFX")
	if _paused and bus == "SFX": return false   # world is frozen; UI/Music still allowed
	var gap := float(c.get("gap", 0.0))
	if _last_play.has(cue) and _clock - float(_last_play[cue]) < gap:
		stats.dropped_gap += 1
		return false
	var grp := str(c.get("group", ""))
	if grp != "" and float(group_gap.get(grp, 0.0)) > 0.0 and _group_last.has(grp) \
			and _clock - float(_group_last[grp]) < float(group_gap[grp]):
		stats.dropped_group += 1
		return false
	if cue_instances(cue) >= int(c.get("max", 1)):
		stats.dropped_max += 1
		return false
	var prio := int(c.get("prio", 1))
	var vol := float(c.get("vol_db", 0.0)) + float(params.get("vol_db", 0.0))
	if params.has("x"):
		var att := _offscreen_atten(float(params.x))
		if att <= -80.0 and prio < 5:
			stats.dropped_offscreen += 1
			return false
		if att < 0.0: stats.attenuated_offscreen += 1
		vol += maxf(att, -offscreen_max_atten_db)
	var p: AudioStreamPlayer
	if bus == "Music":
		p = _stinger
		p.stop()
	else:
		p = _acquire(_ui if bus == "UI" else _sfx, prio)
		if p == null:
			stats.dropped_voices += 1
			return false
	var streams: Array = c.streams
	var vi := 0
	if streams.size() > 1:
		vi = _rng.randi_range(0, streams.size() - 2)
		if vi >= int(_last_variant.get(cue, -1)): vi += 1   # never repeat the same variant twice
	_last_variant[cue] = vi
	var s: AudioStream = streams[vi]
	var jit := float(c.get("pitch", 0.0))
	var pitch := float(params.get("pitch", 1.0)) * (1.0 + (_rng.randf_range(-jit, jit) if jit > 0.0 else 0.0))
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.stream_paused = false
	p.play()
	_v_cue[p] = cue
	_v_prio[p] = prio
	_v_start[p] = _clock
	_v_end[p] = _clock + s.get_length() / p.pitch_scale + 0.02
	_last_play[cue] = _clock
	if grp != "": _group_last[grp] = _clock
	stats.played += 1
	stats.peak_voices = maxi(stats.peak_voices, active_voices())
	var dk := float(c.get("duck", 0.0))
	if dk < 0.0: duck(dk, s.get_length())
	cue_played.emit(cue, _sfx.find(p))
	return true

func _acquire(pool: Array[AudioStreamPlayer], prio: int) -> AudioStreamPlayer:
	var victim: AudioStreamPlayer = null
	for p in pool:
		if not _voice_busy(p): return p
		if victim == null or int(_v_prio[p]) < int(_v_prio[victim]) \
				or (int(_v_prio[p]) == int(_v_prio[victim]) and float(_v_start[p]) < float(_v_start[victim])):
			victim = p
	if victim != null and int(_v_prio[victim]) <= prio:
		victim.stop()
		stats.stolen += 1
		return victim
	return null

## Off-screen policy: 0 dB inside the view; linear to -9 dB at half a screen beyond the edge, -9 dB
## further out (the frontline is often off-screen while the camera follows the hero, and must stay
## audible); returns -80 (drop, low priority only) beyond OFFSCREEN_DROP_SCREENS view widths.
func _offscreen_atten(x: float) -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp else null
	if cam == null: return 0.0
	var half := vp.get_visible_rect().size.x * 0.5
	var d := absf(x - cam.global_position.x) - half
	if d <= 0.0: return 0.0
	if d > OFFSCREEN_DROP_SCREENS * half * 2.0: return -80.0
	return -offscreen_max_atten_db * minf(1.0, d / half)

func stop_all_sfx() -> void:
	for p in _sfx + _ui:
		p.stop()
		_v_end.erase(p)

## Teardown: stop every voice and drop stream references so AudioServer can release its
## playback objects (players freed while playing left AudioStreamPlayback* + stream refs
## alive until exit: reproduced by tools/audio/leak_probe.gd --mode=cycle).
func _exit_tree() -> void:
	for p in _sfx + _ui + _music + ([_stinger] if _stinger else []):
		p.stop()
		p.stream = null
	_v_cue.clear(); _v_prio.clear(); _v_start.clear(); _v_end.clear()
	_music_cur = -1
	_music_id = &""
	_music_fade = [{}, {}]

## Call before SceneTree.quit() and quit >= ~0.3 s later (wall clock, not frames): AudioServer releases
## stopped playbacks asynchronously on its mix thread; one headless frame can be < 1 ms. Without this,
## quitting while music plays reports AudioStreamPlayback*/AudioStreamOggVorbis "leaked at exit"
## (exit-only; process memory is reclaimed by the OS). Reproduced by leak_probe.gd --mode=quit_*.
func prepare_quit() -> void:
	enabled = false   # refuse cues/music queued by the last frames before quit
	_exit_tree()

# ---------------------------------------------------------------- music
func play_music(id: StringName, fade := 0.8) -> void:
	if not enabled: return
	if id == _music_id and _music_cur >= 0 and _music[_music_cur].playing: return
	var d: Dictionary = music_defs.get(id, {})
	if d.is_empty():
		stats.missing += 1
		return
	var s := _load_stream(str(d.file))
	if s == null:
		load_errors.append("missing " + str(d.file))
		return
	if s is AudioStreamOggVorbis: (s as AudioStreamOggVorbis).loop = bool(d.get("loop", true))
	elif s is AudioStreamWAV and bool(d.get("loop", true)):
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int(d.get("loop_samples", 0))
	var nxt := 0 if _music_cur != 0 else 1
	if _music_cur >= 0: _fade(_music_cur, -80.0, fade, true)
	var p := _music[nxt]
	p.stream = s
	p.volume_db = -80.0
	p.play()
	_fade(nxt, float(d.get("vol_db", -8.0)), fade, false)
	_music_cur = nxt
	_music_id = id

func stop_music(fade := 0.8) -> void:
	if _music_cur >= 0: _fade(_music_cur, -80.0, fade, true)
	_music_cur = -1
	_music_id = &""

func current_music() -> StringName:
	return _music_id

func _fade(i: int, to_db: float, dur: float, stop_at_end: bool) -> void:
	_music_fade[i] = {"from": _music[i].volume_db, "to": to_db, "t": 0.0, "dur": maxf(dur, 0.001), "stop": stop_at_end}

# ---------------------------------------------------------------- ducking / pause / focus
## Temporarily lower the Music bus by `db` (negative) for `hold` seconds; deepest request wins.
func duck(db: float, hold: float) -> void:
	if _clock >= _duck_until or db < _duck_target: _duck_target = db
	_duck_until = maxf(_duck_until, _clock + hold)

func set_battle_paused(p: bool) -> void:
	if p == _paused: return
	_paused = p
	if p:
		_pause_t0 = _clock
	else:
		var dt := _clock - _pause_t0
		for v in _v_end: _v_end[v] = float(_v_end[v]) + dt
	for v in _sfx: v.stream_paused = p
	var mi: int = _bus_idx[BUS_MUSIC]
	if _lowpass_slot >= 0: AudioServer.set_bus_effect_enabled(mi, _lowpass_slot, p)
	_apply_bus_volumes()

func is_battle_paused() -> bool:
	return _paused

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if mute_on_focus_loss or what == NOTIFICATION_APPLICATION_PAUSED:
				_focus_muted = true
				_apply_bus_volumes()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_focus_muted = false
			_apply_bus_volumes()

# ---------------------------------------------------------------- tick
func _process(delta: float) -> void:
	advance(delta)

## Advances the audio clock (also used by headless tests).
func advance(delta: float) -> void:
	_clock += delta
	for i in 2:
		var f: Dictionary = _music_fade[i]
		if f.is_empty(): continue
		f.t += delta
		var k := clampf(f.t / f.dur, 0.0, 1.0)
		# fade in dB space with an equal-power-ish curve
		_music[i].volume_db = lerpf(f.from, f.to, sqrt(k) if f.to > f.from else k * k)
		if k >= 1.0:
			if f.stop: _music[i].stop()
			_music_fade[i] = {}
	var tgt := _duck_target if _clock < _duck_until else 0.0
	if tgt == 0.0 and _clock >= _duck_until: _duck_target = 0.0
	if not is_equal_approx(_duck_cur, tgt):
		var rate := DUCK_ATTACK_DB_S if tgt < _duck_cur else DUCK_RELEASE_DB_S
		_duck_cur = move_toward(_duck_cur, tgt, rate * delta)
		_apply_bus_volumes()

func duck_db() -> float:
	return _duck_cur

func snapshot() -> Dictionary:
	var s := stats.duplicate()
	s.active_sfx = active_voices(BUS_SFX)
	s.active_ui = active_voices(BUS_UI)
	s.music = str(_music_id)
	s.duck_db = snf(_duck_cur)
	s.paused = _paused
	s.volumes = _vol.duplicate()
	s.load_errors = Array(load_errors)
	return s

static func snf(v: float) -> float:
	return snappedf(v, 0.01)
