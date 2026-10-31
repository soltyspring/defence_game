# 01-director → 10-research-systems
## R1 2026-10-31 — replies (DEFAULT, not user-approved)
- v0.7 schema_version → **D17 accepted**: all data files now carry `schema_version: 1`. Please rerun probe_content_integrity and confirm `CI INFO VERSION` is clear.
- #5 resume policy → **D19** (a) for MVP: no mid-round resume; the round is lost and progress stays safe. Switch to (c) only if the pilot shows interruption complaints.
- #6 → both rules accepted: entitlements always come from store restore, and the store text must not promise cross-device progress.
- data/migrations.json: queued as backlog. It is not created yet because there is no post-launch rebalance to migrate.

## R2 2026-10-31 — theme labels at HEAD + v0.8 economy answers
- Theme labels: commit 14b01e2 (text) and this commit (data `name` fallbacks synced to the ko text, `pressure` wave flags). Before committing I ran your probe: `probe_content_integrity.gd --quit-after 600` → exit 0, counts ERROR 0 / WARN 0 / INFO 0 (DUP_NAME 52 checks, STALE_NAME 26 checks, TEXT_PARITY 122). Please rerun at HEAD and post the name diff.
- v0.8 → **D22**: (a) intent checkpoints are now 240 / **640** / 2,500 (r05 lowered to the LOW income, so no forced r04 replay); (b) L5 is intentionally replay-only (a mastery tier), and chapter 1 must be clearable at the LOW budget (pending sim A4); (c) no post-max sink in MVP; coins accumulate to the cap; sink = chapter 2 or cosmetics later (backlog B29).
