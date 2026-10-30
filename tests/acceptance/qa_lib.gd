extends RefCounted
## 07-qa acceptance result recorder + helpers. Owner: 07-qa.
## Status vocabulary (docs/verification/README.md):
##   PASS             behaviour verified by this run, with evidence
##   FAIL             behaviour exists but violates contract/expectation (bug filed)
##   NOT_IMPLEMENTED  feature/asset absent on disk; not a regression
##   NOT_TESTED       cannot be exercised in this environment (e.g. needs a phone)
##   BLOCKED          check could not run because of another failure / missing hook

const PASS := "PASS"
const FAIL := "FAIL"
const NOT_IMPL := "NOT_IMPLEMENTED"
const NOT_TESTED := "NOT_TESTED"
const BLOCKED := "BLOCKED"

var results: Array = []
var current_suite := ""

func record(id: String, status: String, title: String, detail := "", evidence: Variant = null) -> void:
	var r := {"id": id, "suite": current_suite, "status": status, "title": title, "detail": detail}
	if evidence != null:
		r["evidence"] = evidence
	results.append(r)
	var line := "[%s] %-16s %s" % [id, status, title]
	if detail != "" and status != PASS:
		line += " :: " + detail
	if status == FAIL:
		printerr(line)
	else:
		print(line)

## PASS/FAIL helper. Returns cond.
func check(id: String, title: String, cond: bool, fail_detail := "", evidence: Variant = null) -> bool:
	record(id, PASS if cond else FAIL, title, "" if cond else fail_detail, evidence)
	return cond

func counts() -> Dictionary:
	var c := {PASS: 0, FAIL: 0, NOT_IMPL: 0, NOT_TESTED: 0, BLOCKED: 0}
	for r in results:
		c[r.status] = int(c.get(r.status, 0)) + 1
	return c

func failed() -> bool:
	return int(counts()[FAIL]) > 0

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data

static func list_files(dir_path: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	var files := d.get_files()
	files.sort()
	for f in files:
		if f.ends_with(ext):
			out.append(dir_path + "/" + f)
	return out

static func rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func write_text(path: String, txt: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()

## Envelope matching INTERFACES.md §3 (checksum = sha256 of payload string).
static func save_envelope(payload: Variant) -> String:
	var txt := JSON.stringify(payload)
	return JSON.stringify({"version": 1, "checksum": txt.sha256_text(), "payload": txt})
