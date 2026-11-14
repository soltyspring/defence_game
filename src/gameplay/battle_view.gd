extends Node2D
## Immediate-mode renderer for BattleSim: one CanvasItem, atlas frames when available,
## procedural pixel placeholders otherwise. Owner: 02-engine.

const SimS := preload("res://src/gameplay/battle_sim.gd")
const PixelCamera := preload("res://src/gameplay/pixel_camera.gd")
const Supply := preload("res://src/gameplay/bakery_supply.gd")
const Backdrop := preload("res://src/gameplay/lane_backdrop.gd")

var sim                     # battle_sim.gd instance
var atlas                   # Atlas autoload (may be null in tests)
var ground_y := 290.0
var biome := "meadow"
var cam_x := 320.0
var view_w := 640.0
var world_zoom := 1.0
var device_scale := 1.0
var render_ahead := 0.0
var _formation_targets := {}
var _formation_slots := {} # uid -> permanent row / sticky column
var _formation_conflicts := {}
var _formation_offsets := {}
var _render_positions := {}
var _formation_timer := 0.0
var _variant_marks: Array = []
var _crowd_badges: Array = []
var view_top := 0.0       # world y at the top of the screen (integer scale may show more than 360 px)
var view_bottom := 360.0
var show_damage := true
var _order: Array = []
var _font: Font
var _num_font: Font
const NUM_FONT_PATH := "res://assets/fonts/Galmuri9.ttf"   # 03 bundled OFL font; digits only, native 10 px
const NUM_PX := 10
var _biome_layers: Array = []
var _biome_atlas := ""
var environment: Node2D

const C_PLAYER := Color("4a7fd4")
const C_PLAYER_D := Color("2c4f8c")
const C_ENEMY := Color("c8483f")
const C_ENEMY_D := Color("7d2a25")
const C_SKIN := Color("f1c79a")
const C_HERO := Color("f2c14e")
const C_OUTLINE := Color("1a1c24")
const C_BAR_PLAYER := Color("63cbe8")
const C_BAR_ENEMY := Color("ef9255")

var _by_lane_y := func(a, b):
	var ay: float = _unit_pos(a).y
	var by: float = _unit_pos(b).y
	return ay < by if not is_equal_approx(ay,by) else a.uid < b.uid
var _bar_rects: Array[Rect2] = []      # queued hp bars: outline rect, fill rect, colour (drawn in _flush_bars)
var _bar_fills: Array[Rect2] = []
var _bar_cols: Array[Color] = []

func setup(p_sim, p_atlas, p_ground_y: float, p_biome: String) -> void:
	sim = p_sim
	atlas = p_atlas
	ground_y = p_ground_y
	biome = p_biome
	environment = Backdrop.new()
	environment.z_index = -10
	add_child(environment)
	environment.build(float(sim.L), ground_y, biome, float(sim.player_base.x), float(sim.enemy_base.x), int(sim.round_def.get("index", 0)))
	_font = ThemeDB.fallback_font
	_num_font = _font
	if ResourceLoader.exists(NUM_FONT_PATH):
		var nf = load(NUM_FONT_PATH)
		if nf is Font:
			_num_font = nf
	_biome_layers = []
	if atlas and atlas.manifest.get("biomes", {}).has(biome):
		var b: Dictionary = atlas.manifest.biomes[biome]
		_biome_atlas = str(b.get("atlas", ""))
		_biome_layers = b.get("layers", [])

func _process(_dt: float) -> void:
	_update_formation(0.0 if sim != null and (sim.paused or sim.ended) else _dt)
	_track_vfx(0.0 if sim == null or sim.paused else _dt)
	if environment and sim:
		var boss = null
		for e in sim.enemies:
			if e.is_boss and not e.dying:
				boss = e
				break
		if boss != null: environment.live_update(true, boss.x, boss.def.has("link_break"), boss.link_src != 0, boss.exposed_t, 0.0 if sim.paused or sim.ended else _dt)
		else: environment.live_update(false, 0.0, false, false, 0.0, _dt)
		environment.present(cam_x, world_zoom, device_scale, float(sim.t))
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	_draw_background()
	_draw_base(sim.player_base, 1)
	_draw_base(sim.enemy_base, -1)
	_draw_workers()
	# depth sort: higher lane_y (closer) drawn last
	_order.clear()
	for u in sim.players: _order.append(u)
	for u in sim.enemies: _order.append(u)
	if sim.hero_respawn <= 0.0: _order.append(sim.hero)
	_order.sort_custom(_by_lane_y)
	_variant_marks.clear()
	# Grounding shadows are one shape pass, rather than a texture/shape switch per unit.
	_halo_a = 0.5 if _bright_chapter() else 0.3
	for u in _order:
		if u.dying: continue
		var foot := _unit_pos(u)
		# stepped oval contact shadow (was a faint 14x2 bar that vanished on snow)
		var w := 8.0 + 4.0 * float(u.def.get("size", 1.0)) + (4.0 if u.is_hero else 0.0)
		var sc := Color(0.06, 0.06, 0.09, 0.30 + _halo_a * 0.4)
		draw_rect(Rect2(foot + Vector2(-w, -1), Vector2(w * 2, 2)), sc)
		draw_rect(Rect2(foot + Vector2(-w + 3, 1), Vector2(w * 2 - 6, 1)), sc)
	_draw_telegraph_zones()
	_draw_links()
	_state_marks.clear()
	_mark_rects.clear()
	for u in _order:
		_draw_unit(u)
	for u in _variant_marks: _draw_variant(u)
	for u in _state_marks: _draw_state_mark(u)
	for badge in _crowd_badges:
		if not _render_positions.has(badge.uid): continue
		var bp := Vector2((_render_positions[badge.uid] as Vector2).x-20*badge.side,ground_y-52)
		var label := "x%d" % int(badge.count)
		draw_string(_num_font,bp+Vector2(1,1),label,HORIZONTAL_ALIGNMENT_LEFT,-1,NUM_PX,C_OUTLINE)
		draw_string(_num_font,bp,label,HORIZONTAL_ALIGNMENT_LEFT,-1,NUM_PX,Color("efda9b"))
	_flush_bars()   # all hp bars after all sprites: one batch of rects instead of breaking sprite batches (08 H2)
	for p in sim.projectiles:
		if p.alive: _draw_projectile(p)
	for f in sim.fxs:
		if f.alive and f.kind != "telegraph": _draw_fx(f)
	if atlas: _draw_vfx()
	_draw_telegraphs()
	if show_damage:
		_placed_text.clear()
		_placed_text.append_array(_mark_rects)   # damage numbers stagger around wind-up wedges instead of covering them
		var live := {}
		for tx in sim.texts:
			if tx.alive:
				live[tx.serial] = true
				if tx.uid < 0: _feed_base_combo(tx)   # base hits: one running total per base (drawn below)
		_draw_base_combos(live)
		for tx in sim.texts:
			if tx.alive and tx.uid >= 0: _draw_text(tx)
		for serial in _text_offsets.keys():
			if not live.has(serial): _text_offsets.erase(serial)

func _unit_pos(u) -> Vector2:
	return _render_positions.get(u.uid,Vector2(roundf(u.x),roundf(ground_y+u.lane_y)))

func _update_formation(dt: float) -> void:
	if sim == null: return
	var all: Array = []
	all.append_array(sim.players)
	all.append_array(sim.enemies)
	if sim.hero_respawn <= 0: all.append(sim.hero)
	var row_counts := {1:[0,0,0],-1:[0,0,0]}
	for u in all:
		if _formation_slots.has(u.uid):
			row_counts[u.side][_formation_slots[u.uid].x] += 1
	var born := {}
	for u in all:
		if u.is_hero or u.is_boss or _formation_slots.has(u.uid): continue
		var row := 0
		for r in range(1,3):
			if row_counts[u.side][r] < row_counts[u.side][row]: row = r
		_formation_slots[u.uid] = Vector2i(row,0)
		row_counts[u.side][row] += 1
		born[u.uid] = true
	_formation_timer -= dt
	if _formation_timer <= 0 or not born.is_empty():
		var interval := maxf(dt,0.15)
		_formation_timer = 0.15
		_crowd_badges.clear()
		# The oldest occupant owns its place. New arrivals use vacancies; survivors
		# never change rows or collapse forward when someone dies/leaves the pack.
		# A unit changes column only once it has STOPPED (or was just born) and an older, stopped unit of its row
		# is drawn on top of it (drawn x closer than FORM_OVERLAP) for 0.3 s. The former rule compared column
		# NUMBERS of everyone within 32 px, walking or not, so units that marched 28 px apart, walked past each
		# other or hovered around the 32 px edge kept being re-seated (tools/qa/formation_mirror.py: 42 -> 13).
		for u in all:
			if u.is_hero or u.is_boss or u.dying: continue
			var slot: Vector2i = _formation_slots[u.uid]
			var is_born: bool = born.has(u.uid)
			var occupied := PackedFloat32Array()
			var same_count := 0
			var leader: int = u.uid
			for other in all:
				if other.side != u.side or other.is_hero or other.is_boss or other.dying: continue
				if absf(other.x-u.x) < 32 and other.id == u.id:
					same_count += 1
					leader = mini(leader,other.uid)
				if other.uid < u.uid and absf(other.x-u.x) < FORM_REACH and _formation_slots[other.uid].x == slot.x and (is_born or other.state != SimS.S_WALK):
					occupied.append(drawn_x(other.x,other.side,_formation_slots[other.uid].y))
			var blocked: bool = (is_born or u.state != SimS.S_WALK) and column_blocked(drawn_x(u.x,u.side,slot.y),occupied)
			var conflict := float(_formation_conflicts.get(u.uid,0.0)) + interval if blocked else 0.0
			_formation_conflicts[u.uid] = conflict
			if blocked and (is_born or conflict >= 0.3):
				var col := free_column(u.x,u.side,slot.y,occupied)
				if col >= 0:
					slot.y = col
					_formation_slots[u.uid] = slot
					_formation_conflicts[u.uid] = 0.0
			if same_count >= 6 and leader == u.uid:
				_crowd_badges.append({"uid":u.uid,"side":u.side,"count":same_count})
	_render_positions.clear()
	_formation_targets.clear()
	var live := {}
	for u in all:
		live[u.uid] = true
		var target := Vector2.ZERO
		if _formation_slots.has(u.uid):
			var slot: Vector2i = _formation_slots[u.uid]
			target = Vector2(-u.side*slot.y*FORM_COL_STEP,-slot.x*10.0-u.lane_y)
		_formation_targets[u.uid] = target
		var offset: Vector2 = _formation_offsets.get(u.uid,target)
		offset.x = move_toward(offset.x,target.x,30.0*dt)
		offset.y = target.y # permanent row: no up/down re-ranking or bobbing
		_formation_offsets[u.uid] = offset
		_render_positions[u.uid] = Vector2(PixelCamera.world_position(u.x+offset.x,world_zoom,device_scale),PixelCamera.world_position(ground_y+u.lane_y+offset.y,world_zoom,device_scale))
	for cache in [_formation_offsets,_formation_slots,_formation_conflicts]:
		for uid in cache.keys():
			if not live.has(uid): cache.erase(uid)

const FORM_COL_STEP := 9.0   # drawn px between two columns of one row
const FORM_OVERLAP := 7.0    # same-row sprites drawn closer than this cover each other
const FORM_COLS := 7
const FORM_REACH := FORM_COL_STEP * FORM_COLS + FORM_OVERLAP   # farther units can never be drawn on top

## Drawn x of a unit standing at sim x in column `col` (columns trail behind the unit's facing).
static func drawn_x(x: float, side: int, col: int) -> float:
	return x - side * col * FORM_COL_STEP

static func column_blocked(here: float, occupied: PackedFloat32Array) -> bool:
	for ox in occupied:
		if absf(ox - here) < FORM_OVERLAP:
			return true
	return false

## Nearest column to `current` whose drawn x is clear of `occupied` (drawn x of older row mates); -1 = none.
static func free_column(x: float, side: int, current: int, occupied: PackedFloat32Array) -> int:
	for step in FORM_COLS:
		for dirn in [1, -1]:
			var col: int = current + step * dirn
			if col < 0 or col >= FORM_COLS or (step == 0 and dirn < 0):
				continue
			if not column_blocked(drawn_x(x, side, col), occupied):
				return col
	return -1

# ---------------- background ----------------
func _draw_background() -> void:
	if environment != null: return
	var left := cam_x - view_w * 0.5 - 8.0
	var w := view_w + 16.0
	if not _biome_layers.is_empty() and atlas and _draw_biome_layers(left, w, false):
		return
	var pal := _biome_palette()
	# sky bands
	var bands := 6
	var band_h := (ground_y - view_top) / float(bands)
	for i in bands:
		var c: Color = pal.sky_top.lerp(pal.sky_bottom, float(i) / (bands - 1))
		draw_rect(Rect2(left, view_top - 8.0 + i * band_h, w, band_h + 9.0), c)
	# far hills (parallax 0.3)
	var off := cam_x * 0.7
	var step := 96.0
	var x0 := floorf((left - off) / step) * step + off - step
	var x := x0
	while x < left + w + step:
		var h := 40.0 + fposmod(x * 0.37, 30.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, ground_y - 40), Vector2(x + step * 0.5, ground_y - 40 - h), Vector2(x + step, ground_y - 40)]), pal.hill_far)
		x += step
	# near hills (parallax 0.6)
	off = cam_x * 0.4
	step = 64.0
	x = floorf((left - off) / step) * step + off - step
	while x < left + w + step:
		var h2 := 18.0 + fposmod(x * 0.53, 22.0)
		draw_rect(Rect2(x, ground_y - 30.0 - h2 * 0.5, step * 0.9, 30.0 + h2 * 0.5), pal.hill_near)
		x += step
	# ground
	draw_rect(Rect2(left, ground_y - 12.0, w, 4.0), pal.grass_top)
	draw_rect(Rect2(left, ground_y - 8.0, w, maxf(90.0, view_bottom - ground_y + 16.0)), pal.ground)
	var gx := floorf(left / 16.0) * 16.0
	while gx < left + w:
		draw_rect(Rect2(gx + fposmod(gx * 0.7, 9.0), ground_y + 10.0 + fposmod(gx * 0.31, 30.0), 2, 2), pal.ground_dot)
		gx += 16.0

func _draw_biome_layers(left: float, w: float, front: bool) -> bool:
	var drew := false
	for layer in _biome_layers:
		if (str(layer.get("z", "")) == "front") != front:
			continue
		var f: Dictionary = atlas.frame(_biome_atlas, str(layer.get("frame", "")))
		if f.is_empty():
			continue
		if not drew and not front and layer.has("clear_color"):
			draw_rect(Rect2(left, view_top - 8.0, w, view_bottom - view_top + 16.0), Color(str(layer.clear_color)))
		drew = true
		var par := float(layer.get("parallax", 1.0))
		var r: Rect2 = f.rect
		var y: float
		if layer.has("lane_line"):
			y = ground_y - float(layer.lane_line)
		else:
			y = float(layer.get("view_y", ground_y - r.size.y))
		if front:
			# Foreground belongs to the lane, not the bottom of the HUD. The old fixed
			# y=342 left bright wheat fragments across the last rows of the window.
			y = ground_y - r.size.y + 4.0
		var tile_w := r.size.x
		# Align the layer once to the camera's device-pixel grid, then step copies by
		# exact tile widths. Whole-world rounding disagrees with zoom 3/2 and 4/3;
		# independently rounding copies can also open a seam around negative origins.
		var bx := PixelCamera.layer_origin(cam_x, par, world_zoom, device_scale)
		var x := floorf((left - bx) / tile_w) * tile_w + bx
		while x < left + w:
			draw_texture_rect_region(f.tex, Rect2(x, y, tile_w, r.size.y), r)
			if layer.has("lane_line") and y + r.size.y < view_bottom + 8.0:
				# Continue the soil below its 80px tile on taller views / below the HUD.
				var tail := Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0)
				draw_texture_rect_region(f.tex, Rect2(x, y + r.size.y, tile_w, view_bottom + 8.0 - y - r.size.y), tail)
			x += tile_w
	return drew

func _biome_palette() -> Dictionary:
	match biome:
		"forest", "biome_02":
			return {"sky_top": Color("2b4a5e"), "sky_bottom": Color("8fb8a8"), "hill_far": Color("2f5a46"), "hill_near": Color("244a38"),
				"grass_top": Color("4f8a3a"), "ground": Color("4a3a2a"), "ground_dot": Color("5d4a36")}
		"desert", "biome_03":
			return {"sky_top": Color("e89a5a"), "sky_bottom": Color("f6d7a0"), "hill_far": Color("c9925a"), "hill_near": Color("b47c48"),
				"grass_top": Color("d9b06a"), "ground": Color("b58a52"), "ground_dot": Color("a07846")}
		_:
			return {"sky_top": Color("4f7cc4"), "sky_bottom": Color("b9dcf2"), "hill_far": Color("6aa86a"), "hill_near": Color("4f8f4f"),
				"grass_top": Color("6cbf4a"), "ground": Color("6b4f34"), "ground_dot": Color("7d5d3e")}

# ---------------- bases ----------------
## Each chapter of ten rounds has its own enemy nest (assets/art/gpt/gpt_nest_cNN, ChatGPT sheets).
static func nest_set(round_index: int) -> String:
	return "base_enemy_c%02d" % clampi((maxi(round_index, 1) - 1) / 10 + 1, 1, 10)

func _draw_base(b: Dictionary, side: int) -> void:
	var x: float = b.x
	var key := "player" if side == 1 else "enemy"
	if atlas:
		var bm: Dictionary = atlas.manifest.get("bases", {}).get(key, {})
		if not bm.is_empty():
			var ratio: float = b.hp / b.hp_max
			var st := "idle" if ratio > 0.5 else ("damaged" if ratio > 0.0 else "ruined")
			var rec = null
			if side < 0:
				# the chapter nest art already faces left (toward our army): never flipped
				var ns := nest_set(int(sim.round_def.get("index", 0)))
				rec = atlas.anim_rec(ns, st)
				if rec != null:
					var bi0: int = atlas.rec_index(rec, sim.t)
					_blit_rec(rec, bi0, Vector2(x, ground_y), false, Color(1, 0.6, 0.6) if b.flash > 0.0 else Color.WHITE)
					return
			if bm.has("anim_set"):
				rec = atlas.anim_rec(str(bm.anim_set), st)
				if rec == null: rec = atlas.anim_rec(str(bm.anim_set), "idle")
			if rec != null:
				var mod0 := Color(1, 0.6, 0.6) if b.flash > 0.0 else Color.WHITE
				var bi: int = atlas.rec_index(rec, sim.t)
				_blit_rec(rec, bi, Vector2(x, ground_y), side < 0 and bool(bm.get("flip", false)), mod0)
				return
			var f: Dictionary = atlas.frame(str(bm.get("atlas", "")), str(bm.get("frame", "")))
			if not f.is_empty():
				var mod := Color(1, 0.6, 0.6) if b.flash > 0.0 else Color.WHITE
				_blit(f, Vector2(x, ground_y), side < 0 and bool(bm.get("flip", false)), mod)
				return
	var main := C_PLAYER if side == 1 else C_ENEMY
	var dark := C_PLAYER_D if side == 1 else C_ENEMY_D
	if b.flash > 0.0:
		main = main.lightened(0.4)
	var bw := 44.0
	var bh := 70.0
	var r := Rect2(x - bw * 0.5, ground_y - bh, bw, bh)
	draw_rect(r.grow(1.0), C_OUTLINE)
	draw_rect(r, Color("8a8f9c"))
	draw_rect(Rect2(r.position.x, r.position.y, bw, 8), Color("6d7280"))
	for i in 4:  # crenellations
		draw_rect(Rect2(r.position.x + i * 12.0, r.position.y - 8.0, 8.0, 8.0), Color("8a8f9c"))
	draw_rect(Rect2(x - 7.0, ground_y - 20.0, 14.0, 20.0), Color("3a2a1e"))
	# banner
	draw_rect(Rect2(x - 1.0, r.position.y - 28.0, 2.0, 20.0), C_OUTLINE)
	draw_rect(Rect2(x + (1.0 if side == 1 else -13.0), r.position.y - 28.0, 12.0, 8.0), main)
	draw_rect(Rect2(x - 12.0, ground_y - 50.0, 24.0, 10.0), dark)

func _draw_workers() -> void:
	Supply.draw(self, sim, atlas, ground_y)

# ---------------- units ----------------
func _anim_name(u) -> String:
	if not u.dying and (not u.ab.is_empty() or u.exposed_t > 0.0):
		if u.heavy_t >= 0.0: return "heavy_prepare"
		if u.fire_t >= 0.0: return "heavy_release"
		if u.recover_t > 0.0:
			return "heavy_release" if float(u.ab.get("recover", 2.0)) - u.recover_t < 0.20 and str(u.ab.get("kind", "slam")) != "vent" else "heavy_exposed"
		if u.exposed_t > 0.0: return "heavy_exposed"
	match u.state:
		SimS.S_WALK: return "walk"
		SimS.S_ATTACK: return "attack"
		SimS.S_DYING: return "death"
	return "idle"

# ---- chapter 4 readouts: link strands, wind-up and weak-point marks ----
var _state_marks: Array = []
var _mark_rects: Array[Rect2] = []      # wind-up wedges drawn this frame

## A sagging strand from every living link source to each unit it protects, drawn under the units.
func _draw_links() -> void:
	var sources := {}
	for e in sim.enemies:
		if not e.dying and e.def.has("link"): sources[e.uid] = e
	if sources.is_empty(): return
	for e in sim.enemies:
		if e.dying or e.link_src == 0 or not sources.has(e.link_src): continue
		var s = sources[e.link_src]
		var a: Vector2 = _unit_pos(s) + Vector2(0, -float(s.def.get("visual_mark_height", 20.0)) - 5.0)
		var b: Vector2 = _unit_pos(e) + Vector2(0, -14.0 * float(e.def.get("size", 1.0)))
		var line := PackedVector2Array([a, (a + b) * 0.5 + Vector2(0, 6.0), b])
		draw_polyline(line, C_OUTLINE, 3.0)
		draw_polyline(line, Color("8fd6cf"), 1.0)

## Wind-up: a wedge over the head that grows until the hit. Exposed (recovering / link cut): an open pale ring at
## chest height. Both keep the unit's own colours, so they also read in greyscale by shape.
func _draw_state_mark(u) -> void:
	if u.hidden:
		# Keep the mound behind sprites, but place a small surface marker above
		# their feet. X stays on the real burrow path, not a formation offset.
		var p := Vector2(roundf(u.x), ground_y - 25.0)
		draw_line(p + Vector2(0, 5), Vector2(p.x, ground_y - 4.0), C_OUTLINE, 3.0)
		draw_rect(Rect2(p + Vector2(0, 6), Vector2(1, 13)), Color("ebcfab"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-6), p+Vector2(8,0), p+Vector2(0,6), p+Vector2(-8,0)]), C_OUTLINE)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4), p+Vector2(5,0), p+Vector2(0,4), p+Vector2(-5,0)]), Color("ebcfab"))
		_mark_rects.append(Rect2(p - Vector2(8,6), Vector2(16,12)))
		return
	var pos := _unit_pos(u)
	var size := float(u.def.get("size", 1.0))
	if u.heavy_t >= 0.0 and str(u.ab.get("kind", "slam")) == "vent":
		return      # opening its own shell is not a danger to announce
	if u.heavy_t >= 0.0:
		var total := maxf(0.1, float(u.ab.get("windup", 1.2)))
		var k := 1.0 - clampf(u.heavy_t / total, 0.0, 1.0)
		var w := 4.0 + 5.0 * k
		var p := pos + Vector2(0, -float(u.def.get("visual_mark_height", 26.0)) - 12.0 - 3.0 * size)
		_mark_rects.append(Rect2(p.x - w - 3.0, p.y - w - 3.0, w * 2.0 + 6.0, w + 8.0))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-w - 2, -w - 2), p + Vector2(w + 2, -w - 2), p + Vector2(0, 4)]), C_OUTLINE)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-w, -w), p + Vector2(w, -w), p + Vector2(0, 1)]), Color("bff3ee"))
	elif u.exposed_t > 0.0:
		var c := pos + Vector2(0, -11.0 * size)
		var r := 5.0 * size + 1.5 * sin(u.exposed_t * 12.0)
		draw_arc(c, r + 1.0, 0, TAU, 16, C_OUTLINE, 3.0)
		draw_arc(c, r + 1.0, 0, TAU, 16, Color("fff0b0"), 1.0)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), Color("fff0b0"))

## A burrowed unit: only the moving mound and the clods it leaves behind.
func _draw_burrow_trail(u) -> void:
	var pos := Vector2(roundf(u.x), ground_y)
	var wob := sin(u.anim_t * 14.0)
	for i in 4:
		var c := pos + Vector2(-u.side * (9.0 + i * 9.0), 0.0)
		var s := 4.0 - i * 0.8
		draw_rect(Rect2(c + Vector2(-s, -s * 0.6), Vector2(s * 2.0, s * 0.9)), Color(0.36, 0.30, 0.22, 0.85 - i * 0.18))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-10, 1), pos + Vector2(-6, -5 - wob), pos + Vector2(0, -7 + wob), pos + Vector2(6, -5 - wob), pos + Vector2(10, 1)]), C_OUTLINE)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-8, 0), pos + Vector2(-5, -3 - wob), pos + Vector2(0, -5 + wob), pos + Vector2(5, -3 - wob), pos + Vector2(8, 0)]), Color("8c7a5c"))
	draw_rect(Rect2(pos + Vector2(-2, -4 + wob), Vector2(4, 2)), Color("8fd6cf"))

const HALO_OFFSETS := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
var _halo_a := 0.3

## Snow, ice and aurora chapters (R21-30, R41-50, R61-70, R81-90): light ground, so stronger halo and shadow.
func _bright_chapter() -> bool:
	var idx := int(sim.round_def.get("index", 0)) if sim != null else 0
	return idx > 0 and ((idx - 1) / 10) in [2, 4, 6, 8]

func _draw_unit(u) -> void:
	if u.hidden and not u.dying:
		_draw_burrow_trail(u)
		_state_marks.append(u)
		return
	var pos := _unit_pos(u)
	if not u.dying:
		if u.heavy_t >= 0.0:
			_state_marks.append(u)
		elif u.exposed_t > 0.0:
			_state_marks.append(u)
	var flip: bool = u.side < 0
	if u.is_hero:
		flip = sim.hero_dir < 0
		# High-contrast pointer keeps the controlled hero identifiable in crowds,
		# including when bread-coloured sprites pass the bakery facade.
		var marker := pos + Vector2(0, -44)
		draw_colored_polygon(PackedVector2Array([marker + Vector2(-5,-5), marker + Vector2(5,-5), marker + Vector2(0,2)]), C_OUTLINE)
		draw_colored_polygon(PackedVector2Array([marker + Vector2(-3,-4), marker + Vector2(3,-4), marker]), Color("ffe7a0"))
	var mod := Color.WHITE
	# Heavy green silhouettes otherwise merge into the dark mold nest during the final push.
	# Keep their hue and animation while lifting their value above that background.
	# With the v2 lane set the ground behind the nest is light, so the boss keeps its own colours.
	if u.is_boss and not (environment != null and environment.v2): mod = Color(3.0, 3.0, 3.0)
	elif u.id == "e_brute": mod = Color(1.15, 1.15, 1.15)
	if u.def.has("visual_tint"):
		mod = Color(str(u.def.visual_tint)) * (1.4 if u.is_boss else 1.15)
		mod.a = 1.0
	if not u.dying and str(u.def.get("visual_mark","")) != "": _variant_marks.append(u)
	# Hit flash: a warm BRIGHTENING. The former Color(1, 0.55, 0.55) multiplied grey-green enemies down to a dark
	# maroon, so a unit under focus fire (flashing most of the time) lost its colours and merged with its neighbours.
	if u.flash > 0.0: mod = Color(1.5, 1.12, 1.12)
	if u.dying: mod.a = clampf(u.dead_t / 0.7, 0.0, 1.0)
	elif u.buff_t > 0.0 and u.buff_mul < 1.0: mod = mod * Color(0.7, 0.85, 1.3)     # frost cream: chilled blue
	elif u.buff_t > 0.0: mod = mod * Color(1.0, 1.0, 0.8)
	var drawn := false
	if atlas:
		var rec = atlas.anim_rec(u.anim_set, _anim_name(u))
		var t: float = u.anim_t
		if rec == null and u.state == SimS.S_IDLE:
			rec = atlas.anim_rec(u.anim_set, "walk")
			t = 0.0
		if rec != null:
			var fi: int = atlas.rec_index(rec, t)
			if not u.dying:   # 1-px dark halo: keeps light units (white hero, pale bread) readable on snow and ice
				var hc := Color(0.05, 0.05, 0.08, _halo_a)
				for off in HALO_OFFSETS: _blit_rec(rec, fi, pos + off, flip, hc)
			_blit_rec(rec, fi, pos, flip, mod)
			drawn = true
			if not u.dying:
				_hp_bar(pos + Vector2(0, -rec.rects[fi].size.y - 3.0), 12.0 + 4.0 * float(u.def.get("size", 1.0)), u.hp / u.hp_max, u.side)
				if u.shield > 0.0:     # sugar barrier: a pink line over the HP bar, as long as the shield is strong
					var bw := 12.0 + 4.0 * float(u.def.get("size", 1.0))
					var sw := bw * clampf(u.shield / maxf(1.0, u.hp_max), 0.0, 1.0)
					draw_rect(Rect2(pos + Vector2(-bw * 0.5, -rec.rects[fi].size.y - 6.0), Vector2(sw, 2.0)), Color(1.0, 0.72, 0.86))
	if not drawn:
		_draw_placeholder(u, pos, flip, mod)

func _draw_variant(u) -> void:
	var pos := _unit_pos(u)
	var mark := str(u.def.get("visual_mark",""))
	# Atlas cells contain transparent padding above the head. These anchors were
	# measured from opaque walk pixels relative to the foot pivot, not cell height.
	var h := float(u.def.get("visual_mark_height",26.0))
	if mark == "thrall":
		# two back stalks with bulbs + a block fist held low in front: reads as "heavy hitter" without the sprite
		for dx in [5.0, 10.0]:
			var top := pos + Vector2(-u.side * dx, -h - (9.0 if dx > 6.0 else 4.0))
			draw_rect(Rect2(top + Vector2(-2, 0), Vector2(4, 12)), C_OUTLINE)
			draw_rect(Rect2(top + Vector2(-1, 1), Vector2(2, 11)), Color("6d857f"))
			draw_rect(Rect2(top + Vector2(-3, -4), Vector2(6, 6)), C_OUTLINE)
			draw_rect(Rect2(top + Vector2(-2, -3), Vector2(4, 4)), Color("93ada2"))
		var fist := pos + Vector2(u.side * 11.0, -12.0)
		draw_rect(Rect2(fist + Vector2(-4, -4), Vector2(9, 10)), C_OUTLINE)
		draw_rect(Rect2(fist + Vector2(-3, -3), Vector2(7, 8)), Color("54726f"))
		draw_rect(Rect2(fist + Vector2(-3, -3), Vector2(7, 2)), Color("93ada2"))
		return
	if mark == "binder":
		# a knot ring floating over the head; the strands start here
		var kc := pos + Vector2(0, -h - 5.0)
		draw_arc(kc, 5.0, 0, TAU, 12, C_OUTLINE, 4.0)
		draw_arc(kc, 5.0, 0, TAU, 12, Color("8fd6cf"), 2.0)
		draw_rect(Rect2(kc - Vector2(1, 1), Vector2(3, 3)), Color("e4fbf6"))
		return
	if mark == "core":
		# the nest core: a diamond over the crown that opens (pale) while the boss is exposed
		var cc := pos + Vector2(0, -h - 4.0)
		var open: bool = u.exposed_t > 0.0
		var rr := 8.0 if open else 6.0
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -rr - 2), cc + Vector2(rr + 2, 0), cc + Vector2(0, rr + 2), cc + Vector2(-rr - 2, 0)]), C_OUTLINE)
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -rr), cc + Vector2(rr, 0), cc + Vector2(0, rr), cc + Vector2(-rr, 0)]), Color("fff0b0") if open else Color("5fa5a6"))
		if not open: draw_rect(Rect2(cc - Vector2(1, 3), Vector2(3, 6)), Color("bff3ee"))
		return
	if mark == "shield" or mark == "warden":
		var scale_px := 2.0 if mark == "warden" else 1.0
		var p := pos + Vector2(u.side * 10, -13) * scale_px
		draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-4)*scale_px,p+Vector2(6,-4)*scale_px,p+Vector2(6,6)*scale_px,p+Vector2(0,11)*scale_px,p+Vector2(-6,6)*scale_px]), C_OUTLINE)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-4,-2)*scale_px,p+Vector2(4,-2)*scale_px,p+Vector2(4,5)*scale_px,p+Vector2(0,8)*scale_px,p+Vector2(-4,5)*scale_px]), Color("688b88"))
		draw_rect(Rect2(p+Vector2(-1,-2)*scale_px,Vector2(2,8)*scale_px),Color("a2c9ba"))
	if mark == "spore":
		var p := pos+Vector2(0,-h)
		draw_rect(Rect2(p+Vector2(-8,-2),Vector2(16,4)),C_OUTLINE)
		draw_rect(Rect2(p+Vector2(-6,-4),Vector2(12,4)),Color("d1b6ec"))
		draw_rect(Rect2(p+Vector2(-2,-6),Vector2(4,3)),Color("f0e7ff"))
	elif mark == "runner":
		var p := pos+Vector2(-u.side*5,-h+3)
		draw_rect(Rect2(p,Vector2(8,3)),Color("a8ccbe"))
		draw_rect(Rect2(p+Vector2(-u.side*3,3),Vector2(6,2)),Color("698d88"))
	elif mark in ["root","frost","ember","warden"]:
		var p := pos+Vector2(0,-h+5)
		var crown: PackedVector2Array
		var color: Color
		match mark:
			"frost":
				crown = PackedVector2Array([Vector2(-14,0),Vector2(-11,-10),Vector2(-6,-5),Vector2(0,-16),Vector2(5,-5),Vector2(10,-10),Vector2(14,0)])
				color = Color("a2dbeb")
			"root":
				crown = PackedVector2Array([Vector2(-15,0),Vector2(-17,-12),Vector2(-11,-10),Vector2(-5,-3),Vector2(1,-13),Vector2(5,-9),Vector2(8,-3),Vector2(14,-10),Vector2(15,0)])
				color = Color("a8bd91")
			"ember":
				crown = PackedVector2Array([Vector2(-13,0),Vector2(-11,-6),Vector2(-5,-9),Vector2(-1,-15),Vector2(4,-9),Vector2(10,-11),Vector2(13,-5),Vector2(13,0)])
				color = Color("c1acd8")
			_:
				crown = PackedVector2Array([Vector2(-12,0),Vector2(-12,-7),Vector2(-8,-7),Vector2(-8,-11),Vector2(8,-11),Vector2(8,-7),Vector2(12,-7),Vector2(12,0)])
				color = Color("9bbab8")
		for i in crown.size(): crown[i] = p + (crown[i] * 0.8).round()
		draw_colored_polygon(crown, color)
		crown.append(crown[0])
		draw_polyline(crown, C_OUTLINE, 1.0)

## Draw frame `i` of a cached AnimRec. Flip = negative-width destination rect placed at the mirrored left edge;
## pixel-identical to draw_set_transform(pos, 0, (-1,1)) (src/core/diag/flip_check.gd: 0 px difference) without
## a transform command per sprite (08 H2).
func _blit_rec(rec, i: int, pos: Vector2, flip: bool, mod: Color) -> void:
	var r: Rect2 = rec.rects[i]
	var pv: Vector2 = rec.pivots[i]
	if flip:
		draw_texture_rect_region(rec.tex, Rect2(pos.x - (r.size.x - pv.x), pos.y - pv.y, -r.size.x, r.size.y), r, mod)
	else:
		draw_texture_rect_region(rec.tex, Rect2(pos - pv, r.size), r, mod)

func _blit(f: Dictionary, pos: Vector2, flip: bool, mod: Color) -> void:
	var r: Rect2 = f.rect
	var pv: Vector2 = f.pivot
	if flip:
		draw_texture_rect_region(f.tex, Rect2(pos.x - (r.size.x - pv.x), pos.y - pv.y, -r.size.x, r.size.y), r, mod)
	else:
		draw_texture_rect_region(f.tex, Rect2(pos - pv, r.size), r, mod)

func _draw_placeholder(u, pos: Vector2, flip: bool, mod: Color) -> void:
	var s := float(u.def.get("size", 1.0))
	if u.is_hero: s = 1.35
	var dir := -1.0 if flip else 1.0
	var main: Color = C_PLAYER if u.side == 1 else C_ENEMY
	var dark: Color = C_PLAYER_D if u.side == 1 else C_ENEMY_D
	if u.is_hero:
		main = C_HERO
		dark = Color("b0802a")
	var tags: Array = u.def.get("tags", [])
	var kind := str(u.def.get("attack_type", "melee"))
	var bob := 0.0
	var lunge := 0.0
	if u.state == SimS.S_WALK:
		bob = 1.0 if int(u.anim_t * 8.0) % 2 == 0 else 0.0
	elif u.state == SimS.S_ATTACK:
		lunge = 3.0 * dir if u.anim_t < 0.15 else 0.0
	var tilt := 0.0
	if u.dying:
		tilt = minf(1.0, u.anim_t * 3.0)
	var bw := roundf(8.0 * s)
	var bh := roundf(10.0 * s)
	var hw := roundf(6.0 * s)
	var base := pos + Vector2(lunge, -bob)
	if tilt > 0.0:
		draw_set_transform(pos, -dir * tilt * 1.4, Vector2.ONE)
		base = Vector2.ZERO
	var c_main := main * mod
	var c_dark := dark * mod
	var c_out := C_OUTLINE * Color(1, 1, 1, mod.a)
	# legs
	draw_rect(Rect2(base.x - bw * 0.5, base.y - 4.0, 3.0, 4.0), c_dark)
	draw_rect(Rect2(base.x + bw * 0.5 - 3.0, base.y - 4.0 + (bob if u.state == SimS.S_WALK else 0.0), 3.0, 4.0 - bob), c_dark)
	# body
	var body := Rect2(base.x - bw * 0.5, base.y - 4.0 - bh, bw, bh)
	draw_rect(body.grow(1.0), c_out)
	draw_rect(body, c_main)
	if tags.has("tank") or u.id.contains("shield"):
		draw_rect(Rect2(base.x + dir * bw * 0.5 - (0.0 if dir > 0 else 5.0), body.position.y + 1.0, 5.0, bh), Color("c0c4cc") * mod)
	# head
	var head := Rect2(base.x - hw * 0.5, body.position.y - hw, hw, hw)
	draw_rect(head.grow(1.0), c_out)
	draw_rect(head, (C_SKIN if u.side == 1 else Color("8fbf5a")) * mod)
	draw_rect(Rect2(base.x + dir * 1.0, head.position.y + 2.0, 1.0, 1.0), c_out)
	if u.is_hero:
		draw_rect(Rect2(head.position.x - 1.0, head.position.y - 2.0, hw + 2.0, 2.0), Color("f2d16b") * mod)
		draw_rect(Rect2(base.x - dir * (bw * 0.5 + 2.0) - 1.0, body.position.y, 3.0, bh), Color("a83a3a") * mod)
	if u.is_boss or tags.has("boss"):
		draw_rect(Rect2(head.position.x - 2.0, head.position.y - 3.0, 3.0, 3.0), Color("e6e6e6") * mod)
		draw_rect(Rect2(head.end.x - 1.0, head.position.y - 3.0, 3.0, 3.0), Color("e6e6e6") * mod)
	# weapon
	var wy := body.position.y + bh * 0.4
	if kind == "ranged":
		draw_line(Vector2(base.x + dir * (bw * 0.5 + 2.0), wy - 5.0), Vector2(base.x + dir * (bw * 0.5 + 2.0), wy + 5.0), Color("8d6e4a") * mod, 1.0)
	elif kind == "siege":
		draw_rect(Rect2(base.x - bw, base.y - 6.0, bw * 2.0, 4.0), Color("6b4f34") * mod)
		draw_circle(Vector2(base.x - bw * 0.6, base.y - 2.0), 2.5, c_out)
		draw_circle(Vector2(base.x + bw * 0.6, base.y - 2.0), 2.5, c_out)
	else:
		var wl := 7.0 * s + (3.0 if u.state == SimS.S_ATTACK and u.anim_t < 0.15 else 0.0)
		draw_line(Vector2(base.x + dir * bw * 0.5, wy), Vector2(base.x + dir * (bw * 0.5 + wl), wy - 2.0), Color("d8dde6") * mod, 1.0)
	if tilt > 0.0:
		draw_set_transform(Vector2.ZERO)
	if not u.dying:
		_hp_bar(pos + Vector2(0, -bh - hw - 9.0), 10.0 + 4.0 * s, u.hp / u.hp_max, u.side)

func _hp_bar(center: Vector2, w: float, ratio: float, side: int) -> void:
	if ratio >= 0.999 and w < 30.0:
		return   # hide full bars on troops to reduce clutter
	var r := Rect2(roundf(center.x - w * 0.5), roundf(center.y), roundf(w), 2.0)
	_bar_rects.append(r.grow(1.0))
	_bar_fills.append(Rect2(r.position, Vector2(roundf(w * clampf(ratio, 0.0, 1.0)), 2.0)))
	_bar_cols.append(C_BAR_PLAYER if side == 1 else C_BAR_ENEMY)

func _flush_bars() -> void:
	for r in _bar_rects:
		draw_rect(r, C_OUTLINE)
	for i in _bar_fills.size():
		draw_rect(_bar_fills[i], _bar_cols[i])
		if _bar_cols[i] == C_BAR_ENEMY:
			var r := _bar_fills[i]
			for x in range(int(r.position.x) + 2, int(r.end.x), 4):
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), C_OUTLINE, 1.0)
	_bar_rects.clear()
	_bar_fills.clear()
	_bar_cols.clear()

# ---------------- projectiles / fx / text ----------------
func _draw_projectile(p) -> void:
	var k: float = clampf(p.t / p.dur, 0.0, 1.0)
	var y: float = ground_y + p.y - sin(k * PI) * p.arc
	var pos := Vector2(roundf(p.x), roundf(y))
	if p.target != null and _render_positions.has(p.target.uid):
		pos += (_unit_pos(p.target)-Vector2(p.target.x,ground_y+p.target.lane_y))*k*k
	if atlas:
		var rec = atlas.anim_rec(p.kind, "fly")
		if rec != null:
			_blit_rec(rec, atlas.rec_index(rec, p.t), pos, p.side < 0, Color.WHITE)
			return
	match p.kind:
		"rock":
			draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), Color("6d6359"))
		"tower_bolt":
			draw_rect(Rect2(pos - Vector2(2, 1), Vector2(5, 2)), Color("f2d16b"))
		"spit":
			draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color("9ad14b"))
		_:
			var d := float(p.side)
			draw_line(pos - Vector2(4.0 * d, 0), pos + Vector2(2.0 * d, 0), Color("e8e0c8"), 1.0)

const TELE_INK := {"charge": Color("ff7a3a"), "lob": Color("ffb43c"), "burrow": Color("d08a48")}
const TELE_RED := Color("ff4a3a")

func _tele_ink(shape: String) -> Color:
	return TELE_INK.get(shape, TELE_RED)

## Ground half of a wind-up warning, drawn under the units: a striped danger patch over the exact hit width
## whose bright edges close in from both sides as the hit approaches (the old pale rail sat on top of the units).
func _draw_telegraph_zones() -> void:
	for f in sim.fxs:
		if not f.alive or f.kind != "telegraph" or f.warning_track >= 3: continue
		var left := roundf(f.x - f.radius)
		var right := roundf(f.x + f.radius)
		var k := clampf(f.t / maxf(0.001, f.dur), 0.0, 1.0)
		var ink := _tele_ink(str(f.warning_shape))
		var pulse := 0.5 + 0.5 * sin(f.t * (6.0 + 18.0 * k))
		var top := ground_y - 10.0      # bottom stays clear of the card bar at small screens
		var h := 14.0
		var zone := ink
		zone.a = 0.16 + 0.14 * pulse
		draw_rect(Rect2(left, top, right - left, h), zone)
		# moving diagonal hazard stripes (stepped 2-px rows, clipped to the patch)
		var st := ink.darkened(0.15)
		st.a = 0.45 + 0.25 * pulse
		var shift := fmod(f.t * 16.0, 8.0)
		var sx := left - h + shift
		while sx < right:
			var ry := 0.0
			while ry < h:
				var x0 := maxf(left, sx + ry)
				var x1 := minf(right, sx + ry + 3.0)
				if x1 > x0: draw_rect(Rect2(x0, top + h - ry - 2.0, x1 - x0, 2.0), st)
				ry += 2.0
			sx += 8.0
		# the part already "charged" (from both edges inward) glows stronger
		var fill := roundf((right - left) * 0.5 * k)
		var hot := ink
		hot.a = 0.22 + 0.18 * pulse
		draw_rect(Rect2(left, top, fill, h), hot)
		draw_rect(Rect2(right - fill, top, fill, h), hot)
		# closing edges: outlined bright posts at the hit extent and at the charge front
		for ex in [left, right - 2.0]:
			draw_rect(Rect2(ex - 1.0, top - 1.0, 4.0, h + 2.0), C_OUTLINE)
			draw_rect(Rect2(ex, top, 2.0, h), ink.lightened(0.35))
		if fill > 3.0 and fill < (right - left) * 0.5 - 2.0:
			var lc := ink.lightened(0.6)
			lc.a = 0.9
			draw_rect(Rect2(left + fill - 1.0, top + 2.0, 1.0, h - 4.0), lc)
			draw_rect(Rect2(right - fill, top + 2.0, 1.0, h - 4.0), lc)

## Top half, drawn after the units so it is never hidden: a thin fuse rail at the feet line and the stack overflow.
func _draw_telegraphs() -> void:
	var overflow: Array[Vector2] = []
	for f in sim.fxs:
		if not f.alive or f.kind != "telegraph": continue
		var left := roundf(f.x - f.radius)
		var right := roundf(f.x + f.radius)
		if f.warning_track >= 3:
			overflow.append(Vector2(left, right))
			continue
		var ink := _tele_ink(str(f.warning_shape))
		var y := ground_y + 3.0 - 3.0 * float(f.warning_track)
		var band := Rect2(left, y, right - left, 2.0)
		draw_rect(band.grow(1.0), C_OUTLINE)
		draw_rect(band, ink.darkened(0.55))
		var fill := roundf(band.size.x * 0.5 * clampf(f.t / maxf(0.001, f.dur), 0.0, 1.0))
		draw_rect(Rect2(left, y, fill, 2.0), ink.lightened(0.25))
		draw_rect(Rect2(right - fill, y, fill, 2.0), ink.lightened(0.25))
		if f.warning_shape == "lob" or f.warning_shape == "burrow":
			# Three teeth distinguish a delayed ground hazard from the smooth slam rail.
			for q in [0.25, 0.5, 0.75]:
				var tx := roundf(lerpf(left, right, q))
				draw_rect(Rect2(tx - 2.0, y - 3.0, 4.0, 4.0), C_OUTLINE)
				draw_rect(Rect2(tx - 1.0, y - 2.0, 2.0, 2.0), ink.lightened(0.4))
	if overflow.is_empty(): return
	overflow.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var span := overflow[0]
	var count := 1
	for i in range(1, overflow.size()):
		if overflow[i].x <= span.y + 4.0:
			span.y = maxf(span.y, overflow[i].y)
			count += 1
		else:
			_draw_telegraph_overflow(span, count)
			span = overflow[i]
			count = 1
	_draw_telegraph_overflow(span, count)

func _draw_telegraph_overflow(span: Vector2, count: int) -> void:
	# Keep the combined danger extent visible even when every regular rail is occupied.
	var band := Rect2(span.x, ground_y - 22.0, span.y - span.x, 3.0)
	draw_rect(band.grow(1.0), C_OUTLINE)
	draw_rect(band, Color("ffe2a1"))
	var p := Vector2(roundf((span.x + span.y) * 0.5) - 10.0, ground_y - 24.0)
	draw_rect(Rect2(p + Vector2(-2, -10), Vector2(27, 13)), C_OUTLINE)
	draw_string(_num_font, p, "+%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX, Color("ffe2a1"))
	_mark_rects.append(Rect2(p + Vector2(-2, -10), Vector2(27, 13)))

## Zone skills drawn as a row of sprites: kind -> px between copies.
const TILED_FX := {"skill_oven": 16.0, "skill_frost": 44.0}

## Visual-only effects the simulation does not spawn (it stays untouched): a flour poof when one of our
## soldiers appears, a spore puff when a mould enemy falls, road dust when the hero sets off, a slime splat
## where a spit lands. {kind, x, y, t, dur}
var _vfx: Array = []
var _seen_players := {}
var _seen_dying := {}
var _hero_moving := false
var _hero_last_x := 0.0
var _seen_proj := {}

func _track_vfx(dt: float) -> void:
	if sim == null or atlas == null: return
	for v in _vfx: v.t += dt
	_vfx = _vfx.filter(func(v): return v.t < v.dur)
	if sim.t <= 0.0: return
	var alive := {}
	for u in sim.players:
		alive[u.uid] = true
		if not _seen_players.has(u.uid):
			_seen_players[u.uid] = true
			if sim.t > 0.2: _vfx.append({"kind": "spawn", "x": u.x, "y": 0.0, "t": 0.0, "dur": 0.45})
	for k in _seen_players.keys():
		if not alive.has(k): _seen_players.erase(k)
	for e in sim.enemies:
		if e.dying and not _seen_dying.has(e.uid):
			_seen_dying[e.uid] = true
			if not e.is_boss: _vfx.append({"kind": "death_poof", "x": e.x, "y": 0.0, "t": 0.0, "dur": 0.45})
	if _seen_dying.size() > 256: _seen_dying.clear()
	var hx: float = sim.hero.x
	if _hero_last_x == 0.0: _hero_last_x = hx
	var moving: bool = absf(hx - _hero_last_x) > 0.05 and sim.hero_respawn <= 0.0
	if moving and not _hero_moving:
		_vfx.append({"kind": "dust", "x": hx, "y": 0.0, "t": 0.0, "dur": 0.35})
	_hero_moving = moving
	_hero_last_x = hx
	# projectiles may be pooled: remember each live spit's last position, splat once it stops being live
	var live := {}
	for p in sim.projectiles:
		if p.alive and p.kind == "spit":
			live[p] = true
			_seen_proj[p] = p.x
	for p in _seen_proj.keys():
		if not live.has(p):
			_vfx.append({"kind": "hit_spit", "x": float(_seen_proj[p]), "y": -12.0, "t": 0.0, "dur": 0.3})
			_seen_proj.erase(p)

func _draw_vfx() -> void:
	for v in _vfx:
		var rec = atlas.anim_rec(v.kind, "play")
		if rec == null: continue
		var k := clampf(v.t / v.dur, 0.0, 1.0)
		_blit_rec(rec, atlas.rec_index(rec, k * maxf(0.0, rec.rects.size() - 0.001) / rec.fps), Vector2(roundf(v.x), ground_y + v.y), false, Color.WHITE)

func _draw_fx(f) -> void:
	var k := clampf(f.t / f.dur, 0.0, 1.0)
	var pos := Vector2(f.x, ground_y + f.y)
	if atlas:
		var rec = atlas.anim_rec(f.kind, "play")
		if rec == null: rec = atlas.anim_rec(f.kind, "loop")
		if rec != null:
			var at: float = f.t if rec.loop else k * maxf(0.0, rec.rects.size() - 0.001) / rec.fps
			var n := 1
			var step := 0.0
			if f.kind in TILED_FX and f.radius > 0.0:
				# zone skills: repeat the sprite across the zone, each copy a frame apart so they do not pulse together
				step = float(TILED_FX[f.kind])
				n = maxi(1, int(floorf(f.radius * 2.0 / step)) + 1)
			for i in n:
				var dx := (float(i) - float(n - 1) * 0.5) * step
				var fi: int = atlas.rec_index(rec, at + (float(i * 3 % 5) / rec.fps if rec.loop else 0.0))
				if not rec.loop and n > 1: fi = clampi(fi - (i * 2 % 3), 0, rec.rects.size() - 1)
				_blit_rec(rec, fi, pos + Vector2(roundf(dx), 0.0), i % 2 == 1, Color.WHITE)
			return
	match f.kind:
		"hit_spark":
			var s := 2.0 + k * 3.0
			draw_rect(Rect2(pos - Vector2(s, 0.5), Vector2(s * 2.0, 1.0)), Color(1, 1, 0.7, 1.0 - k))
			draw_rect(Rect2(pos - Vector2(0.5, s), Vector2(1.0, s * 2.0)), Color(1, 1, 0.7, 1.0 - k))
		"explosion":
			draw_circle(pos, maxf(4.0, f.radius) * (0.4 + k * 0.6), Color(1.0, 0.6, 0.2, 0.7 * (1.0 - k)))
		"spore_burst":
			# a lobbed zone going off: a low violet puff over exactly the marked width
			draw_rect(Rect2(f.x - f.radius, ground_y - 10.0 - 8.0 * k, f.radius * 2.0, 10.0 + 8.0 * k), Color(0.66, 0.45, 0.82, 0.6 * (1.0 - k)))
			draw_rect(Rect2(f.x - f.radius * (0.4 + 0.6 * k), ground_y - 16.0 - 10.0 * k, f.radius * 2.0 * (0.4 + 0.6 * k), 4.0), Color(0.86, 0.72, 0.96, 0.8 * (1.0 - k)))
		"link_break":
			for dx in [-1.0, 1.0]:
				draw_line(pos + Vector2(dx * 2.0, 0), pos + Vector2(dx * (5.0 + 8.0 * k), -4.0 - 6.0 * k), Color(0.56, 0.84, 0.81, 1.0 - k), 2.0)
		"target_mark":
			draw_arc(Vector2(f.x, ground_y), f.radius, 0, TAU, 24, Color(1, 0.3, 0.2, 0.4 + 0.4 * sin(f.t * 20.0)), 1.0)
		"rally", "skill_rally":
			draw_arc(Vector2(f.x, ground_y - 12.0), 10.0 + k * f.radius * 0.5, 0, TAU, 24, Color(1.0, 0.85, 0.3, 1.0 - k), 2.0)
		"heal":
			draw_arc(Vector2(f.x, ground_y - 12.0), 8.0 + k * f.radius, 0, TAU, 24, Color(0.4, 1.0, 0.5, 1.0 - k), 2.0)
		"skill_flour":
			# flour sacks drop on the hero: three pale sacks falling with a puff
			for i in 3:
				var sx: float = f.x - 10.0 + i * 10.0
				var sy := ground_y - 40.0 + minf(1.0, k * 2.0 + i * 0.15) * 26.0
				draw_rect(Rect2(sx - 3, sy - 4, 7, 6), Color(0.94, 0.89, 0.76, 1.0 - k * 0.6))
				draw_rect(Rect2(sx - 3, sy - 4, 7, 1), Color(0.8, 0.66, 0.45, 1.0 - k * 0.6))
			draw_rect(Rect2(f.x - 16.0 * k - 4, ground_y - 4, 32.0 * k + 8, 3), Color(1, 1, 1, 0.5 * (1.0 - k)))
		"skill_shield":
			# sugar barrier: a pale pink dome growing over the allies
			var r2: float = 10.0 + k * f.radius
			draw_arc(Vector2(f.x, ground_y), r2, PI, TAU, 28, Color(1.0, 0.78, 0.88, 0.9 * (1.0 - k)), 2.0)
			draw_arc(Vector2(f.x, ground_y), r2 * 0.8, PI, TAU, 24, Color(1.0, 0.95, 0.98, 0.5 * (1.0 - k)), 1.0)
		"skill_frost":
			# frost cream: a cold sheet over the zone with crystals rising
			draw_rect(Rect2(f.x - f.radius, ground_y - 3.0, f.radius * 2.0, 3.0), Color(0.7, 0.9, 1.0, 0.7 * (1.0 - k)))
			for i in 7:
				var cx: float = f.x - f.radius + (i + 0.5) * f.radius * 2.0 / 7.0
				var h := (6.0 + float((i * 5) % 7)) * (1.0 - absf(k - 0.4))
				draw_rect(Rect2(cx - 1.0, ground_y - 3.0 - h, 3.0, h), Color(0.82, 0.95, 1.0, 0.85 * (1.0 - k)))
		"skill_oven":
			# oven heat: flickering flame tongues along the strip
			for i in 9:
				var cx2: float = f.x - f.radius + (i + 0.5) * f.radius * 2.0 / 9.0
				var fl := roundf(12.0 + 10.0 * absf(sin(f.t * 14.0 + i * 1.7)))
				draw_rect(Rect2(cx2 - 4.0, ground_y - fl, 8.0, fl), Color(0.86, 0.3, 0.12, 0.8 * (1.0 - k * 0.6)))
				draw_rect(Rect2(cx2 - 3.0, ground_y - fl * 0.75, 6.0, fl * 0.75), Color(1.0, 0.58, 0.2, 0.85 * (1.0 - k * 0.6)))
				draw_rect(Rect2(cx2 - 1.0, ground_y - fl * 0.4, 2.0, fl * 0.4), Color(1.0, 0.92, 0.55, 0.9 * (1.0 - k * 0.6)))
			draw_rect(Rect2(f.x - f.radius, ground_y - 2.0, f.radius * 2.0, 2.0), Color(1.0, 0.45, 0.15, 0.6 * (1.0 - k)))
		_:  # shockwave / slam / meteor / barrage
			var r := maxf(8.0, f.radius) * (0.2 + 0.8 * k)
			draw_arc(Vector2(f.x, ground_y), r, PI, TAU, 20, Color(1.0, 0.95, 0.7, 1.0 - k), 3.0)
			draw_rect(Rect2(f.x - r, ground_y - 2.0, r * 2.0, 2.0), Color(0.9, 0.8, 0.6, 0.6 * (1.0 - k)))

static func damage_curve(age: float) -> Vector2:
	var u := clampf(age/0.8,0.0,1.0)
	return Vector2(32.0*(1.0-pow(1.0-u,2.0)),1.0-smoothstep(0.55,1.0,u))

var _text_offsets := {} # spawn-allocated offsets; never reflow surviving numbers
func _draw_text(tx) -> void:
	var curve := damage_curve(tx.t+render_ahead)
	var a := curve.y
	var c := Color(1, 1, 1, a)
	match tx.kind:
		&"gold": c = Color(1.0, 0.85, 0.3, a)
		&"heal": c = Color(0.4, 1.0, 0.5, a)
		&"shield": c = Color(1.0, 0.75, 0.88, a)
		&"crit": c = Color(1.0, 0.4, 0.3, a)
	if tx.uid < 0: c = Color(1.0,0.87,0.48,a)
	# QA-B012: bundled Galmuri9 numerals at their native 10 px grid, 1 px shadow (no outline pass); centred on x.
	var w := _num_font.get_string_size(tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX).x
	var by: float = ground_y + tx.y + tx.rise - curve.x
	if tx.anchor_set != "" and atlas:
		# above the target's frame and its hp bar (bar sits at frame top - 3; lane jitter up to ±6)
		var rec = atlas.anim_rec(tx.anchor_set, "idle")
		if rec == null: rec = atlas.anim_rec(tx.anchor_set, "walk")
		var h: float = rec.rects[0].size.y if rec != null else 24.0
		by = ground_y - h - 12.0 - curve.x
	var p := Vector2(tx.x - w * 0.5,by)
	# vertical stagger (QA-B012): the rect covers the glyphs plus the 1 px outline and is exactly TEXT_STEP high, so a
	# moved number never keeps a 1 px overlap (the old 10 px step under an 11 px rect used up the guard after ~3).
	if not _text_offsets.has(tx.serial):
		var raw := Rect2(p.x-1,p.y-NUM_PX-1,w+2,TEXT_STEP)
		var slot := place_text(raw,_placed_text,TEXT_STEP,TEXT_MAX_STEPS)
		_text_offsets[tx.serial] = Vector2(0,slot.position.y-raw.position.y) if slot.size != Vector2.ZERO else Vector2(0,-TEXT_STEP*posmod(tx.serial,3))
	p += _text_offsets[tx.serial]
	p = Vector2(PixelCamera.world_position(p.x,world_zoom,device_scale),PixelCamera.world_position(p.y,world_zoom,device_scale))
	_placed_text.append(Rect2(p.x-1,p.y-NUM_PX-1,w+2,TEXT_STEP))
	# 1 px dark outline (4 neighbours) for light backgrounds such as the village walls (07 visual7 zoom_nums)
	var oc := Color(C_OUTLINE, a)
	for o in TEXT_OUTLINE:
		draw_string(_num_font, p + o, tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX, oc)
	draw_string(_num_font, p, tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX, c)

# ---- base damage: one running total per base ----
# The sim spawns a new base number every 0.24 s of sustained fire (FText uid -100/-101), so a siege showed a
# ladder of 3-4 rising numbers that restarted all the time. The view now adds those values into ONE number per
# base that stays put while hits keep coming and drifts up once after the last hit. Display only: the sim's
# damage, its texts and their values are untouched, and the shown total is exactly the sum of those values.
const COMBO_HOLD := 0.45     # s the total stays after the last hit
const COMBO_FADE := 0.35     # s of the single drift-up + fade
const COMBO_RISE := 10.0     # px drifted during the fade
const COMBO_SIDE := 38.0     # px from the base centre towards the battlefield (clear of the base HP bar)
const COMBO_UP := 70.0       # px above the ground: over the attackers' heads, under the HUD strips
var _base_combo := {}        # FText uid -> {total:int, seen:{serial:value}, last:float, x:float}

## Pure: shown alpha (x) and drift in px (y) of a base total `age` seconds after its last hit.
static func combo_curve(age: float) -> Vector2:
	var k := smoothstep(COMBO_HOLD, COMBO_HOLD + COMBO_FADE, age)
	return Vector2(1.0 - k, COMBO_RISE * k)

## Adds the not-yet-counted part of one base FText to its base's running total (public for tests).
func _feed_base_combo(tx) -> void:
	if not _base_combo.has(tx.uid):
		var enemy_side: bool = absf(tx.x - float(sim.enemy_base.x)) < absf(tx.x - float(sim.player_base.x))
		var bx: float = float(sim.enemy_base.x) if enemy_side else float(sim.player_base.x)
		_base_combo[tx.uid] = {"total": 0, "seen": {}, "last": -1000.0, "x": bx + (-COMBO_SIDE if enemy_side else COMBO_SIDE)}
	var st: Dictionary = _base_combo[tx.uid]
	var seen: Dictionary = st.seen
	var before := int(seen.get(tx.serial, 0))
	if int(tx.value) > before:
		if float(sim.t) - float(st.last) > COMBO_HOLD + COMBO_FADE:
			st.total = 0                      # the previous total has fully faded: a new burst starts at 0
		st.total = int(st.total) + int(tx.value) - before
		st.last = float(sim.t)
		seen[tx.serial] = int(tx.value)

func _draw_base_combos(live: Dictionary) -> void:
	for uid in _base_combo:
		var st: Dictionary = _base_combo[uid]
		var seen: Dictionary = st.seen
		for serial in seen.keys():
			if not live.has(serial): seen.erase(serial)
		var curve := combo_curve(float(sim.t) + render_ahead - float(st.last))
		if curve.x <= 0.0 or int(st.total) <= 0: continue
		var text := str(int(st.total))
		var w := _num_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX).x
		var p := Vector2(float(st.x) - w * 0.5, ground_y - COMBO_UP - curve.y)
		p = Vector2(PixelCamera.world_position(p.x,world_zoom,device_scale),PixelCamera.world_position(p.y,world_zoom,device_scale))
		_placed_text.append(Rect2(p.x-1,p.y-NUM_PX-1,w+2,TEXT_STEP))   # unit numbers stagger around it
		var oc := Color(C_OUTLINE, curve.x)
		for o in TEXT_OUTLINE:
			draw_string(_num_font, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX, oc)
		draw_string(_num_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_PX, Color(1.0,0.87,0.48,curve.x))

var _placed_text: Array[Rect2] = []   # rects of the damage numbers drawn this frame (07 capture_crowd reads it)
var texts_dropped := 0                 # numbers skipped for lack of a free slot (QA evidence)
const TEXT_STEP := NUM_PX + 2          # 1 px outline above + NUM_PX glyph cell + 1 px outline below
const TEXT_MAX_STEPS := 8
const TEXT_OUTLINE: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]

## Pure layout for damage numbers (QA-B012): move r up in `step` px until it intersects no rect in `placed`.
## Returns that rect, or an empty Rect2 if none is free within max_steps moves. Used by _draw_text and probes.
static func place_text(r: Rect2, placed: Array[Rect2], step: float, max_steps: int) -> Rect2:
	for i in max_steps + 1:
		var free := true
		for q in placed:
			if q.intersects(r):
				free = false
				break
		if free:
			return r
		r.position.y -= step
	return Rect2()
