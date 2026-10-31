# Hostile review of the first 3 minutes after the theme A retheme (owner: 07-qa)
2026-10-31 16:10 +09:00. Build: clean committed HEAD 0590e7a, captured on the secondary monitor (VISUAL_CHECKS.md). Viewpoint: a demanding reviewer who installs the game, plays r01 for three minutes and decides whether to keep it. No human played; the "player" here is the 02 scripted bot (casual policy) plus 07 reading the real rendered frames. Evidence classes: **E** executed/measured, **O** observed in a rendered HEAD frame, **H** hypothesis about players (D11: not testable without a pilot).

## J1 — "I can't see the fight or tell who is who" (owner 03, cc 04/02)
- O: in `evidence/visual-0590e7a/ko_2x_4_r01_t00.png` and `ko_2x_5_r01_t60.png` the lane (ground line ≈ y 560–590 of 720) and units (≈ 30–60 px of 720) occupy a thin band; roughly the top 75% of the frame is sky, mountains and green hills. The biome is still the generic meadow; nothing in the background says bakery vs mould (theme A).
- O: at t = 60 s, four bread soldiers and the hero are on screen in yellow/orange; the only enemy is a grey shape cut off at the right edge (x ≈ 1255). The enemy base is not on screen during the first 60 s in either frame; its state is only the red bar (800/800).
- E: TH-COL-PROTAN / DEUTAN FAIL at HEAD (QA-B011): siege vs e_brute ΔE 1.96 (protan), siege vs boss_overlord ΔE 1.75 (deutan).
- H: on a 5.5" phone the decision "send units now?" depends on seeing the next enemy group; with the camera on the hero, the player learns about enemies only from text.
- Requested fix: bakery/mould biome layers (03), an off-screen enemy indicator or lead camera framing that shows the nearest enemy group (04/02), keep QA-B011 work.
- Re-test: same capture command at the new HEAD; pass = at t ≈ 30/60 s an enemy or an off-screen enemy indicator is visible in frame, the background reads as the theme world, TH-COL-* PASS.

## J2 — "r01 has no risk; I win 3 stars without being hit" (owner 01)
- E (capture runs, 4 of 4, casual bot): r01 won at 105–106 s, **3 stars**, player base **1500/1500 untouched** at 60 s and at the end; header in `ko_2x_6_result.png` shows "웨이브 3/6": the round ended before waves 4–6 (t = 160/210/260) ever spawned. The D18 late waves only reach an idle player.
- E: probe_winrate (20 seeds, HEAD e9dfaa4): r01 casual 18/20.
- H: a first round that cannot hurt the player teaches nothing about defending the base (half of the core loop) and the first result screen gives the maximum rating for minimal effort, so stars lose meaning from round 1.
- Requested fix: decide the r01 intent explicitly (tutorial round vs real challenge). If real: at least one enemy group reaches the player base before ~90 s for a casual policy, and 3 stars not reachable on a first casual run. If tutorial: label it so and make r02 the first real test. Record the rule in ROUNDS.md and the D16 pilot rules.
- Re-test: `capture_visual.gd` r01 report `r01_at_60s.player_base`, `r01_end`, plus `probe_winrate.gd --seeds=20`; pass = the rule 01 writes down, checked by numbers, not by wording.

## J3 — "Which card makes soldiers and which makes money?" (owner 04, cc 01/03)
- O: in `ko_2x_4_r01_t00.png` the only two buttons in the bottom row are **제빵사 40** (worker: income) and **식빵병 30** (soldier). Same frame, same size, same layout; the only difference is a small "0" badge on the worker. In `ko_2x_5_r01_t60.png` the worker shows **88** and a "3" badge, the soldier **30**: the worker's cost rising is the only cue that it is different.
- O: the resource is shown as a bread icon and "+8.5/s"; the word for it ("반죽", per `tut_buy_worker` = "제빵사를 고용하면 반죽이 더 빨리 찹니다.") appears nowhere in the HUD, so the tutorial refers to a name the player has not been shown.
- H: in the first minute a new player either spams the worker (no army) or never buys one (slow economy); both are invisible mistakes.
- Requested fix: distinct worker button treatment (different frame/colour/position or an income "+x/s" sub-label instead of a soldier-style cost), and the resource name next to the resource counter or in the first tutorial line (01 copy).
- Re-test: rendered HEAD HUD frame ko+en at 1×; pass = worker and soldier buttons differ by more than a badge, and the word used in `tut_buy_worker` is visible in the HUD.

## Not claimed (evidence too weak in this run)
- Message stacking and tutorial-hint timing: the t30/t60 frames were produced by stepping the simulation 30 s within one frame, so all toasts/banners appear together. Not reported as a defect.
- "Fun", retention and difficulty for humans: D11, needs the 5-player pilot.

## Re-judgement with numbers, HEAD 68866e9 (2026-10-31 16:50)
| Item | Metric (how measured) | Value | Verdict |
|---|---|---|---|
| J1 framing | screen area covered by unit/hero/base sprites, union on a 2-px logical grid, r01 casual bot, real time, sampled every 5 s to 32 s (`capture_m8.gd` j1) | **5.0–6.9 %** of the 640×360 view; identical ko/en, 1×/2×, notch/full | OPEN |
| J1 framing | lane band = top of tallest visible unit to bottom of ground strip, % of view height | **16.1 %** | OPEN |
| J1 enemy visibility | enemies inside the camera view, r01 t = 7…32 s | **0** at every sample; r08 peak frame (34 units, 160 s) also shows 0 enemies | OPEN |
| J1 sides | ally vs enemy colour (TH-COL) + CVD frames | PASS (ΔE 19–25) | closed part |
| J2 risk | `probe_r01_risk.gd --seeds=20`, casual policy | 20/20 wins, **20/20 three stars**, player base hit in **0/20** runs, max base damage **0 %**, median clear **108 s**, waves reached 3 of 6 | OPEN |
| J2 risk | same, competent policy | 20/20 wins, 20/20 three stars, base hit 0/20, median clear 129.9 s | OPEN |
| J3 | worker shape + resource names (VISUAL_CHECKS C5) | PASS | **closed** (04 6051b3c) |
Observation for 01/04: the r01 HUD shows "웨이브 0/3" while data/rounds/r01.json has 6 waves (late pressure waves at 160/210/260 s); intended hiding or a count mismatch, not yet decided.
Pass rules still owed by 01 (see 07-qa-to-01-director.md): J2 numeric rule in ROUNDS.md; J1 target for object-area % or enemy visibility agreed with 03/04.
