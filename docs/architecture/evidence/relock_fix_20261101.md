# 10 v0.34: cleared rounds re-locked by a content update — fix in save.gd (2026-11-01)

Owner: 02-engine. Request: coordination/requests/10-research-systems-to-02-engine.md v0.34 (pass criteria U1–U6).
10 found the cause in the step-5 rule (from 10's own v0.15 spec, implemented as written in 7f2886c): `unlocked_round` was
recomputed as the length of the leading run of rounds that are first / starred / after a starred round, so one closed
round closed every round behind it.

## New rule (save.gd)
- `Save.is_unlocked(i)`: order[i] is playable iff i < `unlocked_round` (playable prefix) **or** i == 0 **or** `stars` has
  order[i] **or** order[i−1] **or** order[i] ∈ `progress.open_rounds`.
- Content migration step 5 (only when the save has a previous content_version, as before): the ids that were playable
  before the update = `content_snapshot.order[0 : unlocked_round]` (+ old `open_rounds`), mapped by `round_renames`.
  In the NEW order a round is playable if it was playable before (U2) or the star rule opens it. `unlocked_round` = the
  leading playable run; `open_rounds` = rounds beyond that run that are playable only because they were before (not
  derivable from stars). Every round cleared → `unlocked_round` = rounds + 1 is kept (U4: no 11 → 10 rewrite).
- `record_result`: a win inside the prefix (or a forced dev win of a locked round) advances the prefix as before; a win
  of a round that is open only by id opens the next round through its star, without opening the rounds in between.
- `Save.round_reach()` (furthest playable round) replaces `unlocked_round` in `_upgrade_locked`; `Save.upgrade_locked(id)`
  and `buy_upgrade` never lock an upgrade the player already bought (U5).
- Before: a save with stars r01–r05 and unlocked 6 went to unlocked 3 with r03–r05 locked after two inserted rounds.
  Now: unlocked 3 (prefix r01, r02, r02x) but r03–r06 stay playable through `is_unlocked`. **The number alone no longer
  lists every playable round**: UI must call `Save.is_unlocked(i)` / `Save.upgrade_locked(id)` (04's round_select.gd
  and upgrade_panel.gd read `unlocked_round` directly today; request sent to 04).
- U6: no repair of already migrated saves (pre-launch; line 408's same-version skip would not run it anyway).

## Results — 10's probe_relock.gd + relock_variants.py on a HEAD 52cf31a snapshot + this save.gd (run 1, 08:2x KST)
Raw: `relock/relock_run1_20261101.log`. Every boot isolated (private APPDATA, isolated_godot.ps1). Seeds made with the real
`record_result` / `buy_upgrade` on unchanged data (make_mid: r01–r05 cleared, up_melee L2, up_fast L2, unlocked 6).
| case (one update unless noted) | unlocked_round | playable rounds | cleared but locked | file written |
|---|---|---|---|---|
| no change | 6 | r01–r06 | — | no |
| cap4 (max_level 5→4) | 6 | r01–r06 | — | no |
| remove_r03 (M1 shape) | 6→5 | r01 r02 r04 r05 r06 (r07, r08 locked) | — | yes (+ backup) |
| insert1 (r02x after r02) | 6→7 | r01 r02 r02x r03–r06 | — | yes |
| insert1 then insert1b (chain, r02x not played) | 7→3 | r01 r02 r02x r03–r06 (r02y locked) | — | yes |
| insert2 (r02x, r02y in one update) | 6→3 | r01 r02 r02x r03–r06 (r02y locked) | — | yes |
| move_r03_end | 6→5 | r01 r02 r04 r05 r06 r03 (r07–r10 locked) | — | yes |
| rename2 (r03/r04 renamed, no round_renames) | 6→3 | r01 r02 r03n r05 r06 (r04n = new id, locked) | — | yes |
| rename2_map (with round_renames) | 6 | r01 r02 r03n r04n r05 r06 | — | yes (stars renamed) |
| bytes_only, mid save | 6 | r01–r06 | — | **no** |
| bytes_only, all-cleared save (unlocked 11), 1st and 2nd boot | 11 | r01–r10 | — | **no** (rev 11 kept) |
| bytes_only and cap4, "incons" save (unlocked 6, stars r01–r02 only) | 6 | r01–r06 | — | no |
- U1 cleared-but-locked = [] in all 17 boots. U2: r06 (playable, not cleared) stays playable everywhere; a renamed id
  without `round_renames` is a new round. U4: no write for bytes / cap-only updates, including the all-cleared save.
- U5: `up_fast` (bought L2) is never reported locked. `up_siege` (L1, never bought) is locked after remove_r03 because the
  furthest playable round drops from 6 to 5 while siege's unit unlock_round stays 6 (data semantics, not a bought upgrade).
- U3 (M1/M2 of run_content_migration) is re-run in the same job as the animation change (results in the 02 handoff).
