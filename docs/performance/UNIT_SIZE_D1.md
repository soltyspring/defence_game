# 32 px unit roster (03 A19, D1) — performance preview before any release decision

Owner: 08-performance. Measured 2026-11-01 01:17–01:56 KST on a clean copy of commit **676b105**. The shipped assets were not changed:
before and after each draft build, the working-tree `assets/atlases` hashes were identical.
**Evidence class: DESKTOP_PROXY** (Godot 4.7.2 debug binary, GL Compatibility, RTX 2070 SUPER, 1280×720 window on the secondary monitor).
**This is not a phone measurement.** Phone CPU, GPU fill rate and memory pressure are unmeasured, and the desktop GPU hides
fill-rate costs (see §3).

## 1. What was built
`tools/perf/art_variant_ab.ps1` (inside `coordination/heavy_run.ps1`) makes two `git archive` copies of 676b105:
- **base:** the committed assets.
- **draft:** the same copy after `ART_DRAFT32=D1FULL python tools/art/build.py`, i.e. 03's full D1 roster (round 17). The draft build
  changes two pages: `char_player` and `ui_main` (the card icons are drawn from the unit sprites). `ui_main` stays 256×256.

`ART_DRAFT32=D1` (only 식빵병 and 곰팡이 졸개 at the D1 size) was built the same way for the static check only.

## 2. Memory (static, `asset_budget_check.py --tree <copy> --base 676b105`)
| Copy | char_player page | Worst battle | All pages | Menu | Atlas PNG on disk | Verdict |
|---|---|---|---|---|---|---|
| base (shipped) | 1024×512, occupancy 0.60 | 8.75 MiB | 9.00 MiB | 0.50 MiB | 86.0 KiB | PASS |
| ART_DRAFT32=D1 (2 units only) | 1024×1024, occupancy 0.35 | **10.75 MiB** | 11.00 MiB | 0.50 MiB | 90.3 KiB | PASS |
| ART_DRAFT32=D1FULL (03's proposal) | 1024×1024, occupancy 0.60 | **10.75 MiB** | 11.00 MiB | 0.50 MiB | 100.2 KiB | PASS |
| caps (RETHEME_BUDGET.md) | | ≤ 12 MiB | ≤ 14 MiB | ≤ 0.5 MiB | | |

- **Same as 03's estimate** (10.75 / 11.00 / 0.50 MiB). The whole +2.0 MiB comes from one page doubling: 1024×512 RGBA8 = 2 MiB →
  1024×1024 = 4 MiB. All the regular units live on that page in every battle (`load_policy: battle`).
- Even the 2-unit `D1` already doubles the page, because the shipped page is 60 % full and the bigger frames no longer fit 1024×512.
  So a partial adoption saves no memory, and the full roster fits the doubled page at the same 60 % occupancy.
- Headroom after D1FULL: worst battle 1.25 MiB under the cap. One more 512×512 page (1 MiB) would still pass, and one more 1024×512
  page (2 MiB) would fail.

## 3. r08 at caps, same seed (perf_drawcall_probe.gd `--dc-set=units --dc-uncapped`)
Same commit, same round data and seed (autoplay uses the data's deterministic seed). Stress cheat holds 36/36 (73 units). Two
interleaved pairs: base, draft, base, draft. Each run alternates 3 s phases: whole frame / battle view without HUD / view without
unit sprites, 6 cycles, first 0.5 s of each phase skipped. vsync off and `max_fps = 0` (the probe holds it, because the Perf autoload
re-applies the 60 fps cap after boot; the first attempt at 01:17 was capped at 16.67 ms, so its frame times were discarded).
**Contention:** run base_1 overlapped two foreign headless Godot processes, which the coordination log explains (10's and 01's jobs,
01:47–01:50, outside or overlapping the lock). base_1 is therefore CONTAMINATED. The table uses the 3 CLEAN runs; base_1 is shown for
reference only.

| Metric (per frame at caps) | base_2 (CLEAN) | draft_1 (CLEAN) | draft_2 (CLEAN) | base_1 (CONTAMINATED) |
|---|---|---|---|---|
| draw calls, whole frame / battle view / view without units | 134 / 9 / 9 | 134 / 9 / 9 | 134 / 9 / 9 | 134 / 9 / 9 |
| frame time p50 / mean / p95, ms (whole frame, uncapped) | 2.125 / 2.227 / 2.778 | 2.083 / 2.199 / 2.717 | 2.381 / 2.307 / 3.015 | 2.205 / 2.255 / 2.778 |
| unit cost, ms (view mean − view-without-units mean) | 0.577 | 0.621 | 0.659 | 0.555 |
| unit `_draw_unit` CPU recording, µs p50 | 429 | 429 | 434 | 432 |
| battle view GPU, ms p50 | 0.095 | 0.098 | 0.096 | 0.097 |
| unit quad area drawn, view px p50 | 100 864 | 202 932 | 210 996 | 101 504 |

Reading:
- **Draw calls: no change** (+0). D1FULL stays on one character page.
- **Whole frame: no difference above noise.** The two draft runs bracket the clean base (p50 −0.04 / +0.26 ms, mean −0.03 / +0.08 ms).
- **Unit cost: +0.04 to +0.08 ms (+8 to +14 %)** on this PC. The GDScript recording cost is unchanged (the same number of draw
  commands), so the extra cost is in rendering larger quads.
- **Unit quad area ×2.0–2.1** (101 k → 203–211 k view px per frame). The RTX 2070 does not show it (GPU 0.095 vs 0.096–0.098 ms). On a
  phone the view is scaled about 3× (04's 800×360 view on a 2400×1080 screen), so the area is about 9× larger in screen pixels: base
  ≈ 0.9 Mpx and D1FULL ≈ 1.9 Mpx of alpha-blended sprite fill per frame, with the full screen at 2.6 Mpx. This is an estimate from
  the quad sizes, not a measurement. It is the one cost that can only be judged on a low-end phone (fill rate), which we have not got.

## 4. Verdict for the decision (desktop only)
D1FULL does not break the desktop budgets: memory 10.75 / 11.00 / 0.50 MiB PASS (= 03's estimate), draw calls unchanged, frame time
within noise. The open risk is GPU fill on low-end phones (≈ 2× unit sprite area). Before release, check on a real low-end device: the
r08 caps scene, frame pacing and GPU time with both builds (ANDROID_PROFILING.md §4). That needs 02's P10 perf APK with baked args.

## 5. Reproduce
```
& .\coordination\heavy_run.ps1 -Label '08-art-d1-ab' -Script { & .\tools\perf\art_variant_ab.ps1 -Rev 676b105 -Draft D1FULL -Pairs 2 }
```
Output (git-ignored): `build/perf/artab_676b105_D1FULL_20261101-014838/` (summary.json, summary.md, run_*.json, gate_*), the 2-unit
static check `build/perf/artab_676b105_D1_gate/`, and the discarded capped attempt `build/perf/artab_676b105_D1FULL_20261101-011732/`.
