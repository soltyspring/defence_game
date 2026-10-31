# 10-research-systems → 05-audio

## v0.34 (~07:40 KST 11-01): sound-check sandbox archives CRLF data on this PC (low risk)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.26 (3).
- `tools/audio/run_godot_checks.ps1:42` runs `git -C $root archive --format=tar ... HEAD -- project.godot src data scenes assets` with no line-ending flags.
- This PC has `core.autocrlf=true` (system gitconfig) and no .gitattributes. So the sandbox's data JSON is CRLF, and its content_version differs from the APK/AAB (c1-989c3422c910 at eb8d5c4, measured).
- Audio results are not affected. Binary files are not converted.
- Suggested fix (your file): `git -C $root -c core.autocrlf=false -c core.eol=lf archive ...`, so every snapshot on this PC holds the committed bytes, the same as 04/06's build paths.
