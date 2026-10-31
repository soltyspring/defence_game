# watch_userdata summary (2026-10-31 19:28:25 .. 19:29:26)
Folder: C:\Users\aghose\AppData\Roaming\Godot\app_userdata\Lane Defence (read-only)

## Runs that used the REAL user dir (new rotated log in logs/, matched to a process by start time ±2 s)
| run start | owner guess | command line | parent | first log lines of the live godot.log |
|---|---|---|---|---|
| 19:29:02 | 04-client | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe" --path C:\Users\aghose\AppData\Local\Temp\art03_imp --screen 1 --resolution 1600x900 --log-file Z:\.solty\dev\appintoss\defence\build\qa\art03_scale\O1_integer_expand_1600x900\godot_20261031_192901.log -- --round=r01 --auto | "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -Command "$h=\"$env:TEMP\art03_imp\"; Copy-Item \"$h\project.godot\" \"$h\project.godot.orig\" -Force; Copy- | Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org / CI NAMES {"boss_overlord":{"en":"Rot Overlord","fallback":"부패 대군주","kind":"unit","ko":"부패 대군주"},"boss_warlord":{"en":"Mold General","fallback":"곰팡이 장군","kind":"unit","ko":"곰팡이 장군"},"e_bomber":{"en":"Y / PROBE10_CONTENT_INTEGRITY {"checks_run":{"ANIM_REF":20,"BIOME_REF":10,"DUP_ID":36,"DUP_NAME":52,"ENUM":15,"HERO_REF":11,"ICON_REF":8,"MIRROR":4,"ORDER":20,"RANGE":541,"SKILL_REF":22,"STALE_NAME":26,"T |

## save.json / .bak writes (checked every 5 s)
| seen at | file | mtime | Godot processes alive ([real-dir run] = confirmed by log rotation) |
|---|---|---|---|
| 19:28:32 | save.json | 19:28:30 | 07-qa pid=45284; 01-director pid=29048; 01-director pid=49956; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848 |
| 19:28:32 | save.json.bak | 19:25:58 | 07-qa pid=45284; 01-director pid=29048; 01-director pid=49956; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848 |
| 19:29:04 | save.json | 19:29:03 | 07-qa pid=45284; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848; 04-client pid=53840 [real-dir run] |
| 19:29:04 | save.json.bak | 19:28:30 | 07-qa pid=45284; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848; 04-client pid=53840 [real-dir run] |

## Folder diffs every 30 s
| tick | time | kind | file | mtime | save/bak hash | attributed to |
|---|---|---|---|---|---|---|
| 1 | 19:28:59 | changed | save.json | 19:28:30 | 9E9F05BF504ED0BE | 07-qa pid=45284; 01-director pid=29048; 01-director pid=49956; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848 |
| 1 | 19:28:59 | changed | logs/godot.log | 19:28:30 |  | 07-qa pid=45284; 01-director pid=29048; 01-director pid=49956; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848 |
| 1 | 19:28:59 | changed | save.json.bak | 19:25:58 | EB715A51F3A4FC03 | 01-director pid=29048; 01-director pid=49956; 02-engine pid=27852; 02-engine pid=55848 |
| 2 | 19:29:26 | changed | save.json | 19:29:03 | E4263BE635F5B0D9 | 07-qa pid=45284; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848; 04-client pid=53840 [real-dir run] |
| 2 | 19:29:26 | changed | logs/godot.log | 19:29:03 |  | 07-qa pid=45284; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848; 04-client pid=53840 [real-dir run] |
| 2 | 19:29:26 | changed | save.json.bak | 19:28:30 | 9E9F05BF504ED0BE | 07-qa pid=45284; 01-director pid=29048; 01-director pid=49956; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848 |
| 2 | 19:29:26 | new | logs/godot2026-10-31T19.29.02.log | 19:29:02 |  | 07-qa pid=45284; 02-engine pid=27852; 07-qa pid=4068; 02-engine pid=55848; 04-client pid=53840 [real-dir run] |
| 2 | 19:29:26 | removed | logs/godot2026-10-31T19.23.21.log |  |  |  |

| pid | owner guess | start | last seen | command line |
|---|---|---|---|---|
| 45284 | 07-qa | 19:26:10 | 19:29:25 | Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe --headless --path C:\Users\aghose\AppData\Local\Temp\qa07_head -s res://tests/acceptance/probe_balance.gd -- --rounds=r08 --seeds=10 --budgets=lo |
| 29048 | 01-director | 19:22:12 | 19:28:31 | Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe --headless --path . -s C:\Users\aghose\AppData\Local\Temp\multi_seed_sim.gd -- C:\Users\aghose\AppData\Local\Temp\d30_r05final.json - none,low,op |
| 49956 | 01-director | 19:22:12 | 19:28:31 | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s C:\Users\aghose\AppData\Local\Temp\multi_seed_sim.gd -- C:\Users\aghose\AppData\Local\Temp\d30_r05final.json - n |
| 27852 | 02-engine | 19:25:12 | 19:29:09 | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path C:\Users\aghose\AppData\Local\Temp\bd02_head -s res://src/core/diag/selftest.gd |
| 4068 | 07-qa | 19:26:10 | 19:29:25 | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path C:\Users\aghose\AppData\Local\Temp\qa07_head -s res://tests/acceptance/probe_balance.gd -- --rounds=r08 --seeds=10 -- |
| 55848 | 02-engine | 19:25:12 | 19:29:09 | Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe --headless --path C:\Users\aghose\AppData\Local\Temp\bd02_head -s res://src/core/diag/selftest.gd |
| 53840 | 04-client | 19:29:01 | 19:29:04 | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe" --path C:\Users\aghose\AppData\Local\Temp\art03_imp --screen 1 --resolution 1600x900 --log-file Z:\.solty\dev\appintoss\defence\build\qa\art03_ |
| 60324 | 04-client | 19:29:09 | 19:29:15 | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe" --path C:\Users\aghose\AppData\Local\Temp\art03_imp --screen 1 --resolution 873x393 --log-file Z:\.solty\dev\appintoss\defence\build\qa\art03_s |
| 34164 | 04-client | 19:29:17 | 19:29:20 | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe" --path C:\Users\aghose\AppData\Local\Temp\art03_imp --screen 1 --resolution 1280x720 --log-file Z:\.solty\dev\appintoss\defence\build\qa\art03_ |
| 33372 | 04-client | 19:29:25 | 19:29:25 | "Z:\.solty\dev\appintoss\defence\tools\engine\Godot_v4.7.2-stable_win64.exe" --path C:\Users\aghose\AppData\Local\Temp\art03_imp --screen 1 --resolution 1600x900 --log-file Z:\.solty\dev\appintoss\defence\build\qa\art03_ |
