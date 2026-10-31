extends Node
## Maps the `Events` signal bus (INTERFACES.md §1) to audio cues. Owner: 05-audio.
## Contract: docs/audio/AUDIO_CONTRACT.md §3.
## Two sources:
##  1. Direct cues: `Events.sfx(cue, params)` if 02 adds that signal (requested). Authoritative.
##  2. Derived cues from existing signals (commands, toasts, HUD snapshot deltas). Each derived
##     category switches itself off the first time a direct cue of that category arrives, so
##     there is never double playback once 02/04 integrate.

const ERROR_TOASTS := ["not_enough_gold", "army_full", "on_cooldown", "not_enough_mana", "worker_max",
	"unknown", "locked", "round_locked", "no_target", "hero_dead_skill"]

## category -> cues that, when received directly, disable the derived version
const CATEGORIES := {
	"ui": [&"ui_tap", &"ui_back", &"ui_confirm", &"ui_error"],
	"command": [&"deploy", &"worker_buy", &"skill_slam", &"skill_rally", &"skill_barrage", &"skill_heal", &"skill_cast"],
	"death": [&"death_ally", &"death_enemy"],
	"base": [&"hit_base", &"hit_base_mold"],
	"gold": [&"gold_tick"],
	"hero": [&"hero_death", &"hero_respawn"],
	"alert": [&"wave_incoming", &"boss_incoming"],
	"milestone": [&"wave_cleared"],
}

var audio: Node
var ev: Node
var derived := {"ui": true, "command": true, "death": true, "base": true, "gold": true, "hero": true, "alert": true, "milestone": true}
var screen: StringName = &""
var in_battle := false
var _pending: Array = []      # [cue, category]
var _pending_cancel := false
var _flush_queued := false
var _prev := {}               # previous hud snapshot values
var _skill_kind := {}         # skill_id -> kind

func setup(p_audio: Node, p_events: Node) -> void:
	audio = p_audio
	ev = p_events
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c(&"screen_changed", _on_screen)
	_c(&"battle_started", _on_battle_started)
	_c(&"battle_ended", _on_battle_ended)
	_c(&"battle_paused", _on_battle_paused)
	_c(&"toast", _on_toast)
	_c(&"hud_snapshot", _on_hud)
	_c(&"progress_changed", _on_progress)
	_c(&"cmd_deploy_unit", func(_id): _queue(&"deploy", "command"))
	_c(&"cmd_buy_worker", func(): _queue(&"worker_buy", "command"))
	_c(&"cmd_hero_skill", func(id): _queue(skill_cue(str(id)), "command"))
	_c(&"cmd_start_round", func(_id): _ui(&"ui_confirm"))
	_c(&"cmd_retry", func(): _ui(&"ui_confirm"))
	_c(&"cmd_next_round", func(): _ui(&"ui_confirm"))
	_c(&"cmd_open_screen", func(s): _ui(&"ui_back" if StringName(s) == &"menu" else &"ui_tap"))
	_c(&"cmd_set_paused", func(_p): _ui(&"ui_tap"))
	_c(&"cmd_set_setting", _on_setting)
	_c(&"wave_cleared", _on_wave_cleared)   # 02 v1.4 (22d99ea): once per scripted wave, never after a loss
	_c(&"sfx", _on_direct)   # requested from 02 (AUDIO_CONTRACT §3.1); absent signal is fine

func _c(sig: StringName, f: Callable) -> void:
	if ev.has_signal(sig) and not ev.is_connected(sig, f):
		ev.connect(sig, f)

func skill_cue(skill_id: String) -> StringName:
	var kind := str(_skill_kind.get(skill_id, ""))
	if kind == "":
		var content := get_node_or_null("/root/Content")
		if content and content.get("skills") is Dictionary and content.skills.has(skill_id):
			kind = str(content.skills[skill_id].get("kind", ""))
	return StringName(audio.skill_kind_cue.get(kind, "skill_cast"))

# ------------------------------------------------------------ direct cues
## Accepts concrete cue ids from the manifest OR semantic engine events (contract §3.1):
##   &"hit" {kind: melee|ranged|siege}, &"shoot" {projectile}, &"death" {side: "player"|"enemy"},
##   &"base_hit" {side}, &"skill" {skill}, &"explosion".
func resolve(cue: StringName, params: Dictionary) -> StringName:
	match cue:
		&"hit":
			# Theme v3: the VICTIM decides the material (bread crunches, mold squishes). Needs
			# params.target_side from 02 (request A9); without it, fall back to the neutral cues.
			var ts := str(params.get("target_side", ""))
			if ts == "enemy" and audio.cues.has(&"hit_mold"): return &"hit_mold"
			if ts == "player" and audio.cues.has(&"hit_bread"): return &"hit_bread"
			return &"hit_arrow" if str(params.get("kind", "melee")) == "ranged" else &"hit_melee"
		&"shoot":
			return StringName(audio.projectile_cue.get(str(params.get("projectile", "arrow")), "shoot_arrow"))
		&"death":
			return &"death_ally" if str(params.get("side", "enemy")) == "player" else &"death_enemy"
		&"base_hit":
			# enemy base = mold hive (wet), player base = bakery tower (dry)
			if str(params.get("side", "")) == "enemy" and audio.cues.has(&"hit_base_mold"): return &"hit_base_mold"
			return &"hit_base"
		&"skill":
			return skill_cue(str(params.get("skill", "")))
		&"upgrade_result":
			# 04 upgrade_panel result code -> cue (manifest upgrade_result_cue); key name proposed to 04 (C5)
			var m: Dictionary = audio.get("upgrade_result_cue") if audio.get("upgrade_result_cue") is Dictionary else {}
			return StringName(m.get(str(params.get("code", "")), "ui_error"))
	return cue

func _on_direct(cue: StringName, params: Dictionary) -> void:
	var c := resolve(cue, params)
	for cat in CATEGORIES:
		if derived[cat] and CATEGORIES[cat].has(c):
			derived[cat] = false
	if c == &"hit_base" and str(params.get("side", "")) == "enemy":
		params = params.merged({"pitch": 1.12, "vol_db": -2.0})   # only if hit_base_mold is absent
	audio.play(c, params)

# ------------------------------------------------------------ derived cues
func _ui(cue: StringName) -> void:
	if derived.ui: audio.play(cue)

## Command feedback is optimistic: the engine handles the command synchronously and emits an
## error toast on failure, so we wait until the end of the frame and drop the cue if one arrived.
func _queue(cue: StringName, cat: String) -> void:
	if not derived[cat] or not in_battle or audio.is_battle_paused(): return
	_pending.append([cue, cat])
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()

func _flush() -> void:
	_flush_queued = false
	if not _pending_cancel:
		for p in _pending:
			if derived[p[1]]: audio.play(p[0])
	_pending.clear()
	_pending_cancel = false

func _on_toast(key: String, _args: Dictionary) -> void:
	if ERROR_TOASTS.has(key) or (key == "hero_dead" and not _pending.is_empty()):
		if not _pending.is_empty(): _pending_cancel = true
		_ui(&"ui_error")
		return
	match key:
		"wave_incoming":
			if derived.alert: audio.play(&"wave_incoming")
		"boss_incoming":
			if derived.alert: audio.play(&"boss_incoming")
		"counterattack": audio.play(&"wave_incoming", {"pitch": 0.85})
		"hero_dead":
			if derived.hero: audio.play(&"hero_death")
		"save_recovered": _ui(&"ui_error")

func _on_screen(s: StringName, _params: Dictionary) -> void:
	screen = s
	match s:
		&"menu", &"round_select":
			in_battle = false
			audio.set_battle_paused(false)
			audio.play_music(&"music_menu")
		&"battle":
			in_battle = true
			audio.play_music(&"music_battle")
		&"result":
			in_battle = false

func _on_battle_started(info: Dictionary) -> void:
	in_battle = true
	_prev.clear()
	_skill_kind.clear()
	var content := get_node_or_null("/root/Content")
	for sk in info.get("skills", []):
		var id := str(sk.get("id", ""))
		if content and content.get("skills") is Dictionary and content.skills.has(id):
			_skill_kind[id] = str(content.skills[id].get("kind", ""))
	audio.set_battle_paused(false)
	audio.play_music(&"music_battle")

func _on_battle_ended(result: Dictionary) -> void:
	in_battle = false
	audio.set_battle_paused(false)
	audio.stop_music(0.25)
	audio.play(&"stinger_win" if bool(result.get("won", false)) else &"stinger_defeat")

## One cue per Events.wave_cleared (every wave; 04 shows its banner for wave 1 only). The 1.0 s cue gap and
## the "milestone" category make a later direct Events.sfx(&"wave_cleared") from 04 replace this, not double it.
func _on_wave_cleared(_info: Dictionary) -> void:
	if derived.milestone and in_battle: audio.play(&"wave_cleared")

func _on_battle_paused(p: bool) -> void:
	audio.set_battle_paused(p)

func _on_setting(key: String, value: Variant) -> void:
	if key in ["sfx", "music", "master"]:
		audio.set_volume(key, value)
	_ui(&"ui_tap")

func _on_progress(p: Dictionary) -> void:
	if p.get("settings") is Dictionary: audio.apply_settings(p.settings)

## HUD snapshot deltas (10 Hz): base damage, deaths (army count drops), bounty gold, hero state.
func _on_hud(s: Dictionary) -> void:
	if not in_battle: return
	var pb := float(s.get("player_base", {}).get("hp", 0.0))
	var eb := float(s.get("enemy_base", {}).get("hp", 0.0))
	var ap := int(s.get("army", {}).get("player", 0))
	var ae := int(s.get("army", {}).get("enemy", 0))
	var gold := float(s.get("gold", 0.0))
	var alive := bool(s.get("hero", {}).get("alive", true))
	if not _prev.is_empty():
		if derived.base and (pb < _prev.pb - 0.5):
			audio.play(&"hit_base", {"vol_db": 1.0})
		elif derived.base and (eb < _prev.eb - 0.5):
			audio.play(resolve(&"base_hit", {"side": "enemy"}))
		if derived.death and ae < _prev.ae: audio.play(&"death_enemy")
		if derived.death and ap < _prev.ap: audio.play(&"death_ally")
		# bounty: gold rose more than ~0.1 s of income (+1 rounding slack)
		var inc := float(s.get("income", 0.0)) * (float(s.get("t", 0.0)) - float(_prev.t)) + 1.0
		if derived.gold and gold - float(_prev.gold) > maxf(inc, 1.0) and ae < _prev.ae:
			audio.play(&"gold_tick")
		if derived.hero and alive and not _prev.alive:
			audio.play(&"hero_respawn")
	_prev = {"pb": pb, "eb": eb, "ap": ap, "ae": ae, "gold": gold, "alive": alive, "t": float(s.get("t", 0.0))}
