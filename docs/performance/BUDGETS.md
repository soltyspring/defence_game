# BUDGETS.md — resource budget inventory and device tiers (owner: 08-performance)
Updated: 2026-10-31 09:20. Sources: docs/contracts/ENGINE.md §7–8 (02), docs/mobile/BUILD_PLAN.md §5 (04), docs/art/ATLAS_BUDGET.md (03),
measurements in docs/performance/BASELINE_DESKTOP.md and docs/performance/RESOURCE_INVENTORY.md (generated).

Every budget below is **PROVISIONAL** until a physical phone of that tier has been measured with
docs/performance/ANDROID_PROFILING.md. Evidence classes used everywhere:
- **STATIC**: computed from files on disk (PNG headers, WAV headers, APK zip). Exact for what it measures.
- **DESKTOP_PROXY**: measured on the Windows dev PC (i7-9700K, RTX 2070 SUPER, DEBUG editor binary, other workers' processes running). Shows relative cost and scaling only. Never a phone claim.
- **DEVICE**: captured by `tools/perf/android_capture.ps1` on a named physical phone, raw adb output kept. **No DEVICE evidence exists yet** (no phone attached; `adb devices` empty on 2026-10-31).
- **EMULATOR**: not phone evidence (SwiftShader GPU, x86_64 host CPU).

## 1. Device tiers (PROVISIONAL classes; example models are class examples, not tested devices)
| Tier | Definition | Class examples (not yet tested) | Target |
|---|---|---|---|
| Low | 3–4 GB RAM, Mali-G52 / Adreno 610 class GPU, 4×A53/A55 little cores + 2–4 big cores, 720p–1080p screen, Android 9+ | Galaxy A13 (Exynos 850, Mali-G52 MP1), Redmi Note 8 (Snapdragon 665, Adreno 610) | 30 fps mode stable, 60 fps attempted |
| Mid | 4–6 GB, Adreno 618–6xx / Mali-G68–G78 | Galaxy A52 4G (Snapdragon 720G, Adreno 618), Pixel 6a (Tensor, Mali-G78) | 60 fps, p95 frame ≤ 20 ms |
| High | 8 GB+, current flagship GPU | Galaxy S23 (Snapdragon 8 Gen 2) | 60 fps (120 Hz not targeted) |
Note: export preset min SDK is still unset (`gradle_build/min_sdk=""`) and BUILD_PLAN proposes 24 (Android 7). If 7–8 stay installable, the low-tier test must include the oldest supported Android version.

## 2. Budget table (target vs current measurement)
| Metric | Low | Mid | High | Current measurement | Class | Status |
|---|---|---|---|---|---|---|
| Frame time | 30 fps: p95 ≤ 36 ms | 60 fps: p95 ≤ 20 ms | 60 fps | Desktop paced r06 autoplay: 16.67 ms p95 (vsync 60). Desktop uncapped at 36/side caps: ~3.7 ms/frame avg (view drawn) | DESKTOP_PROXY | UNMEASURED on phone |
| Frame CPU at caps (sim + draw + engine) | ≤ 33 ms | ≤ 16 ms (leave GPU/OS headroom: aim ≤ 12 ms) | — | Desktop: ~1.0 engine base + ~1.0–1.7 sim step + ~2.3 battle_view._draw ≈ 4.3–5 ms | DESKTOP_PROXY | AT RISK: ×4 assumed phone slowdown → ~17–20 ms mid tier |
| Battle sim step at caps (36/side) | ≤ 4 ms | ≤ 2 ms (ENGINE.md §7) | ≤ 2 ms | **C11 quiet desktop (18:00, HEAD 8d026d2): avg 0.59 ms, p95 0.71 ms** (linear-scan base 0.93 / 1.04 ms) | DESKTOP_PROXY (quiet, debug binary) | Desktop OK; phone unmeasured (×4 assumption → ≈ 2.4 ms avg = over mid-tier 2 ms) |
| Battle sim step, normal rounds (bot) | ≤ 4 ms | ≤ 2 ms | — | Desktop avg 0.17–0.21 ms, p95 0.28–0.42 ms | DESKTOP_PROXY | OK on proxy |
| Draw calls in battle | ≤ 100 (provisional, low-end GLES3) | ≤ 200 | — | C11 quiet: p95 177–182 at caps (36/36), 110 p95 in plain r01. **Breakdown r08 at caps (DRAWCALLS.md): units 50–54 (atlas-page runs), HUD ≈ 100 (hud_top 48–50, cards 7–11 each), everything else ≤ 9** | DESKTOP_PROXY (count is renderer-side) | OVER low-tier target at caps; fixes requested (02 P9, 03 A9, 04 R8) |
| Total PSS | ≤ 250 MB | ≤ 300 MB | ≤ 350 MB | not measured (needs phone `dumpsys meminfo`) | — | UNMEASURED |
| Atlas texture residency (battle) | ≤ 32 MiB total textures | ≤ 48 MiB | ≤ 64 MiB | 09:20 (10 pages incl. 03 roster/boss pages, working tree): 5.25 MiB r01–r03, 6.25–7.25 MiB r04–r09, 9.25 MiB r10 (both bosses); menu 0.25 MiB. Engine now acquires the round roster only (02 e9dfaa4, P6) | STATIC | OK |
| All renderer texture memory (`RENDER_TEXTURE_MEM_USED`) | ≤ 32 MiB | ≤ 48 MiB | ≤ 64 MiB | 13.1 MiB menu, 15.1 MiB peak in battle at a 1280×720 window (includes render targets, fonts, engine defaults) | DESKTOP_PROXY | OK on proxy; render targets scale with phone resolution |
| SFX decoded RAM | ≤ 8 MiB | ≤ 12 MiB | — | 0.76 MiB PCM (29 WAV, 22.05 kHz mono s16) | STATIC | OK |
| Music | streamed, ≤ 2 tracks open | | | 2 OGG, 0.53 MiB on disk | STATIC | OK |
| Entity caps | 36/side units, 64 projectiles, 48 fx, 24 texts (Perf.gd hard caps; data caps 36/36/64/48/24) | | | stress harness holds 36/side; pools stop growing at caps; 0 unexplained objects | DESKTOP_PROXY | OK (pooling verified) |
| Per-frame allocations in battle loop | 0 beyond pools (ENGINE.md §7) | | | Unit/projectile/fx/text objects: 0 created at steady state. GDScript Dictionary/Array/String temporaries still created per step and per drawn sprite (see BASELINE §5) | DESKTOP_PROXY + code review | PARTIAL |
| Leak across battles | 0 objects retained | | | 0 objects after 5 full battles (headless) | DESKTOP_PROXY | OK on proxy |
| Content load | ≤ 500 ms | ≤ 200 ms | — | 16–54 ms first load (JSON) | DESKTOP_PROXY | OK on proxy |
| Save (atomic write + verify + rename) | ≤ 50 ms p95 | ≤ 30 ms | — | p50 12 ms, p95 16–42 ms (NTFS SSD, busy machine) | DESKTOP_PROXY | WATCH: phone flash + fsync unmeasured; it runs on the main thread during pause/settings |
| Save load | ≤ 20 ms | | | p50 0.9–1.1 ms | DESKTOP_PROXY | OK on proxy |
| Cold start to menu | ≤ 4 s | ≤ 2.5 s | — | not measured | — | UNMEASURED (`am start -S -W`) |
| Battery | ≤ 8 % / 30 min at 60 fps, fixed brightness | | | not measured | — | UNMEASURED |
| Thermal | no status ≥ 3 (severe) in a 15–20 min cap soak | | | not measured | — | UNMEASURED |
| APK size | ≤ 60 MB | | | debug APK 55.30 MiB (04, 07:07): native libs 54.6 MB compressed, x86_64 28.2 MB + arm64-v8a 25.5 MB; game content ~1 MB | STATIC | AT RISK: universal APK carries x86_64; release-template/AAB size unmeasured |
| Source assets on disk | ≤ 20 MB | | | 4.52 MiB (incl. 3.09 MiB Galmuri TTF fonts added ~07:15) | STATIC | OK |
| Re-theme caps (theme A) | worst battle atlas ≤ 12 MiB, all pages ≤ 14 MiB, SFX PCM ≤ 2 MiB, music ≤ 1.5 MiB, APK content +≤ 2 MiB | | | baseline 37b9a93: 9.25 / 9.25 / 0.76 / 0.53 MiB, APK content 1.95 MiB (stale 07:23 APK) | STATIC | set; checked by tools/perf/retheme_compare.py (RETHEME_BUDGET.md) |
| Font glyph cache (memory) | ≤ 4 MiB (provisional) | | | ≤ 2.25 MiB for all ko.json text in every used size (LA8 pages: 128 KiB per 256², 512 KiB per 512²) | CONTENDED_DESKTOP_PROXY (exact byte counts) | OK |
| Font first-use hitch | ≤ 1 frame budget at 60 fps (provisional) | | | +9.4 ms desktop for a first-time 12 px Korean toast; +9–18 ms for a whole cold screen per size (FONT_COST.md) | CONTENDED_DESKTOP_PROXY | AT RISK on phone; pre-warm requested from 04 (R5) |

## 3. Assumptions that must be replaced by device data
1. Desktop→mid-tier GDScript slowdown **×4** (used only to derive desktop proxy gates: 2 ms / 4 = 0.5 ms). Uncalibrated. Calibrate by running the same headless bench workload on a device (request to 02/04: perf export preset, see coordination/requests/08-performance-to-02-engine.md).
2. The editor console binary is a DEBUG build. Release export templates run GDScript faster; no release-template desktop number exists yet because export templates are not installed (tools/engine/editor_data/export_templates/4.7.2.stable is empty at 2026-10-31 07:00).
3. Lossless (non-VRAM-compressed) textures cost w×h×4 bytes of GPU memory with no CPU copy kept by Godot. GLES drivers may still keep shadow copies, visible as `Graphics`/`GL mtrack` in `dumpsys meminfo`. Verify on device.
4. Desktop timings were taken with 4–8 other Godot/CLI processes active; the bench reports a noise floor (`report.noise`) and best-of-3 p95 for the scaling curve. Single-step max values of 15–80 ms seen in round runs coincide with no extra sim work (no events, ordinary unit counts) and are attributed to OS preemption, not to the sim, until reproduced on a quiet machine or device.

## 4. Who owns which lever
| Budget | Owner of the fix | 08 role |
|---|---|---|
| sim step, battle_view draw cost, draw calls, save latency, residency release, export filters | 02-engine | measure, request, re-measure |
| atlas page sizes, occupancy, future pages for missing anim sets, import settings | 03-art | inventory, residency plan |
| HUD cost, debug overlay, build/export pipeline, APK/AAB, device install | 04-client | measure HUD (A/B), APK breakdown, device procedure |
| audio memory/streaming | 05-audio | inventory |
| entity caps / round composition (data) | 01-director | report cap pressure (refused spawns) |
