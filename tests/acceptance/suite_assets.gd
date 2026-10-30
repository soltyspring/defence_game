extends RefCounted
## Image/atlas integration acceptance. Checks the manifest on disk AND what the runtime will actually
## resolve for the content used by P0 rounds (so a sprite that exists but is never found is a FAIL).
## Owner: 07-qa. Contract: INTERFACES.md §5, ENGINE.md §8.

const Q := preload("res://tests/acceptance/qa_lib.gd")
const MANIFEST := "res://assets/manifest.json"

func run(q, tree) -> void:
	q.current_suite = "assets"
	var m = Q.read_json(MANIFEST)
	if not (m is Dictionary):
		q.record("ART-01", Q.NOT_IMPL, "assets/manifest.json present", "missing or unparsable; engine uses procedural placeholders")
		return
	q.record("ART-01", Q.PASS, "assets/manifest.json present and parses")
	var file_issues := []
	var pages := {}
	for a in m.get("atlases", []):
		var id := str(a.get("id", ""))
		var img_path := str(a.get("image", ""))
		var fr_path := str(a.get("frames", ""))
		if not FileAccess.file_exists(img_path): file_issues.append("%s image %s missing" % [id, img_path]); continue
		if not FileAccess.file_exists(fr_path): file_issues.append("%s frames %s missing" % [id, fr_path]); continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(img_path))
		var fr = Q.read_json(fr_path)
		if img == null or not (fr is Dictionary):
			file_issues.append("%s unreadable" % id); continue
		var w := img.get_width(); var h := img.get_height()
		var decl: Array = a.get("size", [0, 0])
		if int(decl[0]) != w or int(decl[1]) != h: file_issues.append("%s declared %s actual %dx%d" % [id, decl, w, h])
		if w > 2048 or h > 2048: file_issues.append("%s exceeds 2048 hard limit (%dx%d)" % [id, w, h])
		if a.has("gpu_bytes") and int(a.gpu_bytes) != w * h * 4: file_issues.append("%s gpu_bytes %s != %d" % [id, a.gpu_bytes, w * h * 4])
		var frames: Dictionary = fr.get("frames", {})
		for fname in frames:
			var f: Dictionary = frames[fname]
			if int(f.x) < 0 or int(f.y) < 0 or int(f.x) + int(f.w) > w or int(f.y) + int(f.h) > h:
				file_issues.append("%s frame %s out of bounds" % [id, fname])
		for set_id in fr.get("anims", {}):
			for an in fr.anims[set_id]:
				for fn in fr.anims[set_id][an].get("frames", []):
					if not frames.has(str(fn)): file_issues.append("%s anim %s/%s frame %s missing" % [id, set_id, an, fn])
		var imp := img_path + ".import"
		if FileAccess.file_exists(imp):
			var t := FileAccess.get_file_as_string(imp)
			if not ("compress/mode=0" in t and "mipmaps/generate=false" in t):
				file_issues.append("%s import not lossless/no-mipmap" % id)
		pages[id] = {"w": w, "h": h, "frames": frames.size()}
	q.check("ART-02", "every atlas page: files exist, size/gpu_bytes match, frames in bounds, anim frames exist, lossless import", file_issues.is_empty(), "; ".join(file_issues.slice(0, 12)), {"pages": pages})

	var content = tree.root.get_node_or_null("Content")
	var atlas = tree.root.get_node_or_null("Atlas")
	if content == null or atlas == null:
		q.record("ART-03", Q.BLOCKED, "runtime sprite resolution", "Content/Atlas autoload missing")
		return
	var p0: Array = Array(content.round_order).slice(0, 3)
	# what the runtime will ask the atlas for (battle.gd / battle_view.gd / battle_sim.gd)
	var unit_sets := {}      # anim_set -> [who]
	var proj := {}
	var biomes := {}
	var icons := []
	for rid in p0:
		var r: Dictionary = content.get_round(rid)
		biomes[str(r.biome)] = rid
		var hero: Dictionary = content.heroes.get(str(r.hero), {})
		unit_sets[str(hero.get("anim_set", ""))] = "hero " + str(hero.get("id", ""))
		var ids: Array = content.round_cards(r)
		for c in ids:
			icons.append("card_" + str(c))
		for s in content.round_skills(r):
			icons.append("skill_" + str(s))
		for w in r.waves:
			for sp in w.get("spawns", []): ids.append(str(sp.unit))
		for u in r.enemy_ai.get("pool", []): ids.append(str(u))
		for u in r.get("trickle", {}).get("pattern", []): ids.append(str(u))
		for id in ids:
			var u: Dictionary = content.get_unit(str(id))
			unit_sets[str(u.anim_set)] = "unit " + str(id)
			var at := str(u.get("attack_type", "melee"))
			if at == "ranged" or at == "siege":
				var pk := str(u.get("projectile", ""))
				proj[pk if pk != "" else ("rock" if at == "siege" else "arrow")] = str(id)
	proj["tower_bolt"] = "base tower"
	var pages_needed: Array = []
	for p in atlas.pages_for_battle(unit_sets.keys(), str(biomes.keys()[0])):
		pages_needed.append(p)
		atlas.acquire(p)
	var unresolved := []
	for s in unit_sets:
		for an in ["walk", "attack", "death"]:
			if atlas.anim_frame(s, an, 0.0).is_empty():
				unresolved.append("%s(%s).%s" % [s, unit_sets[s], an])
	q.check("ART-03", "P0 characters resolve to atlas sprites (else procedural placeholder is drawn)", unresolved.is_empty(),
		"%d unresolved: %s" % [unresolved.size(), ", ".join(unresolved.slice(0, 10))], {"anim_sets": unit_sets, "unresolved": unresolved})
	var proj_bad := []
	for k in proj:
		if atlas.anim_frame(k, "fly", 0.0).is_empty(): proj_bad.append("%s(%s)" % [k, proj[k]])
	q.check("ART-04", "P0 projectiles resolve to atlas 'fly' anims", proj_bad.is_empty(), "unresolved: %s" % [proj_bad], {"kinds": proj})
	var fx := {"hit_spark": "melee hit", "explosion": "splash"}
	for rid in p0:
		for s in content.round_skills(content.get_round(rid)):
			var f := str(content.skills[s].get("fx", ""))
			fx[f if f != "" else str(content.skills[s].kind)] = "skill " + str(s)
	var fx_bad := []
	for k in fx:
		if atlas.anim_frame(k, "play", 0.0).is_empty() and atlas.anim_frame(k, "loop", 0.0).is_empty():
			fx_bad.append("%s(%s)" % [k, fx[k]])
	q.check("ART-05", "P0 combat/skill fx resolve to atlas anims", fx_bad.is_empty(), "unresolved: %s" % [fx_bad], {"kinds": fx})
	var bio_bad := []
	for b in biomes:
		if not m.get("biomes", {}).has(b): bio_bad.append("%s (round %s)" % [b, biomes[b]])
	q.check("ART-06", "P0 round biomes exist in manifest.biomes (else flat procedural background)", bio_bad.is_empty(),
		"round biome ids %s not in manifest biomes %s" % [bio_bad, m.get("biomes", {}).keys()])
	var icon_bad := []
	for i in icons:
		if atlas.get_frame_texture("ui_main", i) == null: icon_bad.append(i)
	q.check("ART-07", "P0 card/skill icons requested by battle_info resolve in ui_main", icon_bad.is_empty(), "missing: %s" % [icon_bad], {"icons": icons})
	var base_bad := []
	for k in ["player", "enemy"]:
		var bm: Dictionary = m.get("bases", {}).get(k, {})
		if atlas.frame(str(bm.get("atlas", "")), str(bm.get("frame", ""))).is_empty(): base_bad.append(k)
	q.check("ART-08", "base sprites resolve", base_bad.is_empty(), "unresolved: %s" % [base_bad])
	var rep: Dictionary = atlas.texture_report()
	q.check("ART-09", "battle texture residency <= 32 MiB low-tier budget (ENGINE.md §7, desktop estimate)", int(rep.resident_gpu_bytes) <= 32 * 1024 * 1024,
		"resident %d bytes" % int(rep.resident_gpu_bytes), {"resident_gpu_bytes": rep.resident_gpu_bytes, "pages": pages_needed})
	for p in pages_needed:
		atlas.release(p)
	var after: Dictionary = atlas.texture_report()
	var leaked := []
	for pg in after.pages:
		if str(atlas.pages[pg.id].meta.get("group", "")) != "ui": leaked.append(pg.id)
	q.check("ART-10", "non-UI atlas pages released after battle refcount drops", leaked.is_empty(), "still resident: %s" % [leaked])
	# missing-asset tolerance
	var miss_ok: bool = atlas.anim_frame("__qa_missing__", "walk", 0.0).is_empty() and atlas.frame("__qa_none__", "x").is_empty() and atlas.get_frame_texture("__qa_none__", "x") == null
	q.check("ART-11", "missing atlas/anim lookups return empty (placeholder path) without error", miss_ok)
