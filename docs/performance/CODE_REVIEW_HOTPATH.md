# CODE_REVIEW_HOTPATH.md — per-frame allocations, entity caps and full scans in the battle loop (owner: 08-performance)
Updated: 2026-10-31 16:4x +09:00. Method: **static code review only (no Godot run)**, because the coordinator has not opened the quiet
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
   only refilled enemies from that pool, which explains the drop to ~40 units. Fix it in the 08 probe (use `Content.round_enemy_roster`)
   before the window.
2. After each 02 change: `ab_retest.ps1 -RequireQuiet` for sim items (H3, H4, H7, H8, H10, H11) and the frame probe for view items
   (H1, H2, H5, H6, H9, H13). Accept only VALID_QUIET runs.
3. Device: none attached. The H1/H2 effects are expected to be larger on Mali-G52/Adreno 610 class GPUs and little cores.
