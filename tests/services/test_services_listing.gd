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
