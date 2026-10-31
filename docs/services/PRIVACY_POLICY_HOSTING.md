# Publishing the privacy policy at a public URL (owner: 06-services)
Version: 1 (2026-10-31). Status: **PREPARATION ONLY. Nothing is published and no hosting is chosen.** The hosting choice and the values for the page are user decisions; 01 asks them later, one at a time, as part of OPEN_DECISIONS.md U3 (privacy contact + public URL). Q2 is deferred by the user (16:09 KST, "수익모델은 보류"), so the page to publish is the **disabled-mode** version: no ads, no purchases, no analytics.

Prepared artifact: `docs/services/privacy_site/index.html` — ko + en, built from PRIVACY_POLICY_DRAFT.md with the monetization blocks removed, legal-review notes kept as HTML comments (not shown to readers), placeholders `{{…}}` still to fill. The lint group `privacy_site` (tests/services/test_services_listing.gd) checks it matches the draft and lists unfilled placeholders as publish blockers.

## 1. What the URL must satisfy (Google Play User Data policy, checked 2026-10-31)
Public, active, not geofenced, not a PDF, not editable by others; linked in Play Console and reachable from inside the app; clearly titled as a privacy policy; names the developer or app (https://support.google.com/googleplay/android-developer/answer/10144311?hl=en). Content was rephrased for compliance with licensing restrictions.

## 2. Free static hosting option: GitHub Pages (facts checked 2026-10-31)
| Fact | Source |
|---|---|
| Free accounts can use Pages only for **public** repositories | https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages |
| Project site URL: `https://<owner>.github.io/<repository>`; one user site per account (repo named `<owner>.github.io`) | same |
| Publishing source: a branch + folder, or a GitHub Actions workflow; entry file `index.html`, `index.md` or `README.md`; changes can take up to 10 minutes; branch sources run Jekyll unless a `.nojekyll` file exists | https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site |
| Pages logs each visitor's IP address for security, whether signed in or not | https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages |
| Not for running a commercial business, e-commerce or SaaS; soft limits 1 GB site, 100 GB/month bandwidth | https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits |
Repository facts (GitHub API, 2026-10-31): `soltyspring/defence_game` is **public**, `has_pages: false`.
A privacy-policy page for a game is not e-commerce, so the usage limit does not appear to block it; the visitor-IP logging is GitHub's processing for people who open the page, not the game's — mention it in one line on the page only if the legal reviewer asks (U8).

## 3. Hosting choices (for 01 to present; 06 does not choose)
| ID | Choice | URL shape (illustrative, not live) | Pros | Cons |
|---|---|---|---|---|
| H1 | Separate small public repository just for the policy (e.g. `<owner>/bakery-knights-legal`), branch `main`, folder `/` | `https://<owner>.github.io/<repo>/` | Only the policy is public as a website; history of policy versions is visible; independent of game repo layout | One more repository to keep |
| H2 | This repository, dedicated branch (e.g. `gh-pages`) containing only `index.html` | `https://soltyspring.github.io/defence_game/` | No new repository | A branch outside `main`, which the team's publish helper does not manage (coordinator/user creates it) |
| H3 | This repository, `main` branch, `/docs` folder | `https://soltyspring.github.io/defence_game/services/privacy_site/` | No setup beyond Pages settings | Publishes every internal doc under `docs/` as web pages; long URL. Not recommended |
| H4 | Another free host (e.g. Google Sites) | — | No GitHub needed | **Not researched in this pass** |
06 observation: H1 keeps the published surface smallest. Not a decision.

## 4. Steps
**[USER]** = only the account owner can do it. **[01]** asks. **[04]** app integration. **[06]** content.
| # | Owner | Step | Done when |
|---|---|---|---|
| P1 | **[01]** → **[USER]** | Ask U3 (one question at a time): who is the developer named in the policy, contact email, privacy contact, and which hosting choice (H1–H4) | Answers recorded in DECISIONS.md |
| P2 | **[USER]** | Arrange the legal review of the Korean text (U8); reviewer edits the draft | Review note recorded; HTML comments resolved |
| P3 | **[06]** | Fill `{{DEVELOPER_NAME}}`, `{{APP_NAME}}`, `{{CONTACT_EMAIL}}`, `{{PRIVACY_OFFICER}}`, `{{EFFECTIVE_DATE}}`, `{{CHILD_AUDIENCE_STATEMENT}}` (needs U4) in both the draft and `privacy_site/index.html`; lint `privacy_site` reports 0 blockers | lint passes with 0 placeholders |
| P4 | **[USER]** | H1: create the public repository; H2: create the branch. Copy `index.html` (and an empty `.nojekyll`) to its root | File visible on GitHub |
| P5 | **[USER]** | Repository Settings → Pages → choose the branch and folder → Save | Pages shows "Your site is live at …" |
| P6 | **[USER]** or **[07]** | Open the URL in a private/incognito window (not signed in), on a phone and a desktop; check both languages, the title, no `{{` left, HTTPS | Screenshot + URL recorded in DATA_SAFETY_DRAFT.md / RELEASE_READINESS_SERVICES.md V2 |
| P7 | **[USER]** | Play Console → App content → Privacy policy: paste the URL | Console accepts it |
| P8 | **[04]** | Set `{{PRIVACY_POLICY_URL}}` for the in-app button (IN_APP_LEGAL_DISPLAY.md §3); re-run aapt2 (no permissions) | Button opens the page |
| P9 | **[06]** | When ads, purchases or analytics are ever turned on: regenerate the page from the draft's conditional blocks, bump `{{EFFECTIVE_DATE}}`, announce the change in game | New version published before the feature ships |

## 5. Not done and why
- No repository, branch or Pages setting was created: hosting is a user decision and account action.
- No real names, email or dates were filled: they are user data (U2/U3) and must not be invented.
