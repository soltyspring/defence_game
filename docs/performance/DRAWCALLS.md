# Draw-call breakdown in a dense battle (r08, caps 36/36)

Owner: 08-performance. Evidence class: **CONTENDED_DESKTOP_PROXY**. Every run had 4–10 foreign Godot processes (other roles' runs; each
run is a wrapper + engine pair). Draw-call **counts** come from Godot's canvas renderer and do not depend on CPU load, so contention does
not change them; it only affects timings, and this document reports none. Not phone evidence.

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
- Runs: v6 18:57, v7 19:04, v8 19:08 (f41fd12, fresh import) and **v9 19:34 (origin/main 84c18ab, after 03's b113085 hero redraw and
  04's 45c05f0, via `tools/perf/drawcall_run.ps1`)**. Earlier runs on fca9346 (v1–v4) and v5 agree on the view rows.
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

| Order / pages | Page runs per frame (median, v7–v9) | Measured view draw calls | Change vs 02's order |
|---|---|---|---|
| 02's lane_y order, 4 pages (shipped) | 49–60 | 54–68 | – |
| Row sort: (rounded lane_y row, page, lane_y), 4 pages | 32–42 | **48 / 48 / 41** (v7 / v8 / v9) | **−12 / −17 / −13 measured** |
| 02's order, 2 pages (player side / enemy side) | 35–47 | not measured | ≈ −15 to −20 predicted |
| Row sort, 2 pages | 22–26 | not measured | ≈ −35 predicted |
| 02's order, 1 character page | 1 | not measured | ≈ −52 predicted |
| Page-first sort, 4 pages (experiment, wrong overlaps) | 4 | **13** (v6–v9) | −42 to −55 measured |

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

So every switch between a plain rect (`draw_rect`, `draw_pixel_box`, `draw_bar`, `draw_hatch`), an icon texture and each font
(ui / bold / num) starts a new draw call. Shadow + glyph pairs from the same font do not. `hud_top._draw` alternates box → icon → text
→ bold number → num number → bar per row, and `touch_button._draw` goes box → icon → label → cost → cooldown rect → badge → reason rect
+ text. That matches ≈ 50 for the top panel and ≈ 9 per card button. Drawing each control's rects first, then icons, then text per font
would bring each control close to one draw call per distinct texture. That is an estimate from the micro-check, not a measurement of the
HUD itself.

## 3. Budget view
BUDGETS.md: battle draw calls ≤ 100 (provisional, low-end GLES3) and ≤ 200 (mid-tier). At caps the battle is at 176–181. Unit pages
(≈ −50 with one page, −12 to −17 with the row sort alone) plus HUD grouping (top panel and buttons ≈ 100 now) are the only two parts big
enough to reach 100. Damage texts, fx and projectiles are not: the 18:25 guess in the 02 request file (texts/fx interleaving) is
corrected by this breakdown. 04's threat markers (31164c8) are hidden until 02's `threat` field exists and are not in these numbers.
The cost of one draw call on a phone is unmeasured.

## 4. Reproduce
```
.\tools\perf\drawcall_run.ps1 -Rev origin/main [-Round r08] [-Warmup 35] [-Phase 2.5] [-SkipMicro]
```
The runner makes the git-archive snapshot `build/perf/dc_<sha>` with its own `--import`, copies `tests/performance/*.gd`, runs
`perf_drawcall_probe.gd` and `perf_batch_micro.gd` on the secondary monitor with a private APPDATA, and exits 3 if isolation is not
proven. Reports (git-ignored): `build/perf/drawcalls_r08_84c18ab_20261031-193400.json` (v9),
`build/perf/batch_micro_84c18ab_20261031-193400.json`, and the earlier `drawcalls_r08_v6|v7|v8_f41fd12.json`.
