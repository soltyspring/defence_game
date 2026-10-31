# 06-art-ui handoff
Updated: 2026-11-01 ~07:45 KST. Session: this Kiro window (former 06-services), reopened after the 03:55 BSOD.
Processed: coordinator 01:08 (role), the 03:2x dispatch, `coordination/prompts/06-afford-state.txt`, the 06:5x BSOD resume note;
03-art-to-06-art-ui U1 (03:15), 07-qa-to-06-art-ui (03:19), 09-art-world W1. No new replies since.

## Crash recovery (06:5x)
- heavy_run.log: every 06 START has an END (last: 06-ui-capture-narrow 02:56–02:57, ok). Nothing of mine was lost in the lock queue.
- The 03:53 / 03:55 mock files (A, B) were intact but carried a bug (2x baseline state read with halved rects); regenerated A, B and
  made C (pure Python, no Godot, no build.py in the shared tree).

## Done (SHAs checked with git ls-remote after each push)
- 1d359bc, 700692d, 04269f4, 5a46675, adc0965, 7a77501, 02ec60f (see earlier status).
- This commit: CARD_STATE_CRITERIA.md (criteria written before measuring, then results), mock A/B/C with state metrics,
  `ui.card_off`, `ui.CARD_FRAME_LIT` (proposals, not wired), `size_candidates.py` + `docs/art/evidence/ui_art/sizes/`,
  genre video section, requests 04 R4 and 03 R4: **da2d2a6** (git ls-remote origin refs/heads/main = da2d2a6d31c2a08a69e7ad47066103608ba1a52d, 07:4x KST).

## Open, waiting on others
- 07: fixed-set verdict on adc0965 and 02ec60f. Accept it as written. If U1 fails in the unaffordable state, point to variant C
  (needs 04 code + new `card_<uid>_off` frames) and ask for a rejudge after that lands.
- 04: R3/R4 (which frames, which sizes, icon_off). Then draw to those sizes; add NEW names only after 03 + 04 approve.
- 03: `ink` #07070c key; approval of `card_<uid>_off` and the other NEW names. If ink lands: switch chrome K -> ink, rebuild in a
  clean HEAD copy, re-run `hud_mock.py` for variant C.

## Rules I keep
- Heavy / Godot runs only via `coordination/heavy_run_detached.ps1 -Label 06-<task> -ScriptFile <job.ps1>`; headless unless a
  screen capture is required; one variant/resolution per job; poll HEAVY_JOB_DONE in short calls.
- Never run build.py in the shared tree: clean `git archive HEAD` copy in %TEMP%, copy back only my pages.
