# 10-research-systems → 06-services (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §5.5, §5.6, §7.
1. TP-08: decide and test the policy for process death between `reward_earned` and a successful `store.commit()`. Either reward and ledger both persist, or neither does. Never only one. A public Archer Forest review (2026-05-03, en) describes the user-visible failure: ad → Play Store opens → game restarts → no reward.
2. Analytics: the current schema (session id never persisted) cannot measure D1/D7 retention. That is a valid privacy choice, but it conflicts with the "observe after launch" need. Please record it as a known limitation and route the option set (Play Console aggregates / consented install-scoped random id / closed-test only) to 01 as a decision, not as a user question from 06.
3. Proposed events for review: `ftue_step{step_id}`, `save_recovered{source: bak|fresh}`. Same bounded-param rules.
4. AdMob SSV `transaction_id` and Play `purchaseToken` are the natural server idempotency keys if a backend ever exists. Your local key derivation already matches this shape. No change requested.

## v0.18 (~17:20 KST): impact on SAVE_BACKUP_POLICY — no change needed
- On our exact engine (4.7.2-stable, commit ed1daf0bf…), Android user:// uses FileAccessUnix with no fsync (flush = fflush). Details are in §9.9 with line citations.
- Your B1 rule set (back up only save.json + save.json.bak; exclude .tmp and .corrupt-*) matches this. Keep it.
- A power loss right after two back-to-back saves could corrupt both main and .bak. That is an inference, not tested on a device. In that case the last Auto Backup copy is the only remaining recovery path, which strengthens B1's rationale.
- Auto Backup shuts the app down before backing up (Android Auto Backup doc), so a half-written file being backed up is unlikely per the documentation.
- Engine save-and-swap (`OS.set_use_file_access_save_and_swap`) is off and unused. If anyone ever enables it, it creates `save.json.tmp-XXXXXX` temp files, which B1 already excludes because it includes only named files.

## v0.26 (~19:12 KST): service suites write the REAL user folder; the save-hash check misses the boot write (P1)
Evidence: DATA_AND_BACKEND_ANALYSIS.md §9.17.
- Every Godot run with autoloads boots Save, which since R5 rewrites the real `user://save.json` after any data change (X1/X3).
- Your `_hash_user_save()` takes its first hash inside the suite, after boot. So "player's save unchanged" can pass while boot already rewrote it.
- The real folder holds your `services_*_report.json` (7) and `m3dbg1~3`.
Change (your files; I did not edit them):
1. `tests/services/run_services_suites.ps1` line 17 (`--path .`): set a private `$env:APPDATA` for the Godot call (restore after), or call `docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(...)`.
2. `tests/services/run_services_on_head.ps1` lines 30/35: the snapshot keeps `config/name="Lane Defence"`. Rename it in the snapshot or use a private APPDATA.
3. If you keep a real-save guard, hash `%APPDATA%\Godot\app_userdata\Lane Defence\save.json(.bak)` in the PowerShell runner BEFORE launching Godot, not inside the suite. Report it as invalid when other Godot processes run at the same time.

## v0.28 (~20:15 KST): reminder — no isolation committed yet, and no 06 runs were seen in the watch window
Source: DATA_AND_BACKEND_ANALYSIS.md §9.19. During 19:41–20:11 none of your suites ran, so their behaviour is unverified. `tests/services/run_services_suites.ps1` (17) and `run_services_on_head.ps1` (30/35) still have no private APPDATA (origin/main 20:11). Your `services_*_report.json` files in the real folder date from 18:44 and 19:04. Please apply 10→06 v0.26. I will rerun the watch after your commit.
