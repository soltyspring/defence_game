# 06-services → 02-engine
Status: QUEUED (file request, not confirmed delivered). Date: 2026-10-31.
Context: docs/services/SERVICES.md. Everything is DISABLED by default (D9). None of this is urgent for the playable slice. Do it when convenient; S1–S3 make the service state persist and are needed before any ad/IAP can be turned on.

## S1 Autoload (your decision)
Add `Services="*res://src/services/services.gd"` after `Save`. In disabled mode it only builds disabled adapters (no network, no SDK, no visible effect). Alternative: defer until 01 confirms monetization. Either is fine; tell me which.

## S2 Save integration (the "reward once" guarantee depends on it)
- Keep a `services` Dictionary in the payload: add `"services": {}` to `Save.fresh()`. `_migrate` already keeps unknown keys; please keep that true for `services` in future migrations.
- After every `Save.load_progress()` (including `.bak` recovery) call:
  `Services.setup({"store": preload("res://src/services/service_store.gd").new(Save.progress["services"], Save.save_progress)})`
  Reason: `load_progress()` replaces the `progress` Dictionary, so an earlier store reference would go stale.
- The service ledger and the reward are then written in the same atomic `save_progress()`.
- If you prefer an accessor (e.g. `Save.services_state() -> Dictionary` + a `Save.loaded` signal), tell me and I adapt.

## S3 Grant sinks (only when 01 enables placements/products)
- Ads: `Services.ads.grant_sink = Callable(...)` with signature `(placement_id: String, reward: Dictionary, context_id: String) -> bool`. Apply `reward.effect` in memory (data/meta.json: `gold_mult_2` at results_win, `player_base_heal_ratio_0_3` once in-round below 30%). Return false if the context is no longer valid (battle ended, already doubled). Do not save inside the sink; the service commits.
- Consumables: `Services.purchases.grant_sink` with `(product_id, grant: Dictionary, purchase_key: String) -> bool`.

## S4 Battle uid (additive contract key)
Add `battle_uid: String` to `BattleInfo` and `BattleResult`, unique per battle instance for at least 7 days (e.g. `"%d-%d" % [Time.get_unix_time_from_system(), counter]`). Ads use `result:<battle_uid>` / `rescue:<battle_uid>` as context ids so one battle can never be rewarded twice.

## S5 Analytics producers (no-op while disabled)
`Services.analytics.track("round_start", {"round_id": id, "attempt": n})`, `track("round_end", {round_id, won, stars, duration_s, kills})`, `track("session_start", {app_version, build, lang})`. Schema: docs/services/ANALYTICS_EVENTS.md. Undeclared params are rejected.

## FYI (not a request)
On 2026-10-31 `selftest.gd` returned exit 1 because of files I do not own: `src/audio/audio_manager.gd` (missing preload `audio_event_bridge.gd`) and `src/ui/hud_top.gd` (parse error). It reported no errors for src/services/**.

# Update M2 (2026-10-31) — still QUEUED, no reply seen
## S2 clarified (ordering now ledger-first)
06 writes the ledger entry into `Save.progress["services"]` BEFORE calling your grant sink, then calls `commit_fn` (= `Save.save_progress`). So a save during the sink is safe. Please still do not save inside the sink. Requested acceptance check, once you integrate: a headless test that kills the process (or simulates a failed `save_progress`) between the sink and the commit, then reloads, and shows that coins and `services.ads.granted_contexts` are both present or both absent. 06 has only shown this against a save double (tests/services/test_services_m2.gd `crash_ads`/`crash_iap`), not against src/core/save.gd. I will not claim cross-save atomicity until that real test exists.
Also: call `Services.setup()` once per load. Two live instances on the same store no longer double-grant (tested), but the second instance drops the first one's in-flight session.

## S6 Offer situations for the policy (needs S4 battle_uid)
- Results: `Services.ads.offer_for("ad_double_gold", {"kind": "result", "result": <BattleResult with battle_uid>})`.
- In battle: `Services.ads.offer_for("ad_base_repair", {"kind": "battle", "battle_uid": uid, "snapshot": <HudSnapshot>, "ended": false})`.
- An eligible rescue returns `constraints.max_stars = 2` (01 rule, RELEASE_DESIGN_REVIEW.md §3). Your sink should apply it to that battle's star result.
- Until S4 exists every call returns `not_eligible` with reason `missing_battle_uid`. That is intended fail-closed behaviour.

# Update M3 (2026-10-31) — still QUEUED, no reply seen
## S2 concrete wiring (tested against your save.gd, unchanged)
After EVERY `Save.load_progress()` (including in `_ready`):
`Services.setup({"store": preload("res://src/services/save_bridge.gd").make_store(Save, Events)})`
- Needs `Save` and `Events` as the autoloads at `/root/Save`, `/root/Events`. The save epoch is counted only when `Events` is `/root/Events` (save.gd emits there).
- A store bound before a reload refuses offers/grants/commits (fail-closed), so re-binding after each load is required.
- Keep ONE Save instance per save file. Two instances = last writer wins; tests show disk stays consistent but one grant is lost.
- Evidence: tests/services/test_services_m3.gd (11 groups, incl. real process death via a child Godot process). It still does not prove the game calls this, so I keep the claim "not integrated".
## Request S7 (optional, small): emit a save epoch you own
If you ever stop emitting `progress_changed` after each save, please expose `Save.saves_completed: int` instead; services would read it. No change needed today.

# Update M4 (2026-10-31) — BLOCKING for service persistence, QUEUED, no reply to S1/S2 seen
S1/S2 are now the blocking items for any claim that service state is persisted by the game. To make it a one-line change:
- S1: add `Services="*res://src/services/services.gd"` after `Save=` in project.godot `[autoload]`.
- S2: nothing else required. As autoload `Services`, services.gd attaches to `/root/Save` in `_ready` and rebinds within one frame after every `Save.load_progress()`. Mode stays `disabled`; no network, SDK or UI effect.
- Acceptance: `pwsh -File tests/services/run_services_suites.ps1` must go from `OVERALL exit=2 (BLOCKED_NOT_INTEGRATED)` to `exit=0`. Report: user://services_integration_report.json. Contract: docs/services/SAVE_INTEGRATION_CONTRACT.md.
- S3 grant sinks: not needed until 01 enables a placement/product (gate reports I5 NOT_REQUIRED_YET).
- S4 battle_uid: seen done (battle.gd:65/74/210); gate check I6 passes against your generator. Thanks.
- The fault hook 07/10 requested is not needed by this gate (it uses a directory at save.json.tmp and child-process OS.kill).
