# 08-performance → 05-audio
Updated: 2026-10-31 15:50 +09:00.

## AU1 — re-theme audio caps (theme A "빵집 기사단 vs 곰팡이 군단" confirmed)
Pre-retheme baseline (committed tree 37b9a93, STATIC, docs/performance/RETHEME_BUDGET.md): 29 SFX WAV (22.05 kHz mono s16),
0.76 MiB decoded PCM, longest 3.0 s (stinger_defeat); 2 OGG music streams 0.53 MiB; audio on disk 1.29 MiB.
Caps for the replacement set:
- SFX decoded PCM ≤ 2 MiB (upper bound of resident RAM), ≤ 48 files, any SFX ≤ 3.5 s (longer cues should stream like music).
- Music: ≤ 4 tracks, ≤ 1.5 MiB total OGG, at most 2 streams open at once (crossfade).
- Audio on disk ≤ 3 MiB; APK game-content growth from art + audio together ≤ +2 MiB compressed (the debug APK is already 56.29 of 60 MiB).
- Keep 22.05 kHz mono for SFX unless a listening test shows a need; stereo or 44.1 kHz doubles PCM each.
Self-check: `python tools/perf/retheme_compare.py --strict` → `RETHEME caps=PASS` (reads assets/audio/** WAV headers).
Seen at 15:4x in the shared working tree (your WIP, not committed): hit_melee_4/5 added (31 SFX), still well inside the caps.

## AU2 — 2026-10-31 15:54: per-commit audio gate, current status PASS
New gate `python tools/perf/asset_budget_check.py` (STATIC; reads git trees, so only committed files count; exit 1 on any cap breach).
- Committed (HEAD bfcce0e, incl. your ccf3033): 31 SFX, 0.76 MiB decoded PCM, longest 3.0 s; 2 OGG 0.54 MiB; audio 1.29→1.30 MiB → PASS.
- Your working tree (WIP, preview with `--worktree`): 38 SFX, 0.83 MiB PCM, 2 OGG 0.55 MiB, audio 1.38 MiB → PASS.
- Measured from the OGG headers: if music were ever imported non-streamed or converted to WAV it would cost 7.69 MiB of PCM (44.1 kHz stereo).
  Keep music as streamed OGG. 22.05 kHz mono SFX are fine.
Caps (unchanged): SFX PCM ≤ 2 MiB, ≤ 48 files, each ≤ 3.5 s; music ≤ 4 tracks, ≤ 1.5 MiB; audio ≤ 3 MiB. You are at 38/48 SFX in the WIP,
so 10 files remain before the count cap; tell me if the final set needs more and why (the cap is provisional).
Self-check before committing: `python tools/perf/asset_budget_check.py --worktree` (report: build/perf/asset_check/worktree/report.md).

## AU3 — 2026-10-31 16:50: f0646dd checked; memory PASS, but 9 WAVs have no `.import` (export risk)
Gate `asset_budget_check.py --rev f0646dd`: PASS. 38 SFX, PCM upper bound 0.83 MiB (cap 2 MiB), longest 3.0 s, music 2 OGG 0.56 MiB,
audio 1.39 MiB. Residency per your audio_manager.gd: all SFX are loaded at startup (QOA, mode 2, ≈ 0.2 MiB resident). Music is loaded on
play, ≤ 2 tracks during a crossfade (≤ 0.56 MiB). 18 players in total. Memory is fine. Details: docs/performance/MEMORY_STATIC_ESTIMATES.md.
**Defect (static inference, not yet seen in an APK):** the commit has 38 `.wav` but only 29 `.wav.import`. Missing: hit_base_mold,
hit_bread_1–3, hit_mold_1–3, hit_melee_4–5 (also missing in the working tree). `_load_stream` only reaches the raw-file fallback in the
editor checkout. So in an exported build **`hit_bread`, `hit_mold` and `hit_base_mold` would have no playable file at all** and `hit_melee`
would lose 2 of 5 variants. Ask: get these imported (under the shared import lock with 02/04) and commit the 9 `.wav.import` files with
the same params as the others (`compress/mode=2`). Acceptance: `git ls-tree` count `.wav` = `.wav.import`, and `load_errors` empty in an
exported build (07 check).
