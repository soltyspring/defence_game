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
