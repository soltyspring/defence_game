# 03-art handoff
Updated: 2026-10-31 09:15 +09:00 · Q1 still PENDING (checked DECISIONS.md at start of task).

## Status
MILESTONE 3: r04–r07 roster art delivered and the white-line root cause handed to 02. Theme is still the reversible default (Q1 PENDING, not user-approved). Nothing here is release completion.

## Read receipts / processed IDs
handoff checkpoint (verified: no uncommitted 03 files at resume), coordinator-to-03-art (incl. QUOTA CHECKPOINT entries, already handled by 9848b06), QUOTA_POLICY, WINDOW_STABILITY, DECISIONS (Q1 PENDING), 08→03 A1/A3 (answered in 03-art-to-08-performance A1), 09→03 R09-03-1..3 (role cues applied to new units; card tier/numeral proposals noted for when 01 designs upgrade tiers), 04→03 R2 (white lines → reproduced, routed).
Outgoing: 03-art-to-02-engine A4 (white-line root cause), A5 (new pages); 03-art-to-01-director A2; 03-art-to-08-performance A1. Delivery state: QUEUED until each owner acknowledges.

## Commits
- 22cd2bb [Docs] white-line real-game reproduction + root-cause evidence for 02. PUSHED origin/main.
- c49de70 [Design] r04~r07 roster + 3 roster atlases. PUSHED origin/main (verified with `git branch -r --contains`).
- Earlier: 9b4ee0b, e93acdd, 6cf3d01, 4088ae0, 5e157e3, abd327d, 9848b06 (all pushed).

## Work done this session
1. **White lines (A8):** reproduced in the real game on the secondary monitor (\\.\DISPLAY2, 04's visible_launch.ps1; note that `-UserArgs` must be passed in-process as an array, because a nested `pwsh -File` joins it with commas). Two 2-device-px #e3f3ff columns at device x 432–433 and 570–571, in every shot at 2/5/8 s. Root cause in 02's `battle_view.gd::_draw_biome_layers`: per-copy `roundf` with .5 offsets (cam_x clamp 230 × (1−parallax)) puts copies 641 px apart. Predicted seams 216.5/285.5 logical match the observed 216/285. Evidence: docs/art/evidence/whitelines/. **Not fixed** until 02 changes it and the same capture shows 0 lines.
2. **Roster:** `tools/art/chars_r04.py`: fast (40×32 pony lancer), siege (48×40 catapult), e_brute (48×48), e_bomber (32×32), boss_warlord (64×64). All original, same palette/outline/rig. Hit frames match data (1/3/3/1/3). Siege has projectile_spawn. New pages: `char_player_adv` 512×256, `char_enemy_adv` 512×256, `char_boss_warlord` 512×512 (battle_roster). Cards card_fast/card_siege, portraits for e_brute/e_bomber/boss_warlord. The existing pages are byte-identical (git diff empty for char_player/char_enemy/bases/fx_combat). The rig gained an optional `boot_w` (default reproduces the old pixels).
3. Hostile review round 2 (ART_AUDIT A12–A15): the first drafts had the catapult facing backwards and a teal brute that read close to the ally blue. Both were fixed and re-inspected.

## Validation (actually run)
- `python tools/art/validate.py --determinism`: PASS (9 pages: bounds, overlap, extrusion, 0 foreign texels in sampling simulation, palette, anim contract, data refs, tiling, Godot-generated .import, font coverage/params, identical bytes across 2 builds). Only data art ref still missing: `boss_overlord`.
- `pwsh tools/art/run_godot_pack_check.ps1` (exported PCK, headless): 9/9 pages load with correct sizes, raw PNG absent, fonts load. PCK 1,218,828 B. Fixed: the JSON report is now read from a UTF-8 file, because console stdout mangled Hangul and broke ConvertFrom-Json.
- Visual: inspected the contact sheets of all 5 new sets at 3–4× and docs/art/previews/battle_mock_2x.png (factions and roles separable at 1×; warlord dominant).
- Totals: disk 60.2 KiB, GPU 7.25 MiB all pages, r01–r03 battle 5.25 MiB.

## Strongest rejection reasons / untested
- No in-game capture of the new units yet. 02's runtime may draw placeholders until it acquires the new pages, and the r04+ rounds were not played here.
- No Android device evidence for any art/font.
- Brute/warlord are shorter than 01's height guidance (32/45 vs 36/52 px), flagged to 01.
- boss_overlord art is missing. A8, A2, A3, A6/A7 (runtime), A9 are open with other owners.

## Milestone 4 (this session): ui_main stale import (04 R4)
- Found: the committed png/json/.import are consistent (c49de70). The main tree has a stale local `.godot/imported/ui_main…md5` (224f322f = abd327d pixels vs png f16e31cf).
- Reproduced in an isolated copy with the same condition: 95/103 ui_main frames wrong (GPU readback + Godot-rendered contact sheet vs source + manifest). After `--import`: 0/103, 0 px. The other 8 pages had 0 mismatches in both states. The window was on the secondary monitor (screen 1). Evidence: docs/art/evidence/ui_import/.
- Real game, main tree, 08:44 secondary-monitor capture: still stale (UiStyle fallback warning). Not fixed in the main tree until 02 re-imports (A6). 04 asked to re-verify (A4).
- Prevention: layout locks in atlas.py/build.py (adding a frame moved 0/98 regions). validate.py checks the local import cache md5 and the lock size. Rebuild output is byte-identical to c49de70 (git diff of assets empty). validate --determinism PASS with 4 expected WARNs (stale/unimported local cache).

- Commit: de85b3e [Fix] ui_main stale-import repro/verify tools + layout locks. PUSHED origin/main (verified with `git branch -r --contains`).

## Milestone 5 (this session): boss_overlord
- `tools/art/chars_boss.py`: hive overlord, 88×80 frame, pivot (36,79). Anims idle/walk/attack (hit 3, = units.json)/summon (events.spawn 3, points.spawn_origin [24,79])/hit/death (+die). New page `char_boss_overlord` 1024×512 (2.00 MiB, battle_roster, r10 only) + `portrait_boss_overlord` on that page. ui_main is untouched.
- Regression: SHA-256 of all 27 previous atlas files (9 pages × png/json/import) identical before vs after.
- validate.py --determinism PASS (only expected WARNs: local .godot cache stale/unimported, A6 with 02). Exported PCK: 10/10 pages load, raw PNG absent, PCK 1,241,540 B. r10 residency from round data = 9.25 MiB.
- Adversarial review: hierarchy measured (overlord 56×34 > warlord 45×24 > brute 32×23 > grunt 19×17). A16: the purple mass was within ΔE 9.7 of ally blue under deuteranopia sim; fixed for the overlord (bark/green; retest image docs/art/previews/boss_overlord_review_3x_after.png). A17: the same issue on existing enemies is OPEN and needs approval to touch existing pages (asked 01 A3). A19: summon has no data frame field (asked 01/02).
- Commit 393ada2 [Design] boss_overlord + page + colour-vision fix: PUSHED origin/main (verified with `git branch -r --contains`). The commit diff touches only char_boss_overlord.png among the atlas PNGs.
- Not done: in-game capture of the overlord (needs 02 --import + an r10 run).

## Next tasks (03)
1. (done) boss_overlord. Next: A17 recolour of existing enemy purple masses if 01 approves; in-game r10 capture after 02 import.
2. When 02 acknowledges A4/A5: rerun the same capture (`& .\tools\build\visible_launch.ps1 -UserArgs @('--round=r01','--shots=2,5,8','--shot-dir=build/qa/art03','--quit-after=10') -EvidenceDir build\qa\art03`) and an r05/r07 capture to verify the new units in game.
3. Re-theme immediately if Q1 is answered.
