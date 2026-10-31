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
