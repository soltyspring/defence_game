# 데이터·백엔드 분석: 성공한 디펜스 게임의 온라인 기능과 우리 게임의 최소 설계
작성: 10-research-systems · 버전 v0.15 (v0.15 §9.6 데이터 버전 변경과 세이브, v0.14 §9.5 업그레이드 효과 곡선, v0.13 §9.4 업그레이드 트랜잭션·content_version, … v0.11 재시작 후 무결성 재실행: D17 확인, v0.12 테마 A 이름표 검사 통과·세이브 재확인) · 기준일 2026-10-31 KST · 모든 출처 접근일 2026-10-31
범위: 경쟁작에서 **관찰되는** 온라인 기능, 그 기능의 **공개 문서화된** 기술, **UNKNOWN**, 우리 오프라인 우선 Godot 게임에 필요한 최소 콘텐츠 DB·세이브·거래 계약. 런타임 코드는 수정하지 않았다. 내부 DB나 비공개 구현에 접근한 적 없다. 게임을 직접 플레이하지 않았다(스토어 텍스트·공개 스크린샷만 확인).

## 0. 현재 판단 (요약)
1. 두 경쟁작 모두 **DB 벤더·스키마·서버 구조는 공개 1차 자료로 확인되지 않는다(UNKNOWN)**. 확인된 기술 사실은 랜덤다이스의 AdMob 플랫폼·비딩 도입(Google 사례 연구)과 고객지원 이메일 도메인(Helpshift) 정도다. Redis/Firestore/MySQL/Unity 사용 여부를 단정하지 않는다.
2. 경쟁작이 성공한 이유를 백엔드에서 찾기는 어렵다. 111퍼센트 리더들 스스로가 마케팅이 잘 되면 리텐션이 오르고, 연 30개 정도 출시해 1~2개가 살아남았다고 말한다([M], S4). 서버 기술은 **실패를 막는 조건**(데이터 유실, 중복 지급, 환불, 정책 위반)으로 보고, 성공 원인으로 보지 않는다.
3. 우리 게임은 계정 없는 오프라인 싱글플레이로 출시하는 것이 비용 대비 맞다. Google Play 정책상 오프라인에서만 만들고 쓰는 계정은 계정 삭제 의무 대상이 아니다(S14). 서버·PvP는 선택 단계로 분리한다.
4. 가장 위험한 전제: "로컬 세이브가 충분히 안전하다". 현재 `src/core/save.gd`는 원자적 쓰기·체크섬·.bak을 갖췄다. 그러나 v0.3에서 **수정하지 않은 save.gd를 헤드리스로 실행해** 확인한 결과(§6.4 SV-1), `.bak` 복구 직후 첫 저장이 정상 백업을 손상 파일로 바꾼다. 그 뒤 장애가 한 번 더 나면 진행도가 1라운드로 초기화된다(실측 6→1). 저장 도중 종료를 흉내 낸 경우에는 `recovered=false`로 **사용자에게 알리지 않고** 초기화된다. 상위 버전 덮어쓰기(SV-2)와 타입 정규화 부재(SV-5)는 07이 독립적으로 재현했다(QA-O003, QA-B003). 전투 결과 멱등성(SV-3)은 아직 코드 읽기 수준이다.

## 1. 방법과 증거 등급
| 표기 | 의미 | 증명할 수 있는 것 | 증명할 수 없는 것 |
|---|---|---|---|
| [F] | 1차 공식 문서(플랫폼 문서, 사례 연구 원문, 법원 판결 보도 중 당사자 발표) | 그 문서가 말한 사실 | 현재도 같은 구현인지 |
| [D] | 개발사가 스토어에 스스로 신고한 정보(Data safety, 권한, 등록 정보) | 신고 내용 | 실제 구현의 정확성 |
| [M] | 자사 마케팅·인터뷰 주장 | 회사가 그렇게 말했다는 사실 | 인과관계, 수치의 정의 |
| [O] | 공개 스크린샷 관찰(2026-10-31 Play 등록 이미지) | 화면에 보이는 기능 | 서버 구현, 실제 빈도 |
| [R] | 이용자 리뷰 표본 | 그런 불만이 존재함 | 비율, 대표성 |
| [I] | 근거 있는 추론 | 설계 요구사항 후보 | 경쟁사가 실제로 그렇게 했는지 |
| [U] | UNKNOWN | — | — |
리뷰 표본 한계: Google Play 영어(hl=en) 상세 페이지에 기본 노출된 리뷰 3건만 봤다. 정렬 기준은 Google이 정한 것이고, 무작위 표본이 아니다. KO 리뷰는 09의 표본(앱당 20건)을 재사용한다(§5.8).
채용 공고 규칙(코디네이터 검토 기준 반영): 회사 채용 공고의 AWS/GCP/NoSQL 같은 기술 태그는 그 회사나 팀이 쓰는 기술의 근거일 뿐이다. 특정 출시 게임의 DB·벤더·스키마나 리텐션의 근거가 아니다. 이 문서는 채용 공고를 경쟁작 백엔드의 근거로 쓰지 않았다. 원문 페이지 스냅샷이나 스크립트도 게시하지 않는다.
스크린샷: 스토어 이미지를 로컬에서 열람만 했고 저장소에 커밋하지 않는다. 우리 게임에 경쟁작 에셋을 쓰지 않는다.

## 2. 대상 식별: "궁수키우기"는 패키지가 확정되지 않았다
사용자가 말한 제목은 Play에 같은 이름의 앱이 여러 개 있다. 검색어 `궁수키우기`, `아처키우기`(KR 스토어, 2026-10-31)로 찾은 결과다.
| 패키지 | 등록 제목(KR) | 개발사 | 다운로드 배지 | 평점/리뷰 수 | 업데이트 |
|---|---|---|---|---|---|
| com.GameDuo.MadArcher | 아처키우기 : 방치형 디펜스 (영문 Archer Forest : Idle Defense) | 게임듀오 | 100만+ | 4.5 / 5.83만 | 2026-09-17 |
| com.ohm1004.Defense | 궁수키우기 RPG | MADPLAY | 10만+ | 4.6 / 5.9천 | 2026-10-18 |
| com.juokstudio.archer | 궁수키우기 : 스틱맨RPG | JU-OK STUDIO | 1만+ | 4.2 / 166 | 2026-10-29 |
| kr.minigame.archer | 궁수 키우기 | Kafra | 10+ | — | 2026-10-30 |
| com.jumongarcher.defense | 궁수 키우기: 성벽전투 | Jong1 | 10+ | — | 2026-10-04 |
| com.rp.archer | 신궁 키우기 : 방치형 RPG | RP Horizon | 5만+ | 4.9 / 2.3천 | 2026-10-22 |
| com.springgames.archercastle | 아처캐슬 키우기 : 방치형 RPG | SPRING Games | 10만+ | 4.7 / 6.7천 | 2026-10-30 |
**가정(미확정):** 비교 대상은 코디네이터가 정한 임시 후보 `com.GameDuo.MadArcher`다. 다운로드 배지가 가장 크고 "디펜스"를 표방하기 때문이다. 사용자가 다른 앱을 뜻했다면 §3의 게임듀오 행만 바뀐다. 랜덤다이스 행은 그대로다. 이 질문은 01의 Q1이 끝난 뒤 01만 물을 수 있으며, 10은 직접 묻지 않는다.
배지 수치는 Play가 표시한 구간값이다. 시점·지역은 2026-10-31 KR 스토어다. 매출 순위나 현재 랭킹이 아니다. 랭킹은 확인하지 않았다.

## 3. 첫 증거/UNKNOWN 매트릭스
### 3.1 성공 지표 (날짜·지역·출처가 있는 것만)
| 게임 | 지표 | 값 | 시점/범위 | 등급·출처 |
|---|---|---|---|---|
| 랜덤 다이스(com.percent.royaldice) | 누적 다운로드, DAU | 1,100만+ 다운로드, DAU 40만 | 사례 연구 게시 당시(검색 메타데이터상 2022-04). 전 세계. 정의 미공개 | [F/M] Google AdMob 사례 연구 S5. Google이 고객 사례로 게시한 마케팅 자료라 독립 감사 수치가 아니다 |
| 랜덤 다이스 | 수익 구성 | 광고 수익이 전체의 15% | 동일 | [F/M] S5 |
| 랜덤 다이스 | Play 배지 | 1,000만+, 4.2★, 리뷰 65만, "에디터 추천" | 2026-10-31 KR | [D/F] S2 |
| 랜덤 다이스 2(com.percent.aos.randomdice2) | Play 배지 | 50만+, 4.6★, 리뷰 8.76천, 업데이트 2026-10-29 | 2026-10-31 KR | S3 |
| 랜덤다이스 | 정점 | "2020년 초에 정점" | 111퍼센트 LD 발언, 게시일 미확인 | [M] S4 |
| 게임듀오(회사 전체) | 매출 | 2019년 4억 → 2024년 630억(통화 단위 표기 없음, 원화로 추정 [I]) | 회사 소개 페이지 | [M] S9. 게임별 매출 아님 |
| 아처키우기 | Play 배지 | 100만+, 4.5★, 리뷰 5.83만 / 영어 페이지 리뷰 55.2K | 2026-10-31 | S1 |
"현재 최상위 랭킹" 주장은 하지 않는다. 지금 순위·매출·리텐션은 UNKNOWN이다. 09-research-product가 제품 측 성공 지표를 맡는다.

### 3.2 온라인 기능: 관찰 vs 공개 기술 vs UNKNOWN
| 영역 | 랜덤 다이스 관찰 | 아처키우기 관찰 | 공개 문서화된 기술 | UNKNOWN |
|---|---|---|---|---|
| 계정·신원 | Data safety: 이메일·사용자 ID(계정 관리, 사기 방지), 구매 내역 수집 [D] | Data safety(영문): 사용자 ID·기기 ID(앱 기능·분석·계정 관리) [D]. 개인정보처리방침: 계정·게임 진행 데이터, 고유 ID 생성, 결제 확인 [D] | 없음 | 로그인 제공자(게스트/구글/애플), 계정 연동 방식, 저장 위치 |
| 실시간 PvP | "전 세계 매치메이킹 실시간 PvP", 트로피·시즌 랭킹 [D 등록 문구]. 스크린샷에 상대 보드가 내 보드 위에 보인다 [O] | 없음(등록 문구 기준) | 없음 | 권위 서버 vs 락스텝, 릴레이, 지역 서버, 엔진 |
| 협동(PvE) | 협동 보스 레이드, 웨이브 기록 [D]. 스크린샷 "Wave 50"에 두 보드 [O] | — | 없음 | 동기화 방식, 봇 매칭 여부 |
| 랜덤다이스2 협동 | 공동 처치 수 "2098"과 파트너 이름 "Skynet"이 화면에 보인다 [O] | — | 없음 | 파트너가 사람인지 봇인지 |
| 길드·시즌 | 크루 대전, 시즌 랭킹전, 한정 이모티콘 [D] | — | 없음 | 시즌 초기화, 리더보드 저장소 |
| 가챠·확률 | 랜덤다이스2 등록 문구: "가챠 시스템 폐지" [M] | 스크린샷 하단에 "*확률형 아이템 포함" [O] | 한국 확률 정보 공개 의무(ECONOMY.md에 01이 정리) | 확률표 저장·버전 관리 방식 |
| 방치/오프라인 보상 | — | "방치형" 장르 표방 [D] | 없음 | 경과 시간을 서버 시각으로 계산하는지 |
| 광고 | AdMob 플랫폼 + 비딩, 2021년 7월 전 세계 적용, 3개월 만에 eCPM +28% [F/M] S5 | Data safety: 광고 목적으로 기기 ID 공유 [D]. 리뷰: 광고 시청 후 Play 스토어가 열리고 게임이 재시작되면 보상이 인정되지 않았다는 불만(2026-05-03) [R] | AdMob 사용(랜덤다이스만) | 보상형 광고 서버 측 검증(SSV) 사용 여부 |
| 고객지원 | 지원 이메일 도메인 `@111percent.mail.helpshift.com` [D] → Helpshift 사용 [I, 강함] | archer@gameduo.net | — | 티켓-계정 연결 방식 |
| 커뮤니티 | 공식 Discord·YouTube [D] | — | — | — |
| 데이터 삭제 | Data safety: 삭제 요청 가능 [D] | Data safety(영문): "삭제할 수 없음" [D] | Play 계정 삭제 정책 S14 | — |
| 전송 보안 신고 | Data safety에 "암호화되지 않음 / 보안 연결로 전송되지 않음"으로 표시 [D] | "전송 중 암호화" [D] | — | 실제 구현. 신고 오류일 수도 있으므로 보안 결함으로 단정하지 않는다 |
| DB·서버 벤더 | **UNKNOWN** | **UNKNOWN** | 없음 | 전부 |
| 엔진 | 공개 1차 자료 미확인 | 미확인 | — | 팬 프로젝트가 Unity로 모작했다는 사실은 원작 엔진의 증거가 아니다 |

### 3.3 개발사 발언 중 시스템 설계에 영향을 주는 것 ([M], S4 슈퍼패스트 뉴스룸 대담, 게시일 미확인)
- 111퍼센트 LD 쌤: PvP는 이기면 즐겁지만 진 사람이 떠나서 규모를 키우기 어려웠다. 그래서 랜덤다이스2는 협동에 무게를 두고 가챠를 없애는 시도를 했다.
- LD 애덤: 협동 게임은 대전 피로가 적다는 가설이 맞았다. 저연령 타깃 가설은 틀렸고, 타깃을 바꿔 약 3개월 동안 다시 설계했다.
- 출시 후 3~4일이 지나면 예측보다 관측(지표)이 중요하다고 말한다. 이 말은 분석 파이프라인 요구로 이어진다 [I].
- 레이블 체제 이전에는 연 30개 정도를 출시해 1~2개가 살아남았다. 이것은 생존자 편향을 보여주는 직접 근거다.
- 법적 맥락([F] 당사자 발표 보도 S10, S11): 2026-04 서울중앙지법 1심은 「랜덤다이스: GO」 모방 게임에 대해 저작권 침해는 인정하지 않고 부정경쟁만 인정했으며 약 5.57억 원 배상을 명했다. 피고는 항소할 예정이다. 우리에게 주는 교훈 [I]: 장르 규칙 자체보다 **구성 요소 조합과 표현을 통째로 가져오는 것**이 법적 위험이다. 그래서 Paladog/Cat War에서 영감을 받더라도 조합·UI·표현은 독자적으로 유지해야 한다.

## 4. 성공 설명: 시스템 관점의 가설과 가장 강한 대안 설명
| 가설 | 근거 | 가장 강한 대안 설명/반례 | 판정 |
|---|---|---|---|
| H1 실시간 PvP와 랭킹이 랜덤다이스 초기 성장의 엔진이었다 | 등록 문구, 2020년 정점 발언 [M] | 같은 회사가 PvP 이탈 문제를 밝혔다. 정점 이후 감소했다. 광고 소재와 UA 예산의 효과를 분리할 수 없다 | 인과 미확정. 우리에게 PvP가 필요하다는 근거가 되지 않는다 |
| H2 협동/비대전 구조가 최근 111퍼센트 흥행작의 공통점이다 | 운빨존많겜·랜덤다이스2 발언 [M] | 같은 회사 안에서도 실패작이 많았다. 생존작만 보고 있다 | 우리 설계(오프라인 PvE)와 방향이 같을 뿐 검증은 아니다 |
| H3 방치형 성장 + 많은 일일 콘텐츠가 아처키우기의 체류를 만든다 | "방대한 스테이지", "끊임없는 콘텐츠" [D] | 리뷰 2026-08-21: "일일 할 일이 너무 많고 성장 경로 설명이 없어 압도적" [R]. 콘텐츠량은 운영 비용이자 이탈 요인일 수도 있다 | 우리 볼륨 목표에는 쓰지 않는다 |
| H4 서버 기반 LiveOps(시즌·이벤트)가 장기 매출을 만든다 | 시즌·크루·이벤트 모드 [D] | 확인 가능한 리텐션·매출 데이터가 없다. 네트워크 효과와 마케팅 예산이 교란 변수다 | UNKNOWN. 우리는 데이터 기반 이벤트를 "앱 업데이트로" 먼저 시험 |
| 반론 전체: "단순한 그래픽/시스템 덕분에 성공" | — | 사후 설명이다. 마케팅 투자, 네트워크 효과(PvP 대기열 유동성), 회사 포트폴리오(연 30개 출시)가 더 큰 설명력을 가질 수 있다 | 채택하지 않음 |

## 5. 영역별: 경쟁작 관찰 → 추론된 요구 → 가능한 설계안 → 우리 결정
각 "가능한 설계안"은 경쟁사가 실제로 썼다는 주장이 아니다. 기능을 구현할 수 있는 대안들이다.

### 5.1 콘텐츠 DB (유닛/스테이지/스킬/희귀도/경제/버전)
- 관찰: 두 게임 모두 유닛 수집·강화·스테이지·보스가 있다 [D]. 아처키우기는 확률형 아이템이 있다 [O].
- 추론된 요구 [I]: 영구 ID, 밸런스 수치와 진행도 분리(세이브에는 ID와 레벨만), 확률표 버전 고정과 공개 가능성, 앱 업데이트 없이 수치를 바꾸려면 원격 배포가 필요하다.
- 설계안: (A) 앱에 번들된 JSON + 빌드 시 검증, (B) SQLite 번들 DB(Godot은 플러그인/GDExtension이 필요), (C) 원격 서명 JSON(CDN) + 번들 기본값, (D) 서버 DB 테이블 + 관리 도구.
- **우리 결정: (A)를 유지한다.** 이미 `data/**`(01 소유), `Content` 로더, 알 수 없는 키 무시, 기본값 폴백이 있다(INTERFACES §2, §6). 추가할 것:
  1. `content_version`: 빌드 시 `data/**` 정렬 해시(예: `c1-<sha256 앞 12자>`). 세이브와 분석 이벤트에 기록해 "어떤 밸런스에서 생긴 진행도인가"를 추적한다.
  2. `data/migrations.json`(01 소유 제안): ID 이름 변경과 폐기 시 환불 규칙.
  ```json
  { "schema_version": 1,
    "renames": { "up_worker_old": "up_worker" },
    "retired": [ { "id": "up_legacy", "refund": "sum_costs_paid", "currency": "gold" } ] }
  ```
  3. 확률형 상품은 MVP에 없다(D9, M3 비권장). 도입되면 확률표를 `data/gacha/<pool>.json` + `pool_version`으로 고정하고 결과 로그에 버전을 남긴다(한국 확률 공개 의무에 대응).
- (B) 기각 이유: 수백 행 규모에서 JSON보다 이점이 없고, 네이티브 플러그인 바이너리와 Android 빌드 위험이 늘어난다. (C)/(D)는 §5.5 선택 단계다.

### 5.2 플레이어 세이브·진행도·재화·권리
- 관찰: 두 경쟁작은 사용자 ID·계정 관리를 신고했다 [D]. 서버 저장 여부는 [U]. 게임듀오 방침은 "계정 및 게임 진행 상황 데이터"를 자동 수집한다고 쓴다 [D].
- 추론: 다기기·재설치를 지원하려면 클라우드 세이브가 필요하다. Google은 Play Games 레벨업 가이드라인에서 클라우드 세이브와 충돌 해결을 요구하고, 게스트 진행도를 자동으로 덮어쓰지 말라고 권한다 [F] S12.
- 우리 현재 상태(코드 확인): `user://save.json`, 페이로드 SHA-256, tmp→rename, `.bak`, `_migrate`. 재화는 정수 `coins`. 업그레이드는 `upgrades{id:level}`로 읽힌다(`fresh()`에는 키가 없음).
- 체크섬은 **손상 탐지용이지 변조 방지가 아니다.** 누구나 다시 계산할 수 있다. 오프라인 싱글에서는 변조를 허용하는 것이 맞다(경쟁·금전 가치가 없음). 서버 없이는 막을 수 없다는 점을 Google도 같은 취지로 설명한다 [F] S6.

**MVP 세이브 v2 제안(02 소유, 요청 R1):**
```json
{ "version": 2,
  "revision": 57,
  "content_version": "c1-3fa9b2c01d4e",
  "app_version": "0.3.0",
  "unlocked_round": 4,
  "wallet": { "gold": 1240 },
  "rounds": { "r01": { "best_stars": 3, "best_time": 95.2, "clears": 4 } },
  "upgrades": { "up_melee_basic": 3 },
  "applied_battles": [ "b7c1e0f29a44d812" ],
  "tutorial_done": [ "t_deploy" ],
  "stats": { "kills": 812, "rounds_played": 19 },
  "settings": { "fps_cap": 60, "sfx": 1.0, "music": 0.8 },
  "services": { "consent": {}, "ads": {}, "iap": {} } }
```
규칙: 계산된 스탯을 저장하지 않는다. 알 수 없는 ID는 보존한다. `applied_battles`는 최근 32개만 유지한다. `wallet`은 `coins`의 v1→v2 이름 변경이다(D12의 "골드"와 일치). 이름을 유지해도 되며 02가 결정한다.

**거래 계약(Transaction contract) — 모든 영구 변경은 하나의 경로로:**
```
Save.transact(key: String, fn: Callable) -> {code, revision}
 1. key가 applied 집합에 있으면 → already_applied (아무것도 바꾸지 않음)
 2. draft = progress.duplicate(true); fn(draft) 실행. 검증 실패면 → rejected (progress 그대로)
 3. draft.revision += 1; key를 applied에 추가
 4. draft를 tmp에 쓰고 검증한 뒤 rename. 실패하면 → save_failed (progress 그대로, UI 토스트)
 5. 성공한 경우에만 progress = draft; progress_changed 발행
```
| 거래 | key | 검증 |
|---|---|---|
| 전투 결과 반영 | `battle:<battle_uid>` (02가 전투 시작 시 128비트 랜덤 생성) | 라운드 해금 상태, 보상 = 데이터 계산값(클라이언트 입력값이 아님) |
| 업그레이드 구매 | `upg:<upgrade_id>:<to_level>` | 대상 해금, level < max_level, gold ≥ cost |
| 보상형 광고 지급 | `ad:<context_id>` (06 설계와 같음) | 06 게이트 통과 |
| 소모성 IAP 지급 | `iap:<sha256(token)[:32]>` (06 설계와 같음) | 검증기 ok |
현재 `record_result`는 메모리를 먼저 바꾸고 `save_progress()`의 반환값을 무시한다. 쓰기가 실패하면 메모리와 디스크가 달라지고, 다음 저장 때 반영된다. 치명적이지는 않다. 다만 업그레이드 구매처럼 "차감 + 레벨업"이 짝인 거래는 위 계약이 필요하다.

### 5.3 협동/PvP/매치/세션 일관성
- 관찰: 랜덤다이스는 실시간 PvP, 협동, 크루전, 미러전을 제공한다 [D]. 상대 보드가 화면에 보인다 [O].
- 추론된 서버 요구 [I]: 매치메이킹 큐, 세션 상태 동기화(상대 보드 표시), 결과 판정 권한, 연결 끊김 처리, 레이팅·시즌 저장, 부정행위 대응.
- 설계안: (A) 없음. (B) 비동기 "고스트" 대전: 상대의 덱·업그레이드 스냅샷과 시드를 받아 로컬에서 시뮬레이션. (C) 실시간 락스텝: 입력만 교환하고, 같은 시드·고정 스텝 결정론에 의존. (D) 서버 권위 실시간: 서버가 시뮬레이션을 돌리고 클라이언트는 입력만 보낸다. Godot 문서는 경쟁·영속 멀티에는 서버 권위 로직을 쓰고 클라이언트 입력을 신뢰하지 말라고 권한다 [F] S13.
- 우리 자산: `battle_sim.gd`는 고정 스텝(`Perf.SIM_STEP`)과 시드 RNG를 쓰고, 화면과 분리되어 있다(코드 확인). (B)/(C)/(D)의 기반이 된다. 단 **기기 간 부동소수점 결정론은 검증되지 않았다.** 같은 시드와 같은 입력 로그로 Windows와 Android의 결과 해시가 같은지 테스트해야 한다(TP-12).
- **우리 결정: MVP는 (A).** 이유: PvP는 대기열이 차야 성립하는 네트워크 효과에 의존한다. 같은 장르 개발사가 PvP 이탈을 밝혔다(S4). 계정·서버·부정행위 대응·데이터 안전 신고 비용이 생긴다. 다음 후보는 (B)다. 서버 없이 "친구 코드" 형태로 스냅샷을 교환하면 경쟁 가치가 없으므로 변조를 허용해도 된다.

### 5.4 원격 설정·LiveOps·이벤트
- 관찰: 시즌제, 시즌 주사위, 이벤트 모드 [D]. 운영 방식은 [U].
- 1차 지침(Firebase Remote Config 문서, 패턴 근거로만 인용) [F] S15: 앱에 기본값을 넣어 네트워크 없이도 동작하게 하고, 받은 값은 다음 실행에 적용하며, 사용자가 보는 UI를 실행 중에 바꾸지 말라고 한다.
- 우리 결정: MVP는 원격 설정 없음(INTERNET 권한 false, `export_presets.cfg` 확인). 이벤트는 `data/events/*.json`과 `start/end` 날짜로 **앱 업데이트를 통해** 배포한다. 기기 시계를 쓰므로 조작이 가능하며, 보상 가치를 낮게 유지한다. L1.5 단계: 서명된 정적 JSON(CDN)을 받고 다음 실행에 적용, 스키마 검증, 킬스위치. 벤더 선택은 사용자 결정(01 경유).

### 5.5 분석 퍼널, 오프라인 보상, 시간 조작
- 관찰: 경쟁작은 분석·진단·기기 ID를 신고했다 [D].
- 우리 현황: 06의 `ANALYTICS_EVENTS.md`는 영구 식별자 없이 세션 ID만 쓴다. 이 설계로는 **D1/D7 리텐션을 계산할 수 없다.** 개인정보를 지키려는 의도적 선택이다. 3.3의 "출시 후에는 관측" 교훈과 충돌한다. 해결안: (a) Play Console 집계 통계로 대체(제공 범위는 확인 필요 [U]), (b) 동의 기반 설치 단위 랜덤 ID(재설치 시 초기화, 데이터 안전 신고 필요), (c) 비공개 테스트에서만 활성화. 01/06 결정 사항이다.
- 퍼널 제안(06 스키마 확장, 요청 R3): `ftue_step{step_id}`(튜토리얼 키, 01 데이터의 `tutorial[]`), `round_start/round_end`(이미 있음), `upgrade_buy`(있음), `save_recovered{source: bak|fresh}`(신규, 세이브 손상률 측정). 금액·자유 텍스트는 보내지 않는다.
- 오프라인(방치) 보상: `meta.json`의 `offline_income.enabled=false`. 활성화한다면 다음 규칙을 따른다. 경과 시간 = `clamp(now_unix − last_seen_unix, 0, cap)`. 시계가 뒤로 가면 보상 0이고 처벌하지 않는다. `cap`은 데이터로 둔다. 세션 안의 시간은 단조 시계(`Time.get_ticks_msec`)를 쓴다. Godot 문서는 `_from_system` 계열은 사용자가 바꿀 수 있는 시계라 정밀 계산에 쓰지 말라고 한다 [F] S16. 앞으로 돌리는 조작은 서버 없이 막을 수 없다. 그래서 보상은 진행 편의 수준으로 제한한다.

### 5.6 멱등 지급·영수증·환불·원장
- 1차 지침 [F] S6: 구매 검증과 확인(acknowledge)은 백엔드에서 처리하라. purchaseToken은 전역 고유이므로 DB 기본키로 써도 된다. PENDING에는 지급하지 말라. Voided Purchases API로 환불 건을 회수하라. 3일 안에 확인하지 않으면 자동 환불된다.
- AdMob SSV [F] S7: 보상 콜백에 `transaction_id`(지급 이벤트별 고유)가 있고 ECDSA 서명으로 검증한다. 서버가 있어야 쓸 수 있다.
- 우리 현황: 06이 로컬 원장(광고 context_id, 토큰 해시)을 이미 만들었고, 프로덕션 검증기는 `verification_unavailable`이다(실제 결제 지급 불가). 이 판단은 1차 지침과 맞다.
- 아처키우기 리뷰 [R]가 보여주는 실패 유형: 광고 → 스토어 열림 → 앱 재시작 → 보상 누락. 우리 대응은 TP-08이다.

### 5.7 마이그레이션·백업·게스트 연동·보안
- Android 자동 백업 [F] S8: Google Drive에 앱당 25MB까지, 대략 하루 한 번, 최신 1개만 보관한다. 내부 저장소 파일이 기본으로 포함된다. Godot 내보내기 옵션 `user_data_backup/allow`가 백업 참여를 정한다 [F] S17. 우리 `export_presets.cfg`에는 이 키가 없다. 실제 기본값은 확인하지 않았다 → 04가 명시적으로 정하고 실기기에서 `adb shell bmgr`로 시험해야 한다(R4).
  - 백업 허용 시 장점: 재설치·기기 변경 때 진행도가 복구된다. 비용 0, 계정 불필요.
  - 위험: 하루 단위의 과거 세이브가 복원된다. 그동안 산 소모성 지급분은 사라질 수 있다. 비소모성은 06의 restore가 재구성한다. 복원 경로는 `.bak` 로직과 함께 테스트해야 한다(TP-11).
- Play Games 저장된 게임 [F] S12: 파일당 3MB, 오프라인 쓰기 가능, 충돌 해결은 게임 책임이다. 게스트 진행도를 자동으로 덮어쓰지 말고 선택지를 보여주라고 권장한다. 도입하면 로그인, 플러그인, 데이터 안전 신고가 생긴다. L2 단계 후보다.
- 보안: Play Integrity는 백엔드가 판정을 받아 조치하는 구조이고, 기본 한도는 하루 1만 요청이다 [F] S18. 서버가 없으면 쓸모가 거의 없다. 클라이언트에 비밀값을 넣지 않는다(06 static_guards가 이미 검사).

### 5.8 09가 넘긴 서버·영속성 증상 → 데이터 요구 (R09-10-1 처리)
09가 KO 리뷰를 표본으로 모았다(2026-10-31, 기본 정렬, 앱당 20개, 대표성 없음; SUCCESS_ANALYSIS.md §8). 10은 리뷰를 다시 수집하지 않고 그 표본을 쓴다. 아래 원인 열은 **가능한 메커니즘**이다. 경쟁사의 실제 원인이 무엇인지는 UNKNOWN이다.
| 증상(09 표본) | 가능한 메커니즘 [I] | 우리 MVP 대응 | 테스트 |
|---|---|---|---|
| 기기 이전 후 아이템 대부분 유실(royaldice 2026-08-24) | 계정 연동 범위 밖 데이터, 로컬 전용 필드 | 계정 없음. 자동 백업(L1) 외에는 이전을 약속하지 않고, 설정·스토어 문구로 고지(04) | TP-11 |
| 재설치 후 유료 광고 제거까지 초기화(MadArcher 2022-12-26) | 권리(entitlement)를 게임 세이브에서만 꺼냄 | 비소모성 권리는 **항상 스토어 restore로 재구성**한다. 세이브 기록은 캐시일 뿐이다(06 설계와 같음) | TP-10, TP-11 |
| "데이터 동기화" 후 챕터 진행 사라짐(archero 2019-07-12) | 클라우드/로컬 충돌 시 최신 시각 우선으로 덮어씀 | L2 도입 시 진행도 필드별 단조 병합(별 수·클리어 수는 max, 재화는 사용자 선택). S12의 "자동 덮어쓰기 금지" | L2 단계에서 추가 |
| 홈 버튼·전화로 판 초기화, 재접속 지연 시 강퇴(randomdice2 2026-08/09) | 서버 세션 타임아웃, 판 상태 비영속 | 오프라인이라 강퇴는 없다. Android가 백그라운드 프로세스를 죽이면 판이 사라진다 → 아래 run checkpoint | TP-15 |
| 환불 → 계정 정지, 이중 결제(MadArcher 2022~2023) | 환불 회수 정책, 결제 원장 | IAP 비활성. 활성 시 Voided Purchases로 권리 회수만 하고, 정지 같은 제재는 01/사용자 결정(S6) | TP-10 |
| 광고 보상 누락(archero 2026-05-21; Archer Forest EN 2026-05-03) | 콜백과 영속 사이 프로세스 종료, 클라이언트 콜백 위조 방지용 서버 검증 실패 | TP-08 정책 | TP-08 |
| 예고 없는 점검, 서버 통합으로 경쟁 콘텐츠 경제 붕괴(MadArcher 2023-09, 2024-06) | 서버 의존 경제 | 오프라인이라 해당 없음. 온라인 기능을 추가하면 점검 공지 채널이 필요하다 | — |
| PvP·협동 매크로 방치(royaldice 2026-08-10) | 서버 권위·탐지 부재 | MVP에 PvP 없음 | — |

**진행 중 전투 체크포인트(09의 E3 실험을 세이브 측면에서 보완):**
- 선택지: (a) 체크포인트 없음. 판은 2~5분이고 초점을 잃으면 일시정지한다(app.gd). 프로세스가 죽으면 판이 사라지지만 진행도 손상은 없다. (b) 일시정지할 때 시뮬레이션 상태 스냅샷을 저장한다. 상태가 크고 버전마다 직렬화 코드를 유지해야 한다. (c) **시드 + 명령 로그**를 저장하고 재시작 시 재연한다. 데이터가 작다(명령 수백 개). 같은 빌드·같은 기기에서 결정론이 성립해야 한다.
- 권장: (c)를 시험하고 실패하면 (a). 메인 세이브와 분리된 `user://run.json`에 쓰고 transact 대상에서 제외한다. 보상은 전투가 끝났을 때만 메인 세이브에 반영한다.
```json
{ "v": 1, "battle_uid": "b7c1e0f29a44d812", "round_id": "r04", "content_version": "c1-3fa9b2c01d4e",
  "app_version": "0.3.0", "seed": 1938475, "upgrades": { "up_melee_basic": 3 },
  "step": 5412, "cmds": [ [120, "deploy", "melee_basic"], [301, "worker"], [640, "hero_move", 1], [655, "skill", "skill_slam"] ],
  "state_hash": "sha256 of sim state at `step`" }
```
- 폐기 규칙: `content_version`, `app_version`, `upgrades` 중 하나라도 다르면 체크포인트를 버린다. 재연 후 `state_hash`가 다르면 버리고 오류 이벤트를 남긴다. 체크포인트는 보상을 만들지 않는다.
- 전제: 명령이 고정 스텝 사이에서 적용되어야 한다. `battle.gd`를 읽어 보면 `_on_deploy/_on_worker/_on_skill`이 `sim.deploy()` 등을 즉시 호출한다. 입력 처리는 `_process`의 스텝 루프 밖에서 일어나므로, 명령은 스텝과 스텝 사이에 적용된다. 영웅 이동 방향 `_ui_dir`은 스텝마다 읽힌다(추정). 따라서 `(스텝 번호, 명령)` 로그로 재연할 수 있을 것으로 본다. 다만 sim에 스텝 카운터와 상태 해시 함수가 필요하고, 실행으로 확인하지 않았다(02, R9).

## 6. 우리 게임 적용: 데이터 소유권과 단계
### 6.1 엔티티와 소유권
| 엔티티 | 저장 위치 | 쓰는 쪽 | 소유 문서 |
|---|---|---|---|
| 콘텐츠(유닛·라운드·스킬·경제·메타·텍스트) | `res://data/**` 읽기 전용 | 01 작성, 02 로드 | DATA_SCHEMA.md |
| 진행도·재화·업그레이드·튜토리얼·통계 | `user://save.json` | 02 `Save.transact` | INTERFACES §3 |
| 동의·광고 원장·구매 원장·권리 | 같은 세이브의 `services` | 06 경유 02 | SERVICES.md |
| 설정 | 같은 세이브 `settings` | 04 UI → 02 | INTERFACES §1.2 |
| 분석 큐 | 메모리 | 06 | ANALYTICS_EVENTS.md |
| 원격 설정·클라우드·서버 원장 | 없음(L1.5~L3) | — | 본 문서 §6.3 |

### 6.2 단계(L0~L5, 출처 ID S#와 별개)와 비용(금액은 공급자 요금표 확인 필요. 구매하지 않음)
| 단계 | 내용 | 고정 운영비 | 복잡도/정책 부담 | 막아주는 실패 |
|---|---|---|---|---|
| L0 MVP 오프라인 | JSON 콘텐츠 + 로컬 세이브 v2 + transact + 멱등 키 | 없음 | 낮음. 계정 삭제 정책 대상 아님(S14) | 중복·누락 지급, 손상, 마이그레이션 |
| L1 백업 | Android 자동 백업 명시 설정 | 없음 | 낮음. 복원 테스트 필요 | 재설치 유실 |
| L2 PGS 클라우드 세이브 | 저장된 게임 + 충돌 UI | 없음(Google 무료 명시) | 중간: 로그인, 플러그인, 충돌 UX, 데이터 안전 | 기기 변경 |
| L3 자체 백엔드 | 영수증 검증, RTDN/환불, SSV, 서버 원장 | 있음(호스팅·도메인·모니터링) | 높음: 개인정보, 계정 삭제 웹 경로, 장애 대응 | 결제 사기, 환불 악용 |
| L4 비동기 고스트 대전 | 스냅샷 교환 | L3 위에서 낮음 | 중간 | — (기능 추가) |
| L5 실시간 PvP/협동 | 매치메이킹 + 권위 서버 | 높음(동시 접속에 비례) | 매우 높음: 넷코드, 부정행위, 대기열 유동성 | — |
실제 결제(IAP)를 켜려면 L3이 사실상 필수다(06 PRODUCTION_REQUIREMENTS §2와 S6이 일치). 서버 없이 IAP를 켜는 것은 "클라이언트 검증, 변조 가능"으로 표시하고 사용자가 결정해야 한다(06 Option B).

### 6.3 선택 백엔드(L3) 최소 스키마 예 (PostgreSQL 문법, 설치하지 않음)
```sql
create table player (
  player_id uuid primary key,
  created_at timestamptz not null default now(),
  deleted_at timestamptz                       -- 계정 삭제 요청 처리(S14)
);
create table save_snapshot (
  player_id uuid references player,
  revision bigint not null,
  schema_version int not null,
  content_version text not null,
  payload jsonb not null,
  primary key (player_id, revision)
);
create table wallet (
  player_id uuid references player,
  currency_id text not null,
  balance bigint not null check (balance >= 0),
  primary key (player_id, currency_id)
);
create table ledger_entry (
  entry_id bigserial primary key,
  player_id uuid not null references player,
  idempotency_key text not null,               -- battle:/upg:/ad:<transaction_id>/iap:<token hash>
  currency_id text not null,
  delta bigint not null,
  reason text not null,
  created_at timestamptz not null default now(),
  unique (player_id, idempotency_key, currency_id)
);
create table purchase (
  purchase_token_sha256 bytea primary key,     -- 토큰은 전역 고유(S6). 원문 대신 해시 저장
  player_id uuid not null references player,
  product_id text not null,
  state text not null check (state in ('pending','purchased','granted','acknowledged','voided')),
  updated_at timestamptz not null default now()
);
create table entitlement (
  player_id uuid references player,
  entitlement_id text not null,
  source_token_sha256 bytea references purchase,
  revoked_at timestamptz,
  primary key (player_id, entitlement_id)
);
```
지급 트랜잭션(멱등):
```sql
begin;
insert into ledger_entry (player_id, idempotency_key, currency_id, delta, reason)
values ($1, $2, 'gold', $3, 'battle_reward')
on conflict (player_id, idempotency_key, currency_id) do nothing
returning entry_id;                  -- 행이 없으면 이미 처리됨 → 잔액을 바꾸지 않고 commit
update wallet set balance = balance + $3 where player_id = $1 and currency_id = 'gold';
commit;
```
`ON CONFLICT DO NOTHING`은 고유 제약 위반 대신 삽입을 건너뛴다(PostgreSQL 문서 S19). 세이브 업로드는 낙관적 동시성으로 처리한다: `insert ... revision = 기대값+1`이 기본키 충돌로 실패하면 → 충돌 UI(S12 권장).
대안 설계(동등하게 가능): 문서형 DB에서 플레이어당 문서 + 처리된 키 하위 컬렉션, 또는 키-값 저장소 + 조건부 쓰기. 경쟁사가 무엇을 쓰는지는 UNKNOWN이고, 이 선택의 핵심은 벤더가 아니라 **고유 키 + 원자적 조건부 쓰기**다.

### 6.4 세이브 위험(실행 증거 표시)
**v0.10 상태(HEAD 5426645, 02 08ef082 이후 실행 재검증):** SV-1 **해결 확인**(훅 기반 8/8, 에뮬레이션 A2/B 6). SV-2 해결(02 회신. 07 TP-06 PASS는 02가 SAVE_FAULTS.md에 보고했고 10은 재실행하지 않음). SV-3 **해결 확인**(162/1). 결과 화면의 "+코인" 표시 문제는 남아 있다(아래 프로브 2 v0.10). SV-4는 `record_result`만 롤백이 있고, 범용 transact는 없다. SV-5는 02 보고상 해결이고, 10은 재실행하지 않았다. 아래 표는 발견 당시 기록이다.
| ID | 관찰(파일·줄) | 영향 | 심각도(제안) | 수정 제안 | 수용 기준 |
|---|---|---|---|---|---|
| SV-1 | `save_progress()`는 기존 `.bak`을 지운 뒤 현재 main을 `.bak`으로 옮긴다. main이 손상되어 `.bak`에서 복구한 직후의 첫 저장은 **정상 `.bak`을 지우고 손상된 main을 `.bak`으로 만든다** | **실행 재현(v0.3, 아래 프로브):** 복구 후 저장 성공 → `.bak` 내용이 손상 파일 → main이 다시 손상되면 `unlocked_round` 6→1(`recovered=true`). 저장 중 종료를 흉내 내면 6→1이고 `recovered=false`라서 사용자에게 알림이 없다 | **P1: 07 QA-B004로 등록(OPEN, 02 담당)** | `recovered`이면 손상 main을 `save.json.corrupt-<n>`으로 격리하고 정상 `.bak`은 유지. 로드할 때 검증된 `.tmp`도 후보로 확인(07 QA-O002와 같은 개선) | TP-02: 프로브 시나리오 A2/B에서 `unlocked_round == 6` |
| SV-2 | `_migrate`는 `from_version`이 `VERSION`보다 커도 `p.version = VERSION`으로 덮어쓴다 | 07이 SAVE-08로 재현했다(QA-O003): v99 세이브를 읽은 뒤 v1로 다시 쓴다 | P2 | `from_version > VERSION`이면 읽기 전용 모드로 열고 원본 보존 | TP-06 |
| SV-3 | e9dfaa4부터 `battle_uid`가 결과에 실린다. 하지만 `App._on_battle_finished` → `Save.record_result` 경로는 이 값을 읽지 않고, 적용한 전투를 기록하지도 않는다 | **실행 재현(v0.6, 아래 프로브 2):** 같은 `battle_uid`의 결과가 두 번 들어오면 두 번 다 반영된다. 골드 162→204, clears 1→2. 디스크에도 같은 값이 남는다. 정상 플레이에서는 `battle.gd`의 `_ended_emitted` 가드가 같은 전투의 두 번째 `finished` 신호를 막는다. 따라서 현재 사용자 경로에서 중복이 일어나는 경우는 보이지 않았다. 위험해지는 경우는 결과를 다시 넣는 경로(광고 2배 보상, 전투 재개 재연, 신호 중복 연결)를 추가할 때다 | P2(현재 사용자 경로에서 재현되지 않으므로 P1 아님. 판정은 07) | Save가 `applied_battles`(최근 32개) 링 버퍼를 두고, uid가 있으면 `already_applied`로 무시한다 | TP-03: 프로브 2의 `duplicate_applied == false`, 골드 162, clears 1 |
| SV-4 | `record_result`가 저장 실패를 무시한다 | 메모리와 디스크 불일치. 다음 저장 때 해소된다 | P3 | transact 계약 | TP-04 |
| SV-5 | 타입 검증이 일부만 있다(`stars`, `best_time`이 Dictionary인지 확인하지 않음) | 07이 SAVE-05/06으로 재현했다(QA-B003): 다음 `record_result`가 스크립트 오류를 내고 결과가 저장되지 않는다 | P2(07 판정) | 필드별 타입 정규화 | TP-13 = 07 SAVE-05/06 |

**SV-1 프로브(연구 증거, 테스트 스위트 아님):** `docs/research/systems/probes/probe_save_rotation.gd`. 실행 명령: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_save_rotation.gd --quit-after 600`. `user://probe10/`만 쓰고, 끝난 뒤 그 폴더를 지웠다. 2026-10-31 실행 출력:
```
PROBE10_SAVE_ROTATION {"A_recovered":true,"A_unlocked_after_load":6,"A_save_ok":true,"A_bak_is_corrupt_after_save":true,
 "A2_unlocked_after_second_fault":1,"A2_recovered":true,
 "B_recovered":true,"B_unlocked_after_crash_reload":1,"B_recovered_after_crash_reload":false, ...}
```
- A/A2는 수정하지 않은 `save.gd` 코드 경로를 그대로 실행했다. B는 save.gd와 같은 순서의 파일 조작을 프로브가 직접 수행한 **에뮬레이션**이다. save.gd 내부에 장애를 주입한 것이 아니므로, 02의 장애 주입 훅(R6)으로 다시 확인해야 한다.
- 실행 중 `get_node() with absolute paths from outside the active scene tree` 오류가 한 번 출력됐다. `SceneTree._initialize` 시점에 `save_progress()`가 `/root/Events`를 찾으면서 생긴 프로브 환경 문제이고, 저장 결과(`A_save_ok=true`)에는 영향이 없었다.
- 다른 작업자의 Godot 헤드리스 프로세스가 동시에 돌고 있었다. 그 프로세스들은 건드리지 않았다. 처음 실행은 `_init` 사용 실수로 멈췄고, 그 프로브 프로세스 2개만 종료했다.

**v0.4 추적(2026-10-31 ~08:20 KST):**
- 07이 독립적으로 실행해 확인했다(`tests/acceptance/suite_faults.gd`, 커밋 f99094f, HEAD 462991a): TP-02 FAIL → **QA-B004 P1(02 담당)**. TP-01 PASS. TP-06 FAIL → QA-B006 P3(이전 QA-O003 대체). TP-13 클램프 FAIL → QA-B007 P3. TP-14 파일 보존은 PASS지만 사용자 알림이 없어 FAIL → QA-B005 P2. TP-03/04/05/11은 NOT_TESTED(battle_uid, 업그레이드 구매 API, data/migrations.json, restore 흐름이 런타임에 없음). 07도 장애 훅이 없어 kill 직후 파일 상태를 재구성하는 방식을 썼다. 따라서 10의 시나리오 B와 07의 TP-02b는 **같은 한계(코드 내부 장애 주입이 아님)** 를 공유한다.
- 06이 회신했다: TP-08 정책은 "둘 다 아니면 둘 다 없음"이다. 실제 save.gd와 자식 프로세스 OS.kill로 검증했다(데스크톱만, 게임에는 아직 연결되지 않음).
- 02의 **R6 장애 훅은 아직 없다.** HEAD 30a14bd의 `src/core/save.gd`에 `_fault` 등 훅이 없다. 커밋 이력상 save.gd의 마지막 커밋은 1eb4637이다. 작업 트리에는 02의 미커밋 변경(`fresh()`에 `tutorial_done: []` 추가) 1줄만 있다. 02는 10의 R1~R9에 회신하지 않았다. 02의 마지막 인수인계는 07:32 계정 전환 체크포인트이고, 그 커밋은 "Index is not empty"로 실패했다고 기록돼 있다.
- 그래서 시나리오 B를 훅으로 재실행하지 못했다. 대신 같은 프로브를 현재 작업 트리(30a14bd + 02의 미커밋 1줄)에서 다시 실행했다. 결과는 위 출력과 같다(A2 6→1, B 6→1, `recovered=false`). SV-1은 현재 코드에서도 그대로다.
- 01은 #5/#6에 회신하지 않았다(01 요청 파일과 docs/design에 관련 기록 없음). `data/migrations.json`도 없다.

**v0.5 추적(2026-10-31 ~08:40 KST, HEAD e9dfaa4):**
- 02가 e9dfaa4에서 `battle_uid`를 넣었다(`src/gameplay/battle.gd` `_make_battle_uid()`. BattleInfo와 BattleResult에 실린다). 이것은 R3의 **ID 부분**만이다. `Save`에는 `applied_battles` 같은 적용 기록이 없다. 그래서 같은 결과가 두 번 들어오면 두 번 반영된다. 이 판단은 코드 읽기에 근거하며 실행하지 않았다.
- 같은 커밋에서 save.gd는 `fresh()`에 `tutorial_done: []`가 추가된 1줄만 바뀌었다. 02 handoff(08:37)에는 "10 R1/R2/R6 save `.bak` quarantine, newer-version read-only, fault-injection hook — NOT done"이 다음 작업 2번으로 적혀 있다. **R6 훅은 아직 없다.**
- 프로브를 e9dfaa4에서 다시 실행했다: A2 6→1, B 6→1, `recovered=false`. SV-1(QA-B004)은 그대로다.

**프로브 2: battle_uid 중복 적용(SV-3/R3, v0.6, 2026-10-31 ~08:50 KST, HEAD e9dfaa4):** `docs/research/systems/probes/probe_battle_uid_dedup.gd`
- 실행 명령: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_battle_uid_dedup.gd --quit-after 900`
- 격리 방식: 07 수용 러너와 같다. 실제 autoload(App, Save, Content)를 쓰되, `_initialize`에서 Save autoload 경로를 `user://probe10/`로 돌린 뒤 실행한다. 실행 전후로 개발자의 실제 `save.json` SHA-256을 비교했다(F33DD39B…776A, 변화 없음). 끝난 뒤 `probe10` 폴더를 지웠다.
- 입력: r01 승리 결과 하나(3별, kill coins 12, `battle_uid: "probe10-dup-0001"`)를 같은 값으로 두 번 넣었다. r01 보상 데이터는 first_clear 100, 재클리어 30, 3별 보너스 50이다.

| 층 | 경로 | 멱등이라면 기대값 | 실제값 | 판정 |
|---|---|---|---|---|
| L1 | `Save.record_result(결과, 0)` × 2 (격리 인스턴스, 보상 100으로 확정된 결과) | 골드 100, clears 1 | 골드 100→**200**, clears 1→**2** | 중복 반영 |
| L2 | `App._on_battle_finished(같은 결과)` × 2 (실제 보상 계산 경로) | 골드 162(=12+100+50), clears 1 | 첫 번째 162(first_clear=true). 두 번째에 **204**(+42 = 재클리어 30 + kill 12, first_clear=false), clears **2** | 중복 반영 |
| L2 디스크 | 다시 읽은 세이브 | 162 / 1 | 204 / 2, `applied_battles` 키 없음 | 중복 영속 |
- 원시 출력(발췌): `"L2_app_on_battle_finished":{"after_first":{"clears":1,"coins":162,...},"after_duplicate":{"clears":2,"coins":204,...},"duplicate_applied":true,"expected_coins_if_idempotent":162}`, `"L2_persisted":{"clears":2,"coins":204,"has_applied_battles_key":false}`, `"save_gd_has_fault_hook":false`
- 한계: 프로브는 `_on_battle_finished`를 직접 두 번 호출했다. 실제 게임에서 두 번 호출되는 경로가 있다는 증거는 아니다. `battle.gd`의 `_ended_emitted`가 같은 Battle 인스턴스에서 두 번째 신호를 막는다(코드 읽기). 이 프로브가 보여주는 것은 **저장 계층에 멱등성 방어가 없다**는 사실이다. 그래서 보상 2배 광고(06 `ad_double_gold`), 전투 재개(R9), 결과 재전송 같은 경로를 추가하면 그 경로가 직접 중복을 막아야 한다.
- 같은 실행에서 R6 훅 존재 여부도 확인했다: `"_fault" in Save` = false. **시나리오 B의 훅 기반 재실행은 여전히 불가능하다.**

**v0.10 재검증: 02의 08ef082(세이브 수정 + R6 훅 + battle_uid 중복 방지) (2026-10-31 ~09:20 KST, HEAD 5426645)**
- 실행 조건: `src/core/save.gd`는 HEAD와 같다(`git diff --quiet` 확인). 작업 트리의 `app.gd`에는 02의 미커밋 변경(로그 출력 문구)만 있고, 저장 경로와는 관계가 없다. 실제 `save.json` 해시는 실행 전후 같았고(F33DD39B…), `user://probe10/`는 실행 후 지웠다.
- 02 회신(`02-engine-to-10-research-systems.md`): R1, R2, R4, R6 수락·구현. R3 부분(battle_uid 단위 멱등. 범용 `Save.transact`는 아직 없음). R5 부분. R7, R8 보류.

**(1) 시나리오 B, 훅 기반 재실행** — `probe_save_rotation.gd`에 시나리오 C를 추가했다(명령은 위 프로브 1과 같다). `Save._fault`를 장애 지점 4개(`after_tmp_write`, `torn_tmp`, `after_bak_rename`, `before_final_rename`)에 각각 걸고, 정상 세이브와 `.bak` 복구 직후 첫 저장 두 경우를 모두 돌렸다. `save_progress()`가 false를 반환하고, 새 Save 노드로 다시 읽는다.
| 장애 지점 / 상태 | 훅 발동(`fault_fired`) | 재로드 진행도(기대 6) | 재로드 `recovered` | 출처 |
|---|---|---|---|---|
| after_tmp_write / 정상 | O | 6 | false (정상 main) | main |
| after_tmp_write / 복구 후 | O | 6 | true | tmp |
| torn_tmp / 정상 | O | 6 | false (정상 main) | main |
| torn_tmp / 복구 후 | O | 6 | true | bak |
| after_bak_rename / 정상 | O | 6 | true | tmp |
| after_bak_rename / 복구 후 | O | 6 | true | tmp |
| **before_final_rename / 정상** | O | 6 | true | tmp |
| **before_final_rename / 복구 후** (원래 시나리오 B) | O | **6** (전 1) | **true** (전 false) | tmp |
- **8/8 통과**(`C_all_pass: true`). main이 정상이 아닌 곳에서 읽은 경우는 모두 `recovered=true`라서 조용한 초기화가 없다. 사용자 알림은 `app.gd` 73~74행에서 `Save.recovered`가 true일 때 `toast("save_recovered", {source})`를 띄운다. 이 부분은 코드 읽기이고, 화면 토스트를 실행으로 확인하지는 않았다.
- 예전 에뮬레이션 시나리오도 회귀 확인했다: A `.bak` 손상 false(전 true), A2 진행도 6(전 1), B 진행도 6 / recovered true(전 1 / false). 02가 SAVE_FAULTS.md에 적은 값과 같다.
- 관찰 2건, 결함 아님:
  - (a) 정상 세이브에서 `after_bak_rename`/`before_final_rename`으로 끊기면 진행도 손실이 없는데도 다음 실행에서 `recovered=true`가 되어 "복구됨" 토스트가 뜬다. 정직한 표시지만 잦으면 잡음이 된다.
  - (b) 격리 파일 `.corrupt-*`가 이 프로브 한 번에 10개 생겼고, 지워지지 않는다. 02도 "not yet pruned"로 적었다. 손상이 반복되는 기기에서는 파일이 계속 쌓인다. P3, 02 판단.

**v0.12 재확인(2026-10-31 ~15:52 KST):** `src/core/save.gd`는 08ef082 이후 바뀌지 않았다.
- `probe_save_rotation`: HEAD abe2303 작업 트리에서 실행했다(save.gd는 HEAD와 같음). 결과는 C 8/8 PASS, A2 6, B 6 / recovered true. 장애 지점 4개 모두에서 진행도가 유지되고 복구 알림 조건(`recovered=true`)이 성립했다. 격리 파일은 7개 생겼다.
- `probe_battle_uid_dedup`: 처음에 작업 트리에서 돌렸더니 `SCRIPT ERROR: Nonexistent function '_on_battle_finished' in base 'Node (app.gd)'`가 나왔다. 원인은 02의 **미커밋 `src/core/app.gd`**다. 줄바꿈이 전부 사라져 10,974바이트가 한 줄(LF 0, CR 0)이 됐고, mtime은 15:46:10이었다. GDScript가 파싱하지 못한다. HEAD의 app.gd는 정상이다(287줄). 그래서 **전체 HEAD 8c8635f를 `git archive`로 풀어 프로젝트 이름을 바꾼 스냅샷**에서 다시 실행했다. 결과는 L1 100/1, L2 **162/1**, 디스크 162/1, `duplicate_applied:false`로 **합격**이다. 실제 save.json 해시는 실행 전후 같았고, 스냅샷은 지웠다.

**(2) battle_uid 중복 반영, 합격 기준 162/1 (v0.10 기록)** — `probe_battle_uid_dedup.gd`를 그대로 다시 실행했다.
| 층 | 기대값 | 08ef082 이전(a19289b 기록) | 08ef082 이후 |
|---|---|---|---|
| L1 `Save.record_result` × 2 | 100 / 1 | 200 / 2 | **100 / 1** |
| L2 `App._on_battle_finished` × 2 | 162 / 1 | 204 / 2 | **162 / 1** (두 번째 결과는 `duplicate:true, saved:false`) |
| L2 디스크 | 162 / 1 | 204 / 2 | **162 / 1**, `applied_battles` 있음 |
- **합격.** `duplicate_applied:false`가 두 층 모두에서 나왔다.
- 남은 표시 문제(코드 읽기, P3): 거부된 중복 결과도 `coins: 42`를 그대로 담고 있다. 그런데 `src/ui/result.gd` 89행은 `"+%d" % result.coins`를 `duplicate`/`saved`와 관계없이 표시한다. 그래서 중복이 화면까지 가면 지급되지 않은 "+42"가 보인다. 쓰기 실패(`saved:false`, 롤백됨)일 때도 같다. 정상 플레이에서는 `_ended_emitted`가 중복을 막으므로 지금 사용자 경로는 없다. 수정 방향은 App이 중복·실패 때 `coins_granted: 0`을 따로 싣거나 UI가 `saved`를 확인하는 것이다. 담당 02/04.

## 7. 위협/실패 사례와 실행 테스트 제안 (07 acceptance, 06 services, 02 훅)
실행 방식: Godot 헤드리스 `--headless -s res://tests/acceptance/<file>.gd`. 02가 `Save.path` 주입(이미 var)과 쓰기 단계별 장애 주입 훅(`Save._fault = "after_bak_rename"` 등, 디버그 빌드 전용)을 제공해야 한다.
| TP | 시나리오 | 절차 | 기대 결과(판정 기준) | 소유 |
|---|---|---|---|---|
| TP-01 | 쓰기 도중 종료 | 각 장애 지점(tmp 쓰기 후, bak rename 후, 최종 rename 전)에서 중단 → 재로드 | 직전 커밋 상태 또는 새 상태 중 하나. 절대 fresh가 아님 | 07 (훅 02) |
| TP-02 | SV-1 이중 장애 | main을 손상 → 로드(.bak 복구) → 저장 중 "after_bak_rename"에서 중단 → 재로드 | 복구된 진행도 유지. 현재 코드에서는 실패 예상 | 07 → 02 |
| TP-03 | 결과 중복 | 같은 결과(같은 battle_uid)를 2회 적용 | 골드·클리어 수 1회만 증가 | 07 |
| TP-04 | 업그레이드 + 저장 실패 | 쓰기 불가 경로에서 구매 | 메모리 골드·레벨 변화 없음, `save_failed` | 07 |
| TP-05 | 콘텐츠 변경 마이그레이션 | 세이브에 없는 ID, max_level 축소, 이름 변경 | 알 수 없는 ID 보존, 레벨 클램프 + 정확한 환불, 크래시 없음 | 07 (규칙 01/02) |
| TP-06 | 상위 버전 세이브 | `version: 99` 세이브 로드 후 저장 시도 | 원본 바이트 그대로 유지 | 07 |
| TP-07 | 시계 조작 | 06 `service_clock` 모의로 날짜 ±1일, 과거로 | 일일 상한 재설정은 문서화된 허용 동작. 음수 경과 시간 0 | 06 |
| TP-08 | 광고 보상 직후 프로세스 종료 | mock 광고 `reward_earned` → `store.commit()` 전에 종료 → 재시작 | 정책 둘 중 하나로 고정하고 테스트: (a) 지급+원장이 함께 영속, (b) 둘 다 없음. 한쪽만 있으면 실패 | 06 |
| TP-09 | 앱 종료 중 구매 완료 | mock billing: 구매 완료 후 재시작, 미처리 구매 조회 | 1회 지급, 1회 확인(ack) | 06 (실기기는 04/07) |
| TP-10 | 환불 | restore에서 권리가 사라짐 | 권리 회수, 오프라인 조회 실패 시 유지 | 06(기존 테스트 확인) |
| TP-11 | 과거 세이브 복원 | 하루 전 세이브 + 이후 비소모성 구매 → restore | 권리 재구성, 크래시 없음 | 07 (실기기 bmgr는 04) |
| TP-12 | 결정론 | 같은 시드·입력 로그로 Windows와 Android에서 sim 실행 → 상태 해시 | 같으면 고스트/락스텝 후보 유지, 다르면 (C) 기각 | 02/08 |
| TP-13 | 변조·이상 세이브 | gold=9,999,999,999, stars="x", 깊은 중첩, 50MB 파일 | 클램프·정규화, 크래시 없음, 로드 시간 한도(08이 정함) | 07 |
| TP-14 | 저장 공간 부족 | 쓰기 실패 모의 | 직전 정상 파일 유지, 토스트 | 07 |
| TP-15 | 전투 중 프로세스 종료 후 재개 | run.json 기록 → 프로세스 종료 → 재시작 → 재연 | `state_hash` 일치 시 같은 판 재개, 불일치·버전 차이 시 폐기하고 메인 세이브 불변 | 02 (실기기 04/07) |

## 8. 성공 가설과 가장 강한 거절 이유 (hostile review)
| 가설 | 거절 이유(가장 강한 것) | 최소 검증 | 미리 정한 판정 |
|---|---|---|---|
| HS-1 계정 없는 오프라인 출시가 충분하다 | 경쟁작은 모두 사용자 ID·계정을 신고했다. 기기를 바꿀 때 진행도를 잃으면 이탈한다 | 자동 백업 복원 실기기 시험(TP-11) + 비공개 테스트 문의 기록 | 복원이 작동하면 L2 연기. 작동하지 않으면 L2를 출시 조건으로 올림(01 결정) |
| HS-2 transact + 멱등 키로 중복·누락 지급을 막는다 | 문서만으로는 결함이 닫히지 않는다 | TP-01~04 실행 | 하나라도 실패하면 출시 차단(P1) |
| HS-3 서버 LiveOps 없이 앱 업데이트 기반 이벤트로 충분하다 | 경쟁작은 시즌·이벤트를 상시 운영한다. 업데이트 심사 지연 때문에 이벤트 속도가 느리다 | 데이터 전용 이벤트 1개를 만들어 빌드부터 배포까지 소요 시간 측정(04) | 측정값이 01의 이벤트 주기보다 길면 L1.5(서명 JSON) 검토 |
| HS-4 PvP 없이 출시한다 | PvP가 랜덤다이스의 정체성과 바이럴이었다 | 비공개 테스트에서 PvP 요청 빈도 관찰 | 정성 신호뿐이다. 비율 주장 금지(D11) |
| 전체 | 이 문서의 분석은 성공을 만들지 못한다. 경쟁작 성공의 주원인은 마케팅·포트폴리오·네트워크 효과일 수 있다 | — | 수용한다. 이 문서의 목적은 실패 방지다. 백엔드를 모방하는 것은 화물 숭배(cargo cult)다 |

## 9. 우선순위 요청 (실제 요청 파일: coordination/requests/10-research-systems-to-*.md)
1. 02: **SV-1 격리 복구(실행 재현됨, P1 후보)**, transact 계약, battle_uid, 세이브 v2 필드, SV-2(=QA-O003)/SV-5(=QA-B003), 장애 주입 훅, R9 전투 체크포인트(선택).
2. 07: SV-1 수용 케이스 추가(장애 훅 없이 가능), TP-01~06, 11, 13, 14.
3. 06: TP-08 정책 확정, `save_recovered`/`ftue_step` 이벤트 검토, 리텐션 측정 불가에 대한 01 결정 요청.
4. 04: `user_data_backup/allow` 명시와 실기기 백업/복원 시험, 데이터 안전 답변 초안에 반영.
5. 01: `data/migrations.json` 규칙, 오프라인 보상 비활성 유지, PvP 비MVP 유지(모두 기본값이며 사용자 승인 아님). 사용자 질문은 Q1 이후 01만.

## 9.1 콘텐츠 테이블 관점 매핑 (v0.2 추가, 현재 data/** 기준)
JSON 파일을 관계형 테이블로 보면 무결성 규칙이 명확해진다. 실제 DB로 바꾸자는 제안이 아니다.
| 논리 테이블 | 파일 | 기본키 | 외래키(참조) | 버전·변경 규칙 |
|---|---|---|---|---|
| unit | data/units/units.json `units[]` | `id` | `projectile` → fx anim, `summon.unit` → unit | ID 영구. 수치는 자유롭게 변경 가능(세이브는 ID만 저장) |
| hero | data/heroes/*.json | `id` | `skills[]` → skill | 동일 |
| skill | data/skills/*.json | `id` | `fx` → anim | 동일 |
| round | data/rounds/rNN.json | `id` | `cards[]`/`waves[].spawns[].unit`/`trickle.pattern[]` → unit, `skills[]` → skill, `hero` → hero | `order.json`이 진행 순서. 순서 변경은 `unlocked_round`(인덱스 저장) 의미를 바꾼다 → 마이그레이션 필요 |
| upgrade | data/meta.json `upgrades[]` | `id` | `target` → unit/hero/resource | `max_level` 축소 시 클램프 + 환불(§5.1 migrations) |
| currency | data/meta.json `currencies[]` | `id` | — | `max` 클램프 |
| text | data/text/<locale>.json | key | `name_key`/`desc_key`에서 참조 | 01의 ko/en parity 검사 |
실행한 검증(읽기 전용 PowerShell, 2026-10-31 07:30): 유닛 12개 ID 중복 0, 영웅 스킬 참조 누락 0, r01~r10의 cards/waves/skills/trickle 참조 오류 0, upgrades의 `costs` 길이 = `max_level−1` 위반 0, `unit:` 대상 누락 0. 이 검사는 참조 무결성만 증명한다. 밸런스나 재미는 증명하지 않는다.
관찰된 설계 위험 [I]: 세이브의 `unlocked_round`가 **순서 인덱스**라서, 라운드를 중간에 끼워 넣으면 이미 깬 라운드가 잠기거나 안 깬 라운드가 열릴 수 있다. v2에서는 진행도를 `rounds{id:{clears}}`에서 파생하는 쪽을 권한다(02/01 결정).

### 9.2 콘텐츠 DB 참조 무결성 프로브 (v0.7, 실행 증거)
v0.2의 PowerShell 검사(§9.1)는 일회성이었다. 이번에는 다시 실행할 수 있는 Godot 프로브로 바꾸고, 아트 매니페스트와 아이콘까지 범위를 넓혔다.
- 파일: `docs/research/systems/probes/probe_content_integrity.gd` (`res://` 파일만 읽고 아무것도 쓰지 않는다. ERROR가 있으면 exit 1이라서 그대로 테스트로 쓸 수 있다)
- 실행 명령: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_content_integrity.gd --quit-after 600`
- 검사 항목: 중복 ID(유닛·스킬·영웅·라운드·업그레이드), ID와 파일명 일치, 유닛·스킬·영웅·바이옴·애니메이션 세트·투사체·fx 참조, **엔진이 만드는 아이콘 이름**(`battle_sim.gd`의 `card_<unit_id>`, `skill_<skill_id>`을 `assets/atlases/ui_main.json`에서 확인), 진영(카드는 아군만, 웨이브는 적만), unlock_round, 수치 범위(522개 항목), 웨이브 시각 순서, `order.json`과 `index` 일치, 업그레이드 대상·비용(양수, 감소하지 않음), economy와 game_config 미러 값, caps와 엔진 상한(INTERFACES §2.7의 40/40/64/48/24), 텍스트 참조와 ko/en 키·자리표시자 일치, `schema_version` 존재 여부.

**HEAD 실행 (f88ce03c7c19b14ac2bd3dcd260d1b9eb7cdca4c, 2026-10-31 ~08:55 KST):** 작업 트리에 01(라운드 10개)과 03(manifest, ui_main.json)의 미커밋 변경이 있었다. 그래서 `git archive HEAD`로 data/·assets/manifest.json·assets/atlases/*.json·project.godot만 임시 폴더에 풀었다. 프로젝트 이름을 바꾸고 autoload 섹션을 지운 상태로 실행해, 게임 부팅과 실제 세이브 접근이 없게 했다. 실행 후 임시 폴더는 지웠다.
| 심각도 | 검사 | 담당 | 내용 |
|---|---|---|---|
| **ERROR** | ANIM_REF | 03 | `boss_overlord.anim_set 'boss_overlord'`가 HEAD의 `assets/manifest.json` anim_sets에 없다. r10.json 61행이 이 보스를 소환한다. 따라서 마지막 라운드 보스가 대체 그래픽으로 나온다(대체 경로는 atlas.gd에서 코드로 읽음. 화면은 확인하지 않음) |
| INFO | VERSION | 01 | data 파일 21개 중 15개(order.json, skills 3개, heroes 1개, rounds 10개)에 `schema_version`이 없다. DATA_SCHEMA는 요구하지 않으므로 결함이 아닌 제안이다. 전역 `game_config.data_version`은 있다 |
- 요약: `{"counts":{"ERROR":1,"INFO":1,"WARN":0}, "tables":{"units":12,"skills":3,"heroes":1,"rounds":10,"order":10,"text_ko":116,"text_en":116,"anim_sets":32,"ui_frames":103}}`, exit 1.
- **작업 트리 실행(같은 시각, 01/03 미커밋 변경 포함):** ERROR 0, INFO 1, exit 0. 작업 트리 manifest에는 boss_overlord가 있다(anim_sets 33개). 03 handoff(08:47)도 "boss_overlord art is missing"을 다음 작업 1번으로 적고 있다. 따라서 이 ERROR는 03이 커밋하면 닫힐 가능성이 높다. 판정은 커밋 후 HEAD에서 다시 실행해서 한다.

**프로브 자체 검증(변이 시험):** HEAD 스냅샷을 복사한 뒤 결함 10종을 일부러 넣었다. 유닛 ID 중복, hp=-5, 존재하지 않는 카드 `ghost_unit`, 웨이브 at=9999(범위 초과와 순서 역전), 없는 튜토리얼 키, base_hp_2=1.7, r03 index=7, 없는 스킬, 업그레이드 대상 `unit:nobody`, ui_main의 `card_tank` 제거, en 키 1개 제거. 10종 모두 ERROR로 잡혔고(16줄) exit 1이었다. 프로브가 항상 통과하는 빈 검사가 아니라는 근거다. 변이 폴더도 지웠다.

**기존 검사와의 관계(중복을 피하기 위해 확인):**
- 07 `tests/acceptance/suite_data.gd` DATA-01~14가 이미 다루는 것: order 존재, 도달 가능성, 유닛·영웅·스킬 교차 참조와 진영, P0 라운드 수치, 유닛 스탯 부호, 텍스트 키 ko/en, 자리표시자, src의 ui/toast 키.
- 03 `tools/art/validate.py` `check_data_refs`가 따라가는 것은 키 이름이 `sprite`/`vfx`/`fx`/`icon`인 값뿐이다. `anim_set`, `projectile`과 엔진이 만드는 `card_<id>`/`skill_<id>`는 보지 않는다. 그래서 03 검증이 "data refs PASS"를 보고하는 동안에도 boss_overlord 누락이 남아 있었다.
- 이 프로브만 추가로 잡는 것: ANIM_REF(anim_set, projectile), BIOME_REF, ICON_REF, 업그레이드 대상·비용, MIRROR, caps 상한, index↔order 위치, 웨이브 순서, summon 참조, unlock_round, schema_version. 07/02에는 이 차이만 넣자고 제안한다.

**v0.9 재실행: 테마 A 확정 이후(2026-10-31 ~09:10 KST, HEAD 9ca4a43d2e7ff70a9f0002e0f4812131548cdd95)**
- 사용자 결정: 코디네이터가 09:03에 Q1 = A안 "빵집 기사단 vs 곰팡이 군단"으로 확정했다고 `coordinator-to-01-director.md`에 기록했다. 다만 HEAD의 `docs/design/DECISIONS.md`에는 Q1이 아직 PENDING이다. 기록하는 일은 01 소관이라 10은 고치지 않았다.
- **테마 이름표는 HEAD에 아직 반영되지 않았다.** `data/text/*.json`의 마지막 커밋은 67bf9ca(D13 영문 축약)이다. 표시 이름은 여전히 중립 이름(보병/Troop, 궁수/Archer, 방패병/Shield, 졸병/Grunt 등)이다. 01의 작업 트리에는 units/heroes/skills/rounds의 미커밋 변경이 있지만 text 파일은 바뀌지 않았다. 따라서 "테마 변경으로 생긴 누락·중복" 검사는 **아직 할 대상이 없다.** 대신 반영 전 기준선을 고정했다.
- 결과: **ERROR 0, WARN 0, INFO 1**(schema_version 15/21), exit 0. **v0.7의 ERROR(boss_overlord anim_set)는 03의 393ada2로 닫혔다**(HEAD manifest anim_sets 32→33).
- 테마 변경에 대비해 검사 2종을 추가했다. 모두 WARN이고, 변이 시험으로 확인했다. 시험 방법은 ko/en에서 tank 이름을 melee와 같은 값으로 바꾸는 것이었고, DUP_NAME 2건과 STALE_NAME 1건이 잡혔다.
  - **DUP_NAME:** 같은 종류(유닛/영웅/스킬/라운드) 안에서 서로 다른 ID가 같은 표시 이름을 쓰는 경우. 플레이어가 둘을 구별할 수 없다.
  - **STALE_NAME:** 데이터의 `name` 대체값이 `name_key`의 ko 텍스트와 다른 경우. 이름표만 바꾸고 대체값을 남겨 두면, 텍스트 로드가 실패했을 때 옛 이름이 보인다.
  - 기준선 `CI NAMES` 출력(26개 ID의 ko/en/대체값)을 이 프로브가 매번 출력한다. 01이 이름표를 커밋하면 같은 명령의 출력과 비교해 바뀐 이름, 누락, 중복을 확인한다.
- HEAD 기준 이름 중 종류를 넘어 같은 것: r05 라운드와 boss_warlord가 둘 다 "군단장"/"(The) Warlord", r10과 boss_overlord가 둘 다 "대군주"/"(The) Overlord"다. 라운드가 보스 이름을 따른 것이라 의도로 보이고, DUP_NAME 대상(같은 종류 안)이 아니다.

**v0.11 재실행(재시작 후, 2026-10-31 ~15:40 KST, HEAD 2884231dcbe69be00e5716537b2aefd1f7b03a32):**
- 결과: **ERROR 0, WARN 0, INFO 0**, exit 0. 깨끗한 `git archive` 스냅샷에서 autoload 없이 실행했고, 실행 후 지웠다. v0.9의 INFO(`schema_version` 15/21 누락)는 01의 **D17**(cbfb0a8, 모든 data 파일에 `"schema_version": 1`)로 닫혔다.
- 이름 비교: v0.9 기준선(9ca4a43)과 HEAD 사이에 유닛·영웅·스킬·라운드 표시 이름(ko/en `*.name` 키)과 units.json의 `name`/`name_key` 변경은 **0건**이다. 그 사이 data/text 변경은 cbfb0a8의 `toast.counterattack` 키 추가 1건뿐이다. 즉 **테마 A 이름표는 HEAD에 아직 없다.** 표시 이름은 여전히 보병/대장/첫 경계 같은 중립 이름이다. 테마로 인한 누락·중복 검사는 이름표가 커밋된 뒤에 한다.
- HEAD의 `docs/design/DECISIONS.md`에는 Q1이 아직 PENDING이다. 사용자 결정(A안, 코디네이터 기록 09:03)을 반영하는 일은 01 소관이다.

**v0.12 테마 A 이름표 검사(2026-10-31 ~15:55 KST):** 01이 14b01e2(text)와 5930430(data `name` 대체값 동기화)을 커밋했고, Q1은 DECIDED로 기록됐다(D20~D22 포함).
| HEAD | 대상 | ERROR | WARN | INFO | 비고 |
|---|---|---|---|---|---|
| abe2303 | 14b01e2 이후, 5930430 이전 | 0 | **26** | 0 | 26건 모두 STALE_NAME(유닛 12·영웅 1·스킬 3·라운드 10): 데이터 `name`이 옛 이름(보병, 대장, 첫 경계 …)으로 남아 있었다 |
| 43b4692e6f1bb91b22e6e697f90cbdd342692e97 | 5930430 이후 | 0 | **0** | 0 | 대체값 동기화로 STALE_NAME 26→0. 01도 커밋 전에 같은 결과를 보고했다 |
- 실행 방식은 전과 같다(깨끗한 `git archive` 스냅샷, autoload 없음, 실행 후 삭제). 누락 키: TEXT_REF 122건, TEXT_PARITY 122키(ko/en 같음), 누락 0. DUP_NAME 52건 검사에서 중복 0.
- STALE_NAME이 실제로 화면에 영향을 주는 경로(코드 읽기): 04의 UI는 `UiText.name_of(kind, id, fallback)`로 `<kind>.<id>.name` 키를 먼저 찾는다. 하지만 02의 대체 UI(`fallback_hud.gd`, `fallback_ui.gd`)는 데이터 `name`을 그대로 쓴다. `battle_info.hero`에는 `name_key`가 없고 `name`만 실린다. 따라서 abe2303 시점에 04 장면이 로드되지 않으면 옛 이름이 보였을 것이다. 지금은 동기화로 해소됐다.

v0.9 기준선(9ca4a43) → HEAD 43b4692 이름 변화(ko / en, 대체값 = ko):
| id | 전 | 후 |
|---|---|---|
| melee_basic | 보병 / Troop | 식빵병 / Toast |
| ranged_basic | 궁수 / Archer | 롤빵병 / Roll |
| tank | 방패병 / Shield | 통식빵 / Loaf |
| fast | 돌격병 / Raider | 프레첼 / Twist |
| siege | 투석기 / Siege | 화덕포 / Oven |
| hero_captain | 대장 / Captain | 제빵 대장 / Head Baker |
| e_grunt | 졸병 / Grunt | 곰팡이 졸개 / Mold Mite |
| e_swarm | 떼거리 / Swarmling | 초파리 떼 / Fruit Flies |
| e_spitter | 투척병 / Spitter | 포자 뱉개 / Spore Spitter |
| e_brute | 거한 / Brute | 썩은 멧돼지 / Rot Boar |
| e_bomber | 자폭병 / Bomber | 부푼 효모 / Yeast Puff |
| boss_warlord | 군단장 / Warlord | 곰팡이 장군 / Mold General |
| boss_overlord | 대군주 / Overlord | 부패 대군주 / Rot Overlord |
| skill_slam | 내려찍기 / Slam | 밀대 내려찍기 / Slam |
| skill_rally | 돌격 함성 / Rally | 갓 구운 함성 / Rally |
| skill_barrage | 일제 포격 / Barrage | 빵가루 포격 / Barrage |
| r01…r10 | 첫 경계 … 대군주 | 첫 번째 반죽 / First Batch, 초파리의 습격 / Fruit Fly Raid, 포자가 날아온다 / Spores Incoming, 썩은 발굽 소리 / Rotten Hooves, 곰팡이 장군 / The Mold General, 곰팡이 성벽을 부숴라 / Break the Mold Wall, 부풀어 터지는 효모 / Rising Yeast, 끝없는 초파리 / Endless Flies, 곰팡이 총공세 / Mold Onslaught, 부패 대군주 / The Rot Overlord |
- 26개 ID 모두 ko 이름이 바뀌었다. en은 스킬 3개(Slam/Rally/Barrage)만 그대로다.
- 종류를 넘어 같은 이름은 전과 같은 두 쌍이다: r05 = boss_warlord("곰팡이 장군", en은 "The Mold General" / "Mold General"), r10 = boss_overlord("부패 대군주"). 보스 라운드가 보스 이름을 따른 것이다. 혼동되는지는 화면 문맥에 달렸다. 이 프로브로는 판정하지 않는다.
- 이 검사는 키·대체값·중복만 본다. 글자 수가 카드 칸(36.67 px)에 맞는지(D20)는 04/07의 렌더링 검사 영역이다.

### 9.3 메타 코인 경제 흐름 프로브 (v0.8, 데이터 계산만)
- 파일: `docs/research/systems/probes/probe_economy_flow.gd` (읽기 전용, 시뮬레이션 없음)
- 실행 명령: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_economy_flow.gd --quit-after 600`
- 실행 대상: HEAD 07e97ca9af74003adead1ff018fcc7175e5fcdb6. data/·upgrade_budgets.json·project.godot만 `git archive`로 풀어서, autoload를 빼고 실행했다. 01의 작업 트리에 미커밋 라운드 변경이 있어서 비교했는데, 보상 블록 10개와 스크립트 스폰(waves, hp 트리거)이 모두 HEAD와 같았다. 그래서 아래 숫자는 작업 트리에도 그대로 적용된다. meta/units/economy는 변경이 없었다.
- **출처 표기:** [DATA]는 data/** 값 또는 그 산술이다. [RULE]은 `app.gd _on_battle_finished`의 보상 규칙이다(첫 클리어는 coins 대신 first_clear_coins, 3별 보너스는 처음 한 번, 승리 시 kill_coins 가산). [ASSUME]은 이 프로브가 정한 가정이다. [INTENT]는 ECONOMY.md 본문의 설계 의도다. **플레이 시간, 승률, 유지율은 계산하지 않았다.**

**(1) 라운드별 수입 [DATA/RULE], 처치 코인은 [ASSUME]**
| 라운드 | 첫 클리어 | 재클리어 | 3별 보너스 | 스크립트 스폰 처치 코인 상한 [ASSUME] | 누적 첫 클리어 | 누적 첫 클리어+3별 |
|---|---|---|---|---|---|---|
| r01 | 100 | 30 | 50 | 12 | 100 | 150 |
| r02 | 140 | 42 | 50 | 14 | 240 | 340 |
| r03 | 180 | 54 | 60 | 24 | 420 | 580 |
| r04 | 220 | 66 | 60 | 32 | 640 | 860 |
| r05 | 300 | 90 | 80 | 57 | 940 | 1,240 |
| r06 | 340 | 102 | 80 | 46 | 1,280 | 1,660 |
| r07 | 380 | 114 | 90 | 37 | 1,660 | 2,130 |
| r08 | 420 | 126 | 90 | 37 | 2,080 | 2,640 |
| r09 | 460 | 138 | 100 | 67 | 2,540 | 3,200 |
| r10 | 600 | 180 | 120 | 138 | 3,140 | 3,920 |
- 재클리어 보상은 모든 라운드에서 첫 클리어의 정확히 30.0%다 [DATA]. ECONOMY.md의 "replay wins 30%"와 일치한다.
- 처치 코인 상한의 가정: waves와 enemy_base_spawns_on_hp의 스폰을 전부 한 번씩 처치한다고 봤다. trickle과 보스 소환은 시간에 따라 달라서 뺐다. 따라서 이 값은 실제 처치 코인의 최솟값도 최댓값도 아니다. ECONOMY.md는 "kill gold ≈ 20–60 per round"라고 쓰는데, 스크립트 부분만 봐도 r01 12, r10 138로 그 범위를 벗어난다. r10은 boss_overlord 60 때문이다.

**(2) 지출 [DATA]:** 업그레이드 10트랙 합계 **6,280**. 트랙 합계: melee 570, ranged 570, tank 645, fast 645, siege 820, hero 710, supply 660, energy 660, worker 480(최대 L4), base_hp 520. 마지막 단계(L5, worker는 L4) 비용 합은 2,740이다.

**(3) 전부 최대 레벨로 올리기 [DATA, 처치 포함 행만 ASSUME]**
| 시나리오 | r01~r10 수입 | 지출 대비 | 부족분 | r10 재클리어 횟수(재클리어 코인만) | r10 재클리어 횟수(+스크립트 처치) |
|---|---|---|---|---|---|
| LOW 첫 클리어만 | 3,140 | 50.0% | 3,140 | 18 | 10 |
| HIGH 첫 클리어+3별 | 3,920 | 62.4% | 2,360 | 14 | 8 |
| HIGH+스크립트 처치 상한 | 4,384 | 69.8% | 1,896 | 11 | 6 |

**(4) 01 budgets 재현과 비교:** 01의 정책 문구("before each round, greedily buy the cheapest affordable unlocked upgrade, ties: meta.json order")를 그대로 구현했다. 가시성은 [ASSUME]으로, 유닛 트랙은 unlock_round ≤ k, energy는 스킬 해금 이후, 나머지는 항상 보이는 것으로 봤다. **결과는 `upgrade_budgets.json`의 LOW/HIGH 20개 항목(10라운드 × 2)과 levels·spent_levels·leftover가 전부 일치했다(diff 0).** 그러므로 01 파일의 계산 자체는 현재 데이터에서 재현된다. 차이는 01 파일이 다루지 않는 범위에 있다.
- 01 파일은 처치 코인을 0으로 둔다. 스크립트 처치 상한을 더하면 r10 직전 상태가 HIGH 27레벨/잔액 90에서 28레벨/잔액 216으로 바뀐다(up_hero 3→4).
- greedy는 r10 직전까지 **어떤 트랙도 L5에 도달하지 못한다**(LOW 최대 L4, 23레벨 / HIGH 27레벨). L5 단계 2,740은 첫 클리어 경로에서는 사실상 재플레이 전용 구간이다.

**(5) 재플레이를 강요하는 지점(설계 의도 기준) [INTENT vs DATA]**
| 시점 | 의도 지출(ECONOMY.md) | LOW 수입 | HIGH 수입 | LOW 부족분 → 필요한 재클리어 | HIGH |
|---|---|---|---|---|---|
| r03 전 | 240 | 240 | 340 | 0 → 0회 | +100 초과 |
| r05 전 | 660 | 640 | 860 | **20 → r04 재클리어 1회(66)** | +200 초과 |
| r10 전 | 2,500 | 2,540 | 3,200 | 없음(+40) | +700 초과 |
- 의도 기준으로 강제 재플레이가 생기는 지점은 **r05 직전 LOW(3별 없이 진행)에서 1회**뿐이다. 3별을 받는 플레이어는 세 시점 모두 의도보다 100~700 많이 번다.
- 재플레이가 정말 강제되는지는 이 표로 알 수 없다. 그것은 "그 업그레이드 없이 다음 라운드를 이길 수 있는가"에 달려 있고, 01의 시뮬레이션(paired_sim/confirm_sim) 영역이다. 이 프로브는 승패를 계산하지 않는다.

**(6) 돈이 남아도는 지점 [DATA + ASSUME 처치 상한]:** 각 라운드 직전에 그때 보이는 업그레이드의 남은 총비용과 누적 수입 상한(HIGH+처치)을 비교했다. **r01~r10 어디에서도 수입이 남은 비용을 넘지 않는다**(예: r10 직전 수입 3,526, 남은 비용 6,280). 첫 클리어 경로에서는 지출처가 없어 돈이 쌓이는 구간이 없다. 잉여는 모든 트랙을 최대로 만든 뒤, 즉 r10 재클리어 약 11~18회 이후에만 생긴다. 그 뒤에는 코인 지출처가 0이고 상한 9,999,999까지 쌓이기만 한다(meta.json currencies.max). 챕터 2나 다른 지출처가 없으면 그 이후의 재플레이 보상은 의미가 없어진다.
- 남은 비용이 크게 뛰는 시점: r06에서 siege 트랙(820)이 보이면서 5,460→6,280이 된다.

**01 결정 D22(v0.12에 반영):** (a) 의도 기준값을 r05 전 660→**640**으로 낮췄다. 그래서 LOW 경로의 부족분 20과 r04 재클리어 1회가 사라진다. 계산상 LOW 640 = 의도 640. (b) L5는 의도된 재플레이 전용 숙련 구간이고, 챕터 1은 LOW 예산으로 깰 수 있어야 한다(01 시뮬레이션 A4 대기). (c) MVP에는 최대 레벨 이후 지출처가 없고, 코인은 상한까지 쌓인다(B29 백로그). 10은 이 결정을 다시 계산하지 않았다. 5930430의 `ECONOMY.md` 변경을 데이터로 다시 확인하는 일은 이 프로브를 HEAD에서 재실행하면 된다.

**(7) 레벨 하나를 사려면 재클리어가 몇 번 필요한가 [DATA]:** 잔액 0에서 시작해 그 트랙이 처음 보이는 라운드만 반복할 때의 값이다. 비싼 끝에서는 hero/supply/energy L5가 r01을 10회, worker L4가 r01을 8회, melee L5가 r01을 9회 반복해야 한다. r10만 반복하면 모든 레벨이 1~2회다. 이 수치는 "이른 라운드 반복은 비효율적"이라는 데이터 사실만 말한다. 플레이어가 실제로 그렇게 행동하는지는 말하지 않는다.

### 9.4 업그레이드 구매 트랜잭션(R3 일반화)과 content_version(R5) (v0.13, 실행 증거)
- 프로브: `docs/research/systems/probes/probe_upgrade_transaction.gd`
- 실행 명령: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_upgrade_transaction.gd --quit-after 900`
- 실행 대상: **깨끗한 전체 HEAD 스냅샷** ab00170d75b51541cccfc4c55e39829cc55f95cd. `git archive` 전체를 풀고 프로젝트 이름을 바꾼 뒤 `--import`로 실행했다. 실제 autoload를 쓰되, Save 경로는 `user://probe10/`로 돌렸다. 작업 트리에는 02·05·06의 미커밋 변경이 있어서 쓰지 않았다. 스냅샷과 사용자 폴더는 실행 후 지웠다.

**(A) 구매 API: 없음(NOT_IMPLEMENTED).** HEAD의 Save/App에는 `buy_upgrade` 계열 메서드가 없고, `Events`에도 `cmd_buy_upgrade` 신호가 없다. `git grep`으로도 `progress.upgrades`에 쓰는 코드가 `_migrate` 정규화 하나뿐임을 확인했다. 04 handoff에도 "upgrade screen (P1) not implemented"라고 적혀 있다. 따라서 업그레이드 구매가 원자적인지는 **아직 시험할 대상이 없다.** 아래 (B)는 지금 있는 저장 함수를 그대로 쓰는 구현이 어떻게 실패하는지 보여 주고, (C)는 구현이 들어왔을 때 쓸 합격 기준이다.

**(B) 현재 save.gd로 "직접 수정 + save_progress()"를 하면(실행):** 코인 100에서 up_melee_basic L2(60)를 사는 흉내를 냈다. `progress`를 직접 바꾸고 `_fault="after_tmp_write"`로 쓰기를 실패시켰다.
| 단계 | 메모리 | 디스크 |
|---|---|---|
| 구매 전 | 100 / L1 | 100 / L1 |
| 저장 실패 직후(`save_progress()`=false) | **40 / L2** (롤백 없음) | 100 / L1 |
| 관계없는 `set_setting("sfx")` 뒤 | 40 / L2 | **40 / L2** |
- 호출자는 실패를 받았는데, 다음 아무 저장에서 구매가 확정된다(`phantom_purchase_persisted_later: true`). UI가 "저장 실패, 다시 시도"를 보여 주고 사용자가 다시 누르면 **두 번 차감**된다. `save_progress()`는 실패해도 `revision`만 되돌린다. `record_result`만 자기 필드를 롤백한다. 그래서 구매는 반드시 `record_result`처럼 자기 롤백을 갖는 전용 함수여야 한다.

**(C) 합격 기준(제안 계약 `Save.buy_upgrade(upgrade_id, to_level) -> code`)과 기준 자체의 검증:** 스냅샷의 save.gd에만 임시로 두 구현을 붙여 같은 시험을 돌렸다. 저장소에는 넣지 않았다. 하나는 참조 구현(검사 → 차감·레벨 → 저장 실패 시 롤백, 같은 `to_level` 재호출은 `already_applied`), 다른 하나는 단순 구현(검사·롤백 없음)이다.
| 시험 | 기대값 | 참조 구현 | 단순 구현 |
|---|---|---|---|
| C1 같은 구매 두 번(`to_level`=2 ×2) | 500→440, L2, 두 번째 `already_applied` | PASS | **FAIL**: 340 / L3(두 번 차감) |
| C2 쓰기 실패(`after_tmp_write`) | 메모리·디스크 500 / L1, `save_failed` | PASS | **FAIL**: 메모리 440 / L2, 코드 `ok` |
| C3 마지막 rename 전 종료(`before_final_rename`) | 재로드가 (500, L1) 또는 (440, L2) 중 하나 | PASS(440, L2) | PASS (save.gd의 원자적 쓰기 덕분) |
| C4 경계값: 코인 = 비용(60) / 비용−1(59) | 0 / L2 `ok`, 59 / L1 `not_enough_coins` | PASS | **FAIL**: 59에서도 `ok`. 코인이 −1이 됐다가 로드 시 0으로 클램프돼 **사실상 공짜 구매** |
| C5 최대 레벨 초과 | 코인 불변, `max_level` | PASS | PASS |
- 기준이 두 구현을 구별한다(참조 5/5, 단순 2/5). 따라서 빈 검사가 아니다. 참조 구현은 `locked`(대상 미해금) 검사를 하지 않았다. 해금 규칙(DATA_SCHEMA "Visible only when target unlocked")은 02/04가 정해야 한다.
- C3 주의: `before_final_rename`에서 참조 구현은 `save_failed`를 반환하고 메모리를 롤백한다. 그런데 디스크의 `.tmp`가 다음 실행에서 채택되어 구매가 적용된다(440, L2). 실제 프로세스 종료라면 문제가 없다. 프로세스가 살아 있는 상태에서 이 지점의 실패를 사용자에게 "실패"로 보여 주면, 재시작 후 구매가 적용돼 있는 불일치가 생긴다. 이 지점은 사실상 "적용 여부 불명"으로 다루는 것이 정확하다.

**(D) R5 content_version 관련 실행 증거:** 저장된 `up_melee_basic` 레벨이 현재 `max_level`(5)보다 큰 9인 세이브를 만들었다. 리밸런스로 최대 레벨이 낮아진 상황을 가정한 것이다.
| 항목 | 기대(DATA_SCHEMA/RELEASE_DESIGN_REVIEW 규칙) | 실제(HEAD) |
|---|---|---|
| 로드 후 레벨 | max_level로 클램프 + 제거된 레벨 비용 환불 | **9 유지**(`_migrate`는 1..99로만 클램프) |
| 전투 hp 배율(`_upgrade_mult`) | 1.32(L5 상한) | **1.64**(L9로 계산) |
| 알 수 없는 업그레이드 `up_retired_xyz` | 무시·보존 | 보존(규칙과 일치) |
| 알 수 없는 라운드 별 `r99_retired` | 무시·보존 | 보존(규칙과 일치) |
| 세이브의 `content_version` | 있어야 버전 차이를 감지 | **없음** |
- 이 클램프·환불 누락은 지금 사용자 경로로는 생기지 않는다. 구매 API가 없어 레벨이 1을 넘을 수 없기 때문이다. 구매 기능이 생기고 그 뒤 리밸런스가 일어나면 나타난다. RELEASE_DESIGN_REVIEW §3의 "Rebalance lowers an upgrade's max_level → Clamp the level and refund"가 구현되지 않은 상태다.

**R5 content_version 검사 제안(02 구현, 01 데이터, 07 수용):**
1. 정의: `content_version = "c<schema>-" + sha256(정렬된 data/**/*.json 경로+내용)[:12]`. Content가 로드할 때 계산한다. `game_config.data_version`(사람이 붙이는 이름)과는 별개로, 내용이 바뀌면 반드시 달라지는 값이다.
2. 세이브: 성공한 저장마다 `progress.content_version`을 기록한다. 로드할 때 현재 값과 다르면 `content_changed`로 표시하고 아래 3을 실행한다. 분석 이벤트 후보로 `content_migrated{from_prefix,to_prefix}`가 있다(06 스키마, 01 승인).
3. 버전이 바뀌었을 때 할 일(데이터 기반, 버전 번호 비교가 아닌 내용 비교): (a) 각 `upgrades[id]`를 현재 `max_level`로 클램프하고 초과 레벨의 비용 합을 환불한다. 환불은 `applied` 키 `refund:<content_version>:<id>`로 한 번만 한다. (b) `data/migrations.json`(01 백로그)의 `renames`를 적용한다. (c) 알 수 없는 ID는 보존한다. (d) `unlocked_round`가 순서 인덱스라는 문제(R8)는 라운드 ID 기반 해금으로 바꾸기 전까지 `order.json` 변경을 금지 조건으로 둔다.
4. 실행 검사(07 TP-05에 해당): 이 프로브의 (D)를 합격 기준으로 쓴다. 기대값은 레벨 5, 환불 = L6~L9 비용 합(현재 데이터에 그 레벨의 비용이 없으므로 01이 "제거된 레벨" 비용 규칙을 정해야 한다), hp 배율 1.32, 알 수 없는 ID 보존, `content_version` 기록이다. 추가 변이: `max_level` 축소, 업그레이드 ID 이름 변경(+migrations), 라운드 삽입. 무결성 프로브(§9.2)와 같은 스냅샷 방식으로 돌린다.

### 9.5 업그레이드 레벨별 전투 효과 곡선 (v0.14, 엔진 코드로 계산)
- 사용자 결정 반영: 수익 모델 Q2는 **보류**다(사용자 원문 "수익모델은 보류", 코디네이터 전달). 그래서 아래 분석은 "수익화 없이 공정하게 깰 수 있는가"를 기준으로 본다. 01의 D22 기준값(r03 전 240 / r05 전 640 / r10 전 2,500)과 D23 리밸런스(적 강화 배율 절반)가 반영된 HEAD 데이터를 썼다.
- 프로브: `docs/research/systems/probes/probe_upgrade_effect.gd`. 실행 명령: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_upgrade_effect.gd --quit-after 600`
- 실행 대상: 깨끗한 HEAD ea16a8e4805d63abf994ecabc76a4fbe679dbb4a 스냅샷(data·src·project.godot, autoload 없음). exit 0. 종료 시 Godot 경고 "1 resources still in use at exit"가 1회 나왔는데, 프로브가 만든 BattleSim 참조이고 결과와 무관하다. 스냅샷은 지웠다.
- 표기: [ENGINE]은 실제 `BattleSim.setup/deploy/_spawn_enemy/income()`이 낸 값이다. [FORMULA]는 `_damage`의 `피해 = max(1, 공격 − 방어)`로 계산한 "처치에 필요한 타격 수"다. 오라·Rally·넉백·광역·집중 공격·이동 시간은 무시한다. [ASSUME]은 일꾼 수 가정(0/3/최대 8)이다. [LOWPATH]는 01의 LOW 첫 클리어 탐욕 구매 경로다. **승률·플레이 시간·유지율은 계산하지 않았다.**

**(1) 레벨별 수치 [ENGINE, r10 기준. 아군 수치에는 라운드 영향이 없음]**
| 트랙 | L1 | L2 | L3 | L4 | L5 | L5/L1 | 다음 레벨 비용 |
|---|---|---|---|---|---|---|---|
| 유닛 5종 hp·공격 | ×1.00 | ×1.08 | ×1.16 | ×1.24 | ×1.32 | +32% | melee 60/100/160/250 등 |
| 영웅 hp·공격 | 600/25 | 660/27.5 | 720/30 | 780/32.5 | 840/35 | +40% | 80/130/200/300 |
| 본진 hp(r10) | 2,400 | 2,640 | 2,880 | 3,120 | 3,360 | +40% | 50/90/150/230 |
| 보급 수입(일꾼 0/3/8) [ASSUME] | 4.0/8.5/16.0 | 4.5/9.0/16.5 | 5.0/9.5/17.0 | 5.5/10.0/17.5 | 6.0/10.5/18.0 | +50%/+24%/+12.5% | 70/120/190/280 |
| 보급 상한(r10) | 500 | 525 | 550 | 575 | 600 | +20% | (같은 트랙) |
| 일꾼 수입(일꾼 1/3/8) [ASSUME] | 5.5/8.5/16 | 5.75/9.25/18 | 6.0/10.0/20 | 6.25/10.75/22 | (최대 L4) | +14%/+26%/+37.5% | 90/150/240 |
| 기력 재생·상한 | 3.0/100 | 3.4/110 | 3.8/120 | 4.2/130 | 4.6/140 | +53% | 70/120/190/280 |
- 보급 트랙은 고정 +0.5/s다. 일꾼이 많을수록 상대 효과가 줄어든다(일꾼 8명 기준 +12.5%). 일꾼 트랙은 일꾼당 +0.25/s라 일꾼 수에 비례한다. 같은 L2 구매라도 일꾼 2명 이상이면 일꾼 트랙(90)의 수입 증가가 보급 트랙(70)보다 크다. 일꾼 2명이면 +0.5 대 +0.5, 3명이면 +0.75 대 +0.5다. 둘이 서로 대체되는 선택이라는 점은 데이터에서 나온다. 실제 일꾼 수는 플레이에 달려 있다.
- 기력 [DATA]: 쿨다운에 묶이지 않고 스킬을 계속 쓰려면 Slam 40/8 s = 5.0/s, Rally 60/20 s = 3.0/s, Barrage 80/30 s = 2.67/s가 필요하다. **Rally나 Barrage만 쓰면 L1(3.0/s)에서 이미 쿨다운에 묶여 있어 기력 업그레이드로 시전 횟수가 늘지 않는다.** 효과가 생기는 경우는 Slam을 반복하거나 여러 스킬을 섞을 때다(Slam+Rally 8.0/s, 셋 다 10.67/s). L5(4.6/s)도 이 둘에 못 미친다. `mana_on_kill` 1이 별도로 더해진다.

**(2) 체감 지점: 처치 타격 수가 바뀌는 레벨 [ENGINE 수치 + FORMULA]** — "체감"은 타격 수가 1 이상 바뀌는 것으로 정의했다. 같은 비율 증가라도 타격 수가 그대로면 화면에서 차이가 거의 없다는 가정이다. 이 정의 자체가 [ASSUME]이고, 실제 체감은 플레이테스트로만 알 수 있다.
| 트랙 / 상황 | 아군이 적을 죽이는 타격 수 L1→L5 | 바뀌는 레벨 | 적이 아군을 죽이는 타격 수 L1→L5 |
|---|---|---|---|
| melee, r01 e_grunt | 9/8/8/7/7 | L2, L4 | 12→16 (매 레벨) |
| melee, r10 e_swarm | 4/4/4/3/3 | L4 | 20→26 |
| ranged, r02 e_swarm | 3/3/3/3/2 | **L5만** | 14→19 |
| ranged, r10 e_spitter | 6/6/5/5/5 | L3 | 8→11 |
| tank, r03 e_grunt | 11/10/9/9/8 | L2, L3, L5 | 58→77 |
| fast, r04 e_swarm | 3/3/3/3/2 | **L5만** | 18→23 |
| **siege, r06·r10 e_grunt/e_swarm/e_bomber** | 2/2/2/2/2, 1/1/1/1/1 | **변화 없음** | 증가 |
| siege, r10 e_brute | 9/8/7/7/7 | L2, L3 | 8→11 |
| hero, r01 e_grunt | 4/4/4/4/3 | **L5만** | 86→120 |
| hero, r10 e_swarm | 2/2/2/2/2 | 변화 없음 | 185→259 |
| 보스·brute 상대(모든 트랙) | 예: melee vs boss_overlord 1,084→553 | 매 레벨 | — |
- 체력이 큰 적(보스, brute)에게는 매 레벨이 처치 시간을 줄인다. 체력이 작은 적(swarm, grunt, bomber)에게는 2~3레벨에 한 번만 타격 수가 바뀐다.
- **siege 공격 업그레이드는 작은 적에게 효과가 0이다**(이미 1~2타). siege의 업그레이드 가치는 brute·보스·본진(structure_mult, 이 표에 없음)에서만 나온다.
- 방어 쪽(적이 아군을 죽이는 타격 수)은 거의 매 레벨 늘어난다. 작은 적의 낮은 공격력이 방어구 1과 만나 1타 단위로 쌓이기 때문이다.
- **L5 재플레이 구간(D22)의 체감 [FORMULA]:** L5에서만 처음 바뀌는 지점이 ranged·fast의 swarm 상대, hero의 r01 grunt 상대, melee의 r10 spitter 상대 등에 있다. 그래서 L5는 숫자상 +8%p라도 일부 흔한 적에게 타격 수 1 감소로 나타난다. "숙련 구간이 느껴지는가"에 대한 데이터상 근거는 있다. 반대로 siege와 hero의 작은 적 상대는 L5에서도 그대로다.

**(3) 과도해지는 지점: LOW 경로 레벨 대 그 라운드의 적 강화 배율 [LOWPATH + DATA]**
| 라운드 | 적 hp/공격 배율(D23 이후) | LOW 경로 melee(=ranged) | tank | hero | 아군 hp 배율 − 적 hp 배율 (melee) |
|---|---|---|---|---|---|
| r01 | 1.00/1.00 | L1 ×1.00 | L1 | L1 ×1.00 | 0 |
| r02 | 1.00/1.00 | L1 | L1 | L1 | 0 (본진만 L2) |
| r03 | 1.025 | L2 ×1.08 | L2 | L1 | **+0.055** |
| r04 | 1.05 | L2 ×1.08 | L2 | L1 | +0.03 |
| r05 | 1.075 | L2 ×1.08 | L2 | L2 ×1.10 | +0.005 |
| r06 | 1.10 | L3 ×1.16 (ranged L2) | L2 | L2 | **+0.06** |
| r07 | 1.14 | L3 ×1.16 | L3 | L2 | +0.02 |
| r08 | 1.18 | L3 ×1.16 | L3 | L3 ×1.20 | −0.02 |
| r09 | 1.225 | L3 ×1.16 | L3 | L3 | −0.065 |
| r10 | 1.275/1.25 | L4 ×1.24 | L3 | L3 ×1.20 | −0.035 |
- D23으로 적 배율이 절반이 된 뒤, **LOW 경로만으로도 r03~r07에서는 아군 배율이 적 배율보다 높다.** r08~r10에서는 뒤진다. 둘 다 몇 % 수준이다.
- 과도해지는 쪽은 재플레이다. 모든 유닛 L5(+32%)·영웅 L5(+40%)는 r10의 +27.5%보다 높다. 재플레이로 일찍 L5를 사면 이른 라운드는 배율 차가 +30%를 넘는다(예: r03 1.025 대 1.32). L5는 재플레이 전용(D22)이므로, 재플레이한 플레이어는 r01~r07을 크게 앞선 상태로 다시 하게 된다. 이것이 의도된 숙련 보상인지 지루함인지는 데이터로 판단할 수 없다.
- **QA-J2(r01에 위험 없음)와의 관계 [DATA]:** r01 첫 플레이 시점에는 코인이 0이라 모든 트랙이 L1이다. 따라서 업그레이드는 r01 첫 플레이의 위험도와 무관하다. QA-J2는 r01 데이터(웨이브·기지)의 문제다. r01 재플레이에서는 업그레이드가 위험을 더 낮출 뿐이다. 본진 hp 업그레이드는 QA-J2 관찰("player base 1500/1500 untouched")처럼 본진이 맞지 않는 라운드에서는 효과가 0이다.

**(4) 01에 넘길 판단 재료(결정은 01, 데이터 수정은 하지 않음):** (a) siege 공격 업그레이드는 작은 적 상대 효과가 0이다. hp만 올리거나 structure_mult 쪽을 강화하는 등 트랙 설계를 검토할 수 있다. (b) 기력 업그레이드는 단일 스킬 사용 시 효과가 없다. 설명 문구가 "스킬을 더 자주 쓴다"라면 Rally/Barrage만 쓰는 플레이어에게는 사실과 다르다. (c) 보급 대 일꾼 트랙은 일꾼 2명 이상이면 일꾼 트랙이 같은 단계에서 더 효율적이다. (d) LOW 경로는 r03~r07에서 근소하게 앞서고 r08~r10에서 근소하게 뒤진다. "LOW 예산으로 챕터 1을 깬다"(D22 b)의 판정은 01의 시뮬레이션 A4가 해야 한다. 이 표는 그 시뮬레이션이 볼 지점(r08~r10)을 좁혀 줄 뿐이다.

### 9.6 데이터 버전 변경 시 기존 세이브의 운명 (v0.15, 스냅샷 실행)
- 프로브: `docs/research/systems/probes/probe_content_migration.gd`. 구동 스크립트: `docs/research/systems/probes/run_content_migration.ps1`.
- 실행 명령: `powershell -NoProfile -File docs/research/systems/probes/run_content_migration.ps1`
- 방식:
  - HEAD a9223df9043534ef32d77eacb0299a8c02373feb를 `git archive`로 %TEMP%에 풀고, 프로젝트 이름을 바꾼 뒤 `--import`한다.
  - 기준 데이터에서 "기존 세이브" 고정본을 만든다(%TEMP%의 절대 경로). 내용은 r01~r06 클리어, 별 3/3/2/3/1/2(합 14), `unlocked_round` 7, 코인 1,234, 업그레이드 melee L5·ranged L3·tank L2다.
  - 변이마다 스냅샷 사본을 따로 만들어 그 안의 data만 고친다. 그 다음 실제 Content·Save autoload로 고정본 사본을 읽고, 저장하고, 다시 읽는다.
  - 저장소의 data/**와 실제 세이브는 바꾸지 않았다. 실제 save.json 해시는 실행 전후 같았고 `git status -- data`도 깨끗했다. 임시 폴더는 모두 지웠다.
  - 첫 실행은 Windows PowerShell 5에서 Godot의 stderr가 종료 오류로 바뀌어 중단됐다. `$ErrorActionPreference='Continue'`로 고친 뒤 다시 돌렸다.
- 결과(로드 직후와 저장→재로드 결과는 모든 변이에서 같았다. 즉 아래 상태가 그대로 영속된다):

| 변이 | 해금(기준: r01~r07 열림) | 별 기록 | 업그레이드·전투 효과 | 코인 | 판정 |
|---|---|---|---|---|---|
| M0 변경 없음 | 같음 | 14 | 그대로 | 1,234 | 정상 |
| M1 r03 삭제 | **r08이 새로 열림**(r07을 깨지 않았는데 건너뜀). 이유: `unlocked_round` 7이 순서 인덱스라서 | r03의 별은 세이브에 **보존**되지만 챕터 별 합계는 14→**12**(현재 순서에 있는 라운드만 셀 때) | 그대로 | 그대로 | 진행 규칙 위반(건너뛰기). 별 2개가 합계에서 빠짐 |
| M2 r02 뒤에 r02b 삽입 | **r07이 잠김**(r06을 깼으므로 열려 있던 다음 라운드). r02b는 열림 | 14 | 그대로 | 그대로 | **진행 후퇴**: 이미 열린 라운드를 잃음 |
| M3 r04↔r05 교환 | 같음(둘 다 클리어한 상태라 영향 없음). 미클리어 구간에서 바꾸면 M1/M2와 같은 문제가 생긴다 | 14 | 그대로 | 그대로 | 이 고정본에서는 무해 |
| M4 melee `max_level` 5→3 | 같음 | 14 | **L5 유지, 전투 hp 배율 1.32**(새 상한이면 1.16). 환불 0 | 1,234 | 상한 초과 효과가 계속 적용되고 환불도 없음 |
| M5a 유닛 ID 변경(melee_basic→toast_knight, 업그레이드 대상도 갱신) | 같음 | 14 | 그대로(세이브는 업그레이드 ID로 저장하므로) | 그대로 | 안전 |
| M5b 업그레이드 ID 변경(up_melee_basic→up_toast_knight) | 같음 | 14 | 옛 키 `up_melee_basic: 5`는 **보존되지만 고아**가 된다. 새 트랙은 L1이라 **melee 보너스 소실**(투자 570 코인의 효과가 사라짐) | 그대로 | 데이터는 남지만 효과 손실 |
- 좋은 점: 알 수 없는 별·업그레이드 키를 지우지 않는다(DATA_SCHEMA의 "unknown IDs ignored/kept" 규칙과 일치). 코인은 어떤 변이에서도 바뀌지 않았다. 복구 경고나 읽기 전용 상태도 생기지 않았다.
- 문제 셋은 모두 "세이브가 데이터 버전을 모른다"(`content_version` 없음)와 "해금이 순서 인덱스다"(R8)에서 나온다. **라운드 삭제·삽입·순서 변경(M1/M2), 업그레이드 상한 감소(M4), 업그레이드 ID 변경(M5b)은 지금 상태로는 출시 후에 하면 안 되는 변경이다.** 유닛 ID 변경(M5a)과 수치 변경은 안전하다.

**R5 최소 구현 계약(제안: 02 런타임, 01 데이터, 07 수용)**
1. 필드(세이브, 추가만 하므로 VERSION 유지 가능):
   - `content_version: String`: Content가 `load_all` 때 계산한다. 값은 `"c1-" + sha256(정렬된 data/**/*.json 경로+내용)[:12]`이다. 성공한 저장마다 기록한다.
   - `migrations_applied: Array[String]`: 적용한 마이그레이션 키. 키 형식은 `mig:<from_cv>:<to_cv>`, `refund:<to_cv>:<upgrade_id>`다. 한 번만 적용되게 하는 장부다.
   - `unlocked_round`는 호환용으로 남기되, 진실의 원천은 아래 2의 ID 기반 규칙이다.
2. 해금 규칙(ID 기반, R8 해결): `order[i]`는 다음 중 하나면 열린다. i == 0이거나, 그 라운드 자체를 클리어했거나(`stars`에 있음), 바로 앞 라운드(`order[i-1]`)를 클리어했을 때. 이 규칙이면 M1에서 r08이 잠기고(앞의 r07 미클리어) M2에서 r07이 열린다(앞의 r06 클리어. 이미 깬 r03~r06은 그대로 열림). `unlocked_round`는 이 규칙으로 다시 계산해 저장한다.
3. 마이그레이션 표 `data/migrations.json`(01 소유, 현재 백로그):
```json
{ "schema_version": 1,
  "upgrade_renames": { "up_melee_basic": "up_toast_knight" },
  "round_renames":   { },
  "retired_rounds":  [ "r03" ],
  "upgrade_cost_history": { "up_melee_basic": [60, 100, 160, 250] } }
```
   `upgrade_renames`는 세이브 키를 새 ID로 옮긴다. 대상 키가 이미 있으면 더 높은 레벨을 쓴다. `round_renames`는 `stars`와 `best_time` 키를 옮긴다. `retired_rounds`의 별은 보존하되 챕터 합계에 넣을지는 01이 정한다. `upgrade_cost_history`는 환불 계산에만 쓴다.
4. 환불 규칙(01 결정 대기, v0.13 요청과 같은 질문): 레벨 L이 새 상한 M보다 크면 레벨을 M으로 내리고 `sum(cost_history[M-1 .. L-2])`를 코인으로 환불한다. 키 `refund:<to_cv>:<id>`로 한 번만 한다. 기록이 없으면 환불 0으로 하고 `error{area:"content", code:"refund_unknown"}`을 남긴다(코드 집합은 06과 맞춤). 코인 상한 클램프는 그대로 둔다.
5. 실행 순서: 로드 → `_migrate`(형식) → `content_version`이 다르면 `content_migrate(content)`(3 → 4 → 2 순서) → `migrations_applied`·`content_version`을 기록하고 저장. 실패하면 기존 롤백 경로를 쓴다. 이 과정은 한 번의 원자적 저장으로 끝낸다.
6. 수용 기준(07 TP-05): 위 구동 스크립트를 그대로 쓰고, 마이그레이션 표가 있다는 가정에서 기대값은 다음과 같다. M1: r08 잠김, r03 별 보존, 코인·업그레이드 불변. M2: r02b·r03~r07 열림. M3: 불변. M4: melee L3, 코인 1,234 + 410(160+250) = **1,644**, hp 배율 1.16, 두 번째 로드에서 추가 환불 없음. M5b(rename 항목 있음): `up_toast_knight` L5, 배율 1.32, 고아 키 없음. M5a: 불변. 모든 변이에서 `content_version`이 기록되어야 한다.

## 10. 출처 (모두 2026-10-31 KST 접근)
| ID | 출처 | URL | 한계 |
|---|---|---|---|
| S1 | 아처키우기 Google Play(KR, EN), Data safety(EN) | https://play.google.com/store/apps/details?id=com.GameDuo.MadArcher&hl=ko · https://play.google.com/store/apps/datasafety?id=com.GameDuo.MadArcher&hl=en | KR Data safety 페이지는 본문 추출 실패 |
| S2 | 랜덤 다이스 Google Play(KR, EN), Data safety(KR) | https://play.google.com/store/apps/details?id=com.percent.royaldice&hl=ko · https://play.google.com/store/apps/datasafety?id=com.percent.royaldice&hl=ko | 개발사 자기신고 |
| S3 | 랜덤 다이스 2 Google Play(KR) | https://play.google.com/store/apps/details?id=com.percent.aos.randomdice2&hl=ko | — |
| S4 | 슈퍼패스트 뉴스룸 "111퍼센트의 '퍼블리싱할 결심'" | https://superfast.best/newsroom/aboutpublishingtheory/ | 게시일 미확인, 자사 인터뷰 |
| S5 | Google AdMob 사례: 111 Percent eCPM 28% 증가 | https://admob.google.com/home/resources/one-hundred-eleven-percent-grows-ecpms-twenty-eight-percent-admob-platform-bidding/ | 게시일은 검색 메타데이터 기준. 벤더 마케팅 |
| S6 | Android: Play Billing 보안 권장사항 | https://developer.android.com/google/play/billing/security | — |
| S7 | AdMob 보상형 SSV | https://developers.google.com/admob/android/ssv | — |
| S8 | Android 자동 백업 | https://developer.android.com/identity/data/autobackup | — |
| S9 | 게임듀오 회사 소개(EN), 개인정보처리방침(시행 2025-08-05) | https://gameduo.net/en · https://gameduo.net/privacy-policy | 매출 단위 미표기 |
| S10 | Inven Global, 111퍼센트 부분 승소(당사자 발표) | https://www.invenglobal.com/articles/20710/111-percent-wins-partial-victory-in-random-dice-go-plagiarism-lawsuit | 1심, 판결문 비공개 |
| S11 | 게임메카, 양측 해석 | https://www.gamemeca.com/en/view.php?gid=1773899 | 같음 |
| S12 | Play Games Services 저장된 게임 | https://developer.android.com/games/pgs/savedgames | — |
| S13 | Godot 고수준 멀티플레이 | https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html | — |
| S14 | Play 계정 삭제 요구사항 | https://support.google.com/googleplay/android-developer/answer/13327111?hl=en | — |
| S15 | Firebase Remote Config 로딩 전략 | https://firebase.google.com/docs/remote-config/loading | 패턴 근거로만 인용, 벤더 추천 아님 |
| S16 | Godot Time 클래스 | https://docs.godotengine.org/en/stable/classes/class_time.html | — |
| S17 | Godot EditorExportPlatformAndroid | https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html | 기본값 미확인 |
| S18 | Play Integrity API 개요 | https://developer.android.com/google/play/integrity/overview | — |
| S19 | PostgreSQL INSERT / ON CONFLICT | https://www.postgresql.org/docs/current/sql-insert.html | — |
| S20 | Play 검색 결과(궁수키우기/아처키우기)와 각 상세 페이지 배지 | https://play.google.com/store/search?q=%EA%B6%81%EC%88%98%ED%82%A4%EC%9A%B0%EA%B8%B0&c=apps | 검색 순위는 개인화·시점에 따라 다름 |
