# Title name search log (owner: 06-services)
Version: 2. Searched **2026-10-31 09:15–09:25 KST** by 06-services. This is a preliminary web search, **not a trademark clearance**.

Update 2026-10-31 (Q3): the user chose the working title "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense" at 16:19 KST. The other four rows below are kept as history. The final store name waits for the KIPRIS class 9 and 41 search by a person: procedure, terms and empty record form in **docs/services/KIPRIS_MANUAL_CHECK.md**. Until that record is filled, the KIPRIS rows stay `NOT_CHECKED` (the lint enforces this).

09's later store search (docs/research/product/SUCCESS_ANALYSIS.md §28) found the similar bread-themed game "Bread Defense / 빵어전" (ETERNAXCODE). It does not share our name; the wording overlap and how the store text avoids it are in STORE_LISTING_DRAFT.md §7.

Machine-checked by `tests/services/test_services_listing.gd` group `name_search_log`: the working title in STORE_LISTING_DRAFT.md §2 has one row per source below, each with a date and a status from the fixed set.

Status values: `NO_EXACT_MATCH_FOUND` (the method used showed no app or mark with the same name; does not prove none exists), `SIMILAR_FOUND` (related names or concepts found, listed), `NOT_CHECKED` (the source could not be searched by 06).

## 1. Methods and their limits
| Source | What 06 did | Limit |
|---|---|---|
| Google Play store search | Fetched `https://play.google.com/store/search?q=Bakery%20Knights&c=apps` | The page renders results with JavaScript; the fetcher received only the page frame, **no results**. Treated as not checked. |
| Web search restricted to play.google.com | Queries: `"Bakery Knights" site:play.google.com`; `"빵집 기사단" OR "곰팡이 군단" OR "곰팡이 디펜스" site:play.google.com` | Search-engine index of Play pages, incomplete and not live |
| General web search | Queries: `"Bakery Knights" game`; `"Bread Knight" OR "Bakery Knight" mobile game Android`; `"Mold Legion" OR "Mold Defense" game`; `"빵집 기사단" 게임`; `"Bakery Knights" trademark OR app OR "App Store"` | Not exhaustive; small or unindexed apps can be missed |
| KIPRIS (Korean trademark DB, https://www.kipris.or.kr) | Opened the KIPRIS home page (loads) and tried a direct trademark query URL (timed out after 30 s). Web search for `KIPRIS 상표 "빵집 기사단" OR "빵집기사단" 출원` returned only KIPRIS how-to pages | KIPRIS search runs in the browser; **no trademark search result was obtained**. KIPRIS Plus OpenAPI needs an API key (not added, by policy) |
| US/EU/WIPO trademark databases | Not searched | — |

## 2. Results per candidate
| Candidate | Source | Date | Status | Result |
|---|---|---|---|---|
| 빵집 기사단 | Google Play | 2026-10-31 | SIMILAR_FOUND | Site search found no app named 빵집 기사단. Unrelated "기사단" titles exist on Play (e.g. 픽셀 드래곤 기사단: 방치형 RPG, com.highbrow.games.dvidle). |
| 빵집 기사단 | Web | 2026-10-31 | NO_EXACT_MATCH_FOUND | `"빵집 기사단" 게임` returned no game with this name. |
| 빵집 기사단 | KIPRIS | 2026-10-31 | NOT_CHECKED | No search result obtained (see §1). |
| 빵집 기사단: 곰팡이 디펜스 | Google Play | 2026-10-31 | NO_EXACT_MATCH_FOUND | Site search for 곰팡이 디펜스 found no app. |
| 빵집 기사단: 곰팡이 디펜스 | Web | 2026-10-31 | SIMILAR_FOUND | "Mold Defense" style concepts exist outside Play: Rottenlands (deck-building tower defense against moldy creatures, arsvatra.com); several small itch.io mold games. Different names. |
| 빵집 기사단: 곰팡이 디펜스 | KIPRIS | 2026-10-31 | NOT_CHECKED | No search result obtained. |
| 빵집 기사단 대 곰팡이 군단 | Google Play | 2026-10-31 | NO_EXACT_MATCH_FOUND | Site search for 곰팡이 군단 found no app. |
| 빵집 기사단 대 곰팡이 군단 | Web | 2026-10-31 | NO_EXACT_MATCH_FOUND | No game with this name found. |
| 빵집 기사단 대 곰팡이 군단 | KIPRIS | 2026-10-31 | NOT_CHECKED | No search result obtained. |
| Bakery Knights | Google Play | 2026-10-31 | SIMILAR_FOUND | No app named Bakery Knights found. Many bakery-named games exist (e.g. Bakery Story, com.teamlava.bakerystory; My Bakery Empire, com.cocoplay.sweet.bakery), all simulation, not knights/defense. |
| Bakery Knights | Web | 2026-10-31 | SIMILAR_FOUND | No game named Bakery Knights found. Closest concept: A Baker's Dungeon (Steam app 4310360, bakery adventuring party auto-battler). |
| Bakery Knights | KIPRIS | 2026-10-31 | NOT_CHECKED | No search result obtained; English marks were not searched in US/EU/WIPO either. |
| Bakery Knights: Mold Defense | Google Play | 2026-10-31 | NO_EXACT_MATCH_FOUND | No app found for "Bakery Knights" or "Mold Defense" via site search. |
| Bakery Knights: Mold Defense | Web | 2026-10-31 | SIMILAR_FOUND | Same mold-defense concepts as above (Rottenlands; itch.io "Mold", "The Mold", "Moldwasher"). |
| Bakery Knights: Mold Defense | KIPRIS | 2026-10-31 | NOT_CHECKED | No search result obtained. |
| Bakery Knights vs Mold Legion | Google Play | 2026-10-31 | NO_EXACT_MATCH_FOUND | No app found. |
| Bakery Knights vs Mold Legion | Web | 2026-10-31 | NO_EXACT_MATCH_FOUND | `"Mold Legion"` returned no game with this name. |
| Bakery Knights vs Mold Legion | KIPRIS | 2026-10-31 | NOT_CHECKED | No search result obtained. |

## 3. Concept-level note (not a name conflict)
CookieRun: Kingdom (Devsisters, com.devsisters.ck) is a large Korean game whose characters are baked goods fighting a "dark legion". Our names do not use "Cookie" or "CookieRun", but players may compare the themes. 09-research-product may want to check the identity risk; 06 makes no legal judgement.

## 4. What the user (or a professional) still needs to do
1. KIPRIS 상표 검색 by hand for the working title, classes 9 and 41: follow docs/services/KIPRIS_MANUAL_CHECK.md (15 terms incl. similar-sound forms, status values, record form).
2. Google Play search in the Play app (live results) for the working title in ko and en.
3. If the English title is used abroad: USPTO / EUIPO / WIPO Global Brand Database.
4. Record the KIPRIS results in KIPRIS_MANUAL_CHECK.md §5–§6 with date and searcher; 06 then updates the KIPRIS rows here.
