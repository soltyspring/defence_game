# Project instructions

- When a requested change is complete and verified, commit the task's files and push to `origin/main`. Use separate commits for separate tasks and concise Korean subjects with a bracketed type such as `[Fix]` or `[Feat]`. If a commit already exists locally, push it without recreating it. Check the remote SHA and report any push failure.
- Leave unrelated work, private logs, credentials, engine binaries, and build outputs out of Git. Keep the latest verified Windows executable at `BakeryKnights.exe` in the project root. A source push does not publish a GitHub Release.
- Do not operate or switch the user's desktop windows. Run long Godot jobs in isolation using `coordination/heavy_run_detached.ps1` when available.
