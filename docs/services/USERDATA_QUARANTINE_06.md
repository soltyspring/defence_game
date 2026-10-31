# 06 test leftovers moved out of the real player folder (owner: 06-services)
Done 2026-10-31 23:35:13 KST, by coordinator decision: move, do not delete; reversible. No Godot was run for this.

- **From:** `%APPDATA%\Godot\app_userdata\Lane Defence\` (the real desktop user:// of this project)
- **To:** `%LOCALAPPDATA%\defence_userdata_quarantine\06-20261031-233513\` (+ `MANIFEST_06.json` with the same data as below)
- **Method:** `Move-Item` without `-Force`, so nothing is overwritten. The destination did not exist before.
- **Why these are 06's:**
  - The 7 report names are written by `tests/services/test_services*.gd` (`FileAccess.open("user://services_*_report.json")`).
  - `m3dbg1~3` hold `phase.txt` = `after_commit persisted=true`, the marker written by `tests/services/m3_child.gd`. They came from a manual M3 debug run at 15:40.
  - Not moved: `save.json`, `save.json.bak`, `logs/`, and every other role's file (selftest_*, qa07/, perf/, probe10/, atlas_guard_test/, …).

| File (relative to the user folder) | Size (B) | SHA-256 |
|---|---|---|
| services_test_report.json | 711 | 47C4F4F38A670C00E1AE5B64F090974B8B41160EE20BDA1656782D86CD5F8B64 |
| services_m2_test_report.json | 524 | 03E7FC2902C08782FAA57165842C2374BE1F88A1E88533807916EE6926E1385B |
| services_m3_test_report.json | 1182 | 4F3A352D1F69C4488698F33741DD99BBD4FC03AE71376545D3EB32CEF11931C3 |
| services_m8_test_report.json | 265 | 0C408F82E861E8605C34F8C6D953594EEA4E01CD404011DDBA7BD91BE7A1FB24 |
| services_m10_test_report.json | 404 | 82AD80747324B7D90B34F2149400EFE9A81C81198CF9562372A90855EB059AFC |
| services_listing_report.json | 1384 | 42AF3AF76D81223600DAD675A0F3FA866D84DD15E78A5095798A6A9749B74987 |
| services_integration_report.json | 4026 | 66992F9691DA82259F49FC07ED2E11A9BA16AC69A715746C85B86C85C0C2F435 |
| m3dbg1\phase.txt | 27 | AD3F7495FAFC42CC4B4BB4F1C034390DF6295D279546D996FD73F4A6972BBB7B |
| m3dbg1\save.json | 678 | C5322004BB6FBE32D1DA9E27EDA8A612485BD0F144C843773426DC8053721567 |
| m3dbg1\save.json.bak | 544 | 833E41507C256C5934BF66D3CD85DE7C5993B1900182EB68FF57BD310C0D4E20 |
| m3dbg2\phase.txt | 27 | AD3F7495FAFC42CC4B4BB4F1C034390DF6295D279546D996FD73F4A6972BBB7B |
| m3dbg2\save.json | 678 | CC5DF096D352192278FF701E5071B6EFA54742BD464C21FFFB83E04C8004DD46 |
| m3dbg2\save.json.bak | 544 | 833E41507C256C5934BF66D3CD85DE7C5993B1900182EB68FF57BD310C0D4E20 |
| m3dbg3\phase.txt | 27 | AD3F7495FAFC42CC4B4BB4F1C034390DF6295D279546D996FD73F4A6972BBB7B |
| m3dbg3\save.json | 678 | 8F389798004DD50137FDB39D4838E58AE6E49BE9A052111EDBA5DFDD7E3FBC73 |
| m3dbg3\save.json.bak | 544 | 833E41507C256C5934BF66D3CD85DE7C5993B1900182EB68FF57BD310C0D4E20 |

**Verification after the move:**
- All 16 files exist at the destination with the same SHA-256 and are gone from the source.
- No `services_*`, `m3dbg*` or `svc_*` entries are left in the real folder.
- The player save was unchanged:
  - `save.json` 614A1FAC560FBB78… before = after
  - `save.json.bak` E4263BE635F5B0D9… before = after

**Undo (one line, PowerShell; fails instead of overwriting if a name already exists):**
```
Get-ChildItem "$env:LOCALAPPDATA\defence_userdata_quarantine\06-20261031-233513" -Exclude MANIFEST_06.json | Move-Item -Destination "$env:APPDATA\Godot\app_userdata\Lane Defence"
```
Since 29d31be, 06 runners use a private APPDATA and fail if they cannot prove it (`SVC06_ISOLATION`), so these files should not come back.
