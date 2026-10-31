# Content rating (IARC) questionnaire — draft answers (owner: 06-services)
Version: 1 (2026-10-31). Status: **DRAFT for whoever fills in Play Console. Not submitted.** Play's questionnaire wording is only visible inside Play Console, so the rows below are grouped by the topics that IARC ratings and descriptors cover, not copied from the form. Answers describe the build at commit-time and the decided theme A (bread knights vs mold legion). Misrepresenting content can lead to removal, so the person submitting must check every answer against the real build.

## 1. Sources (checked 2026-10-31)
| Fact (paraphrased) | Source |
|---|---|
| Every app needs an IARC rating; complete the Play Console questionnaire for each new app and re-submit when content changes; ads must not be much more mature than the app | https://support.google.com/googleplay/android-developer/answer/9898843?hl=en |
| Questionnaire in Play Console (App content → Content rating); the email is used for IARC correspondence; ratings come from several authorities (ESRB, PEGI, USK, ACB, ClassInd, GRAC for games in Korea, IARC generic); target audience is declared separately and may trigger the Families policy | https://support.google.com/googleplay/android-developer/answer/188189?hl=en |
| GRAC levels for games in Korea: 전체이용가, 12+, 15+, 19+. PEGI 3 allows comical cartoon violence; PEGI 12 covers more graphic violence against fantasy characters or non-graphic violence against human-looking characters | same page |
| Interactive elements (shown separately, do not change the age rating): in-game purchases (incl. random items), users interact, shares location, unrestricted internet | https://www.esrb.org/ratings-guide/ |
Content was rephrased for compliance with licensing restrictions.

## 2. Draft answers (current build, disabled monetization)
| Topic | Draft answer | Evidence / reason | Confirm by |
|---|---|---|---|
| Category | Game (strategy / lane defense) | GDD.md | 01 |
| Violence | Yes: fantasy/cartoon combat. Small pixel characters attack each other, units collapse in a death animation, explosion and impact effects | docs/art/ART_DIRECTION.md (attack, hit, death anims), fx_combat atlas | 03 screenshot review |
| Blood / gore | No blood, gore or dismemberment found in art docs | ART_DIRECTION.md, ART_AUDIT.md (no blood assets listed) | 03 must confirm in the re-themed art |
| Violence against human-looking characters | **Open.** Current (pre-theme) player units use "warm skin" human-like figures and the hero is a caped captain. After the bakery re-theme they may become bread characters, but the head baker hero and little bakers may stay human-looking. Non-graphic violence against human-looking characters can move PEGI from 3/7 to 12 | ART_DIRECTION.md line on faction colours; theme A role mapping in GDD §1 | 01/03 decide character design; re-answer after re-theme |
| Fear / horror | Mild: mold and insect enemies, two bosses (one with glowing eyes). No jump scares or horror audio known. **Open (09 R09-06-3):** mold/rot/insect imagery may be read as disgust or horror; answer from 03's final re-themed art, not from this draft | ART_DIRECTION.md boss notes; 05 audio; 09-research-product-to-06-services.md R09-06-3 | 03/05 |
| Sexual content / nudity | No | — | 03 |
| Language (profanity, crude humour) | No profanity. Text keys in data/text are game UI and skill text | data/text/ko.json, en.json | 01 |
| Controlled substances (alcohol, tobacco, drugs) | No. ("Yeast bomb" is a planned enemy name in GDD §1; not a drug reference) | GDD §1 | 01 |
| Gambling / simulated gambling | No. No random paid items, no wagering | services disabled; no gacha in design (ECONOMY.md §4 does not recommend M3) | 01 |
| Discrimination / hate | No | — | 01 |
| Users interact / user-generated content | No. No chat, no multiplayer, no sharing | no network code in src/ (search for HTTPRequest/WebSocket/ENet found none); APK has no permissions | 02/04 |
| Shares location | No | APK requests no permissions (aapt dump, see DATA_SAFETY_DRAFT.md §2) | 04 |
| Unrestricted internet | No | no web view, no browser, no INTERNET permission | 04 |
| Digital purchases | No (today) | services `disabled`; no billing library | changes if monetized |
| Ads (separate Play declaration "Contains ads") | No (today) | no ad SDK | changes if monetized |

Expected outcome (estimate, not a rating): with non-human fantasy characters only, an all-ages or low rating such as PEGI 3/7, ESRB Everyone, GRAC 전체이용가 is plausible. If human-looking characters take hits, PEGI 12 / IARC 12+ is possible. The actual rating comes only from the submitted questionnaire.

## 3. When answers must change
| Change | Questionnaire / declaration effect | Also update |
|---|---|---|
| Rewarded ads turned on | Play "Contains ads" = Yes; ads must not be more mature than the app (set AdMob max ad content rating to match) | Data safety (DATA_SAFETY_DRAFT.md §4), privacy policy [광고 활성화 시], Families rules if children may see ads |
| In-app purchases turned on | Digital purchases = Yes (interactive element "In-Game Purchases") | Data safety (purchase history), privacy policy [결제 활성화 시] |
| Paid random items (gacha) | "In-Game Purchases (Includes Random Items)"; may raise rating in some regions; Korean probability disclosure law applies | 01 design, legal review |
| Online play, chat, leaderboards with names, sharing screenshots | Users interact = Yes; possibly unrestricted internet | Data safety, privacy policy, Families social-feature rules |
| Location or other permissions | Shares location = Yes if shown to other users | Data safety, prominent disclosure |
| Character re-design (human-looking units that get hit, blood effects) | Violence answers change; rating may rise | 03 screenshots, re-submit questionnaire |
| Target audience includes children | Not a rating answer, but triggers the Families policy | OPEN_DECISIONS.md U4 |
