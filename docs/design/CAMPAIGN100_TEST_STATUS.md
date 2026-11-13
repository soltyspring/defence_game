# 검증 현황 및 일괄 검사 대기 목록

2026-11-13 사용자가 테스트를 나중에 모아서 진행하도록 요청했다. 이후 추가 전투 시뮬레이션과 실행파일 구동 검사는 진행하지 않았다. Windows 빌드는 `-SkipRuntimeTests`로 완료했고 BUILD_INFO의 `runtime_verification`은 `deferred_by_user`다.

## 보류 요청 전에 실행한 검사

| 항목 | 결과 |
| --- | --- |
| 신규 캠페인 일반 모드 | 973개 검증 통과 |
| 신규 캠페인 테스트 상점 모드 | 984개 검증 통과 |
| 기존 캠페인 | 351개 검증 통과 |
| 기존 도전 콘텐츠 | 251개 검증 통과 |
| 기존 서리·둥지 보스 | 180개 검증 통과 |
| UI 통합 | 49개 검증 통과 |
| 서비스·강화 | 1,208개 assertion 통과, 종료 시 ObjectDB 2개·리소스 1개 잔존 경고/오류로 전체 실행기는 실패 처리 |
| 초기 밸런스 탐색 | 216회 비교 완료. 최종 데이터 검증 결과가 아님 |
| 관문 보정 | 30Hz, casual 봇, seed 11로 후보 보정 완료. 독립 검증 미실행 |

관문 후보 계수는 R23=1.5291, R42=1.4521, R61=1.6575, R79=0.7663, R96=1.1476이다. R79는 적 조합에 따른 보정 때문에 1보다 작다. 이 결과만으로 특정 금액을 지출해야 하거나 지출하면 반드시 클리어한다는 보장은 할 수 없다.

## 다음 일괄 검사

1. 서비스 검사 종료 시 남는 객체·리소스를 추적하고 정리한다.
2. 공용 heavy-run 잠금 안에서 `tools/build/verify_campaign100.ps1 -Godot '<console exe 경로>' -Balance`를 실행한다.
3. 실제 게임과 같은 60Hz에서 독립 seed 29/47/83의 관문 구매 전후 비교와 100개 스테이지 개별 검사를 수행한다.
4. `journey_campaign100.gd`로 실제 별·처치 골드·최초 클리어 보상과 강화 상태를 누적한 연속 진행을 검사한다.
5. 신규 병종 편성별 플레이와 화면·입력을 확인한다. 10종 중 5종의 모든 252개 조합은 아직 장기 검증하지 않았다.
6. 격리 APPDATA에서 패키지 실행파일의 메뉴·전투·상점 구동과 `probe_campaign100_export.gd`를 검사한다.
7. 실패한 관문·성장 구간을 조정하고 영향을 받는 검사를 다시 수행한다.

현재 실행파일은 빌드가 완료된 테스트 상점 포함 버전이다. 패키지 실행 및 최종 밸런스 검증 완료 버전으로 표시하지 않는다. 실제 결제는 연결하지 않았다. 저장 폴더는 `BakeryKnights-Campaign100`으로 분리했다.

## 빌드 재현

```powershell
& ./tools/build/build_windows.ps1 -Godot '<Godot console exe 절대 경로>' -FromWorkingTree -GoldShopPreview -UserDataName 'BakeryKnights-Campaign100' -SkipRuntimeTests -OutDir './build/windows/campaign100-preview'
```

이 명령도 공용 heavy-run 잠금 안에서 실행한다. 테스트를 재개할 때에는 `-SkipRuntimeTests`를 제거한다. 빌드 출력·개인 로그·엔진·세이브는 Git에 포함하지 않는다.
