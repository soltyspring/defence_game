extends SceneTree
## Leak attribution for 05-audio. Owner: 05-audio.
##   godot --headless --verbose --path <sandbox> -s res://tools/audio/leak_probe.gd -- --mode=empty|audio|cycle
## empty : quit on the first frame, creates nothing (baseline of autoload/engine exit noise)
## audio : create AudioManager (+bridge), play cues + music, free it, quit
## cycle : 25 create/use/free cycles; checks bus count, Master/Music effect count and object count are bounded
const AudioS := preload("res://src/audio/audio_manager.gd")

var mode := "empty"
var _done := false
var rep := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="): mode = a.get_slice("=", 1)

func _cycle_once() -> void:
	var a: Node = AudioS.new()
	root.add_child(a)
	a.play(&"ui_tap")
	a.play(&"hit_melee")
	a.play_music(&"music_menu", 0.0)
	a.advance(0.1)
	a.play_music(&"music_battle", 0.0)
	a.advance(1.0)
	a.stop_music(0.0)
	a.advance(0.1)
	root.remove_child(a)
	a.free()

var _frame := 0
var _t_prep := 0
const QUIT_WAIT_MS := 300
var _o0 := 0.0
var _b0 := 0
var _fx0 := 0
var _mfx0 := 0

func _process(_d: float) -> bool:
	if _done: return true
	_frame += 1
	rep.mode = mode
	if mode == "cycle":
		# one create/use/free cycle per frame, then idle frames so AudioServer can release playbacks
		if _frame == 1:
			_cycle_once()   # warm-up: first cycle creates buses/effects and loads streams
			return false
		if _frame == 2:
			_o0 = Performance.get_monitor(Performance.OBJECT_COUNT)
			_b0 = AudioServer.bus_count
			_fx0 = AudioServer.get_bus_effect_count(0)
			_mfx0 = AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Music"))
		if _frame <= 26:
			_cycle_once()
			return false
		if _frame < 40:
			return false
		rep.cycles = 25
		rep.object_delta = int(Performance.get_monitor(Performance.OBJECT_COUNT) - _o0)
		rep.bus_count = [_b0, AudioServer.bus_count]
		rep.master_fx = [_fx0, AudioServer.get_bus_effect_count(0)]
		rep.music_fx = [_mfx0, AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Music"))]
		rep.pass = rep.object_delta <= 0 and _b0 == AudioServer.bus_count and _fx0 == rep.master_fx[1] and _mfx0 == rep.music_fx[1]
	elif mode == "audio":
		# single create/use/free, then idle frames before quit (AudioServer releases playbacks per frame)
		if _frame == 1:
			_cycle_once()
			return false
		if _frame == 2:
			_t_prep = Time.get_ticks_msec()
		if _frame < 3 or Time.get_ticks_msec() - _t_prep < QUIT_WAIT_MS:
			return false
	elif mode == "quit_direct" or mode == "quit_prepared":
		# autoload Audio playing battle music, then quit like App --quit-after does
		var au := root.get_node_or_null("Audio")
		if au == null:
			rep.error = "needs Audio autoload (sandbox -Integration)"
		elif _frame == 1:
			au.play_music(&"music_battle", 0.0)
			au.play(&"hit_melee")
			return false
		elif _frame < 10:
			return false
		elif mode == "quit_prepared":
			if _frame == 10:
				au.prepare_quit()
				_t_prep = Time.get_ticks_msec()
				return false
			if Time.get_ticks_msec() - _t_prep < QUIT_WAIT_MS:
				return false   # wall-clock wait: the mixer thread releases stopped playbacks
	_done = true
	print("LEAK_PROBE ", JSON.stringify(rep))
	quit(0 if rep.get("pass", true) else 1)
	return true
