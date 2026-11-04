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
	environment.build(float(sim.L), ground_y, biome)
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
	_update_formation(_dt)
	if environment and sim:
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
	for u in _order:
		if u.dying: continue
		var foot := _unit_pos(u)
		draw_rect(Rect2(foot + Vector2(-7,0),Vector2(14,2)),Color(0.08,0.08,0.07,0.32))
	for u in _order:
		_draw_unit(u)
	for u in _variant_marks: _draw_variant(u)
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
		if f.alive: _draw_fx(f)
	if show_damage:
		_placed_text.clear()
		var live := {}
		for tx in sim.texts:
			if tx.alive:
				live[tx.serial] = true
				_draw_text(tx)
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
	_formation_timer -= dt
	if _formation_timer <= 0:
		_formation_timer = 0.08 # bounded O(n²), at most 40 per side, 12.5 Hz
		_formation_targets.clear()
		_crowd_badges.clear()
		for u in all:
			var count := 0
			var rank := 0
			var same_count := 0
			var leader: int = u.uid
			if not u.is_hero and not u.is_boss and not u.dying:
				for other in all:
					if other.side != u.side or other.is_hero or other.is_boss or other.dying: continue
					if absf(other.x-u.x) < 24:
						count += 1
						if other.uid < u.uid: rank += 1
						if other.id == u.id:
							same_count += 1
							leader = mini(leader,other.uid)
			var offset := Vector2.ZERO
			if count > 1:
				# Every row stays above the lane: the lowest row must never enter the card strip.
				var row := posmod(rank,3)-2
				offset = Vector2(-u.side * minf(54.0,(rank/3)*9.0+row*4.0),row*10.0-u.lane_y)
			_formation_targets[u.uid] = offset
			if same_count >= 6 and leader == u.uid:
				_crowd_badges.append({"uid":u.uid,"side":u.side,"count":same_count})
	_render_positions.clear()
	var live := {}
	for u in all:
		live[u.uid] = true
		var target: Vector2 = _formation_targets.get(u.uid,Vector2.ZERO)
		var offset: Vector2 = _formation_offsets.get(u.uid,Vector2.ZERO)
		offset = offset.lerp(target,1.0-exp(-12.0*dt))
		_formation_offsets[u.uid] = offset
		_render_positions[u.uid] = Vector2(PixelCamera.world_position(u.x+offset.x,world_zoom,device_scale),PixelCamera.world_position(ground_y+u.lane_y+offset.y,world_zoom,device_scale))
	for uid in _formation_offsets.keys():
		if not live.has(uid): _formation_offsets.erase(uid)
	if environment == null and not _biome_layers.is_empty() and atlas:
		_draw_biome_layers(cam_x - view_w * 0.5 - 8.0, view_w + 16.0, true)

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
func _draw_base(b: Dictionary, side: int) -> void:
	var x: float = b.x
	var key := "player" if side == 1 else "enemy"
	if atlas:
		var bm: Dictionary = atlas.manifest.get("bases", {}).get(key, {})
		if not bm.is_empty():
			var ratio: float = b.hp / b.hp_max
			var st := "idle" if ratio > 0.5 else ("damaged" if ratio > 0.0 else "ruined")
			var rec = null
			if bm.has("anim_set"):
				rec = atlas.anim_rec(str(bm.anim_set), st)
				if rec == null: rec = atlas.anim_rec(str(bm.anim_set), "idle")
			if rec != null:
				var mod0 := Color(1, 0.6, 0.6) if b.flash > 0.0 else Color.WHITE
				var bi: int = atlas.rec_index(rec, sim.t)
				_blit_rec(rec, bi, Vector2(x, ground_y), side < 0 and bool(bm.get("flip", false)), mod0)
				_hp_bar(Vector2(x, ground_y - rec.rects[bi].size.y - 8.0), 44.0, b.hp / b.hp_max, side)
				return
			var f: Dictionary = atlas.frame(str(bm.get("atlas", "")), str(bm.get("frame", "")))
			if not f.is_empty():
				var mod := Color(1, 0.6, 0.6) if b.flash > 0.0 else Color.WHITE
				_blit(f, Vector2(x, ground_y), side < 0 and bool(bm.get("flip", false)), mod)
				_hp_bar(Vector2(x, ground_y - f.rect.size.y - 8.0), 44.0, b.hp / b.hp_max, side)
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
	_hp_bar(Vector2(x, r.position.y - 36.0), 44.0, b.hp / b.hp_max, side)

func _draw_workers() -> void:
	Supply.draw(self, sim, atlas, ground_y)

# ---------------- units ----------------
func _anim_name(u) -> String:
	match u.state:
		SimS.S_WALK: return "walk"
		SimS.S_ATTACK: return "attack"
		SimS.S_DYING: return "death"
	return "idle"

func _draw_unit(u) -> void:
	var pos := _unit_pos(u)
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
	if u.is_boss: mod = Color(3.0, 3.0, 3.0)
	elif u.id == "e_brute": mod = Color(1.15, 1.15, 1.15)
	if u.def.has("visual_tint"):
		mod = Color(str(u.def.visual_tint)) * (1.4 if u.is_boss else 1.15)
		mod.a = 1.0
	if not u.dying and str(u.def.get("visual_mark","")) != "": _variant_marks.append(u)
	if u.flash > 0.0: mod = Color(1.0, 0.55, 0.55)
	if u.dying: mod.a = clampf(u.dead_t / 0.7, 0.0, 1.0)
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
			_blit_rec(rec, fi, pos, flip, mod)
			drawn = true
			if not u.dying:
				_hp_bar(pos + Vector2(0, -rec.rects[fi].size.y - 3.0), 12.0 + 4.0 * float(u.def.get("size", 1.0)), u.hp / u.hp_max, u.side)
	if not drawn:
		_draw_placeholder(u, pos, flip, mod)

func _draw_variant(u) -> void:
	var pos := _unit_pos(u)
	var mark := str(u.def.get("visual_mark",""))
	var h := 26.0
	if atlas:
		var rec = atlas.anim_rec(u.anim_set,"walk")
		if rec != null: h = rec.rects[0].size.y-3.0
	if mark == "shield" or mark == "warden":
		var p := pos+Vector2(u.side*8,-15)
		draw_rect(Rect2(p-Vector2(5,0),Vector2(10,16)),C_OUTLINE)
		draw_rect(Rect2(p-Vector2(4,-1),Vector2(8,13)),Color("b8a37b"))
		draw_rect(Rect2(p+Vector2(-1,1),Vector2(2,12)),Color("eadcb4"))
	if mark == "spore":
		var p := pos+Vector2(0,-h)
		draw_rect(Rect2(p+Vector2(-8,-2),Vector2(16,4)),C_OUTLINE)
		draw_rect(Rect2(p+Vector2(-6,-4),Vector2(12,4)),Color("d1b6ec"))
		draw_rect(Rect2(p+Vector2(-2,-6),Vector2(4,3)),Color("f0e7ff"))
	elif mark == "runner":
		var p := pos+Vector2(-u.side*5,-h+3)
		draw_rect(Rect2(p,Vector2(8,3)),Color("e6c887"))
		draw_rect(Rect2(p+Vector2(-u.side*3,3),Vector2(6,2)),Color("bb754d"))
	elif mark in ["root","frost","ember","warden"]:
		var p := pos+Vector2(0,-h)
		var color := Color("a2dbeb") if mark == "frost" else (Color("edb15e") if mark == "ember" else Color("c4ce86"))
		draw_rect(Rect2(p+Vector2(-12,-3),Vector2(24,5)),C_OUTLINE)
		for dx in [-9,0,9]:
			draw_rect(Rect2(p+Vector2(dx-2,-9),Vector2(4,10)),color)
		draw_rect(Rect2(p+Vector2(-11,-2),Vector2(22,3)),color)

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

func _draw_fx(f) -> void:
	var k := clampf(f.t / f.dur, 0.0, 1.0)
	var pos := Vector2(f.x, ground_y + f.y)
	if atlas:
		var rec = atlas.anim_rec(f.kind, "play")
		if rec == null: rec = atlas.anim_rec(f.kind, "loop")
		if rec != null:
			var at: float = f.t if rec.loop else k * maxf(0.0, rec.rects.size() - 0.001) / rec.fps
			_blit_rec(rec, atlas.rec_index(rec, at), pos, false, Color.WHITE)
			return
	match f.kind:
		"hit_spark":
			var s := 2.0 + k * 3.0
			draw_rect(Rect2(pos - Vector2(s, 0.5), Vector2(s * 2.0, 1.0)), Color(1, 1, 0.7, 1.0 - k))
			draw_rect(Rect2(pos - Vector2(0.5, s), Vector2(1.0, s * 2.0)), Color(1, 1, 0.7, 1.0 - k))
		"explosion":
			draw_circle(pos, maxf(4.0, f.radius) * (0.4 + k * 0.6), Color(1.0, 0.6, 0.2, 0.7 * (1.0 - k)))
		"target_mark":
			draw_arc(Vector2(f.x, ground_y), f.radius, 0, TAU, 24, Color(1, 0.3, 0.2, 0.4 + 0.4 * sin(f.t * 20.0)), 1.0)
		"rally", "skill_rally":
			draw_arc(Vector2(f.x, ground_y - 12.0), 10.0 + k * f.radius * 0.5, 0, TAU, 24, Color(1.0, 0.85, 0.3, 1.0 - k), 2.0)
		"heal":
			draw_arc(Vector2(f.x, ground_y - 12.0), 8.0 + k * f.radius, 0, TAU, 24, Color(0.4, 1.0, 0.5, 1.0 - k), 2.0)
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
