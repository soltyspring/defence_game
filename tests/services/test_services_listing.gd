extends SceneTree
## Lint for docs/services/STORE_LISTING_DRAFT.md and PRIVACY_POLICY_DRAFT.md. Owner: 06-services.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_listing.gd
## Exit 0 = pass, 1 = failure. Rules from Play's Metadata policy and Store listing limits
## (sources and check date in STORE_LISTING_DRAFT.md §1). This checks mechanical rules only;
## it does not prove the copy is good, accurate in every word, or legally sufficient.

const LISTING := "res://docs/services/STORE_LISTING_DRAFT.md"
const POLICY := "res://docs/services/PRIVACY_POLICY_DRAFT.md"
const LIMITS := {"title": 30, "short": 80, "full": 4000}

## Ranking, price/promotion and Play-program wording (Metadata policy examples) + superlatives.
const BANNED_EN := ["#1", "best", "top", "popular", "award", "free", "% off", "discount", "sale",
	"editor's choice", "editors' choice", "new", "no. 1", "number one", "ultimate", "google play", "trending"]
const BANNED_KO := ["1위", "최고", "인기", "무료", "할인", "에디터", "추천", "신규", "수상", "베스트", "역대급", "구글 플레이"]
## Third-party marks (09 R09-06-3): Devsisters' Cookie Run family and real bakery brands must not
## appear in titles, IAP names or store text.
const BANNED_BRANDS := ["쿠키", "쿠키런", "cookie", "cookierun", "devsisters", "데브시스터즈", "파리바게뜨", "paris baguette", "뚜레쥬르", "tous les jours", "성심당"]
const STOP_EN := ["the", "and", "a", "an", "to", "of", "for", "your", "you", "or", "with", "from", "each", "any", "such", "as", "by", "in", "on", "no", "every", "then", "into", "after", "use", "up", "per"]

var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}, "lengths": {}}

func _initialize() -> void:
	_group("listing_fields", test_listing_fields)
	_group("listing_wording", test_listing_wording)
	_group("listing_claim_markers", test_listing_markers)
	_group("privacy_policy_template", test_policy)
	_group("name_search_log", test_name_search_log)
	_group("content_rating_draft", test_content_rating)
	_group("data_safety_draft", test_data_safety)
	_group("billing_docs", test_billing_docs)
	report.passes = passes
	report.failures = Array(failures)
	var f := FileAccess.open("user://services_listing_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[test_services_listing] passes=%d failures=%d" % [passes, failures.size()])
	for g in report.groups:
		print("  %-26s %s" % [g, report.groups[g]])
	for k in report.lengths:
		print("  len %-10s %s" % [k, str(report.lengths[k])])
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

static func block(text: String, key: String) -> String:
	var a := text.find("<!-- BEGIN %s -->" % key)
	var b := text.find("<!-- END %s -->" % key)
	if a < 0 or b < 0 or b < a:
		return ""
	a += ("<!-- BEGIN %s -->" % key).length()
	return text.substr(a, b - a).strip_edges()

## Store text with draft markers removed (markers are stripped before submission).
static func store_text(s: String) -> String:
	for m in ["[수익화 결정 시 변경]", "[CHANGES IF MONETIZED]", "[이름 확정 대기]", "[NAMES PENDING]"]:
		s = s.replace(" " + m, "").replace(m, "")
	return s

func listing() -> String:
	return FileAccess.get_file_as_string(LISTING) if FileAccess.file_exists(LISTING) else ""

func titles(lang: String) -> Array:
	var out: Array = []
	for line in block(listing(), "title." + lang).split("\n"):
		var l := line.strip_edges()
		if l.begins_with("- "):
			out.append(l.substr(2).strip_edges())
	return out

func test_listing_fields() -> bool:
	if not check(listing() != "", "STORE_LISTING_DRAFT.md exists"):
		return true
	for lang in ["ko", "en"]:
		var ts := titles(lang)
		check(ts.size() >= 2, "%s: at least 2 title candidates (%d)" % [lang, ts.size()])
		for t in ts:
			report.lengths["title." + lang + ":" + t] = t.length()
			check(t.length() <= LIMITS.title, "%s title '%s' ≤ 30 chars (%d)" % [lang, t, t.length()])
		for field in ["short", "full"]:
			var s := store_text(block(listing(), field + "." + lang))
			report.lengths[field + "." + lang] = s.length()
			check(s.length() > 0, "%s.%s present" % [field, lang])
			check(s.length() <= LIMITS[field], "%s.%s ≤ %d chars (%d)" % [field, lang, LIMITS[field], s.length()])
		var sh := store_text(block(listing(), "short." + lang))
		check(not sh.contains("\n"), "%s short description is one line" % lang)
	return true

static func has_emoji(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if (c >= 0x1F000 and c <= 0x1FAFF) or (c >= 0x2600 and c <= 0x27BF) or (c >= 0x2B00 and c <= 0x2BFF) or c == 0xFE0F:
			return true
	return false

func all_store_fields(lang: String) -> Array:
	var out: Array = titles(lang)
	out.append(store_text(block(listing(), "short." + lang)))
	out.append(store_text(block(listing(), "full." + lang)))
	return out

func test_listing_wording() -> bool:
	var re_word := RegEx.create_from_string("[A-Za-z][A-Za-z']*")
	for lang in ["ko", "en"]:
		for s in all_store_fields(lang):
			var low: String = s.to_lower()
			check(not has_emoji(s), "%s: no emoji in '%s'" % [lang, s.left(40)])
			check(not RegEx.create_from_string("([!?.*~★☆♥])\\1").search(s), "%s: no repeated special characters in '%s'" % [lang, s.left(40)])
			for w in BANNED_EN:
				var hit := false
				if w.length() <= 4 and not w.contains(" ") and not w.contains("#") and not w.contains("%"):
					hit = RegEx.create_from_string("\\b" + w + "\\b").search(low) != null
				else:
					hit = low.contains(w)
				check(not hit, "%s: no ranking/promo/program wording '%s' in '%s'" % [lang, w, s.left(40)])
			for w in BANNED_BRANDS:
				check(not low.contains(w), "%s: no third-party brand '%s' in '%s'" % [lang, w, s.left(40)])
			for w in BANNED_KO:
				check(not s.contains(w), "%s: no ranking/promo wording '%s'" % [lang, w])
			for m in re_word.search_all(s):
				var word := m.get_string()
				check(not (word.length() >= 4 and word == word.to_upper()), "%s: no ALL CAPS word '%s'" % [lang, word])
		# keyword repetition and word lists in the full description
		var full := store_text(block(listing(), "full." + lang))
		var counts := {}
		if lang == "en":
			for m in re_word.search_all(full.to_lower()):
				var w := m.get_string()
				if w.length() >= 3 and not STOP_EN.has(w):
					counts[w] = int(counts.get(w, 0)) + 1
		else:
			for tok in full.split(" ", false):
				var w := tok.strip_edges().rstrip(".,:!?")
				if w.length() >= 2:
					counts[w] = int(counts.get(w, 0)) + 1
		var worst := ""
		var worst_n := 0
		for w in counts:
			if counts[w] > worst_n:
				worst_n = counts[w]
				worst = w
		report.lengths["most_repeated." + lang] = "%s x%d" % [worst, worst_n]
		check(worst_n <= 5, "%s: no keyword repeated more than 5 times in full description ('%s' x%d)" % [lang, worst, worst_n])
		for line in full.split("\n"):
			var parts := line.split(",")
			var short_parts := 0
			for p in parts:
				if p.strip_edges().split(" ", false).size() <= 2:
					short_parts += 1
			check(not (parts.size() >= 6 and short_parts >= 6), "%s: no keyword list line '%s'" % [lang, line.left(40)])
		check(not RegEx.create_from_string("(?i)(review|리뷰|후기)[^\\n]*[\"“”]").search(full), "%s: no testimonial quotes" % lang)
	return true

func test_listing_markers() -> bool:
	# Monetization statements must carry the change marker (monetization undecided).
	for pair in [["ko", ["광고", "결제"], "[수익화 결정 시 변경]"], ["en", ["ads", "purchase"], "[CHANGES IF MONETIZED]"]]:
		var raw := block(listing(), "full." + pair[0])
		var found := false
		for line in raw.split("\n"):
			for kw in pair[1]:
				if line.to_lower().contains(kw):
					found = true
					check(line.contains(pair[2]), "%s: monetization line carries %s: '%s'" % [pair[0], pair[2], line.left(50)])
		check(found, "%s: full description states the current monetization status" % pair[0])
	# Each claim table row names evidence.
	var t := listing()
	var sec := t.substr(t.find("## 5."))
	var rows := 0
	for line in sec.split("\n"):
		if line.begins_with("| ") and not line.begins_with("| Claim") and not line.begins_with("|---"):
			rows += 1
			check(line.split("|").size() >= 4 and line.split("|")[2].strip_edges() != "", "claim row has evidence: '%s'" % line.left(40))
		if line.begins_with("Not claimed"):
			break
	check(rows >= 6, "at least 6 evidenced claims (%d)" % rows)
	return true

func test_policy() -> bool:
	if not check(FileAccess.file_exists(POLICY), "PRIVACY_POLICY_DRAFT.md exists"):
		return true
	var t := FileAccess.get_file_as_string(POLICY)
	var ko := block(t, "policy.ko")
	var en := block(t, "policy.en")
	check(ko.begins_with("# 개인정보처리방침"), "ko titled 개인정보처리방침 (Play: clearly labelled)")
	check(en.begins_with("# Privacy Policy"), "en titled Privacy Policy")
	# Google Play User Data policy content items, in both languages.
	var need := {
		"developer": [["{{DEVELOPER_NAME}}"], ["{{DEVELOPER_NAME}}"]],
		"contact": [["{{CONTACT_EMAIL}}"], ["{{CONTACT_EMAIL}}"]],
		"data types": [["처리하는 개인정보"], ["Information we process"]],
		"sharing": [["제3자 제공"], ["Sharing"]],
		"security": [["안전성 확보"], ["Security"]],
		"retention/deletion": [["보유 기간", "파기"], ["Retention and deletion"]],
		"changes/effective date": [["{{EFFECTIVE_DATE}}"], ["{{EFFECTIVE_DATE}}"]],
	}
	for item in need:
		for kw in need[item][0]:
			check(ko.contains(kw), "ko covers %s (%s)" % [item, kw])
		for kw in need[item][1]:
			check(en.contains(kw), "en covers %s (%s)" % [item, kw])
	# Change markers for monetization and legal review in both languages.
	for m in ["[광고 활성화 시]", "[결제 활성화 시]", "[법률 확인 필요]"]:
		check(ko.contains(m), "ko marks %s" % m)
	for m in ["[IF ADS ENABLED]", "[IF PURCHASES ENABLED]", "[LEGAL REVIEW]"]:
		check(en.contains(m), "en marks %s" % m)
	# Same number of conditional blocks in ko and en (translation drift guard).
	for pair in [["[광고 활성화 시]", "[IF ADS ENABLED]"], ["[결제 활성화 시]", "[IF PURCHASES ENABLED]"], ["[분석 활성화 시]", "[IF ANALYTICS ENABLED]"]]:
		check(ko.count(pair[0]) == en.count(pair[1]), "ko/en same count of %s / %s (%d vs %d)" % [pair[0], pair[1], ko.count(pair[0]), en.count(pair[1])])
	# Placeholders match between ko and en.
	var re := RegEx.create_from_string("\\{\\{[A-Z_]+\\}\\}")
	var pk := {}
	var pe := {}
	for m in re.search_all(ko): pk[m.get_string()] = true
	for m in re.search_all(en): pe[m.get_string()] = true
	var a: Array = pk.keys(); a.sort()
	var b: Array = pe.keys(); b.sort()
	check(a == b, "ko/en placeholders match (%s vs %s)" % [str(a), str(b)])
	# Lines outside conditional blocks must not claim collection (disabled-mode basis).
	for line in (ko + "\n" + en).split("\n"):
		var conditional := line.contains("활성화 시]") or line.contains("[IF ")
		if not conditional and (line.contains("광고 식별자를 수집") or line.to_lower().contains("we collect your")):
			check(false, "unconditional collection claim: '%s'" % line.left(50))
	passes += 1
	return true

# ------------------------------------------------------------------ M7: name search, rating, data safety

const NAME_LOG := "res://docs/services/NAME_SEARCH_LOG.md"
const RATING := "res://docs/services/CONTENT_RATING_DRAFT.md"
const SAFETY := "res://docs/services/DATA_SAFETY_DRAFT.md"
const NAME_STATUS := ["NO_EXACT_MATCH_FOUND", "SIMILAR_FOUND", "NOT_CHECKED"]
const NAME_SOURCES := ["Google Play", "Web", "KIPRIS"]

## Every title candidate has one row per source with a date and a fixed status.
func test_name_search_log() -> bool:
	if not check(FileAccess.file_exists(NAME_LOG), "NAME_SEARCH_LOG.md exists"):
		return true
	var rows := {}
	for line in FileAccess.get_file_as_string(NAME_LOG).split("\n"):
		var c := line.split("|")
		if c.size() < 7 or not NAME_SOURCES.has(c[2].strip_edges()):
			continue
		var key := c[1].strip_edges() + "|" + c[2].strip_edges()
		check(not rows.has(key), "name log: one row for %s" % key)
		rows[key] = {"date": c[3].strip_edges(), "status": c[4].strip_edges(), "result": c[5].strip_edges()}
	var candidates: Array = titles("ko") + titles("en")
	check(candidates.size() == 6, "name log: 6 title candidates in the listing (%d)" % candidates.size())
	for t in candidates:
		for src in NAME_SOURCES:
			var k: String = t + "|" + src
			if not check(rows.has(k), "name log row for '%s' / %s" % [t, src]):
				continue
			var r: Dictionary = rows[k]
			check(RegEx.create_from_string("^2026-\\d\\d-\\d\\d$").search(r.date) != null, "name log %s has a date" % k)
			check(NAME_STATUS.has(r.status), "name log %s status '%s' from fixed set" % [k, r.status])
			check(r.result.length() >= 10, "name log %s records a result" % k)
	var txt := FileAccess.get_file_as_string(NAME_LOG)
	check(txt.contains("not a trademark clearance"), "name log states it is not a trademark clearance")
	return true

## Rating draft: every topic answered, trigger table covers ads/purchases/user interaction/location/internet.
func test_content_rating() -> bool:
	if not check(FileAccess.file_exists(RATING), "CONTENT_RATING_DRAFT.md exists"):
		return true
	var t := FileAccess.get_file_as_string(RATING)
	var s2 := t.substr(t.find("## 2."), t.find("## 3.") - t.find("## 2."))
	var topics := ["Category", "Violence", "Blood / gore", "Fear / horror", "Sexual content", "Language", "Controlled substances", "Gambling", "Users interact", "Shares location", "Unrestricted internet", "Digital purchases", "Ads"]
	for topic in topics:
		var found := false
		for line in s2.split("\n"):
			var c := line.split("|")
			if c.size() >= 5 and c[1].strip_edges().begins_with(topic):
				found = true
				check(c[2].strip_edges() != "" and c[3].strip_edges() != "", "rating topic '%s' has answer and evidence" % topic)
				check(c[4].strip_edges() != "", "rating topic '%s' names who confirms" % topic)
		check(found, "rating topic '%s' present" % topic)
	var s3 := t.substr(t.find("## 3."))
	for trig in ["ads", "purchases", "random items", "chat", "Location", "children"]:
		check(s3.to_lower().contains(trig.to_lower()), "rating change table covers '%s'" % trig)
	check(t.contains("Not submitted"), "rating draft marked not submitted")
	check(t.contains("**Open.**"), "open human-looking-character question kept visible")
	return true

## Data safety draft: "No" answer only while the build really sends nothing.
func test_data_safety() -> bool:
	if not check(FileAccess.file_exists(SAFETY), "DATA_SAFETY_DRAFT.md exists"):
		return true
	var t := FileAccess.get_file_as_string(SAFETY)
	var cats := ["Location", "Personal info", "Financial info", "Health and fitness", "Messages", "Photos and videos", "Audio files", "Files and docs", "Calendar", "Contacts", "App activity", "Web browsing", "App info and performance", "Device or other IDs"]
	var s3 := t.substr(t.find("## 3."), t.find("## 4.") - t.find("## 3."))
	for c in cats:
		check(s3.contains(c), "data safety §3 lists category '%s'" % c)
	check(s3.contains("| **No** |"), "data safety answers No for collect/share")
	# The "No" answer is valid only if these hold in the repo right now.
	var inet := "missing"
	if FileAccess.file_exists("res://export_presets.cfg"):
		for line in FileAccess.get_file_as_string("res://export_presets.cfg").split("\n"):
			if line.strip_edges().begins_with("permissions/internet="):
				inet = line.strip_edges().get_slice("=", 1)
	check(inet == "false" or inet == "missing", "export INTERNET permission is off (%s); otherwise revise DATA_SAFETY_DRAFT.md" % inet)
	var d: Dictionary = load("res://src/services/services_factory.gd").create({})
	var snap: Dictionary = load("res://src/services/service_diagnostics.gd").snapshot(d)
	check(not snap.live.values().has(true), "default services build has nothing live (%s)" % str(snap.live))
	check(snap.adapters.analytics_sink == "null", "default analytics sink is null")
	var s4 := t.substr(t.find("## 4."))
	for f in ["Rewarded ads", "In-app purchases", "Verification server", "Remote analytics", "Accounts"]:
		check(s4.contains(f), "data safety change table covers '%s'" % f)
	check(t.contains("{{PRIVACY_POLICY_URL}}"), "privacy policy URL required even with No")
	return true

# ------------------------------------------------------------------ M9: billing preparation docs

const PLUGINS := "res://docs/services/BILLING_PLUGIN_CANDIDATES.md"
const SANDBOX := "res://docs/services/BILLING_SANDBOX_TEST_PLAN.md"
const NOSERVER := "res://docs/services/NO_SERVER_MINIMUM.md"

## Plugin table: every candidate has a Billing Library ≥ 8 claim, a source URL and a release date;
## nothing installed in the project. Sandbox plan: every setup step has an owner tag, every test
## case names an expected service result code that really exists. No-server doc: every risk has a
## mitigation and residual; missing items stay marked Missing.
func test_billing_docs() -> bool:
	for p in [PLUGINS, SANDBOX, NOSERVER]:
		if not check(FileAccess.file_exists(p), "%s exists" % p):
			return true
	var pt := FileAccess.get_file_as_string(PLUGINS)
	var rows := 0
	for line in pt.split("\n"):
		var c := line.split("|")
		if c.size() > 9 and RegEx.create_from_string("^ P-[A-Z] $").search(c[1]) != null:
			rows += 1
			var ver := RegEx.create_from_string("(\\d+)\\.(\\d+)\\.(\\d+)").search(c[4])
			check(ver != null and int(ver.get_string(1)) >= 8, "plugin %s billing library ≥ 8 (%s)" % [c[1].strip_edges(), c[4].strip_edges()])
			check(c[5].strip_edges().begins_with("YES"), "plugin %s meets B1" % c[1].strip_edges())
			check(RegEx.create_from_string("\\(2026-\\d\\d-\\d\\d\\)").search(c[3]) != null, "plugin %s release date" % c[1].strip_edges())
			check(c[8].contains("https://"), "plugin %s official source" % c[1].strip_edges())
	check(rows >= 2, "at least 2 plugin candidates (%d)" % rows)
	check(pt.contains("**Nothing is installed.**"), "plugin doc states nothing installed")
	check(not DirAccess.dir_exists_absolute("res://addons/GodotGooglePlayBilling") and not DirAccess.dir_exists_absolute("res://addons/AndroidIAPP"), "no billing plugin installed in addons/")
	var st := FileAccess.get_file_as_string(SANDBOX)
	var R := load("res://src/services/service_result.gd")
	var codes := {}
	for k in R.get_script_constant_map():
		var v = R.get_script_constant_map()[k]
		if v is String:
			codes[v] = true
	var setup := 0
	var cases := 0
	for line in st.split("\n"):
		var c := line.split("|")
		if c.size() < 6:
			continue
		var id := c[1].strip_edges()
		if RegEx.create_from_string("^S\\d+$").search(id) != null:
			setup += 1
			check(RegEx.create_from_string("\\[(USER|04|06|07)\\]").search(c[2]) != null, "setup %s has an owner tag" % id)
		elif RegEx.create_from_string("^T\\d+$").search(id) != null:
			cases += 1
			var found := false
			for m in RegEx.create_from_string("`([a-z_]+)[^`]*`").search_all(c[4]):
				if codes.has(m.get_string(1)) or ["restore_finished", "purchase_finished", "entitlement_changed", "consumable_granted"].has(m.get_string(1)):
					found = true
			check(found, "test case %s names a real service result code" % id)
			check(c[6].strip_edges() != "", "test case %s maps to a requirement/row" % id)
	check(setup >= 8, "sandbox plan has setup steps (%d)" % setup)
	check(cases >= 12, "sandbox plan has test cases (%d)" % cases)
	check(st.contains("**PLAN ONLY. Nothing here has been run.**"), "sandbox plan marked not run")
	check(st.count("**[USER]**") >= 5, "user-only steps marked (%d)" % st.count("**[USER]**"))
	var ns := FileAccess.get_file_as_string(NOSERVER)
	var risks := 0
	var s4 := ns.substr(ns.find("## 4."), ns.find("## 5.") - ns.find("## 4."))
	for line in s4.split("\n"):
		var c := line.split("|")
		if c.size() >= 7 and not line.begins_with("| Risk") and not line.begins_with("|---"):
			risks += 1
			check(c[4].strip_edges() != "" and c[5].strip_edges() != "", "risk '%s' has mitigation and residual" % c[1].strip_edges().left(30))
	check(risks >= 6, "no-server doc lists risks (%d)" % risks)
	for m in ["R7", "R8", "R9"]:
		var line_ok := false
		for line in ns.split("\n"):
			if line.begins_with("| %s |" % m):
				line_ok = line.contains("**Missing:**")
		check(line_ok, "no-server %s still marked Missing" % m)
	# The code still refuses real purchases without a trusted verifier.
	var d: Dictionary = load("res://src/services/services_factory.gd").create({})
	check(d.verifier.kind() == "unavailable", "default verifier is still 'unavailable' (no client-side verifier shipped)")
	check(not FileAccess.file_exists("res://src/services/billing/client_side_verifier.gd"), "no client-side verifier without user decision U6")
	return true
