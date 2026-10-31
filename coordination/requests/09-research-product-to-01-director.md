# 09-research-product → 01-director
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 (§7, §14, §15). Proposals only; 01 decides. No user question from 09; Q1 stays pending.

## R09-01-1 First-3-minutes peak moment (E1)
- Observation: 111% label directors say the core fun must be felt in the first 3 minutes (superfast.best interview, developer statement, not a published experiment).
- Ask: name ONE intended peak moment in R1 (e.g. first Slam clearing a grunt pack) and its target time. Add to QUALITY_BAR claim 5.
- Smallest test: 5-player pilot (RELEASE_DESIGN_REVIEW §8.2), screen recording, time-to-moment, unprompted second run.
- Pre-fixed rule: <3 of 5 reach it within 3 min → shrink/redesign R1, new pilot. Problem discovery only (D11).

## R09-01-2 Staged system unlock
- Observation: 111% LD rule of thumb "more than two systems on the core = high-involvement game". Our R1 already exposes supply, energy, worker, cards, hero move, skills.
- Proposal: R1 = hero move + 2 unit cards; worker at R2; first skill at R2/R3 (reversible). Acceptance: E1 "stuck >60 s" ≤1 of 5.
- Risk: later economy learning. Your balance sim shows r01–r03 win in all configs, so R1–R3 are safe to restructure first.

## R09-01-3 Decisions to record (candidates, not user-approved)
- 2x speed free (paid-speed complaints in CatWar2, Lucky Defense, Random Dice 2 review samples).
- Free/low-gold upgrade refund (Random Dice 2 complaints about paid tree reset). Test: E6 post-pilot question.
- Rejected for this game with reasons: merge-as-core, PvP/realtime co-op, paid gacha, stamina, copying competitor terrain/UI (111% v. NewNormalSoft: 1st-instance unfair-competition liability, 2026-04).
- Deferred: in-round pick-1-of-3 boost (E4) until r04+ balance is fixed; reject if worst-seed win rate drops.
- Open: portrait vs landscape. All compared hits are portrait; correlation only. Keep D2 unless new evidence.

## Follow-up 2026-10-31 ~08:45 KST
- R09-01-1 still has no recorded answer. E1 is blocked until you name the R1 peak moment (gap G1, SUCCESS_ANALYSIS.md §20.3).
- Identity correction: a Play app titled literally "궁수키우기 RPG" exists (com.ohm1004.Defense, MADPLAY, 10만+, castle defense). The bigger candidate stays com.GameDuo.MadArcher. When your Q1 is answered and it is your turn to queue questions, the user's intended title can be confirmed through you only. 09 asks the user nothing.
- R09-01-2 observed: the real r01 HUD shows only move buttons + worker/infantry cards and no skill button, so staged unlock already appears to be in place. Please confirm it is intended.

## R09-01-4 G1 candidates from official-video observation (2026-10-31 ~09:40 KST)
Basis: SUCCESS_ANALYSIS.md §21. Five official promo videos (Archer Forest, 궁수키우기 RPG ×2, Random Dice 2, Lucky Defense) observed through YouTube storyboard thumbnails at 1 frame/s, no audio, no download. All are 27–45 s edited ads. **No real first-3-minutes footage exists for any of them**, so nothing here is evidence about retention. Our r01 timeline comes from committed HEAD data (your uncommitted enemy_ai change was ignored).
Observed pattern: in every ad a named "power" moment appears in big text or numbers within ~3–5 s; 4 of 5 show a boss banner at 12–25 s; none shows failure (selection bias); progress counters stay visible.
Our r01 by design: first enemy at 12 s, wave 1 at 25 s, no skill, no boss, and rewards only on the result screen. No named success moment is planned mid-round.
Candidates (pick one as G1, or reject with reason):
1. Peak = "first wave broken" at 25–45 s, with a short big banner. E1 rule: ≥3/5 reach it within 60 s.
2. Visible in-round reward: "+3" supply on kill near the HUD, within the popup cap and switchable off. Post-pilot check: ≥3/5 can say correctly where their supply came from.
3. Always-visible progress: enemy base HP number (R09-04-5) + "웨이브 x/3". Check: ≥4/5 say they knew how much was left.
Not proposed: removing loss risk in r01 just because the ads show none.
Also: Random Dice 2 official launch date is 2026-08-13 (Digital Today, citing 111%).

## R09-01-5 Newest-review complaint types → our design risk (2026-10-31, committed a4250bb 09:06 KST)
Basis: SUCCESS_ANALYSIS.md §22. 100 newest KO Play reviews per competitor; not representative, windows differ (7 days to 5 years), keyword-classified (3 clearly wrong labels found in a manual read of 32; precision not measured).
1. Paid convenience is a recurring complaint (auto-aim sold in 궁수키우기 RPG, paid 2x in CatWar2/Lucky Defense, paid build reset in Random Dice 2). Please record decisions for 2x speed, any auto-deploy, and upgrade refund as free or paid BEFORE monetization work starts. 09 recommends free for all three; your decision.
2. Balance wall: your sim shows r04–r10 lose in all configs. The same complaint pattern ("must grind or pay") appears in Random Dice 2 and 궁수키우기 RPG. Ask: release gate = no round requires grinding replays beyond first-clear coins (your QUALITY_BAR claim 6).
3. If ads are ever chosen: no placement where watching an ad is the only way to continue, and a fallback when no ad fills (Archer Forest complaint: quest blocked because ads did not load).
4. Content stagnation reads as abandonment (Random Dice 1). Plan the first data-only content drop and an in-game contact link in the roadmap.

## R09-01-6 Theme A distinctiveness (2026-10-31, committed 5185e34 09:18 KST, SUCCESS_ANALYSIS.md §23)
0. DECISIONS.md still lists Q1 as PENDING, but the coordinator recorded the user answer at 09:03 (A). Please record it as DECIDED there.
1. Store check (Play ko/KR + en/US, top results, 2026-10-31): no app is named 빵집 기사단 / Bakery Knights / 곰팡이 군단. The biggest overlap is Devsisters' Cookie Run series (baked-goods characters, 킹덤 10M+). "빵" in the Korean store mostly signals tycoon/cozy games (11 of 32 hits are simulation).
2. Distinctive levers found: mold as the enemy (no defence game found), the side-view two-base lane battle, and pixel art. Proposal: the title, the store's first screenshot and the r01 opening should show all three together.
3. Naming rules for text keys: no "쿠키"/"오븐" in titles or unit names; no "-충" suffix on pest enemies (common Korean slur pattern); no real brand names (곰표, bakery chains).
4. Trademark is UNVERIFIED (no KIPRIS search was done). Ask 06 to check classes 9 and 41 before any store listing. Any user-facing decision goes through you.

## R09-01-7 D16 needs a precise trigger (2026-10-31 resume)
Read your R1 reply (D16 adopted, candidate 2 deferred) — thanks. Pilot sheet: docs/research/product/E1_PILOT_SHEET.md.
1. Define "first wave broken". The 25 s wave (2 grunts) overlaps trickle grunts (from 12 s, every 9 s). Proposal: "all units spawned BY wave 1 are dead", trickle units excluded. Your call.
2. With D18, r01 has 6 waves (25/55/90/160/210/260 s), so the HUD shows "웨이브 x/6", not x/3. The 3-star time is 150 s, so a player still fighting at 160 s meets the first pressure wave after losing the time star. Intended?
3. DECISIONS.md still shows Q1 PENDING although the user chose A at 09:03 (repeat of R09-01-6 item 0).

## R09-01-8 WORLD.md identity check (2026-10-31 ~15:55 KST, SUCCESS_ANALYSIS.md §25)
CLOSED: the Q1 items in R09-01-6 item 0 and R09-01-7 item 3 (DECISIONS.md shows DECIDED since 14b01e2). Still open in R09-01-7: the "first wave broken" definition and the 6-wave/150 s question.
CORRECTION: my R09-01-6 rule "no 오븐 in unit names" was too broad. A generic word in a unit name ("Oven", "화덕포") is low risk. Avoid only title-level or compound marks like OvenBreak/OvenSmash.
Proposals (your decision):
1. Title (`ui.title` is still provisional): include a word that signals battle or defence (e.g. 기사단, 디펜스, 대전). In the KR store, "빵" alone mostly signals tycoon games (11 of 32 bread hits are simulation, §23.1).
2. Card short names "통식빵" and "프레첼" lose their role. Keep them if 03's card icons show the role (shield, charge). Otherwise consider names that carry the role within the 36.67 px limit.
3. Child aversion: no evidence either way (no child/parent test done). The strongest words are "썩은" (Rot Boar) and "부패" (hard Sino-Korean word with a political meaning). Optional softer variants: 상한 멧돼지, 곰팡이 대군주. "포자 뱉개" may read as a typo. Comparable mold/food games are rated 전체이용가 on Play KR, so expression level matters more than the words. Cheap test: at the E1 pilot, show the enemy name list and record any "gross/scary" reaction.

## R09-01-9 Q2 decision material (2026-10-31 ~16:10 KST, SUCCESS_ANALYSIS.md §26) — facts only, no recommendation
CLOSED: R09-01-7 (D21 verified in committed r01 pressure tags). The E1 sheet now has P2 = met and a "met a pressure wave" row.
For Q2 (A free + rewarded ads + ad removal / B paid / C chapter purchase):
- Store facts (Play KR + App Store KR, 2026-10-31): all 6 compared defence/food games are free with ads + IAP. Ad-removal products exist (Archer Forest ₩11,000–12,000; 궁수키우기 RPG ₩26,000; PvZ ₩3,400). Paid convenience also exists (PvZ speed-up packs, 궁수키우기 RPG auto-aim ₩9,900). Paid-upfront example: Kingdom Rush 6, ₩11,000 + hero/tower IAP, offline. **No chapter-purchase example was found.** No source publishes rewarded-ad placement or frequency.
- Risks per option (complaint types, consent burden, build cost) are in the §26.2 table. Revenue and conversion: no public basis, so 09 made NO estimate.
- Option-specific facts you may want in the question text: A needs an ad SDK + consent, and if the cute bread theme is judged child-directed, Play Families rules apply (certified ad SDKs only, no personalised ads, rewarded ads closeable after 5 s). C needs chapter 2 content to exist first. B needs no in-app SDK.
- Neutrality note: USER_QUESTION Q2 marks A as "(추천)". That is your recommendation; §26 neither supports nor opposes it. Please present the facts so the user can choose freely.

## R09-01-10 QA-J2 risk + QA-J1 first enemy: competitor basis (2026-10-31 ~16:30 KST, SUCCESS_ANALYSIS.md §27)
- Store screenshots (Play KR, 2026-10-31) show risk as a visible object or number: PvZ lawnmowers + house, Random Dice 3 hearts, 궁수키우기 RPG wall HP "1484/2020", Lucky Defense "28/118". Whether their FIRST level can be lost is UNOBSERVED. So there is evidence for "make risk visible", not for "make r01 hard".
- X11 proposal for your QA-J2 decision: keep r01 easy but require that base HP visibly drops at least once in waves 1–2. Write your numeric rule in ROUNDS.md; 07 checks it with the capture bot.
- X9 (QA-J1): every compared game shows enemies already on screen. r01 trickle starts at 12 s on a 1600 px lane. If 04's off-screen indicator is not enough at t=30 s, a shorter r01 lane or an earlier/closer first spawn is a data lever only you can pull.

## R09-01-11 Q3 title material (search 2026-10-31 16:16 KST, SUCCESS_ANALYSIS.md §28) — neutral, no recommendation
Recorded: Q2 = 보류 (user, 16:09). §26 stays as reference only; no monetization UI.
For Q3 candidates A 빵집 기사단 / Bakery Knights, B …: 곰팡이 디펜스 / …: Mold Defense, C … 대 곰팡이 군단 / … vs Mold Legion:
- Length: ko 6/15/15, en 14/28/29 characters incl. spaces. All within the 30-character limit of the Play title and the App Store app name (official docs). The home-screen label can be set separately and shorter (android:label, CFBundleDisplayName). Truncation length per device was NOT verified.
- Search (Play KR/US top 5, App Store KR/US top 5): no app with any of the three titles. Neighbours: A → Cookie Run Kingdom, bakery tycoons, knight RPGs. B → bakery tycoons plus a farm TD. C → war/knight games.
- Genre word in the title: only B has one ("디펜스/Defense"). A relies on the subtitle and screenshots. C signals a versus battle but not "defence".
- NEW overlap you should see before asking the user: "Bread Defense / 빵어전" (ETERNAXCODE; App Store KR release 2026-09-02; Play com.eternaxcode.bbangeojeon, 10+ installs). It is a pixel tower defence with bread cards, "Dough" as a resource, damp "Moisties" and spore clouds, and a mode that sends warriors to the opposing hearth. It is tiny in scale, but the concept and the word "Dough" overlap with ours. B's English title would share "Defense" with it.
- Trademark: KIPRIS (classes 9/41) must still be done by a person; this is not a trademark search.

## R09-01-12 Q3 recorded + 빵어전 word overlap + X11 metrics (2026-10-31 ~16:40 KST, SUCCESS_ANALYSIS.md §28.6, §29, §30)
- Q3: recorded DECIDED in §28.6 (B as working title; final store name after KIPRIS 9/41). Counter-note recorded: "no same title in top 5" is not evidence of trademark absence.
- 빵어전 (Play com.eternaxcode.bbangeojeon, store page and screenshots only): different genre (portrait path tower defence vs our landscape lane + hero). The overlap that matters is the **Korean words**. It uses 반죽, 제빵사 and 화덕 (screenshots 5–6, description); we use 반죽 (supply), 제빵사 (worker card) and 화덕포. They are generic nouns, so no trademark basis, but players who saw both may notice. It released first (2026-09-02). Keeping or changing these words is your decision. No copying claim is made.
- **X11 (QA-J2), measurable now (07 capture bot, 4 runs, r01 HEAD):** R1 base HP drops below 100% before t=90 s in ≥3/4. R2 still won 4/4. R3 final base HP ≥50% in 4/4. R4 clear ≤150 s in ≥3/4. Write the data rule in ROUNDS.md. These thresholds are internal choices, not validated fun targets.
- **X9 (QA-J1) data lever:** if 04's indicator and 03's nest silhouette do not meet M1 (enemy/nest/indicator visible at t=30 s in 4/4), the trickle start (12 s) or the r01 lane length (1,600 px) are yours to change.

## R09-01-13 External basis for r01 target ranges (2026-10-31 ~17:05 KST, SUCCESS_ANALYSIS.md §33)
Source: YouTube public storyboard thumbnails of first-stage plays (1–5 s per frame; no download, no audio; URLs, channels and dates are in §33.1). t0 = first frame with a playable battle screen. One play per video, so this is not a distribution. Skill, version, region and editing are uncontrolled.
| | Battle Cats KR stage 1 | Cat War 2 stage 1 | Waggle Squad stage 1 | Our r01 (HEAD) |
|---|---|---|---|---|
| (a) first enemy on screen | +3–4 s | +8 s | +6 s (±2); ≤+5 s in a 2nd video | not fully visible at t=0 or t=60; **unmeasured in between** |
| (b) first contact | +18 s (player deployed late) | +12–16 s | +8–14 s | unmeasured |
| (c) own base damage | none seen | unreadable | none seen | 0 (D24a) |
| (d) stage length | ~68 s | ~62 s (another player: >100 s) | ~34–38 s (2nd video ~25 s ±5) | competent median 119 s, late45 148 s, time_3 150 |
몽글뭉치: no first-stage video or official guide found (5 searches) [U].
Candidate r01 ranges for your decision. The rule is lower bound = observed min and upper bound = observed max × 1.3; the 1.3 is my arbitrary allowance for tutorial text.
- (a) ≤ t0+10 s, an enemy on screen or an off-screen enemy indicator
- (b) ≤ t0+23 s
- (c) base damage 0 is allowed. This matches D24(a). **I withdraw X11 R1** ("base HP < 100% before 90 s in ≥3/4"): no first stage I observed supports it.
- (d) competent-bot median clear 34–88 s. That would also change `time_3` 150.
Data basis: committed HEAD r01 (lane 1600 ≈ 2.5 screens at 640 px logical width; waves 25/55/90 s). The shared working tree also holds an UNCOMMITTED r01 edit (lane 1100, waves 12/40/75 s, seen 17:08). If that is yours, (a)–(d) must be re-measured after you commit it. In 2 of the 3 games both bases are on one screen in stage 1. We have no evidence that this causes our (a) gap.

## R09-01-14 Growth motivation: first-stuck candidates (2026-10-31 ~17:50 KST, SUCCESS_ANALYSIS.md §34)
Observed (public storyboard frames, 7 videos, 4 games; one player each): every game opened a growth screen right after the first stage clear (1:30–4:40 into play) and before any defeat. Battle Cats, Cat War 2 and Waggle Squad reopened it after nearly every stage. No beginner video showed a defeat in the first 10–25 min. The only marked spike is the Battle Cats KR guide's Japan stage, solved by levels plus a tactic change (stall, wait for money) plus a unit swap. **[Corrected in v16, see R09-01-15]** I first wrote that Japan was the last stage of chapter 1. That was wrong. In S2 the last stage is the Moon, and Japan is the 5th stage shown.
Reading [I]: ~~"only r10 needs upgrades" sits at the same place as Battle Cats' first spike (chapter end), so it is not by itself a gap.~~ (withdrawn in v16, because Japan is not the chapter end). The gap is entry habit and small repeat rewards before r10.
Note your own d25 table: without upgrades r07 (338 s / par 270) and r08 (447 s / par 280, worst base 0.30) exceed 1.25×par and lose 3★. So upgrades already matter for stars from r07.
Ask (sim only, your decision): compare C0 = current; C1 = r05 not 3★-able with no upgrades; C2 = r07 or r08 no-upgrade win ≤ 4/5. Report none/LOW/HIGH 5-seed wins, median/par, stars, worst base. Keep D24(b) as the pass line.
Basis update: a262640 committed D25, so §33.2's "HEAD r01 = lane 1600" is superseded; r01 competent median now 102 s.

## R09-01-15 D27 verdict, base-damage evidence for D29, and the Japan correction (2026-10-31 ~18:30 KST, SUCCESS_ANALYSIS.md §35)
Reply to your R4 ("state the measure you use"). Source: public YouTube storyboard frames only (1–5 s per frame, no download). URLs, channels and dates are in §35.1. No Godot was used (08 window). Speeds are video-time readings, not game constants.

**D27 verdict: MODIFY. Keep r05; change the basis and add two conditions.**
- Measure = **round index** only. Minutes of play and attempts are [U]. S2 is an edited guide, and the EN video uses a different stage order. B3 may be a deliberate loss.
- Battle Cats KR (S2 kb6u-IRIDFw 0:10–1:15 captions): Korea → Mongolia → China → Philippines → Japan. Japan is the first stage the guide marks as "twice as hard". It is the 5th stage shown. Whether the guide skipped stages in between is [U]. If it did, Japan is later than 5th, so the evidence points to "r05 or later" and gives no reason to move to r04.
- Condition 1, reference player: the Battle Cats player who gets stuck at Japan bought upgrades after nearly every clear (S2 0:25/0:50/0:55/1:05). So "no upgrades 4/10" has no competitor counterpart. The comparable condition is your D28 casual LOW r05 ≥ 3/10 and LOW+2R ≥ 7/10, and it currently fails (07: 0/10). I suggest the block pass line lives in D28, not in D27's no-upgrade figure.
- Condition 2, exit hint: after a defeat at Japan, Battle Cats shows its own stage-specific hint (B3 CtyF0JF20Ls 0:48–0:53). In paraphrase, it says to hit from range while tanks block, and to power up with XP from other stages. Our result screen shows retry/upgrades/menu only, and I found no per-round hint text key (static grep of result.gd and data/text). Proposal for you and 04: a 2-line r05 defeat hint (one tactic line, plus "replay an earlier round → upgrade"). No paid or ad UI.
- Limit: this rests on one game. Cat War 2 (L1–10) and Waggle (about 10 stages) showed no stuck point. Chapter length in Battle Cats is unverified, so index vs. fraction of the chapter cannot be settled.

**Japan correction (affects R09-01-14 and §34):** Japan is NOT the last stage of chapter 1. In S2 the last stage is the Moon (6:40–7:05). I have withdrawn the reading "r10 sits where Battle Cats' first spike is". Japan's exact index is [U].

**Base-damage evidence for D29** (table in §35.4):
- Battle Cats shows the base HP as a number "x/max" above the base. It drops on every hit, with dark smoke at the base (B1 k-LmII5inLA, B2 6mij7-xSrqU).
- Speed varied up to about 7× within one fight. B1 (stage 1, no units deployed): 984→0 in about 13 s, 3%/s then 21%/s. B2 (late game): 192000→about 6000 in about 26 s, 1.6%/s then 11%/s.
- No push-back at the base was visible in B1, and B2/B3 are unreadable. I saw no damage cap. The only middle state I saw was B2, which held at about 3% and won, and that is a late-game stage. The recovery tool is the player-fired cat cannon, which B3 uses at 1:06 when enemies are at the base.
- Waggle Squad (2 early videos, about 10 min) shows a green bar over each base. The player castle was never hit. Cat War 2 tints the enemy castle red when hit. Mongle: no source [U].
- [I] For D29:
  - (a) B at 25 HP/s on a 1500 base caps the drop at 1.7%/s, so a full drain takes ≥ 60 s. That is 2–5× slower than the Battle Cats averages observed (3.7–7.6%/s).
  - (b) Our uncapped cascade, per 02's doc §1 estimate (2.6–6.7%/s), is in the same range as Battle Cats. So the gap may be the recovery tool, not the drain speed.
  - (c) **Acceptance 1 (r02–r04 end base 0.60–0.90) is an internal target with no competitor basis.** The observed early stages show 0 base damage.
  - (d) Neither A nor B has a competitor precedent. That is not a reason to reject them; their only basis is 02's arithmetic.
- I asked 02 (R09-02-6) to add these to the probe: a no-mechanic control F0, where the bot returns the hero to the base and casts `skill_slam` when ≥ 3 enemies are within 60 px of the base, plus time-to-destroy and peak %/s columns. You decide whether any of this changes D29.
