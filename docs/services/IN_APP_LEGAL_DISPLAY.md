# In-app privacy policy link and open-source licence display (owner: 06-services; UI owner: 04)
Version: 1 (2026-10-31). Status: **proposal for 04** (request in coordination/requests/06-services-to-04-client.md, M11). 06 does not edit UI. Not legal advice; the font and engine licences are permissive but their text must actually reach the player.

## 1. Requirements (sources checked 2026-10-31, paraphrased)
| ID | Requirement | Source |
|---|---|---|
| L1 | Privacy policy: link in Play Console AND a link or the text inside the app; required even when no data is collected | https://support.google.com/googleplay/android-developer/answer/10144311?hl=en |
| L2 | Godot is MIT-licensed; the only requirement is to make the licence text available to the user. Acceptable places: a credits screen, a separate "Third-party / Open source licenses" screen (often in settings), the output log on Android, or a link to godotengine.org/license. Godot also contains third-party code with its own permissive licences; `Engine.get_license_text()`, `Engine.get_copyright_info()` and `Engine.get_license_info()` return this from the engine binary | https://docs.godotengine.org/en/stable/about/complying_with_licenses.html |
| L3 | Galmuri (SIL OFL 1.1): the font may be bundled and sold with software only if each copy contains the copyright notice and the licence, as a stand-alone text file, human-readable header, or in the software's readme/licence | assets/fonts/OFL-Galmuri.txt condition 2; provenance assets/fonts/fonts_provenance.json (Galmuri v2.40.4, no Reserved Font Name declared). The shipped fonts are subsets, i.e. Modified Versions, which OFL allows under the same licence |
| L4 | Art and audio: original work made for this project, no third-party assets | docs/art/ART_DIRECTION.md ("Licence: original work"); 05 generates SFX/music itself (docs/audio/) — 05 to confirm no third-party samples |
Content was rephrased for compliance with licensing restrictions.

## 2. Current state (read 2026-10-31, HEAD 8ad912f)
- Settings → "Credits" (src/ui/settings_panel.gd) shows the Galmuri credit line (`ui.font_credit`), the text "SIL Open Font License 1.1: assets/fonts/OFL-Galmuri.txt" and the Galmuri repository address. **Gaps:** (a) the OFL text itself is not readable in the game, and the file path shown is not something a player can open; (b) the OFL text file is missing from the inspected APK (07e97ca; fix in 141d226 not yet re-verified, 04 A6); (c) no Godot licence text; (d) no privacy policy entry.
- No network permission, so any link must open the system browser (`OS.shell_open`) rather than load inside the game.

## 3. Proposed placement (06 recommendation; 04 decides layout)
| Item | Where | Content | Works offline |
|---|---|---|---|
| Privacy policy | Settings, a row/button "개인정보처리방침 / Privacy Policy" next to Credits; also on the store listing | Opens `{{PRIVACY_POLICY_URL}}` in the browser. Below the button one line: "현재 이 게임은 개인정보를 수집하지 않습니다 / This game currently collects no personal data" (true only in disabled mode; change marker as in PRIVACY_POLICY_DRAFT.md) | Button needs a browser + network; the one-line summary is offline. Optional: bundle the policy text and show it in a scroll view (Play allows text in the app), but then it must be updated with every policy version |
| Credits | Settings → Credits (exists) | Game title, developer `{{DEVELOPER_NAME}}`, "Art, music and sound: original works made for this game", "Font: Galmuri by Lee Minseo (quiple), SIL Open Font License 1.1", "Made with Godot Engine" | Yes |
| Open-source licences | Settings → Credits → "오픈소스 라이선스 / Open source licenses" (scrollable text view, Back returns) | (1) Full OFL 1.1 text with the Galmuri copyright line, read from `res://assets/fonts/OFL-Galmuri.txt` at runtime (file must be in the export, 02 include_filter); (2) Godot MIT text from `Engine.get_license_text()` with the "This game uses Godot Engine…" lead-in; (3) third-party components from `Engine.get_copyright_info()` / `Engine.get_license_info()` | Yes |
| Billing/ads plugin licences | Same licences view, only if a plugin ships | MIT text of the chosen plugin (BILLING_PLUGIN_CANDIDATES.md: both candidates MIT) and any SDK notices | Yes |

## 4. Acceptance checks for 04 (proposed)
1. In a release-style APK/AAB: the OFL text file is present (unzip listing) and the licences view shows its first line "Copyright (c) 2019–2025 Lee Minseo" and the OFL title.
2. The licences view shows "Permission is hereby granted, free of charge" (Godot MIT) and a non-empty third-party list from the engine.
3. Privacy button opens the browser with the configured URL; with no URL configured it is hidden, never pointing at a placeholder.
4. `aapt2 dump permissions` still reports none after adding the button.
5. All text wraps at 1× and 2×, ko and en (04's existing typography checks).

## 5. Open points
- Hosting and URL of the privacy policy: user (OPEN_DECISIONS.md U3).
- Whether `libc++_shared.so` shipped by the Android export template is covered by `Engine.get_copyright_info()`: **not verified**; 04/02 check the template's notices.
- 05 to confirm audio contains no third-party samples (L4).
