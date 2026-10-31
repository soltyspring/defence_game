# ENGINE.md — engine selection and project contract (owner: 02-engine)
Version: 1.0 (2026-10-31). Changes are announced in coordination/requests/02-engine-to-*.md.

## 1. Decision
**Godot 4.7.2-stable (official build `4.7.2.stable.official.ed1daf0bf`), GDScript, Compatibility renderer (OpenGL ES 3.0 / WebGL2 class).**

Evidence gathered on this machine (2026-10-31):
- No engine was installed. Official GitHub release list: latest stable = `4.7.2-stable` (2026-08-18); 4.8 is beta only, so it is rejected.
- Downloaded `Godot_v4.7.2-stable_win64.exe.zip` from github.com/godotengine/godot releases, SHA-512 matched the official `SHA512-SUMS.txt` (`match=True`), extracted to `tools/engine/` in self-contained mode (`_sc_` file), `--version` prints `4.7.2.stable.official.ed1daf0bf`.
- Android SDK present at `%LOCALAPPDATA%\Android\Sdk`: platform-tools (adb), build-tools 35.0.0/36.0.0/36.1.0, platforms android-35/36, NDK 27.1, cmake. **cmdline-tools missing** (only needed for Gradle/AAB builds). Java: Oracle JDK 25.0.2 (Godot docs: JDK 17 recommended, higher supported).
- Alternatives considered: Unity/Unreal (not installed, licence/account and large install, heavier APK); Defold (fine for 2D but no local install, smaller ecosystem for our team); web/Capacitor (not native, worse frame pacing). Godot gives a free, open, portable editor, a headless CLI for automated checks, first-party Android export, small runtime (~25–35 MB APK class), and pixel-perfect 2D.

Why Compatibility renderer: widest low-end Android GPU coverage (GLES3), lower driver risk and lower power use than Vulkan Mobile for a pure 2D sprite game. Reversible via one project setting.

## 2. Tool locations (02-owned, not committed: see .gitignore)
| Item | Path |
|---|---|
| Editor (GUI) | `tools/engine/Godot_v4.7.2-stable_win64.exe` |
| Editor (console, for CI/headless) | `tools/engine/Godot_v4.7.2-stable_win64_console.exe` |
| Self-contained editor data/settings | `tools/engine/editor_data/` (created by the `_sc_` marker) |
| Export templates | `tools/engine/editor_data/export_templates/4.7.2.stable/` (installed from the official .tpz) |
| Downloads + checksums | `tools/engine/dl/` |

## 3. Exact commands (PowerShell, from workspace root)
```powershell
$G = ".\tools\engine\Godot_v4.7.2-stable_win64_console.exe"
& $G --headless --path . --import                       # import assets / build .godot cache
& $G --headless --path . --check-only --script res://src/core/app.gd   # parser check of one script
& $G --headless --path . -s res://src/core/diag/selftest.gd           # all-script parse + headless battle sims (exit code 0 = pass)
& $G --path .                                            # run the game windowed (local preview, 1280x720)
& $G --path . -e                                         # open editor
& $G --headless --path . --export-debug "Android" build/android/defence-debug.apk   # Android debug APK
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r build/android/defence-debug.apk
```
Android release (AAB, Play) path: 04 owns `tools/build/**` scripts, signing (keystore + passwords via env vars `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`, never in source), and gradle build setup. Requirements tracked in docs/architecture/ANDROID_BUILD.md.

## 4. Project settings (project.godot, 02-owned)
- Main scene: `res://scenes/gameplay/main.tscn` (bootstrap + router).
- Base viewport **640×360** landscape (`sensor_landscape`), stretch mode `canvas_items`, aspect `expand` (wide phones show more lane, UI anchors to safe area). Window test size 1280×720.
- Default texture filter **Nearest**, `snap_2d_transforms_to_pixel=true`, `snap_2d_vertices_to_pixel=true`. No mipmaps on 2D textures.
- Renderer: `gl_compatibility` (desktop + mobile).
- Physics engine is not used for combat (custom 1-D lane simulation). Physics ticks 60.
- Max FPS 60; low tier toggle 30 (settings). `application/run/low_processor_mode` used in menus only through code.
- Autoloads (all 02-owned in src/core): `Events` (signal bus), `Content` (data + fallbacks), `Atlas` (atlas manifest loader/cache), `Save` (progress/save), `App` (router/lifecycle), `Perf` (budgets/caps/diagnostics).

## 5. Folder layout and ownership
```
project.godot, export_presets.cfg, .gitignore, icon.svg   02 (root config)
src/core/**          02  autoloads: events.gd, content.gd, atlas.gd, save.gd, app.gd, perf.gd, diag/**
src/gameplay/**      02  battle sim, units, bases, hero, skills, waves, enemy AI, fallback HUD/menus
scenes/gameplay/**   02  main.tscn, battle.tscn
src/ui/**, scenes/ui/**  04  HUD, menus, result, settings (consume INTERFACES.md signals)
assets/**            03  assets/manifest.json, assets/atlases/*.png + *.json, audio later
data/**              01  data/units/*.json, data/heroes/*.json, data/skills/*.json, data/rounds/*.json, data/economy.json
tests/**, tools/build/**, docs/qa/**, docs/mobile/**   04
tools/engine/**      02  engine binaries (git-ignored)
docs/contracts/**, docs/architecture/**  02
```

## 6. Integration rules
- Engine loads UI scenes from fixed paths if they exist, otherwise uses 02 fallback UI (src/gameplay/fallback_*.gd):
  - `res://scenes/ui/main_menu.tscn`, `res://scenes/ui/round_select.tscn`, `res://scenes/ui/hud.tscn`, `res://scenes/ui/result.tscn`.
  - UI scenes talk ONLY through the `Events` autoload (see INTERFACES.md). They never reach into gameplay nodes.
- Content (data/**) is read as JSON via `Content`; missing/invalid files fall back to built-in defaults and log a warning (never crash).
- Art is resolved via `Atlas` from `assets/manifest.json`; missing atlas/anim → procedural placeholder shapes.
- No worker edits another owner's file; request changes via coordination/requests.

## 7. Runtime budgets (PROVISIONAL — joint with 04, to be replaced by profiling evidence)
| Tier | Example class | Target | RAM total | Texture residency |
|---|---|---|---|---|
| Low | 2–3 GB RAM, Mali-G52 / Adreno 610, Android 9+ | 30 fps locked option, 60 attempted | ≤ 250 MB PSS | ≤ 32 MB GPU |
| Mid | 4–6 GB, Adreno 6xx/Mali-G7x | 60 fps, p95 frame ≤ 20 ms | ≤ 300 MB | ≤ 48 MB |
| High | 8 GB+ | 60 fps (120 not targeted) | ≤ 350 MB | ≤ 64 MB |
- Entity caps (enforced in code): ONE source = data `game_config.caps` (01) read through `Content.caps()`, clamped by engine hard ceilings in `Perf` (40 per side, 64 projectiles, 48 fx, 24 floating text). Effective 2026-10-31: 36 ally / 36 enemy / 64 projectiles / 48 fx / 24 texts (D7's "30/40" is outdated; 01 to update D7). Ally over cap → deploy refused (`army_full`, not charged); enemy over cap → queued. Pools for projectiles/fx/texts/units are preallocated to these caps at battle setup.
- Object pooling for units, projectiles, fx, floating text. No per-frame allocations in the battle loop beyond pooled reuse.
- Simulation: fixed step 1/60 s with accumulator, max 4 steps/frame (spiral-of-death guard). Seeded RNG per battle for deterministic headless tests.
- CPU target: battle sim ≤ 2 ms/frame on mid tier at cap. Measured via `Perf` in headless sims (desktop numbers are only a proxy; device numbers required before release).
- Download size target: APK ≤ 60 MB (provisional), assets ≤ 20 MB.
- Lifecycle: on `NOTIFICATION_APPLICATION_PAUSED` / focus out → battle auto-pauses and progress is saved; on resume stays paused until user taps resume. Save written atomically (tmp → rename) with `.bak` rollback and schema `version` for migration.

## 8. Texture/atlas rules (shared with 03; details in INTERFACES.md §5)
- Pixel art imported **lossless** (VRAM compression off — ETC2/ASTC smear pixel art), filter nearest, mipmaps off, repeat off.
- Max atlas page **1024×1024** preferred, hard limit 2048×2048. RGBA8 GPU cost = w×h×4 bytes (1024² = 4 MiB, 2048² = 16 MiB).
- Atlases grouped and loaded per need: `ui_*` (always), `char_<faction>` (by round roster), `fx_combat`, `biome_<id>` (per round). `Atlas.acquire(id)/release(id)` with refcount; battle scene releases biome/character pages on exit.
- Padding ≥ 2 px with 1 px edge extrusion, frame pivot = feet (bottom-centre) unless stated.
