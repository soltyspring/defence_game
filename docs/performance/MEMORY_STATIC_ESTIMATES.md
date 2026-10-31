# MEMORY_STATIC_ESTIMATES.md — audio decode/residency and pool preallocation (owner: 08-performance)
Updated: 2026-10-31 16:50 +09:00. Method: **static** (committed files read with `git show`, WAV/OGG headers via
`tools/perf/asset_budget_check.py`, code reading). No Godot run, no device. Numbers marked "estimate" are arithmetic, not measurements.

## 1. Audio after 05's theme rework f0646dd (16:36)
Gate: `python tools/perf/asset_budget_check.py --rev f0646dd` (base 37b9a93) and `--base ccf3033` (previous audio commit) → **PASS**.
| Item | ccf3033 | f0646dd | Cap (RETHEME_BUDGET §3) |
|---|---|---|---|
| SFX WAV files | 31 | 38 | ≤ 48 |
| SFX decoded PCM (upper bound of RAM) | 0.76 MiB (792 254 B at 37b9a93) | **0.83 MiB (872 956 B)** | ≤ 2 MiB |
| Longest SFX | 3.0 s | 3.0 s | ≤ 3.5 s |
| Music | 2 OGG, 0.53 MiB | 2 OGG, 0.56 MiB (585 553 B) | ≤ 4 tracks, ≤ 1.5 MiB |
| Audio on disk | 1.29 MiB | 1.39 MiB (1 460 181 B) | ≤ 3 MiB |
"52 files" in the coordinator note = 38 WAV + 2 OGG + 1 manifest + imports. The commit tree has 72 entries under assets/audio, of which 31 are `.import` files.

### 1.1 Decode mode and residency (from the committed `.import` files and src/audio/audio_manager.gd)
- **SFX**: every cue file is loaded once at startup by `_load_manifest` (`audio_manager.gd:143-169`), so all SFX are resident for the whole
  session (menu and battle). The imported WAVs use `compress/mode=2` (QOA, ≈ 3.2 bits/sample, about 1/5 of PCM). The 29 previously imported
  files occupy 172 067 B in `.godot/imported/*.sample`. Resident SFX estimate: **≈ 0.2 MiB** (QOA); upper bound 0.83 MiB if stored as PCM.
- **Music**: `AudioStreamOggVorbis` (`importer="oggvorbisstr"`). It is loaded on `play_music` (`audio_manager.gd:352`). The compressed Ogg
  data stays in RAM and is decoded while playing. During a crossfade both tracks are resident: **≤ 0.56 MiB**. Fully decoded PCM would be
  7.69 MiB (44.1 kHz stereo); the code does not do that.
- **Voices**: pools are created once (`audio_manager.gd:125-130`): 12 SFX + 3 UI + 1 stinger + 2 music = 18 `AudioStreamPlayer` nodes.
  The per-cue `max` values in the manifest sum to 42 > 12 SFX voices, so priority stealing (`_acquire`, 293) caps simultaneous SFX at 12.
  Memory is negligible. **CPU for 12 simultaneous QOA decodes + the Vorbis stream on a low-end core is unmeasured** (device needed).
- Verdict: memory is within the caps with a large margin (SFX ≤ 0.83 MiB of 2 MiB, music 0.56 of 1.5 MiB).

### 1.2 Release defect found: 9 new WAVs have no `.import` file in the commit
`git ls-tree f0646dd assets/audio/sfx` has 38 `.wav` but only 29 `.wav.import`. Missing: hit_base_mold, hit_bread_1–3, hit_mold_1–3,
hit_melee_4–5 (also absent from the working tree at 16:47). `_load_stream` (`audio_manager.gd:132-141`) uses `load()` when an import exists,
else a raw-file fallback that only works in the editor checkout ("not used in exported builds"). Inference: **in an exported APK the cues
`hit_bread`, `hit_mold` and `hit_base_mold` lose all their files (silent), and `hit_melee` loses 2 of 5 variants.** It is not verified in an
APK yet, because no APK was built after f0646dd. Sent to 05 (owner of the `.import` files) and to 07 for an export check. The import
must run under the shared import lock (02/04).

## 2. Pool preallocation in 02's 22d99ea (`BattleSim._prealloc_pools`)
Committed at HEAD: projectiles = caps.projectiles (64), fx = caps.fx (48), texts = caps.text (24), unit pool = caps.ally + caps.enemy + 8
= **80** (the coordinator's "72" excludes the +8 for dying units). Fields per class (HEAD): Unit 31, Projectile 17, Fx 7, FText 6.
Estimate per GDScript RefCounted instance: Object + script-instance overhead ≈ 300–500 B, + 24 B per member Variant (64-bit Godot 4).
Unit also gets one empty `Dictionary` (`var def: Dictionary`, ≈ 0.1 KB). Strings start empty (shared).
| Pool | Count | Per instance (estimate) | Total (estimate) |
|---|---|---|---|
| Unit | 80 | 1.1–1.3 KB | 84–106 KB |
| Projectile | 64 | 0.7–0.9 KB | 45–58 KB |
| Fx | 48 | 0.47–0.67 KB | 22–32 KB |
| FText | 24 | 0.44–0.64 KB | 11–15 KB |
| **Sum** | 216 objects | | **≈ 0.16–0.21 MiB** per battle start |
Context: total PSS budget low tier 250 MB, so this is ≤ 0.1 %. The allocations move from mid-fight to `setup()`, so the remaining question
is the battle-start hitch, not memory. A new `BattleSim` is created per battle; the old pools are freed with the old sim (M1 leak check: 0
objects retained after 5 battles, to be re-confirmed with preallocation).
Measurement plan (when Godot is allowed): `Performance.OBJECT_COUNT` and `MEMORY_STATIC` before/after `BattleSim.setup()` in perf_bench
(new case), and the battle-start frame time in the frame probe.

## 3. Measured in C11 (18:17, quiet desktop, debug binary) — correction of §2
`perf_bench.gd --only=setup`: one `BattleSim.new()+setup()` creates **219 objects** (64 + 48 + 24 pooled + 79 units + sim internals) and
raises static memory by **≈ 478 KB** (r01 478 032 B, r10 476 788 B). Setup takes p50 0.81 ms (max 2.86 ms). The §2 estimate of
0.16–0.21 MiB was **about 2.3× too low**: measured ≈ 0.46 MiB. It is still ≤ 0.2 % of the 250 MB low-tier PSS budget, and the setup time
of < 3 ms is not a visible hitch on desktop. Unit pool = 79 (36 + 36 + 8 − the hero, which is created separately).
