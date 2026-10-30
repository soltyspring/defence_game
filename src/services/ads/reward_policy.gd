extends RefCounted
## Rewarded-ad offer policy: turns 01's placement rule (`where` in data/meta.json) plus the
## current game situation into eligible/not and a context id. Owner: 06-services.
## Fail-closed: unknown rules, missing data or a missing battle_uid => not eligible.
## The policy decides WHEN an offer may appear. RewardedAdService still applies enabled,
## consent, offline, cap and once-per-context gates. Monetization itself is still undecided.
##
## Situations (Dictionaries built by 02/04 from INTERFACES.md shapes):
##   {"kind": "result", "result": BattleResult}                     for where = results_win
##   {"kind": "battle", "battle_uid": String, "snapshot": HudSnapshot,
##    "ended": bool}                                               for where = in_round_once_below_30pct
## battle_uid is requested from 02 (06-services-to-02-engine S4). Until it exists every
## evaluation returns reason "missing_battle_uid".

const RULE_RESULTS_WIN := "results_win"
const RULE_RESCUE := "in_round_once_below_30pct"
const RESCUE_HP_RATIO := 0.30
## From RELEASE_DESIGN_REVIEW.md §3 (01): a run that used the rescue ad is capped at 2 stars.
## 02 applies it; the policy only reports it so the sink and result screen agree.
const RESCUE_MAX_STARS := 2

const UID_PATTERN := "^[A-Za-z0-9_.:-]{1,64}$"

## Returns {"eligible": bool, "reason": String, "context_id": String, "constraints": Dictionary}
static func evaluate(placement: Dictionary, situation: Dictionary) -> Dictionary:
	var reward = placement.get("reward", {})
	var where := str(reward.get("where", "")) if reward is Dictionary else ""
	match where:
		RULE_RESULTS_WIN:
			return _results_win(situation)
		RULE_RESCUE:
			return _rescue(situation)
	return _no("unknown_rule")

static func _results_win(s: Dictionary) -> Dictionary:
	if str(s.get("kind", "")) != "result":
		return _no("wrong_situation")
	var r = s.get("result")
	if not (r is Dictionary):
		return _no("missing_result")
	if not (r.get("won") is bool) or not r.won:
		return _no("not_won")
	var coins = r.get("coins")
	if not (coins is int or coins is float) or coins <= 0:
		return _no("no_coins_to_double")
	var uid := _uid(r.get("battle_uid"))
	if uid.is_empty():
		return _no("missing_battle_uid")
	return {"eligible": true, "reason": "", "context_id": "result:" + uid, "constraints": {}}

static func _rescue(s: Dictionary) -> Dictionary:
	if str(s.get("kind", "")) != "battle":
		return _no("wrong_situation")
	var ended = s.get("ended", false)
	if not (ended is bool) or ended:
		return _no("battle_ended")   # fail closed on a malformed flag
	var uid := _uid(s.get("battle_uid"))
	if uid.is_empty():
		return _no("missing_battle_uid")
	var snap = s.get("snapshot")
	if not (snap is Dictionary) or not (snap.get("player_base") is Dictionary):
		return _no("missing_snapshot")
	var hp = snap.player_base.get("hp")
	var hp_max = snap.player_base.get("hp_max")
	if not (hp is int or hp is float) or not (hp_max is int or hp_max is float) or hp_max <= 0:
		return _no("bad_base_hp")
	if hp <= 0:
		return _no("base_destroyed")
	if float(hp) / float(hp_max) >= RESCUE_HP_RATIO:
		return _no("base_hp_not_low")
	return {"eligible": true, "reason": "", "context_id": "rescue:" + uid,
		"constraints": {"max_stars": RESCUE_MAX_STARS}}

static func _uid(v: Variant) -> String:
	if not (v is String):
		return ""
	var re := RegEx.create_from_string(UID_PATTERN)
	return v if re.search(v) != null else ""

static func _no(reason: String) -> Dictionary:
	return {"eligible": false, "reason": reason, "context_id": "", "constraints": {}}
