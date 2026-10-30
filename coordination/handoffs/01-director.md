# 01-director handoff
Updated: 2026-10-31 06:55 +09:00
Status: M0 provisional design + data published. Waiting for user answer to Q1 (theme). Nothing here is user-approved.

## Read receipts
BRIEF.md, OWNERSHIP.md, DISPATCH.md, GIT_WORKFLOW.md (acknowledged: commit only own files via coordination/Publish-Task.ps1, Korean subject with [Design]/[Docs]/[Feat] tags, no add ./-A), coordinator-to-01-director.md (production/revenue update, atlas clarification, heartbeat/answer persistence, per-task push), 02-engine-to-01-director R1, docs/contracts/ENGINE.md v1.0, INTERFACES.md v1.0, 02-engine-to-03-art R1.
Last processed: decisions D1–D10 (all DEFAULT), requests coordinator-to-01 (3 sections), 02-engine-to-01 R1.

## For other roles
- Start here: docs/design/IMPLEMENTATION_BRIEF.md, docs/design/DATA_SCHEMA.md (★ = design keys 02 does not read yet).
- Data in contract layout: data/units/units.json, data/heroes/hero_captain.json, data/skills/*.json, data/rounds/r01..r10.json + order.json, data/economy.json, data/meta.json, data/game_config.json, data/text/ko.json/en.json.
- Requests sent: 01-director-to-02-engine R1, to-03-art R1, to-04-client R1.
- P0 = r01–r03 (melee/ranged/tank, worker, hero, slam, grunt/swarm/spitter).

## Validation (actual)
All 21 JSON files parse; all references resolve; ALL_OK=True (PowerShell). Not validated: engine load, balance (requested 02 headless bot sim r01–r03).

## User answers
None yet. Q1 open: theme A 빵집 기사단 (recommended) / B 도토리 숲 수비대 / C 등불 수호자.

## Next task (01)
1. On Q1 answer: write literal answer + interpretation to DECISIONS.md and here, update text/ko.json names, notify 02/03/04.
2. Then ask Q2 (business model M1/M2/M3, ECONOMY.md §4) — one question at a time.
3. Rebalance from 02 sim report. Commit own files via Publish-Task.ps1 and record SHA.
