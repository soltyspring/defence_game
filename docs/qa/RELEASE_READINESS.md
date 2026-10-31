# Release readiness checklist — 04-client scope (Android pipeline, signing, privacy, UI/mobile QA)
Updated: 2026-10-31 15:50 +09:00. TESTED = run with the evidence named here; UNTESTED = not run; BLOCKED = cannot run without the named dependency.
This is NOT a release-ready claim. First playable is an internal milestone. Store publication and paid accounts are user actions.

## A. Build artefact (debug APK from HEAD 07e97ca)
Command: `.\tools\build\build_android_debug.ps1`. It exports from a `git archive` copy with its own `.godot` cache, so the shared tree's import cache is not touched, no emulator is started and no window opens. Evidence: `build/qa/apk_head/` (git-ignored): apk_report.json, badging.txt, permissions.txt, signing.txt, repo_secrets.txt, export.log.
| # | Check | Status | Evidence |
|---|---|---|---|
| A1 | Debug APK exports from a clean copy of HEAD | TESTED | 07e97ca, 47 s, `defence-debug.apk` |
| A2 | APK size | TESTED (debug only) | 59,106,028 B (56.37 MiB). Native libs 54.6 MB compressed (arm64-v8a + x86_64), game content ≈ 2.1 MB compressed. Under the provisional 60 MB budget only because content is tiny; the release must drop x86_64 (08 R1) |
| A3 | No raw source images, fonts or audio shipped | TESTED | 0 `.png`, 0 `.ttf`, 0 raw wav/ogg; 10/10 atlas pages present as imported `.ctex` (incl. char_*_adv, char_boss_*), 3 fonts as `.fontdata` |
| A4 | No tests/docs/tools/coordination/build files, scripts, keystores or .env in the APK | TESTED | inspect_apk.py: 0 FAIL |
| A5 | Dev/mock code in the APK | FOUND (debug acceptable, release not) | Shipped: src/ui/mock/* + scenes/ui/ui_preview (04), src/core/diag/selftest + src/gameplay/bot_player (02), src/services mocks (06; may be intended runtime fallbacks). Request: release preset exclude list (02, 04 R12) |
| A6 | OFL licence text shipped with the fonts | FIX CLAIMED by 02 (141d226), NOT re-verified in an APK by 04 | assets/fonts/OFL-Galmuri.txt is not in the APK; include_filter lacks `assets/fonts/*.txt` (02, requested in R9 and by 03 A2b). The in-game credits panel shows the credit and the file name |
| A7 | Permissions | TESTED | `aapt2 dump permissions`: none. No INTERNET (no ads/IAP/analytics yet) |
| A8 | SDK levels | TESTED | minSdk 24, targetSdk 36, compileSdk 36. Play's current target-API requirement must be re-checked on the release date (UNTESTED against policy text) |
| A9 | Package / version | TESTED | com.soltyspring.lanedefence (PROVISIONAL, user may change), versionCode 1, versionName 0.1.0 |
| A10 | Signing | TESTED (debug) | v2 + v3 verified; signer CN=Godot, OU=Godot Engine (debug keystore in tools/engine/editor_data, git-ignored) |
| A11 | No signing material or passwords in the repository | TESTED | At 07e97ca: 0 tracked keystore/jks/p12/pfx/.env/export_credentials files, 0 export_presets keystore/password values, 0 password literals (`git grep`) |
| A12 | Release APK/AAB, arm64 only, upload key via env vars | BLOCKED | needs a user-generated upload key (user action), Gradle/AAB setup (cmdline-tools, 02 A7/A9). Not started |
| A13 | Install + start on the emulator from this APK | UNTESTED by 04 | 02 owns the LaneDefence_Phone AVD; not touched. Time slot requested (04 R12). 02 has its own earlier evidence (ANDROID_BUILD A10) for an older APK |
| A14 | Physical device: start, touch, safe area, fonts, frame pacing, memory, thermals, battery | BLOCKED | no device attached |

## B. UI / mobile (desktop evidence only, DISPLAY2 secondary monitor)
| # | Check | Status | Evidence |
|---|---|---|---|
| B1 | Real engine mounts 04 screens (not fallback) | TESTED | tests/integration 31/31 headless + visible |
| B2 | Layout matrix incl. notches/integer-scale views; touch targets ≥ 40 logical | TESTED (math) | tests/ui 3000 configurations |
| B3 | Bundled Korean font, no OS fallback, full glyph coverage | TESTED | docs/qa/TYPOGRAPHY_QA.md |
| B4 | ko/en text fits the worst layout (theme A names, 01 14b01e2) | TESTED | cards: 0 ellipsis ko/en (07 TH-FIT-HUD PASS); round tiles: 2-line wrap, 0 truncated at 83/97 px (07 TH-FIT-ROUND still measures 1 line, see 04→07 15:50) |
| B5 | Pixel-regular text at 1× and 2× | TESTED | 1× capture build/qa/real4/{ko,en}_1x_*.png; 2× 0–5% odd runs |
| B6 | Pixel-regular text at 2.5× (non-integer devices, e.g. 1600×900) | TESTED (desktop) | 02 141d226 integer scale: 1600×900 → 800×450 view, 0.0% irregular glyph runs in HUD/round select/result, ko+en (build/qa/real7) |
| B7 | Base HP numbers, star met/unmet by shape, boss bar, tutorial hint, skill-name tip, credits | TESTED (desktop) | build/qa/real3, real4 |
| B8 | UI atlas icons correct | TESTED in a fresh HEAD snapshot (desktop); dev tree still stale | build/qa/real5/headsnap_ko_3d_skilltip.png (own import): unit portraits + skill icons correct. The shared dev tree still needs 02 --import (vector fallbacks there). Android not checked (A13) |
| B11 | Android back acts once per press; no HUD pause menu under the result | TESTED (07 flow suite on HEAD archive) | 0d8cc5b: FLOW-23/23B/13B PASS, flow 44/44 |
| B12 | No raw engine ids in toasts | TESTED | FLOW-04B PASS at 0d8cc5b; unknown keys are suppressed and logged |
| B9 | Multi-touch / back / lifecycle pause | TESTED (synthetic events) | tests/ui; not on a device |
| B10 | Real finger use on a phone | BLOCKED | device |

## C. Privacy, ads/IAP, consent (04 owns the architecture and release QA; 06 owns the adapters)
| # | Check | Status | Evidence |
|---|---|---|---|
| C1 | Data collected/shared by the current build | TESTED (static) | no INTERNET permission and no SDKs in the APK → nothing leaves the device. Play Data safety would currently answer "no data collected" (06 ANALYTICS_EVENTS §4). Re-check when any SDK is added |
| C2 | Ad/IAP/consent UI | NOT PRESENT (by design) | monetization undecided (01 D9). No purchase or ad buttons |
| C3 | Purchase restore / failure / pending UI | UNTESTED | 06 U1 states defined; UI after approval only |
| C4 | Privacy policy URL, consent (UMP) flow | BLOCKED | requires a user decision + accounts |

## D. Next actions
1. 02: OFL include, integer scale, release preset excludes, install slot (04 R9/R12).
2. 04: after the install slot, install `build/qa/apk_head/defence-debug.apk` on the AVD, capture menu/HUD and the credits screen, check that Hangul and icons render. The emulator is proxy evidence only.
3. User: connect a physical Android phone for A14/B10; generate a release upload key outside the repo for A12.
