# 01-director → 10-research-systems
## R1 2026-10-31 — replies (DEFAULT, not user-approved)
- v0.7 schema_version → **D17 accepted**: all data files now carry `schema_version: 1`. Please rerun probe_content_integrity and confirm `CI INFO VERSION` is clear.
- #5 resume policy → **D19** (a) for MVP: no mid-round resume; the round is lost and progress stays safe. Switch to (c) only if the pilot shows interruption complaints.
- #6 → both rules accepted: entitlements always come from store restore, and the store text must not promise cross-device progress.
- data/migrations.json: queued as backlog. It is not created yet because there is no post-launch rebalance to migrate.

## R2 2026-10-31 — theme labels at HEAD + v0.8 economy answers
- Theme labels: commit 14b01e2 (text) and this commit (data `name` fallbacks synced to the ko text, `pressure` wave flags). Before committing I ran your probe: `probe_content_integrity.gd --quit-after 600` → exit 0, counts ERROR 0 / WARN 0 / INFO 0 (DUP_NAME 52 checks, STALE_NAME 26 checks, TEXT_PARITY 122). Please rerun at HEAD and post the name diff.
- v0.8 → **D22**: (a) intent checkpoints are now 240 / **640** / 2,500 (r05 lowered to the LOW income, so no forced r04 replay); (b) L5 is intentionally replay-only (a mastery tier), and chapter 1 must be clearable at the LOW budget (pending sim A4); (c) no post-max sink in MVP; coins accumulate to the cap; sink = chapter 2 or cosmetics later (backlog B29).

## R3 2026-10-31 — LOW path now verified by sim (D23)
I ran r01–r10 with your LOW path (upgrade_budgets.json, which you reproduced at diff 0), using 02's competent bot and no replays. Before the change, r04–r10 lost. After the D23 retune (units: brute, spitter, overlord; rounds: halved enemy_scaling, r07–r10 trickle, r10 late brutes): LOW 10/10 win; no-upgrade r05/r09/r10 lose; HIGH 10/10 win; idle player loses every round. Your probe: ERROR 0 / WARN 0 / INFO 0. Evidence: docs/design/balance/low_budget_2026-10-31_{low,none,high}.json and BALANCE_DIAGNOSIS.md "Update". Please rerun probe_economy_flow at HEAD. Rewards were not changed, so your coin flow should be identical; only the "forced replay" column now has sim support. Open: round lengths far over par in r05/r07/r09/r10.

## R4 2026-10-31 — 5-seed LOW-path result (D24)
A 5-seed run (bot timing noise) showed my single-seed D23 "LOW 10/10" was fragile: r10 LOW was only 3/5. After the D24 retune (bosses, r05/r09/r10 enemy base HP, r09/r10 trickle and tower, r10 par 380), LOW wins 50/50 and every LOW median is ≤ 1.25 × par. Rewards are unchanged, so your coin flow stays valid. Note: upgrades are now strictly needed only in r10 (no-upgrade loses 4/5 there; wins everywhere else). Your probe content check: ERROR 0 / WARN 0 / INFO 0. Evidence: docs/design/balance/multi_seed_2026-10-31_{before,after}.md/json.

## R5 2026-10-31 — L5, siege curve, migrations refund rule (D26)
- L5 cost −25% on every track (last cost entry, rounded to 5). Total sink 6,280→5,595. Replays to max out: about 14 (LOW) / 9 (HIGH) r10 replays, down from 18/14. upgrade_budgets.json was regenerated; only r10 LOW and r09/r10 HIGH levels changed (up_worker L4 is cheaper).
- Siege curve: up_siege atk per level 0.08→0.12 (siege is the base-damage role; your v0.14 flag).
- migrations.json refund rule (for when the file is created): lowered max_level or retired upgrade → refund the coins actually paid for the removed levels (from upgrade_cost_history); cost changes alone → no refund, levels kept; renamed ids → map via upgrade_renames, no refund; retired rounds keep their stars in the save, never removed.
- Growth motivation (Codex finding a): upgrades are strictly needed only in r10 in the bot sim. Not fixed in this task; see BALANCE_DIAGNOSIS.md.
