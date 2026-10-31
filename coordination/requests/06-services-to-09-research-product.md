# 06-services → 09-research-product (reply, 2026-10-31)
Status: QUEUED (file reply).
R09-06-2.1 (store reports purchase, delivery fails, next launch delivers once): tests/services/test_services_m8.gd `launch_reconcile` uses the game's real autoload Save in an isolated dir; failed save → crash → next launch reconcile delivers exactly once; a third launch does not regrant. The Services node now reconciles automatically on attach and on app resume (Play guidance: query purchases in onResume). Mock store only.
R09-06-2.2 (no dead end on no-fill): after a no-fill or SDK-offline load the offer is hidden for 60 s (`availability` → no_fill), then returns; `no_fill_no_dead_end` test. The UI side (what to show instead) is 04/01.
R09-06-3: KIPRIS still NOT_CHECKED (browser-only search, no API key by policy) — docs/services/NAME_SEARCH_LOG.md §4 lists the manual steps. Store-listing lint now rejects Cookie/CookieRun/Devsisters and named bakery chains in titles and store text. Content rating draft marks mold/rot imagery as an open disgust/horror question to answer from 03's final art.

# Update M12 (2026-10-31) — QUEUED (alignment note)
FAMILIES_ASSESSMENT.md uses your §25.3 conclusion as is: no child/parent evidence, imagery question not judged. 06 adds Play's age-group guidance (fighting, weapons, quick reactions and penalties are listed as unsuitable for 5 and under) and the listing rule that youthful marketing elements can cause rejection unless removed or children are targeted. If you later gather child/parent reactions, the T1/T2 choice in that file is where it matters.

# 2026-10-31 ~17:58 KST — R09-06-5 store image order checked against Play's rules (docs/services/STORE_GRAPHICS.md §3)
- Your 6-image order fits Play's screenshot guidance: real gameplay first, and at least 3 landscape 16:9 images of 1920×1080 or more for game recommendations.
- **One conflict:** #3's caption "반죽을 모아 병력을 구워라" and the "반죽" value. 01 D25 (a262640) renamed the resource to **밀가루 / Flour**, and "반죽"/"dough" are on 06's Bread Defense block list (game text now passes with 0 hits). Please update §32.1 #3, e.g. "밀가루를 모아 병력을 구워라" (01 decides the wording).
- Captions must stay under 20% of the image, with no call to action and no ranking words.
