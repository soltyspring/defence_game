# CODE_REVIEW_HOTPATH.md — per-frame allocations, entity caps and full scans in the battle loop (owner: 08-performance)
Updated: 2026-10-31 16:04 +09:00. Method: **static code review only (no Godot run)**, because the coordinator has not opened the quiet
window C11 yet. Reviewed the committed files at HEAD 0590e7a (exported with `git show HEAD:<file>`, so other workers' WIP is excluded):
`src/gameplay/battle_sim.gd` (last change e9dfaa4), `src/gameplay/battle_view.gd` and `src/gameplay/battle.gd` (141d226),
`src/core/atlas.gd` (fdd4d86), `src/core/perf.gd` (1eb4637), `data/game_config.json`. Line numbers refer to those committed versions.
The costs below are an **order of magnitude estimate**. The timing figures cited come from earlier CONTENDED_DESKTOP_PROXY runs, and the
08:08–09:00 A/B is INVALID. Each item lists how it will be measured; nothing here is a phone number.

Counting basis: "at caps" = 36 living units per side (effective cap, §1) + dying units (0.7 s each) + ≤ 8 workers, up to 64 projectiles,
48 fx and 24 damage texts. The sim runs at 60 steps/s. GDScript `{}`/`[]` literals, `Dictionary`/`Array` returns and String formatting
allocate on the heap every time. `Vector2`/`Rect2`/`Color` are value types (no heap).

## 1. Entity caps vs D7 vs actual pools
| Source | ally | enemy | projectiles | fx | damage texts |
|---|---|---|---|---|---|
| DECISIONS.md D7 (01, DEFAULT) | 30 | 40 | 64 | — | — |
| `data/game_config.json` caps (01 data) | 36 | 36 | 64 | 48 (`max_vfx`) | 24 |
| `battle_sim.gd:89` fallback defaults | 30 | 40 | 64 | 32 | 24 |
| `perf.gd` ceilings (`CAP_UNITS_PER_SIDE` etc.) | 40 | 40 | 64 | 48 | 24 |
| ENGINE.md §7 | 36/side | 36/side | 64 | 48 | 24 |
| **Effective** (`battle_sim.gd:218-224`: data value clamped to perf ceilings) | **36** | **36** | **64** | **48** | **24** |
Findings:
- D7's "30 ally / 40 enemy" is **not** what runs. The data sets 36/36, and the engine ceiling was raised from 36 (M1) to 40 per side.
  Four places define caps with three different value sets. Request: one source of truth (data), with D7 and ENGINE.md updated to match.
- Pools are **lazy**. Projectile (`_new_projectile`, 959-969), fx (`_fx`, 971-989), text (`_text`, 991-1006) and unit objects
  (`_new_unit`, 926) are created the first time they are needed, i.e. in the middle of the first big fight. Afterwards they are reused
  (M1: 0 unexplained objects in steady state). Pool sizes are bounded by the caps above. The unit pool is bounded by the peak concurrent
  units (living + dying).
- Dying units stay in `players`/`enemies` for 0.7 s (`_kill` 769, reaped in `_reap_side` 904-916), so every per-unit loop also walks
  them. At high churn the arrays grow well beyond the cap: M1 counted 126 entries at 36/side with 22 respawns/s (an object count, not a timing).
- `caps.text` = 24 popups. `_damage` (760) creates one per hit; when the pool is full, the new text is dropped silently (fine for cost).

## 2. Candidates ranked by expected cost at caps (highest first)
| # | Where (committed line numbers) | What runs per frame / step | Why it matters on low-end | How 08 measures it |
|---|---|---|---|---|
| H1 | `battle_view.gd:230,232` (units), `201` (workers), `330` (projectiles), `349-350` (fx), `158-161` (bases) → `atlas.gd:136-143` `anim_frame` → `anim()` 120-133 + `frame()` 108-117 | Every drawn sprite builds **2 Dictionaries** (anim + frame) plus string-keyed lookups. A failed `play` lookup for fx tries `loop` too (a third). ≈ 90–110 sprites at caps → **~200 Dictionary allocations per frame ≈ 12 000/s** | M1 A/B: battle_view `_draw()` ≈ 2.2 ms/frame at caps on the desktop (contended), more than the sim step. Allocation-bound GDScript scales badly on little cores | `run_perf.ps1 -Frame` stress A/B view (frame avg shown vs hidden) in C11, + a micro-bench calling `Atlas.anim_frame` ×100 (to add) |
| H2 | `battle_view.gd:237`→`317-322` hp bars drawn between sprites; `245-247` `draw_set_transform` per flipped sprite (all enemies); `322` `Color("6fd36f")`/`Color("e5534b")` parse a hex string per bar | Untextured rects and transform changes interleaved with textured sprites break 2D batching; the hex parse runs per bar per frame | M1: draw calls p95 186 at caps vs 19 in the menu; the low-tier provisional target is ≤ 100 | `draw_calls` p95 from the frame probe at caps (same scene, same seed) |
| H3 | `battle_sim.gd:554,556,560,589,608,615,622,632` per-unit `u.def.range`, `float(u.def.speed)`, `str(u.def.get("attack_type"))`, `u.def.get("knockback")`, `u.def.get("projectile")` (twice on 622), `u.def.get("splash")` | Dictionary lookups + `str()`/`float()` conversions per unit per step (60/s) in the `units` section (68 % of the mirrored step in the 08:57 run after the sorted-lane fix; that run is INVALID/contaminated, share only indicative) | Branchy lookups on the hottest loop; ~72 units × 60 = 4 300 unit-steps/s | bench `sections.units` avg + cap-clash step avg (`perf_bench.gd`) via `ab_retest.ps1 -RequireQuiet` |
| H4 | `battle_sim.gd:638, 877, 973, 785, 800` `_cue(...)` with a `{...}` params literal; `789` builds `str(cue) + ":" + kind` | The params Dictionary and key String are allocated **before** the "already coalesced this step" check (790), so every shot, hit, explosion, death and base hit allocates 2 objects even when the cue is dropped | Hits/shots happen several times per step at caps | Count `_cue` calls per step in the bench (instrumented copy) and the step avg delta |
| H5 | `battle_view.gd:52-56` `_order.clear()` + `append` all units + `sort_custom(func(a, b): ...)` | A new lambda Callable every frame + O(n log n) sort with Callable calls | Callable dispatch per compare ≈ n log n ≈ 500 calls/frame at caps | Part of the H1 A/B; isolate with a micro-bench (sort of 80 units with lambda vs cached Callable) |
| H6 | `battle_view.gd:380-381` `draw_string_outline` + `draw_string` per damage text at size 8 with `ThemeDB.fallback_font` (`_font`, set in `setup`) | 2 text draws per text, ≤ 24 texts; size 8 is a separate glyph cache from the Galmuri UI sizes; the fallback font is not Galmuri | First-use glyph rasterisation (FONT_COST.md: +9 ms desktop per cold Korean string; digits are cheaper) and extra draw calls | Frame probe draw calls + first-hit frame spike; font probe case "fallback 8 px digits" (to add) |
| H7 | `battle_sim.gd:760` `str(int(dmg))`, `801` `str(int(amount))`, `784` `"+%d" % b` | One String per hit / base hit / bounty | Low per item, frequent at caps | Included in H3/H4 measurement |
| H8 | `battle_sim.gd:269,293,342,417,448,475,506,776,799,922` `events.append(["type", {...}])` | Array + Dictionary per event. `799` "shake" fires on **every hit to the player base**, so it is frequent during sieges | Moderate; `battle.gd:166-168` already swaps buffers (P3 done) | Bench with sieges at the player base (r06 stress), events per step |
| H9 | `battle.gd:143-149` counts alive projectiles and fx every frame for `Perf.counts` | 2 extra full loops over 64 + 48 slots per frame | Small, but redundant with sim-side counters | Removed-loop A/B in the frame probe (small) |
| H10 | `battle_sim.gd:851` `_step_projectiles` and `881/885` `_step_fx` walk all pool slots incl. dead; `960, 975, 993` linear free-slot scans | Bounded by caps (64 / 48 / 24) | Small; a free-list would make spawn O(1) | bench `sections.projectiles`, `sections.fx_text` |
| H11 | `battle_sim.gd:272-276` `army_count` O(n), called by `_step_spawns` 422 (every step while a spawn is due), `_step_ai` 464, `deploy`, `_step_boss_summon` 576, and `snapshot()` 1026 **inside the per-card loop** + 1041 (×7 scans every 0.1 s) | Repeated O(n) counts | Small (4 µs per call on desktop, M1) | `army_count_one_call` already in the bench |
| H12 | `battle_sim.gd:1021-1051` `snapshot()` at 10 Hz (~15 Dictionaries/Arrays) | M1: 0.04 ms p50 desktop | Low | `hud_snapshot` in the bench |
| H13 | `battle_view.gd:116` `Color(str(layer.clear_color))` per frame; `112` `atlas.frame()` per biome layer per frame (Dictionary) | 5 layers × 2 passes | Low | Part of H1 |

Not a problem (checked): `_sorted_into` (392-413) reuses persistent lane arrays (no per-step allocation); `_area_damage_side` no longer
duplicates (fdd4d86); `battle.gd` swaps the event buffer (P3); towers scan foes only when their cooldown fires (every 1.5 s).

## 3. Measurement plan (in the quiet window C11, same seeds, contamination monitor on)
1. Baseline at HEAD: `perf_bench.gd` (sections) and `run_perf.ps1 -Frame` (stress A/B view, draw calls, readability counts). The stress
   refill must be fixed first. Root cause found in this review: D18 set `enemy_ai.pool = []` in r01–r10, and `perf_frame_probe.gd _stress()`
   only refilled enemies from that pool, which explains the drop to ~40 units. **Fixed 16:10** (BASELINE §7.4: 36/36 reached in a functional check). In that run the sim did not step (open item).
2. After each 02 change: `ab_retest.ps1 -RequireQuiet` for sim items (H3, H4, H7, H8, H10, H11) and the frame probe for view items
   (H1, H2, H5, H6, H9, H13). Accept only VALID_QUIET runs.
3. Device: none attached. The H1/H2 effects are expected to be larger on Mali-G52/Adreno 610 class GPUs and little cores.

## 4. Status of H1–H13 after 02's 22d99ea (16:34; reviewed read-only with `git show`, **not timed**)
| Item | 22d99ea change | 08 static assessment | Still to measure (C11) |
|---|---|---|---|
| H1 | `Atlas.anim_rec()` returns a cached `AnimRec`, `rec_index()` returns an int; units, workers, bases, projectiles and fx use it (`atlas.gd` new block after `_load_texture`; `battle_view.gd` `_blit_rec`) | Per-sprite Dictionary **allocation removed**. What remains per sprite is 2 lookups (`_rec_cache.get`, `per.has`) on persistent dicts. Biome layers (≤ 5/frame) and the base static fallback still build `frame()` dicts | frame-probe view A/B at caps |
| H2 | hp bars queued and drawn after all sprites; flip via negative-width dest rect; bar colours const | Removes the per-sprite `draw_set_transform` and the hex parse. Bars now form one rect group. Draw-call reduction is **not yet measured**. The 3 typed bar arrays are cleared and refilled every frame (see H20) | draw calls p95 at caps |
| H5 | cached `_by_lane_y` Callable | Lambda allocation per frame removed; the sort itself remains | part of view A/B |
| caps | `Content.caps()` = one source (data), clamped to perf.gd ceilings; sim no longer has its own defaults | Resolves §1. D7 text still says 30/40 (01) | — |
| pools | `_prealloc_pools()` in `setup` (64 + 48 + 24 + ally+enemy+8 units) | Mid-fight allocation of pooled objects removed; the ~216 objects per battle start are now created during loading | battle start time (load hitch) |
| P2b | tie-break = lowest uid, whole tie group scanned | Behaviour equivalence reported by 02 with 08's `targeting_equivalence.gd` (EQUIVALENT 0/30); 08 has not re-run it yet | — |
| H3, H4, H6, H8–H13 | not changed | still open | as §2 |
New risk from 22d99ea:
- **H19** `battle_sim.gd` (22d99ea) lines 707-718 and 731-741: the neighbour scan no longer stops after 4 candidates. It stops only when
  `found >= 4 and d > best_d`, and it also walks past dying units without counting them. Stacked melee units at **identical x** (the
  P2b ties) make the tie group the scan length. In heavy stacking at caps this could move the cost back toward the linear scan.
  Measure: `perf_bench.gd` sections.units and the same-build `targeting_ab` in clash mode (which places units on 9 shared x offsets, so ties
  exist). Compare with the linear switch in C11.
- **H20** `battle_view.gd` `_hp_bar` / `_flush_bars`: `_bar_rects/_bar_fills/_bar_cols.append` per bar and `clear()` per frame. Typed-array
  `clear()` can free the buffer, so up to ~80 × 3 appends may re-grow it every frame. Low; a fixed-size buffer with a count avoids it.

## 5. 04 UI hot paths (committed HEAD files: hud.gd, hud_top.gd, touch_button.gd, ui_style.gd, upgrade_panel.gd at 6051b3c; banner 0590e7a)
No `Tween` and no per-frame node creation in these files. `hud._process` (427-433) only fades the toast/banner `modulate.a`. Canvas
commands are re-recorded only on `queue_redraw()`, so the cost is driven by **redraw frequency**:
| # | Where (HEAD) | What | Frequency | Low-end concern | How to measure |
|---|---|---|---|---|---|
| H14 | `hud.gd:400-412` `_on_wave_cleared` → `show_banner(UiText.t("banner.first_wave_cleared"))` at FONT_L 24 bold (`hud.gd:95-96`) | First-time Korean string at Bold 24: cold glyph rasterisation in the frame that shows the D16 "peak moment" banner | once per battle, at the most important moment | FONT_COST.md: Bold 24 cold toast +6.6 ms desktop, ×4 ≈ 26 ms on a mid phone (≥ 1 dropped frame exactly at the peak) | font probe case with this string; frame-probe spike at the first wave clear |
| H15 | `hud.gd:196-247` `_on_snapshot` | builds 2 Dictionaries (`by_id`, `skills_by`), and `queue_redraw()` on every card, skill, worker and move button + `top` even when nothing changed | 10 Hz (HudSnapshot) | ~12 controls re-record their whole `_draw` 10×/s | frame probe with the UI A/B (`--perf-ab-ui`) at caps; count redraws |
| H16 | `ui_style.gd:188-195` `fit_text` ellipsis loop (one `get_string_size` per removed char, O(n²)), called from `hud_top.gd:118` (wave text, `%d` formatting) and `134` (boss name), `upgrade_panel.gd:262, 285` | string measuring + formatting in `_draw` | 10 Hz in battle (hud_top) | only when text is too long; boss names on narrow screens | micro-bench of `fit_text` with a 20-char Korean string at 12 px |
| H17 | `ui_style.gd:322-327` `draw_number` draws every character twice (shadow + glyph) with per-char `get_char_size` | per redraw: gold, cap, income, base HP, army counts, card costs | 10 Hz | many small draw commands (same font texture, probably batched) | draw calls with the UI A/B |
| H18 | `touch_button.gd:140` `fit_lines` (wrap + measure) in every button `_draw` | per button redraw | 10 Hz × ~11 buttons in battle (because of H15) | repeated text measuring | same as H15 |
| H18b | `upgrade_panel.gd:154-167` `_layout` frees and recreates all buy buttons (`TouchButton.new`, `connect`); `_draw` 247-286 formats names and levels per row | on open, layout and page change only (menu screen) | low; not in battle | — |
Main fixes: redraw a button or `hud_top` only when its displayed values changed (H15/H18); pre-warm the glyph cache incl. the banner string
at 24 px bold (H14, extends 04 R5).
