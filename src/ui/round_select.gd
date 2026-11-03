extends "res://src/ui/ui_screen.gd"
## Round (stage) selection. Owner: 04-client.
## Reads Content.get_round_list() + Save.progress (read-only); emits cmd_start_round(id) / cmd_open_screen(&"menu").
## Paged grid (5×2 per page) instead of a scroll view so every tile is a plain tap target.

const COLS := 5
const ROWS := 2

var rounds: Array = []           # [{id,index,name,biome}]
var page := 0
var tiles: Array = []            # TouchButton per visible slot
var btn_back: Control
var btn_upgrades: Control
var btn_prev: Control
var btn_next: Control
var tile_rects: Array[Rect2] = []

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	btn_back = make_button(UiText.t("ui.back"), _on_back)
	btn_upgrades = make_button(UiText.t("ui.upgrades"), open_upgrades)
	btn_back.glyph = &""
	btn_prev = make_button("", func(): _set_page(page - 1))
	btn_prev.glyph = &"left"
	btn_next = make_button("", func(): _set_page(page + 1))
	btn_next.glyph = &"right"
	for i in COLS * ROWS:
		var t: Control = TouchButton.new()
		t.font_size = UiStyle.FONT_S
		t.wrap_lines = 2
		t.tapped.connect(_on_tile.bind(i))
		add_child(t)
		tiles.append(t)
	reload()

func _bus_links() -> Array:
	return [[&"progress_changed", func(_p): _refresh()]]

func ui_setup(params: Dictionary) -> void:
	if params.get("rounds") is Array:
		rounds = params.rounds
		_refresh()

func reload() -> void:
	var c := autoload("Content")
	if c != null and c.has_method("get_round_list"):
		rounds = c.get_round_list()
	# open on the page containing the newest unlocked round
	var latest := 0
	for i in rounds.size():
		if is_round_unlocked(i): latest = i
	page = clampi(latest / (COLS * ROWS), 0, _pages() - 1)
	_refresh()

func _pages() -> int:
	return maxi(1, ceili(rounds.size() / float(COLS * ROWS)))

func _set_page(p: int) -> void:
	page = clampi(p, 0, _pages() - 1)
	_refresh()

func is_round_unlocked(order_index: int) -> bool:
	return round_is_unlocked(order_index)

func _refresh() -> void:
	if tiles.is_empty():
		return
	var stars: Dictionary = progress().get("stars", {})
	for i in tiles.size():
		var idx := page * COLS * ROWS + i
		var t: Control = tiles[i]
		if idx >= rounds.size():
			t.hide()
			continue
		t.show()
		var r: Dictionary = rounds[idx]
		var unlocked := is_round_unlocked(idx)
		t.text = UiText.name_of("round", str(r.id), str(r.get("name", "")))
		t.disabled = not unlocked
		t.glyph = &"" if unlocked else &"lock"
		t.icon = null if unlocked else UiStyle.ui_icon("icon_lock")
		t.badge = ""
		t.set_meta("stars", int(stars.get(str(r.id), 0)))
		t.set_meta("number", int(r.get("index", idx + 1)))
		t.fill = UiStyle.C_PANEL_LIGHT if unlocked else UiStyle.C_DISABLED
		t.queue_redraw()
	btn_prev.visible = page > 0
	btn_next.visible = page < _pages() - 1
	queue_redraw()

func _on_tile(slot: int) -> void:
	var idx := page * COLS * ROWS + slot
	if idx >= rounds.size() or not is_round_unlocked(idx):
		return
	emit_cmd(&"cmd_start_round", [str(rounds[idx].id)])

func _on_back() -> void:
	emit_cmd(&"cmd_open_screen", [&"menu"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and btn_back != null and not modal_open() and claim_back():
		emit_cmd_deferred(&"cmd_open_screen", [&"menu"])

func _layout() -> void:
	if btn_back == null:
		return
	var t := maxf(target, 40.0)
	place(btn_back, Rect2(safe.position + Vector2(4, 4), Vector2(72, t)))
	place(btn_upgrades, Rect2(Vector2(safe.end.x - 4 - 80, safe.position.y + 4), Vector2(80, t)))
	var top := safe.position.y + t + 12
	var bottom := safe.end.y - 6
	var side := t + 10
	var area := Rect2(safe.position.x + side, top, safe.size.x - side * 2, bottom - top)
	var gap := 8.0   # 8 dp between tiles (07 LAYOUT L4)
	var tw := floorf((area.size.x - gap * (COLS - 1)) / COLS)
	var th := floorf((area.size.y - gap * (ROWS - 1)) / ROWS)
	tile_rects.clear()
	for i in tiles.size():
		var cx := i % COLS
		var cy := i / COLS
		var r := Rect2(area.position.x + cx * (tw + gap), area.position.y + cy * (th + gap), tw, th)
		tile_rects.append(r)
		place(tiles[i], r)
	place(btn_prev, Rect2(safe.position.x + 4, area.get_center().y - t / 2, t, t))
	place(btn_next, Rect2(safe.end.x - 4 - t, area.get_center().y - t / 2, t, t))
	_refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), UiStyle.C_BG)
	UiStyle.draw_text_centered(self, UiText.t("ui.select_round"), Vector2(safe.get_center().x, safe.position.y + 4 + maxf(target, 40.0) / 2), UiStyle.FONT_L)
	var p := progress()
	# coins right-aligned just left of the upgrades button (where they are spent)
	var cxr := safe.end.x - 4 - 80 - 8
	var cs := str(int(p.get("coins", 0)))
	UiStyle.draw_number(self, cs, Vector2(cxr, safe.position.y + 24), UiStyle.FONT_M, UiStyle.C_GOLD, 1, &"bold")
	var cw := UiStyle.number_width(cs, UiStyle.FONT_M, &"bold")
	if not UiStyle.draw_ui_icon(self, "icon_gold", Vector2(cxr - cw - 10, safe.position.y + 24)):
		UiStyle.draw_glyph(self, &"coin", Vector2(cxr - cw - 10, safe.position.y + 24), 5)

## Overlay drawn on top of each tile (number + stars) via TouchButton.overlay.
func _ready() -> void:
	super._ready()
	for t in tiles:
		t.overlay = _draw_tile_overlay

func _draw_tile_overlay(t: Control) -> void:
	var n := int(t.get_meta("number", 0))
	UiStyle.draw_number(t, str(n), Vector2(t.size.x / 2, 16), UiStyle.FONT_L, UiStyle.C_TEXT if not t.disabled else UiStyle.C_TEXT_DIM, 0, &"bold")
	if not t.disabled:
		var st := int(t.get_meta("stars", 0))
		for k in 3:
			var sc := Vector2(t.size.x / 2 + (k - 1) * 18, t.size.y - 30)
			UiStyle.draw_star_marker(t, sc, k < st, 5.5)
