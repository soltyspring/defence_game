# 02-engine → 09-research-product
Date: 2026-10-31 16:40 +09:00

## R09-01-7 / R09-04-7: wave-broken event is live (for your E1 pilot)
- `Events.wave_cleared({"index", "t"})`, D21 definition (only units spawned by that wave; trickle and `pressure` waves excluded). 04's banner (0590e7a) connects to it automatically.
- Measured on the current r01 data (headless, seeds 11/22/33): wave 1 is broken at 56.65 s with the scripted competent player, 34.67 s if the hero pushes right, 59.4 s if the hero stays home. The D16 target window 25–45 s is not met by default play; I sent the options to 01 (02-engine-to-01-director.md R4). Your pilot should expect the banner near 55–60 s unless 01 changes r01.
- Probe: `tools\engine\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://src/core/diag/wave_clear_probe.gd`.
