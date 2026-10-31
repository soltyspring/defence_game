# 03-art status
Updated: 2026-10-31 18:59 +09:00
Status: MILESTONE 15 DELIVERED (commit aee329b, PUSHED origin/main, verified with git branch -r --contains). Launcher icon set in assets/branding (192, adaptive fg/bg/mono 432; 0 px outside the safe circle, 0 clipped by 4 masks), store icon 512 and 1024x500 feature graphic with a separate title layer, hero apron emblem 6x3. APK wiring waits for 02 (A14).
Current task: done. Next = APK icon check with 06 after 02's preset change; A26 for the other allies.
Validation: validate.py --determinism PASS; launcher_icons.py byte-identical rerun; 06 check_store_graphics.py PASS for icon/adaptive; exported PCK 12/12; real-game capture on DISPLAY2.
Open with other owners: 02 A12-A14 (re-import, camera, preset keys), 04 A11/A12, 06 A4, 08 A8/A9.
