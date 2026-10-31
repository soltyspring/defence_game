# Draw-call breakdown in a dense battle (r08, caps 36/36)

Owner: 08-performance. Evidence class: **DESKTOP_PROXY** (draw-call counts only). Runs v1–v9 had 4–10 foreign Godot processes
(CONTENDED; each run is a wrapper + engine pair); v10 ran inside the machine-wide lock with 0 at start. Draw-call **counts** come from
Godot's canvas renderer and do not depend on CPU load, so contention does not change them; it only affects timings, and this document
reports none. Not phone evidence.

## 1. Method
- Snapshot: `git archive` of origin/main **f41fd12** (v6–v8, includes 04's 31164c8 HUD) and **84c18ab** (v9), each with **its own
  `--import`**. The shared `.godot/imported` holds 03's uncommitted `ui_main`/`char_player` PNGs; without the re-import, UiStyle printed
  "atlas ui_main import is stale → icons disabled" and the HUD was measured without icons (runs v5 and fca9346 v1–v4 are affected for the
  HUD rows only).
- Window 1280×720 on the secondary monitor (UI viewport 640×360), GL Compatibility (`rendering_method.mobile` is also
  `gl_compatibility`), Godot 4.7.2 debug binary, RTX 2070 SUPER.
- `tests/performance/perf_drawcall_probe.gd`: autoplay r08 with the stress cheat (both armies refilled to 36/36, base HP reset, bosses
  excluded), 35 s warm-up, then 02's battle view is replaced by `tests/performance/drawcall_view.gd`. That subclass draws the same thing
  and adds per-category switches, page-run counters and sort-mode experiments.
- Phases are 2.5 s each and the first 0.5 s is skipped. Each removal phase is compared with the reference phase measured just before it,
  because HUD state drifts: the HUD alone measured 103–143 draw calls within one run. Deltas are not additive.
- Runs: v6 18:57, v7 19:04, v8 19:08 (f41fd12, fresh import), **v9 19:34 (origin/main 84c18ab, after 03's b113085 hero redraw and
  04's 45c05f0, via `tools/perf/drawcall_run.ps1`)** and **v10 23:32–23:41 (origin/main 36e2a9e, includes 02's eceb9f4; adds the
  simulated page-merge phases, 3 font-size micro rows and the equivalence re-check)**. Earlier runs on fca9346 (v1–v4) and v5 agree on
  the view rows. v10: frame 177, units −55, hud_top −48, cards 9 each, so nothing moved since v9.
- **user:// isolation:** v1–v8 and the first micro-checks booted the game with the real `%APPDATA%` user folder (10's v0.26 P1 finding,
  10-research-systems-to-08-performance.md). From v9 on, every 08 launcher runs Godot with a private APPDATA
  (`tools/perf/perf_isolation.ps1`), proven by the run's own `godot.log` under `build/perf/appdata/<tool>/`. Draw-call counts do not
  depend on the save (stress holds 36/36), and v9 matches v6–v8.
- Batching micro-check: `tests/performance/perf_batch_micro.gd` draws 12 repeats of each pattern on one lone Control using UiStyle.

## 2. Results
Whole frame (`all`): **176–181** draw calls (v6–v9). Battle view alone (HUD hidden): 54–68. HUD alone (view hidden): 103–143.

| Part | Delta when removed (v6 / v7 / v8 / v9) | Note |
|---|---|---|
| **Unit sprites** (72–76 units) | **50 / 54 / 53 / 50** | view drops to 9 |
| Background + biome layers | 2 / 2 / 5 / 2 | |
| Bases + workers | 9 / 0 / 1 / 9 | |
| HP bars (flushed after sprites, 08 H2) | −1 / −1 / 2 / −1 | one rect batch |
| Projectiles (0–3 alive) | 2 / 3 / −1 / 2 | |
| Fx (0–3 alive) | 0 / 3 / 0 / 1 | |
| Damage texts (2–10 alive) | 2 / 1 / 0 / 6 | |
| **HUD top panel** (`hud_top.gd`) | **48 / 48 / 50 / 48** | |
| Card buttons ×5 (식빵병, 롤빵병, 통식빵, 프레첼, 화덕포) | 7–11 each, **≈ 45 total** | `touch_button.gd` |
| Worker button (제빵사) | 6 / 5 / 5 / (−17, HUD state changed mid-phase) | |
| Skill buttons ×3 | 2–12 each (state-dependent) | |
| Pause, camera ◀ ▶ buttons | 0–4 each | |
| Labels (wave banner, wave text) | −2 to 2 | |

The two largest causes are the unit sprites (≈ 53) and the HUD's own draw order (top panel ≈ 50, buttons ≈ 50).

### 2.1 Unit sprites: atlas-page interleaving
`_draw_unit` only draws textured quads (bars come later), so a new batch starts whenever two consecutive units in depth order come
from different atlas pages. The 4 character pages are char_player (25–26 units incl. hero, 512×512), char_player_adv (11–12, 512×256),
char_enemy (23–25, 512×256) and char_enemy_adv (13, 512×256). `drawcall_view.gd` counts these page runs every frame in the real order and
for alternatives:

| Order / pages | Page runs per frame (median, v7–v10) | Measured view draw calls | Change vs 02's order |
|---|---|---|---|
| 02's lane_y order, 4 pages (shipped) | 49–61 | 54–71 | – |
| Row sort: (rounded lane_y row, page, lane_y), 4 pages | 32–42 | **48 / 48 / 41 / 47** (v7 / v8 / v9 / v10) | **−12 to −17 measured** |
| 02's order, 2 pages (player side / enemy side) | 29–47 | **46** (v10, simulated binding) | **−23 measured (simulated)** |
| Row sort, 2 pages | 20–26 | **31** (v10, simulated binding) | **−40 measured (simulated)** |
| 02's order, 1 character page | 1 | **9** (v10, simulated binding) | **−57 measured (simulated)** |
| Page-first sort, 4 pages (experiment, wrong overlaps) | 4 | **13** (v6–v10) | −42 to −55 measured |

"Simulated binding" (v10, `drawcall_view.gd` `tex_mode`): every character sprite is drawn with one shared page texture (or one per
side) and keeps its own region rect. The pixels are wrong, but the GPU sees the same texture changes a merged atlas would cause, so the
count is what the merge would give without 03 repacking anything. Workers, bases, projectiles and fx keep their real textures.

The model fits: removing the units removes 50–54 draw calls for 49–60 runs, and both measured sorts land where the run count predicts
(v8: 48 = 9 non-unit + 39 runs; v9: 41 = 9 + 32; page-first 13 = 9 + 4).
- **Row sort** keeps the depth order: units are drawn at `roundf(ground_y + lane_y)`, so units on the same pixel row have the same depth
  and their current order between them is arbitrary anyway (`sort_custom` is not stable). Only those ties are reordered.
- **Page-first** sort changes which unit covers which across rows. It only shows the floor for the current pages and is not a
  shipping order.
- **Merging pages** keeps 02's order unchanged. Pixel area from the atlas JSON `occupancy`: char_player 152 830 px + char_player_adv
  48 628 + char_enemy 52 691 + char_enemy_adv 61 211 = **315 360 px**. That fits one 1024×512 page (524 288 px, 60 % full) = **2.0 MiB
  RGBA8** instead of today's 2.5 MiB. Whether the shapes pack is for 03's packer to confirm. Trade-off: char_player is `load_policy:
  battle` and the other three are `battle_roster`. A round that uses only basic units would load 2.0 MiB instead of 1.5 MiB; the worst
  battle (gate 9.25 MiB) drops by 0.5 MiB. Two pages (player 201 458 px in 512×512, enemy 113 902 px in 512×512) would be 2.0 MiB too.

### 2.2 HUD: texture switches inside each control
Batching micro-check (12 repeats each, draw calls above an empty screen):

| Pattern in one `_draw` | Draw calls |
|---|---|
| 12 rects / 12 texts (one font) / 12 bold numbers / 12 ui_main icons | 1 each |
| rect, text, rect, text … | **24** |
| 12 rects, then 12 texts | **2** |
| FONT_S text, FONT_M bold number, interleaved | **24** |
| the same, grouped | **2** |
| rect, icon, text interleaved | **36** |
| the same, grouped by kind | **3** |
| card label (ui 12) + cost in the HEAD style (num kind, 10 px), interleaved | **24** |
| card label (ui 12) + cost in 04's WIP style `NUM_READ` (ui kind, 12 px), interleaved | **1** |
| one font (ui) at 12 px and 24 px, interleaved | **24** |

(v10 rows from `build/perf/batch_micro_36e2a9e_20261031-233207.json`; the first rows repeat v9 exactly.)

So every switch between a plain rect (`draw_rect`, `draw_pixel_box`, `draw_bar`, `draw_hatch`), an icon texture and each glyph cache
starts a new draw call. A glyph cache is one font **at one size**: the same font at 12 and 24 px switches too, while a label and a
number in the same font and size batch as one. Shadow + glyph pairs from the same font do not cost extra. All HUD icons (cards, skills,
pause, camera, resources) come from the one `ui_main` page. `hud_top._draw` alternates box → icon → text → bold number → num number → bar per row, and `touch_button._draw` goes box → icon → label → cost → cooldown rect → badge → reason rect
+ text. That matches ≈ 50 for the top panel and ≈ 9 per card button. Drawing each control's rects first, then icons, then text per font
would bring each control close to one draw call per distinct texture. That is an estimate from the micro-check, not a measurement of the
HUD itself.

## 3. Budget view and reduction plan
### 3.0 Result after 03's merge (v11, 2026-11-01 00:28–00:32, origin/main 64a95c6, inside the heavy lock, isolated, 0 foreign Godot)
03 committed option A in 253f2b6 (one 1024×512 character page; gate PASS, worst battle 9.25 → 8.75 MiB). Measured at caps:
**battle view 58–71 → 8–9** (page runs 49–61 → 1; units add −1 to 0), so 03 A9 meets its acceptance (≤ 15) and matches the simulated
−57. **Whole frame 177 → 132.** The unit row sort (02 P9) no longer changes anything (`+rowsort` 9 = reference 9).
The HUD is now the cost: HUD alone 114–125 (v10: 103–114), `hud_top` **56** (v6–v10: 48–50), card buttons 9–10, skills 2–3,
worker 7. HUD code changes between v10 and v11 are 04's d724b9a (numbers Galmuri9 10 → Galmuri11 12, base HP bar 14 → 16 px) and
1850c3f (threat-marker text, hidden in this scene). The +8 on `hud_top` is measured, but its mechanism is not isolated. A split ui-12
glyph cache is unlikely, because FONT_COST.md shows every ko.json string at Galmuri11 12 fits one cache page. My micro-check estimate
(−1 to −2 per card button from ui-12 numbers) is **not confirmed** by the HUD: card buttons stayed at 9–10.

### 3.1 Plan (as of v10; rows marked done are measured)
BUDGETS.md: battle draw calls ≤ 100 (provisional, low-end GLES3) and ≤ 200 (mid-tier). At caps the battle is at 176–181 (v10: 177).
Damage texts, fx and projectiles are ≤ 6 each, which corrects the 18:25 guess in the 02 request file (texts/fx interleaving). 04's
threat markers (31164c8) are hidden until 02's `threat` field exists and are not in these numbers. The cost of one draw call on a
phone is unmeasured.

| Change (owner) | Saving at caps | Basis |
|---|---|---|
| Unit row sort (02 P9) | −13 (−12 to −17) | measured, 4 runs |
| 2 character pages, player / enemy side (03 A9 option B) | −23 | measured, simulated binding |
| 2 pages + row sort (03 + 02) | −40 | measured, simulated binding |
| 1 character page (03 A9 option A) | −57 | measured, simulated binding; **done in 253f2b6: −57 measured for real (v11)** |
| HUD drawn in texture layers, `hud_top` (04 R8) | ≈ −40 of 48 | estimate from the micro-check |
| HUD layers, card buttons (9 → ≈ 4 each ×5), worker (6 → 3), skills (3 → 2 each ×3) (04 R8) | ≈ −30 | estimate from the micro-check |
| Card costs in `NUM_READ` (ui 12) instead of num 10 (04 WIP) | ≈ −1 to −2 per button (part of the row above) | measured in the micro-check only |

Combinations (frame 177 at caps today; HUD rows are estimates): 1 page + HUD layers ≈ **177 − 57 − 70 ≈ 50**. 2 pages + row sort + HUD
layers ≈ **67**. Row sort + HUD layers ≈ **94**. Units alone do not get there (1 page: ≈ 120), and the HUD alone does not either
(≈ 107). So reaching ≤ 100 needs the HUD layering (04) plus at least the row sort (02); 03's page merge gives the margin.
**After v11:** the frame is 132 with units solved, and the HUD (114–125) is the only large part left. The ≤ 100 target now depends on
04's layering alone: an estimated −70 would give ≈ 62. The row sort is no longer needed.

## 4. Reproduce
```
& .\coordination\heavy_run.ps1 -Label '08-drawcalls' -Script { & .\tools\perf\drawcall_run.ps1 -Rev origin/main [-Round r08] [-SkipMicro] [-Equivalence] }
```
The runner must run inside the machine-wide lock (`coordination/heavy_run.ps1`; it exits 4 otherwise). It makes the git-archive
snapshot `build/perf/dc_<sha>` with its own `--import`, copies `tests/performance/*.gd`, and runs `perf_drawcall_probe.gd` and
`perf_batch_micro.gd` on the secondary monitor. With `-Equivalence` it also runs `targeting_equivalence.gd` headless. Every call is
serial and goes through 10's `isolated_godot.ps1`, and the runner exits 3 if isolation is not proven. Reports (git-ignored):
`build/perf/drawcalls_r08_64a95c6_20261101-002827.json` (v11, after 03's merge), `drawcalls_r08_36e2a9e_20261031-233207.json` (v10),
`batch_micro_36e2a9e_20261031-233207.json`,
`equivalence_36e2a9e_20261031-233207.json`, `drawcalls_r08_84c18ab_20261031-193400.json` (v9), and the earlier
`drawcalls_r08_v6|v7|v8_f41fd12.json`.
