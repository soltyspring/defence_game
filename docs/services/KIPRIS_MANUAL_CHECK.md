# KIPRIS trademark check — manual procedure and record (owner: 06-services)
Version: 1 (2026-10-31). Status: **NOT DONE. No KIPRIS result has been obtained by anyone.** Every result cell below is empty on purpose. Do not fill it from memory, from a web search, or from another tool's guess.

**This is a search checklist, not a legal opinion or a trademark clearance.** If any live mark (출원, 공고, 등록) is the same as or close to our title in class 9 or 41, ask a patent attorney (변리사) before choosing the store name.

Why: the user decided the working title on 2026-10-31 16:19 KST ("빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense") and said the final store name is fixed only after a person checks KIPRIS classes 9 and 41 (coordinator-to-06-services.md, "Q3 answered"). 06 could not run the search: the KIPRIS home page loads, but the search runs in the browser, a direct query URL timed out, and the KIPRIS Plus OpenAPI needs an API key that was not added by policy (NAME_SEARCH_LOG.md §1).

Machine-checked by `tests/services/test_services_listing.gd` group `kipris_manual_check`: every term in §3 has a §5 row for class 9 and class 41; a row other than `NOT_DONE` must have a date and a searcher; `HITS_RECORDED` needs at least one §6 record; and NAME_SEARCH_LOG.md must keep the KIPRIS rows for the working title at `NOT_CHECKED` while any §5 row is `NOT_DONE`.

## 1. Who and when
- Who: the user, or a person the user names. **[USER]**
- When: before the Play Console store listing is saved with the final name, and before 03 finalises the logo text.
- Time needed: about 30–60 minutes for 16 terms × 2 classes.

## 2. Steps (KIPRIS web, https://www.kipris.or.kr)
06 has not seen the search screen itself, so menu names below may differ from the real screen. If they differ, use the real one and write its name in the §6 memo column.
1. Open https://www.kipris.or.kr in a desktop browser. Choose the trademark search (상표 검색). If the site asks for a login, note that in the memo column.
2. Open the detailed search (상세 검색 or similar). Put the term from §3 in the trademark name field (상표명 / 명칭).
3. Limit to one Nice class at a time: **class 9** (downloadable game software, 게임 소프트웨어), then **class 41** (online game services, 온라인 게임 제공업). If the screen offers a similar-group code (유사군 코드) field, look up the codes for those two goods/services in KIPRIS's goods search, write the codes in the memo column, and search with them too.
4. Include every status in the filter (do not hide 소멸, 거절, 포기). Dead marks are still worth a line in §6.
5. For each term × class: if there are no hits, set §5 to `NO_HIT`. If there are hits, open each one that looks the same or close and copy its details into §6, then set §5 to `HITS_RECORDED` with the record numbers.
6. Save a screenshot or PDF of each result list (file name: `kipris_<date>_<T#>_<class>.png`). Store it outside the repo or where the user chooses; write the file name in §6. Do not commit screenshots that show personal data of applicants.
7. Tell 01 when done. 01 updates DECISIONS.md and asks the user to confirm the final name; 06 updates NAME_SEARCH_LOG.md and STORE_LISTING_DRAFT.md.

## 3. Search terms
Spaces and punctuation change KIPRIS hits, so both forms are listed. "Similar" terms cover sound and meaning (for example "베이커리나이츠" is how "Bakery Knights" sounds in Korean).

| T# | Term | Language | Kind |
|---|---|---|---|
| T1 | 빵집 기사단 곰팡이 디펜스 | ko | full title |
| T2 | 빵집 기사단 | ko | main name |
| T3 | 빵집기사단 | ko | main name, no space |
| T4 | 곰팡이 디펜스 | ko | sub-name |
| T5 | 곰팡이디펜스 | ko | sub-name, no space |
| T6 | 빵 기사단 | ko | similar meaning |
| T7 | 베이커리 나이츠 | ko | sound of the English name |
| T8 | 베이커리나이츠 | ko | sound, no space |
| T9 | 몰드 디펜스 | ko | sound of "Mold Defense" |
| T10 | Bakery Knights Mold Defense | en | full title |
| T11 | Bakery Knights | en | main name |
| T12 | BakeryKnights | en | main name, no space |
| T13 | Bakery Knight | en | singular |
| T14 | Mold Defense | en | sub-name |
| T15 | Mould Defense | en | British spelling |
| T16 | MoldDefense | en | sub-name, no space |

## 4. Status values to record (KIPRIS 행정처분 상태)
Copy the status exactly as KIPRIS shows it. How to read it for our purpose (not legal advice):

| Status | Meaning | What it means for us |
|---|---|---|
| 출원 | applied, under examination | live; a possible conflict, note the filing date |
| 공고 | published for opposition | live; close to registration |
| 등록 | registered | live; strongest conflict if same/similar in class 9 or 41 |
| 거절 | refused | usually not blocking; note why if shown |
| 소멸 | expired or lapsed | usually not blocking; note the date |
| 포기 | abandoned | usually not blocking |
| 취하 | withdrawn | usually not blocking |
| 무효 | invalidated | usually not blocking |
If KIPRIS shows another value, copy it and mark the row "모름" in the similarity column.

Similarity column values: `동일` (same text), `유사` (close in look, sound or meaning), `비유사` (clearly different), `모름` (cannot tell; ask a professional).

## 5. Summary per term and class
Result values: `NOT_DONE` (not searched yet), `NO_HIT` (searched, no mark found), `HITS_RECORDED` (marks found, listed in §6).

| T# | Term | Class | Result | Date (YYYY-MM-DD) | Searcher | §6 records |
|---|---|---|---|---|---|---|
| T1 | 빵집 기사단 곰팡이 디펜스 | 9 | NOT_DONE | | | |
| T1 | 빵집 기사단 곰팡이 디펜스 | 41 | NOT_DONE | | | |
| T2 | 빵집 기사단 | 9 | NOT_DONE | | | |
| T2 | 빵집 기사단 | 41 | NOT_DONE | | | |
| T3 | 빵집기사단 | 9 | NOT_DONE | | | |
| T3 | 빵집기사단 | 41 | NOT_DONE | | | |
| T4 | 곰팡이 디펜스 | 9 | NOT_DONE | | | |
| T4 | 곰팡이 디펜스 | 41 | NOT_DONE | | | |
| T5 | 곰팡이디펜스 | 9 | NOT_DONE | | | |
| T5 | 곰팡이디펜스 | 41 | NOT_DONE | | | |
| T6 | 빵 기사단 | 9 | NOT_DONE | | | |
| T6 | 빵 기사단 | 41 | NOT_DONE | | | |
| T7 | 베이커리 나이츠 | 9 | NOT_DONE | | | |
| T7 | 베이커리 나이츠 | 41 | NOT_DONE | | | |
| T8 | 베이커리나이츠 | 9 | NOT_DONE | | | |
| T8 | 베이커리나이츠 | 41 | NOT_DONE | | | |
| T9 | 몰드 디펜스 | 9 | NOT_DONE | | | |
| T9 | 몰드 디펜스 | 41 | NOT_DONE | | | |
| T10 | Bakery Knights Mold Defense | 9 | NOT_DONE | | | |
| T10 | Bakery Knights Mold Defense | 41 | NOT_DONE | | | |
| T11 | Bakery Knights | 9 | NOT_DONE | | | |
| T11 | Bakery Knights | 41 | NOT_DONE | | | |
| T12 | BakeryKnights | 9 | NOT_DONE | | | |
| T12 | BakeryKnights | 41 | NOT_DONE | | | |
| T13 | Bakery Knight | 9 | NOT_DONE | | | |
| T13 | Bakery Knight | 41 | NOT_DONE | | | |
| T14 | Mold Defense | 9 | NOT_DONE | | | |
| T14 | Mold Defense | 41 | NOT_DONE | | | |
| T15 | Mould Defense | 9 | NOT_DONE | | | |
| T15 | Mould Defense | 41 | NOT_DONE | | | |
| T16 | MoldDefense | 9 | NOT_DONE | | | |
| T16 | MoldDefense | 41 | NOT_DONE | | | |

## 6. Record form (one row per mark found)
Copy one empty row per hit. Leave it out when there are no hits (the §5 row says `NO_HIT`).

| R# | Date | Searcher | T# | Class | Application no. (출원번호) | Registration no. (등록번호) | Mark as shown | Applicant / owner | Status (§4) | Goods/services (short) | Similarity (§4) | Memo / screenshot file |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| R1 | | | | | | | | | | | | |

## 7. After the search
- No live `동일`/`유사` mark in class 9 or 41: 01 asks the user to confirm the working title as the final store name (one question at a time).
- Any live `동일`/`유사` mark, or any `모름`: stop and ask a patent attorney; 01 brings the result and the option list to the user.
- Other markets: if the English title is used outside Korea, the same check is needed in USPTO, EUIPO or WIPO Global Brand Database. Not part of this checklist.
