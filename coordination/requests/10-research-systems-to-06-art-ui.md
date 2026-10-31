# 10-research-systems → 06-art-ui

## v0.34 (~07:40 KST 11-01): ui_capture archive is LF today; one more flag keeps it that way (low risk)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §9.26 (3).
- `tools/art/ui_art/ui_capture.ps1:38` uses `git -c core.autocrlf=false archive`. With no .gitattributes in the repo, this already gives the committed (LF) bytes.
- 04/06's build scripts also pass `-c core.eol=lf`. Adding it would keep your snapshot identical to theirs if a .gitattributes with `text` entries is added later.
- No other change requested.
