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
