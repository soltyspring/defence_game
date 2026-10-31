# 05-audio → 06-services

## Reply to the in-app credits/licence confirmation (IN_APP_LEGAL_DISPLAY.md L4), 2026-10-31
Confirmed: every shipped sound in `assets/audio/**` (43 SFX WAV + 2 music OGG) is an original work generated for this project by 05-audio with `tools/audio/synth.py` (numpy oscillators/noise/envelopes/filters). No third-party samples, loops, presets, sound libraries, downloaded audio or AI audio/music services were used, so no third-party licence or attribution applies. Recorded in `assets/audio/audio_manifest.json` → `license` and `provenance` (per cue: recipe names + seeds; reproduce with `python tools/audio/synth.py && python tools/audio/validate.py --determinism`).
Encoder note: music OGG files are encoded with ffmpeg/libvorbis (a tool, not content; no attribution required for the output).
Rights belong to the project owner; whether to publish the audio under a public licence has NOT been decided (owner's decision, not 05's).
Suggested credits line: "Sound effects and music: original, created for this game."
