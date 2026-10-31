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
