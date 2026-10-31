extends SceneTree
## Lint for docs/services/STORE_LISTING_DRAFT.md and PRIVACY_POLICY_DRAFT.md. Owner: 06-services.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_listing.gd
## Exit 0 = pass, 1 = failure. Rules from Play's Metadata policy and Store listing limits
## (sources and check date in STORE_LISTING_DRAFT.md §1). This checks mechanical rules only;
## it does not prove the copy is good, accurate in every word, or legally sufficient.

const LISTING := "res://docs/services/STORE_LISTING_DRAFT.md"
const POLICY := "res://docs/services/PRIVACY_POLICY_DRAFT.md"
const LIMITS := {"title": 30, "subtitle": 30, "short": 80, "full": 4000}
## Q3 working title, decided by the user 2026-10-31 16:19 KST (coordinator-to-06-services.md).
## Final store name only after the KIPRIS check (docs/services/KIPRIS_MANUAL_CHECK.md).
const WORKING_TITLE := {"ko": "빵집 기사단: 곰팡이 디펜스", "en": "Bakery Knights: Mold Defense"}
const APPLE_NAME_MIN := 2

## Ranking, price/promotion and Play-program wording (Metadata policy examples) + superlatives.
const BANNED_EN := ["#1", "best", "top", "popular", "award", "free", "% off", "discount", "sale",
	"editor's choice", "editors' choice", "new", "no. 1", "number one", "ultimate", "google play", "trending"]
const BANNED_KO := ["1위", "최고", "인기", "무료", "할인", "에디터", "추천", "신규", "수상", "베스트", "역대급", "구글 플레이"]
## Third-party marks (09 R09-06-3): Devsisters' Cookie Run family and real bakery brands must not
## appear in titles, IAP names or store text.
const BANNED_BRANDS := ["쿠키", "쿠키런", "cookie", "cookierun", "devsisters", "데브시스터즈", "파리바게뜨", "paris baguette", "뚜레쥬르", "tous les jours", "성심당",
	"빵어전", "bread defense", "eternaxcode"]
## Signature wording of the similar game "Bread Defense / 빵어전" (ETERNAXCODE; 09 SUCCESS_ANALYSIS §28,
## store pages checked 2026-10-31). Store text must not borrow it (STORE_LISTING_DRAFT.md §7).
## ko: substring match. en: word-start match (catches plurals), multi-word phrases by substring.
const COMPETITOR_KO := ["빵어전", "반죽", "화덕", "온기", "빵 카드", "눅눅이", "축축", "홀씨", "불씨", "빵전사", "대련", "따뜻한 빵", "타워디펜스", "타워 디펜스", "제빵사", "도감"]
const COMPETITOR_EN := ["bread defense", "dough", "hearth", "warmth", "bread card", "moistie", "damp trail", "spore cloud", "ember", "bread warrior", "duel", "warm bread", "tower defense", "tower defence", "assistant"]
const STOP_EN := ["the", "and", "a", "an", "to", "of", "for", "your", "you", "or", "with", "from", "each", "any", "such", "as", "by", "in", "on", "no", "every", "then", "into", "after", "use", "up", "per"]

var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}, "lengths": {}}

func _initialize() -> void:
	_group("listing_fields", test_listing_fields)
	_group("listing_wording", test_listing_wording)
	_group("listing_competitor_overlap", test_competitor_overlap)
	_group("listing_claim_markers", test_listing_markers)
	_group("privacy_policy_template", test_policy)
	_group("name_search_log", test_name_search_log)
	_group("content_rating_draft", test_content_rating)
	_group("data_safety_draft", test_data_safety)
	_group("billing_docs", test_billing_docs)
	_group("legal_and_options_docs", test_legal_options)
	_group("privacy_site", test_privacy_site)
	_group("families_and_rating_q2", test_families_rating)
	_group("kipris_manual_check", test_kipris_manual)
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
		# One working title per language, equal to the user's Q3 answer (Play title = App Store name).
		check(ts == [WORKING_TITLE[lang]], "%s: title block holds only the Q3 working title '%s' (%s)" % [lang, WORKING_TITLE[lang], str(ts)])
		for t in ts:
			report.lengths["title." + lang] = t.length()
			check(t.length() <= LIMITS.title, "%s title '%s' ≤ 30 chars, Play title and App Store name (%d)" % [lang, t, t.length()])
			check(t.length() >= APPLE_NAME_MIN, "%s title ≥ 2 chars (App Store name minimum)" % lang)
			check(t == t.strip_edges() and not t.contains("  "), "%s title has no stray spaces" % lang)
		var sub := store_text(block(listing(), "subtitle." + lang))
		report.lengths["subtitle." + lang] = sub.length()
		check(sub.length() > 0, "%s App Store subtitle present" % lang)
		check(sub.length() <= LIMITS.subtitle, "%s App Store subtitle ≤ 30 chars (%d)" % [lang, sub.length()])
		check(not sub.contains("\n"), "%s subtitle is one line" % lang)
		check(ts.is_empty() or (sub != ts[0] and not ts[0].contains(sub)), "%s subtitle does not repeat the title" % lang)
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
	out.append(store_text(block(listing(), "subtitle." + lang)))
	out.append(store_text(block(listing(), "short." + lang)))
	out.append(store_text(block(listing(), "full." + lang)))
	return out

## No store field borrows the similar game's name or signature wording (STORE_LISTING_DRAFT.md §7).
func test_competitor_overlap() -> bool:
	for lang in ["ko", "en"]:
		var fields := all_store_fields(lang)
		check(fields.size() == 4, "%s: title, subtitle, short and full all checked (%d)" % [lang, fields.size()])
		for s in fields:
			var low: String = s.to_lower()
			for w in COMPETITOR_KO:
				check(not s.contains(w), "%s: no Bread Defense wording '%s' in '%s'" % [lang, w, s.left(40)])
			for w in COMPETITOR_EN:
				var hit := low.contains(w) if w.contains(" ") else RegEx.create_from_string("\\b" + w).search(low) != null
				check(not hit, "%s: no Bread Defense wording '%s' in '%s'" % [lang, w, s.left(40)])
	# The §7 table documents every blocked phrase, so 01 sees the same list the lint uses.
	var t := listing()
	var s7 := t.substr(t.find("## 7."))
	for w in COMPETITOR_KO + COMPETITOR_EN:
		if w in ["tower defence", "타워 디펜스"]:
			continue
		check(s7.contains(w), "§7 table lists blocked phrase '%s'" % w)
	return true

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
	check(candidates == [WORKING_TITLE.ko, WORKING_TITLE.en], "name log: listing carries the Q3 working title (%s)" % str(candidates))
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
	var s2_end := t.find("## 2a.") if t.find("## 2a.") > 0 else t.find("## 3.")   # §2a (Q2 re-check) has its own format
	var s2 := t.substr(t.find("## 2."), s2_end - t.find("## 2."))
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
	for m in ["R7", "R9"]:   # R8 (quantity) fixed in M10
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

# ------------------------------------------------------------------ M11: legal display, Q2 options, Data safety confirmation

const LEGAL := "res://docs/services/IN_APP_LEGAL_DISPLAY.md"
const OPTIONS := "res://docs/services/MONETIZATION_OPTIONS_WORK.md"

func test_legal_options() -> bool:
	for p in [LEGAL, OPTIONS, SAFETY]:
		if not check(FileAccess.file_exists(p), "%s exists" % p):
			return true
	# Legal display: L1–L4 each with a source; the OFL text it relies on exists in the repo and
	# really carries the copyright line the acceptance check expects.
	var lt := FileAccess.get_file_as_string(LEGAL)
	for id in ["L1", "L2", "L3", "L4"]:
		var found := false
		for line in lt.split("\n"):
			if line.begins_with("| %s |" % id):
				found = true
				var c := line.split("|")
				check(c.size() >= 5 and c[3].strip_edges() != "", "legal %s has a source" % id)
		check(found, "legal requirement %s present" % id)
	var ofl := FileAccess.get_file_as_string("res://assets/fonts/OFL-Galmuri.txt") if FileAccess.file_exists("res://assets/fonts/OFL-Galmuri.txt") else ""
	check(ofl.begins_with("Copyright (c) 2019"), "OFL file starts with the Galmuri copyright line")
	check(ofl.contains("SIL Open Font License, Version 1.1"), "OFL file names OFL 1.1")
	check(Engine.get_license_text().contains("Permission is hereby granted"), "Engine.get_license_text() returns the MIT text (licences view source)")
	check(Engine.get_copyright_info().size() > 0, "Engine.get_copyright_info() non-empty")
	check(lt.contains("**proposal for 04**"), "legal display marked as proposal (06 does not edit UI)")
	# Q2 options: every comparison row has a non-empty cell for A, B and C.
	var ot := FileAccess.get_file_as_string(OPTIONS)
	var s1 := ot.substr(ot.find("## 1."), ot.find("## 2.") - ot.find("## 1."))
	var rows := 0
	for line in s1.split("\n"):
		var c := line.split("|")
		if c.size() >= 6 and not line.begins_with("| Item") and not line.begins_with("|---"):
			rows += 1
			for i in [2, 3, 4]:
				check(c[i].strip_edges() != "", "options row '%s' has a value for %s" % [c[1].strip_edges(), ["", "", "A", "B", "C"][i]])
	check(rows >= 10, "options comparison rows (%d)" % rows)
	var s2 := ot.substr(ot.find("## 2."), ot.find("## 3.") - ot.find("## 2."))
	check(Array(s2.split("\n")).filter(func(l): return l.begins_with("| ") and not l.begins_with("| Test area") and not l.begins_with("|---")).size() >= 5, "test scope rows per option")
	check(ot.contains("not a decision"), "options doc marked not a decision")
	# Data safety confirmation ties to a concrete APK hash and the 04 check IDs.
	var st := FileAccess.get_file_as_string(SAFETY)
	check(RegEx.create_from_string("SHA-256 `[0-9A-F]{64}`").search(st) != null, "Data safety confirmation records the APK SHA-256")
	check(st.contains("A7 TESTED") and st.contains("C1 TESTED"), "Data safety confirmation cites 04 A7 and C1")
	check(st.contains("release AAB"), "confirmation requires release AAB re-check")
	return true

# ------------------------------------------------------------------ M12: publishable privacy page, Families, Q2 deferred

const SITE := "res://docs/services/privacy_site/index.html"
const HOSTING := "res://docs/services/PRIVACY_POLICY_HOSTING.md"
const FAMILIES := "res://docs/services/FAMILIES_ASSESSMENT.md"
const DISABLED_PLACEHOLDERS := ["{{APP_NAME}}", "{{CHILD_AUDIENCE_STATEMENT}}", "{{CONTACT_EMAIL}}", "{{DEVELOPER_NAME}}", "{{EFFECTIVE_DATE}}", "{{PRIVACY_OFFICER}}"]

static func strip_comments(html: String) -> String:
	return RegEx.create_from_string("(?s)<!--.*?-->").sub(html, "", true)

## The page matches the draft's disabled-mode text: same section titles in both languages, no
## monetization blocks, no visible reviewer markers, only disabled-mode placeholders. Remaining
## placeholders are reported as publish blockers (not failures: values are user data).
func test_privacy_site() -> bool:
	for p in [SITE, HOSTING, POLICY]:
		if not check(FileAccess.file_exists(p), "%s exists" % p):
			return true
	var raw := FileAccess.get_file_as_string(SITE)
	var visible := strip_comments(raw)
	var draft := FileAccess.get_file_as_string(POLICY)
	for lang in ["ko", "en"]:
		var block_text := block(draft, "policy." + lang)
		var titles_found := 0
		for line in block_text.split("\n"):
			if line.begins_with("## "):
				var title := line.substr(3).strip_edges()
				check(visible.contains("<h2>%s</h2>" % title), "site has %s section '%s'" % [lang, title])
				titles_found += 1
		check(titles_found == 9, "draft %s has 9 sections (%d)" % [lang, titles_found])
	check(visible.contains("<h1>개인정보처리방침</h1>") and visible.contains("<h1>Privacy Policy</h1>"), "page titled as privacy policy in ko and en")
	check(visible.contains("<title>개인정보처리방침 / Privacy Policy"), "HTML title names the privacy policy")
	for m in ["활성화 시]", "[IF ", "[법률 확인 필요]", "[LEGAL REVIEW]", "[수익화", "[CHANGES"]:
		check(not visible.contains(m), "no visible draft marker '%s' on the page" % m)
	for kw in ["광고 사업자", "인앱 결제", "ad provider", "In-app purchases"]:
		check(not visible.contains(kw), "disabled-mode page does not mention '%s'" % kw)
	check(visible.contains("현재 게임은 이용자의 개인정보를 수집하거나 외부로 전송하지 않습니다"), "ko states no data collected (disabled mode)")
	check(visible.contains("does not collect personal information"), "en states no data collected")
	var found := {}
	for m in RegEx.create_from_string("\\{\\{[A-Z_]+\\}\\}").search_all(visible):
		found[m.get_string()] = true
	var keys: Array = found.keys()
	keys.sort()
	check(keys.all(func(k): return DISABLED_PLACEHOLDERS.has(k)), "only disabled-mode placeholders on the page (%s)" % str(keys))
	report["privacy_site_publish_blockers"] = keys
	print("  privacy_site publish blockers (unfilled placeholders): %d %s" % [keys.size(), str(keys)])
	var ht := FileAccess.get_file_as_string(HOSTING)
	check(ht.contains("**PREPARATION ONLY. Nothing is published and no hosting is chosen.**"), "hosting doc marked preparation only")
	check(ht.count("**[USER]**") >= 4, "hosting steps mark user-only actions (%d)" % ht.count("**[USER]**"))
	check(ht.contains("https://docs.github.com/en/pages/"), "hosting facts cite GitHub docs")
	return true

func test_families_rating() -> bool:
	for p in [FAMILIES, RATING]:
		if not check(FileAccess.file_exists(p), "%s exists" % p):
			return true
	var ft := FileAccess.get_file_as_string(FAMILIES)
	for id in ["F1", "F2", "F3", "F4", "F5", "F6", "F7"]:
		var ok := false
		for line in ft.split("\n"):
			if line.begins_with("| %s |" % id):
				ok = line.contains("https://")
		check(ok, "families rule %s has a source" % id)
	for opt in ["T1", "T2", "T3"]:
		check(ft.contains("| %s |" % opt), "families option %s present" % opt)
	check(ft.contains("not a decision"), "families doc marked not a decision")
	check(ft.contains("SUCCESS_ANALYSIS.md §25.3"), "families doc aligned with 09 §25.3")
	var rt := FileAccess.get_file_as_string(RATING)
	var s2a := rt.substr(rt.find("## 2a."), rt.find("## 3.") - rt.find("## 2a."))
	for topic in ["Ads", "Digital purchases", "Users interact", "Shares location", "Unrestricted internet"]:
		var ok2 := false
		for line in s2a.split("\n"):
			if line.begins_with("| " + topic):
				ok2 = line.split("|")[2].strip_edges() == "No"
		check(ok2, "Q2-deferred re-check answers No for %s" % topic)
	# The "No" answers must match the repo right now.
	var d: Dictionary = load("res://src/services/services_factory.gd").create({})
	check(load("res://src/services/service_diagnostics.gd").snapshot(d).live.values().all(func(v): return v == false), "nothing live in default services")
	check(not DirAccess.dir_exists_absolute("res://addons"), "no addons/ (no ad or billing plugin)")
	var od := FileAccess.get_file_as_string("res://docs/services/OPEN_DECISIONS.md")
	check(od.contains("DEFERRED by user 2026-10-31 16:09 KST"), "U1 marked deferred by user")
	return true

# ------------------------------------------------------------------ Q3: working title, KIPRIS manual check

const KIPRIS := "res://docs/services/KIPRIS_MANUAL_CHECK.md"
const KIPRIS_CLASSES := ["9", "41"]
const KIPRIS_RESULTS := ["NOT_DONE", "NO_HIT", "HITS_RECORDED"]
const KIPRIS_STATUS := ["출원", "공고", "등록", "거절", "소멸", "포기", "취하", "무효"]

static func section(t: String, start: String, end: String) -> String:
	var a := t.find(start)
	if a < 0:
		return ""
	var b := t.find(end, a)
	return t.substr(a, (b - a) if b > a else -1)

## The checklist covers both classes for every term, both title languages, and the status
## values; results can only be entered with a date and a searcher; nothing can claim a KIPRIS
## result elsewhere while the record is empty.
func test_kipris_manual() -> bool:
	if not check(FileAccess.file_exists(KIPRIS), "KIPRIS_MANUAL_CHECK.md exists"):
		return true
	var t := FileAccess.get_file_as_string(KIPRIS)
	check(t.contains("not a legal opinion"), "KIPRIS doc says it is not a legal opinion")
	check(t.contains("https://www.kipris.or.kr"), "KIPRIS doc names the site")
	check(t.contains("**[USER]**"), "KIPRIS search marked as a user/person step")
	for cls in ["class 9", "class 41"]:
		check(t.contains(cls), "KIPRIS doc covers %s" % cls)
	var s4 := section(t, "## 4.", "## 5.")
	for st in KIPRIS_STATUS:
		check(s4.contains("| %s |" % st), "status value '%s' explained" % st)
	# §3 terms
	var terms := {}
	for line in section(t, "## 3.", "## 4.").split("\n"):
		var c := line.split("|")
		if c.size() >= 5 and RegEx.create_from_string("^T\\d+$").search(c[1].strip_edges()) != null:
			terms[c[1].strip_edges()] = c[2].strip_edges()
	check(terms.size() >= 10, "at least 10 search terms (%d)" % terms.size())
	var term_texts: Array = terms.values()
	# Both working titles (punctuation removed) and their main parts are searched.
	for lang in ["ko", "en"]:
		var title: String = WORKING_TITLE[lang]
		var full := title.replace(":", "")
		check(term_texts.has(full), "full %s title searched as '%s'" % [lang, full])
		for part in title.split(":"):
			check(term_texts.has(part.strip_edges()), "%s title part '%s' searched" % [lang, part.strip_edges()])
			check(term_texts.has(part.strip_edges().replace(" ", "")), "%s title part without spaces '%s' searched" % [lang, part.strip_edges().replace(" ", "")])
	# §5 summary: one row per term × class, results only with date and searcher.
	var rows := {}
	var not_done := 0
	var hits_ids: Array = []
	for line in section(t, "## 5.", "## 6.").split("\n"):
		var c := line.split("|")
		if c.size() < 9 or RegEx.create_from_string("^T\\d+$").search(c[1].strip_edges()) == null:
			continue
		var id := c[1].strip_edges()
		var cls := c[3].strip_edges()
		var res := c[4].strip_edges()
		var key := id + "|" + cls
		check(not rows.has(key), "one summary row for %s" % key)
		rows[key] = true
		check(terms.get(id, "") == c[2].strip_edges(), "summary %s term matches §3" % key)
		check(KIPRIS_CLASSES.has(cls), "summary %s class is 9 or 41" % key)
		check(KIPRIS_RESULTS.has(res), "summary %s result '%s' from fixed set" % [key, res])
		if res == "NOT_DONE":
			not_done += 1
			check(c[5].strip_edges() == "" and c[6].strip_edges() == "" and c[7].strip_edges() == "", "summary %s NOT_DONE has no date/searcher/records" % key)
		else:
			check(RegEx.create_from_string("^20\\d\\d-\\d\\d-\\d\\d$").search(c[5].strip_edges()) != null, "summary %s result has a date" % key)
			check(c[6].strip_edges() != "", "summary %s result names the searcher" % key)
			if res == "HITS_RECORDED":
				check(c[7].strip_edges().contains("R"), "summary %s points to §6 records" % key)
				hits_ids.append(id)
	for id in terms:
		for cls in KIPRIS_CLASSES:
			check(rows.has(id + "|" + cls), "summary row for %s class %s" % [id, cls])
	# §6 records: filled rows need date, searcher, term, class, status from §4.
	var filled := {}
	for line in section(t, "## 6.", "## 7.").split("\n"):
		var c := line.split("|")
		if c.size() < 14 or RegEx.create_from_string("^R\\d+$").search(c[1].strip_edges()) == null:
			continue
		var empty := true
		for i in range(2, 13):
			if c[i].strip_edges() != "":
				empty = false
		if empty:
			continue
		var rid := c[1].strip_edges()
		check(RegEx.create_from_string("^20\\d\\d-\\d\\d-\\d\\d$").search(c[2].strip_edges()) != null, "record %s has a date" % rid)
		check(c[3].strip_edges() != "", "record %s names the searcher" % rid)
		check(terms.has(c[4].strip_edges()) and KIPRIS_CLASSES.has(c[5].strip_edges()), "record %s names a §3 term and class" % rid)
		check(KIPRIS_STATUS.has(c[10].strip_edges()) or c[12].strip_edges() == "모름", "record %s status from §4 (or similarity 모름)" % rid)
		check(["동일", "유사", "비유사", "모름"].has(c[12].strip_edges()), "record %s similarity from fixed set" % rid)
		filled[c[4].strip_edges()] = true
	for id in hits_ids:
		check(filled.has(id), "HITS_RECORDED term %s has a §6 record" % id)
	report["kipris_not_done"] = not_done
	print("  kipris rows NOT_DONE: %d of %d" % [not_done, rows.size()])
	# No fabricated result: while anything is NOT_DONE, the doc and the name log say so.
	if not_done > 0:
		check(t.contains("**NOT DONE."), "KIPRIS doc headline says NOT DONE while rows are open")
		for line in FileAccess.get_file_as_string(NAME_LOG).split("\n"):
			var c := line.split("|")
			if c.size() >= 7 and c[2].strip_edges() == "KIPRIS" and WORKING_TITLE.values().has(c[1].strip_edges()):
				check(c[4].strip_edges() == "NOT_CHECKED", "name log KIPRIS row for '%s' stays NOT_CHECKED" % c[1].strip_edges())
		check(listing().contains("**KIPRIS class 9/41 search: NOT DONE**"), "listing states the KIPRIS search is not done")
	check(FileAccess.get_file_as_string(NAME_LOG).contains("KIPRIS_MANUAL_CHECK.md"), "name log points to the manual check")
	return true
