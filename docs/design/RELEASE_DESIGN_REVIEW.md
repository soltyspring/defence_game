# Release design review — theme-neutral (01-director)
Date: 2026-10-31. Scope: data at commit e42f809 + fixes in this task. Theme Q1 is still unanswered; nothing here is user-approved. Monetization text is a recommendation only. No balance or performance numbers below are measured; every target is labelled as a target. 02's balance sim has not arrived yet (02-engine-to-01-director still only R1 at the time of writing).

## 1. Data audit findings (actual, from a PowerShell check of data/**)
Checked: order.json vs `index`, enemy first appearance vs `first_round`, cards/skills vs `unlock_round`, tutorial keys vs ko.json, upgrade targets vs unlocks, reward sums, ko/en key parity, duplicated values across files.

| ID | Finding | Type | Action |
|---|---|---|---|
| F1 | en.json had 21 of 60 ko keys. English UI would show Korean for all descriptions, round names, tutorials and upgrades | defect | **Fixed**: en.json now has 60/60 keys, parity verified |
| F2 | ROUNDS.md said 3 workers by t≈17 s; with the contract cost curve 40×1.3^n the actual figures are workers at t=0/6/16 s, 8.5 supply/s | stale doc | **Fixed** in ROUNDS.md |
| OK | order.json r01…r10 matches `index` 1…10 | pass | — |
| OK | Every enemy first appears exactly in its `first_round` (grunt r1, swarm r2, spitter r3, brute r4, warlord r5, bomber r7, overlord r10). No enemy is used before it is introduced | pass | — |
| OK | Round `cards` and `skills` match `unlock_round`. Each new unit or skill has a tutorial key in its unlock round | pass | — |
| OK | Upgrades appear with their unit (siege upgrade from r6). Reward sums: first clears 3,140, 3-star bonuses 780, all upgrades 6,280 | pass | — |
| C1 | Contract `reward{coins, first_clear_coins}` does not say whether first-clear coins **replace** or **add to** `coins`. Design intent is replace (meta.json `round_rewards_rule`) | ambiguity | Asked 02 (request R2) |
| C2 | `hero_captain.skills` lists all 3 skills. Until 02 implements `round.skills[]` gating, r01 shows Slam/Rally/Barrage from the first second, which breaks onboarding | P0 dependency | Restated to 02 as P0 |
| C3 | game_config.json repeats resources/worker/bases/tower values from economy.json, hero and rounds. The values match today but can drift | risk | Rule: economy/hero/rounds are authoritative for the engine. game_config is only for caps, camera, lane and respawn. Added to DATA_SCHEMA |
| C4 | Upgrade name keys are generic (`upgrade.unit`) | UI need | 04 composes "<unit name> + upgrade label" (request R2) |
| C5 | Enemies have no `desc_key`, which a codex or boss intro will need | gap | Backlog B21, not needed for P0 |
| R1 | r04 introduces 3 things at once (fast unit, Rally, brute) | pacing risk | Recommendation §2.3. Not changed: not an unambiguous defect |

## 2. First session and rounds 1–3 pacing
### 2.1 First-session flow (target ≤ 30 s from cold start to first deployed unit)
1. Launch → optional short logo → main menu with a single large "Play" button (round select hidden until r01 is cleared).
2. r01 starts with hero, 1 card (melee), the worker button and **no skill buttons**.
3. Tutorial banners are non-blocking and trigger on events:
   - tut_move_hero at t=0.
   - tut_deploy_unit after the first hero move or at t=4 s.
   - tut_buy_worker once supply ≥ 40 after the first deploy.
   - tut_destroy_base when any ally passes 50% of the lane.
   Each banner dismisses itself when the player performs the action.
4. First enemy contact: trickle starts at t=12, first wave at t=25. The enemy tower at 60% power gives the first push a real but non-lethal obstacle.
5. Win → results (stars + coins) → "Next" is the primary button. The upgrade screen is introduced after r02 (one free nudge, "Buy your first upgrade", with enough coins: 240 after r02 against a 60-coin first upgrade).
6. 2× speed and the pause menu are visible from r01, but 2× stays disabled during tutorial steps.
### 2.2 Intended rhythm (targets, to verify by sim and playtest)
| Round | New element | Planned decisions | Target first-try win | Target length |
|---|---|---|---|---|
| r01 | hero, melee, worker | invest vs spend | ≥ 95% | 90–150 s |
| r02 | ranged, Slam; swarm | first AoE timing, front/back line | ≥ 85% | 110–170 s |
| r03 | tank; spitter | composition (tank front), comeback spike at 60% / 25% | 60–80% (≥ 90% within 3 tries) | 140–200 s |
### 2.3 Recommendations (unapproved, reversible)
- r04 overload: move Rally to r05 so the boss round introduces the "push window" skill and r04 only teaches fast vs brute. Cost: one `unlock_round` edit plus moving a tutorial key. I will apply it only after the sim shows r04 is harder than its target, or on user or Codex direction.
- Show a one-line "why you lost" hint on the loss screen, chosen from data: base killed by spitters → suggest tank; by swarm → Slam; by brute → ranged.

## 3. Failure, retry and reward edge cases (rules for 02/04)
| Case | Rule |
|---|---|
| Retry or quit mid-battle | Forfeit: no coins and no kill coins. Counts as an attempt, not a loss. This prevents restart-farming kill coins |
| Loss | Keep `loss_coin_ratio` (50%) of kill coins only. No first-clear or star rewards. Offer Retry (primary), Upgrades, Menu |
| Both bases reach 0 in the same simulation tick | Player wins. Resolve the enemy base first so the result favours the player |
| Hero dies at the same moment the round ends | No effect on the result |
| First clear with 3 stars | Grant both first_clear_coins and three_star_bonus_coins |
| Replay with fewer stars | best_stars never decreases. Replay coins are still granted |
| 3-star bonus | Granted once per round (`three_star_claimed`) |
| Results screen double-tap or re-entry | Rewards are applied exactly once per battle instance (battle id). Granting coins and saving happen in a single atomic save write |
| App killed or backgrounded during battle | Auto-pause. If the process dies, the battle is lost with no reward and no penalty. Progress before the battle is intact |
| App killed between the win and the save | Accepted to lose that reward. The save is atomic, so either the full result is saved or none of it |
| r10 "Next" | next_round_id "" → chapter-complete screen, then round select |
| Coin cap (9,999,999) | Clamp. Unreachable in chapter 1 |
| Rebalance lowers an upgrade's max_level | Clamp the level and refund the coins for removed levels (save migration, 02) |
| Unknown round or upgrade IDs in a save | Ignore and keep them in the save, never crash |
| Rescue ad used (if monetization is approved) | Caps that run at 2 stars, so stars cannot be bought |
| Army cap reached | Card shows "army full" and no supply is charged |
| Local clock change (daily first-win) | Low-value exploit, accepted. Max one bonus per local calendar day. No server |

## 4. Monetization alternatives (recommendation only, NOT approved; Q2 after Q1)
Constraint for every model: chapter 1 can be cleared with zero spending, no stamina system, no forced mid-round interstitials, and non-consumable purchases must be restorable.
| Model | Revenue potential | Build/compliance cost | Player trust / fit | Offline |
|---|---|---|---|---|
| M1 Premium paid app | low volume, one-time | lowest: no SDK, no consent UI | high | full |
| M2 Free + rewarded ads (×2 results coins, base rescue) + "Remove ads / supporter" non-consumable | medium | ad SDK, consent (UMP/GDPR/Korean privacy notice), billing library, restore, Data safety form (04) | good if ads are opt-in only | ads need network; game playable offline |
| M4 Free chapter 1 + one-time chapter packs (chapters 2+) | medium, scales with content | billing + restore only, no ads | high (pay for content, not power) | full after purchase |
| M2+M4 hybrid | highest of the fair options | sum of both | good | as above |
| M3 Premium currency + random hero summons | highest ceiling | highest: Korean probability disclosure (Game Industry Promotion Act amendment, enforced 2024-03-22), live ops, balance | conflicts with the fair-progression pillar | weak |
Recommendation: M2 at launch (smallest content dependency) with M4 when chapter 2 exists. Not M3. Cosmetic skins only once the theme is fixed (atlas cost per skin, see §6).

## 5. Retention without stamina
- Per-round stars and chapter star milestones (proposal: 10/20/30 stars → 100/200/300 coins). Needs a data field. Backlog B22.
- Clear unlock cadence: something new in r1–r4 and r6–r8, bosses at r5 and r10.
- Replay challenges on cleared rounds (data-driven modifiers: "no tank", "hero only skills", "2× enemy speed"), each with a one-time coin reward. Reuses existing content at zero art cost.
- Daily first win ×2 coins (hook exists, disabled). Local date only.
- Endless survival mode with a local personal best. Reuses chapter 1 assets.
- Chapter 2 biome and a second hero unlocked by star total. This is the largest content cost.
- No energy/stamina, no login-streak loss penalties, no push notifications by default. Notifications need opt-in and are a user decision.

## 6. Content production cost and atlas reuse constraints
Atlas page budget and packing are owned by 03. The figures below are design-side estimates, not measurements.
- Per character: idle 2 + walk 4 + attack 4 + hit 1 + death 4 ≈ 15 frames. A 32×32 frame plus padding is about 36×36 px, so ~1,300 px² per frame and ~20k px² per character. A 1024² page (4 MiB RGBA8) holds all 7 ally sprites, or the 5 enemies plus 2 larger bosses.
- Estimated per-battle residency: ui + char_player + char_enemy + fx + bases + biome_01 ≈ 6 pages × ≤ 4 MiB ≈ ≤ 24 MiB. This is under the provisional low-tier 32 MiB (ENGINE.md §7), not measured.
- Reuse rules:
  - Chapter 1 uses one biome (`biome_01`) for all 10 rounds. Variety comes from palette and time-of-day tints and prop swaps, not new pages.
  - Elite/variant enemies are palette swaps of existing sprites.
  - Skill FX share one fx page.
  - Bosses get their own frames; nearest-neighbour upscales of grunts are not allowed because they read poorly.
- Content additions are cheap when they are data only (modifiers, challenge rounds, endless mode). They are expensive when they need a new character (about 15 frames), a new biome (new page) or a hero (about 20 frames incl. cast).
- Every skin or cosmetic adds residency only while equipped. 03 must keep variants on separate small pages, or swap palettes in a shader only if 02 approves the cost.

## 7. Accessibility and localization needs
- Allies and enemies must differ by palette **and** by facing direction or silhouette. Run a deuteranopia/protanopia simulation of the HP bars and team colours (03/04, B16).
- Touch targets ≥ 48 dp minimum (56 dp preferred for hero ◀ ▶ and cards). Optional left-handed mirrored layout (backlog).
- Hero movement option: hold-to-move (default) or tap-to-toggle march/hold.
- Screen shake toggle, damage numbers toggle, flash limit ≤ 3 flashes/s, pause available at any time, 2× speed.
- Text: no text baked into art. Allow ~35% longer English strings. The pixel font must cover Hangul (licence checked by 03/04). Numbers formatted per locale. ko is the primary locale, en is complete (F1).
- Audio cues (boss incoming, base under attack) always have a visual equivalent (banner, base HP bar flash).

## 8. Measurable playtest acceptance criteria (targets, not results)
Automated (deterministic sim, seeds 1–5, bot policy in 01-director-to-02-engine R1 §15):
- A1 bot wins r01–r03 on all seeds without upgrades. r04–r10 wins with the upgrade budget of first clears only.
- A2 round length within ±25% of `time_3` par.
- A3 peak alive units per side ≤ 36; no projectile/fx cap overflow except queued enemies.
- A4 zero-spend clear of chapter 1 (no ads, no purchases) with the first-clear-only upgrade budget.
- A5 data validation (parse, references, ko/en parity) passes in CI (04 request R2).
Human playtest (≥ 5 first-time testers, phone, landscape):
- H1 median time from launch to first deployed unit ≤ 30 s. ≥ 90% clear r01 with no outside help.
- H2 first-try win rates r01 ≥ 95%, r02 ≥ 85%, r03 60–80%. r03 ≥ 90% within 3 tries.
- H3 ≥ 80% can explain what workers do after r01 (exit question).
- H4 ≥ 70% buy at least one upgrade before starting r03.
- H5 Slam used ≥ 1 per minute in r02 (median). Hero damage share 15–35% in r01–r03.
- H6 loss-to-restart ≤ 3 s on the low-tier test device.
- H7 first chapter-1 clear takes 35–60 min of total play.
- H8 no tester reports being unable to tell allies from enemies. A colour-blind simulation screenshot review passes.
Results go into RELEASE_READINESS_DESIGN.md as TESTED only with linked evidence.
