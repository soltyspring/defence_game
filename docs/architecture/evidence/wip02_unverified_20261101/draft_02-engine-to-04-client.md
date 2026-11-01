
## 2026-11-01 — R16, R17-2, R19 done; round unlocks are now id-based (10 v0.34): please switch two reads (commit SHA in my handoff)
- **R16:** `HudSnapshot.threat` = `{view_left, view_right, nest_left, enemy_visible, ground_screen_y, enemy_right?, enemy_left?}`. All values are world px except ground_screen_y. `enemy_right` and `enemy_left` are absent when there is no enemy on that side. `nest_left` is the enemy base's drawn left edge from the current base frame. It is computed in `battle.gd._threat()` at 10 Hz. INTERFACES §1.3.
- **R17-2:** `_update_camera` raises the ground row by the bottom safe inset: `ground_screen_y = view.y − 70 − inset`, where inset = `floor(view.y − SafeArea.safe_rect().end.y)`, clamped to 0…25 % of view.y. Your safe_area.gd returns the full view on desktop, so desktop and headless runs are unchanged. Not tested with a real inset (no device, no override run).
- **R19:** lane damage numbers use Galmuri11 at 12 px (ink 11 px, 1.75 mm on 360 dp), with a 1 px outline and a 14 px stagger step. 02's headless replay of r08 (text_overlap_probe) is in my evidence.
- **Please change (your files):** `round_select.gd:60 is_round_unlocked()` and `upgrade_panel.gd:87 visible_upgrades()` read `progress.unlocked_round` directly. After a content update that inserts or moves rounds, that number is only the leading playable run. Cleared rounds behind a new unplayed round stay playable through `Save.is_unlocked(i)`, but your screen would show them locked, which is exactly 10's v0.34 symptom.
  - Use `Save.is_unlocked(order_index)` for tiles.
  - Use `Save.upgrade_locked(upgrade_id)` (or `Save.round_reach()` against the unit's unlock_round) for upgrades. An upgrade already bought (level ≥ 2) is never locked.
  - Normal play gives the same values as before.
