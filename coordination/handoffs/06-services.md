# 06-services handoff
Updated: 2026-10-31 (M4 complete)
Status: M4 COMPLETE. **BLOCKER: 02 S1/S2 unanswered → the game does not register `Services` and does not persist service state. There is NO game-integration evidence.** M3 evidence = real `src/core/save.gd` in isolation. No real ads, billing, consent SDK or remote analytics; everything runs in `disabled` mode (verified D1–D6 every gate run). No monetization decision; none invented.
Session: same Kiro window, resumed after the 08:21–08:22 authExpiryRetry failure under the new login. Session ID not exposed to the agent. HISTORICAL QUOTA CHECKPOINT sections in coordinator-to-06-services.md are previous-account records; not acted on.

## Ownership (unchanged)
src/services/**, docs/services/**, tests/services/**, coordination/status/06-services.md, coordination/handoffs/06-services.md, coordination/requests/06-services-to-*.md.

## Resume check (this session)
- Work tree: clean for 06 paths at resume (M3 fully pushed: 5d61d0d, 078df2e, 1f6e57c). The failed 08:21 request had left nothing half-written.
- coordinator-to-06-services.md: 30 lines, latest = 3× HISTORICAL QUOTA CHECKPOINT (do not stop). No new 06 task beyond the user's M4 review.
- 02: no 02→06 reply; `Services` absent from project.godot and src/core. 02 handoff lists "06 S1–S3/S5 Services autoload … open". 02 DID ship S4 `battle_uid` (battle.gd:65/74/210).
- Requests to 06: 09-research-product, 10-research-systems (both handled in M3).

## Completed (M4)
- `src/services/services.gd`: `attach_save(save, events, options)`, `ensure_bound()` (rebinds when `Save.load_progress()` replaced progress; called every frame), auto-attach in `_ready` when it is the autoload `/root/Services` and `/root/Save` exists. So 02 S1 (one project.godot line) is enough; mode stays disabled.
- `tests/services/test_services_integration.gd`: game integration gate. Exit 0 = integrated + pass, 2 = BLOCKED, 1 = failure. Groups: disabled_mode (D1–D6), integration_contract (I1–I6), binding_failure_injection (R1, R2, R3, R6, R8, R9, R14, R15, P1), binding_process_death (R4, R5, R7 via child process), state_table_sync, hygiene (player's user://save.json(.bak) hash unchanged). `-- --simulate-integration` exercises the game-binding path with a test-added node; never counted as game evidence.
- `tests/services/integration_child.gd`: process-death child using the game autoloads.
- `tests/services/run_services_suites.ps1`: runs all 4 suites sequentially, OVERALL exit 0/2/1.
- `docs/services/SAVE_INTEGRATION_CONTRACT.md` (02 steps, gate, I1–I6, fault-injection methods, isolation), `docs/services/REWARD_STATE_TABLE.md` (R1–R16, P1–P6, D1–D6; doc-synced by the test), SERVICES.md v0.4 §7 blocker note.
- Requests: 02 M4 update (S1/S2 marked BLOCKING, one-line change, acceptance = runner exit 0), 07 M4 update (treat exit 2 as open blocker; accept rows only with binding=game and game_evidence=true).

## Validation evidence (actual)
- `pwsh -File tests/services/run_services_suites.ps1` → test_services exit 0 (502/0), test_services_m2 exit 0 (130/0), test_services_m3 exit 0 (161/0), test_services_integration exit 2 `verdict=BLOCKED_NOT_INTEGRATED passes=71 failures=0 blockers=4 binding=bridge_simulated`; OVERALL exit=2. Blockers: I1 autoload missing, I2 store not bound, I3 epoch unverifiable, I4 rebinding unverifiable. I5 NOT_REQUIRED_YET (01 enables nothing). I6 PASS (real battle_uid generator).
- Simulated run (`-- --simulate-integration`): exit 2, I2 PASS_SIMULATED, I3 PASS, I4 PASS (stale before frame: true, rebound after one `_process`), all R/P rows PASS with binding=services_node_simulated, game_evidence=false.
- Gate mutations (each exit 1, file hash restored): no per-frame rebind → I4 FAIL; disabled mode honouring 01 flags → D2 FAIL ×2; ledger written after sink → R8 FAIL ×4; table row renamed in doc → state_table_sync FAIL.
- Isolation: user://svc_int_test absent after runs; hygiene group PASS.
- Readback: after fetch, `git diff origin/main` on the committed paths is empty.

## Strongest reasons to reject / untested
- No game integration: the gate is BLOCKED by design until 02 registers the autoload. Until it exits 0, claim only "isolated save.gd + simulated binding".
- Auto-attach inside services.gd means 02 S1 also activates S2 behaviour; 02 may prefer explicit `attach_save`. Both are documented.
- Rebinding drops in-flight ad/purchase sessions (their grants would be refused as stale anyway). Ledger prevents duplicates.
- Desktop Windows only; mocks only; no grant sink exists in the game (S3).
- D6 reads a 02/04 file (export_presets.cfg); if they enable INTERNET the gate fails D6 by design.

## Git
- M1: 17623c1, 9c20763, b7fa3c0. M2: 0f84461, 708bdb0, 7c43ebd. M3: 5d61d0d, 078df2e, 1f6e57c. All PUSHED.
- M4 gate: 7fe59f926674961e1e7c872294ca6044009e04d0 `[Feat] 게임 Save 연동 게이트(차단 표시·실패 주입·프로세스 종료)와 보상 중복/유실 상태표, Services 자동 연결·재바인딩 추가` (6 files) → PUSHED origin/main (ls-remote = 7fe59f9…).
- M4 docs/requests/handoff: next commit; SHA in status after push.

## Next task (06)
1. When 02 adds the autoload line: run `pwsh -File tests/services/run_services_suites.ps1`; require OVERALL exit 0 and every R/P row `binding=game`, then update SAVE_INTEGRATION_CONTRACT.md status and REWARD_STATE_TABLE.md "Game binding" column with the evidence.
2. If the gate fails after integration: fix 06-side causes; route 02-side causes with the failing row ID.
3. Otherwise idle on this blocker; no new monetization work without 01 decisions.
