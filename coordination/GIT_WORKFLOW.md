# Git task delivery (user directive)
Repository: https://github.com/soltyspring/defence_game
Remote: origin. Shared branch: main. Local branch already tracks origin/main and preserves original remote history.
Every completed, meaningfully verified task must be committed and pushed by the responsible Claude CLI. Codex coordinates only; it does not author game features. Do not wait for the whole game to commit. Do not make a commit per keystroke or include unfinished unrelated work. User authorized pushes here.

## Exact commit convention (user supplied)
[Feat] 새로운 기능 추가
[Fix] 버그 수정
[Design] UI 디자인/도트 이미지/그래픽 디자인 변경
[!BREAKING CHANGE] 커다란 API 변경
[!HOTFIX] 치명적인 긴급 버그 수정
[Style] 동작 변경 없는 코드 포맷 변경
[Refactor] 프로덕션 코드 리팩토링
[Comment] 주석 추가/변경
[Docs] 문서 수정
[Test] 테스트 추가/리팩토링 (프로덕션 코드 변경 없음)
[Chore] 빌드/패키지 매니저/설정 변경
[Rename] 파일/폴더 이동·이름 변경만
[Remove] 파일 삭제만
Example: [Feat] 아군 유닛 출병과 본진 공격 구현
Use concise Korean subjects and optional body describing why and actual validation. NEVER use feat: or art: instead of this convention. Split unrelated task types when sensible. No invented ticket IDs.

## Shared checkout serialization (mandatory for ALL workers)
Never run git add ., git add -A, git commit -a, reset, clean, stash, force push, history rewrite or rebase while others work. Stage only explicit owned task files. Read OWNERSHIP.md. Cross-owner changes must be committed by their owner.
ALL staging/commit/push operations MUST use coordination/Publish-Task.ps1. It holds a shared exclusive file lock at .git/task-publish.lock throughout staging, commit and push. Do not bypass a busy lock. The helper refuses a pre-existing staged index or an unexpected remote divergence, and never rebases/resets. On push failure preserve the local commit, record error in handoff and request coordination help. Do not recreate the same commit.
Only helper calls from workspace root, e.g.:
& .\coordination\Publish-Task.ps1 -Role 01-director -Type Docs -Subject '첫 전투 기획과 라운드 설계 추가' -Paths @('docs/design/IMPLEMENTATION_BRIEF.md','data/economy.json')
Before call: run your meaningful validation and inspect your diff; helper does not replace verification.
Record commit SHA, remote branch, push success and validation in your own handoff after each task. If network/auth fails say PUSH_PENDING, never PUSHED. Never write credentials into source/logs. Never commit local engine binaries/templates, imported cache, logs, signing keys, secrets, APK/AAB or unrelated files. 02 must publish a project .gitignore matching these exclusions; current .git/info/exclude already prevents local tooling/cache/keys from accidental staging.

## Request delivery
Every worker must read this file at next milestone, and acknowledge Git protocol in own handoff. Initial files remain uncommitted until owners review them. Codex adding this directive file does not count as worker read receipt.

Windows PowerShell caveat: invoke Publish-Task.ps1 DIRECTLY, without 2>&1, pipes or output redirection. Native Git stderr may otherwise trigger terminating errors under ErrorActionPreference Stop. If it fails, inspect index/current SHA and preserve local commits; do not re-stage other workers files. Root build output exclusions are anchored so tools/build source scripts remain trackable.
