extends SceneTree
## 06-services: the coin upgrade purchase (02 Save.buy_upgrade, 4d77225; 04 upgrade_panel.gd) stays
## an in-game coin spend, separate from ads and billing, while Q2 (business model) is DEFERRED
## by the user (2026-10-31 16:09 KST).
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_upgrade.gd
## Exit 0 = pass, 1 = failure. Uses the autoload Save redirected to an isolated dir (the player's
## user://save.json is hash-checked unchanged) and the game's own /root/Services (disabled).
##  - static_isolation: the upgrade code in save.gd/app.gd/upgrade_panel.gd (comments stripped)
##    calls no Services, ads, billing, receipt, store or network API.
##  - data_isolation: data/meta.json upgrades cost only coins (gold); no product/price/ad fields;
##    iap_catalog disabled and empty; gems disabled.
##  - runtime_direct / runtime_app_path: buying through Save.buy_upgrade and through
##    Events.cmd_buy_upgrade -> App leaves Services untouched (diagnostics, progress.services),
##    results carry only {id, to_level, code, coins, level}, codes come from Save.UPG_*.
## Not covered: what a future monetized upgrade (gems, ads) would need. That is a Q2 decision.

const BASE_FMT := "user://svc_upg_test_%d"
## Calls or names that would tie the coin upgrade to monetization or the network.
const FORBIDDEN_CORE := ["Services", "purchases.", "ads.", "billing", "receipt", "token", "sku", "product",
	"rewarded", "show_ad", "iap", "gems", "verifier", "shell_open", "HTTPRequest", "HTTPClient", "JavaClassWrapper",
	"Engine.get_singleton", "consent", "analytics"]
## The 04 panel says "purchase" for the coin spend; it must still not reach these.
const FORBIDDEN_UI := ["Services", "billing", "receipt", "token", "sku", "product", "rewarded", "show_ad",
	"iap", "gems", "shell_open", "HTTPRequest", "JavaClassWrapper", "Engine.get_singleton", "consent", "analytics"]
const UPGRADE_KEYS := ["id", "target", "name_key", "max_level", "costs", "per_level"]
const RESULT_KEYS := ["code", "coins", "id", "level", "to_level"]

var BASE := BASE_FMT % OS.get_process_id()
## Sources read by the static/data checks. Mutation tests pass temp copies with
## `-- --save-gd=<p> --app-gd=<p> --meta=<p> --panel=<p>`; other roles' files are never edited.
## `--selfcheck-touch-services` writes into progress.services between the snapshots to prove the
## runtime detector fires (detector self-check, not a product behaviour).
var SRC := {"save-gd": "res://src/core/save.gd", "app-gd": "res://src/core/app.gd", "meta": "res://data/meta.json", "panel": "res://src/ui/upgrade_panel.gd"}
var selfcheck_touch := false
var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}}
var save: Node
var orig_path := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		for k in SRC:
			if a.begins_with("--%s=" % k):
				SRC[k] = a.substr(k.length() + 3)
		if a == "--selfcheck-touch-services":
			selfcheck_touch = true
	_run.call_deferred()

func _run() -> void:
	save = root.get_node_or_null("Save")
	if save == null or not save.has_method("buy_upgrade"):
		printerr("[test_services_upgrade] Save autoload or Save.buy_upgrade missing; run with --path .")
		quit(1)
		return
	orig_path = save.path
	var h0 := _hash_user_save()
	_group("static_isolation", test_static)
	_group("data_isolation", test_data)
	_group("runtime_direct", test_direct)
	_group("runtime_app_path", test_app_path)
	_group("q2_repo_scan", test_q2_repo_scan)
	save.path = orig_path
	save.load_progress()
	_group("hygiene", func() -> bool:
		check(_hash_user_save() == h0, "player's user://save.json(.bak) unchanged")
		return true)
	_wipe(BASE)
	DirAccess.remove_absolute(BASE)
	print("[test_services_upgrade] passes=%d failures=%d" % [passes, failures.size()])
	for g in report.groups:
		print("  %-22s %s" % [g, report.groups[g]])
	quit(0 if failures.is_empty() else 1)

func _group(name: String, fn: Callable) -> void:
	current = name
	var before := failures.size()
	var p0 := passes
	var done = fn.call()
	if done != true:
		check(false, "group aborted before its end")
	report.groups[name] = "PASS (%d checks)" % (passes - p0) if failures.size() == before else "FAIL"

func check(cond: bool, msg: String) -> bool:
	if cond:
		passes += 1
	else:
		failures.append(current + ": " + msg)
		printerr("FAIL [%s] %s" % [current, msg])
	return cond

func eq(a: Variant, b: Variant, msg: String) -> bool:
	return check(a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])

func _hash_user_save() -> String:
	var s := ""
	for p in ["user://save.json", "user://save.json.bak"]:
		s += (FileAccess.get_file_as_string(p).sha256_text() if FileAccess.file_exists(p) else "absent") + ";"
	return s

func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_wipe(dir + "/" + sub)
		d.remove(sub)

func use_dir(name: String, coins: int) -> String:
	var p := BASE + "/" + name
	_wipe(p)
	DirAccess.make_dir_recursive_absolute(p)
	save.path = p + "/save.json"
	save.load_progress()
	save.progress["coins"] = coins
	save.save_progress()
	return p

## Code without comments (whole-line and trailing `#`), so documentation wording does not count.
static func code_only(src: String) -> String:
	var out := PackedStringArray()
	for line in src.split("\n"):
		var l := line
		var i := l.find("#")
		if i >= 0:
			l = l.left(i)
		if l.strip_edges() != "":
			out.append(l)
	return "\n".join(out)

## Body of `func <name>` up to the next top-level func.
static func func_body(src: String, fname: String) -> String:
	var a := src.find("func " + fname + "(")
	if a < 0:
		return ""
	var b := src.find("\nfunc ", a + 5)
	return src.substr(a, (b - a) if b > a else -1)

func scan(label: String, text: String, forbidden: Array) -> void:
	var low := text.to_lower()
	for w in forbidden:
		check(not low.contains(str(w).to_lower()), "%s: no '%s'" % [label, w])

## Services state that a coin upgrade must not touch.
func services_state() -> Dictionary:
	var sv = root.get_node_or_null("Services")
	if sv == null:
		return {}
	sv.ensure_bound()
	return {"diag": sv.diagnostics(), "mode": sv.mode,
		"data": (save.progress.get("services", {}) as Dictionary).duplicate(true)}

func test_static() -> bool:
	var sg := FileAccess.get_file_as_string(SRC["save-gd"])
	var names := ["buy_upgrade", "upgrade_level", "upgrade_cost", "_upgrade_def", "_upgrade_locked", "_content"]
	for n in names:
		var body := code_only(func_body(sg, n))
		if check(body != "", "save.gd has func %s" % n):
			scan("save.gd %s" % n, body, FORBIDDEN_CORE)
	var bu := code_only(func_body(sg, "buy_upgrade"))
	check(bu.contains("save_progress()"), "buy_upgrade commits through Save.save_progress (local file only)")
	var ag := FileAccess.get_file_as_string(SRC["app-gd"])
	var ab := code_only(func_body(ag, "_on_buy_upgrade"))
	if check(ab != "", "app.gd has _on_buy_upgrade"):
		scan("app.gd _on_buy_upgrade", ab, FORBIDDEN_CORE)
		check(ab.contains("Save.buy_upgrade("), "App routes cmd_buy_upgrade to Save.buy_upgrade")
	var ev := code_only(FileAccess.get_file_as_string("res://src/core/events.gd"))
	check(ev.contains("signal cmd_buy_upgrade(") and ev.contains("signal upgrade_result("), "Events has the upgrade signals")
	var up: String = SRC["panel"]
	if check(FileAccess.file_exists(up), "04 upgrade_panel.gd exists"):
		scan("upgrade_panel.gd", code_only(FileAccess.get_file_as_string(up)), FORBIDDEN_UI)
	# Nothing in services calls the upgrade path either (no hidden coupling the other way).
	for f in ["services.gd", "save_bridge.gd", "services_factory.gd", "ads/reward_policy.gd", "billing/purchase_service.gd"]:
		var t := code_only(FileAccess.get_file_as_string("res://src/services/" + f))
		check(not t.contains("buy_upgrade") and not t.contains("upgrade_result") and not t.contains("\"upgrades\""), "src/services/%s does not touch upgrades" % f)
	return true

func test_data() -> bool:
	var j := JSON.new()
	if not check(j.parse(FileAccess.get_file_as_string(SRC["meta"])) == OK, "meta.json parses"):
		return true
	var meta: Dictionary = j.data
	var ups: Array = meta.get("upgrades", [])
	check(ups.size() > 0, "meta.json has upgrades (%d)" % ups.size())
	for u in ups:
		var id := str(u.get("id", "?"))
		for k in u.keys():
			check(UPGRADE_KEYS.has(k), "upgrade %s field '%s' is a coin-upgrade field (no price/product/ad fields)" % [id, k])
		var costs: Array = u.get("costs", [])
		check(costs.size() == int(u.get("max_level", 1)) - 1, "upgrade %s has one coin cost per level" % id)
		check(costs.all(func(c): return (c is float or c is int) and c > 0 and c == floor(c)), "upgrade %s costs are positive whole coins" % id)
	var iap: Dictionary = meta.get("iap_catalog", {})
	check(iap.get("enabled", true) == false and (iap.get("products", [1]) as Array).is_empty(), "iap_catalog disabled and empty (Q2 deferred)")
	for c in meta.get("currencies", []):
		if str(c.get("id", "")) == "gems":
			check(c.get("enabled", true) == false, "premium currency gems disabled")
	var ug := code_only(FileAccess.get_file_as_string(SRC["save-gd"]))
	check(ug.contains("progress.coins = coins - cost"), "buy_upgrade spends progress.coins (gold), nothing else")
	return true

func test_direct() -> bool:
	var dir := use_dir("direct", 500)
	var s0 := services_state()
	if not check(not s0.is_empty(), "game /root/Services present"):
		return true
	eq(s0.mode, "disabled", "Services mode disabled")
	check(not s0.diag.live.values().has(true), "nothing live before")
	var cost: int = save.upgrade_cost("up_melee_basic", 2)
	check(cost > 0, "upgrade cost known (%d)" % cost)
	var codes := [save.UPG_OK, save.UPG_ALREADY, save.UPG_MAX, save.UPG_COINS, save.UPG_UNKNOWN, save.UPG_LOCKED,
		save.UPG_INVALID, save.UPG_SAVE_FAILED, save.UPG_SAVE_UNCERTAIN, save.UPG_READ_ONLY]
	var c1: String = save.buy_upgrade("up_melee_basic", 2)
	eq(c1, save.UPG_OK, "buy ok")
	eq(int(save.progress.coins), 500 - cost, "coins spent")
	var c2: String = save.buy_upgrade("up_melee_basic", 2)
	eq(c2, save.UPG_ALREADY, "repeat refused")
	save.progress["coins"] = 0
	var c3: String = save.buy_upgrade("up_melee_basic", 3)
	eq(c3, save.UPG_COINS, "no coins: not_enough_coins (no ad or shop fallback)")
	save.progress["coins"] = 500 - cost
	# Failed write: a directory where the .tmp file goes (same trick as the M3/M4 gate).
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")
	var c4: String = save.buy_upgrade("up_melee_basic", 3)
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	check(c4 == save.UPG_SAVE_FAILED or c4 == save.UPG_SAVE_UNCERTAIN, "write failure reported (%s)" % c4)
	eq(int(save.progress.coins), 500 - cost, "coins rolled back after failed write")
	for c in [c1, c2, c3, c4]:
		check(codes.has(c), "code '%s' is a Save.UPG_* code" % c)
	if selfcheck_touch:
		(save.progress["services"] as Dictionary)["selfcheck"] = {"touched": true}
	var s1 := services_state()
	eq(s1.diag, s0.diag, "Services diagnostics unchanged by upgrade purchases")
	eq(s1.data, s0.data, "progress.services unchanged by upgrade purchases")
	check(not s1.diag.live.values().has(true), "nothing live after")
	# On disk: the services section did not change either.
	save.load_progress()
	eq(JSON.stringify(save.progress.get("services", {}), "", true), JSON.stringify(JSON.parse_string(JSON.stringify(s0.data)), "", true), "services section on disk unchanged (compared after the same JSON round trip)")
	return true

func test_app_path() -> bool:
	var ev := root.get_node_or_null("Events")
	var app := root.get_node_or_null("App")
	if not check(ev != null and app != null and ev.has_signal("cmd_buy_upgrade"), "Events/App autoloads with cmd_buy_upgrade"):
		return true
	use_dir("app", 300)
	var s0 := services_state()
	var results: Array = []
	var toasts: Array = []
	var cb := func(r): results.append(r)
	var tb := func(k, _p): toasts.append(k)
	ev.upgrade_result.connect(cb)
	ev.toast.connect(tb)
	var cost: int = save.upgrade_cost("up_base_hp", 2)
	ev.cmd_buy_upgrade.emit("up_base_hp", 2)
	ev.cmd_buy_upgrade.emit("up_base_hp", 2)   # double tap
	ev.upgrade_result.disconnect(cb)
	ev.toast.disconnect(tb)
	eq(results.size(), 2, "App answered both commands")
	if results.size() == 2:
		var keys: Array = results[0].keys()
		keys.sort()
		eq(keys, RESULT_KEYS, "upgrade_result carries only id/to_level/code/coins/level (no receipt, token or price fields)")
		eq(results[0].code, save.UPG_OK, "first command ok")
		eq(results[1].code, save.UPG_ALREADY, "double tap already_applied")
		eq(int(results[0].coins), 300 - cost, "result coins after spend")
	check(not toasts.has("save_failed"), "no save_failed toast on success (%s)" % str(toasts))
	var s1 := services_state()
	eq(s1.diag, s0.diag, "Services diagnostics unchanged via App path")
	eq(s1.data, s0.data, "progress.services unchanged via App path")
	return true

# ------------------------------------------------------------------ Q2 deferred: repo-wide scan

## Game code outside src/services must not reach ads, billing, receipts or store SDKs while Q2 is
## deferred (user, 2026-10-31 16:09 KST). Comments are stripped. The battle "kill reward" is not an ad,
## so plain "rewarded" is not a token here. Also: no addons/ (plugins), no android/ Gradle template
## with plugin AARs, no enabled plugin flags in export_presets.cfg.
const Q2_TOKENS := ["Services.ads", "Services.purchases", "/root/Services", "get_singleton(", "JavaClassWrapper",
	"GodotGooglePlayBilling", "AndroidIAPP", "AdMob", "MobileAds", "purchaseToken", "receipt", "HTTPRequest", "HTTPClient"]
const Q2_SCAN_DIRS := ["res://src", "res://scenes"]

func _scan_files(dir: String, exts: Array, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if exts.has(f.get_extension()):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_scan_files(dir.path_join(sub), exts, out)

func test_q2_repo_scan() -> bool:
	var files: Array = []
	var dirs: Array = Q2_SCAN_DIRS.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--q2-extra-dir="):   # mutation tests: an outside folder with planted files
			dirs.append(a.substr("--q2-extra-dir=".length()))
	for d in dirs:
		_scan_files(d, ["gd", "tscn"], files)
	files = files.filter(func(p): return not str(p).begins_with("res://src/services/"))
	check(files.size() >= 30, "game files scanned outside src/services (%d)" % files.size())
	for p in files:
		var t := code_only(FileAccess.get_file_as_string(p))
		for tok in Q2_TOKENS:
			check(not t.contains(tok), "%s: no '%s' (Q2 deferred)" % [p, tok])
	check(not DirAccess.dir_exists_absolute("res://addons"), "no addons/ (no ad or billing plugin)")
	check(not DirAccess.dir_exists_absolute("res://android/plugins"), "no android/plugins (v1 Android plugins)")
	var cfg := ConfigFile.new()
	if check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg loads"):
		for sec in cfg.get_sections():
			if not sec.ends_with(".options"):
				continue
			for k in cfg.get_section_keys(sec):
				if str(k).begins_with("plugins/"):
					check(cfg.get_value(sec, k) != true, "%s %s plugin not enabled (Q2 deferred)" % [sec, k])
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta.json"))
	check(meta is Dictionary and (meta.get("iap_catalog", {}) as Dictionary).get("enabled", true) == false, "iap_catalog still disabled")
	return true
