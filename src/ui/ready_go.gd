extends Control
## Battle start signal: READY drops in, then GO! punches in over a flour burst and flies off (about 1.7 s).
## English words in every language (2026-11-15 user). Art: assets/art/ui/ready_start (tools/art/import_ready_start.py);
## plan: docs/art/release_slice/ready_start_regen/PROMPTS.md. The battle holds sim time until `go` and drives `advance`.
## A tap anywhere jumps straight to GO!.

signal go

const READY := preload("res://assets/art/ui/ready_start/ready.png")
const GO := preload("res://assets/art/ui/ready_start/go.png")
const BURST := preload("res://assets/art/ui/ready_start/burst.png")
const GO_AT := 0.9          # s: READY leaves, GO! lands, the battle clock starts
const LEN := 1.7            # s: everything gone
const SCALE := 2.0          # art pixels -> UI pixels (integer, so the pixels stay square at rest)

var t := 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func finished() -> bool:
	return t >= LEN

## Sim time is held while this is true.
func holding() -> bool:
	return t < GO_AT

func skip() -> void:
	if t < GO_AT: advance(GO_AT - t)

func advance(dt: float) -> void:
	var before := t
	t += dt
	if before < GO_AT and t >= GO_AT:
		mouse_filter = Control.MOUSE_FILTER_IGNORE      # from GO! on, taps reach the HUD again
		go.emit()
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
		skip()
		accept_event()

static func _ease_out_back(x: float) -> float:
	var c := 1.6
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)

func _blit(tex: Texture2D, centre: Vector2, k: float, alpha: float, angle := 0.0) -> void:
	var s := Vector2(tex.get_size()) * SCALE * k
	draw_set_transform(centre.round(), angle, Vector2.ONE)
	draw_texture_rect(tex, Rect2((-s * 0.5).round(), s.round()), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	var view := get_viewport_rect().size
	var cy := roundf(view.y * 0.42)
	var cx := roundf(view.x * 0.5)
	# dim band across the middle: in over 0.15 s, out over the last 0.2 s
	var band := clampf(t / 0.15, 0.0, 1.0) * clampf((LEN - t) / 0.2, 0.0, 1.0)
	draw_rect(Rect2(0, cy - 40, view.x, 80), Color(0.08, 0.05, 0.04, 0.45 * band))
	# READY: falls from above with a small bounce, bobs, then shrinks away as GO! lands
	if t < GO_AT + 0.12:
		var drop := clampf(t / 0.28, 0.0, 1.0)
		var y := cy - 60.0 * (1.0 - _ease_out_back(drop))
		if t >= 0.28 and t < GO_AT: y += roundf(sin((t - 0.28) * 9.0))
		var k := 1.0
		var a := clampf(t / 0.08, 0.0, 1.0)
		if t >= GO_AT:
			var out := (t - GO_AT) / 0.12
			k = 1.0 - 0.6 * out
			a = 1.0 - out
		_blit(READY, Vector2(cx, y), k, a)
	if t >= GO_AT:
		var g := t - GO_AT
		var punch := clampf(g / 0.15, 0.0, 1.0)
		var k := lerpf(1.6, 1.0, punch)                  # lands at exactly 2x art pixels
		var leave := clampf((t - 1.5) / 0.2, 0.0, 1.0)  # flies up and fades
		var y := cy - 50.0 * leave * leave
		var a := 1.0 - leave
		_blit(BURST, Vector2(cx, y), lerpf(0.5, 1.15, punch) + 0.05 * sin(g * 6.0), a * 0.95, sin(g * 3.0) * 0.08)
		_blit(GO, Vector2(cx, y), k, a)
