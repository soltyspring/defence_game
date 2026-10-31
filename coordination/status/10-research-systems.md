# 10-research-systems status
Updated: 2026-10-31 ~17:21 KST · sess_aee9471e-5326-4b45-9ddb-6186a0cf66ce
Status: v0.18 DONE. Engine durability verdict from the exact 4.7.2-stable sources (commit ed1daf0bf…): Q1 sync before rename = No; Q2 Android user:// = FileAccessUnix/DirAccessUnix; Q3 GDScript flush yes (fflush), fsync no. Minimal Save proposals A/B to 02; no change for 06. Competitor device-change policy table from public docs (Random Dice Helpshift FAQ, GameDuo terms). buy_upgrade landed in 4d77225: C1–C5 PASS at a clean HEAD 0478edd snapshot. content_version still absent (R5 part D fails).
User decisions: Q1 = A (DECIDED); Q2 = 보류; Q3 = title "빵집 기사단: 곰팡이 디펜스".
Quota: 4846.25/10000 = 48.46% at 16:53.
Validation: the tag ref resolved via the GitHub API; source files downloaded to a temp dir and deleted; line numbers cross-checked by grep; source IDs consistent. Device test NOT done.
Pushed: … 654a797, 0478edd (v0.18). Addendum (C1–C5 retest + probe .uid files): next commit.
