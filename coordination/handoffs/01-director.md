# 01-director handoff
Updated: 2026-10-31 +09:00
Status: M0 design + data published (e42f809); release design review completed (see Git below). Waiting for user Q1 (theme). Nothing here is user-approved; all decisions D1–D10 are DEFAULT.

## Read receipts
BRIEF.md (06:24 version), OWNERSHIP.md, DISPATCH.md, GIT_WORKFLOW.md (acknowledged: own files only via coordination/Publish-Task.ps1, Korean subject with user tag convention), coordinator-to-01-director.md incl. "Dispatch R3", 02-engine-to-01-director R1, ENGINE.md v1.0, INTERFACES.md v1.0, docs/mobile/BUILD_PLAN.md (test harness tools/build/run_tests.ps1 noted).
Last processed: decisions D1–D10; requests coordinator-to-01 (sections incl. Dispatch R3), 02-engine-to-01 R1. No 02 integration/sim response yet.

## For other roles
- Start: docs/design/IMPLEMENTATION_BRIEF.md, DATA_SCHEMA.md (★ design keys), RELEASE_DESIGN_REVIEW.md (edge-case rules §3, acceptance criteria §8).
- Data (contract layout): data/units/units.json, heroes/hero_captain.json, skills/*.json, rounds/r01..r10.json + order.json, economy.json, meta.json, game_config.json, text/ko.json + en.json (60/60 parity).
- Requests: 01-director-to-02-engine R1 + R2 (reward semantics C1, skill gating P0, resolution rules, sim); to-03-art R1; to-04-client R1 + R2 (executable tests).

## Validation (actual)
Data parse + references + ko/en parity ALL_OK=True. Audit findings F1 (en.json missing 39 keys, fixed), F2 (stale worker timing doc, fixed), C1–C5 documented. Balance/perf: UNTESTED.

## User answers
None. Q1 open: A 빵집 기사단 (recommended) / B 도토리 숲 수비대 / C 등불 수호자.

## Next task (01)
1. On Q1 answer: record literal answer + interpretation + affected roles in DECISIONS.md and here; update text names; append requests to 02/03/04; publish.
2. Then ask Q2 business model (RELEASE_DESIGN_REVIEW §4) — one at a time.
3. Rebalance after 02 sim; decide B25 (Rally r04→r05).

## Git
- e42f8090f9aaaf8eae90041e8a6c2efb8982aaf5 "[Design] 초기 기획서, 데이터 스키마와 1~10라운드 임시 데이터 추가" → PUSHED origin/main.
- ec657bc70f5146629c1ff017f264cb574117d77f "[Fix] 영문 텍스트 누락 키 39개 보완" (data/text/en.json) → PUSHED origin/main. Validation: ko/en parity 60/60.
- abdb664e2bbda12edc4b7769d42c846bfac08c61 "[Docs] 출시 기준 기획 검토서와 데이터 감사 결과 추가" (9 files) → PUSHED origin/main.
- Note: Publish-Task.ps1 aborts silently if its output is piped/redirected (git fetch stderr under ErrorActionPreference=Stop). Call it without redirection.
