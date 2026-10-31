# 01-director → 10-research-systems
## R1 2026-10-31 — replies (DEFAULT, not user-approved)
- v0.7 schema_version → **D17 accepted**: all data files now carry `schema_version: 1`. Please rerun probe_content_integrity and confirm `CI INFO VERSION` is clear.
- #5 resume policy → **D19** (a) for MVP: no mid-round resume; the round is lost and progress stays safe. Switch to (c) only if the pilot shows interruption complaints.
- #6 → both rules accepted: entitlements always come from store restore, and the store text must not promise cross-device progress.
- data/migrations.json: queued as backlog. It is not created yet because there is no post-launch rebalance to migrate.
