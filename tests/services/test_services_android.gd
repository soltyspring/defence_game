extends SceneTree
## Android export, permissions and backup-policy checks. Owner: 06-services.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_android.gd
## Exit 0 = pass, 1 = failure. A missing release preset or APK is reported (WAITING / NOT_RUN), not failed.
## What it proves: export presets and the APKs found locally carry none of the ad ID, billing,
## internet or network-state permissions (Q2 deferred: everything disabled), and
## docs/services/SAVE_BACKUP_POLICY.md states the backup values the repo and the APK really have.
## What it does not prove: behaviour on a device (no device test has been run), or anything about
## an APK/AAB that is not on this machine.

const POLICY_DOC := "res://docs/services/SAVE_BACKUP_POLICY.md"
const PRESETS_DEFAULT := "res://export_presets.cfg"
var PRESETS := PRESETS_DEFAULT   # `-- --presets=<path>` reads a copy instead (mutation tests; never edit 02's file)
const SAVE_GD := "res://src/core/save.gd"
const SAFETY := "res://docs/services/DATA_SAFETY_DRAFT.md"
const PRIVACY := "res://docs/services/PRIVACY_POLICY_DRAFT.md"
const SITE := "res://docs/services/privacy_site/index.html"
const DOC_APK := "res://build/qa/apk_head/defence-debug.apk"
const APK_DIRS := ["res://build/qa/apk_head", "res://build/android", "res://build/release"]
## Must stay absent while ads, billing and analytics are disabled. The Mobile Ads SDK and the Play
## Billing library add the first two by manifest merge, so the APK check matters more than the preset.
const BLOCKED_PERMS := ["com.google.android.gms.permission.AD_ID", "com.android.vending.BILLING",
	"android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE"]
const SCENARIOS := ["S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8"]
const OPTIONS := ["B0", "B1", "B2", "B3"]

var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}}
var release_preset := "WAITING"
var apks_checked := 0
var aapt2 := ""
var launcher_status := "WAITING"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--presets="):
			PRESETS = a.substr("--presets=".length())
	aapt2 = find_aapt2()
	_group("android_permissions", test_permissions)
	_group("backup_policy_values", test_backup_values)
	_group("backup_policy_doc", test_backup_doc)
	_group("backup_privacy_consistency", test_consistency)
	_group("godot_uid_tracked", test_uid_tracked)
	_group("launcher_label", test_launcher_label)
	report.passes = passes
	report.failures = Array(failures)
	report.release_preset = release_preset
	report.apks_checked = apks_checked
	report.aapt2 = aapt2 if aapt2 != "" else "not found"
	print("[test_services_android] passes=%d failures=%d release_preset=%s apks_checked=%d aapt2=%s launcher_label=%s" % [passes, failures.size(), release_preset, apks_checked, "yes" if aapt2 != "" else "no", launcher_status])
	for g in report.groups:
		print("  %-28s %s" % [g, report.groups[g]])
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

# ------------------------------------------------------------------ helpers

static func find_aapt2() -> String:
	var roots: Array = []
	for v in ["ANDROID_HOME", "ANDROID_SDK_ROOT"]:
		if OS.get_environment(v) != "":
			roots.append(OS.get_environment(v))
	if OS.get_environment("LOCALAPPDATA") != "":
		roots.append(OS.get_environment("LOCALAPPDATA").path_join("Android/Sdk"))
	for r in roots:
		var bt: String = r.path_join("build-tools")
		var d := DirAccess.open(bt)
		if d == null:
			continue
		var vers := Array(d.get_directories())
		vers.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) > 0)
		for v in vers:
			for exe in ["aapt2.exe", "aapt2"]:
				var p: String = bt.path_join(v).path_join(exe)
				if FileAccess.file_exists(p):
					return p
	return ""

static func hex_contains(hay_hex: String, needle: PackedByteArray) -> bool:
	var n := needle.hex_encode()
	var i := hay_hex.find(n)
	while i >= 0:
		if i % 2 == 0:
			return true
		i = hay_hex.find(n, i + 1)
	return false

## True if the string appears in the binary manifest as UTF-8 or UTF-16LE (AXML string pool or
## AAB protobuf). Absence in the pool means no element or attribute uses it.
static func manifest_has(manifest: PackedByteArray, s: String) -> bool:
	var hx := manifest.hex_encode()
	return hex_contains(hx, s.to_utf8_buffer()) or hex_contains(hx, s.to_utf16_buffer())

func presets() -> Array:
	var out: Array = []
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS) != OK:
		return out
	for sec in cfg.get_sections():
		if RegEx.create_from_string("^preset\\.\\d+$").search(sec) == null:
			continue
		var opts := {}
		if cfg.has_section(sec + ".options"):
			for k in cfg.get_section_keys(sec + ".options"):
				opts[k] = cfg.get_value(sec + ".options", k)
		out.append({"id": sec, "name": str(cfg.get_value(sec, "name", "")), "platform": str(cfg.get_value(sec, "platform", "")),
			"export_path": str(cfg.get_value(sec, "export_path", "")), "options": opts})
	return out

static func is_release(p: Dictionary) -> bool:
	var s: String = (p.name + " " + p.export_path).to_lower()
	return s.contains("release") or s.ends_with(".aab") or int(p.options.get("gradle_build/export_format", 0)) == 1

func apk_files() -> Array:
	var out: Array = []
	for dir in APK_DIRS:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".apk") or f.ends_with(".aab"):
				out.append(dir.path_join(f))
	return out

func aapt2_dump(args: Array) -> String:
	if aapt2 == "":
		return ""
	var out: Array = []
	var code := OS.execute(aapt2, PackedStringArray(args), out, true)
	return "\n".join(PackedStringArray(out)) if code == 0 else ""

func doc() -> String:
	return FileAccess.get_file_as_string(POLICY_DOC) if FileAccess.file_exists(POLICY_DOC) else ""

static func section(t: String, start: String, end: String) -> String:
	var a := t.find(start)
	if a < 0:
		return ""
	var b := t.find(end, a + start.length())
	return t.substr(a, (b - a) if b > a else -1)

## §1 table: setting -> current value (third column).
func doc_values() -> Dictionary:
	var vals := {}
	for line in section(doc(), "## 1.", "### 1a.").split("\n"):
		var c := line.split("|")
		if c.size() >= 6 and not line.begins_with("| Setting") and not line.begins_with("|---"):
			vals[c[1].strip_edges()] = c[3].strip_edges()
	return vals

# ------------------------------------------------------------------ groups

func test_permissions() -> bool:
	var ps := presets()
	if not check(ps.size() > 0, "export_presets.cfg has presets"):
		return true
	var any_release := false
	for p in ps:
		if p.platform != "Android":
			continue
		var o: Dictionary = p.options
		for k in o:
			if str(k).begins_with("permissions/") and o[k] is bool:
				check(o[k] == false, "%s (%s): %s is off while services are disabled" % [p.id, p.name, k])
		var custom: Array = Array(o.get("permissions/custom_permissions", PackedStringArray()))
		for perm in BLOCKED_PERMS:
			check(not custom.has(perm), "%s (%s): custom permission %s absent" % [p.id, p.name, perm])
		check(custom.is_empty(), "%s (%s): no custom permissions (%s)" % [p.id, p.name, str(custom)])
		if is_release(p):
			any_release = true
	release_preset = "PRESENT" if any_release else "WAITING"
	print("  release preset: %s (04 R12-2 -> 02)" % release_preset)
	# Built packages found on this machine (untracked build outputs; none = NOT_RUN, not a failure).
	for path in apk_files():
		var zr := ZIPReader.new()
		if not check(zr.open(path) == OK, "%s opens as zip" % path):
			continue
		var entry := "AndroidManifest.xml" if path.ends_with(".apk") else "base/manifest/AndroidManifest.xml"
		var man := zr.read_file(entry)
		zr.close()
		if not check(man.size() > 0, "%s has %s" % [path, entry]):
			continue
		apks_checked += 1
		if path.contains("release"):
			release_preset = "PRESENT"
		# Positive control: the decoder sees strings that must be there.
		check(manifest_has(man, "com.soltyspring.lanedefence"), "%s: package name found in manifest strings (decoder works)" % path)
		for perm in BLOCKED_PERMS:
			check(not manifest_has(man, perm), "%s: %s absent from manifest" % [path, perm])
		if aapt2 != "" and path.ends_with(".apk"):
			var dp := aapt2_dump(["dump", "permissions", ProjectSettings.globalize_path(path)])
			if check(dp.contains("package: com.soltyspring.lanedefence"), "%s: aapt2 dump permissions ran" % path):
				for perm in BLOCKED_PERMS:
					check(not dp.contains(perm), "%s: aapt2 lists no %s" % [path, perm])
	print("  packages checked: %d %s" % [apks_checked, "" if apks_checked > 0 else "(NOT_RUN: no APK/AAB on this machine)"])
	return true

func test_backup_values() -> bool:
	var vals := doc_values()
	if not check(vals.size() >= 8, "§1 table has the current values (%d rows)" % vals.size()):
		return true
	var android: Array = presets().filter(func(p): return p.platform == "Android")
	if not check(android.size() > 0, "an Android preset exists"):
		return true
	var o: Dictionary = android[0].options
	check(vals.get("hasFragileUserData", "") == str(o.get("package/retain_data_on_uninstall", false)).to_lower(), "doc hasFragileUserData = preset retain_data_on_uninstall (%s)" % str(o.get("package/retain_data_on_uninstall")))
	check(vals.get("use_gradle_build", "") == str(o.get("gradle_build/use_gradle_build", false)).to_lower(), "doc use_gradle_build = preset (%s)" % str(o.get("gradle_build/use_gradle_build")))
	check(vals.get("package", "") == str(o.get("package/unique_name", "")), "doc package = preset (%s)" % str(o.get("package/unique_name")))
	check(str(vals.get("release preset", "")).begins_with("none") == (release_preset == "WAITING"), "doc release preset row matches (%s)" % release_preset)
	var m := RegEx.create_from_string("var path := \"([^\"]+)\"").search(FileAccess.get_file_as_string(SAVE_GD))
	var save_path := m.get_string(1) if m else ""
	check(save_path != "" and vals.get("save path", "") == save_path, "doc save path = save.gd (%s)" % save_path)
	# Prebuilt template => manifest attributes come from Godot; with Gradle the doc must be redone.
	if o.get("gradle_build/use_gradle_build", false) == false:
		check(vals.get("allowBackup", "") == "false" and vals.get("dataExtractionRules", "") == "absent" and vals.get("fullBackupContent", "") == "absent", "doc states the Godot template backup values while the prebuilt template is used")
	# APK manifest (when aapt2 and the documented APK exist on this machine).
	if aapt2 != "" and FileAccess.file_exists(DOC_APK):
		var x := aapt2_dump(["dump", "xmltree", "--file", "AndroidManifest.xml", ProjectSettings.globalize_path(DOC_APK)])
		if check(x.contains("E: application"), "aapt2 xmltree ran on %s" % DOC_APK):
			var ab := RegEx.create_from_string(":allowBackup\\(0x[0-9a-f]+\\)=(\\S+)").search(x)
			check(ab != null and ab.get_string(1) == vals.get("allowBackup", ""), "APK allowBackup = doc (%s)" % (ab.get_string(1) if ab else "absent"))
			check(x.contains(":dataExtractionRules(") == (vals.get("dataExtractionRules", "") != "absent"), "APK dataExtractionRules presence = doc")
			check(x.contains(":fullBackupContent(") == (vals.get("fullBackupContent", "") != "absent"), "APK fullBackupContent presence = doc")
			var hf := RegEx.create_from_string(":hasFragileUserData\\(0x[0-9a-f]+\\)=(\\S+)").search(x)
			check(hf != null and hf.get_string(1) == vals.get("hasFragileUserData", ""), "APK hasFragileUserData = doc")
			var ts := RegEx.create_from_string(":targetSdkVersion\\(0x[0-9a-f]+\\)=(\\d+)").search(x)
			check(ts != null and ts.get_string(1) == vals.get("targetSdk", ""), "APK targetSdk = doc (%s)" % (ts.get_string(1) if ts else "?"))
		var sha := FileAccess.get_sha256(DOC_APK).to_upper()
		if not doc().contains(sha):
			print("  NOTE: %s changed since the doc was written (SHA-256 %s); values above were re-read from the new file" % [DOC_APK, sha.left(12)])
	else:
		print("  APK manifest values NOT_RUN (aapt2 %s, APK %s)" % ["found" if aapt2 != "" else "missing", "found" if FileAccess.file_exists(DOC_APK) else "missing"])
	return true

func test_backup_doc() -> bool:
	var t := doc()
	if not check(t != "", "SAVE_BACKUP_POLICY.md exists"):
		return true
	check(t.contains("**This is a desk study of the repository, the built APK and official docs. No real-device test has been run.**"), "doc says no device test was run")
	check(t.contains("not a decision"), "options marked not a decision")
	var s3 := section(t, "## 3.", "## 4.")
	for id in SCENARIOS:
		var ok := false
		for line in s3.split("\n"):
			if line.begins_with("| %s |" % id):
				var c := line.split("|")
				ok = c.size() >= 8 and c[3].strip_edges() != "" and c[5].strip_edges() != ""
				var verified := c[6].strip_edges() if c.size() >= 8 else ""
				check(verified == "NOT TESTED" or RegEx.create_from_string("^TESTED 20\\d\\d-\\d\\d-\\d\\d .{10,}").search(verified) != null, "scenario %s device status is NOT TESTED or dated evidence ('%s')" % [id, verified])
		check(ok, "scenario %s has outcome and source" % id)
	var s4 := section(t, "## 4.", "## 5.")
	for id in OPTIONS:
		check(s4.contains("| %s " % id), "option %s present" % id)
	check(s4.contains("06 recommendation (not a decision)"), "recommendation labelled as such")
	for url in ["https://developer.android.com/identity/data/autobackup", "https://developer.android.com/about/versions/12/behavior-changes-12", "https://support.google.com/googleplay/android-developer/answer/10787469"]:
		check(t.contains(url), "doc cites %s" % url)
	# §6 rule files include exactly the save and its backup, nothing transient.
	var s6 := section(t, "## 6.", "## 7.")
	var m := RegEx.create_from_string("var path := \"user://([^\"]+)\"").search(FileAccess.get_file_as_string(SAVE_GD))
	var base := m.get_string(1) if m else "?"
	var inc: Array = []
	for r in RegEx.create_from_string("<include domain=\"file\" path=\"([^\"]+)\"/>").search_all(s6):
		inc.append(r.get_string(1))
	check(inc.size() == 6, "rule files list 6 includes (2 cloud, 2 device, 2 legacy) (%d)" % inc.size())
	for p in inc:
		check(p == base or p == base + ".bak", "rule include '%s' is the save or its .bak" % p)
	check(not s6.contains("<exclude"), "B1 rules rely on include-only (no stray excludes)")
	check(s6.contains("<cloud-backup>") and s6.contains("<device-transfer>") and s6.contains("<full-backup-content>"), "rules cover cloud, D2D and Android 11-")
	check(t.contains("**Release preset: WAITING.**") == (release_preset == "WAITING"), "doc §8 release-preset status matches the repo (%s)" % release_preset)
	return true

func test_consistency() -> bool:
	var vals := doc_values()
	var backup_on: bool = vals.get("allowBackup", "false") == "true" or vals.get("dataExtractionRules", "absent") != "absent"
	var sd := FileAccess.get_file_as_string(SAFETY)
	check(sd.contains("## 2b. Re-check against the Android backup policy"), "Data safety draft has the backup re-check (§2b)")
	check(sd.contains("| Does the app collect or share any of the required user data types? | **No** |"), "Data safety answer is still No")
	check(sd.contains("on-device data is removed by uninstalling or clearing app data") != backup_on, "Data safety deletion row matches backup state (backup %s)" % ("on" if backup_on else "off"))
	var pp := FileAccess.get_file_as_string(PRIVACY)
	check(pp.contains("[백업 활성화 시]") and pp.contains("[IF BACKUP ENABLED]"), "privacy draft has the backup conditional in ko and en")
	check(pp.count("[백업 활성화 시]") == pp.count("[IF BACKUP ENABLED]"), "ko/en backup conditional counts match")
	var site := FileAccess.get_file_as_string(SITE)
	var visible := RegEx.create_from_string("(?s)<!--.*?-->").sub(site, "", true)
	if not backup_on:
		check(not visible.contains("Google 계정 백업") and not visible.contains("Google account backup"), "published page has no backup sentence while backup is off")
	else:
		check(visible.contains("Google 계정 백업") and visible.contains("Google account backup"), "published page states the backup copy while backup is on")
	check(doc().contains("**no contradiction with the current build (B0).**") != backup_on, "doc §5 verdict is for the current backup state")
	return true

## Godot 4.4+ writes a `.uid` beside every script; the engine docs say to commit them (UID
## references break on other clones otherwise; see docs/services/GODOT_UID_AUDIT.md). Every 06
## script must have its .uid tracked by git. Repo-wide untracked .uid files are reported only
## (other owners commit their own).
const UID_DIRS := ["res://src/services", "res://tests/services"]

func _gd_files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_gd_files(dir.path_join(sub), out)

func test_uid_tracked() -> bool:
	var out: Array = []
	var code := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "ls-files", "--", "src/services", "tests/services"]), out, true)
	if code != 0 or out.is_empty():
		print("  godot_uid_tracked NOT_RUN (git unavailable, exit %d)" % code)
		return true
	var tracked := {}
	for line in "\n".join(PackedStringArray(out)).split("\n"):
		if line.strip_edges() != "":
			tracked["res://" + line.strip_edges()] = true
	var scripts: Array = []
	for d in UID_DIRS:
		_gd_files(d, scripts)
	check(scripts.size() >= 40, "06 scripts found (%d)" % scripts.size())
	for s in scripts:
		if not tracked.has(s):
			continue   # an untracked script (work in progress) has no committed uid yet
		check(FileAccess.file_exists(s + ".uid"), "%s has a .uid file" % s)
		check(tracked.has(s + ".uid"), "%s.uid is tracked by git" % s)
	var st: Array = []
	OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain", "--untracked-files=all"]), st, true)
	var others := 0
	for line in "\n".join(PackedStringArray(st)).split("\n"):
		if line.begins_with("?? ") and line.ends_with(".uid") and not line.contains("services/"):
			others += 1
	print("  untracked .uid outside 06 paths: %d (reported to owners, not committed by 06)" % others)
	return true

# ------------------------------------------------------------------ Q4 launcher label in the real APK

## User decision Q4, 2026-10-31 17:19 KST (option A): home-screen name ko "빵집 기사단", en "Bakery Knights".
const LAUNCHER_EXPECTED := {"ko": "빵집 기사단", "en": "Bakery Knights"}
const LAUNCHER_OLD := "Lane Defence"

## Labels from `aapt2 dump badging`: {"default": .., "<locale>": ..}.
static func badging_labels(badging: String) -> Dictionary:
	var out := {}
	for m in RegEx.create_from_string("(?m)^application-label(?:-([A-Za-z0-9-]+))?:'([^']*)'").search_all(badging):
		out[m.get_string(1) if m.get_string(1) != "" else "default"] = m.get_string(2)
	return out

## OK = ko and en labels match Q4; OLD = every label is still the pre-Q4 name (APK built before 02's
## change: waiting, not a failure); MISMATCH = anything else; NONE = no label found.
static func label_verdict(badging: String) -> String:
	var l := badging_labels(badging)
	if l.is_empty():
		return "NONE"
	var all_old := true
	for k in l:
		if l[k] != LAUNCHER_OLD:
			all_old = false
	if all_old:
		return "OLD"
	var ko: String = l.get("ko", l.get("default", ""))
	var en: String = l.get("en", l.get("default", ""))
	return "OK" if ko == LAUNCHER_EXPECTED.ko and en == LAUNCHER_EXPECTED.en else "MISMATCH"

## `aapt2 dump badging` through a temp file: OS.execute's captured stdout does not keep UTF-8 on
## Windows (probe 2026-10-31: Korean text lost), but a redirected file keeps the raw bytes.
func badging_utf8(apk: String) -> String:
	if aapt2 == "":
		return ""
	var tmp := OS.get_cache_dir().path_join("svc_badging_%d.txt" % OS.get_process_id())
	var out: Array = []
	var code := -1
	if OS.get_name() == "Windows":
		# Redirect inside a tiny batch file; passing a quoted redirect through `cmd /c` breaks quoting.
		var bat := OS.get_cache_dir().path_join("svc_badging_%d.cmd" % OS.get_process_id())
		var bf := FileAccess.open(bat, FileAccess.WRITE)
		bf.store_string("@\"%~1\" dump badging \"%~2\" > \"%~3\" 2>nul\r\n")
		bf.close()
		code = OS.execute(bat, PackedStringArray([aapt2.replace("/", "\\"), apk.replace("/", "\\"), tmp.replace("/", "\\")]), out, true)
		DirAccess.remove_absolute(bat)
	else:
		code = OS.execute("sh", PackedStringArray(["-c", "'%s' dump badging '%s' > '%s' 2>/dev/null" % [aapt2, apk, tmp]]), out, true)
	var s := FileAccess.get_file_as_string(tmp) if FileAccess.file_exists(tmp) else ""
	DirAccess.remove_absolute(tmp)
	return s if code == 0 else ""

func test_launcher_label() -> bool:
	# The verdict logic, proven on synthetic aapt2 output (works without a rebuilt APK).
	var b_old := "application-label:'Lane Defence'\napplication-label-ko:'Lane Defence'\napplication-label-en:'Lane Defence'\n"
	var b_ok := "application-label:'Bakery Knights'\napplication-label-ko:'빵집 기사단'\napplication-label-en:'Bakery Knights'\n"
	var b_ok_default_en := "application-label:'Bakery Knights'\napplication-label-ko:'빵집 기사단'\n"
	var b_no_ko := "application-label:'Bakery Knights'\napplication-label-en:'Bakery Knights'\n"
	var b_full := "application-label:'Bakery Knights: Mold Defense'\napplication-label-ko:'빵집 기사단: 곰팡이 디펜스'\n"
	var b_typo := "application-label:'Bakery Knight'\napplication-label-ko:'빵집 기사단'\n"
	var b_mixed := "application-label:'Lane Defence'\napplication-label-ko:'빵집 기사단'\n"
	var cases := [[b_old, "OLD"], [b_ok, "OK"], [b_ok_default_en, "OK"], [b_no_ko, "MISMATCH"], [b_full, "MISMATCH"], [b_typo, "MISMATCH"], [b_mixed, "MISMATCH"], ["", "NONE"]]
	for c in cases:
		check(label_verdict(c[0]) == c[1], "label verdict self-test: %s -> %s (got %s)" % [c[0].replace("\n", " | ").left(60), c[1], label_verdict(c[0])])
	# Export settings (02): still the old name = WAITING; anything else must be the Q4 name.
	var android: Array = presets().filter(func(p): return p.platform == "Android")
	var pkg_name := str(android[0].options.get("package/name", "")) if android.size() > 0 else ""
	var preset_state := "WAITING"
	if pkg_name != LAUNCHER_OLD:
		preset_state = "CHANGED"
		check(LAUNCHER_EXPECTED.values().has(pkg_name), "export package/name '%s' is a Q4 launcher name" % pkg_name)
	var loc = ProjectSettings.get_setting("application/config/name_localized", {})
	if loc is Dictionary and not loc.is_empty():
		for lang in ["ko", "en"]:
			check(str(loc.get(lang, "")) == LAUNCHER_EXPECTED[lang], "config/name_localized[%s] = '%s'" % [lang, LAUNCHER_EXPECTED[lang]])
	# Built packages on this machine.
	var verdicts := {}
	if aapt2 == "":
		print("  launcher_label: APK NOT_RUN (aapt2 missing); preset %s" % preset_state)
	else:
		for path in apk_files():
			if not path.ends_with(".apk"):
				continue
			var v := label_verdict(badging_utf8(ProjectSettings.globalize_path(path)))
			verdicts[path] = v
			check(v == "OK" or v == "OLD", "%s launcher label is the Q4 name or the pre-Q4 build (%s)" % [path, v])
	launcher_status = "VERIFIED" if verdicts.values().has("OK") else "WAITING"
	if verdicts.values().has("MISMATCH") or verdicts.values().has("NONE"):
		launcher_status = "FAIL"
	print("  launcher_label: %s (preset %s, apks %s)" % [launcher_status, preset_state, str(verdicts)])
	return true
