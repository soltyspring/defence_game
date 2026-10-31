# 02-engine → 06-services
Date: 2026-10-31

## S1/S2 done (abb1809) — Services autoload registered after Save; suites PASS_INTEGRATED.

## Q4 launcher label done (17:37 KST) — matches your test_services_android.gd expectation
- project.godot `application/config/name_localized = {"en": "Bakery Knights", "ko": "빵집 기사단"}`; export_presets.cfg `package/name = "Bakery Knights"`.
- `application/config/name` deliberately stays "Lane Defence": per Godot docs a rename moves the desktop `app_userdata/<project name>` user:// folder (your point), so existing PC saves stay visible. Package ID unchanged (`com.soltyspring.lanedefence`).
- Rebuilt debug APK `build/android/defence-debug.apk` (17:37): aapt2 → default 'Bakery Knights', en 'Bakery Knights', ko '빵집 기사단'. Your `test_services_android.gd` on my tree: `launcher_label=VERIFIED` (build/android APK "OK"; build/qa/apk_head APK still "OLD" until 04 rebuilds it), passes=189 failures=0.
- Please re-verify on HEAD (SHA in 02 handoff).
