# INTERFACES.md — runtime contracts (owner: 02-engine)
Version: 1.0 (2026-10-31). Godot 4.7.2 / GDScript. Additive changes only without a version bump; breaking changes announced via coordination/requests.

## 1. Signal bus `Events` (autoload, src/core/events.gd)
UI (04) emits `cmd_*` signals and listens to state signals. Gameplay (02) does the reverse. Nobody else holds node references across ownership boundaries.

### 1.1 Engine → UI (state)
| Signal | Args | When |
|---|---|---|
| `screen_changed(screen: StringName, params: Dictionary)` | `&"menu" \| &"round_select" \| &"battle" \| &"result"` | router switched screen |
| `battle_started(info: Dictionary)` | see §1.3 `BattleInfo` | battle scene ready |
| `hud_snapshot(s: Dictionary)` | see §1.3 `HudSnapshot` | 10 Hz during battle + immediately after any command |
| `battle_ended(result: Dictionary)` | see §1.3 `BattleResult` | emitted ONCE, ~1.2 s after the final blow, right after `result.tscn` is mounted (also readable as `App.last_result`) |
| `battle_paused(paused: bool)` | | pause toggled (incl. app lifecycle) |
| `toast(key: String, args: Dictionary)` | keys: `not_enough_gold`, `army_full`, `on_cooldown`, `not_enough_mana`, `hero_dead`, `wave_incoming`, `boss_incoming`, `worker_max` | feedback |
| `progress_changed(p: Dictionary)` | see §1.3 `Progress` | after save/unlock |
| `floating_text(world_pos: Vector2, text: String, kind: StringName)` | kind `dmg`,`heal`,`gold`,`crit` | optional; engine draws its own fallback |
| `tutorial_step(key: String)` | key from `round.tutorial` (text: data/text/<locale>.json), `""` = hide | engine TutorialDirector (src/gameplay/tutorial_director.gd): shows on trigger, hides when the player does the action or on timeout; never pauses. Also mirrored in `HudSnapshot.tutorial` |
| `wave_cleared(info: Dictionary)` | `{"index": int, "t": float}` | v1.4: a scripted wave is broken = every unit spawned BY that wave is dead (01 D21). Trickle, AI, base triggers, boss summons and `pressure: true` waves never count. Once per wave, in order, never after a loss. `index` = `HudSnapshot.wave.index` numbering |
| `sfx(cue: StringName, params: Dictionary)` | cues `deploy{unit}`, `worker_buy`, `skill{skill}`, `hero_death`, `hero_respawn`, `wave_incoming`/`boss_incoming{index,boss}`, `hit{kind: melee/ranged/siege, x}`, `shoot{projectile,x}`, `death{side,x,boss}`, `base_hit{side}`, `explosion{x}` | for 05-audio; combat cues coalesced to ≤1 per cue+kind per sim step |
| `content_migrated(info: Dictionary)` | `{"levels": int, "coins": int, "from": String, "to": String}` | v1.8 (01 D32): once per session, right after the menu is mounted, while a content-update notice is pending (§3). Text key `notice.content_migrated` |

### 1.2 UI → Engine (commands)
| Signal | Args | Effect |
|---|---|---|
| `cmd_start_round(round_id: String)` | | load battle for round (must be unlocked) |
| `cmd_deploy_unit(unit_id: String)` | | spend gold, spawn at player base (cooldown, cap checks) |
| `cmd_buy_worker()` | | buy a worker (raises income) |
| `cmd_hero_move(dir: int)` | -1 = retreat (left), 0 = hold, +1 = advance (right) | held-button style: send on press and 0 on release |
| `cmd_hero_skill(skill_id: String)` | | cast if mana/cooldown ok |
| `cmd_set_paused(paused: bool)` | | |
| `cmd_retry()` | | restart current round |
| `cmd_next_round()` | | start next unlocked round |
| `cmd_open_screen(screen: StringName)` | `menu`, `round_select` | navigation |
| `cmd_set_setting(key: String, value: Variant)` | `fps_cap` (30/60), `sfx`, `music`, `show_damage` | persisted in save |
| `cmd_ack_content_migrated()` | | v1.8: the content_migrated notice was shown; engine clears it and saves |

### 1.3 Dictionary shapes (keys are stable; extra keys may be added)
```gdscript
# BattleInfo
{ "round_id": "r01", "round_index": 1, "round_name": "Meadow Gate", "biome": "meadow",
  "cards": [ {"id":"spearman","name":"Spearman","cost":50,"cooldown":3.0,"icon": {"atlas":"ui_icons","frame":"card_spearman"}} ],
  "skills": [ {"id":"shockwave","name":"Shockwave","mana":40,"cooldown":8.0} ],
  "hero": {"id":"hero_knight","name":"Knight"}, "lane_length": 1200.0 }

# HudSnapshot (10 Hz)
{ "t": 12.4, "gold": 140, "gold_max": 999, "income": 6.0,
  "workers": 2, "workers_max": 8, "worker_cost": 78,
  "mana": 35.0, "mana_max": 100.0,
  "cards":  [ {"id":"spearman","cost":50,"cd":1.2,"cd_total":3.0,"ready":false,"affordable":true} ],
  "skills": [ {"id":"shockwave","mana":40,"cd":0.0,"cd_total":8.0,"ready":true} ],
  "hero": {"hp":420,"hp_max":600,"alive":true,"respawn":0.0,"x":310.0},
  "player_base": {"hp":1500,"hp_max":1500}, "enemy_base": {"hp":1200,"hp_max":1500},
  "wave": {"index":2,"total":5,"next_in":7.5,"boss":false},
  "army": {"player":6,"enemy":9,"cap":36}, "paused": false,
  "threat": {"view_left":80.0,"view_right":880.0,"nest_left":1012.0,"enemy_visible":false,"enemy_right":1180.0,"ground_screen_y":290.0} }
# threat (v2.0, 04 R16/R17-2): world x of the camera's left/right edges, the enemy base's drawn left edge, any alive
# enemy unit inside the view; enemy_right / enemy_left = nearest alive enemy beyond that edge (key ABSENT if none);
# ground_screen_y = ground row in view px from the top (view height − 70 − bottom safe inset).

# BattleResult
{ "round_id":"r01", "won":true, "stars":3, "time":95.2, "kills":41, "coins":60,
  "first_clear":true, "next_round_id":"r02" }   # next_round_id "" if none

# Progress
{ "version":1, "unlocked_round":3, "stars":{"r01":3,"r02":1}, "coins":120, "settings":{...} }
```

## 2. Data files (01 owns content; engine loader contract)
All JSON, UTF-8. Loader: `Content` (src/core/content.gd). Unknown keys ignored; missing keys take defaults below. Missing files → built-in defaults (src/core/default_content.gd). Numbers are floats unless noted. Distances in **world pixels** (base view 640×360, lane ground y≈300; player base x=40, enemy base x=lane_length-40). Speeds px/s, times seconds.

### 2.1 `data/units/<id>.json` (or one `data/units/units.json` with `{"units":[...]}` — both accepted)
```json
{ "id":"spearman", "name":"Spearman", "faction":"player",
  "cost":50, "cooldown":3.0, "hp":120, "atk":14, "atk_interval":1.0,
  "range":20, "speed":34, "attack_type":"melee", "projectile":"",
  "splash":0, "knockback":0, "armor":0, "targets":"ground", "bounty":8,
  "size":1, "anim_set":"spearman", "tags":["infantry"] }
```
`faction`: `player` | `enemy` | `both`. `attack_type`: `melee` | `ranged` | `siege` (siege prefers bases: ×2 vs base). `projectile`: anim id or "" (ranged default arrow). `splash` radius px (0 = single target). `armor` flat reduction (min 1 dmg). `bounty` gold to player on kill (enemy units only).

### 2.2 `data/heroes/<id>.json`
```json
{ "id":"hero_knight", "name":"Knight", "hp":600, "atk":30, "atk_interval":0.8, "range":24,
  "speed":70, "armor":2, "respawn":10.0, "mana_max":100, "mana_regen":4.0,
  "skills":["shockwave","rally"], "anim_set":"hero_knight", "leash":0.55 }
```
`leash`: max fraction of lane the hero may advance.

### 2.3 `data/skills/<id>.json`
```json
{ "id":"shockwave", "name":"Shockwave", "mana":40, "cooldown":8.0,
  "kind":"aoe_damage", "radius":90, "power":80, "duration":0, "fx":"shockwave" }
```
`kind`: `aoe_damage` (enemies within radius of hero), `heal_allies` (allies within radius, power=hp), `rally` (allies speed+atk ×(1+power/100) for duration), `meteor` (damage at frontmost enemy, radius), `summon` (`"unit":"id","count":n`).

### 2.4 `data/rounds/<id>.json`
```json
{ "id":"r01", "index":1, "name":"Meadow Gate", "biome":"meadow",
  "lane_length":1200, "player_base_hp":1500, "enemy_base_hp":1200,
  "start_gold":100, "hero":"hero_knight",
  "cards":["spearman","archer"],
  "waves":[ {"at":4, "spawns":[{"unit":"goblin","count":3,"interval":1.5}]},
            {"at":30,"boss":true,"spawns":[{"unit":"ogre","count":1}]} ],
  "enemy_ai": {"income":5.0, "start_gold":40, "pool":["goblin","goblin_archer"], "think":2.5, "after_waves_loop":true},
  "enemy_base_spawns_on_hp": [ {"below":0.5, "spawns":[{"unit":"goblin","count":4,"interval":0.6}]} ],
  "reward": {"coins":50, "first_clear_coins":100},
  "stars": {"time_3":120, "base_hp_2":0.5} }
```
Win: enemy base hp 0. Loss: player base hp 0. Stars: 1 = win, +1 if player base ≥ `base_hp_2` fraction, +1 if time ≤ `time_3`.

### 2.5 `data/economy.json`
```json
{ "gold_max":999, "base_income":4.0, "worker_income":2.0, "workers_start":1, "workers_max":8,
  "worker_cost_base":60, "worker_cost_growth":1.3, "mana_on_kill":2 }
```
Gold income/s = base_income + workers × worker_income.

### 2.6 Rounds order
`data/rounds/order.json` = `{"rounds":["r01","r02",...]}`; if missing, sorted by `index`.

### 2.7 Supported 01 design extension keys (implemented in battle_sim.gd v1.1)
- Data sets: if `data/<set>/` yields ≥1 valid entry, built-in defaults for that set are NOT mixed in.
- `data/game_config.json`: `caps.max_ally_units` (default 30), `caps.max_enemy_units` (40), `caps.max_projectiles` (64), `caps.max_vfx` (32), `caps.max_damage_popups` (24) — engine clamps to hard ceilings 40 / 40 / 64 / 48 / 24 (Perf constants). Enemy overflow policy = queue (retry every 0.5 s). `lane.ground_y` (290), `combat.deterministic_seed_default`.
- Round: `cards` null/empty → player units with `unlock_round ≤ index` sorted by unlock_round then cost (max 5). `skills` explicit list (filtered to hero skills) or empty → hero skills with `unlock_round ≤ index` (max 3). `gold_max`, `workers_max` override economy. `enemy_scaling{hp,atk}` multiplies enemy unit stats. `enemy_tower_atk_mult`. `trickle{start,pattern,interval,interval_min,ramp_per_min}`. `reward.three_star_bonus_coins` (first time reaching 3★). `tutorial`, `boss_round`, `name_key` are passed through in BattleInfo.
- Unit: `structure_mult` (damage multiplier vs bases; if absent siege=2, else 1), `self_destruct` (dies after its attack resolves, no bounty), `kill_coins` (meta coins on kill, summed into result), `is_boss` or tag `boss` (immune to knockback, `boss` toast), `summon{unit,count,interval,max_alive}`, `knockback` px (decays 300 px/s). `armor` is flat (dmg = max(1, atk − armor)).
- Hero: `mana_start`, `respawn_per_death`, `respawn_max`, `invuln_on_spawn`, `attack_while_moving` (default true), `aura{radius, atk_speed_mult}`.
- Skill: `offset_x` (area centre = hero.x + offset), `knockback`, `delay` (meteor: delayed impact, position locked at cast; target = frontmost enemy within 320 px ahead else hero.x+120), `unlock_round`. `cast_time` currently ignored.
- Economy: `base_tower{atk, atk_interval, range}` → both bases shoot (enemy × `enemy_tower_atk_mult`); `loss_coin_ratio` of kill_coins kept on loss.
- Meta (`data/meta.json` upgrades): applied at battle start from `Save.progress.upgrades{upgrade_id: level}` — `unit:<id>` hp/atk mult, `hero:<id>` hp/atk mult, `resource:supply` regen_add/cap_add, `resource:energy` regen_add/cap_add, `worker` income_add, `base:player` hp_mult.
- Rewards (App): win → first clear `first_clear_coins` else `coins`, + kill_coins, + 3★ bonus once. Loss → kill_coins × loss_coin_ratio.
- Not yet implemented (ignored): `hit_frame`, `cast_time`, `chapter`, data/text localisation (04 owns UI text).
- v1.2 (2026-10-31): `round.skills` explicit list (including `[]` = no skills, r01) is authoritative; only absent or all-null lists derive from `unlock_round`. Both bases reaching 0 HP in the same sim step = player win. Damage applied outside `step()` (commands/tests) resolves the battle immediately.
- v1.2 additive keys: BattleInfo `battle_uid` (`"<unix>-<32 hex>"`, 128 random bits, unique per battle instance), `tutorial`, `boss_round`; BattleResult `battle_uid`, `tutorial_done` (keys completed this battle); HudSnapshot `tutorial` (current key or ""), `boss{alive,hp,hp_max,id,name_key}`, `speed`. Progress `tutorial_done: Array[String]` (completed keys are not shown again).
- Per-battle atlas residency uses `Content.round_enemy_roster(round)` (waves, AI pool, trickle, HP triggers, boss summons) instead of every enemy.
- v1.4 (2026-10-31): wave entries with `"pressure": true` (01 D18/D21) spawn normally but are excluded from `waves_total`, `HudSnapshot.wave.{index,total,next_in,boss}`, the `wave`/`boss_incoming` toast and `wave_cleared`. Entity caps have ONE source: `Content.caps()` = data/game_config.json `caps` (missing keys: `Content.CAPS_DEFAULT`, same values) clamped to perf.gd ceilings. Effective today: ally 36, enemy 36, projectiles 64, fx 48, damage texts 24 (ceilings 40/40/64/48/24). Pools are preallocated to these caps at battle setup.
- v1.5 (2026-10-31, 01 D29, design: docs/architecture/BASE_DAMAGE_OPTIONS.md): `economy.base_defense{dps_cap, push_px, stagger_s, tower_splash}`, PLAYER base only. Every key missing or 0 = off = the behaviour before v1.5 (bit-identical bot results). `dps_cap` = at most that many HP lost per sliding 1 s window (the excess is dropped; a fully absorbed hit shows no damage text, flash, shake or `base_hit` cue; the text shows the applied amount). `push_px` = knock-back (px, decays 300 px/s) given to a non-boss enemy each time it hits the player base. `stagger_s` = extra attack delay after such a hit. `tower_splash` = splash radius (px) of the player base tower bolt. Values are 01's (data/economy.json); the engine only reads them at battle setup. `BattleSim.base_dmg_capped` = HP removed by the cap this battle (probe/QA evidence). Acceptance probe: `src/core/diag/base_damage_probe.gd`.

## 3. Save file (engine-owned; 04 may build settings UI on top)
`user://save.json` (+ `user://save.json.bak`). Written atomically via `save.json.tmp` → rename; previous file kept as `.bak`. Content: `{"version":1,"checksum":"<sha256 of payload string>","payload":"<Progress serialised as JSON string>"}` (payload is a string so the checksum is byte-exact). On parse/checksum failure → load `.bak` → else fresh defaults, and record `recovered:true` (UI may toast). Migration hook `Save._migrate(payload, from_version)`.
v1.3 (2026-10-31, docs/architecture/SAVE_FAULTS.md): load order main → verified `.tmp` → `.bak` → fresh; unreadable mains are quarantined as `save.json.corrupt-<unix>` and never rotated into `.bak`; `Save.recovery_source` (main|tmp|bak|fresh); `Save.read_only` for newer-version files (never written); `Events.toast("save_failed", {error})`; `record_result(result, idx) -> bool` idempotent per `battle_uid` (`progress.applied_battles`, last 32) with rollback on write failure; `Save.was_applied(uid)`; debug-only `Save._fault` ∈ `Save.FAULT_POINTS` = after_tmp_write | torn_tmp | after_bak_rename | before_final_rename (one-shot; `fault_fired`). New Progress keys: `revision`, `upgrades`, `applied_battles`, `tutorial_done`.
v1.5 meta upgrades: `Save.buy_upgrade(upgrade_id, to_level) -> String` buys ONE level (to_level must be current+1): validates first, deducts coins and raises `progress.upgrades[id]` in one atomic save, rolls both back on a failed write. Codes: `ok`, `already_applied` (to_level ≤ current; repeat/double tap), `max_level`, `not_enough_coins`, `unknown_id`, `locked` (target unit's unlock_round > unlocked_round), `invalid_level` (skips a level), `save_failed` (nothing changed), `save_uncertain` (memory rolled back but the verified .tmp may be adopted on the next launch), `read_only`. Helpers: `Save.upgrade_level(id)`, `Save.upgrade_cost(id, to_level)` (meta.json `costs[to_level-2]`, -1 if none). UI path: `Events.cmd_buy_upgrade(id, to_level)` → App → `Events.upgrade_result({id, to_level, code, coins, level})`; `progress_changed` fires on success; `toast("save_failed")` on save_failed/save_uncertain. Battles read levels at start (`BattleSim.setup(..., upgrades)`).
v1.6 (10 F1): after a failed `save_progress()`, `Save.last_failure_uncertain` is true when the files on disk would make the next `load_progress()` adopt that write (main unreadable/missing and a valid `.tmp`). `buy_upgrade` returns `save_uncertain` in exactly that case (else `save_failed`, which now always means "disk unchanged"); App marks `BattleResult.save_uncertain = true` for record_result failures in that state.
v1.7 (10 R5, PROVISIONAL rules until 01 decides): every successful save writes `content_version` (= `Content.content_version`, "c1-" + sha256 of sorted data/**/*.json [:12]) and `content_snapshot` {upgrades: {id: {target, costs, max_level}}, order}. On load with a different content_version, in ONE save (rollback on failure): upgrade renames (`data/migrations.json` `upgrade_renames`, else same-`target` match), round renames (`round_renames`), clamp levels to max_level with a once-only refund at the snapshot's recorded prices (`refund:<cv>:<id>` in `migrations_applied`; unknown price → 0 + warning), and id-based unlock recompute (order[i] open iff i==0 or stars[order[i]] or stars[order[i-1]]) — the recompute only when the save already had a content_version. Legacy saves without one and with nothing to fix are not rewritten during load; fresh loads never write. `Save.migration_log` lists what ran.
v1.8 (2026-11-01, 01 D32 + 10 F2/X1/v0.27/v0.28; replaces the PROVISIONAL parts of v1.7):
- Progress key `upgrade_paid {id: {"<level reached>": coins paid}}`, written by `buy_upgrade` in the same atomic save as coins and level and removed on rollback. `_migrate` keeps only levels 2..current with int values ≥ 0.
- Content migration order: upgrade renames → **retired upgrades** (id gone from meta.json and not renamed: refund all levels, remove the level and the paid record) → clamp to max_level with refund → round renames → id-based unlocks. Refund price per level = `upgrade_paid` (actually paid), else the snapshot price, else 0 + `content/refund_unknown`. Once per (content_version, id) (`refund:`/`retire:` keys in `migrations_applied`). Coins clamped to the gold cap once. If meta.json has no upgrades at all, upgrades are left alone.
- **No write during a load when nothing changed** (any previous content_version; 10 X1). The next ordinary save stamps the new version.
- **F2:** if the migration write fails, memory is rolled back and `Save._migration_pending` keeps every later save in that session on the OLD content_version/snapshot, so the next launch migrates again (refund still once).
- Before a migration writes, the loaded file is copied to `save.pre-<old content_version>.json` (legacy saves: `save.pre-legacy.json`). Ordinary saves never touch it. An existing copy for the same old version is kept. The newest 2 are kept.
- Quarantined `save.json.corrupt-*` copies: the newest 3 are kept.
- Notice (D32 (3)): a migration that removed levels or refunded coins stores `progress.migration_notice = {levels, coins, from, to}` (unseen notices add up). `Save.migration_notice()` reads it. `Save.last_migration` holds this session's result. App emits **`Events.content_migrated(info)`** once per session after the menu screen is mounted while a notice is pending. The UI shows `notice.content_migrated` (`{levels}`, `{coins}`, 01's text) and then sends **`Events.cmd_ack_content_migrated()`**, which clears the notice and saves. The engine fallback menu shows and acknowledges it itself.

## 4. Scenes the engine instantiates (04 provides; fallback exists)
| Path | Root type | Contract |
|---|---|---|
| `res://scenes/ui/main_menu.tscn` | Control | emits `Events.cmd_open_screen(&"round_select")` / `cmd_start_round` |
| `res://scenes/ui/round_select.tscn` | Control | reads `Content.get_round_list()` + `Save.progress`; emits `cmd_start_round(id)` |
| `res://scenes/ui/hud.tscn` | Control (full rect) | listens `battle_started`, `hud_snapshot`, `toast`; emits battle cmds |
| `res://scenes/ui/result.tscn` | Control | listens `battle_ended`; emits `cmd_retry`, `cmd_next_round`, `cmd_open_screen` |
UI scenes are added under a `CanvasLayer` (layer 10) the engine owns. Read-only queries allowed: `Content.get_round_list() -> Array[Dictionary]` (`id,index,name,biome`), `Content.get_unit(id)`, `Save.progress` (Dictionary, read-only), `Atlas.get_frame_texture(atlas_id, frame) -> AtlasTexture` for icons.
v1.9 (2026-11-01, 03 A19 / 04 R17-3) battle camera: the ground row stays `battle.GROUND_FROM_BOTTOM` = 70 view px above the view bottom in every view size. Optional world-only zoom `App.world_zoom()` = (k+1)/k with k = `App.pixel_scale` (4/3 at k = 3, 3/2 at k = 2), so one art pixel is k+1 device pixels. Switch: project setting `game/camera/world_zoom_plus_one` (bool, **default false** = zoom 1, camera identical to v1.8). Dev/test user args: `--world-zoom=on|off`, `--world-zoom-k=<k>` (framing of a k-scale phone in a k=2 window). The HUD CanvasLayer is never zoomed. Visible world width = view width / zoom (`battle.view.view_w`); `battle.world_zoom` = the zoom of the last frame. Turning it on waits for 03's D1 art and 01's warning-time check.
v2.0 (2026-11-01):
- **Unlocks (10 v0.34):** `Save.is_unlocked(i)` = i < `unlocked_round` (playable prefix) or i == 0 or `stars` has order[i] or order[i−1], or order[i] is in `progress.open_rounds` (ids a content update kept open beyond the prefix; absent in normal play). A content update recomputes both from the ids that were playable before (`content_snapshot.order[0:unlocked_round]` after `round_renames`) plus that rule, so cleared and previously playable rounds never close and unearned rounds never open. `Save.round_reach()` = furthest playable round (1-based) for unit unlock checks. `Save.upgrade_locked(id)`: target unit not reached yet; never true for an upgrade already bought (level ≥ 2). **UI must use these instead of reading `unlocked_round`** (it no longer expresses every open round). A save with every round cleared keeps `unlocked_round` = rounds + 1 across updates.
- **Unit display (07 QA-B025/QA-O006):** `BattleView.anim_for(u, atlas)` picks death > hero `cast` (once per cast) > `attack` while its frames play > `hit` (once per hit, re-armed after `BattleSim.HIT_REARM` 0.6 s) > held attack > walk/idle. Deaths play at alpha 1 for the whole animation, then the last frame fades over `BattleView.DEATH_FADE` 0.3 s; corpses last `BattleSim.DEATH_TIME` 1.5 s (was 0.7 s; visual only). `BattleView.death_alpha(t, anim_len)` is the fade rule. The hero's death is drawn during respawn.
- Lane damage numbers: Galmuri11 at 12 px (04 R19, ≥ 1.7 mm), outline 1 px, step 14 px.
- Biome layers may carry `"opaque": true` (03): the clear-colour rect under the layers then skips the rows that layer covers (08 P11; pixel-identical; selftest checks the flag against the PNG alpha). `battle.view.clear_px_drawn` = area drawn last frame.

## 5. Art: atlas manifest (03 produces, 02/04 consume)
### 5.1 `assets/manifest.json`
```json
{ "version":1, "pixel_scale":1,
  "atlases":[ {"id":"char_player","group":"character","image":"res://assets/atlases/char_player.png",
               "frames":"res://assets/atlases/char_player.json","size":[1024,512],
               "disk_bytes":81234,"gpu_bytes":2097152,"biome":""} ],
  "anim_sets": { "spearman":"char_player", "goblin":"char_enemy", "hero_knight":"char_player",
                 "arrow":"fx_combat", "shockwave":"fx_combat" },
  "bases": { "player":{"atlas":"bases","frame":"base_player"}, "enemy":{"atlas":"bases","frame":"base_enemy"} },
  "biomes": { "meadow": {"atlas":"biome_meadow", "layers":[ {"frame":"sky","parallax":0.1}, {"frame":"hills","parallax":0.4}, {"frame":"ground","parallax":1.0,"tile":true} ] } },
  "ui": { "atlas":"ui_main" } }
```
`group`: `character` | `fx` | `ui` | `biome` | `base`. Engine acquires: `ui` always; per battle: roster `character` pages, `fx`, `base`, and the round's `biome` page; released when battle exits.

### 5.2 Per-atlas frames file `assets/atlases/<id>.json`
```json
{ "atlas":"char_player", "image":"char_player.png", "size":[1024,512], "padding":2, "extrude":1,
  "frames": { "spearman/walk/0": {"x":2,"y":2,"w":32,"h":32,"pivot":[16,31]} },
  "anims": { "spearman": {
      "idle":   {"frames":["spearman/idle/0","spearman/idle/1"], "fps":4,  "loop":true},
      "walk":   {"frames":["spearman/walk/0", "..."],            "fps":8,  "loop":true},
      "attack": {"frames":["..."], "fps":10, "loop":false, "hit_frame":2},
      "hit":    {"frames":["..."], "fps":10, "loop":false},
      "death":  {"frames":["..."], "fps":8,  "loop":false} } } }
```
- Required anim names per character: `idle, walk, attack, death`; optional `hit`, `cast` (hero), `spawn`. FX: `play` (one-shot) or `loop`. Projectiles: `fly`.
- `x,y,w,h` = frame rect inside the page excluding extrusion. `pivot` = pixel inside the frame placed on the ground point (bottom-centre feet for characters, centre for fx/projectiles).
- All characters drawn **facing right**; engine mirrors enemy faction with `flip_h`.
- Frame names: `<anim_set>/<anim>/<n>` recommended (not required).
- Scale: base view 640×360; infantry ~24–32 px tall, hero ~32–40 px, bases ~96–128 px tall, lane ground at y≈300.
- `hit_frame` = index where damage applies (engine applies damage at that frame time; fallback 50% of attack anim).

### 5.3 Import rules (03 writes `.import`-compatible settings or 02 sets project defaults)
Lossless, no mipmaps, nearest filter, no repeat, `process/fix_alpha_border=true`. 03 publishes `docs/art/ATLAS_BUDGET.md` with per-page disk & GPU bytes; 02 verifies residency at runtime via `Perf.texture_report()`.

## 6. Fallback guarantee
Every reference (unit, hero, skill, round, atlas, anim, UI scene) has a fallback. The game must stay playable with `data/`, `assets/` and `scenes/ui/` all empty. `selftest.gd` checks this explicitly.
