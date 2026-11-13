extends "res://src/ui/ui_screen.gd"
## Main menu. Owner: 04-client. Emits cmd_start_round (continue), cmd_open_screen(&"round_select").
## Two pages: "title" = 시작하기 / 이어하기 / 설정; 시작하기 opens "lobby" = 라운드 선택 / 강화 (+ 뒤로, shop).
## The lobby is its own screen (기사단 본부): no logo, a header bar (뒤로 · title · gold · shop) and two large cards,
## each with one line under it saying what waits there (next round and stars / how many upgrades the gold buys now).
## The page is remembered for the session, so coming back from round select / shop / a battle lands in the lobby.
static var last_page := "title"
var page := "title"
var btn_start: Control
var btn_back: Control
var btn_play: Control         # 이어하기: the first unlocked round without stars (disabled before any progress)
var btn_select: Control
var btn_settings: Control
var btn_upgrades: Control
var btn_shop: Control
const RosterScreen := preload("res://src/ui/roster.gd")
const TitleBlock := preload("res://src/ui/title_block.gd")
const GoldShopCatalog := preload("res://src/core/gold_shop_catalog.gd")
var title_slot := Rect2()   # QA
var title_page := ""        # atlas page held for the logo (released when the menu leaves the tree)
var settings_panel: Control
var quit_layer: Control
var quit_buttons: Array = []
var _notice := ""

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # menu owns the whole screen
	btn_start = make_button(UiText.t("ui.start"), func(): show_page("lobby"))
	btn_start.fill = UiStyle.C_ACCENT.darkened(0.15)
	btn_start.font_size = UiStyle.FONT_L
	btn_play = make_button(UiText.t("ui.continue"), _on_play)
	btn_select = make_button(UiText.t("ui.select_round"), _on_select)
	btn_select.fill = UiStyle.C_ACCENT.darkened(0.15)
	btn_select.font_size = UiStyle.FONT_L
	btn_upgrades = make_button(UiText.t("ui.upgrades"), open_upgrades)
	btn_upgrades.font_size = UiStyle.FONT_L
	btn_back = make_button(UiText.t("ui.back"), func(): show_page("title"))
	btn_settings = make_button(UiText.t("ui.settings"), _on_settings)
	if GoldShopCatalog.enabled():
		btn_shop = make_button(UiText.t("shop.title"), func(): emit_cmd(&"cmd_open_screen", [&"gold_shop"]))
	settings_panel = SettingsPanel.new()
	settings_panel.hide()
	add_child(settings_panel)
	quit_layer = preload("res://src/ui/dim_layer.gd").new()
	quit_layer.title = UiText.t("ui.quit_confirm")
	quit_layer.hide()
	add_child(quit_layer)
	for d in [["ui.quit", func(): get_tree().quit()], ["ui.cancel", func(): quit_layer.hide()]]:
		var b: Control = TouchButton.new()
		b.text = UiText.t(d[0])
		b.tapped.connect(d[1])
		quit_layer.add_child(b)
		quit_buttons.append(b)
	var s := autoload("Save")
	if s != null and bool(s.get("recovered")):
		_notice = UiText.t("ui.save_recovered")
	notice_dialog = NoticeDialog.new()
	notice_dialog.acknowledged.connect(_on_notice_ack)
	add_child(notice_dialog)
	# 02 52f9fa3: a pending content-migration notice stays in the save until acked; App also emits
	# content_migrated right after mounting the menu. Read it here too, so the order of the two never matters.
	if s != null and s.has_method("migration_notice"):
		var n: Dictionary = s.migration_notice()
		if not n.is_empty():
			_on_content_migrated(n)
	show_page(last_page)
	_refresh_labels()

func show_page(p: String) -> void:
	page = p if p in ["title", "lobby"] else "title"
	last_page = page
	var lobby := page == "lobby"
	for b in [btn_start, btn_play, btn_settings]: b.visible = not lobby
	for b in [btn_select, btn_upgrades, btn_back]: b.visible = lobby
	if btn_shop != null: btn_shop.visible = lobby
	_refresh_labels()
	_layout()
	queue_redraw()

func _bus_links() -> Array:
	return [[&"progress_changed", func(_p): _refresh_labels()], [&"content_migrated", _on_content_migrated]]

## 01 D32 / 02 52f9fa3: show `notice.content_migrated` once; the ack goes out when the player closes it, so a
## player who quits first sees it again on the next launch (the engine keeps it in the save until then).
const NoticeDialog := preload("res://src/ui/notice_dialog.gd")
var notice_dialog: Control
var migration_info := {}          # QA: last notice shown
var migration_acks := 0           # QA: cmd_ack_content_migrated sent
func _on_content_migrated(info: Dictionary) -> void:
	if info.is_empty() or (notice_dialog.visible and info == migration_info):
		return
	migration_info = info.duplicate()
	notice_dialog.text = NoticeDialog.format_notice(info)
	if safe.size.x <= 0.0:
		notice_dialog.visible = true      # read during _build: laid out by the first _layout()
		return
	notice_dialog.open(notice_dialog.text, view, safe, target)

func _on_notice_ack() -> void:
	migration_acks += 1
	emit_cmd(&"cmd_ack_content_migrated", [])

## Round id to start with "play": first unlocked round without stars, else the last unlocked.
func continue_round_id() -> String:
	var list := _round_list()
	if list.is_empty():
		return ""
	var p := progress()
	var stars: Dictionary = p.get("stars", {})
	var pick := str(list[0].id)
	for i in list.size():
		if not s_round_unlocked(i): continue
		pick = str(list[i].id)
		if int(stars.get(pick, 0)) == 0:
			return pick
	return pick

func s_round_unlocked(i: int) -> bool:
	return round_is_unlocked(i)

func _round_list() -> Array:
	var c := autoload("Content")
	if c != null and c.has_method("get_round_list"):
		return c.get_round_list()
	return []

func _refresh_labels() -> void:
	var p := progress()
	var started := int(p.get("unlocked_round", 1)) > 1 or not (p.get("stars", {}) as Dictionary).is_empty()
	btn_play.disabled = not started     # nothing to continue on a fresh save: 시작하기 is the way in
	btn_play.queue_redraw()
	var n := upgrades_ready()
	btn_upgrades.badge = str(n) if n > 0 else ""
	queue_redraw()

## How many upgrades the player can buy right now (unlocked, level gate reached, enough gold). Shown on the 강화 card.
func upgrades_ready() -> int:
	var c := autoload("Content")
	var s := autoload("Save")
	if c == null or s == null or not (c.get("meta") is Dictionary) or not s.has_method("upgrade_cost"):
		return 0
	var coins := int(progress().get("coins", 0))
	var n := 0
	for u in c.meta.get("upgrades", []):
		var id := str(u.get("id", ""))
		if id == "" or s.upgrade_locked(id): continue
		var to := int(s.upgrade_level(id)) + 1
		var cost := int(s.upgrade_cost(id, to))
		if cost >= 0 and cost <= coins and int(s.round_reach()) >= int(s.upgrade_level_unlock_round(id, to)): n += 1
	return n

## [next round number or 0, stars earned, stars possible] for the 라운드 선택 card.
func round_summary() -> Array:
	var list := _round_list()
	var stars: Dictionary = progress().get("stars", {})
	var got := 0
	var next := 0
	for i in list.size():
		var st := int(stars.get(str(list[i].id), 0))
		got += st
		if next == 0 and st == 0 and s_round_unlocked(i): next = int(list[i].get("index", i + 1))
	return [next, got, list.size() * 3]

func _on_play() -> void:
	var id := continue_round_id()
	if id == "":
		emit_cmd(&"cmd_open_screen", [&"round_select"])
	elif RosterScreen.needs_choice(autoload("Content"), autoload("Save")):
		RosterScreen.pending_round = id          # same stop as a round tile: pick who fights, then start
		emit_cmd(&"cmd_open_screen", [&"roster"])
	else:
		emit_cmd(&"cmd_start_round", [id])

func _on_select() -> void:
	emit_cmd(&"cmd_open_screen", [&"round_select"])

func _on_settings() -> void:
	settings_panel.open(bus, progress().get("settings", {}), view, safe, target)

func _exit_tree() -> void:
	title_page = TitleBlock.hold_page(title_page, "")    # release: battle does not keep the logo page
	super._exit_tree()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and quit_layer != null:
		if notice_dialog != null and notice_dialog.visible:
			if claim_back():
				notice_dialog.close()   # back = seen (acked), never opens the quit dialog with the same press
			return
		if settings_panel.visible or modal_open() or not claim_back():
			return   # panel handles it / press already used by the screen that navigated here
		if page == "lobby" and not quit_layer.visible:
			show_page("title")   # back steps out of the lobby first
			return
		quit_layer.visible = not quit_layer.visible

func _layout() -> void:
	if btn_play == null:
		return
	var bw := clampf(safe.size.x * 0.44, 252.0, 300.0)   # title: start + a row of two; lobby: two big buttons
	var bh := maxf(target, 44.0)
	var cx := safe.get_center().x
	var y := safe.position.y + safe.size.y * 0.50
	place(btn_start, Rect2(cx - bw / 2, y, bw, bh + 6))
	var w2 := floorf((bw - 8) / 2.0)    # 8 px between buttons (07 LAYOUT L4 / QA-B027: 8 dp)
	place(btn_play, Rect2(cx - bw / 2, y + bh + 14, w2, bh))
	place(btn_settings, Rect2(cx - bw / 2 + w2 + 8, y + bh + 14, w2, bh))
	# lobby: header row (뒤로 left, shop right), then two large cards centred in what is left, a caption line under each
	var head := bh + 8
	var lw := clampf(safe.size.x * 0.72, 320.0, 520.0)
	var gap := 12.0
	var lw2 := floorf((lw - gap) / 2.0)
	var lh := clampf(safe.size.y - head - 56.0, bh * 2 + 8, 150.0)
	var ly := safe.position.y + head + maxf(8.0, (safe.size.y - head - lh - 28.0) * 0.5)
	place(btn_select, Rect2(cx - lw / 2, ly, lw2, lh))
	place(btn_upgrades, Rect2(cx - lw / 2 + lw2 + gap, ly, lw2, lh))
	place(btn_back, Rect2(safe.position + Vector2(4, 4), Vector2(72, bh)))
	if btn_shop != null:
		place(btn_shop, Rect2(Vector2(safe.end.x - 92, safe.position.y + 4), Vector2(88, bh)))
	place(quit_layer, Rect2(Vector2.ZERO, view))
	quit_layer.title_y = safe.get_center().y - 30
	for i in quit_buttons.size():
		place(quit_buttons[i], Rect2(cx - 124 + i * 128, safe.get_center().y, 120, bh))
	quit_layer.panel = Rect2(Vector2(cx - 140, quit_layer.title_y - 26).round(), Vector2(280, bh + 66).round())
	if settings_panel.visible:
		settings_panel.open(bus, settings_panel.settings, view, safe, target)
	if notice_dialog != null and notice_dialog.visible:
		notice_dialog.open(notice_dialog.text, view, safe, target)

## Pixel menu art (docs/art/release_slice/menu_regen): bakery keep left, mould nest right, quiet centre for the
## logo and buttons. Scaled to cover the view, centred; the scale is a whole number of device pixels per art pixel
## when the screen is scaled up (k >= 2), so the pixels stay even. Old placeholder bands if the file is missing.
const MENU_BG := "res://assets/backgrounds/menu_bg.png"
static var _menu_bg: Texture2D = null

func _draw_background() -> void:
	if _menu_bg == null and ResourceLoader.exists(MENU_BG): _menu_bg = load(MENU_BG)
	var h := view.y
	if _menu_bg != null:
		var ts := Vector2(_menu_bg.get_size())
		var s := maxf(view.x / ts.x, view.y / ts.y)
		var app := autoload("App")
		var k := float(app.pixel_scale) if app != null and app.get("pixel_scale") != null else 1.0
		if k >= 2.0: s = ceilf(s * k) / k
		var size := ts * s
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect(_menu_bg, Rect2(((view - size) * 0.5).round(), size), false)
		draw_rect(Rect2(0, 0, view.x, h * 0.5), Color(0.06, 0.04, 0.10, 0.18))   # a touch darker behind the logo
		return
	var bands := [Color(0.14, 0.18, 0.32), Color(0.18, 0.24, 0.40), Color(0.24, 0.32, 0.48), Color(0.32, 0.40, 0.52)]
	for i in bands.size():
		draw_rect(Rect2(0, i * h * 0.15, view.x, h * 0.15 + 1), bands[i])
	draw_rect(Rect2(0, h * 0.6, view.x, h * 0.4), Color(0.20, 0.36, 0.22))
	draw_rect(Rect2(0, h * 0.82, view.x, h * 0.18), Color(0.36, 0.27, 0.18))

func _draw() -> void:
	_draw_background()
	if page == "lobby":
		_draw_lobby()
		return
	# title slot: between the coin row and the play button; logo (03) or text (title_block.gd)
	var slot_top := safe.position.y + 28
	var first: Control = btn_select if page == "lobby" else btn_start
	var slot_bottom := first.position.y - 22    # leave room for the subtitle line
	title_slot = Rect2(safe.position.x + 8, slot_top, safe.size.x - 16, maxf(40.0, slot_bottom - slot_top))
	var loc := "en" if UiText.t("ui.play") == "Play" else "ko"
	title_page = TitleBlock.hold_page(title_page, loc)   # only this locale's logo page (03 A10); switches with language
	var bottom := TitleBlock.draw(self, title_slot, loc)
	var sub: Array = UiStyle.fit_text(UiText.t("ui.subtitle"), safe.size.x - 16, UiStyle.FONT_M)
	UiStyle.draw_text_centered(self, sub[0], Vector2(safe.get_center().x, minf(bottom + 10, first.position.y - 10)), UiStyle.FONT_M, UiStyle.C_TEXT)
	var p := progress()
	if not UiStyle.draw_ui_icon(self, "icon_gold", Vector2(safe.position.x + 14, safe.position.y + 14)):
		UiStyle.draw_glyph(self, &"coin", Vector2(safe.position.x + 14, safe.position.y + 14), 5)
	UiStyle.draw_number(self, str(int(p.get("coins", 0))), Vector2(safe.position.x + 25, safe.position.y + 14), UiStyle.FONT_M, UiStyle.C_GOLD, -1, &"bold")
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	UiStyle.draw_number(self, "v" + ver, Vector2(safe.end.x - 6, safe.end.y - 10), UiStyle.NUM_READ, UiStyle.C_TEXT_DIM, 1, UiStyle.NUM_READ_KIND)
	if _notice != "":
		UiStyle.draw_text_centered(self, _notice, Vector2(safe.get_center().x, safe.end.y - 24), UiStyle.FONT_S, UiStyle.C_ACCENT)

## Lobby: the menu art pushed back behind a dark sheet, a header band, and what each card leads to.
func _draw_lobby() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(UiStyle.C_BG, 0.82))
	var bh := maxf(target, 44.0)
	var mid_y := safe.position.y + 4 + bh / 2
	draw_rect(Rect2(0, 0, view.x, safe.position.y + bh + 8), Color(0, 0, 0, 0.28))
	UiStyle.draw_text_centered(self, UiText.t("lobby.title", "Hall"), Vector2(safe.get_center().x, mid_y), UiStyle.FONT_L)
	# gold: right side, just left of the shop button (where it is spent), as on round select
	var right := safe.end.x - 8 - (96.0 if btn_shop != null else 0.0)
	var cs := str(int(progress().get("coins", 0)))
	UiStyle.draw_number(self, cs, Vector2(right, mid_y), UiStyle.FONT_M, UiStyle.C_GOLD, 1, &"bold")
	var cw := UiStyle.number_width(cs, UiStyle.FONT_M, &"bold")
	if not UiStyle.draw_ui_icon(self, "icon_gold", Vector2(right - cw - 10, mid_y)):
		UiStyle.draw_glyph(self, &"coin", Vector2(right - cw - 10, mid_y), 5)
	var sum := round_summary()
	var a: String = UiText.t("lobby.next") % int(sum[0]) if int(sum[0]) > 0 else UiText.t("lobby.all_clear")
	a += "  ·  " + UiText.t("lobby.stars") % [int(sum[1]), int(sum[2])]
	var n := upgrades_ready()
	var b: String = UiText.t("lobby.can_upgrade") % n if n > 0 else UiText.t("lobby.no_upgrade")
	var cap_y := btn_select.position.y + btn_select.size.y + 14
	for d in [[btn_select, a, UiStyle.C_TEXT], [btn_upgrades, b, UiStyle.C_GOLD if n > 0 else UiStyle.C_TEXT_DIM]]:
		var line: Array = UiStyle.fit_text(d[1], d[0].size.x, UiStyle.FONT_S)
		UiStyle.draw_text_centered(self, line[0], Vector2(d[0].position.x + d[0].size.x / 2, cap_y), UiStyle.FONT_S, d[2])
