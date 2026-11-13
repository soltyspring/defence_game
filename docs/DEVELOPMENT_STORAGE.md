# 개발 폴더 용량 관리

- 루트의 `BakeryKnights.exe`는 최신 검증본을 유지한다. `build/windows/` 아래 이전 EXE와 중간 ZIP은 재생성할 수 있다. 실제 배포본과 검증 자료는 별도로 보존한다.
- `build/avd/`의 에뮬레이터 사용자 데이터는 보존한다. 자동 테스트에서 Quick Boot 스냅샷이 필요 없으면 `-no-snapshot-load -no-snapshot-save`로 실행한다.
- `tools/audio/_render/`는 로컬 렌더 출력이다. 보존할 QA 리포트와 청취 샘플은 `docs/audio/`에서 관리한다.
- `tools/engine/dl/`은 설치용 다운로드 캐시다. 설치된 엔진과 필요한 내보내기 템플릿은 유지한다.
- 배포 에셋은 `assets/`에 둔다. 챕터 배경 재생성 시안과 프롬프트는 [챕터 아트 보관 브랜치](https://github.com/soltyspring/defence_game/tree/codex/archive/chapter-art-20261114/docs/art/painted_chapters_v2)에 있다.
