extends Node
## Budgets, entity caps and lightweight runtime diagnostics. ENGINE.md §7 (PROVISIONAL). Owner: 02-engine.

const CAP_UNITS_PER_SIDE := 40
const CAP_PROJECTILES := 64
const CAP_FX := 48
const CAP_FLOATING_TEXT := 24
const SIM_STEP := 1.0 / 60.0
const SIM_MAX_STEPS := 4

var _frame_ms := PackedFloat32Array()
var _idx := 0
var sim_ms_last := 0.0
var sim_ms_max := 0.0
var counts := {"units": 0, "projectiles": 0, "fx": 0}
var show_overlay := false

func _ready() -> void:
	_frame_ms.resize(240)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_frame_ms[_idx] = delta * 1000.0
	_idx = (_idx + 1) % _frame_ms.size()

func frame_p95() -> float:
	var a := _frame_ms.duplicate()
	a.sort()
	return a[int(a.size() * 0.95)]

func snapshot() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"frame_ms_p95": frame_p95(),
		"sim_ms": sim_ms_last, "sim_ms_max": sim_ms_max,
		"units": counts.units, "projectiles": counts.projectiles, "fx": counts.fx,
		"tex_mem_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"video_mem_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_mem": Performance.get_monitor(Performance.MEMORY_STATIC),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
	}

func set_fps_cap(cap: int) -> void:
	Engine.max_fps = clampi(cap, 30, 60)
