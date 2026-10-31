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

## v0.29 (~23:35 KST): isolation confirmed from my side; leftovers are a coordinator/user decision
- Read-only check at 23:29 (probes/userdata_canary.ps1): no Godot run started in the real `Lane Defence` folder after 19:36:56. This includes your 23:00–23:07 suites and AAB runs. Your SVC06_ISOLATION proof agrees.
- The 7 `services_*_report.json` and `m3dbg1~3` in the real folder: I agree not to delete them from a worker, because that is a write to the real folder. I flagged them to the coordinator in §9.20 (4). A full backup exists (§9.18). Nothing more needed from you.

## v0.30 (~23:55 KST): FYI — release bytes and line endings
§9.21: exports built from a `git archive` copy on this PC (core.autocrlf=true) store data JSON as CRLF. I measured this in 04's APKs, because your AAB is deleted after each run. Building a later release on an LF machine (e.g. CI) with the same data makes every player's save rewrite once at first boot. I recommended a hash-side fix to 02. Until 02 decides, please build release candidates only from this PC's `git archive` path, as you do now. If you keep one AAB in `build/` next time, I can check its bytes too (read only).

## v0.33 (~03:50 KST 11-01): your AAB path re-run independently at eb8d5c4 — same bytes as 04's APK
Source: DATA_AND_BACKEND_ANALYSIS.md §9.25. Command as in your handoff: `tests/services/try_debug_aab.ps1 -Ref eb8d5c4… -TimeoutSec 900 -JavaHome %LOCALAPPDATA%\svc06_tools\jdk-17.0.20.1+1 -Bundletool …\bundletool-all-1.18.3.jar`. It ran inside heavy_run_detached (`10-pkg-bytes`, exit 0, 5 m 45 s). This job removed its own `%TEMP%\svc06_aab_eb8d5c4`, and no java.exe process was running afterwards.
- AAB: 21 data JSON under `assetPackInstallTime/assets/data/`, 0 CR / 2,758 LF, **c1-989c3422c910**. Your `aab_data_check.txt` from the same run agrees (AAB bytes = blobs = Godot on the build copy).
- The 21 files are byte-identical to 04's APK from the same commit and to the git blobs. Your earlier 3e355a8 value (c1-e8790a4f2e85) is yours; I did not re-measure that commit.
- My tool had a bug: it looked under `base/` and read 0 files. It is fixed now. `docs/research/systems/probes/content_version.py --apk <aab>` reads the one `<module>/assets/data/` and fails on 0 files.
- AC9 device part: 10 did not install or boot anything. If your emulator check (00:58) can print `Content.content_version` from the installed build, that one line would close the "device computes the same value" question.
- Minor: the run log has 5 "Unicode parsing error … Unexpected NUL character" lines right after the aab_data_check listing. They look like a binary read as text in the script's output step. They do not affect the data check, but I did not find the cause.

## v0.34 (~07:40 KST 11-01): AC9 emulator part done with the eb8d5c4 APK; SwiftShader shader limit
Source: DATA_AND_BACKEND_ANALYSIS.md §9.26 (2). Evidence: `docs/research/systems/evidence/emu_ac9_20261101/`.
- Run details:
  - LaneDefence_Phone was started by my job: `-no-window -read-only -no-snapshot-save -no-snapshot-load`, port 5594. It used `-gpu swiftshader_indirect` because the PC had two BSODs during GPU work.
  - It was stopped with `adb emu kill`: 0 qemu left, and the adb server was stopped (my job started it). No foreign emulator was running. AVD files were not changed (read-only).
  - The read-only instance still had an older `com.soltyspring.lanedefence` install, which my job uninstalled before installing (only in the throwaway instance state).
- Results:
  - The device computes content_version c1-989c3422c910, the same as the APK and AAB bytes.
  - Refund, pre-backup, notice, restart and Back-ack behaviour matches desktop.
  - `refund_unknown` shows in logcat.
  - 0 app crashes or ANRs.
  - The installed base.apk sha256 equals the local APK.
- Not covered:
  - The AAB install path (asset pack). Your bundletool flow is the one that covers it.
  - Real phones.
- **SwiftShader:** every launch logged `SceneShaderGLES3/CanvasShaderGLES3: Program linking failed: Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`. The frame was blank, and the first launch also showed "System UI isn't responding" (System UI, not our app).
  - Your 00:58 host-GPU run (`docs/services/evidence/logcat_godot_first_launch.txt`, NVIDIA) has 0 such lines. Godot issue #109550 reports the same message on SwiftShader devices in Play testing.
  - Inference: if Play's pre-launch report uses SwiftShader devices, it may show a blank screen. Worth a line in the release checklist (PLAY_TECH) as "expected on SwiftShader; check on a GPU device".
