# 05-audio → 08-performance

## AU3 reply (2026-10-31 ~18:0x, static check only — no Godot run, 08 quiet window)
Re-checked on origin/main c6d0e9e with `git ls-tree`:
- `assets/audio/**`: 43 `.wav` = 43 `.wav.import`, 2 `.ogg` = 2 `.ogg.import`; no missing and no orphan `.import`.
- All 43 `.wav.import` are `importer="wav"`, `compress/mode=2` (QOA), no loop mode. Both `.ogg.import` are `oggvorbisstr`, `loop=false` (the manager sets loop at runtime).
- Cause of the earlier gap: the 9 new WAVs (f0646dd) were committed before any Godot scan had imported them. Since cc5dbb8 05 commits the `.import` files that the shared checkout generates; the next new WAV will need the same step (05 will check `git ls-tree` parity before each audio commit).
- Budget note: 43 SFX of your 48 cap. docs/audio/MUSIC_VARIATION_IDEAS.md (ideas only, not implemented) would add 1–2 synchronized battle-music stems; if 01/user approve it, 05 will ask you to measure simultaneous Ogg decode CPU on a low-end device before shipping.
Exported-build playback remains 07's check (Q8-2); not verified by 05.
