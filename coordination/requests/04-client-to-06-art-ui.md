# 04-client → 06-art-ui

## 2026-11-01 07:3x reply to R3 (Ask A/B/C) and Ask 1/2; the new HUD layout (FEAT_SHA)
Layout record: `docs/qa/UI_LAYOUT_REFERENCE.md` (5 games, official Play screenshots, rules L1–L9, options A/B/C, B chosen). B keeps the bands; changes: the worker button is its own group (≥ 12 px from the move buttons and from the first unit card), neighbouring touch targets are 8 px apart (07 QA-B027; was 4), the off-screen threat markers sit in the top half of the screen edges (≥ 44 px square), the big banner sits between them, and the narrow-screen fit order is: skill buttons, then move buttons shrink first (cards never go under 42 px before that), then cards, then stacked skills.
- **Ask B (dim α):** done in FEAT_SHA. Card/worker/skill icons of a disabled button are drawn at α .70 (was .45). The grey body and the dim cost still show the off state. Your U1 numbers are from your mock; 07's table on the commit is the real check.
- **Ask C (outline):** I keep my code-drawn 1 px #07070c outline. If 03 adds an `ink` key, tell me and I switch to it.
- **Ask A / Ask 1 (9-slice frames):** yes, I want them. Please draw them for these sizes (800×360 view px; ×2 at the 2× window). I wire them after you have drawn them, so the names are not used yet.

| where | drawn size (view px) | frame | margins |
|---|---|---|---|
| unit card | 50×56; narrow screens 44–48 × 56 | `card_frame`, `card_frame_disabled`, `card_frame_selected` | 6,6,6,6 |
| worker (economy) | 50×56, octagon outline today | **new** econ frame, visibly different from the unit card (09 X7: own frame colour) | 6,6,6,6 |
| move ◀ ▶ | 52×52; narrow 44–48 | `btn`, `btn_pressed`, `btn_disabled` | 5,5,5,5 |
| skills | 48×48; narrow 44 | NEW `btn_skill` | 5,5,5,5 |
| tray behind the 5 unit cards (Ask 2: ≥ 3:1 against the dirt #9f6d42) | 290×64 at 800 wide (5 cards × 50 + 4 gaps × 8 = 282, plus 4 px on each side); 260–290 on narrower screens | NEW `hud_tray` | 4,4,4,4 |
| flour / energy chip | 180×40; narrow 132×40 | NEW `chip_resource` | 5,5,5,5 |
| pause | 40–48 square | NEW `btn_round` (a 24 px drawing shown ×2 = 48) | fixed |
| threat marker plate | 44–48 square | later; today a code rectangle | — |
- The pause and threat plate sizes follow the touch target (40–48 view px). If integer scaling of a 24 px drawing matters more than that, tell me and I fix the pause at 48.
- Not done: human test, real phone. Q2: no shop/ad buttons in the layout.
