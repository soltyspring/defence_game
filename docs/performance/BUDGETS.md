# BUDGETS.md — resource budget inventory and device tiers (owner: 08-performance)
Updated: 2026-10-31. Sources: docs/contracts/ENGINE.md §7–8 (02), docs/mobile/BUILD_PLAN.md §5 (04), docs/art/ATLAS_BUDGET.md (03),
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
| Battle sim step at caps (36/side) | ≤ 4 ms | ≤ 2 ms (ENGINE.md §7) | ≤ 2 ms | Desktop 1.07–1.72 ms avg, p95 1.66–3.04 ms (varies with machine load) | DESKTOP_PROXY | AT RISK: desktop already near the mid-tier phone budget |
| Battle sim step, normal rounds (bot) | ≤ 4 ms | ≤ 2 ms | — | Desktop avg 0.17–0.21 ms, p95 0.28–0.42 ms | DESKTOP_PROXY | OK on proxy |
| Draw calls in battle | ≤ 100 (provisional, low-end GLES3) | ≤ 200 | — | 19 menu; 93 at 3 units (04 HUD); 186–217 at caps (mixed atlas art and procedural placeholders) | DESKTOP_PROXY (count is renderer-side, transferable) | OVER low-tier target at caps |
| Total PSS | ≤ 250 MB | ≤ 300 MB | ≤ 350 MB | not measured (needs phone `dumpsys meminfo`) | — | UNMEASURED |
| Atlas texture residency (battle) | ≤ 32 MiB total textures | ≤ 48 MiB | ≤ 64 MiB | 5.25 MiB (6 pages, RGBA8 w×h×4; was 5.12 MiB before 03 grew `ui_main` to 256×256 at ~07:15); menu 0.25 MiB | STATIC | OK |
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
| Font runtime cost | glyph cache ≤ 4 MiB (provisional) | | | not measured (dynamic TTF glyph caches allocate on first use) | — | UNMEASURED |

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
