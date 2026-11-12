extends RefCounted
## Connects the release-slice art to a running battle without editing the game: the battle, sim, camera, HUD and
## input stay the game's own. Only pictures change:
##   - atlas page "release_slice" is registered in the Atlas autoload (in memory) and the anim sets base_player /
##     base_enemy point at it, so battle_view._draw_base() draws the new bases through its normal path;
##   - page "release_slice_chars" does the same for hero_captain / melee_basic / e_grunt (apply(..., chars = false)
##     keeps the current characters);
##   - the view's backdrop node is replaced by slice_backdrop.gd (same interface), which also supplies the mill
##     region bakery_supply draws.
## Nothing is written to assets/manifest.json or to any file. restore() puts the Atlas back.
const SliceBackdrop := preload("res://src/art_preview/slice_backdrop.gd")
const HudSkin := preload("res://src/art_preview/hud_skin.gd")
const PAGE := "release_slice"
const SETS := ["base_player", "base_enemy"]
## Characters live on their own page (slice_chars.png), so the battlefield page is not touched when they change.
## Frame names, sizes, pivots, frame counts, fps and hit frames equal assets/atlases/char_player.json.
const CHAR_PAGE := "release_slice_chars"
const CHAR_JSON := "res://assets/art/release_slice/slice_chars.json"
const CHAR_PNG := "res://assets/art/release_slice/slice_chars.png"
const CHAR_SETS := ["hero_captain", "melee_basic", "e_grunt"]
## The other nine regular units (tools/art/release_slice/chars2.py), same contract.
const CHAR2_PAGE := "release_slice_chars2"
const CHAR2_JSON := "res://assets/art/release_slice/slice_chars2.json"
const CHAR2_PNG := "res://assets/art/release_slice/slice_chars2.png"
const CHAR2_SETS := ["worker", "ranged_basic", "tank", "fast", "siege", "e_spitter", "e_swarm", "e_brute", "e_bomber"]

static func apply(app, atlas, chars := true) -> bool:
	if app.battle == null or app.battle.view == null:
		return false
	if not atlas.pages.has(PAGE):
		atlas.pages[PAGE] = {"meta": {"id": PAGE, "frames": SliceBackdrop.ATLAS_JSON, "image": SliceBackdrop.ATLAS_PNG, "group": PAGE},
			"frames": {}, "anims": {}, "tex": null, "refs": 0, "loaded": false, "source": "none"}
	if not atlas.acquire(PAGE):
		return false
	if not atlas.has_meta("slice_prev_sets"):
		var prev := {}
		for s in SETS: prev[s] = atlas.anim_sets.get(s, "")
		atlas.set_meta("slice_prev_sets", prev)
	for s in SETS: atlas.anim_sets[s] = PAGE
	if chars:
		for spec in [[CHAR_PAGE, CHAR_JSON, CHAR_PNG, CHAR_SETS], [CHAR2_PAGE, CHAR2_JSON, CHAR2_PNG, CHAR2_SETS]]:
			if not FileAccess.file_exists(spec[1]): continue
			if not atlas.pages.has(spec[0]):
				atlas.pages[spec[0]] = {"meta": {"id": spec[0], "frames": spec[1], "image": spec[2], "group": PAGE},
					"frames": {}, "anims": {}, "tex": null, "refs": 0, "loaded": false, "source": "none"}
			if atlas.acquire(spec[0]):
				var prev_sets: Dictionary = atlas.get_meta("slice_prev_sets")
				for s in spec[3]:
					if not prev_sets.has(s): prev_sets[s] = atlas.anim_sets.get(s, "")
					atlas.anim_sets[s] = spec[0]
	if chars: _apply_bosses(app, atlas)
	atlas._invalidate_recs()
	var view = app.battle.view
	var sim = app.battle.sim
	var old = view.environment
	var bd = SliceBackdrop.new()
	bd.z_index = -10
	view.add_child(bd)
	bd.build(float(sim.L), float(view.ground_y), str(sim.round_def.biome), float(sim.player_base.x), float(sim.enemy_base.x), int(sim.round_def.get("index", 0)))
	view.environment = bd
	if old != null: old.queue_free()
	if chars:
		var hud = app.get_tree().get_first_node_in_group("battle_hud")
		if hud != null: HudSkin.attach(hud)
	return true

## Six bosses on their own page (tools/art/release_slice/bosses.py). boss_warlord / boss_overlord keep their set ids;
## the four variants that only recoloured those two get their own art sets. Their unit defs are changed in memory
## (anim_set, and visual_tint dropped because the new art carries its own colours); restore() puts them back.
const BOSS_PAGE := "release_slice_bosses"
const BOSS_JSON := "res://assets/art/release_slice/slice_bosses.json"
const BOSS_PNG := "res://assets/art/release_slice/slice_bosses.png"

static func _apply_bosses(app, atlas) -> void:
	if not FileAccess.file_exists(BOSS_JSON): return
	var meta = JSON.parse_string(FileAccess.get_file_as_string(BOSS_JSON))
	if not (meta is Dictionary): return
	if not atlas.pages.has(BOSS_PAGE):
		atlas.pages[BOSS_PAGE] = {"meta": {"id": BOSS_PAGE, "frames": BOSS_JSON, "image": BOSS_PNG, "group": PAGE},
			"frames": {}, "anims": {}, "tex": null, "refs": 0, "loaded": false, "source": "none"}
	if not atlas.acquire(BOSS_PAGE): return
	var prev_sets: Dictionary = atlas.get_meta("slice_prev_sets")
	for s in meta.anims:
		if not prev_sets.has(s): prev_sets[s] = atlas.anim_sets.get(s, "")
		atlas.anim_sets[s] = BOSS_PAGE
	var content = app.battle.sim.content
	var prev_defs := {}
	for unit_id in meta.get("boss_sets", {}):
		if not content.units.has(unit_id): continue
		var d: Dictionary = content.units[unit_id]
		prev_defs[unit_id] = {"anim_set": d.get("anim_set"), "visual_tint": d.get("visual_tint"), "visual_mark_height": d.get("visual_mark_height")}
		d["anim_set"] = meta.boss_sets[unit_id]
		d.erase("visual_tint")
		if d.has("visual_mark_height"):           # the badge sits above the new, taller silhouettes
			d["visual_mark_height"] = 62.0 if str(d.anim_set).ends_with("millward") or str(d.anim_set).ends_with("frostguard") else 78.0
	atlas.set_meta("slice_prev_defs", [content, prev_defs])

static func restore(atlas) -> void:
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		var hud = tree.get_first_node_in_group("battle_hud")
		if hud != null and hud.get_node_or_null("SliceHudSkin") != null:
			var skin = hud.get_node("SliceHudSkin")
			for b in hud.card_buttons + hud.skill_buttons:
				if is_instance_valid(b): b.overlay = Callable()
			skin.queue_free()
	if atlas.has_meta("slice_prev_defs"):
		var pd: Array = atlas.get_meta("slice_prev_defs")
		for unit_id in pd[1]:
			var d: Dictionary = pd[0].units[unit_id]
			d["anim_set"] = pd[1][unit_id].anim_set
			if pd[1][unit_id].visual_tint != null: d["visual_tint"] = pd[1][unit_id].visual_tint
			if pd[1][unit_id].visual_mark_height != null: d["visual_mark_height"] = pd[1][unit_id].visual_mark_height
		atlas.remove_meta("slice_prev_defs")
		if atlas.pages.has(BOSS_PAGE):
			atlas.release(BOSS_PAGE)
			atlas.pages.erase(BOSS_PAGE)
	if atlas.has_meta("slice_prev_sets"):
		var prev: Dictionary = atlas.get_meta("slice_prev_sets")
		for s in prev: atlas.anim_sets[s] = prev[s]
		atlas.remove_meta("slice_prev_sets")
	for page in [PAGE, CHAR_PAGE, CHAR2_PAGE]:
		if atlas.pages.has(page):
			atlas.release(page)
			atlas.pages.erase(page)
	atlas._invalidate_recs()

## Card / enemy portraits redrawn from the new sprites (tools/art/release_slice/ui_portraits.py): a copy of ui_main
## with only the portrait pixels changed. Call before App.start_round so the HUD builds its cards from it.
const UI_PNG := "res://assets/art/release_slice/slice_ui.png"
const UiStyle := preload("res://src/ui/ui_style.gd")

static func apply_ui(atlas) -> bool:
	# Battle cards ask for {"atlas": "ui_main", "frame": "card_*"} directly, so the ui_main page's texture is swapped
	# for the copy (same size, same frame table) while the preview runs.
	if not FileAccess.file_exists(UI_PNG) or not atlas.pages.has("ui_main"): return false
	if not atlas.pages["ui_main"].loaded: atlas.acquire("ui_main")
	if not atlas.has_meta("slice_prev_ui"):
		atlas.set_meta("slice_prev_ui", atlas.pages["ui_main"].tex)
	var tex = SliceBackdrop.load_texture(UI_PNG)
	if tex == null: return false
	atlas.pages["ui_main"].tex = tex
	atlas._invalidate_recs()
	UiStyle.clear_icon_cache()
	return true

static func restore_ui(atlas) -> void:
	if atlas.has_meta("slice_prev_ui"):
		atlas.pages["ui_main"].tex = atlas.get_meta("slice_prev_ui")
		atlas.remove_meta("slice_prev_ui")
		atlas._invalidate_recs()
	UiStyle.clear_icon_cache()
