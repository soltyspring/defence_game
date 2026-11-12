extends RefCounted
## Per-round lane scenery for R01-R40 (docs/art/fable52/BACKDROP_ROUNDS.md). Pure data + flat-shape painters used by
## lane_backdrop.gd: no textures of its own, nothing darker than the unit outlines, flat masses only behind the unit
## band (the 44 px above the ground line); detail starts above it.
##   spec(index)  -> what round `index` shows: chapter, stage 0..1 inside it, sky, palette, landmarks, base states.
##   paint_*      -> draw one landmark into a Shapes layer (box / poly).
## Planes: "far" = ridge layer (parallax 0.22), "mid" = field layer (0.4), "near" = world-locked, behind the units.

const CHAPTER_NAMES := ["meadow", "orchard", "frost", "nest"]

## Sky keys per chapter: [stage, [top, upper, lower, horizon]]. The round's sky is interpolated between keys.
const SKY := [
	[[0.0, ["80adca", "9ec2d4", "bcd6dd", "d8e2d6"]], [0.45, ["86b4d2", "a6c9d9", "c6dde0", "e0e6d2"]],
		[0.78, ["8f9fc0", "b9a9b4", "e0b99a", "ecd3a6"]], [1.0, ["7f95a3", "94a7ad", "a9b8b4", "bcc5b8"]]],
	[[0.0, ["a9b7b0", "c3c4a8", "dccf9f", "ead9a8"]], [0.5, ["a6ada0", "bdbd9f", "cfc79f", "d9cfa6"]],
		[1.0, ["9a9aa0", "b0a59c", "c4ad92", "cfb894"]]],
	[[0.0, ["9db4d4", "b4c6dc", "cbd8e2", "dfe6e6"]], [0.5, ["93a6c2", "a9b8cc", "c0cbd6", "d5dcdf"]],
		[0.85, ["8494b8", "9da5bd", "bcafb0", "d9bd9e"]], [1.0, ["7f8fb4", "9a9fba", "c0a9a4", "e2b98c"]]],
	[[0.0, ["7f9a98", "8aa5a0", "97b0a8", "a5b9ad"]], [0.55, ["85949e", "909fa6", "9fadae", "afbab2"]],
		[1.0, ["8b88a6", "9893ad", "a8a2b4", "b9b3ba"]]],
]

## Flat colours per chapter. ridge_* = far silhouettes, field = the plane right behind the units (kept mid-tone so
## both factions' outlines hold), band = the lighter strip above the unit band, lane_tint = modulate of the walking
## lane (unchanged from the earlier look, so foot-level readability is the same as before).
const PAL := [
	{"ridge_a": "9ab5a9", "ridge_b": "aec2a6", "field": "9eae78", "band": "cdbf85", "band_hi": "ddd09a", "cloud": "edf0df", "cloud_lo": "c6d9df", "lane_tint": "ffffff", "tension": "c9cfd6"},
	{"ridge_a": "a8a488", "ridge_b": "b9b08a", "field": "8f8a55", "band": "b8a56b", "band_hi": "c9b77a", "cloud": "e6dfc2", "cloud_lo": "cfc9ac", "lane_tint": "d9c3a2", "tension": "cdbfae"},
	{"ridge_a": "a3b4c6", "ridge_b": "bccad6", "field": "7c8f96", "band": "aebcc2", "band_hi": "c4d0d4", "cloud": "e4eaee", "cloud_lo": "c6d2dc", "lane_tint": "a9bfd1", "tension": "b9bfd6"},
	{"ridge_a": "7d928f", "ridge_b": "8ba09a", "field": "64776c", "band": "7f938a", "band_hi": "8fa398", "cloud": "a9bcb2", "cloud_lo": "93a79f", "lane_tint": "94a9a2", "tension": "b4a9c9"},
]

## Landmarks per round: [kind, plane, lane fraction, variant]. Fractions are where the piece sits when the camera
## is there; "home" / "enemy" planes are placed relative to the two bases. Every round differs from its neighbours
## in at least one of: landmark set, composition, time of day (sky stage), enemy base state.
const ROUNDS := {
	1: [["shelter", "mid", 0.42, 0], ["windbreak", "mid", 0.7, 0], ["nest_far", "far", 0.97, 0.3, 0.5]],
	2: [["shelter", "mid", 0.3, 0], ["stall", "mid", 0.62, 0], ["nest_far", "far", 0.97, 0.36, 0.5]],
	3: [["stall", "mid", 0.3, 0], ["shop", "mid", 0.52, 0], ["shop", "mid", 0.74, 0], ["nest_far", "far", 0.96, 0.42, 0.5]],
	4: [["shop", "mid", 0.3, 0], ["shop", "mid", 0.63, 1], ["palisade", "near", 0.58, 0], ["nest_far", "far", 0.95, 0.5, 0.5]],
	5: [["shop", "mid", 0.42, 1], ["smoke", "mid", 0.66, 0], ["palisade", "near", 0.55, 1], ["nest_far", "far", 0.93, 0.66, 0.5]],
	6: [["shop", "mid", 0.28, 1], ["shop", "mid", 0.55, 1], ["cart", "near", 0.68, 0], ["nest_far", "far", 0.92, 0.72, 0.5]],
	7: [["palisade", "near", 0.4, 1], ["cart", "near", 0.5, 1], ["shop", "mid", 0.7, 2], ["nest_far", "far", 0.9, 0.8, 0.5]],
	8: [["stall", "mid", 0.38, 1], ["shop", "mid", 0.6, 2], ["palisade", "near", 0.5, 2], ["palisade", "near", 0.7, 1], ["nest_far", "far", 0.88, 0.9, 0.5]],
	9: [["palisade", "near", 0.33, 2], ["shop", "mid", 0.3, 2], ["smoke", "mid", 0.5, 1], ["palisade", "near", 0.6, 2], ["nest_far", "far", 0.86, 1.0, 0.5]],
	10: [["shop", "mid", 0.25, 2], ["smoke", "mid", 0.4, 1], ["palisade", "near", 0.45, 2], ["nest_front", "enemy", -150, 0, 0.6]],
	11: [["orchard_gate", "near", 0.2, 0], ["fruit_tree", "mid", 0.34, 0], ["fruit_tree", "mid", 0.58, 1], ["tree_ridge", "far", 0.5, 0]],
	12: [["fruit_tree", "mid", 0.26, 1], ["ladder", "near", 0.4, 0], ["fruit_tree", "mid", 0.5, 0], ["fruit_tree", "mid", 0.72, 2], ["tree_ridge", "far", 0.5, 0]],
	13: [["fruit_tree", "mid", 0.3, 0], ["cart_fallen", "near", 0.5, 0], ["fruit_tree", "mid", 0.64, 2], ["tree_ridge", "far", 0.5, 1]],
	14: [["fruit_tree", "mid", 0.25, 2], ["blight_tree", "mid", 0.5, 0], ["ladder", "near", 0.34, 1], ["fog", "mid", 0.7, 0], ["tree_ridge", "far", 0.5, 1]],
	15: [["press_house", "mid", 0.48, 0], ["cart_fallen", "near", 0.36, 1], ["blight_tree", "mid", 0.72, 0], ["fog", "mid", 0.6, 0], ["tree_ridge", "far", 0.5, 1]],
	16: [["bare_tree", "mid", 0.3, 0], ["bare_tree", "mid", 0.52, 1], ["fog", "mid", 0.4, 1], ["fog", "mid", 0.75, 0], ["tree_ridge", "far", 0.5, 2]],
	17: [["cart_fallen", "near", 0.38, 0], ["cart_fallen", "near", 0.47, 1], ["bare_tree", "mid", 0.6, 0], ["blight_tree", "mid", 0.78, 1], ["fog", "mid", 0.55, 1], ["tree_ridge", "far", 0.5, 2]],
	18: [["bare_tree", "mid", 0.28, 1], ["mill_ruin", "far", 0.8, 0, 0.42], ["blight_tree", "mid", 0.55, 1], ["fog", "mid", 0.5, 1], ["tree_ridge", "far", 0.4, 2]],
	19: [["blight_tree", "mid", 0.3, 0], ["mill_ruin", "mid", 0.62, 0, 0.7], ["cart_fallen", "near", 0.44, 0], ["fog", "mid", 0.35, 1], ["fog", "mid", 0.8, 1], ["tree_ridge", "far", 0.4, 2]],
	20: [["bare_tree", "mid", 0.26, 0], ["blight_tree", "mid", 0.46, 1], ["root_arch", "near", 0.62, 0], ["mill_ruin", "enemy", -170, 1, 0.8], ["fog", "mid", 0.5, 1]],
	21: [["hearth", "home", 150, 0], ["snow_fence", "near", 0.36, 0], ["signpost", "near", 0.52, 0], ["peaks", "far", 0.5, 0, 0.5]],
	22: [["hearth", "home", 150, 0], ["silo", "mid", 0.45, 0, 0.85], ["snow_fence", "near", 0.62, 1], ["peaks", "far", 0.5, 0, 0.5]],
	23: [["hearth", "home", 150, 0], ["silo", "mid", 0.3, 1, 0.85], ["silo", "mid", 0.5, 0, 0.85], ["silo", "mid", 0.66, 2, 0.85], ["peaks", "far", 0.5, 0, 0.5]],
	24: [["hearth", "home", 150, 0], ["silo", "mid", 0.26, 2, 0.85], ["mill_hall", "mid", 0.56, 0, 0.85], ["peaks", "far", 0.5, 1, 0.5]],
	25: [["hearth", "home", 150, 1], ["mill_hall", "mid", 0.36, 1, 0.85], ["mill_hall", "mid", 0.66, 0, 0.85], ["ice_wall", "far", 0.9, 0, 0.5], ["peaks", "far", 0.4, 1, 0.5]],
	26: [["hearth", "home", 150, 1], ["mill_hall", "mid", 0.24, 1, 0.85], ["chimney", "mid", 0.5, 0, 0.62], ["ice_wall", "far", 0.74, 1, 0.5], ["peaks", "far", 0.3, 1, 0.5]],
	27: [["hearth", "home", 150, 1], ["ice_wall", "mid", 0.5, 0, 0.85], ["ice_gate", "mid", 0.68, 0, 0.75], ["peaks", "far", 0.3, 1, 0.5]],
	28: [["hearth", "home", 150, 2], ["ice_gate", "mid", 0.26, 1, 0.75], ["chimney", "mid", 0.48, 1, 0.62], ["chimney", "mid", 0.6, 0, 0.62], ["oven_glow", "far", 0.92, 0.5, 0.5]],
	29: [["hearth", "home", 150, 2], ["chimney", "mid", 0.3, 1, 0.62], ["chimney", "mid", 0.52, 2, 0.62], ["oven_glow", "far", 0.85, 0.8, 0.5], ["snow_fence", "near", 0.42, 1]],
	30: [["hearth", "home", 150, 2], ["chimney", "mid", 0.28, 2, 0.62], ["oven_glow", "far", 0.8, 1.0, 0.5], ["oven_heart", "enemy", -160, 0, 0.55]],
	31: [["camp", "home", 120, 0], ["rib", "mid", 0.3, 0], ["rib", "mid", 0.62, 1], ["strands", "far", 0.5, 0]],
	32: [["camp", "home", 120, 0], ["rib", "mid", 0.24, 1], ["rib", "mid", 0.46, 0], ["rib", "mid", 0.74, 2], ["strands", "far", 0.5, 0]],
	33: [["camp", "home", 120, 0], ["rib", "mid", 0.34, 2], ["pillar", "mid", 0.56, 0], ["strands", "far", 0.5, 1]],
	34: [["camp", "home", 120, 1], ["pillar", "mid", 0.28, 1], ["rib", "mid", 0.5, 0], ["sac", "mid", 0.72, 0], ["strands", "far", 0.5, 1]],
	35: [["camp", "home", 120, 1], ["pillar", "mid", 0.3, 0], ["pillar", "mid", 0.62, 1], ["sac", "mid", 0.46, 1], ["knot_wall", "enemy", -150, 0], ["strands", "far", 0.5, 1]],
	36: [["camp", "home", 120, 1], ["sac", "mid", 0.26, 0], ["sac", "mid", 0.48, 2], ["sac", "mid", 0.7, 1], ["pores", "far", 0.5, 0]],
	37: [["camp", "home", 120, 2], ["sac", "mid", 0.3, 2], ["pillar", "mid", 0.5, 1], ["sac", "mid", 0.66, 0], ["pores", "far", 0.5, 1]],
	38: [["camp", "home", 120, 2], ["sac", "mid", 0.24, 1], ["tunnel_mouth", "mid", 0.5, 0], ["sac", "mid", 0.76, 2], ["pores", "far", 0.5, 1]],
	39: [["camp", "home", 120, 2], ["pillar", "mid", 0.26, 0], ["pillar", "mid", 0.44, 1], ["core_light", "far", 0.9, 0.6, 0.5], ["tunnel_mouth", "mid", 0.66, 1], ["pores", "far", 0.3, 2]],
	40: [["camp", "home", 120, 2], ["pillar", "mid", 0.24, 1], ["core_ribs", "mid", 0.56, 0], ["core_light", "far", 0.8, 1.0, 0.5], ["core_chamber", "enemy", -170, 0, 0.75]],
}

## One line per round for the change table (docs) and for QA: what is on screen that the neighbours do not have.
const NOTES := {
	1: "아침. 곡물 창고와 방풍림, 멀리 작은 둥지", 2: "곡물 창고와 불 켜진 노점", 3: "노점과 불 켜진 가게 둘", 4: "첫 불 꺼진 가게, 온전한 방책",
	5: "늦은 오후. 방책 한 곳이 무너지고 연기, 둥지가 커짐", 6: "불 꺼진 가게 둘, 버려진 수레", 7: "무너진 방책·수레·판자 친 가게", 8: "노을. 탄 노점, 방책 두 곳 붕괴",
	9: "방책 잔해뿐, 연기, 능선 위 둥지 전체", 10: "흐린 저녁. 둥지가 적 기지 바로 뒤 전면에 드러남",
	11: "과수원 문과 열매 달린 나무", 12: "사다리와 바구니, 나무 세 그루", 13: "첫 쓰러진 수레", 14: "곰팡이 핀 나무와 첫 안개",
	15: "버려진 착즙 헛간(중간 보스)", 16: "잎 진 나무와 짙은 안개 두 겹", 17: "수레 두 대 바리케이드", 18: "능선 너머 제분소 실루엣",
	19: "제분소가 중경으로, 부서진 물레", 20: "뿌리 아치를 지나 적 기지 뒤 제분소 폐허",
	21: "눈 덮인 울타리와 이정표, 아군 화덕 불빛", 22: "얼어붙은 저장고 하나", 23: "저장고 세 동", 24: "제분장과 얼어붙은 물레",
	25: "제분장 두 동, 멀리 얼음 방벽(보스)", 26: "식은 굴뚝, 방벽이 가까워짐", 27: "얼음 방벽과 관문", 28: "관문을 지나 굴뚝 지대, 지평선의 오븐 불빛",
	29: "굴뚝 숲, 오븐 불빛이 커짐", 30: "적 기지 뒤 오븐 심장, 하늘 아래가 달아오름",
	31: "균사 통로 입구: 갈빗대 둘", 32: "갈빗대 셋, 통로가 좁아짐", 33: "첫 균사 기둥", 34: "기둥·갈빗대·첫 포자낭",
	35: "기둥 사이 포자낭, 적 기지 뒤 매듭 벽", 36: "포자실: 포자낭 셋, 벽의 숨구멍", 37: "포자실 깊은 곳: 큰 포자낭과 기둥", 38: "굴 입구(잠입병의 길)와 포자낭",
	39: "핵실 앞: 기둥 둘, 굴, 멀리 핵의 빛", 40: "핵실: 핵으로 모이는 갈빗대와 맥동하는 균사",
}

static func chapter_of(index: int) -> int:
	return clampi((index - 1) / 10, 0, 3)

static func stage_of(index: int) -> float:
	return float((index - 1) % 10) / 9.0

static func sky_of(index: int) -> Array:
	var keys: Array = SKY[chapter_of(index)]
	var s := stage_of(index)
	var a: Array = keys[0]
	var b: Array = keys[keys.size() - 1]
	for i in range(keys.size() - 1):
		if s >= float(keys[i][0]) and s <= float(keys[i + 1][0]):
			a = keys[i]
			b = keys[i + 1]
			break
	var span := maxf(0.001, float(b[0]) - float(a[0]))
	var t := clampf((s - float(a[0])) / span, 0.0, 1.0)
	var out: Array = []
	for i in 4:
		out.append(Color(str(a[1][i])).lerp(Color(str(b[1][i])), t))
	return out

## Light of the round on ridge / field / set planes (at 2x zoom the sky itself is almost off screen, so the time of
## day has to sit on the land): [stage, colour] keys per chapter.
const LIGHT := [
	[[0.0, "ffffff"], [0.45, "ffffff"], [0.78, "f6dcc0"], [1.0, "c4ccd0"]],
	[[0.0, "ffffff"], [0.5, "f2ecd8"], [1.0, "ddd0c0"]],
	[[0.0, "ffffff"], [0.5, "eef0f6"], [1.0, "d9dcee"]],
	[[0.0, "ffffff"], [0.55, "f0f0f4"], [1.0, "e9e0f4"]],
]

static func light_of(index: int) -> Color:
	var keys: Array = LIGHT[chapter_of(index)]
	var st := stage_of(index)
	for i in range(keys.size() - 1):
		if st <= float(keys[i + 1][0]):
			var span := maxf(0.001, float(keys[i + 1][0]) - float(keys[i][0]))
			return Color(str(keys[i][1])).lerp(Color(str(keys[i + 1][1])), clampf((st - float(keys[i][0])) / span, 0.0, 1.0))
	return Color(str(keys[keys.size() - 1][1]))

static func spec(index: int) -> Dictionary:
	if not ROUNDS.has(index):
		return {}
	var ch := chapter_of(index)
	return {"index": index, "chapter": ch, "name": CHAPTER_NAMES[ch], "stage": stage_of(index), "sky": sky_of(index),
		"pal": PAL[ch], "light": light_of(index), "landmarks": ROUNDS[index], "boss": index % 5 == 0, "note": str(NOTES.get(index, ""))}

# ---- painters: (layer, x = centre, y = base line, variant) ----
static var _o := Vector2.ZERO      # origin and scale of the piece being painted (paint() sets them)
static var _k := 1.0

static func _b(l, x: float, y: float, w: float, h: float, c: String) -> void:
	if w < 0.0:
		x += w
		w = -w
	if h < 0.0:
		y += h
		h = -h
	l.box(Rect2(_o + (Vector2(x, y) - _o) * _k, Vector2(w, h) * _k), Color(c))

static func _p(l, ox: float, oy: float, pts: Array, c: String) -> void:
	var out := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		out.append(_o + (Vector2(ox + float(pts[i]), oy + float(pts[i + 1])) - _o) * _k)
	l.poly(out, Color(c))

## Draws `kind` with its base centre at (x, y). `piece_scale` scales the whole piece about that point.
static func paint(l, kind: String, x: float, y: float, v, piece_scale := 1.0) -> void:
	_o = Vector2(x, y)
	_k = piece_scale
	match kind:
		# ---- chapter 1: wheat village ----
		"shelter":
			_b(l, x - 49, y - 30, 52, 28, "e0d2ac")
			_p(l, x, y, [-57, -30, -39, -47, -8, -47, 10, -30], "bd8f6a")
			_b(l, x - 36, y - 19, 17, 17, "a99a74")
		"windbreak":
			_p(l, x, y, [-44, -2, -43, -22, -30, -35, -13, -38, 6, -29, 14, -32, 33, -21, 42, -2], "a9b585")
		"stall":
			# market stall: lit awning (0) or burnt frame (1)
			if int(v) == 0:
				_b(l, x - 22, y - 20, 44, 20, "d8c79c")
				_p(l, x, y, [-28, -20, -22, -31, 22, -31, 28, -20], "c98a66")
				for i in 4: _b(l, x - 24 + i * 13, y - 24, 6, 4, "eadfbe")
				_b(l, x - 14, y - 14, 28, 8, "f0d890")
			else:
				for dx in [-20.0, 16.0]: _b(l, x + dx, y - 26, 4, 26, "8c8272")
				_p(l, x, y, [-24, -26, -20, -31, 6, -29, 4, -24], "9a8f7c")
				_b(l, x - 16, y - 6, 30, 6, "a39883")
		"shop":
			# 0 = open and lit, 1 = closed (dark windows), 2 = boarded up, roof sagging
			var wall := "e3d5b3" if int(v) == 0 else ("c6c0ad" if int(v) == 1 else "b3b1a4")
			var roof := "bd7d5e" if int(v) == 0 else ("a08572" if int(v) == 1 else "8f8a82")
			_b(l, x - 26, y - 34, 52, 34, wall)
			if int(v) == 2: _p(l, x, y, [-32, -34, -20, -50, 6, -46, 22, -52, 32, -34], roof)
			else: _p(l, x, y, [-32, -34, -20, -52, 20, -52, 32, -34], roof)
			_b(l, x + 10, y - 60, 7, 12, "a79d88")
			for dx in [-19.0, 6.0]:
				_b(l, x + dx, y - 27, 13, 13, "f3dc8e" if int(v) == 0 else "8e9a98")
				if int(v) == 2: _b(l, x + dx - 2, y - 22, 17, 3, "a08c6a")
			if int(v) == 0:
				_b(l, x - 24, y - 12, 48, 5, "c98a66")
				_b(l, x - 4, y - 50, 8, 8, "f0d890")
		"smoke":
			# a leaning column: 0 thin, 1 wide and dull
			var c := "c9cfc8" if int(v) == 0 else "b5b9b4"
			for i in 5:
				var w := 10.0 + i * (4.0 if int(v) == 0 else 7.0)
				_b(l, x - w * 0.5 + i * 7.0, y - 18.0 - i * 16.0, w, 14, c)
		"palisade":
			# 0 = whole, 1 = one gap with fallen stakes, 2 = stumps only. Flat mass in the unit band, points above it.
			var n := 9
			for i in n:
				var px := x - 54.0 + i * 12.0
				var h := 30.0 + float(posmod(i * 7, 3)) * 2.0
				if int(v) == 1 and i >= 4 and i <= 5: h = 9.0
				if int(v) == 2: h = 8.0 + float(posmod(i * 5, 4)) * 4.0
				_b(l, px, y - h, 10, h, "b79e74")
				if h > 20.0: _p(l, px, y - h, [0, 0, 5, -7, 10, 0], "c4ac80")
			if int(v) != 2: _b(l, x - 56, y - 16, 112 if int(v) == 0 else 46, 4, "a48c66")
			if int(v) >= 1: _p(l, x, y, [-6, 0, 20, -8, 24, -4, 0, 3], "a48c66")
		"cart":
			# abandoned cart: 0 upright, 1 tipped onto its shaft
			if int(v) == 0:
				_b(l, x - 20, y - 20, 40, 12, "b59868")
				_b(l, x - 24, y - 24, 4, 16, "a38657")
				for dx in [-14.0, 8.0]: _b(l, x + dx, y - 9, 9, 9, "8f8468")
			else:
				_p(l, x, y, [-22, -4, 10, -26, 20, -18, -10, 0], "b59868")
				_b(l, x + 8, y - 12, 10, 10, "8f8468")
		"nest_far":
			# the nest on the far ridge; v = 0.3 (a bump) .. 1.0 (spires over the ridge)
			var s := float(v)
			_p(l, x, y, [-70 * s, 6, -46 * s, -34 * s, -18 * s, -50 * s, 12 * s, -44 * s, 40 * s, -62 * s, 58 * s, -30 * s, 80 * s, 6], "7f9a96")
			if s > 0.45:
				_b(l, x + 34 * s, y - 84 * s, 6, 26 * s, "7f9a96")
				_p(l, x + 37 * s, y - 84 * s, [-12, 0, -8, -9, 8, -9, 12, 0], "8faaa3")
			if s > 0.75:
				_b(l, x - 30 * s, y - 70 * s, 5, 24 * s, "7f9a96")
				_p(l, x - 28 * s, y - 70 * s, [-10, 0, -6, -8, 7, -8, 11, 0], "8faaa3")
				_b(l, x - 4, y - 40 * s, 8, 6, "8fd0c8")
		"nest_front":
			# R10: the nest stands right behind the enemy base. Spires and caps above the unit band, flat root mass in it.
			_p(l, x, y, [-150, 0, -128, -58, -92, -92, -40, -104, 10, -96, 52, -120, 96, -86, 130, -50, 150, 0], "86a09a")
			_p(l, x, y, [-110, 0, -96, -44, -60, -70, -10, -78, 44, -70, 84, -48, 104, 0], "93aca4")
			for sp in [[-96.0, 150.0, 16.0], [-30.0, 176.0, 22.0], [44.0, 196.0, 26.0], [100.0, 140.0, 14.0]]:
				_b(l, x + sp[0], y - sp[1], 7, sp[1] - 60.0, "7b9692")
				_p(l, x + sp[0] + 3.5, y - sp[1], [-sp[2], 0, -sp[2] * 0.6, -sp[2] * 0.7, sp[2] * 0.6, -sp[2] * 0.7, sp[2], 0], "9bb5ac")
				_b(l, x + sp[0] - 2, y - sp[1] + 6, 4, 4, "9be0d6")
			for eye in [[-58.0, -64.0], [4.0, -72.0], [60.0, -60.0]]:
				_b(l, x + eye[0], y + eye[1], 12, 6, "9be0d6")
		# ---- chapter 2: tainted orchard ----
		"orchard_gate":
			for dx in [-34.0, 28.0]: _b(l, x + dx, y - 62, 6, 62, "b39a70")
			_p(l, x, y, [-44, -62, -34, -74, 34, -74, 44, -62], "c2a878")
			_b(l, x - 16, y - 70, 32, 6, "d9c38e")
		"fruit_tree", "bare_tree", "blight_tree":
			var tall := 30.0 + float(int(v) % 3) * 6.0
			_b(l, x - 4, y - tall, 8, tall, "a8946e")
			if kind == "bare_tree":
				_p(l, x, y - tall, [-2, 0, -22, -20, -19, -23, 0, -6], "a8946e")
				_p(l, x, y - tall, [2, 0, 18, -26, 21, -23, 4, -4], "a8946e")
				_b(l, x - 2, y - tall - 22, 4, 22, "a8946e")
			else:
				var leaf := "b9b77c" if kind == "fruit_tree" else "9aa58c"
				_p(l, x, y - tall, [-30, 4, -32, -18, -18, -34, 6, -38, 28, -26, 32, -4, 14, 8, -14, 9], leaf)
				_b(l, x - 20, y - tall - 22, 24, 7, "c9c68a" if kind == "fruit_tree" else "a9b39a")
				if kind == "fruit_tree":
					for f in [[-16.0, -8.0], [0.0, -24.0], [16.0, -10.0]]: _b(l, x + f[0], y - tall + f[1], 5, 5, "cf8f62")
				else:
					# caps growing out of the crown, pale spots: the blight is a shape, not a tint
					_p(l, x - 12, y - tall - 30, [-12, 0, -8, -8, 8, -8, 12, 0], "7f9c98")
					_p(l, x + 14, y - tall - 20, [-9, 0, -6, -6, 6, -6, 9, 0], "7f9c98")
					_b(l, x - 22, y - tall - 6, 5, 5, "c9dcd2")
					_b(l, x + 8, y - tall - 2, 5, 5, "c9dcd2")
		"tree_ridge":
			# far row of crowns: 0 full, 1 thinning, 2 bare trunks. Spacing and height vary.
			for i in range(-14, 15):
				var tx := x + i * 58.0 + float(posmod(i * 37, 23))
				var th := 18.0 + float(posmod(i * 13, 14))
				if int(v) == 2 or (int(v) == 1 and posmod(i, 3) == 0):
					_b(l, tx, y - th - 8, 4, th + 8, "a39c84")
					_p(l, tx, y - th - 8, [0, 0, -12, -10, -10, -13, 2, -2], "a39c84")
				else:
					_p(l, tx, y, [-22, 0, -24, -th * 0.6, -10, -th, 12, -th - 4, 26, -th * 0.5, 24, 0], "a9ad84")
		"ladder":
			_p(l, x, y, [-10, 0, 2, -44, 6, -44, -6, 0], "b89b68")
			_p(l, x, y, [8, 0, 10, -44, 14, -44, 12, 0], "b89b68")
			for i in 4: _b(l, x - 5 + i, y - 10 - i * 9, 16, 3, "c7ab78")
			if int(v) == 1: _b(l, x + 18, y - 9, 14, 9, "c9a56c")
		"cart_fallen":
			_p(l, x, y, [-26, 0, -18, -20, 14, -26, 24, -8, 18, 0], "b0935f")
			_b(l, x - 8, y - 34, 12, 12, "93876a")
			_b(l, x - 5, y - 31, 6, 6, "b0a482")
			if int(v) == 1: _p(l, x, y, [20, 0, 34, -14, 38, -11, 26, 0], "a08655")
			for a in [[-34.0, -4.0], [30.0, -5.0]]: _b(l, x + a[0], y + a[1], 6, 5, "cf8f62")
		"press_house":
			_b(l, x - 44, y - 44, 88, 44, "b8ab8c")
			_p(l, x, y, [-52, -44, -30, -68, 16, -64, 30, -70, 52, -44], "9b8f7c")
			_b(l, x - 12, y - 30, 24, 30, "8c8876")
			for dx in [-36.0, 22.0]: _b(l, x + dx, y - 34, 12, 12, "8e9a98")
			_p(l, x + 46, y, [0, 0, 6, -30, 30, -34, 34, 0], "a79a78")
			_b(l, x + 54, y - 46, 5, 14, "a79a78")
		"mill_ruin":
			# the abandoned mill: 0 = whole silhouette with a broken wheel, 1 = taken by the blight (behind the base)
			_b(l, x - 30, y - 86, 60, 86, "b3ac98" if int(v) == 0 else "9fa9a0")
			_p(l, x, y - 86, [-36, 0, -22, -26, 4, -22, 12, -30, 36, 0], "9c9486" if int(v) == 0 else "86968f")
			_b(l, x - 10, y - 70, 20, 16, "8e9a98")
			_b(l, x - 9, y - 26, 18, 26, "8f8c7c")
			# wheel: three spokes left, the fourth lies on the ground
			_p(l, x + 40, y - 40, [-3, 0, -3, -36, 3, -36, 3, 0], "a59876")
			_p(l, x + 40, y - 40, [0, -3, 34, -10, 36, -4, 0, 3], "a59876")
			_p(l, x + 40, y - 40, [0, 3, -30, 14, -32, 8, 0, -3], "a59876")
			_b(l, x + 34, y - 46, 12, 12, "8f8468")
			_p(l, x + 58, y, [0, 0, 30, -5, 32, 0], "a59876")
			if int(v) == 1:
				for cap in [[-22.0, -112.0, 16.0], [14.0, -124.0, 20.0], [-2.0, -100.0, 12.0]]:
					_b(l, x + cap[0], y + cap[1], 5, 30, "7b9692")
					_p(l, x + cap[0] + 2.5, y + cap[1], [-cap[2], 0, -cap[2] * 0.6, -cap[2] * 0.6, cap[2] * 0.6, -cap[2] * 0.6, cap[2], 0], "93ada5")
				_b(l, x - 6, y - 66, 12, 6, "9be0d6")
		"fog":
			# two soft slabs above the unit band; never at foot height
			var c := "d6d3bb" if int(v) == 0 else "c9c9b8"
			_p(l, x, y, [-150, -8, -120, -18, 60, -18, 130, -8, 60, -3, -110, -3], c)
			_p(l, x + 40, y - 22, [-90, 0, -60, -8, 70, -8, 100, 0], c)
		"root_arch":
			_p(l, x, y, [-70, 0, -62, -60, -30, -96, 16, -100, 54, -72, 66, 0, 52, 0, 42, -62, 12, -84, -26, -80, -48, -54, -54, 0], "8c9a8a")
			_b(l, x - 8, y - 104, 16, 8, "a9b89f")
			for cap in [[-58.0, -64.0], [50.0, -76.0]]: _p(l, x + cap[0], y + cap[1], [-12, 0, -8, -8, 8, -8, 12, 0], "93ada5")
		# ---- chapter 3: frost road ----
		"peaks":
			for i in range(-10, 11):
				var px := x + i * 150.0 + float(posmod(i * 41, 50))
				var ph := 46.0 + float(posmod(i * 29, 40)) + (16.0 if int(v) == 1 else 0.0)
				_p(l, px, y, [-80, 10, -22, -ph, 4, -ph + 8, 28, -ph - 6, 90, 10], "a9b9cb")
				_p(l, px, y, [-22, -ph, 4, -ph + 8, 28, -ph - 6, 40, -ph + 14, 8, -ph + 24, -30, -ph + 18], "e6edf0")
		"hearth":
			# the bakery's field oven by the keep: a warm light that reads from across the lane. v = 0 bright .. 2 far from home, lower fire
			_b(l, x - 22, y - 34, 44, 34, "c9a888")
			_p(l, x, y, [-26, -34, -14, -50, 14, -50, 26, -34], "b98a6a")
			_b(l, x + 6, y - 70, 9, 22, "b9a08a")
			_b(l, x - 12, y - 22, 24, 22, "f2a65a" if int(v) < 2 else "e0935a")
			_b(l, x - 7, y - 16, 14, 16, "ffd98a")
			# light on the snow: a warm wedge on the ground plane above the lane edge, wider near home
			var reach := 120.0 - 26.0 * float(int(v))
			_p(l, x, y, [-reach * 0.5, 0, -18, -8, 18, -8, reach, 0], "e9c79a")
		"snow_fence":
			for i in 7:
				var fx := x - 42.0 + i * 14.0
				var fh := 20.0 + float(posmod(i * 5, 3)) * 3.0 - (8.0 if int(v) == 1 and i > 4 else 0.0)
				_b(l, fx, y - fh, 5, fh, "a59a86")
				_b(l, fx - 1, y - fh - 3, 7, 3, "e6edf0")
			_b(l, x - 44, y - 13, 96, 3, "a59a86")
		"signpost":
			_b(l, x - 2, y - 46, 5, 46, "8f8672")
			_p(l, x, y - 44, [-4, 0, 22, 0, 30, 6, 22, 12, -4, 12], "c4a66f")
			_b(l, x - 4, y - 49, 26, 3, "e6edf0")
		"silo":
			# frozen storehouse: v changes height and how far the ice has climbed
			var h := 62.0 + float(int(v)) * 12.0
			_b(l, x - 20, y - h, 40, h, "b6bcc0")
			_p(l, x, y - h, [-22, 0, -12, -14, 12, -14, 22, 0], "c9d0d4")
			_b(l, x - 22, y - h * 0.5, 44, 4, "9aa4ac")
			_b(l, x - 6, y - 20, 12, 20, "8f989e")
			_p(l, x, y, [-26, 0, -22, -18 - 8.0 * int(v), -10, -8, 4, -22 - 6.0 * int(v), 16, -6, 26, 0], "dbe6ea")
			_b(l, x - 14, y - h - 17, 28, 4, "eef3f4")
		"mill_hall":
			# the milling hall: long roof, frozen wheel. 1 = seen from the other end (wheel on the left)
			var sgn := -1.0 if int(v) == 1 else 1.0
			_b(l, x - 56, y - 50, 112, 50, "b3b8ba")
			_p(l, x, y - 50, [-62, 0, -44, -24, 44, -24, 62, 0], "c7ced2")
			_b(l, x - 60, y - 53, 120, 4, "eef3f4")
			for dx in [-40.0, -12.0, 16.0]: _b(l, x + dx * sgn - 6, y - 38, 12, 14, "8f9ca6")
			var wx := x + 70.0 * sgn
			_b(l, wx - 24, y - 52, 48, 5, "9aa4ac")
			_b(l, wx - 3, y - 76, 5, 52, "9aa4ac")
			_p(l, wx, y - 50, [-17, -19, -13, -23, 19, 17, 15, 21], "9aa4ac")
			_p(l, wx, y - 50, [-12, 18, 2, -2, 6, -22, 12, -22, 6, 4, -8, 22], "dbe6ea")
		"chimney":
			# cold stacks of the bake works; no smoke. v = 0..2 changes the cluster
			for st in ([[0.0, 92.0]] if int(v) == 0 else ([[-16.0, 78.0], [14.0, 104.0]] if int(v) == 1 else [[-26.0, 70.0], [0.0, 112.0], [24.0, 86.0]])):
				_b(l, x + st[0] - 7, y - st[1], 14, st[1], "aaa7a6")
				_b(l, x + st[0] - 9, y - st[1] - 5, 18, 6, "9a9796")
				_b(l, x + st[0] - 9, y - st[1] - 8, 18, 3, "eef3f4")
			_b(l, x - 34, y - 18, 68, 18, "b3b8ba")
		"ice_wall":
			# a rampart of ice blocks: upright slabs with flat tops, above the unit band. 1 = nearer (taller)
			var k := 1.0 if int(v) == 0 else 1.35
			for i in range(-5, 6):
				var ix := x + i * 44.0
				var ih := (58.0 + float(posmod(i * 17, 22))) * k
				_b(l, ix - 20, y - ih, 40, ih, "b9cdd8")
				_b(l, ix - 20, y - ih, 40, 5, "e9f1f4")
				_b(l, ix + 12, y - ih + 5, 8, ih - 5, "a6bccb")
		"ice_gate":
			# the gate through the wall. 1 = seen from behind (passed)
			_b(l, x - 74, y - 86, 44, 86, "b9cdd8")
			_b(l, x + 30, y - 86, 44, 86, "b9cdd8")
			_b(l, x - 74, y - 92, 148, 8, "e9f1f4")
			_p(l, x, y - 86, [-30, 0, -18, 14, 18, 14, 30, 0], "a6bccb")
			if int(v) == 0:
				_b(l, x - 30, y - 60, 60, 60, "93a8b8")
				_b(l, x - 3, y - 60, 6, 60, "a6bccb")
			else:
				_p(l, x, y, [-30, 0, -30, -44, -20, -52, -16, 0], "93a8b8")
		"oven_glow":
			# the Oven Heart beyond the horizon: warm bands under the cold sky; v = how much of it shows
			var s := float(v)
			_p(l, x, y, [-240 * s, 8, -150 * s, -22 * s, 0, -40 * s, 150 * s, -22 * s, 240 * s, 8], "e7c3a0")
			_p(l, x, y, [-150 * s, 8, -80 * s, -10 * s, 0, -22 * s, 80 * s, -10 * s, 150 * s, 8], "f2c98e")
			if s > 0.7:
				_b(l, x - 22, y - 74 * s, 14, 60 * s, "a99f9c")
				_b(l, x + 12, y - 92 * s, 16, 78 * s, "a99f9c")
				_b(l, x + 14, y - 96 * s, 12, 5, "f6b36a")
		"oven_heart":
			# R30: the furnace behind the enemy base. Brick mass, three stacks, the mouth is the only bright orange.
			_p(l, x, y, [-140, 0, -128, -70, -84, -104, 84, -104, 128, -70, 140, 0], "a59a96")
			_b(l, x - 96, y - 112, 192, 10, "b9aeaa")
			for st in [[-70.0, 170.0], [-8.0, 206.0], [58.0, 182.0]]:
				_b(l, x + st[0] - 11, y - st[1], 22, st[1] - 104.0, "9c918e")
				_b(l, x + st[0] - 14, y - st[1] - 6, 28, 7, "b9aeaa")
				_b(l, x + st[0] - 6, y - st[1] - 12, 12, 6, "f6b36a")
			_p(l, x, y, [-44, -52, -36, -84, 0, -96, 36, -84, 44, -52], "e58c4e")
			_p(l, x, y, [-28, -52, -22, -74, 0, -82, 22, -74, 28, -52], "ffd28a")
			for dx in [-104.0, 92.0]: _b(l, x + dx, y - 84, 12, 26, "8f989e")
		# ---- chapter 4: nest depths ----
		"camp":
			# forward camp instead of the town: field oven, lantern posts, supply crates. v = how deep (fewer lights)
			_b(l, x - 18, y - 26, 36, 26, "c4a888")
			_p(l, x, y, [-22, -26, -12, -40, 12, -40, 22, -26], "b08868")
			_b(l, x - 9, y - 18, 18, 18, "f2a65a")
			_b(l, x - 5, y - 13, 10, 13, "ffd98a")
			for i in (3 - int(v)):
				var lx := x + 40.0 + i * 46.0
				_b(l, lx, y - 52, 4, 52, "a3977f")
				_b(l, lx - 5, y - 62, 14, 12, "ffd98a")
				_b(l, lx - 7, y - 65, 18, 4, "b08868")
			_b(l, x - 52, y - 14, 20, 14, "bfa57a")
			_b(l, x - 46, y - 26, 14, 12, "cdb488")
		"strands":
			# hanging hyphae on the far wall: thin verticals of uneven length; 1 = denser
			for i in range(-12, 13):
				if int(v) == 0 and posmod(i, 2) == 1: continue
				var sx := x + i * 70.0 + float(posmod(i * 31, 40))
				var sl := 40.0 + float(posmod(i * 23, 70))
				sl = 14.0 + sl * 0.4
				_b(l, sx, y - 52, 4, sl, "8fa39b")
				_b(l, sx - 3, y - 52 + sl, 10, 6, "a3b6ab")
		"rib":
			# tunnel rib: a leaning arch segment from floor to ceiling. Variants lean and split differently.
			var lean: float = [18.0, -14.0, 6.0][int(v) % 3]
			_p(l, x, y, [-16, 0, -10 + lean, -110, 14 + lean, -150, 30 + lean, -150, 12 + lean, -104, 10, 0], "8a9f97")
			_p(l, x, y, [-4, 0, 2 + lean, -100, 10 + lean, -100, 6, 0], "9db0a6")
			if int(v) == 2: _p(l, x + lean, y - 104, [8, 0, 44, -30, 50, -24, 14, 6], "8a9f97")
			_b(l, x - 22, y - 6, 44, 6, "7f948c")
		"pillar":
			var w := 26.0 + 8.0 * float(int(v) % 2)
			_p(l, x, y, [-w, 0, -w * 0.6, -60, -w * 0.8, -150, w * 0.8, -150, w * 0.6, -60, w, 0], "84998f")
			_b(l, x - w * 0.3, y - 150, w * 0.5, 150, "97aaa0")
			for kn in [[-0.5, -50.0], [0.3, -92.0]]: _b(l, x + w * kn[0], y + kn[1], 10, 8, "a9bcb0")
		"sac":
			# spore sac hanging from the ceiling: stalk + bulb + pale pores. Bigger with v. The bulb stays above the unit band.
			var r := 12.0 + 4.0 * float(int(v))
			var drop := 38.0 - 3.0 * float(int(v))
			_b(l, x - 3, y - 150, 6, 150 - drop - r, "8a9f97")
			_p(l, x, y - drop, [-r, 0, -r * 0.8, -r * 0.9, 0, -r * 1.3, r * 0.8, -r * 0.9, r, 0, r * 0.6, r * 0.6, -r * 0.6, r * 0.6], "a09bb6")
			_b(l, x - r * 0.5, y - drop - r * 0.6, 6, 6, "d9d2ea")
			_b(l, x + r * 0.2, y - drop - r * 0.2, 5, 5, "d9d2ea")
		"pores":
			# breathing holes in the chamber wall, uneven rows
			for i in range(-10, 11):
				var px := x + i * 84.0 + float(posmod(i * 47, 50))
				var py := y - 8.0 - float(posmod(i * 19, 30))
				var pw := 14.0 + float(posmod(i * 7, 3)) * 5.0 + 4.0 * float(int(v))
				_b(l, px, py, pw, 8, "7d908c")
				_b(l, px + 3, py + 2, pw - 6, 4, "b3aed0" if posmod(i, 3) == 0 else "93a59c")
		"tunnel_mouth":
			# a burrow in the wall: the raiders' way. Pale rim, mid-tone hollow, above the unit band.
			_p(l, x, y - 6, [-34, 0, -30, -30, -10, -46, 14, -46, 32, -28, 34, 0], "a9bcb0")
			_p(l, x, y - 6, [-24, 0, -22, -24, -6, -36, 10, -36, 24, -22, 24, 0], "73877f")
			if int(v) == 1: _p(l, x, y - 6, [-36, 0, -62, 2, -62, 6, -36, 5], "a9bcb0")
		"knot_wall":
			_p(l, x, y, [-120, 0, -110, -70, -70, -100, 0, -108, 70, -100, 110, -70, 120, 0], "7f948c")
			for kn in ([[-70.0, -84.0], [-10.0, -98.0], [56.0, -88.0]] if int(v) == 0 else []):
				_p(l, x + kn[0], y + kn[1], [-12, 0, -8, -10, 8, -10, 12, 0, 8, 10, -8, 10], "a09bb6")
				_b(l, x + kn[0] - 3, y + kn[1] - 3, 6, 6, "d9d2ea")
		"core_light":
			# the core's glow at the end of the chamber; v = strength
			var s := float(v)
			_p(l, x, y, [-200 * s, 10, -120 * s, -50 * s, 0, -84 * s, 120 * s, -50 * s, 200 * s, 10], "a59fc0")
			_p(l, x, y, [-110 * s, 10, -60 * s, -28 * s, 0, -48 * s, 60 * s, -28 * s, 110 * s, 10], "bdb6d6")
		"core_ribs":
			# ribs that all lean towards the core (to the right): the chamber points at the target
			for i in 4:
				var rx := x - 150.0 + i * 96.0
				var top := 60.0 + i * 16.0
				_p(l, rx, y, [-12, 0, 6 + top * 0.5, -96, top, -150, top + 18, -150, 22 + top * 0.5, -92, 10, 0], "8a8fa6")
				_p(l, rx, y, [-2, 0, 12 + top * 0.5, -90, 18 + top * 0.5, -90, 6, 0], "a2a6bc")
		"core_chamber":
			# R40: the wall behind the base holds the core's cradle: a ring of ribs around a hollow. The pulse is drawn live.
			_p(l, x, y, [-150, 0, -140, -84, -96, -128, 0, -146, 96, -128, 140, -84, 150, 0], "86889f")
			_p(l, x, y, [-92, -40, -84, -92, -40, -120, 40, -120, 84, -92, 92, -40], "9d9db4")
			_p(l, x, y, [-58, -52, -52, -90, -22, -106, 22, -106, 52, -90, 58, -52], "b8b3d0")
			for dx in [-120.0, -66.0, 60.0, 114.0]:
				_p(l, x + dx, y, [-6, 0, -2, -150, 8, -150, 6, 0], "7f8298")
