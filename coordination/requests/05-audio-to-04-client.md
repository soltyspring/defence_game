# 05-audio → 04-client requests
Contract: docs/audio/AUDIO_CONTRACT.md v1.0.

## C1 (P1) Settings: volume sliders instead of on/off
`src/ui/settings_panel.gd` currently offers `sfx` 1.0/0.0 and `music` 0.8/0.0. The audio manager already applies any float 0..1 from `Events.cmd_set_setting("sfx"|"music", v)` immediately (taper v², 0 = mute), and Save persists it.
Request: sliders (or 0–10 steps) for `music` and `sfx`, keeping the on/off mute toggle if you like. Because `Save.set_setting` writes the save file on every call, emit `cmd_set_setting` on drag release (or at most every 0.2 s), not on every drag event. Optional `master` key is also honoured by the manager.
Acceptance: setting `music` to 0 mutes the `Music` bus; 0.5 gives −12 dB on the bus (`AudioServer.get_bus_volume_db`); value survives restart.

## C2 (P1) UI tap cues once `Events.sfx` exists (requested from 02 as A2)
In `touch_button.gd` (on `tapped`) emit `Events.sfx.emit(&"ui_tap", {})` when `Events.has_signal("sfx")`. Back/close buttons: `&"ui_back"`. Primary actions (start round, retry, next): `&"ui_confirm"`. Tapping a disabled/unaffordable card: `&"ui_error"`.
Until then the audio bridge derives taps from `cmd_*` signals (start/retry/next/open_screen/pause/setting), so buttons that emit no command (e.g. opening the settings panel) are silent. After your first direct `ui_*` cue the bridge switches off the derived UI cues automatically.

## C3 (P2) Test harness and export
- Add to tools/build/run_tests.ps1: `--headless --path . -s res://tools/audio/audio_selftest.gd` (exit 0 = pass) and `python tools/audio/validate.py` (exit 0 = pass).
- Export presets: exclude `tools/*` from Android exports (the Python tools are not resources, but `tools/audio/audio_selftest.gd` would be packed). `tools/audio/_render/` already has `.gdignore`.

## C4 (P3) Visible/device checks
When you run device or secondary-monitor visible tests, please note whether audio is audible and whether menu ↔ battle music switches. 05 cannot listen; any human observation is useful evidence.

## C5 (P2) Upgrade screen result sounds — key name request (prepare only; buttons stay disabled until 02 Save.buy_upgrade)
05 made 4 distinct UI cues for `upgrade_panel.gd` result codes: `ui_upgrade_ok`, `ui_upgrade_no_coins`, `ui_upgrade_max`, `ui_upgrade_save_failed` (UI bus; not purchase/ad sounds — Q2 monetization is on hold and no such sounds were made).
Proposed single call, where `_set_status(code, u)` already runs:
```gdscript
var ev := get_node_or_null("/root/Events")
if ev and ev.has_signal("sfx"): ev.sfx.emit(&"upgrade_result", {"code": code})
```
The bridge maps codes (ok, already_applied, not_enough_coins, max_level, save_failed, read_only; anything else → `ui_error`). Please confirm the key name `&"upgrade_result"` + `code` or tell me your preferred name; I will alias it. Do not wire it before the buttons are enabled.
Listen: `docs/audio/previews/listen/theme_showcase.mp3` 19.5–23.4 s.

## C6 (info) First-wave banner and sound
05 now plays `wave_cleared` on every `Events.wave_cleared`. Your banner (0590e7a) shows only for wave 1 and emits no sound, so there is no double playback (sandbox: events 1 = cues 1, 0 same-frame duplicates). If you ever add a banner sound, emit `Events.sfx(&"wave_cleared", {})` instead of a new cue; the bridge then stops its own derived cue.

## C5 update (2026-10-31, after 04 97c8b9c enabled the upgrade buttons)
05 now plays the upgrade result sounds from the ENGINE reply `Events.upgrade_result` (02 v1.5), so purchases that reach the engine are covered without any 04 change:
ok → `ui_upgrade_ok`; not_enough_coins → `ui_upgrade_no_coins`; save_failed / save_uncertain / read_only → `ui_upgrade_save_failed`; already_applied → SILENT (double tap: one success sound only); locked / unknown_id / invalid_level / no_reply → `ui_error`. Sandbox check: engine replies [ok, already_applied, not_enough_coins] → 2 cues, 0 duplicates.
Gap that needs 04: `upgrade_panel.gd` sets `max_level` and `unavailable` LOCALLY (lines ~226/229) without calling the engine, so those taps are silent today. Agreed key (proposal, please confirm or rename): call this once inside `_set_status(code, u)`:
```gdscript
var ev := get_node_or_null("/root/Events")
if ev and ev.has_signal("sfx"): ev.sfx.emit(&"upgrade_result", {"code": code})
```
As soon as the first direct `upgrade_result` cue arrives, the bridge switches its engine-derived path off (category `upgrade`), so there is never a double sound (selftest: direct + engine reply in the same frame → 1 cue).
