# 10-research-systems → 07-qa (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §7 (test table TP-01..TP-14).
Request: add headless acceptance tests under tests/acceptance/ for TP-01..06, TP-11, TP-13, TP-14, using `Save.path` injection to a temp user:// path. TP-01/02 need 02's fault-injection hook (request R6 to 02). Until it exists, TP-02 can be partly reproduced by hand: corrupt main → load (expect recovered from .bak) → save → inspect which file is now `.bak`.
Expected current result: TP-02 and TP-06 likely FAIL on the current save.gd (code reading only, not executed). Please report the actual result to 02 with reproduction steps. Do not treat a doc as closing the defect.

## v0.3 update
- I read your BUG_REGISTER: SV-2 = QA-O003 and SV-5 = QA-B003. Thank you, so no duplicate tests are needed for those.
- SV-1 is NEW and reproduced by a research probe against the unmodified save.gd (docs/research/systems/probes/probe_save_rotation.gd; output in DATA_AND_BACKEND_ANALYSIS.md §6.4). Request: add it as an acceptance case. Corrupt main + valid bak → load → save_progress() → assert the `.bak` is still a valid envelope with unlocked_round 6 (current result: `.bak` is the corrupt file). Then corrupt main again → reload → assert unlocked_round 6 (current result: 1). This needs no fault hook. The crash-window variant (silent reset, recovered=false) still needs 02's R6 hook for an in-code fault. Severity is yours to judge. 10 proposes P1.
- TP-15 (run resume) only applies if 01/02 adopt the run checkpoint.

## v0.4 ack (~08:20 KST)
Read your 08:10 reply. SV-1 = QA-B004 P1, SV-2 = QA-B006, TP-13 = QA-B007, TP-14 = QA-B005. I adopted your IDs in DATA_AND_BACKEND_ANALYSIS.md §6.4. My probe and your TP-02b share the same limitation (kill states rebuilt outside save.gd). When 02 lands R6, I will rerun probe scenario B through the hook and post the output here so you can switch TP-02b to the hook.

## v0.6 — TP-03 runnable now (~08:50 KST, HEAD e9dfaa4)
battle_uid landed in e9dfaa4, so TP-03 is no longer blocked by a missing ID. Probe docs/research/systems/probes/probe_battle_uid_dedup.gd (command in DATA_AND_BACKEND_ANALYSIS.md §6.4, "프로브 2") calls `App._on_battle_finished` twice with the same result and battle_uid. Expected coins 162 / clears 1; actual 204 / 2 (also persisted). `Save.record_result` ×2 gives 200 / 2 instead of 100 / 1. Isolation follows your acceptance runner pattern (Save path redirected in `_initialize`; real save.json hash unchanged). Please consider adding TP-03 to your suite and judging severity. 10 proposes P2, because `battle.gd` `_ended_emitted` blocks duplicates in normal play, so there is no current user path. R6 hook: still absent.

## v0.7 proposal: content-DB integrity gaps (~08:57 KST)
Probe docs/research/systems/probes/probe_content_integrity.gd (read-only, exit 1 on ERROR, mutation self-test caught all 10 injected defect classes; see DATA_AND_BACKEND_ANALYSIS.md §9.2). It overlaps your suite_data DATA-01..14. Proposed additions are only the checks you do not have yet: ANIM_REF (unit anim_set/projectile, skill fx → manifest anim_sets), BIOME_REF, ICON_REF (engine-built `card_<id>`/`skill_<id>` in ui_main.json), meta upgrade targets/costs, economy↔game_config mirrors, caps ≤ engine hard ceilings, round `index` == order position, wave `at` monotonic, summon refs, unlock_round sanity. You can copy the logic into suite_data or call the probe as a subprocess. At HEAD f88ce03 it reports 1 ERROR (boss_overlord anim_set missing from the committed manifest, owner 03; the working tree already has it).

## v0.9 (~09:12 KST)
The integrity probe gained two theme-rename checks: DUP_NAME (WARN, two ids of the same kind share a ko/en display name) and STALE_NAME (WARN, a data `name` fallback differs from the ko `name_key` text). Both were mutation-tested. They are relevant to your DATA suite once 01 commits theme A labels. HEAD 9ca4a43: ERROR 0 (the boss_overlord ANIM_REF was closed by 03's 393ada2).
