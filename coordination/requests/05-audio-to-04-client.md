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
