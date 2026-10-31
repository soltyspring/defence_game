# 05-audio → 01-director

## Q-candidate (for your queue only — do NOT ask while Q5 is open; one question at a time is yours to schedule)
Topic: should battle music change with the battle situation? Background: docs/audio/MUSIC_VARIATION_IDEAS.md (ideas only; nothing implemented, nobody has listened). Today all 10 rounds use one 27-second battle loop; an earned r05 win (396 s) hears it about 14.5 times.
Suggested wording (Korean, for the user):
> 전투 음악을 상황에 따라 바꿀까요?
> A) 지금처럼 한 곡 고정 (가장 단순, 파일 추가 없음)
> B) 보스가 나오면 같은 곡의 단조 변주로 바뀜 (추천: 보스 라운드 r05·r10만 해당, 음악 파일 +1개, 약 +0.35 MB)
> C) B에 더해 곰팡이에게 밀릴수록 끈적한 소리가 섞임 (가장 생생하지만 파일 +2개 약 +0.7 MB, 저사양 기기 CPU 측정 필요)
Why 05 recommends B: largest audible change for the smallest cost; works with events that already exist (`boss_incoming`, death cue `boss: true`); stays well inside the 2.5 MB audio budget (now 1.46 MB). C needs 08's low-end decode measurement first.
Affected: 05 (synth + bridge), 08 (CPU if C), 07 (listening/acceptance). No change for 02/04.

## R1 (theme timbre direction) — status
Covered: bakery warm/dry palette (oven/shop bells, crust crunch, wooden knocks), mold squelch/fizz/wet pops, spore-burst explosion (yeast bomber), boss low bubbling drone, rolling-pin slam, restrained (no gore).
Not yet covered (05 backlog, not started): fruit-fly buzz for e_swarm (needs a per-unit hint in the death/hit cue or a new `swarm` cue), Rally = cheer + oven whoosh (now a brass-like horn), Barrage = crumb-shell volley (now whistle + 3 impacts), UI confirm as tray-bell/whisk (now a square chime), bright folk menu motif (now a music-box bell melody — close but not folk). I will do these after the current verification task unless you reprioritise.
