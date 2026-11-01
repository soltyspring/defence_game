# 04-client status
Updated: 2026-11-01 09:2x +09:00
Status: STOPPED by the user (09:17 "이제 그만만들고 멈춰", "푸시하고 끝내"). Details and exact next steps: coordination/handoffs/04-client.md, section "09:2x USER STOP".
On main: 2de6668/ad47eda D32 menu notice; e2404af 08 R8 draw calls 132 → 129 (target ≤ 100 not met; glyph-page cause, not proven by a run); a3bbc72 notice test leftovers fixed (gate UI 3414/0, integration 49/0, migration 17/0).
Not in main (unverified, left in the working tree): HUD layout B (src/ui/hud_layout.gd, threat_marker.gd, touch_button.gd, main_menu.gd, round_select.gd, tests/ui/test_ui.gd), docs/qa/UI_LAYOUT_REFERENCE.md + docs/qa/layout_ref/ + tools/build/layout_options.py, tests/ui/drawcall_hud_probe.gd, and 4 request notes with a FEAT_SHA placeholder.
Heavy run still queued (not killed): 04-layout-b-gate2, pid 45580, log build/heavy/04-layout-b-gate2-20261101-080528.log (headless gate dry run; publishes nothing).
Waiting on others: 02 R16 `snapshot.threat` (07 QA-B026), R17, R18, R19; 06 frame redraw for the new sizes. Not done: real phone, human test.
