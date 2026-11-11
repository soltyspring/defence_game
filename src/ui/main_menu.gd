extends "res://src/ui/ui_screen.gd"
## Main menu. Owner: 04-client. Emits cmd_start_round (continue), cmd_open_screen(&"round_select").

var btn_play: Control
var btn_select: Control
var btn_settings: Control
var btn_upgrades: Control
var btn_shop: Control
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
	btn_play = make_button(UiText.t("ui.play"), _on_play)
	btn_play.fill = UiStyle.C_ACCENT.darkened(0.15)
	btn_play.font_size = UiStyle.FONT_L
	btn_select = make_button(UiText.t("ui.select_round"), _on_select)
	btn_upgrades = make_button(UiText.t("ui.upgrades"), open_upgrades)
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
	_refresh_labels()

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
	btn_play.text = UiText.t("ui.continue") if started else UiText.t("ui.play")
	btn_play.queue_redraw()

func _on_play() -> void:
	var id := continue_round_id()
	if id == "":
		emit_cmd(&"cmd_open_screen", [&"round_select"])
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
		quit_layer.visible = not quit_layer.visible

func _layout() -> void:
	if btn_play == null:
		return
	var bw := clampf(safe.size.x * 0.44, 252.0, 300.0)   # play + a row of three (select / upgrades / settings)
	var bh := maxf(target, 44.0)
	var cx := safe.get_center().x
	var y := safe.position.y + safe.size.y * 0.50
	place(btn_play, Rect2(cx - bw / 2, y, bw, bh + 6))
	var w3 := floorf((bw - 16) / 3.0)   # 8 px between the three buttons (07 LAYOUT L4 / QA-B027: 8 dp)
	place(btn_select, Rect2(cx - bw / 2, y + bh + 14, w3, bh))
	place(btn_upgrades, Rect2(cx - bw / 2 + w3 + 8, y + bh + 14, w3, bh))
	place(btn_settings, Rect2(cx - bw / 2 + 2 * (w3 + 8), y + bh + 14, w3, bh))
	if btn_shop != null:
		place(btn_shop, Rect2(Vector2(safe.end.x - 92, safe.position.y + 4), Vector2(88, bh)))
	place(quit_layer, Rect2(Vector2.ZERO, view))
	quit_layer.title_y = safe.get_center().y - 30
	for i in quit_buttons.size():
		place(quit_buttons[i], Rect2(cx - 124 + i * 128, safe.get_center().y, 120, bh))
	if settings_panel.visible:
		settings_panel.open(bus, settings_panel.settings, view, safe, target)
	if notice_dialog != null and notice_dialog.visible:
		notice_dialog.open(notice_dialog.text, view, safe, target)

func _draw() -> void:
	# Background placeholder until 03 ships menu art: sky gradient bands + pixel hills.
	var h := view.y
	var bands := [Color(0.14, 0.18, 0.32), Color(0.18, 0.24, 0.40), Color(0.24, 0.32, 0.48), Color(0.32, 0.40, 0.52)]
	for i in bands.size():
		draw_rect(Rect2(0, i * h * 0.15, view.x, h * 0.15 + 1), bands[i])
	draw_rect(Rect2(0, h * 0.6, view.x, h * 0.4), Color(0.20, 0.36, 0.22))
	var x := 0.0
	while x < view.x:
		var hh := 18.0 + 14.0 * absf(sin(x * 0.013)) + 8.0 * absf(sin(x * 0.041))
		draw_rect(Rect2(x, h * 0.6 - hh, 8, hh), Color(0.16, 0.30, 0.20))
		x += 8
	draw_rect(Rect2(0, h * 0.82, view.x, h * 0.18), Color(0.36, 0.27, 0.18))
	# title slot: between the coin row and the play button; logo (03) or text (title_block.gd)
	var slot_top := safe.position.y + 28
	var slot_bottom := btn_play.position.y - 22    # leave room for the subtitle line
	title_slot = Rect2(safe.position.x + 8, slot_top, safe.size.x - 16, maxf(40.0, slot_bottom - slot_top))
	var loc := "en" if UiText.t("ui.play") == "Play" else "ko"
	title_page = TitleBlock.hold_page(title_page, loc)   # only this locale's logo page (03 A10); switches with language
	var bottom := TitleBlock.draw(self, title_slot, loc)
	var sub: Array = UiStyle.fit_text(UiText.t("ui.subtitle"), safe.size.x - 16, UiStyle.FONT_M)
	UiStyle.draw_text_centered(self, sub[0], Vector2(safe.get_center().x, minf(bottom + 10, btn_play.position.y - 10)), UiStyle.FONT_M, UiStyle.C_TEXT)
	var p := progress()
	if not UiStyle.draw_ui_icon(self, "icon_gold", Vector2(safe.position.x + 14, safe.position.y + 14)):
		UiStyle.draw_glyph(self, &"coin", Vector2(safe.position.x + 14, safe.position.y + 14), 5)
	UiStyle.draw_number(self, str(int(p.get("coins", 0))), Vector2(safe.position.x + 25, safe.position.y + 14), UiStyle.FONT_M, UiStyle.C_GOLD, -1, &"bold")
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	UiStyle.draw_number(self, "v" + ver, Vector2(safe.end.x - 6, safe.end.y - 10), UiStyle.NUM_READ, UiStyle.C_TEXT_DIM, 1, UiStyle.NUM_READ_KIND)
	if _notice != "":
		UiStyle.draw_text_centered(self, _notice, Vector2(safe.get_center().x, safe.end.y - 24), UiStyle.FONT_S, UiStyle.C_ACCENT)
