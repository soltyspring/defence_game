# Store screenshot captures (raw, no captions) — 04-client

Date: 2026-10-31 18:50 KST. For 06 (a143134, docs/services/STORE_GRAPHICS.md) and 09 (9e0487d, SUCCESS_ANALYSIS §32.1).
These are **raw captures**: no caption overlay, no device frame. Captions wait for 01's wording. 06 decides which ones go to `docs/services/store_assets/`.

## How they were made
- Source: a clean `git archive` snapshot of HEAD **f41fd12**, imported on its own, plus the capture script `tests/integration/store_capture.gd` (04). Run with `tools/build/visible_launch.ps1 -ProjectPath <snapshot> -Script res://tests/integration/store_capture.gd -Resolution 1280x720 -UserArgs '--out=<abs dir>','--locale=ko|en'` on the secondary monitor (DISPLAY2).
- The script switches its own window to borderless fullscreen on DISPLAY2. Log: `mode=3 window=(1920, 1080) screen=1 view=(640, 360) pixel_scale=3`, so each frame is the real 640×360 game view rendered at integer ×3 (not upscaled afterwards).
- Each frame comes from the game viewport only: no PC window frame and no window title. It is converted to RGB8 (alpha dropped) before saving.
- Real engine (App, BattleSim, battle view, 04 HUD). **Staged, not human play.** The script uses:
  - the real deploy and worker commands (`Events.cmd_deploy_unit`, `cmd_buy_worker`);
  - the hero's walk direction (`sim.set_hero_dir`) and real touches on the HUD ▶ and skill buttons;
  - fast-forwarded sim steps;
  - flour and energy set to plausible values before a shot, so cards are lit (the HUD shows those values);
  - the boss spawned by `sim._spawn_enemy("boss_warlord")`;
  - the win in #6 caused by the sim's own base-damage path.
- An isolated save: all tutorials are marked done, so there are no hint strips. No test-injected toasts. Toast and banner fades are waited out. No pause screen, no shop or price screen (Q2 보류). The resource is shown as 밀가루 / Flour (D25), never 반죽.

## Scene list (09 order)
| # | File (ko / en) | Round, sim time | What it shows |
|---|---|---|---|
| 1 | store_01_battle_{ko,en}.png | r03, t≈43 s | Lane battle at the first contact: mixed army vs mould soldiers, hero behind the line, both base HP numbers (1500/1500 vs 1200/1200), wave line, damage numbers |
| 2 | store_02_hero_skill_{ko,en}.png | r03, t≈47 s | Hero next to the fight with ▶ held and the first skill (밀대 내려찍기 / slam) just cast: hit numbers 25/74/60, energy bar spent, skill button on cooldown |
| 3 | store_03_economy_{ko,en}.png | r03, t≈16 s | Economy choice: 제빵사/Baker (worker, octagon button, cost 52 after the 2nd baker) next to the soldier cards; 밀가루/Flour 190/300 +5.5/s |
| 4 | store_04_roster_{ko,en}.png | r06, t≈10 s | Roster: all five soldier types on cards (식빵병·롤빵병·통식빵·프레첼·화덕포 / Toast·Roll·Loaf·Twist·Oven) and a mixed column (incl. the siege cannon) leaving the bakery castle; two skills |
| 5 | store_05_boss_{ko,en}.png | r05, t≈27 s | Boss: 곰팡이 장군 / Mold General walking into the bakery army, boss HP bar with name, mould horde behind it |
| 6 | store_06_result_{ko,en}.png | r03, t≈44 s | Result: 승리!/Victory!, 3 star rows (all met), time 0:43, 4 kills, reward +243, first-clear bonus; buttons Menu / Upgrades / Retry / Next Round (coins only, no shop) |

## Checks (static, no Godot)
`python tools/build/check_store_captures.py` imports 06's `check_screenshot()` from `tests/services/check_store_graphics.py` (read-only) and adds two 04 checks: exact 1920×1080, and not a black frame (> 90 % dark samples = INVALID, e.g. a locked PC). Result: **12 files, 60 checks, 0 FAIL/INVALID** (check_result.json). All frames are 24-bit PNG RGB, 1920×1080 16:9, between 0.0 and 3.4 % dark samples. So the PC was not locked, and **no frame is marked invalid**.
I looked at every ko and en frame by eye on the secondary monitor capture.

## Known weaknesses (not fixed here)
- Units are small on screen: bodies are about 24 of 360 px (07 QA-J1). The bottom HUD row also covers the last few pixels of units that walk behind the cards. This is the real 640×360 layout.
- In #4 the column is still near the castle and spread out (fast units ahead). It shows the types, not a fight.
- #1–#2: the army is 5/36. A human player at this point could have more units.
- The off-screen nest/enemy markers are not visible: they need 02's `snapshot.threat` field (04→02 R16).
- No captions (01 decides wording). 06's "≤ 20 % of the image" rule applies when captions are added.
- `store_capture_{ko,en}.json` records the sim time, dark % and save result per frame. Its paths point to the build/qa run folder; the files here are copies.
