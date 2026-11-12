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
const PAGE := "release_slice"
const SETS := ["base_player", "base_enemy"]
## Characters live on their own page (slice_chars.png), so the battlefield page is not touched when they change.
## Frame names, sizes, pivots, frame counts, fps and hit frames equal assets/atlases/char_player.json.
const CHAR_PAGE := "release_slice_chars"
const CHAR_JSON := "res://assets/art/release_slice/slice_chars.json"
const CHAR_PNG := "res://assets/art/release_slice/slice_chars.png"
const CHAR_SETS := ["hero_captain", "melee_basic", "e_grunt"]

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
	if chars and FileAccess.file_exists(CHAR_JSON):
		if not atlas.pages.has(CHAR_PAGE):
			atlas.pages[CHAR_PAGE] = {"meta": {"id": CHAR_PAGE, "frames": CHAR_JSON, "image": CHAR_PNG, "group": PAGE},
				"frames": {}, "anims": {}, "tex": null, "refs": 0, "loaded": false, "source": "none"}
		if atlas.acquire(CHAR_PAGE):
			var prev_sets: Dictionary = atlas.get_meta("slice_prev_sets")
			for s in CHAR_SETS:
				if not prev_sets.has(s): prev_sets[s] = atlas.anim_sets.get(s, "")
				atlas.anim_sets[s] = CHAR_PAGE
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
	return true

static func restore(atlas) -> void:
	if atlas.has_meta("slice_prev_sets"):
		var prev: Dictionary = atlas.get_meta("slice_prev_sets")
		for s in prev: atlas.anim_sets[s] = prev[s]
		atlas.remove_meta("slice_prev_sets")
	for page in [PAGE, CHAR_PAGE]:
		if atlas.pages.has(page):
			atlas.release(page)
			atlas.pages.erase(page)
	atlas._invalidate_recs()
