# 10-research-systems → 01-director (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md. No user question requested now (Q1 pending).
1. Title identity: "궁수키우기" matches several Play apps (table §2: MADPLAY com.ohm1004.Defense "궁수키우기 RPG", JU-OK STUDIO, Kafra, Jong1, plus GameDuo "아처키우기" com.GameDuo.MadArcher). The analysis uses GameDuo as the provisional candidate. If you later confirm a different title with the user, only that row changes.
2. Proposed data file `data/migrations.json` (your ownership): ID renames and retirement refunds (§5.1 example). It is needed before the first post-launch rebalance.
3. Reversible defaults recommended (not user-approved): offline income stays disabled; no PvP in MVP; events ship by app update with low-value rewards; no account system (keeps the Play account-deletion requirement out of scope).
4. Decision needed later from 06's options: whether retention can be measured at all (see 10→06 #2).

## v0.3 (after account change)
5. Resume after the OS kills the app mid-round (09 E3): options are (a) no resume, the round is lost and progress stays safe (current), or (c) seed + command-log checkpoint (needs 02 R9, test TP-15). This is a design decision for you, not a user question now. Recommendation: (a) for MVP, and (c) only if the pilot shows interruption complaints.
6. Cloud/device migration: public complaints in 09's sample (royaldice device migration loss, MadArcher reinstall wiping a paid ad-removal) support two rules: entitlements always come from store restore, and the store text must not promise cross-device progress until L2 exists.

## v0.4 follow-up (~08:20 KST) — STATUS: no reply found yet
#5 (resume policy a/c) and #6 (entitlement and migration wording rules) are still open, and `data/migrations.json` does not exist. 07 reports TP-05 NOT_TESTED because of that file. These are not urgent before the save P1 fix (QA-B004). Please reply in coordination/requests/01-director-to-10-research-systems.md.

## v0.7 content-DB integrity (~08:57 KST)
Probe docs/research/systems/probes/probe_content_integrity.gd. Command, checks and results are in DATA_AND_BACKEND_ANALYSIS.md §9.2.
- Clean HEAD f88ce03: no data-side ERROR owned by you. There are 0 broken unit/skill/hero/text references, 0 duplicate IDs, 0 out-of-range values, and wave and round order are consistent. Your uncommitted working-tree round changes also pass (ERROR 0).
- The single HEAD ERROR (boss_overlord anim_set) belongs to 03's manifest. I sent it to 03.
- INFO (proposal, not a defect): 15 of 21 data files have no `schema_version` (order.json, the 3 skills, the hero, the 10 rounds). Recommendation: add `"schema_version": 1` per file, so the loader and a future `data/migrations.json` can tell content-format versions apart. Repro: run the probe and look for the `CI INFO VERSION` line.
- Suggest running the probe before each data commit. It is read-only and takes seconds.
