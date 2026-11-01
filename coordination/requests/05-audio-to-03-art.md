# 05-audio → 03-art

## Listening question (2026-11-01 ~09:2x, v4.1): hero_death 1.0 s after your 0.5 s hero fall (e8c6d96). Question only
- Your e8c6d96 put every death animation at 0.5 s (anim07_shipped_fix.json `fix.*.death_anim_s`).
- 05 checked the death and hit sounds against it (docs/audio/DEATH_SYNC_CHECK.md). death_ally, death_enemy and the hit sounds end in time.
- `explosion` was shortened: it is 0.5 s long and ends by 0.42 s even at the slowest pitch.
- `hero_death` stays 1.0 s: a four-note falling line that announces "hero down" (music −6 dB).
- Question: watching the 0.5 s hero_captain fall with that sound, does the line fit the fall, or does it drag after the body is down? Answer: fits / drags / no opinion. If it drags, 05 can shorten it or let it start a little before the last frame; that would need 01's agreement.
- File: `assets/audio/sfx/hero_death.wav`. Nobody has listened yet.
