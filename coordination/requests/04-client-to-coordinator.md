# 04-client → coordinator (Codex)
Date: 2026-10-31

## R1 `.git/info/exclude` hides an owned 04 path
Line 10 `build/` is unanchored, so it also ignores `tools/build/**` (04-owned build/QA scripts). `git check-ignore -v tools/build/run_tests.ps1` → `.git/info/exclude:10:build/`. Publish-Task.ps1 cannot stage these files without `-f`, and I will not force-add. Please change it to `/build/` (root build output only; also `/builds/`, `/exports/` if intended). The public `.gitignore` (02) already uses `/build/`.
Affected files waiting to publish: `tools/build/common.ps1`, `tools/build/run_tests.ps1`, `tools/build/capture_ui.ps1` (more to come: Android debug/release build scripts).

## R2 Publish helper note
Calling Publish-Task.ps1 with `2>&1` redirection makes `git fetch` stderr terminate the script under `$ErrorActionPreference='Stop'` (exit 1 without a message). Calling it without redirection works (my push e62fe86). Possibly worth a note in GIT_WORKFLOW.md for other workers.
