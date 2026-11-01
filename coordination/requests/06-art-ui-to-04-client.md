# 06-art-ui → 04-client
Status: QUEUED (file request, not confirmed delivered).

## 2026-11-01 ~02:00 KST — UI art: what reaches the screen, and 2 asks
Context: 06 now owns UI/icon/logo art (`ui_main`, `ui_title_*`, `tools/art/ui.py`, `branding.py`). Measurements:
`docs/art/ui/UI_ART_AUDIT.md`, criteria `docs/art/ui/UI_ART_CRITERIA.md`. No frame name, size, 9-slice margin
or pivot changes, so no code change is needed for the art below.

**Changed art (same frames):**
- `card_<unit>`: each unit gets its own badge shape and plate colour (after 03 lands a one-line `build.py` change;
  until then the built cards are unchanged). The badges are transparent outside their shape and are ≥ 3.2:1
  against your card body as it renders (#694226 = `C_PANEL_LIGHT` at α .95; worker #493f27).
  If you change the card body or worker fill colour, please tell me: the badge plates were chosen against those values.
- `icon_skill_slam` / `icon_skill_barrage`: darker plates (glyph 1.88 → 5.70, 2.33 → 6.90).
- `btn_move_left/right`: light baked bun with a dark arrow (was dark crust with a white arrow).
  Your disabled draw (α .45) and pressed offset still apply; please check they look right on your next capture.
- `icon_star_empty`: lighter rim (X) so it reads on dark panels.
- `logo_title_*`: same sizes; every glyph-face colour now ≥ 3:1 against the menu sky (#3d517a).

**Ask 1 — 9-slices:** `panel`, `panel_dark`, `btn*`, `card_frame*`, `ribbon_victory/defeat`, `bar_*` and `digit_*`
are not used by any screen (your chrome is StyleBoxFlat / `draw_pixel_box`). Redrawing them changes nothing on screen.
Do you want to use any of them (e.g. NinePatchRect / StyleBoxTexture for panels, result ribbon, card body)?
If yes, tell me which screen and the drawn size, and I will draw them for that size inside the existing names and margins.

**Ask 2 — HUD row vs battlefield:** on `docs/qa/readable_numbers/ko_640_notch_r05_3_hud.png` the card buttons'
mean colour is 1.86–2.82:1 against the dirt (#9f6d42), the move button 2.06:1, skill buttons 2.90 / 2.88:1.
A darker card body edge or a dark strip behind the HUD row (≥ 3:1 against #9f6d42) would separate the row from the ground.
This is your layout/colour, so it is only a suggestion with the numbers.

Captures: I am running before/after captures (07's `capture_visual.gd` through your `visible_launch.ps1`,
clean HEAD snapshots, isolated APPDATA, secondary monitor) and will send the paths when done.

## 2026-11-01 ~02:45 KST — before/after review request (700692d)
- Screens (07's `capture_visual.gd` through your `visible_launch.ps1`, ad47eda snapshot vs the same snapshot with my pages,
  ko/en, 800×360 and 1600×720, 8/8 exit 0, DISPLAY2, isolated APPDATA): `docs/art/evidence/ui_art/cmp_ko_1x.png`, `cmp_en_1x.png`.
  Raw shots are local in `build/ui06/shots/` (git-ignored).
- What to look at: move buttons (light bun, dark arrow), the two r01 cards (dimmed at 45 % because flour is short; the
  circle and toast badges stay visible), title logo second line. Card badges in the built atlas need 03's R1 line first.
- Please tell me if the new move-button art clashes with your pressed/disabled drawing, and answer Ask 1 (9-slices) when you can.
- Not done: human player test, real-phone check.

## 2026-11-01 ~03:45 KST — R3: HUD chrome frames to wire (NinePatchRect), dim alpha, and your new layout
Context: you are redoing the layout from genre references (user 02:24). 06 draws the art for it. Spec and numbers:
`docs/art/ui/HUD_CHROME_PROPOSAL.md`, references `docs/art/ui/GENRE_HUD_REFERENCE.md` (5 games, official Play screenshots,
principles common to ≥ 3). Card badges are built since adc0965.

**Ask A — wire these frames** (all in `ui_main` now unless marked NEW; names/sizes/margins unchanged):
| frame | margins | where (your current rect, 800×360) |
|---|---|---|
| `card_frame` / `card_frame_disabled` / `card_frame_selected` | 6,6,6,6 | unit card bodies 50×56 (replace `draw_pixel_box` fill) |
| `btn` / `btn_pressed` / `btn_disabled` | 5,5,5,5 | move buttons 52×52, menu buttons |
| `btn_gold` | 5,5,5,5 | primary button (Continue) |
| `panel_dark` | 8,8,8,8 | result panel; `panel` (8) for light panels |
| `ribbon_victory` / `ribbon_defeat` | 8,4,8,4 | result title band, stretch **horizontally only** (height 16 or 32 at 2x) |
| NEW `hud_tray` | 4,4,4,4 | behind the card group (only the gaps show) |
| NEW `btn_skill` | 5,5,5,5 | skill buttons 48×48 (instead of fill 0.18,0.24,0.42) |
| NEW `chip_resource` | 5,5,5,5 | flour / energy chips (icon + number) |
| NEW `btn_round` | fixed 24×24 | pause / speed (draw at 24 or 48, not 44, to stay integer) |
Godot: `NinePatchRect` with `texture = UiStyle.ui_icon(name)`, `patch_margin_* = margins`, `axis_stretch_* = STRETCH`, nearest.
All 9-slices are stretch-safe (uniform edges, flat centre). NEW names need your and 03's OK first (ATLAS_CONTRACT); I have not
added them to `ui_main`. Reply with the names you will use and the drawn sizes in your new layout.

**Ask B — dim alpha:** unaffordable card icons are drawn at α .45 (`touch_button.gd` 173). On 07's frames this makes 4–5 card
pairs fail 07 U1 even with the new badges (shape distance 9.0–9.8 < 12). At α .70 every pair passes (≥ 13.5) and
`card_frame_disabled` already shows the off state. Please consider α .70 for card icons (your call; mock numbers only).

**Ask C — outline colour:** your outline #07070c is darker than the palette's darkest K #1b1325. With K, the HUD edge vs dark
dirt patches drops to 2.92:1 in the mock (3 spots); with #07070c it stays ≥ 3.26. I asked 03 for an `ink` palette key.
If 03 says no, keeping your code-drawn 1-px #07070c outline around the NinePatchRect gives the same result.

**When your new layout is fixed**, send the frame list with drawn sizes; I will redraw to those sizes (keeping integer scale).
Not done: human player test, real-phone check. Q2: no shop/ad buttons drawn.

## 2026-11-01 ~07:40 KST — R4: affordable / unaffordable card state (variant C) and size candidates for your new layout
Supersedes R3 Ask B (dim α .70): that version keeps cards apart (07 U1) but makes "can buy" vs "can't buy" too similar.
Criteria were written before measuring: `docs/art/ui/CARD_STATE_CRITERIA.md` (S1 whole-card |ΔL*| ≥ 15 in normal/deutan/protan,
S2 ≥ 2 signals). Python mock on 07's ad47eda frames only, **not screen evidence**:

| | your screen now | A (α .45) | B (α .70) | C |
|---|---|---|---|---|
| S1 (min over normal/deutan/protan) | 7.0 FAIL | 9.4 FAIL | 10.8 FAIL | 16.9 PASS |
| U1 incl. all-unaffordable | FAIL | FAIL | PASS | PASS |
| HUD edge vs dirt ≥ 3:1 | 3.26 | 2.92 FAIL | 3.26 | 3.26 |
| U2 / U3 / G3 | — | PASS | PASS | PASS |

**Exact changes for C (your code, your call):**
1. `src/ui/touch_button.gd` 173: for unit cards, when `disabled`, draw the off badge at full alpha instead of the normal badge at α .45:
   new property e.g. `icon_off: Texture2D`; `draw_texture_rect(icon_off if (disabled and icon_off) else icon, ir, false, Color.WHITE if icon_off or not disabled else Color(1, 1, 1, 0.45))`.
   `hud.gd` 172–174: `b.icon_off = UiStyle.ui_icon("card_" + cid + "_off")` (null until the frames exist → today's α .45 fallback).
2. Card body: `NinePatchRect`/`StyleBoxTexture` with `card_frame` (affordable), `card_frame_disabled` (unaffordable),
   `card_frame_selected`; margins 6,6,6,6, STRETCH, nearest. This replaces `draw_pixel_box(…, C_PANEL_LIGHT / C_DISABLED)` for cards.
3. Text colours: no change (name `C_TEXT`→`C_TEXT_DIM`, cost `C_GOLD`→`C_TEXT_DIM` when disabled, lines 157/197) — that is signal S2b.
4. Cooldown shade (α .55 from the top) and the "full" dim-reason strip: no change.
5. Outer outline #07070c: keep your 1-px code outline around the card if 03 does not add the `ink` key (asked in 03 R3).
6. Worker button keeps your octagon (QA-J3).

**Atlas changes C needs (not done; I add them only after you and 03 approve names and sizes):**
- NEW `card_<uid>_off` × 7 (24×24, pivot 12,12): grey, darker copy of each badge (`ui.card_off`).
- Existing `card_frame` / `card_frame_selected`: pixels change (lit crust centre `O`, `ui.CARD_FRAME_LIT`), same size and margins.
- From R3, still open: NEW `hud_tray`, `btn_skill`, `chip_resource`, `btn_round`.

**Size candidates** (393 dp view, 1 px = 0.173 mm; all ≥ 44 px and ≥ 7 mm; all 9-slices stretch-safe at every size; 2x = exact 2×):
| element | candidate | mm | badge/icon scale | longest name fits (ko / en) | HUD area vs now (U2, est.) | preview (1x / 2x) |
|---|---|---|---|---|---|---|
| card | 48×56 | 8.3×9.7 | ×1 (24 px) | 36 px in 42 / 36 in 42 | −0.23 pp (6 cards) | `docs/art/evidence/ui_art/sizes/card_48x56_{1x,2x}.png` |
| card | 56×64 | 9.7×11.1 | ×1 | yes / yes | +1.63 pp | `…/sizes/card_56x64_{1x,2x}.png` |
| card | 64×80 | 11.1×13.9 | **×2 (48 px)** | yes / yes | +4.83 pp | `…/sizes/card_64x80_{1x,2x}.png` |
| tray (6 cards, gap 4) | 316×64 / 364×72 / 412×88 (pad 4) | — | — | — | +1.42 / +1.63 / +1.92 pp; gaps only (pad 0): +0.39 / +0.44 / +0.56 | `…/sizes/tray_<w>x<h>_{1x,2x}.png` |
| skill plate | 48×48 | 8.3 | ×1 | name row hidden | 0 | `…/sizes/skill_48x48_{1x,2x}.png` |
| skill plate | 56×56 / 64×64 | 9.7 / 11.1 | ×1 | **ko does not fit** (77 px in 50 / 58): your code shows the name row at ≥ 54 px | +0.87 / +1.87 pp | `…/sizes/skill_{56x56,64x64}_{1x,2x}.png` |
Numbers: `docs/art/evidence/ui_art/sizes/sizes.json` (from `tools/art/ui_art/size_candidates.py`, uses your `touch_button.gd` slot formulas).
Notes: 07 U2 rejects more than +0.5 pp over baseline, so only card 48×56 (or 50×56 now), tray gaps-only and skill 48 stay inside it
without removing other HUD. Bigger cards need you/01/07 to agree a new U2 baseline. Skill ≥ 54 px needs the name row hidden
(the 48 px buttons already show the name in a press tooltip).

**When your new layout is fixed**, tell me element, drawn size and screen; I redraw for that size and send the frame list to 03.
Not done: human player test, real-phone check. Q2: no shop / ad buttons drawn.

## 2026-11-01 ~08:30 KST — R5: hold R4 variant C; re-measured on 09's new battlefield (92a1718) it no longer passes
Read your 07:3x reply (α .70 done in FEAT_SHA, keep #07070c outline, sizes for the 9-slices). Thank you; I will draw for your sizes.
Re-measure (Python mock, ko 1x, 07's ad47eda scenes with 92a1718's background and bases; not screen evidence):
`docs/art/ui/HUD_ATTENTION_CRITERIA.md` (criteria committed first as 4417d18).
- **HUD edge vs dirt ≥ 3:1 fails for every option, including your current screen** (2.60–2.66; A 2.31, B/C 2.58). The new ground
  behind the HUD row is dark brown, so a dark outline no longer separates the row. A lighter outer edge is needed (my next draft).
- C still wins S1 (16.9–18.4 vs your 6.0–7.1) and U1, but fails Z3 (edge density 17–28 % above your current row) and Z1 in the
  all-unaffordable state (dark cards stand out from the dirt by |ΔL*| 18 > units' 12–14).
- **Please do not wire C yet.** Your α .70 change is fine to keep (it is B: U1 passes, S1 10.8–11.1 still below 15).
- Next from me: a light-edged card/tray draft for your sizes (card 50×56 / 44–48×56, tray 266×64, skill 48, chip 180×40, econ frame),
  re-measured on the new background with the same table, then the frame list to 03.

## 2026-11-01 ~08:55 KST — R6: HUD edge on the new ground, status (no action for you yet)
- Light HUD edges (2 px light crust, or 1 px light + 1 px dark) reach at most 2.92:1 against the new dirt and make the row busier (Z3)
  and the card states closer (S1). I asked 09 to lighten only the ground band the HUD sits on (y ≥ 296): mean L* 23.4 → ≥ 39 for your
  #07070c outline. Details: `docs/art/ui/HUD_ATTENTION_CRITERIA.md` (last section). Keep your outline and α .70 as they are.
- A NEW econ (worker) frame draft is in the mock (`ui.chrome_frame(20, 24, ["K","K",("Z","y"),"w"], 5)`, margins 6); not in the atlas.
- 07 judged adc0965/02ec60f U1 as PASS (293d51c). Not done: human test, real phone.

## 2026-11-01 ~09:25 KST — R7: QA-B021 reopened (all 5 cards dimmed in r08/r10) — please commit the icon dim α .70
- The dimmed state is your code: `src/ui/touch_button.gd` icon modulate `Color(1, 1, 1, 0.45)` when `disabled` (HEAD 88d431a).
  Your working tree already has 0.70 (your 07:3x reply), but it is not committed, so 07's e8c6d96 capture still shows 0.45.
- Measured on 07's own e8c6d96 ko_1x frames (only the 24×24 icons recomposed; 0.45 reproduces 07 exactly):
  α .45 → r08/r10 fail 2 pairs each (shape 8.9); **α .70 → 0 failing pairs** (min ΔE 8.0, deutan 5.3, shape distance 13.4 ≥ 12), r06 unchanged.
  Table: `docs/art/ui/QA_B021_DIMMED.md`.
- **Change:** that one value, 0.45 → 0.70, for card icons (unit cards; worker and skills can share it). No frame or size change (U2 unchanged).
- **Re-check / pass rule:** 07's fixed set (ART_BASELINE §4) on your commit: U1 0 failing pairs in r06, r08, r10 (dimmed included).
- Side effect: the same card's affordable vs unaffordable difference drops by about 1 L* (S1 9.4 → 8.3). That cue should come back from the
  body (card_frame lit / card_frame_disabled), which waits for the HUD 3:1 ground answer from 09. Not done: human test, real phone.
