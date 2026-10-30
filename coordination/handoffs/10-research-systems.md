# 10-research-systems handoff
Updated: 2026-10-31 07:30 KST
Owned: docs/research/systems/**, coordination/status|handoffs/10-research-systems.md, coordination/requests/10-research-systems-to-*.md
Git protocol (GIT_WORKFLOW.md) read and acknowledged: Publish-Task.ps1 only, explicit owned paths, no redirection.
Processed requests: coordinator-to-10-research-systems.md (research expansion block). Decisions read: DECISIONS.md D1–D12, Q1 PENDING (not touched, no user questions asked).

## Done (v0.1)
docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md: evidence classes; title ambiguity table (7 Play apps named 궁수/아처 키우기, GameDuo com.GameDuo.MadArcher kept as PROVISIONAL candidate); dated success metrics; online feature evidence/UNKNOWN matrix (DB vendor/schema UNKNOWN for both); developer statements (PvP churn, co-op pivot, 30 launches/yr → 1–2 survive); 2026-04 Random Dice GO first-instance ruling (unfair competition, not copyright) as anti-cloning lesson; per-area designs; save v2 JSON + Save.transact contract; optional PostgreSQL schema + idempotent grant; staged cost table L0–L5; threat/test table TP-01..14; hypotheses with rejection reasons.
Key findings for owners (code reading, unexecuted): SV-1 double-fault total save loss path in save.gd rotation after .bak recovery (P1 candidate); SV-2 newer-version save overwritten; SV-3 no battle_uid idempotency.
Limitations: no hands-on play; review sample = 3 en reviews shown by Play; screenshots viewed locally then deleted, not committed; superfast article date unknown; AdMob case-study date from search metadata.

## Requests issued
02 (R1–R7), 07 (TP acceptance), 06 (TP-08 policy, retention limitation), 04 (user_data_backup/allow + bmgr test), 01 (title note, migrations.json, defaults).

## Commit
(see below after publish)

## Next task
v0.2: field-level content-table spec cross-check vs data/*.json, Korean-locale review sampling, test skeleton specs for 07. Stop at 97% quota.
Outstanding questions: none.
