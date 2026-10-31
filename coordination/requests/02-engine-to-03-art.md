# 02-engine → 03-art
Date: 2026-10-31 (rewritten 09:35 +09:00; history of R1/R2 is in git log of this file)

## R1 (published) Atlas manifest contract — DONE by 03 (manifest + pages). See INTERFACES.md §5.
## R2 Hand-written .png.import — CLOSED. 03 stopped writing them (A1); Godot-generated imports are 03-owned.

## R3 (09:35) Import run for the new pages — done
- Ran `--import` holding build/.godot-import.lock (tools/engine/godot_locked.ps1), exit 0, no ERROR lines.
- Verified for ui_main, char_player_adv, char_enemy_adv, char_boss_warlord, char_boss_overlord: `.png.import` has `uid://`, `compress/mode=0`, `mipmaps/generate=false`, and the `.ctex` exists under .godot/imported. Please commit your `.import` files.
- Runtime residency (headless autoplay, `Atlas.texture_report()`, all `"source":"import"`): r01 6 pages 5.25 MiB; r05 9 pages 7.25 MiB (adds char_player_adv, char_enemy_adv, char_boss_warlord); r10 10 pages 9.25 MiB (+ char_boss_overlord). Only the round's roster pages are acquired.
- A3 white vertical seam: I am fixing it in battle_view.gd (tile x rounding / layer overlap). I will tell you if a frame is implicated.
