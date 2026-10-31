# Hostile review: strongest reasons to reject this game today (owner: 07-qa)
Version 1, 2026-10-31 08:15 +09:00. Method adapted from the gongmojeon skill (§6 탈락 심사): build the strongest rejection case first, classify each attack, attach evidence, owner, fix and the check that will re-test the **same** scenario. This is a mobile game, not a contest. There is no external jury, score or weighting here; the severity scale is internal (BUG_REGISTER.md). Nothing below claims user research, playtests with humans or commercial outcomes.

## Evidence classes (never mixed)
- **E** executed by 07: acceptance run, with run ID and check ID. Clean-HEAD runs are `head-<sha>`.
- **O** observed in a real rendered frame (file named). 07 has not opened any game window itself yet (secondary-monitor launcher pending, QA-R4).
- **I** inference from code or data reading, not executed.
- **H** hypothesis about players; untestable until humans play (D11).

## Attack categories
A. release blocker (data loss, crash, cannot progress) · B. contract/logic contradiction · C. missing evidence for a core claim · D. presentation/completeness.

## 1. Rejection reasons, strongest first
| # | Cat | Attack | Evidence | Owner → fix | Same-scenario re-test |
|---|---|---|---|---|---|
| R1 | A | **A player can lose all progress silently.** After one corrupt-save recovery, the next save deletes the only good backup; a kill during that save restores fresh progress with no notice. | E: TP-02a/TP-02b FAIL at head-462991a (QA-B004 P1). Also TP-14b: save failures are never shown (QA-B005). | 02: validate before rotating, read verified .tmp, emit save_failed | `run_acceptance.ps1 -Head -Only faults` TP-02a/b, TP-14b PASS |
| R2 | A | **No phone has run this game under 07 verification.** Every "PASS" in RELEASE_EVIDENCE.md is desktop headless. 02 has emulator screenshots; an emulator is not a low-end phone (GPU, thermals, touch latency, notch, back gesture). | E: PLAT-03 NOT_TESTED; `adb devices` shows only `emulator-5580` in every run. O: docs/architecture/evidence/android_emu_*.png are emulator frames. | 04: install on a physical low-tier device; 08: device profile | adb serial of a physical device in env.txt + FLOW-equivalent manual script |
| R3 | B | **Android back is broken on two screens.** One press on result skips round select; one press on round select opens "quit game?". | E: FLOW-23, FLOW-23B FAIL (QA-B001). Mechanism matched against Godot 4.7.2 `Window::_propagate_window_notification`. | 04 (or 02 latch) | FLOW-23/23B PASS |
| R4 | D | **The game is silent.** 31 original audio files and a manager exist but nothing plays. | E: AUD-01 PASS, AUD-02 NOT_IMPLEMENTED (no `Audio` autoload). | 02 wiring, 05 bridge | AUD-02 PASS then AUD-03 cue checks |
| R5 | B | **Raw ids reach the player.** Mid-battle "counterattack" toast is shown as the literal key. | E: FLOW-04B, DATA-13/14 FAIL (QA-B008). | 01 text keys | FLOW-04B PASS |
| R6 | C | **"Strategic choices matter" is unproven.** The only balance evidence is a scripted bot: the "competent" bot is not better than the casual one (r01 17/20 both, r03 11/20 vs 10/20), and the competent bot wins *slower*. A bot that cannot exploit the system says nothing about whether players can; a bot that is no better when smarter suggests the decisions it models barely change outcomes. | E: probe_winrate.gd 20 seeds (QA-O001). I: QUALITY_BAR §2 already suspects "buy workers, spam the cheap unit" dominance. | 01/02: paired policy sims with fixed decision rules (01 R3); 07 re-runs one policy/seed | Independent re-run matches 02 numbers within stated tolerance |
| R7 | C | **Difficulty curve has a cliff at r03** (bot win rate drops from 20/20 at r02 to ~10/20), and 01's uncommitted fix (enemy AI disabled) made r01/r02 unlosable for an idle player. Either the curve or the fix is wrong; neither is validated. | E: QA-O001; QA-W001 (workspace run 20261031-074155, R1/R2-LOSS FAIL with WIP data, PASS at HEAD). | 01 | `-Only sim` with the final data: R*-LOSS PASS and win-rate table re-run |
| R8 | D | **The battlefield is a thin strip; the enemy is invisible.** In the emulator r01 frame (1600×720) roughly the top 75% is sky/mountains; the lane is a band near y≈550–590 and units are ~60 px tall at 1600 px wide. Nothing on screen shows where enemies or the enemy base are (no minimap/edge indicator) while the camera follows the hero. | O: android_emu_battle_r01_20261031.png. H: on a 5.5" phone this reduces readability and situational awareness. | 03/04: lane framing, off-screen enemy indicator; 01 decides | Rendered frames at small/narrow/wide phones via secondary-monitor launcher; QUALITY_BAR claim 4 check |
| R9 | D | **Visible background seams.** Thin white vertical lines in the far/mid layers. | O: same frame (x≈520 and x≈707). Already reported by another role (commit 22cd2bb, rounding seam to 02). | 02 | Same camera position frame without lines |
| R10 | D | **Placeholder identity.** Working title "Lane Defence", flat-band menu background, theme Q1 still pending. A store reviewer or player sees no distinct identity yet. | O: android_emu_menu_20261031.png. DECISIONS Q1 PENDING. | 01 (user decision), 03 | After Q1: menu frame review |
| R11 | B | **Result screen shows a hidden pause menu underneath.** | E: FLOW-13B FAIL (QA-B002). | 04 | FLOW-13B PASS |
| R12 | A/B | **Save accepts anything with a valid checksum.** Wrong types cause a script error on the next win (QA-B003); 1e12 unlocked rounds and 10-digit coins are kept (QA-B007); a newer-version save is downgraded (QA-B006). The checksum is unkeyed sha256, so it detects corruption, not tampering (I). | E: SAVE-05 FAIL, SAVE-06 BLOCKED, TP-13a FAIL, TP-06 FAIL. | 02 | SAVE-05/06, TP-13a, TP-06 PASS |

## 2. What would make me withdraw a rejection
- R1/R12: the listed checks pass on a clean HEAD run, and TP-01 still passes.
- R2: a physical-device session with adb serial, screen recording or captures, and the same flow (start → deploy → background → resume → win → retry) completed.
- R6/R7: a policy comparison where at least one meaningful decision (e.g. worker timing or unit mix) changes the win rate by more than the seed-to-seed spread, using rules fixed before running. If no such decision exists, the claim must be dropped, not reworded.
- R8: framed screenshots at 16:9 and 20:9 where friend/enemy/health are distinguishable at the logical size of a 5.5" phone, plus an answer to "where is the enemy?" visible on screen.

## 3. What is already strong (E only; does not offset any item above)
First three rounds are winnable and losable at HEAD with deterministic seeds; touch, multi-touch hold-and-tap, background/resume pause, safe-area layouts across 16:9–21:9 and 4:3, atlas residency/release, monetization disabled in every layer, 06 service suites green (run 20261031-080846). These are necessary conditions, not reasons a player would choose this game.

## 3a. First 3 minutes after retheme (2026-10-31 16:10)
See [FIRST_3MIN_REVIEW.md](FIRST_3MIN_REVIEW.md): J1 cannot see the fight / tell sides apart (03, cc 04/02), J2 r01 has no risk (01), J3 worker vs soldier card indistinguishable and resource unnamed (04, cc 01). Visual evidence: [VISUAL_CHECKS.md](VISUAL_CHECKS.md).

## 3b. Method additions
Evidence staleness and vertical-slice gate from the external reference: [EXTERNAL_REFERENCE_REVIEW.md](EXTERNAL_REFERENCE_REVIEW.md) (A2: emulator frames used in R8–R10 predate the font/UI commits; A4: slice gate is NOT PROCEED, Q4 = NO because of QA-B004).

## 4. Not reviewed yet (gaps, not passes)
Rendered Hangul text (tofu/clipping), colour-blind readability, peak-crowd frames (r08), rounds r04–r10 rules, reward edge cases (double reward on re-entry, mid-battle retry), audio mix in context, low-end device performance (08 owns), store/privacy disclosures (04).

## 5. Re-test log
| Date | Item | Result |
|---|---|---|
| 2026-10-31 08:08 | QA-B001/B002/B003 same scenarios at head-462991a | still FAIL (no fix claimed yet) |
| 2026-10-31 08:52 | all 12 committed FAILs at HEAD e9dfaa4 | still FAIL; R4 partly withdrawn: AUD-02 PASS (Audio autoload wired), AUD-03 audible behaviour unverified |
| 2026-10-31 09:14 | HEAD 5426645 (run 20261031-091441) | R1 withdrawn (QA-B004/B005 verified), R3 withdrawn (B001), R11 withdrawn (B002), R12 withdrawn for types/clamp/downgrade (B003/B006/B007; checksum still unkeyed). R5 partly: FLOW-04B PASS, DATA-13/14 FAIL. New theme-era items: QA-B009/B010 label clipping, QA-B011 CVD colour proxy |
| 2026-10-31 15:40 | HEAD 2884231 (run 20261031-153757) | R7 idle-loss part withdrawn (D18 committed, R1/R2-LOSS PASS). R5: only 4 save/lock toast keys left. QA-B011 shifted to siege vs brute/overlord. Theme rename not yet committed |
| 2026-10-31 15:50 | HEAD abe2303 (run 20261031-154903) | R5 withdrawn (QA-B008 verified). R10 partly withdrawn: theme A names committed (art retheme pending). QA-B009/B010 verified. Open: QA-B011 colour proxy only |
| 2026-10-31 16:30 | HEAD 3b2d830 (run 20261031-162034) + rendered C3/C4 | 0 automated FAIL. QA-B011 verified (colour proxy + CVD frame). New P3: QA-B012 damage numbers, QA-B013 HP bar colours under CVD. J1 partly answered: enemies now distinct in hue; framing/biome still open |
