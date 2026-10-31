# 02-engine handoff
Updated: 2026-10-31 17:47 +09:00
Status: ACTIVE — paused for 08's quiet measurement window 18:00–18:30 KST (no Godot/editor/emulator runs by 02, no source edits in the shared tree in that window).
Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL QUOTA CHECKPOINT notices are previous-account records; not acted on.

## User decisions
Q1 theme A "빵집 기사단 vs 곰팡이 군단" (data IDs unchanged). Q3 work title "빵집 기사단: 곰팡이 디펜스" (store name after KIPRIS). Q4 (17:19 KST): home-screen name ko "빵집 기사단", en "Bakery Knights"; in-game/store titles keep the full work title. Q2 monetization ON HOLD (no paid currency/ad-reward paths).

## This round
1. Q4 (4b5926d): `application/config/name_localized = {"en": "Bakery Knights", "ko": "빵집 기사단"}`, `package/name = "Bakery Knights"`. `config/name` kept "Lane Defence" so the desktop user:// folder (app_userdata/Lane Defence) does not move (Godot docs). Package ID unchanged. APK rebuilt 17:37 under the import lock: aapt2 default/en 'Bakery Knights', ko '빵집 기사단'. 06 test_services_android: launcher_label=VERIFIED, 189/0. Evidence: docs/architecture/ANDROID_BUILD.md A16. Known side effect: desktop window title still "Lane Defence".
2. 10 F1 (4b5926d): after a failed write, `Save.last_failure_uncertain` is computed from disk (main unreadable/missing + valid .tmp = next load adopts it) → buy_upgrade `save_uncertain`; `save_failed` now always means disk unchanged. BattleResult.save_uncertain for record_result. 10 probe: C1–C5 and C5b–C13 PASS; C6 after_tmp_write/after_recovery = save_uncertain, disk 440/L2.
Validation 17:39–17:41: selftest PASS (70 scripts; report path still app_userdata/Lane Defence).

## Commits (PUSHED, origin/main verified)
… 4d77225, 09508b1, 7fc45f5, 4b5926d (Q4 + F1). This handoff: committed after.

## Next (after 18:30)
1. 10 R5 content_version (minimal contract in 10's v0.15): Content computes `content_version = "c1-" + sha256(sorted data/**/*.json)[:12]`; Save writes it and `migrations_applied`; on mismatch in ONE atomic save: apply data/migrations.json renames (01 owns the file), clamp upgrades to max_level, refund per 01's rule (unknown → 0 + logged), recompute unlocks id-based (order[i] unlocked iff i==0 or stars has order[i] or order[i-1]); roll back on failed write. Needs from 01: refund rule / cost history and migrations.json schema. Acceptance: 10's run_content_migration.ps1 M1/M2/M4/M5b.
2. 07/06/10 re-verify on 4b5926d (requests written). 04 to rebuild build/qa/apk_head (still OLD label).
3. 08 remaining H3/H4/H8/H9–H13, P4, P5; QA-J1 camera framing with 04; 01 decisions (D16 vs r01 data, D7 caps text, 900 s timer); 05 A8; OS close → quit_game; 04 R12 release preset.
