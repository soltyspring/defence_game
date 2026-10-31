
# Mandatory production/revenue update from user (2026-10-31)
The target is a commercially releasable mobile game, not merely a demo. Explicitly account for memory, CPU/GPU, frame pacing, battery/thermals, storage/download size, loading, low-end devices, save migration/corruption recovery and mobile lifecycle. 02/04 must jointly define measurable budgets and device tiers, object pooling/entity caps, texture/audio budgets and actual profiling evidence; provisional targets must be labelled provisional. 01 owns retention/economy/monetization design and backlog; ask user one monetization decision at a time after initial theme question. 04 owns Android release pipeline, signing kept out of source, privacy/data disclosures, ad/IAP adapter architecture, purchase restore and failure cases, consent requirements and release QA. Do not invent account credentials or claim production billing/ads are verified without real sandbox/device evidence. 03 owns atlas packing, texture dimensions/memory estimates and compressed import recommendations. First playable slice is an internal milestone only, not completion. Keep a release readiness checklist with tested/untested/blocked evidence. Release publication and paid vendor spending remain separate user actions. Codex will push back on unsupported done claims.

# User clarification: sprite sheets / texture atlases
User explicitly asks to bundle the numerous pixel images. 03 must implement real packed sprite sheets/texture atlases with a machine-readable region/frame manifest, grouped by character/combat FX/UI/biome as appropriate. Coordinate animation names, padding/extrusion, nearest filtering, frame pivots, maximum texture dimensions and import compression with 02. 02/04 consume the atlas manifest and load/unload by scene/biome rather than loading the entire catalogue. Quantify decompressed GPU texture memory as well as disk size; document mipmap choices, device limits and batching evidence. Avoid massive monolithic atlases that force unnecessary residency. Produce contact-sheet previews and validate no texture bleeding. This is required for release readiness, not an optional suggestion.

# Coordinator heartbeat and user answers
Codex now checks this chat/project every 2 minutes. Before each milestone and before returning to the user, reread coordination/requests/coordinator-to-<your-role>.md, docs/design/DECISIONS.md and other handoffs. Record last processed decision IDs and request IDs in your handoff, so delivery can be verified. 01: after every CLI user answer, save the literal answer (no secrets), interpretation, provisional/confirmed distinction and affected roles immediately. Notify affected roles through request files. Keep only one unanswered user question at a time. All roles: keep a clear Next task section so Codex can resume your specific session without overlap. Never claim that a dependency exists until you have read it.

# New mandatory user instruction: per-task GitHub push
Repository connection is ready: origin https://github.com/soltyspring/defence_game, main tracks origin/main. Read coordination/GIT_WORKFLOW.md BEFORE any Git mutations. Every verified task: commit/push your OWN files using coordination/Publish-Task.ps1 and report actual SHA/push result. Exact user convention: [Feat], [Fix], [Design], [!BREAKING CHANGE], [!HOTFIX], [Style], [Refactor], [Comment], [Docs], [Test], [Chore], [Rename], [Remove] followed by concise Korean subject. Never git add . or add -A; shared index operations serialized with helper lock. No force/reset/rebase/stash. Do not publish engine binaries, caches, local transcripts or secrets. 02: create public .gitignore; include atlas/import source appropriately. Acknowledge read/processed directive in your handoff. Existing user answers/design still apply.

## Dispatch R3 — resume coordination + publish verified foundations
User resumed automatic coordination and requires each completed task committed AND pushed. Current files include project.godot, shared contracts and core autoload scripts. At next safe milestone, reread GIT_WORKFLOW.md, run actual parser/import checks and publish the coherent verified engine foundation with Publish-Task.ps1 using exact [Feat]/[Chore]/[Docs] convention and explicit owned paths. Record SHA/push evidence. Continue playable battle implementation after the checkpoint. Inspect DECISIONS.md and director handoff before each milestone; resolve conflicting default entity caps by contract rather than silently diverging. Update stale handoff/status, communicate newly available interfaces to 04 and sprite/atlas requirements to 03. Preserve all other workers files and avoid committing engine binaries/export templates.

# Eight-worker expansion — authoritative ownership overrides
User authorizes FOUR additional Kiro workers (8 total) and uniform window layout. All remain claude-opus-5.5 + trust-all. Existing owners keep current tasks except narrow reserved paths below; coordinate at milestones, never silently edit foreign files.
05-audio: assets/audio/**, src/audio/**, tools/audio/**, docs/audio/**, own status/handoff/requests. These paths are EXCLUDED from 03-art ownership. Original SFX/music generation, audio manager and mixer contract. No UI/core changes; request bootstrap and settings integration from 02/04.
06-services: src/services/**, docs/services/**, tests/services/**, own status/handoff/requests. Services for monetization, purchase/ad mock adapters, analytics event contracts and release configuration boundaries. tests/services/** is EXCLUDED from 04-client ownership. No production SDK credentials, charges or unapproved products; commercial choices go to 01. Existing save/progression core remains 02; UI remains 04; economy data remains 01. Request cross-owner changes rather than duplicating systems.
07-qa: tests/acceptance/**, tools/qa/**, docs/verification/**, own status/handoff/requests. Independent integration acceptance, regressions, release verification and bug reports. tests/acceptance/** is EXCLUDED from 04-client ownership. No fixes in source/gameplay/UI: issue reproducible owner-targeted requests. 04 retains UI/export checks and build pipeline.
08-performance: tools/perf/**, tests/performance/**, docs/performance/**, own status/handoff/requests. Repeatable profiling/stress and CPU/RAM/GPU/thermal methodology. tests/performance/** is EXCLUDED from 04-client ownership. 02 owns runtime fixes; send measured findings to 02/03/04. Desktop results never substitute for actual phone claims.
Every role may read all files. Ownership above overrides broad prior assets/** and tests/** grants. No new worker asks the user directly: one question at a time through 01 only. Each completed verified task uses shared Publish-Task.ps1 and records SHA and push result. Avoid spawning competing Godot editors/imports; coordinate import/build lock with 02/04 and keep profiling output under local ignored directories.

## Dispatch R4 — quality, judge review, typography and secondary-monitor tests
Read coordination/QUALITY_REVIEW.md fully at next safe milestone. New direct user instructions include rigorous research, gongmojeon hostile rejection->fix->retest, strong Korean font/pixel visual verification and SECONDARY-monitor-only visible game tests. Implement the role-specific obligations there. Acknowledge read + actual actions/results in handoff. Use max effort for hard analysis when supported on next safe resume, no restart of active work solely for flags. Cross-owner issues go to owner; every verified fix/task commit AND push.

# Completion review gate (explicit user instruction)
After EVERY completed task inspect actual diff/commit, real test artifacts, regressions and downstream integrations. Report: changes; validation commands/results/artifacts; strongest rejection reasons/untested claims; owner fixes; SAME failing scenario retest; actual SHA/push; concrete next task. A push/parser/test count is not proof of correctness, fun, phone usability or release readiness. Docs alone do not close runtime defects. Update stale status/handoffs. P0/P1 blockers stay open until real acceptance evidence, no average score hides them. Codex directly dispatches the next correction/test to the completed CLI, verifies work actually starts, then advances implementation after verification; independent tasks may proceed across explicitly tracked dependencies.

C02: raw PNG filesystem fallback is dev-only, cannot certify APK atlas loads. Existing import-remap defect must be retested in an exported build without fallback before closing. Bot wins do not prove fun/Android performance. Update stale handoff with real evidence.

Window stability user override: read coordination/WINDOW_STABILITY.md. Never close/kill/recreate agent/terminal windows for next tasks or effort. Existing work must continue in its current window. New direct messages require proven live non-closing transport; request files stay QUEUED until acknowledged. No duplicate workers.

Latest user checkpoint/CPU instructions: read coordination/QUOTA_POLICY.md. At observed97% save current atomic work/handoff, no new task/model call, await user login. Local guard preserves per-role WIP branches without changing main/shared index. Do not close worker windows. Keep full required verification but avoid rerunning unchanged imports/tests and coordinate heavy Godot runs. No throttling or process termination.

# User update: 97% work stop and individual handoffs
At >=97% stop ongoing work at the earliest safe boundary and write one role-specific file coordination/handoffs/<role>.md containing current task, completed/unfinished work, exact next steps, session ID, actual validation, errors and commit/push state. Commit and push owned WIP safely (checkpoint branch if unverified). Stop issuing new work and await user login. Quota guard generates fallback handoff only if missing, explicitly marked coordinator snapshot, and preserves existing handoffs; it creates independent WIP branches and reports actual push results. Never claim a worker authored an unconfirmed handoff or that it stopped merely because a request file exists. On trigger, coordinator must actively verify each session and deliver stop/checkpoint instruction using a supported safe session mechanism; if busy sessions cannot be stopped and instructed without losing work, report specific limitation, preserve windows and save snapshots. No authentication automation.

## HISTORICAL QUOTA CHECKPOINT (previous account; superseded after new login)
Historical instruction only: do not stop for this old notice. On a NEW 97% trigger, stop current work at a safe boundary and write coordination/handoffs/02-engine.md with completed work, unfinished work, exact next steps, validation, errors, session ID and commit/push status; commit/push owned work where possible. Await account login.

## HISTORICAL QUOTA CHECKPOINT (previous account; superseded after new login)
Historical instruction only: do not stop for this old notice. On a NEW 97% trigger, stop current work at a safe boundary and write coordination/handoffs/02-engine.md with completed work, unfinished work, exact next steps, validation, errors, session ID and commit/push status; commit/push owned work where possible. Await account login.

## HISTORICAL QUOTA CHECKPOINT (previous account; superseded after new login)
Historical instruction only: do not stop for this old notice. On a NEW 97% trigger, stop current work at a safe boundary and write coordination/handoffs/02-engine.md with completed work, unfinished work, exact next steps, validation, errors, session ID and commit/push status; commit/push owned work where possible. Await account login.


## Coordinator typography correction 2026-10-31 08:12 KST
Investigate 04 typography QA finding: non-integer 2.5x causes uneven pixel text and sprites. Evaluate integer scaling plus mobile aspect ratio, touch and safe area tradeoffs. Implement only after coordinating with 04; provide evidence in same 2.5x case and request independent 07 visual check. Publish verified owned changes.
Please acknowledge reading; queued until confirmed.


## Coordinator priority 2026-10-31 08:52 KST
먼저 import 잠금을 잡고 Godot --import를 한 번 실행하세요. ui_main과 새 페이지 char_player_adv·char_enemy_adv·char_boss_warlord가 대상입니다. 이 한 번으로 03 A6, 04 아이콘 재검증, 09 R09-04-6(결과 화면 별 아이콘이 다른 그림으로 보임)이 함께 풀립니다. 이어서 정수 배율(scale_mode) 결정을 04와 맞추세요. 그다음 저장 결함 작업(QA-B004, R6 훅, R3 적용 기록)을 진행하세요. R3 합격 기준은 10의 probe_battle_uid_dedup.gd 결과 162/1입니다. 읽음 기록을 남기세요.


## USER DECISION 2026-10-31 09:03 KST (Q1 answered)
원문: "모두 고치고 A) 빵집 기사단 vs 곰팡이 군단이걸로" (사용자가 코디네이터 채팅에서 직접 답변)
해석: Q1 테마는 A안 '빵집 기사단 vs 곰팡이 군단'으로 확정(DECIDED by user). 아군은 빵집 기사단, 적은 곰팡이 군단. 또한 지금까지 보고된 결함을 모두 고치라는 지시.
영향: 01 기획 이름·세계관·텍스트, 03 아군/적/보스/배경/UI 그래픽 재테마, 04 UI 문구·타이틀·아이콘, 05 음악·효과음 음색, 02 데이터 ID는 테마 중립 유지(D1)로 코드 변경 최소, 07 재검증, 09 경쟁작 대비 정체성 점검, 06 스토어 문구, 08 텍스처 예산 재확인.
데이터 ID는 D1에 따라 그대로 두고 표시 이름·그래픽·소리만 바꾼다.



## Coordinator 2026-10-31 09:13 KST
06의 연동 게이트가 여전히 종료 코드 2입니다. project.godot에 Save 다음 줄로 Services="*res://src/services/services.gd" autoload를 등록해 주세요(06 SAVE_INTEGRATION_CONTRACT.md). 등록 후 tests/services/run_services_suites.ps1 종료 코드 0을 06과 함께 확인하세요. 남은 순서: 정수 배율(scale_mode) 적용, APK 출시용 프리셋(OFL 문서 포함, 개발용 코드 제외, arm64만), 05의 prepare_quit 호출(A7), QA-B003/B005/B006/B007.

## QUOTA CHECKPOINT
Stop current work at a safe boundary. Write coordination/handoffs/02-engine.md with completed work, unfinished work, exact next steps, validation, errors, session ID and commit/push status; commit/push owned work where possible. Await account login.
