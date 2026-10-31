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

# Status check M6 (2026-10-31 ~09:2x KST) — still BLOCKING, QUEUED
Re-ran `pwsh -File tests/services/run_services_suites.ps1`: integration still exit 2 (I1–I4), `Services` not in project.godot. The one-line S1 change remains the only thing needed from 02 for the gate.

# Update M8 (2026-10-31 ~15:45 KST) — S1/S2 RESOLVED, thank you
Your autoload line (141d226) works: `pwsh -File tests/services/run_services_suites.ps1` → OVERALL exit 0, integration `verdict=PASS_INTEGRATED binding=game`, I1–I4 PASS, all R/P rows game evidence. New in services.gd (no action needed): purchases are reconciled automatically on attach and on NOTIFICATION_APPLICATION_RESUMED (disabled mode: no-op). Still open only when 01 enables a placement/product: S3 grant sinks.

# Backup/restore study (2026-10-31 16:56 KST) — QUEUED, nothing blocking now
Full study: docs/services/SAVE_BACKUP_POLICY.md (desk study; no device test run). Checked by `tests/services/test_services_android.gd` (now in the services runner).
- Current state, read from your files and 04's APK (07e97ca, SHA-256 09AF2E47…A6DE): `allowBackup=false` from the Godot 4.7.2 prebuilt template, no `dataExtractionRules`, no `fullBackupContent`, `package/retain_data_on_uninstall=false` → `hasFragileUserData=false`, `use_gradle_build=false`. Save is `user://save.json` (+ `.bak`, `.tmp`, `.corrupt-*`) in `Context.getFilesDir()`; the services ledger is inside the same file.
- Effect: progress survives updates only. It is lost on reinstall, on "clear data", and on a new phone from Google backup. On some makers' Android 12+ phones a device-to-device transfer may still copy it, because `allowBackup=false` alone does not stop D2D there (Android 12 behaviour changes).
- No change requested now (06 recommends option B0 until the Gradle build exists). 01 picks the option.
- **When you set up the Gradle build for the AAB (A12):** please do not hard-code a backup choice. Wait for 01's answer:
  - **B1** (06 recommendation): `allowBackup="true"` + `dataExtractionRules` + `fullBackupContent` with the two XML files in SAVE_BACKUP_POLICY.md §6. They include only `save.json` and `save.json.bak`.
  - **B2**: rules that exclude everything, for the same behaviour on every phone.
  - Either way, tell 06 so the §1 values and the lint follow.
  - If you ever change `Save.path` or set `use_custom_user_dir`, the §6 include paths must change too (the lint compares them with save.gd).
- **Release preset (04 R12-2):** none exists yet, so the lint reports `release_preset=WAITING` (not a failure). When you add one:
  - Keep `permissions/custom_permissions` empty and every `permissions/*` false while Q2 is deferred.
  - Export to a path or name containing "release" (or an .aab), so the check picks it up automatically.
  - The APK/AAB check scans `build/qa/apk_head/`, `build/android/` and `build/release/` for AD_ID, BILLING, INTERNET and ACCESS_NETWORK_STATE in the binary manifest. These matter because the Mobile Ads SDK and Billing library add AD_ID and BILLING by manifest merge without any preset change.
- The mutation tests for this lint use a temp copy of export_presets.cfg (`-- --presets=<path>`). Your file was never edited.

# 2026-10-31 17:25 KST — QUEUED: 2 untracked Godot .uid files in your paths (06 did not commit them)
Godot 4.4+ says `.uid` files must be committed (https://godotengine.org/article/uid-changes-coming-to-godot-4-4/). Without them, UID references break on other clones and Godot falls back to paths with warnings. Your `.gitignore` already allows them. Audit: docs/services/GODOT_UID_AUDIT.md.
- `src/core/diag/flip_check.gd.uid`, `src/core/diag/wave_clear_probe.gd.uid`. Both scripts are tracked (22d99ea). Please add them to your next Publish-Task `-Paths`.
- No tracked file uses these UIDs yet, so nothing is broken today.
- Suggestion for everyone: list `<script>.gd.uid` next to `<script>.gd` in `-Paths`. The helper stages only the listed files, and that is how these were missed.
- FYI: `Save.buy_upgrade` (4d77225) is now covered by `tests/services/test_services_upgrade.gd`. It checks that there are no Services, ads, billing or receipt calls and that `progress.services` is unchanged after a real purchase. It passes. The mutation tests use temp copies of save.gd and app.gd; your files were not edited.

# 2026-10-31 ~17:50 KST — QUEUED, after 01 records Q4 (launcher name). No change now
- The build's launcher name is `Lane Defence` (export_presets.cfg `package/name`, project.godot `config/name`; the 07e97ca APK shows `application-label:'Lane Defence'` in every locale). The store and in-game title are now "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense". Please wait for 01's Q4 record before changing anything.
- When you change it, two things to check (06 did not verify either):
  1. Whether ko and en launcher names can differ with the prebuilt template (`application/config/name_localized`, or `package/name` only).
  2. That renaming `config/name` moves the desktop `user://` folder (Windows `%APPDATA%/Godot/app_userdata/<name>`). Desktop test saves and the services tests' `user://svc_*` dirs would start fresh. Android is not affected; its files dir is per package.
- After the change, 06's lint `launcher_label_note` will fail until STORE_LISTING_DRAFT §2b states the new label. That is intended: 06 updates the doc.

# 2026-10-31 ~18:05 KST — Q4 DECIDED (user 17:19): launcher name ko "빵집 기사단", en "Bakery Knights". FYI on how 06 checks your change
- **Expected after your change:** `aapt2 dump badging` shows the ko label `빵집 기사단`. The en label (or the default label, if there is no en entry) shows `Bakery Knights`. The in-game and store titles stay the full working title.
- **06 check:** `tests/services/test_services_android.gd` group `launcher_label` reads the real label of every APK in `build/qa/apk_head/`, `build/android/` and `build/release/`. Rules:
  - All labels still `Lane Defence` = WAITING (built before your change). This is not a failure.
  - Labels that match Q4 = VERIFIED.
  - Anything else fails: a typo, the full title, a missing ko entry, or a mix with `Lane Defence`.
- It also checks `export_presets.cfg` `package/name` (once it is no longer `Lane Defence`, it must be one of the two Q4 names) and `application/config/name_localized` ko/en (if you set it).
- The check was tested on four throwaway APKs built with aapt2 (OK, typo, full title, wrong ko). They were deleted afterwards. Today both existing APKs read `Lane Defence`, so the status is WAITING.
- Reminder from the earlier entry: renaming `config/name` moves desktop `user://`. Android is unaffected.
