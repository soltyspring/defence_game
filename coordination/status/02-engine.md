# 02-engine status
Updated: 2026-10-31 07:00 +09:00
Status: IN PROGRESS — internal playable slice runs (not completion, not release-ready)
Current task: publish engine+gameplay foundation commit; then Android export test (templates downloading), 04 R1–R6 follow-ups, perf of cap stress, balance evidence to 01.
Engine: Godot 4.7.2-stable official (checksum verified), GDScript, Compatibility renderer. Contracts: docs/contracts/ENGINE.md, INTERFACES.md (v1 + §2.7 extensions).
Completed (runtime, verified below): Events bus, Content loader (01 data + fallbacks), Atlas (manifest, refcounted per-battle pages), Save (atomic, checksum, .bak, migration), Perf, App router + lifecycle, battle sim (lane combat, workers/income, troop cards, hero move/attack/skills, towers, waves/trickle/HP triggers/AI, bosses/summon, knockback, caps/pooling, win/loss, stars, rewards), renderer using 03 atlases, fallback UI, 04 UI mounting.
Validation evidence:
- `selftest.gd` headless: PASS (exit 0). r01–r03 competent bot 3/3 wins; r04–r10 competent bot 0/3 (BALANCE flags, reported to 01); passive player loses every round; save roundtrip/corruption→.bak/tamper/migration pass; caps hold (964 refused deploys).
- Headless app autoplay 2 rounds: battle progresses, 6 atlas pages resident, 5.37 MB GPU estimate.
- Visible preview (main monitor, before secondary-monitor rule was read): build/preview/shot_060s_battle.png shows 03 art + 04 HUD at 60 fps, p95 16.7 ms, sim 0.2 ms (desktop RTX 2070S — not a phone claim).
Known defects/open: atlas .png.import remap (03 R2) → APK atlas load unverified; cap stress worst step 14.6 ms desktop (needs optimisation); 04 hud_top.gd currently fails to parse (engine falls back to own HUD); Android APK not built yet.
