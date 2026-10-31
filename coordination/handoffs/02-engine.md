# 02-engine handoff
Updated: 2026-11-01 07:10 +09:00
Status: ACTIVE. Task: coordination/prompts/02-stall-zoom.txt (bot stall fix + world zoom flag) + 10 AC1 (content.gd CRLF) + 01 R12 answer.
Verified on a clean HEAD snapshot (job `02-verify`, 07:06–07:11): selftest PASS 77/77, UI integration 49/0, 07 sim/flow/save/faults 106/0,
AC1 CRLF = LF = c1-989c3422c910. Being committed; SHA (from git ls-remote) in the status file after the push.
Resumed after the 2nd blue screen (0x3B, 03:55 KST). My files had no NUL bytes and were not truncated (byte scan 06:53). heavy_run.log:
my `02-snap-verify` (03:27) never reached START, so it had no result to discard; the two `02-zoom-caps` exit 1 are explained below.
Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL / QUOTA CHECKPOINT notices are previous-account records; not acted on.
Heavy runs: only via `coordination/heavy_run_detached.ps1 -Label 02-<job> -ScriptFile build/heavy/<job>.ps1`, poll `HEAVY_JOB_DONE` in short calls,
headless unless a screen capture is required (two blue screens during GPU work), private APPDATA, no batching of variants.
Last processed: DECISIONS up to D37; 01→02 R10/R11/R12 (answered); 03→02 A17–A19 (A19 step 1 done; import deferred); 04→02 R16–R19 (R17-3/R18 done
behind the flag; R16, R17-2, R19 open); 10→02 v0.24–v0.33 (AC1 fixed in content.gd; Part D open); 08→02 P9/P10 (queued).

## User decisions
Q1 theme A "빵집 기사단 vs 곰팡이 군단". Q2 monetization ON HOLD (no ads/billing/shop UI). Q3 work title "빵집 기사단: 곰팡이 디펜스" (store name after KIPRIS).
Q4 home-screen name ko "빵집 기사단", en "Bakery Knights". Q5 difficulty unanswered; D28 is a default, not approval.

## This round (uncommitted, files intact)
1. Bot stall (docs/architecture/evidence/bot_stall_20261101.md; probe src/core/diag/bot_stall_probe.gd; raw rows evidence/bot_stall/):
   cause = competent worker-reserve trap (half-price reserve → 2–4 workers of 5) + hurt hero walking home for good; not the card order.
   Fix in src/gameplay/bot_player.gd (knobs + `use_legacy_policy()`). LOW s1–5 competent median r02 171.4 → 120.7, r03 212.4 → 125.9,
   r04 220.7 → 128.8; casual unchanged except r03 s4. Side effects: r05 none 0/10 → 10/10 (both bots), r05 LOW 10/10, r10 comp 460 → 264 s.
2. World zoom (docs/architecture/evidence/world_zoom_20261101.md; frames evidence/world_zoom/): App.world_zoom(), project setting
   game/camera/world_zoom_plus_one=false, args --world-zoom/--world-zoom-k; battle.gd camera ground row 70 view px above the bottom (290/360 in
   all 5 captures). k=2 zoom 3/2: 11.8 % odd runs (off 0.1 %), cause unverified. INTERFACES.md §4 v1.9.
3. 10 AC1: content.gd hashes CRLF as LF (`_crlf_to_lf`, same rule as content_version.py `lf`); src/core/diag/print_content_version.gd.
4. 01 R12 (boss-death hooks): feasible, ~1 h, not built (01 asked to wait).
- `02-zoom-caps` exit 1 causes: 02:35 = my battle.gd parse error (selftest gate, no captures); 03:14 = last step UI integration 48/1
  "menu draws the ko logo (mode=text)" on the shared tree; captures exit 0.
- Contamination I caused (reported in coordination/requests/02-engine-to-coordinator.md and to 01/07/08/10): shared-tree bot_player.gd changed
  since 01:03:49 (01's D38 and r05-structure sweeps used the fixed bot); battle.gd did not compile 01:31–02:43.
- Validation: shared-tree selftest PASS 03:14 (76 scripts); bot_stall probes A/B/C; captures. Clean snapshot `02-verify` (HEAD 3f70d8f + my
  files, log build/heavy/02-verify-20261101-065518.log, outputs build/save_evidence/verify02/): selftest PASS 77/77; UI integration 49/0 (the
  logo failure was the shared tree); 07 acceptance sim+flow+save+faults PASS 106/0; AC1 CRLF (2,758 CR) = LF = c1-989c3422c910 = python `lf`.

## Commits (PUSHED, verified with git ls-remote)
… eceb9f4, c6fbf1f, 52f9fa3 (save migration + QA-B012), 2944cc0 (SHA record). This round: pending.

## Next
1. When `02-verify` is done (log build/heavy/02-verify-20261101-065518.log, outputs build/save_evidence/verify02/): read results, fix if needed,
   commit bot_player.gd, battle.gd, app.gd, content.gd, project.godot, the two diag scripts, INTERFACES.md, evidence docs and request files; record the
   ls-remote SHA here.
2. 01: r05 block with the fixed bot; R12 only if 01 confirms. 03: D1 art, then one main-tree import if still needed. Zoom switch stays off.
3. 04 R16 threat field, R17-2 bottom inset (70 + inset), R19 damage-number size. 08 P9 after re-measure. QA-B013, 06 AAB/launcher icons, 10 Part D.
