# 10-research-systems → 08-performance

## v0.26 (2026-10-31 ~19:12 KST): perf runs write the REAL user folder (P1)
Evidence: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.17.
- Godot resolves user:// from %APPDATA% plus `config/name` ("Lane Defence").
- `perf_bench.gd` moves Save to `user://perf/` only after boot. By then the Save autoload has already loaded, and possibly rewritten, the real save.json: X1 rewrites it after any data change, and X3 clamps levels when the data is being edited.
- Your snapshots also keep the project name.
Change (your files; I did not edit them):
1. `tools/perf/run_perf.ps1` lines 44/49/95/117–123 and `tests/performance/test_bench_semantics.ps1` line 26 (`--path .`): set a private `$env:APPDATA` around each Godot call (restore after), or use `docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(...)`.
2. `tools/perf/ab_retest.ps1` lines 77/81 and `tools/perf/c11_window.ps1` lines 61/97/116/128/130: in the snapshot's project.godot set `config/name="perf08 snapshot"`, or use a private APPDATA.
Note for measurement windows: a private APPDATA also keeps other workers' boot writes out of your timing runs.
Check: the run's `godot.log` exists under the private folder.

## v0.34 (~07:40 KST 11-01): four perf scripts archive CRLF data on this PC (low risk); SwiftShader uniform limit FYI
Source: DATA_AND_BACKEND_ANALYSIS.md §9.26 (3).
- These calls have no line-ending flags:
  - `tools/perf/ab_retest.ps1:36`
  - `art_variant_ab.ps1:42`
  - `drawcall_run.ps1:53`
  - `c11_window.ps1:87`
  - `asset_budget_check.py:78`
- This PC has `core.autocrlf=true` and no .gitattributes, so the snapshots hold CRLF data.
  - Effect on perf numbers: negligible (JSON parse size +2,758 B of 66,187 B).
  - The snapshots do get a different content_version from the APK/AAB.
  - For `asset_budget_check.py`, only text files grow; images and audio are binary and unchanged.
- Suggested fix (your files): `git -c core.autocrlf=false -c core.eol=lf archive ...`, as in `tools/build/build_android_debug.ps1:25`.
- FYI: on the emulator with SwiftShader, Godot's GLES3 scene and canvas shaders failed to link: fragment uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261). The frame was blank. I did not check real phone GPU limits; this is for your device-coverage notes.

## v0.35 (~08:00 KST 11-01): the SwiftShader shader-link failure — risk on real phones and how to check it
Source: DATA_AND_BACKEND_ANALYSIS.md §9.27 (3).
- **What failed (fact):** Godot's built-in shaders, not ours.
  - The project has no `.gdshader`, `ShaderMaterial` or `CanvasItemMaterial`; the renderer is `gl_compatibility` for desktop and mobile.
  - logcat showed `SceneShaderGLES3` ×4 at engine start and `CanvasShaderGLES3` ×1 at the first 2D draw: `Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`, on `OpenGL ES 3.0 SwiftShader 4.0.0.1`. The frame was blank.
- **Limits:** GLSL ES 3.x minimum is 224 (Khronos OpenGL-API issue #59), so SwiftShader's 261 is a legal value. In Godot 4.7.2 `canvas.glsl`, the fragment default block holds only 7 samplers and 2 uints. The big arrays (`LightData` Light[MAX_LIGHTS], `GlobalShaderUniformData`, `CanvasData`) are uniform blocks.
- **Judgement:**
  - Inference, medium confidence: low risk on hardware-GPU phones. Uniform-block members are a separate limit, and 06's host-GPU emulator run had 0 such errors.
  - Inference, high confidence: Play pre-launch / Test Lab virtual devices that use SwiftShader will show blank screens. Godot issue #109550 reports the same message from Play testing.
  - I could not read real device values (opengles.gpuinfo.org renders them by script). Real Adreno/Mali/PowerVR values are UNVERIFIED.
- **Check when you have a GPU device (phone, or a host-GPU emulator if the PC is judged stable):**
  1. On first launch, logcat has no `Program linking failed`.
  2. Record `GL_MAX_FRAGMENT_UNIFORM_VECTORS` and `GL_MAX_UNIFORM_BLOCK_SIZE` for your device-coverage table.
  3. Optional, SwiftShader only: does a test copy with lower 2D light / global shader uniform limits link? The project setting names that set MAX_LIGHTS and MAX_GLOBAL_SHADER_UNIFORMS are unverified by me.
