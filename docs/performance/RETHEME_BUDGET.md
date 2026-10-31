# RETHEME_BUDGET.md — texture / audio / APK baseline before the theme change and caps for 03 and 05 (owner: 08-performance)
Updated: 2026-10-31 15:50 +09:00. Trigger: user decision Q1 = A "빵집 기사단 vs 곰팡이 군단" (coordinator-to-08, 09:03 KST).
03 re-draws the atlases, 05 replaces the audio. Evidence class: **STATIC** (PNG/WAV headers and zip listing; exact). No device data.
These are memory/download numbers only; frame cost of the new art is measured separately (BASELINE_DESKTOP.md).

## 1. Baseline (pre-retheme, committed tree)
Source: `docs/performance/baselines/retheme_before_37b9a93.json` = `tools/perf/budget_inventory.py` run on a `git archive HEAD`
snapshot at 37b9a93 (15:4x). The last commit touching `assets/` before it is d6cf7df (09:14). The shared working tree already holds
03/05 WIP (modified atlases, two new SFX), so that WIP is deliberately **not** in the baseline.

| Item | Baseline | Notes |
|---|---|---|
| Atlas pages | 10 | char_player 512², char_enemy 512×256, char_player_adv 512×256, char_enemy_adv 512×256, char_boss_warlord 512², char_boss_overlord 1024×512, bases 512², fx_combat 512×256, ui_main 256², biome_meadow 1024×512 |
| Atlas GPU, all pages (RGBA8 w×h×4, no mips) | 9.25 MiB | 4.96 MiB of it unused page area (occupancy 0.35–0.58) |
| Atlas GPU per battle (roster residency, battle.gd) | r01–r03 5.25 · r04, r06–r09 6.25 · r05 7.25 · r10 9.25 MiB | worst = r10 (both bosses) |
| Atlas GPU in menus | 0.25 MiB | ui_main only |
| Atlas PNG on disk | 72.3 KiB | 8-bit indexed PNG |
| SFX | 29 WAV, 22.05 kHz mono s16, 0.76 MiB decoded PCM (upper bound of RAM), longest 3.0 s (stinger_defeat) | Godot stores them as `.sample` (172 KB total on disk in .godot/imported) |
| Music | 2 OGG streams, 0.53 MiB | streamed, not decoded into RAM |
| Audio on disk total | 1.29 MiB | |
| Fonts (unchanged by the theme) | 3.09 MiB TTF on disk; glyph caches ≤ 2.25 MiB in RAM/VRAM (FONT_COST.md) | |
| Debug APK | 56.29 MiB = 54.6 MB native libs (arm64 + x86_64) + 2.16 MB dex + **1.95 MiB game content** (`assets/`) | **Built 07:23 by 04, so it is older than the 09:14 art and 09:18 engine commits.** Fresh before/after APKs requested from 04 (§4) |

## 2. Why these caps (low-tier budget arithmetic, provisional)
Low tier texture budget is 32 MiB total (ENGINE.md §7). Already used outside atlases, measured on desktop: engine + render targets
10.3–13.1 MiB in menus at 1280×720 (a 2400×1080 phone adds ≈ +5 MiB per extra full-screen buffer); glyph caches ≤ 2.25 MiB.
32 − 13 − 2.25 − ~4.75 MiB safety margin for phone render targets ≈ **12 MiB for atlases in the worst battle**.
APK: 60 MiB provisional limit, already 56.29 MiB in the stale debug build, so game content may grow by **at most 2 MiB compressed**.

## 3. Caps for the re-theme (checked by `python tools/perf/retheme_compare.py [--strict]`)
| Metric | Cap | Baseline | Owner |
|---|---|---|---|
| Atlas GPU, worst battle | ≤ 12 MiB | 9.25 MiB | 03 |
| Atlas GPU, menus | ≤ 0.5 MiB | 0.25 MiB | 03 |
| Atlas GPU, all pages | ≤ 14 MiB | 9.25 MiB | 03 |
| Largest page side | ≤ 1024 px (no new 2048 pages) | 1024 | 03 |
| Atlas PNG on disk | ≤ 1 MiB | 72.3 KiB | 03 |
| SFX decoded PCM | ≤ 2 MiB | 0.76 MiB | 05 |
| SFX file count | ≤ 48 | 29 | 05 |
| Longest SFX | ≤ 3.5 s (longer = music/stream) | 3.0 s | 05 |
| Music streams | ≤ 4 tracks, ≤ 1.5 MiB total, at most 2 open at once | 2, 0.53 MiB | 05 |
| Audio on disk | ≤ 3 MiB | 1.29 MiB | 05 |
| APK total (debug universal) | ≤ 60 MiB | 56.29 MiB (stale build) | 04 build, 03/05 content |
| APK game content growth | ≤ +2 MiB compressed vs the pre-retheme APK | 1.95 MiB | 03/05 |
Preferred: keep every existing page size and frame rect (03 already keys layout locks by frame name) so the change is pixels only and the
GPU numbers stay identical. Any page size change, new page or new load group: tell 08 before building.

## 4. After the re-theme
1. 03/05 commit their assets; 04 builds a debug APK at the pre-retheme commit and again after (same preset), or names both files.
2. `python tools/perf/retheme_compare.py --strict` (or `--after <inventory.json>`) → `RETHEME caps=PASS|FAIL`; per-round table in
   `build/perf/retheme_after/retheme_compare.json`. If the APK file is unchanged the tool prints that the APK rows are not evidence.
3. 08 records the after-numbers in §5 and re-runs the frame probe for draw cost (the new art may change occupancy and placeholder use).

## 5. After-numbers
Not measured yet (re-theme assets not committed at 15:50). A check at 15:4x on the shared working tree (03/05 WIP) gave caps=PASS
with unchanged page sizes and 2 extra SFX (hit_melee_4/5); this is WIP, not a result.
