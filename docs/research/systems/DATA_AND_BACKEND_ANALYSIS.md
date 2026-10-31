# 데이터·백엔드 분석: 성공한 디펜스 게임의 온라인 기능과 우리 게임의 최소 설계
작성: 10-research-systems · 버전 v0.35 (v0.35 §9.27 재잠금 검증 묶음 준비·ID 기준 해제 저장안(ID_UNLOCK_SAVE_DESIGN.md)·SwiftShader 셰이더 한도 위험 판단·AAB 에뮬레이터 설치, v0.34 §9.26 업데이트 뒤 라운드 재잠금 원인 확정(save.gd 5단계, 10의 §9.6 규칙)·재현 표·release_guard 재잠금 검사, AC9 에뮬레이터 확인(실기기 미검증), git archive 줄 끝 위험 표, §9.24 AC2 정정(모두 깬 세이브), v0.33 §9.25 04 APK·06 AAB 패키지 data 바이트 같음(eb8d5c4, LF c1-989c3422c910), 앞선 줄 끝 주장의 사실·추론 구분, 04 이전 안내 시험 검토·실제 재부팅 보완 탐침(연속 업데이트·일시정지·환불 0), v0.32 §9.24 02 52f9fa3 재검증: F2 9/9, 업데이트 시나리오, 마이그레이션, AC1~AC9, 카나리 해시 기준 전환, v0.31 §9.22 정규화 해시 도입 전 호환성 공격 사례·02 수용 기준, heavy_run 덮어쓰기 원인, v0.30 §9.21 줄 끝과 content_version: 엔진 실측·APK 바이트·업데이트 재현·정규화 위치 추천, v0.29 §9.20 재개 후 손실 점검, D32/D33 대조와 출시 가드, HEAD 재실행, 재개 시간대 감시, v0.28 §9.19 실제 사용자 폴더 감시 30분·담당별 쓰기 증거·qa07 996 MB 원인, v0.27 §9.18 실제 사용자 폴더 백업, 업데이트·다운그레이드 실측, D26 결정 요청과 이전 전 백업 방어안, v0.26 §9.17 실제 사용자 폴더 오염 경로 전수 조사와 공통 격리 방법, v0.25 §9.16 01 opt 정책 구현·대조, 원거리 L5 역전 원인과 수정안, R5 수용 실행·F2 발견, v0.24 §9.15 D27 데이터 경제표·효과표 재실행·F1 독립 재실행·09 코인 흐름 회신, v0.23 §9.14 환불 근거 두 방식의 JSON 형식·장단점·테스트, v0.22 §9.13 경쟁작 공식 문서의 밸런스 변경·업데이트·오지급 처리와 D26 대조, v0.21 §9.12 정책별 경제 기준표·메뉴 토스트 미표시, v0.20 §9.11 a262640 재계산·업그레이드 화면 확인, v0.19 §9.10 buy_upgrade C1~C13, v0.18 §9.9 엔진 저장 내구성 판정·경쟁작 기기 변경 정책, v0.17 §9.8 저장 원자성 점검, v0.16 §9.7 챕터 1 코인 흐름·비용 대비 효과, v0.15 §9.6 데이터 버전 변경과 세이브, v0.14 §9.5 업그레이드 효과 곡선, v0.13 §9.4 업그레이드 트랜잭션·content_version, … v0.11 재시작 후 무결성 재실행: D17 확인, v0.12 테마 A 이름표 검사 통과·세이브 재확인) · 기준일 2026-10-31 KST · 모든 출처 접근일 2026-10-31
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
v0.22 갱신: 게임듀오 자사 페이지(S31)가 "아처키우기"를 `com.GameDuo.MadArcher`로 링크한다 [F]. "아처키우기 = 이 패키지"는 확인됐고, "궁수키우기 = 아처키우기"는 여전히 가정이다.

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
- **8/8 통과**(`C_all_pass: true`). main이 정상이 아닌 곳에서 읽은 경우는 모두 `recovered=true`라서 조용한 초기화가 없다. 사용자 알림은 `app.gd` 73~74행에서 `Save.recovered`가 true일 때 `toast("save_recovered", {source})`를 띄운다. 이 부분은 코드 읽기이고, 화면 토스트를 실행으로 확인하지는 않았다. **[v0.21 정정] 실행 결과, 메뉴 화면에서는 토스트가 그려지지 않는다(§9.12 S2: 변화 픽셀 0). 그런데 부팅 직후 화면은 메뉴다. 그래서 `recovered=true`는 기록되지만, 사용자에게 보이는 복구 알림은 현재 없다고 판단한다. 부팅 시 `save_recovered` 토스트를 직접 캡처하지는 않았다(추론).**
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

**(C) 실행 결과(v0.18 부록, 02의 4d77225 `Save.buy_upgrade` 도입 후, 깨끗한 전체 HEAD 0478edd0249a43e126e00fdc0ec172a6ea7d71b6 스냅샷):** API 발견(`Save.buy_upgrade`, `Events.cmd_buy_upgrade` 있음). **C1~C5 모두 PASS:**
- C1: `ok` → `already_applied`, 440 / L2
- C2: `save_failed`, 메모리·디스크 500 / L1
- C3: 재로드 440 / L2(일치하는 짝). 반환 코드는 프로브가 기록하지 않았다. 구현은 `.tmp` 검증 후 실패 시 `save_uncertain`을 돌려준다(코드 읽기).
- C4: 정확히 60은 `ok` 0 / L2, 59는 `not_enough_coins` 59 / L1
- C5: `max_level`

(B)의 직접 수정 위험 시연은 여전히 재현된다. 이것은 `buy_upgrade`를 거치지 않는 호출자에게만 해당한다. (D) R5는 여전히 실패다(레벨 9 유지, 배율 1.64, `content_version` 없음). C6~C13은 아직 자동화하지 않았다.

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
2. 해금 규칙(ID 기반, R8 해결): `order[i]`는 다음 중 하나면 열린다. i == 0이거나, 그 라운드 자체를 클리어했거나(`stars`에 있음), 바로 앞 라운드(`order[i-1]`)를 클리어했을 때. 이 규칙이면 M1에서 r08이 잠기고(앞의 r07 미클리어) M2에서 r07이 열린다(앞의 r06 클리어. 이미 깬 r03~r06은 그대로 열림). `unlocked_round`는 이 규칙으로 다시 계산해 저장한다. **(v0.34 정정: 이 규칙이 이미 깬 라운드를 다시 잠그는 원인이다. 라운드 2개 이상 연속 삽입, `round_renames` 없는 이름 변경, 깬 라운드 이동에서 생긴다. §9.26)**
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

### 9.7 챕터 1 코인 흐름 재계산과 비용 대비 효과가 꺾이는 레벨 (v0.16)
- 사용자 결정: Q3 작업 제목 = **"빵집 기사단: 곰팡이 디펜스"**(16:19 KST 원문). Q2 수익 모델은 보류다. 그래서 이 모델에는 유료 재화와 광고 보상을 넣지 않는다. 프로브가 `data/meta.json`의 플래그를 직접 확인했다: gems·rewarded_ads·daily_first_win·offline_income·iap가 모두 `false`이고, 어느 것도 계산에 넣지 않았다.
- 대기 항목 확인(git): 02의 22d99ea는 HEAD의 조상이다. HEAD c1ce3f5에서 `git grep -E "func buy_upgrade|content_version" -- src` 결과는 0건이다. **C1~C5와 R5 수용 기준은 계속 대기**한다. 구현이 들어오면 `probe_upgrade_transaction.gd`와 `run_content_migration.ps1`를 같은 방식으로 돌린다.
- 실행: `probe_economy_flow.gd`(v0.16에서 챕터 1 종료 상태와 트랙별 반복 횟수를 추가하고, 의도 기준값을 D22의 640으로 고침)와 `probe_upgrade_effect.gd`를 HEAD 스냅샷(data·src·budgets, autoload 없음)에서 돌렸다. 경제 프로브는 f0d80e0과 c1ce3f5에서, 효과 프로브는 f0d80e0에서 실행했고 모두 exit 0이다. 01의 686af29는 v0.14 실행(ea16a8e)에 이미 들어 있었고, 그 뒤 data 변경은 없다(`git diff --stat ea16a8e HEAD -- data` 비어 있음). 그래서 효과 수치는 v0.14 표와 같다. 01 `upgrade_budgets.json` 재현은 여전히 일치(diff 0)한다.

**(1) 라운드별 코인 [DATA/RULE, 처치는 ASSUME]:** 첫 클리어·재클리어·3별은 §9.3 표와 같다(100…600 / 30…180 / 50…120). 686af29 이후 바뀐 것은 스크립트 처치 코인 상한뿐이다. r01 12→**39**, r02 14→28, r10 138→**129**이고, 합계는 464→496이다. 재클리어는 모든 라운드에서 첫 클리어의 30%다.

**(2) 챕터 1 첫 클리어 직후(r10 첫 클리어 보상까지 받은 뒤) 살 수 있는 레벨 [LOWPATH/HIGH 탐욕 구매]**
| 경로 | 구매 레벨 수 | 잔액 | 트랙별 레벨 | 남은 비용(최대까지) | r10 반복(코인만) | r10 반복(+스크립트 처치, ASSUME) |
|---|---|---|---|---|---|---|
| LOW(첫 클리어만) | 27 | 30 | 유닛 4종·보급·기력·본진 L4, siege L3, hero L3, 일꾼 L3/4 | 3,170 | **18** | 11 |
| HIGH(+첫 3별) | 30 | 150 | 대부분 L4, 본진 **L5**, 일꾼 L3/4 | 2,510 | **14** | 8 |
- 트랙 하나를 최대로 만드는 데 필요한 r10 반복(LOW, 코인만): 대부분 2회, siege 4회, hero 3회다.
- 의도 기준값(D22) 대비: r03 전 240 = LOW 240, r05 전 640 = LOW 640, r10 전 2,500 < LOW 2,540. **LOW 경로에서 부족한 지점은 없다**(v0.8의 20 부족은 D22로 해소).

**(3) 코인이 쌓이는 구간 / 반복 노동 구간 [수치만]**
- 쌓이는 구간: r01~r10 동안에는 없다. 각 라운드 직전 누적 수입 상한(HIGH+처치)은 0/189/407/671/983/1,420/1,886/2,393/2,940/3,567이고, 그때 보이는 미구매 비용은 2,940/4,170/4,815/5,460/5,460/6,280…6,280이다. 수입이 비용을 넘는 라운드는 없다. 쌓이는 구간은 **모든 트랙을 최대로 만든 뒤에만** 생긴다. LOW 기준으로 r10을 18회 반복한 뒤부터이고, 그 뒤 코인은 상한 9,999,999까지 쓸 곳이 없다(D22 c, B29).
- 반복 노동 구간: 첫 클리어 경로가 끝난 뒤 최대 레벨까지 r10 재클리어 **14~18회**(코인만), 처치 코인 가정을 넣으면 8~11회다. 이른 라운드를 반복하면 더 많아진다. 같은 비용에 r01은 r10의 1/6만 준다(30 대 180). 이 수치가 "과도"한지는 01이 판단한다. 10은 시간·재미를 추정하지 않는다.

**(4) 비용 대비 체감 효과가 꺾이는 레벨 [§9.5 효과 프로브 대조, ENGINE+FORMULA]** — "체감 지점" = 처치 타격 수(아군→적 또는 적→아군)가 바뀌는 (트랙, 적, 라운드) 행의 수다. 행은 트랙이 처음 보이는 라운드와 r10의 적 종류마다 하나씩이다. 100코인당 체감 지점 수는 [ASSUME 지표]로, 모든 적을 같은 비중으로 센다.
| 트랙 | L2 | L3 | L4 | L5 | 꺾이는 레벨 |
|---|---|---|---|---|---|
| melee (비용 60/100/160/250) | 11지점, 18.3/100 | 9, 9.0 | 10, 6.3 | 10, 4.0 | L3. L3는 작은 적 상대 공격 지점이 0/5 |
| ranged (60/100/160/250) | 12, 20.0 | 8, 8.0 | 7, 4.4 | 13, 5.2 | L3(L5에서 약간 회복) |
| tank (70/115/180/280) | 17, 24.3 | 17, 14.8 | 15, 8.3 | 15, 5.4 | L4 |
| fast (70/115/180/280) | 16, 22.9 | 12, 10.4 | 10, 5.6 | 15, 5.4 | L3 |
| siege (90/150/230/350) | 14, 15.6 | 13, 8.7 | 10, 4.3 | 10, **2.9** | L3. **L4·L5는 전 트랙 최저**이고, 작은 적 상대 공격 지점 0~1/7 |
| hero (80/130/200/300) | 13, 16.3 | 11, 8.5 | 12, 6.0 | 12, 4.0 | L3. L3는 작은 적 상대 공격 지점 0/5 |
- 공통: 비용이 레벨마다 약 1.6배로 오르고 효과는 레벨당 +8%(영웅 +10%)로 일정하다. 그래서 100코인당 체감 지점은 L2→L3에서 대략 절반으로 준다(tank는 약 40% 감소로 가장 완만하다). 앞의 수입 표와 합치면, LOW 경로가 챕터 1 동안 사는 레벨(대부분 L4까지)이 비용 대비 효과가 높은 구간이다. **L5(재플레이 전용, D22 b)는 100코인당 2.9~5.4 지점**으로 가장 낮다.
- 보급·일꾼·기력·본진 트랙은 타격 수 지표에 해당하지 않아 이 표에 없다. 대신 §9.5 (1)의 비율 수치를 쓴다: 보급은 레벨당 +0.5/s 고정, 일꾼은 레벨당 일꾼 1명당 +0.25/s, 기력 업그레이드는 Rally/Barrage만 쓸 때 효과 없음, 본진은 맞는 라운드에서만 효과.

### 9.8 현재 Save 구현의 저장 원자성 점검 (v0.17, buy_upgrade 이전 준비)
- 범위: HEAD c15e43a3e496527d44474d09a69b0f6d777a91fc의 `src/core/save.gd`. 마지막 변경은 08ef082이고, `git show`로 읽기만 했다. 실제 세이브와 작업 트리는 수정하지 않았다. **실기기 종료 테스트는 하지 않았다.**
- **코드 읽기 결과**(`save.gd` 주석과 본문):
  - 쓰기 순서는 `save.json.tmp`에 쓰기 → `flush()` → `close()` → `.tmp` 다시 읽어 검증 → (main이 정상이면) 기존 `.bak` 삭제 + main→`.bak` rename / (main이 손상이면) main을 `.corrupt-<unix>`로 격리 → `.tmp`→main rename이다. 임시 파일에 쓴 뒤 이름을 바꾸는 방식이고, 백업 1개를 유지한다.
  - 읽기 순서는 정상 main → 정상 `.tmp` → 정상 `.bak` → 새 세이브다. 크기 2 MiB 초과, JSON 오류, envelope 없음, 체크섬 불일치, payload가 객체가 아님 중 하나면 거부하고 다음 후보로 넘어간다.
  - 버전은 **payload 안의 `version`**으로 판단한다. VERSION=1보다 크면 읽기 전용이다. 없으면 0으로 보고 이전 형식에서 이전한다. envelope의 `version`은 쓰기만 하고 읽을 때는 무시한다.
- **실행 재현**: 프로브 `docs/research/systems/probes/probe_save_load_cases.gd`, 명령 `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path <스냅샷> -s res://docs/research/systems/probes/probe_save_load_cases.gd --quit-after 600`.
  - HEAD를 `git archive`한 src+project.godot 스냅샷(autoload 제거, 프로젝트 이름 변경)에서 `user://probe10/`에만 썼다. 60초 워치독을 두었고, 실제 실행 시간은 1.6초였다. exit 0. 끝난 뒤 파일 0개를 확인했고 스냅샷과 사용자 폴더를 지웠다.
  - 첫 실행에서 L03(체크섬)과 L09(버전) 케이스가 잘못 만들어져 있었다. L03은 envelope 안 escape된 문자열을 치환하지 못했고, L09는 envelope 버전만 바꿨다. 고쳐서 다시 돌렸고 아래는 수정 후 결과다.

| 케이스 | 파일 상태 | 로드 결과(진행도 / 출처 / recovered) | 격리 | 이후 저장 |
|---|---|---|---|---|
| L01 main 0바이트, `.bak` 정상 | 전원 차단 직후 같은 상태 | 6 / bak / true | main 격리 | 성공, 재로드 main 6 |
| L02 main JSON 절반에서 잘림 | 부분 기록 | 6 / bak / true | 격리 | 성공 |
| L03 payload만 손으로 수정(체크섬 그대로) | 변조 | 6 / bak / true, `checksum mismatch` | 격리 | — |
| L04 payload가 배열 | 형식 오류 | 6 / bak / true | 격리 | — |
| L05 main 없음, `.tmp` 최신 정상, `.bak` 이전 | rename 직전 종료 | **8 / tmp** / true(최신 상태 채택) | — | 성공, `.tmp` 정리됨 |
| L06 main 없음, `.tmp` 잘림, `.bak` 정상 | 쓰기 도중 종료 | 6 / bak / true | `.tmp`는 격리하지 않고 남김(다음 저장이 덮어씀) | — |
| L07 셋 다 손상 | 최악 | 1 / fresh / **true**(사용자에게 알림) | main 격리 | 성공. 단 손상 `.bak`은 다음 회전 전까지 남음 |
| L08 main 2 MiB 초과 | 크기 제한(02 잠정값) | 6 / bak / true | 격리 | — |
| L09 payload `version` 99 | 상위 버전 | 8 / main / false, **read_only true** | — | `save_progress()` false, **파일 바이트 그대로** |
| L09b envelope만 99, payload 1 | — | 8 / main, read_only **false** | — | 성공(v1로 다시 씀) |
| L10 `version` 필드 없음(구 형식) | 이전 형식 | 4 / main | — | 성공(v1로 이전) |
| L11 UTF-8 BOM 접두 | 외부 편집기 저장 | 8 / main(정상 로드) | — | — |
| L12 envelope 없는 일반 JSON | 형식 오류 | 6 / bak / true, `bad envelope` | 격리 | — |
| L13 파일 없음 | 첫 설치 | 1 / fresh / false | — | 성공 |
- 결론(데스크톱 Windows 실행 기준): 이 손상 유형들에서 진행도를 잃지 않았다(L07 제외. L07은 복구할 사본이 없는 경우이고 알림이 있다). 상위 버전은 덮어쓰지 않는다. 체크섬은 변조나 손상 탐지용일 뿐 보안 장치가 아니다(§5.2).
- **Android 강제 종료와 부분 기록 위험(코드와 1차 소스 읽기, 실기기 미실시):**
  - 프로세스 종료(저메모리 종료, 최근 앱에서 밀어 닫기): `flush()`로 커널에 넘어간 데이터는 프로세스가 죽어도 남는다. 같은 디렉터리 안의 `rename`은 POSIX에서 원자적이다. 그래서 디스크에는 "이전 main" 또는 "새 main", 혹은 "main 없음 + 검증된 `.tmp`"(L05와 같은 상태)가 남고, 읽기 순서가 모두 처리한다. 이 경로는 R6 장애 훅 4지점으로 데스크톱에서 재현했다(§6.4 v0.10, 8/8).
  - 전원 차단·커널 패닉: Godot의 `FileAccessUnix::flush()`는 `fflush()`만 호출한다. godotengine/godot master의 `drivers/unix/file_access_unix.cpp`에는 `fsync`가 없다(S21). 4.7.2 태그와 Android에서 user://에 쓰는 FileAccess 구현이 같은지는 **확인하지 않았다(UNKNOWN)**. Android의 `AtomicFile`은 rename 전에 데이터를 sync한다고 문서에 적혀 있다(S22). 따라서 전원 차단 직후에는 새 main이 비어 있거나 이전 내용일 수 있다. 이 경우 읽기 순서상 `.bak`(직전 저장본)으로 돌아가므로, **잃는 범위는 최근 한두 번의 저장**으로 예상된다(L01·L02가 그 상태의 데스크톱 재현). GDScript에서 fsync를 직접 부를 방법은 확인하지 못했다(UNKNOWN).
  - 남은 실험(04/07, 실기기 필요): `adb shell am kill`이나 강제 종료를 저장 직후 반복하는 방법, 기기 전원 차단은 수동으로 해야 한다. 기록하지 않은 결과를 주장하지 않는다.

**buy_upgrade가 이 저장 경로를 쓸 때 C1~C5에 더할 합격 기준(02·07 전달):**
| ID | 시나리오 | 기대값 |
|---|---|---|
| C6 | 구매 중 장애 지점 4개(`after_tmp_write`, `torn_tmp`, `after_bak_rename`, `before_final_rename`) × 정상/복구 직후 | 재로드 시 (코인, 레벨)이 언제나 (구매 전) 또는 (구매 후)의 짝. 코인만 줄거나 레벨만 오른 상태는 없음 |
| C7 | `read_only`(payload v99) 세이브에서 구매 | `read_only` 반환, 메모리·파일 바이트 불변 |
| C8 | `.bak`/`.tmp` 복구 직후 첫 구매 | 저장 후 `.bak`이 손상 파일이 아니고, 재로드 시 구매가 반영됨(SV-1 경로 재확인) |
| C9 | 잔액 = 비용, 잔액 = 비용−1, 이미 코인 상한 근처 | 메모리·디스크 모두 코인이 음수가 되지 않음. 로드 시 0으로 클램프되어 공짜가 되는 경로 없음(v0.13 단순 구현 결함) |
| C10 | `save_failed` 반환 후 UI | 성공 표시 없음. "결과 불명" 지점(`before_final_rename`)에서는 UI가 Save 상태를 다시 읽어 표시 |
| C11 | 같은 프레임 두 번 탭(같은 `to_level`) | 1회만 차감(`already_applied`) |
| C12 | 구매 실패(롤백) → 같은 세션에서 `record_result` 성공 | 디스크에 전투 결과만 있고 실패한 구매는 없음. 반대 순서도 서로의 롤백이 상대 필드를 되돌리지 않음 |
| C13 | 구매 직후 앱 일시정지(`NOTIFICATION_APPLICATION_PAUSED` → `Save.save_progress()`) | 추가 저장이 구매를 중복 반영하지 않음. 실기기는 미실시로 표기 |

### 9.9 실제 엔진 버전에서의 저장 내구성 판정과 경쟁작의 기기 변경 정책 (v0.18)
**(1) 우리가 쓰는 Godot 버전 [확인]:**
- 바이너리 `tools/engine/Godot_v4.7.2-stable_win64_console.exe --version`의 출력은 `4.7.2.stable.official.ed1daf0bf`다.
- `tools/build/common.ps1`의 `GodotVersionDir = '4.7.2.stable'`와 템플릿 경로 `tools/engine/editor_data/export_templates/4.7.2.stable`이 같은 버전을 가리킨다. `project.godot`의 `config/features`는 "4.7"이고, docs/architecture/ANDROID_BUILD.md A1/A2에 SHA-512 검증 기록이 있다.
- GitHub API에서 태그 `4.7.2-stable`은 커밋 `ed1daf0bf001b61586d9930840f2f1394092c079`를 가리킨다. 바이너리 버전 문자열과 같으므로, 아래 인용은 **우리가 쓰는 정확한 커밋의 소스**다(S23).

**(2) 세 질문의 판정(4.7.2-stable 소스, 줄 번호 인용)**
| 질문 | 답 | 근거 |
|---|---|---|
| Q1 rename 전에 데이터를 디스크에 sync하는가 | **아니오** | `FileAccessUnix::flush()`는 `fflush(f)`만 호출한다([file_access_unix.cpp#L329-L332](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/unix/file_access_unix.cpp#L329-L332)). `_close()`는 `fclose`다(#L198-L220). `DirAccessUnix::rename`은 POSIX `::rename`이다([dir_access_unix.cpp#L401-L431](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/unix/dir_access_unix.cpp#L401-L431), #L420). 내려받은 8개 파일(file_access_unix.cpp, dir_access_unix.cpp, os_android.cpp, file_access_android.cpp, file_access_filesystem_jandroid.cpp, dir_access_jandroid.cpp, core/io/file_access.cpp/.h)에서 `fsync`·`fdatasync`·`F_FULLFSYNC` 검색 결과는 0건이다 |
| Q2 Android에서 user://에 쓰는 구현 | **FileAccessUnix / DirAccessUnix [확인]** | `OS_Android::initialize_core()`에서 `make_default<FileAccessUnix>(ACCESS_USERDATA)`([os_android.cpp#L120](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/os_android.cpp#L120)), `make_default<DirAccessUnix>(ACCESS_USERDATA)`(#L133). `user://` 경로는 `ACCESS_USERDATA`로 간다([core/io/file_access.cpp#L72-L73](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access.cpp#L72-L73)). 그러므로 Q1의 Unix 구현이 Android user://에도 그대로 적용된다 |
| Q3 GDScript에서 flush/fsync를 할 수 있는가 | **flush: 예(단 fsync 아님) / fsync: 아니오** | `FileAccess.flush`가 바인딩되어 있지만(core/io/file_access.cpp#L1027) 내부는 `fflush`라 사용자 공간 버퍼를 커널에 넘길 뿐이다. fsync 바인딩은 없다(검색 0건). `OS.set_use_file_access_save_and_swap(true)`(core/core_bind.cpp#L316-L318, #L846)를 켜면 WRITE 열기가 `<path>-XXXXXX` 임시 파일에 쓰고 close할 때 rename한다(file_access_unix.cpp#L118-L168, #L210-L218). 여기에도 sync는 없다. 기본값은 꺼져 있다(`backup_save = false`, file_access.h#L145). 저장소 `src`에는 이 호출이 없다(`git grep` 0건) |
- 결론 [추론, 실기기 미실시]:
  - 프로세스 강제 종료에서는 안전하다. 커널에 넘어간 데이터와 원자적 rename, 그리고 세이브 로드 순서가 지켜 준다(§9.8, §6.4 8/8).
  - 전원 차단·커널 패닉에서는 마지막 쓰기들이 아직 저장 장치에 내려가지 않았을 수 있다. 커널은 dirty 데이터를 일정 시간 뒤 기록한다(`dirty_expire_centisecs`·`dirty_writeback_centisecs`, S26). Android 기기의 실제 값과 파일 시스템(f2fs/ext4)별 rename 동작은 **불명**이다.
  - 그래서 **두 번의 저장이 짧은 간격으로 이어지면** main과 .bak이 둘 다 아직 기록되지 않은 상태일 수 있다. 예: 전투 결과 저장 직후 앱이 일시정지해 다시 저장하는 경우(app.gd의 ecord_result와 NOTIFICATION_APPLICATION_PAUSED 저장). 이때 전원이 끊기면 두 파일이 모두 손상되어 새 세이브로 돌아갈 가능성을 배제할 수 없다[추측].
  - 저장이 충분히 떨어져 있으면 .bak이 이미 기록되어 있어, 잃는 범위는 최근 저장 하나로 줄어든다[추측].

**(3) 02에 제안하는 최소 변경(02가 판단):**
- 이미 만족하는 것: "flush·close → 검증 → rename" 순서와 "정상 main만 .bak으로 회전"은 HEAD에 있다(§9.8). 바꿀 필요가 없다.
- 제안 A(최소): **시간 간격을 둔 .bak 회전.** 마지막 회전 뒤 T초(잠정값, 08/02가 정함) 안에 다시 저장하면, .bak은 그대로 두고 main만 교체한다. 교체 방법은 main 삭제 → .tmp→main rename이다. 그 사이에 끊겨도 로드 순서가 "main 없음 + 검증된 .tmp"를 처리한다(§9.8 L05). 이렇게 하면 .bak은 언제나 T초 이상 된 세대라, 기록됐을 가능성이 높아진다. 수용 시험: T 안의 두 번째 저장 뒤 .bak 바이트가 첫 저장 전 main과 같아야 하고, T가 지나면 회전되어야 하며, 기존 R6 8/8과 §9.8 14종이 그대로 통과해야 한다.
- 제안 B: 연속 저장 합치기. 같은 프레임이나 짧은 간격의 save_progress 호출을 한 번으로 묶는다. 결과 저장과 일시정지 저장이 겹치는 경우가 대상이다.
- 제안 C(무거움, 선택): Android 네이티브 플러그인으로 fsync를 호출하는 것. 04 빌드 경로와 플러그인 유지 비용이 생긴다. Android `AtomicFile`(S22)이 그 방식이다. 지금 단계에서는 권하지 않는다.
- 하지 않을 것: OS.set_use_file_access_save_and_swap을 켜는 것. 내구성 이득은 없고 임시 파일만 늘어난다(근거는 위 Q3).

**(4) 06 영향:** 06의 SAVE_BACKUP_POLICY.md B1안(`save.json`과 `save.json.bak`만 백업하고 `.tmp`·`.corrupt-*`는 제외)은 이 결과와 맞는다. 바꿀 필요가 없다. 전원 차단 때 두 파일이 모두 손상되는 경우[추측]에는 Auto Backup의 마지막 사본이 유일한 다음 복구 경로라는 점이 B1의 근거를 보강한다. Auto Backup은 백업할 때 앱을 종료한다(S8). 그래서 쓰기 도중인 파일이 백업될 위험은 문서상 낮다.

**(5) 경쟁작의 기기 변경·재설치 진행 저장(공개 자료만, 2026-10-31 접근. 내부 DB 구조는 추정하지 않음):**
| 항목 | 랜덤 다이스(com.percent.royaldice, 111퍼센트) | 아처키우기(잠정 com.GameDuo.MadArcher, 게임듀오) |
|---|---|---|
| 1차 자료 | 공식 도움말 센터(Helpshift) "🔐 계정" 섹션 4개 문서(S24) | 회사 공통 서비스 이용약관(S25), 개인정보처리방침(S9), Play Data safety(S1). 게임 전용 FAQ는 찾지 못했다 |
| 계정 연동 | 플랫폼 계정 연동. "구글, 애플, 게임센터 등"이고, 스토어 계정 1개에 게임 계정 1개다. 이미 연동한 계정의 해제·변경은 불가하다(S24 "연동 된 스토어 계정을 바꾸고 싶어요") | 약관에 "임시회원 = 게스트 로그인 기능"이 정의되어 있다(S25 용어 정의 3호). 개인정보처리방침에는 Facebook·Google 등 제3자 도구 연결 시 받는 데이터가 적혀 있다(S9). 게임 안의 연동 화면은 확인하지 않았다 |
| 기기 변경 | "크로스플랫폼 로그인 지원, Android와 iOS 상호간 로그인 가능". 계정 이관은 "오류로 접속이 불가한 경우에 한해" 지원하고, **단순 분실·기기 변경 요청은 지원하지 않는다**(S24 "계정 이관을 해주세요") | 약관 예시 문구: "기기 변경 또는 본인의 선택에 의한 기기 초기화에 따른 데이터 소실, 변경에 대해서는 복구가 불가능", "모바일 기기에 게임 정보를 기록하는 서비스의 특성에 따라 … 앱을 삭제하면 게임 데이터가 삭제되며 복구가 불가능"(S25). 이 문구는 "서비스 별 추가(아래는 예시)"라고 되어 있어, **아처키우기에 그대로 적용되는지는 불명**이다 |
| 계정 정보 보관 | "연동하신 플랫폼의 계정을 관리/보관하고 있지 않다"(S24 "계정을 분실했어요") | 방침상 "계정 및 게임 진행 상황에 대한 데이터"를 자동 수집하고, 고유 ID를 생성한다(S9). 서버 저장 여부는 불명 |
| 재설치 | 공식 문서에 직접 언급 없음(불명). 연동 로그인으로 복구된다고 보는 것은 추론 | 위 약관 예시(앱 삭제 시 복구 불가)가 적용된다면 게스트 데이터는 소실. 09 리뷰 표본(2022-12-26, [R])에도 "재설치 후 광고 제거까지 초기화" 불만이 있다 |
| 클라우드 저장 | "크로스플랫폼 로그인"이 공개된 사실이다. 저장 위치와 방식은 불명 | 불명 |
- 우리 게임에 주는 시사점[추론]: 두 회사 모두 "플랫폼 계정에 연동하지 않으면 기기 변경 시 보장 없음"을 정책으로 명시하거나, 그렇게 읽힌다. 우리는 계정이 없는 오프라인 게임이라, 기기 변경 복구는 Android Auto Backup(06 B1)뿐이다. 스토어·설정 문구에 "기기 간 진행 이전 보장"을 쓰지 않는다는 D19 규칙과 일치한다. Q2 보류에 따라 결제 복원은 범위 밖이다.
### 9.10 buy_upgrade 장애 내성 C1~C13 전체 실행 (v0.19)
- 프로브: `docs/research/systems/probes/probe_upgrade_transaction.gd` (v0.19에서 파트 E = C6~C13과 C5b 추가, 120초 워치독 추가)
- 실행 명령: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path <스냅샷> -s res://docs/research/systems/probes/probe_upgrade_transaction.gd --quit-after 900`
- 실행 대상: origin/main HEAD **ed7218a2e97a6dd74eb48112ac8b07eb370447dc**를 `git archive`한 전체 스냅샷이다(프로젝트 이름 변경, `--import`, 실제 autoload 사용, Save 경로는 `user://probe10/`). exit 0, 2.0초. 실제 save.json 해시는 실행 전후 같았고, 스냅샷·사용자 폴더·임시 파일은 지웠다.
- 첫 실행에서 C13의 `revision_delta`가 다음 케이스를 실행한 뒤에 계산되어 0으로 나왔다. 측정 위치를 고쳐 다시 돌렸고, 아래는 수정 후 결과다.

| ID | 시나리오 | 기대값 | 실제값 | 판정 |
|---|---|---|---|---|
| C1 | 같은 구매 2회 | 440/L2, 두 번째 `already_applied` | 같음 | PASS |
| C2 | `after_tmp_write` 실패 | `save_failed`, 500/L1 | 같음 | PASS |
| C3 | `before_final_rename` 종료 | 재로드가 일치하는 짝 | 440/L2 | PASS |
| C4 | 코인 60 / 59 | `ok` 0/L2 / `not_enough_coins` 59/L1 | 같음 | PASS |
| C5 | 최대 레벨 | `max_level` | 같음 | PASS |
| C5b | 미해금 대상(ranged, 해금 1) | `locked`, 코인 불변 | 같음 | PASS |
| C6 | 장애 지점 4개 × 정상/복구 직후(8케이스) | 디스크 짝이 (500,L1) 또는 (440,L2), 메모리는 반환 코드와 일치 | 8/8 일치. 코드: `torn_tmp`·`after_tmp_write`는 `save_failed`, `after_bak_rename`·`before_final_rename`은 `save_uncertain` | PASS(아래 F1 참고) |
| C7 | 읽기 전용(v99) | `read_only`, 메모리·바이트 불변 | 같음 | PASS |
| C8 | `.bak` 복구 직후 첫 구매 | `ok`, `.bak`은 정상인 이전 세대, 디스크 440/L2 | 같음 | PASS |
| C9 | 코인 60·59·9,999,999 | 음수 없음, 9,999,939 | 같음 | PASS |
| C10 | App 경로(`cmd_buy_upgrade` → `upgrade_result`) | 실패·불명이면 `ok` 아님 + `save_failed` 토스트 + 보고 코인 500. 성공이면 토스트 없음 | 같음(신호 수준. 화면 렌더링은 확인 안 함) | PASS |
| C11 | 같은 프레임 두 번 탭 | 1회 차감, 코드 `ok`,`already_applied` | 같음 | PASS |
| C12 | 구매 실패→결과 성공 / 결과 실패→구매 성공 | 600/L1 / 440/L2, clears 0, applied 빈 배열 | 같음 | PASS |
| C13 | 구매 후 `App._notification(NOTIFICATION_APPLICATION_PAUSED)` | 중복 반영 없음 | 440/L2, revision +1. 불명(`before_final_rename`) 뒤 일시정지 저장 → 디스크가 메모리와 같은 500/L1로 정리됨 | PASS(**데스크톱 흉내, 실기기 미실시**) |
- **F1(P3, 02 판단):** 복구 직후(main 격리, main 없음) 상태에서 `after_tmp_write`로 실패하면 코드는 `save_failed`다. 그런데 디스크에 완성된 `.tmp`가 남아, 다음 실행에서 채택되어 구매가 적용된다(재로드 440/L2). `UPG_SAVE_FAILED` 주석 "nothing changed, in memory or on disk"와 다르다. 짝은 맞으므로 코인만 잃는 일은 없다. 다만 사용자는 실패 토스트를 본 뒤 재시작하면 구매가 되어 있다. 정상 상태에서는 main이 이기므로 생기지 않는다.
- **R5 D**(상한 감소 시 레벨 9 유지, hp 배율 1.64, `content_version` 없음)는 이번 실행에서도 그대로 실패다.
### 9.11 01 a262640 이후 코인 흐름 재계산, 업그레이드 화면 C10 화면 확인, F1 대기 (v0.20)
**(1) 코인 흐름 전후 비교** — 같은 프로브(`probe_economy_flow.gd`, `probe_upgrade_effect.gd`)를 두 스냅샷에서 돌렸다. **전**은 c1ce3f5(07e7614 표의 기준), **후**는 ee30b9d(a262640 포함. 이후 HEAD까지 data 변경 없음)이고, 둘 다 exit 0이다. 출력은 git이 무시하는 `docs/research/systems/.local_inspect/`에 두었다.
- 실행 중 문제: %TEMP%에 쓴 출력 파일이 두 번 사라졌다. 원인은 확인하지 못했다(다른 작업자의 임시 정리 작업일 가능성). 그래서 무시 폴더로 바꿔 다시 실행했다.
- 01 변경 [DATA]: L5 비용 인하(melee·ranged 250→190, tank·fast 280→210, siege 350→260, hero 300→225, supply·energy 280→210, base 230→170), worker L4 240→180, r01 웨이브 시각 25/55/90→12/40/75. 보상 블록은 변경 없다. 총 비용은 6,280→**5,595**다. 01 `upgrade_budgets.json` 재현은 여전히 일치(diff 0)한다.

| 항목 | 전(c1ce3f5) | 후(ee30b9d) |
|---|---|---|
| 업그레이드 총비용 | 6,280 | **5,595** |
| 챕터 1 후 LOW: 구매 레벨 / 잔액 / 남은 비용 | 27 / 30 / 3,170 | 27 / 60 / **2,515** |
| 챕터 1 후 HIGH | 30 / 150 / 2,510 | 31 / 80 / **1,755** |
| 최대까지 r10 반복(코인만) LOW / HIGH | **18 / 14** | **14 / 10** |
| 같은 지표(+스크립트 처치, ASSUME) | 11 / 8 | 8 / 6 |
| 처치 코인 상한 r01 / 합계 | 39 / 496 | 41 / 474 |
| D22 기준값 240/640/2,500 | LOW 충족 | LOW 충족(변화 없음) |
- 트랙별(LOW, 후): melee·ranged·tank·fast L4로 각각 r10 2회, siege L3 3회, hero L3 3회, supply·energy L3 3회, worker L4·본진 L5는 최대 도달.
- 코인이 쌓이는 구간은 여전히 r01~r10 동안 없다. 모두 최대로 만든 뒤(r10 10~14회 반복)부터 쓸 곳이 없다.

**100코인당 체감 지점(같은 ASSUME 지표, §9.7):**
| 트랙 | L2 | L3 | L4 | L5 전→후 |
|---|---|---|---|---|
| melee | 18.3 | 9.0→8.0 | 6.2 | 4.0→**5.8** |
| ranged | 20.0→21.7 | 8.0 | 4.4 | 5.2→**6.3** |
| tank | 24.3 | 14.8 | 8.3 | 5.4→**7.1** |
| fast | 22.9→21.4 | 10.4 | 5.6 | 5.4→**7.6** |
| siege | 15.6 | 8.7 | 4.3→5.2 | 2.9→**3.8** |
| hero | 16.2 | 8.5 | 6.0 | 4.0→**5.3** |
- 꺾이는 지점은 그대로 **L2→L3**(대략 절반)이다.
- L5는 비용 인하로 25~45% 올랐다. 이제 **ranged·fast는 L5가 L4보다 효율이 높다**(6.3>4.4, 7.6>5.6). melee는 L4와 비슷하다(5.8 대 6.2).
- siege L5는 여전히 전 트랙 최저(3.8)다. 작은 적 상대 공격 효과가 0인 구조(§9.5)는 바뀌지 않았다.
- 일부 행의 타격 수가 바뀐 이유: units.json 수치 변경(c1ce3f5..HEAD diff 10줄)이 적 hp에 영향을 주었다. 원인 행은 따로 분해하지 않았다.

**(2) 업그레이드 화면 C10 화면 수준 확인(04 97c8b9c 연결 이후)**
- 프로브: `docs/research/systems/probes/probe_upgrade_ui.gd`. 실제 main 장면을 띄우고, 메뉴에서 `open_upgrades()`를 연 뒤, 04의 실제 구매 처리 `UpgradePanel._on_buy`(→ `cmd_buy_upgrade` → App → `Save.buy_upgrade` → `upgrade_result`)를 호출하고, 각 케이스 뒤에 렌더링된 프레임을 캡처했다.
- 실행: 04의 `tools/build/visible_launch.ps1 -ProjectPath <HEAD 8104970 스냅샷> -Script res://docs/research/systems/probes/probe_upgrade_ui.gd -Resolution 1280x720`.
  - 런처 기록으로 **보조 모니터 DISPLAY2**에 배치됐음을 확인했다. 창 rect는 -1600,330,-304,1089이고 `on_secondary: true`, 종료 코드 EXIT_0이다.
  - Save 경로는 이름을 바꾼 스냅샷의 `user://probe10/`였다. 실제 save.json 해시는 실행 전후 같았다.
  - 캡처와 배치 기록은 `docs/research/systems/evidence/upgrade_ui_8104970/`에 있다(PNG 6장, launch JSON). 04 파일은 수정하지 않았다.

| 케이스 | 표시 문구(실제 렌더링) | 패널 코인 | Save 메모리 | 디스크 | 판정 |
|---|---|---|---|---|---|
| 성공(500 코인) | "식빵병 · 병사 강화 Lv 2 완료!", 행 Lv 2/5, 다음 비용 100 | 440 | 440/L2 | 440/L2 | 일치 |
| 코인 부족(메모리 10) | "골드가 90 부족합니다"(100−10) | 10 | 10/L2 | (테스트용으로 메모리만 바꿈) | 일치 |
| 최대 레벨 | "이미 최대 레벨입니다" | 500 | 500/L5 | 500/L5 | 일치 |
| 저장 실패(`after_tmp_write`) | "× 저장하지 못했습니다. 골드와 레벨은 그대로입니다", `save_failed` 토스트 신호 | 500 | 500/L1 | 500/L1 | 일치 |
| 결과 불명(`before_final_rename`) | "× 저장 결과를 확인하지 못했습니다. 다시 실행해 확인하세요" | 500 | 500/L1 | **440/L2**(다음 실행에서 `.tmp` 채택) | 문구가 "다시 실행해 확인"이라 동작과 맞음 |
- 화면 관찰 3건(04 판단, 모두 P3):
  - (a) 성공 캡처에서 모달 뒤 메뉴의 좌상단 지갑은 **500** 그대로이고, 패널 지갑만 440이다. 모달을 닫으면 갱신되는지는 확인하지 않았다.
  - (b) `save_failed` 토스트는 신호로는 나갔지만 캡처한 프레임에는 보이지 않는다. 모달에 가려졌거나 메뉴 화면에 토스트 표시가 없는 것으로 보이는데, 어느 쪽인지 원인은 확인하지 않았다.
  - (c) 결과 불명일 때도 같은 `save_failed` 토스트 키를 쓴다. 이 토스트의 ko 문구는 "저장 공간을 확인해 주세요"라서, 불명 상황 설명과는 다르다.
- F1과의 관계: 저장 실패 문구 "골드와 레벨은 그대로입니다"는 정상 상태에서는 사실이다(위 표). 하지만 §9.10 F1 상황(복구 직후 `after_tmp_write`)에서는 재시작 후 구매가 적용되므로 사실이 아니게 된다.

**(3) F1 재검증:** `src/core/save.gd`의 마지막 변경은 여전히 4d77225다. 02 회신에도 F1 수정이 없다. **대기.** 수정이 커밋되면 `probe_upgrade_transaction.gd` C6의 `after_tmp_write/after_recovery` 케이스에서 기대값 디스크 500/L1(또는 코드 `save_uncertain`)을 확인한다.
### 9.12 01 재설계 판정용 경제 기준표와 메뉴 토스트 재확인 (v0.21)
**(1) 세 정책별 라운드 진입 시점 표** — 프로브 `probe_economy_policies.gd`. 구동 스크립트는 `run_economy_policies.ps1`이고, data만 쓰며 autoload 없는 임시 프로젝트에서 600초 상한으로 돈다. 정책 정의:
- P0: 구매 없음.
- P1: 첫 클리어 코인만 받고, 라운드마다 들어가기 전에 가장 싼 다음 레벨부터 산다.
- P2: 첫 클리어 + 첫 3별 + 스크립트 처치 코인(ASSUME)을 받고, 같은 규칙으로 산다. 트랙 안에서 비용이 줄지 않으므로 "가장 싼 것부터"는 예산 대비 **구매 레벨 수를 최대화**한다. 승리에 최적이라는 뜻은 아니다.
- 해금 규칙은 01 `upgrade_budgets.json`을 재현하던 것과 같다. 시뮬레이션·플레이 시간·승률·유지율은 다루지 않는다.

HEAD 40382b0 결과(`-Rev HEAD`, exit 0, 업그레이드 총비용 5,595). "카드−적"은 그 라운드 카드 유닛 hp 배율 평균에서 적 hp 배율을 뺀 값이다:
| 라운드 | 적 hp 배율 | P0 코인 / 레벨 | P1 진입 코인 → 구매 / 누적 레벨 / 카드−적 | P2 진입 코인 → 구매 / 누적 레벨 / 카드−적 |
|---|---|---|---|---|
| r01 | 1.000 | 0 / 0 | 0 → 0 / 0 / 0 | 0 → 0 / 0 / 0 |
| r02 | 1.000 | 100 / 0 | 100 → 1 / 1 / 0(본진 L2만) | 191 → 3 / 3 / +0.08 |
| r03 | 1.025 | 240 / 0 | 190 → 3 / 4 / +0.055 | 239 → 3 / 6 / +0.055 |
| r04 | 1.050 | 420 / 0 | 180 → 2 / 6 / +0.03 | 293 → 3 / 9 / +0.03 |
| r05 | 1.075 | 640 / 0 | 260 → 3 / 9 / +0.005 | 365 → 3 / 12 / +0.045 |
| r06 | 1.100 | 940 / 0 | 320 → 3 / 12 / −0.004 | 512 → 4 / 16 / +0.044 |
| r07 | 1.140 | 1,280 / 0 | 380 → 3 / 15 / +0.004 | 538 → 3 / 19 / +0.02 |
| r08 | 1.180 | 1,660 / 0 | 430 → 3 / 18 / −0.036 | 645 → 4 / 23 / +0.012 |
| r09 | 1.225 | 2,080 / 0 | 480 → 3 / 21 / −0.065 | 572 → 3 / 26 / −0.001 |
| r10 | 1.275 | 2,540 / 0 | 490 → 3 / 24 / −0.083 | 645 → 3 / 29 / −0.019 |
- 읽는 법(수치만): P0 플레이어는 r10에 2,540코인을 쓰지 않은 채로 들어가고 아군 배율은 1.00이다. "업그레이드가 의미 있는 막힘 라운드"를 판정하려면 01의 시뮬레이션이 이 세 열의 레벨 조합(구동 스크립트 출력의 `levels` 열)으로 해당 라운드를 돌려야 한다. P1에서 카드−적이 처음 음수가 되는 지점은 r06(−0.004)이고, 뚜렷해지는 것은 r08부터다. P2는 r09부터 음수다.
- 01 재실행 명령(한 줄): `powershell -NoProfile -File docs/research/systems/probes/run_economy_policies.ps1`. 기본값은 커밋 전 작업 트리 data이고, `-Rev HEAD`로 커밋을 지정할 수 있다.

**(2) `save_failed` 토스트 미표시: 캡처 시점 문제가 아니라 표시 경로가 없다**
- 프로브 `probe_toast_series.gd`를 04 `visible_launch.ps1`로 HEAD 8302f5dc6cdd8e661076eb367ad1f5c0701a17d5 스냅샷에서 실행했다. **보조 모니터 DISPLAY2**, EXIT_0. 실제 save.json 해시는 실행 전후 같았다.
- PC 잠금 확인: 실행 전후 모두 `LockApp`·`LogonUI` 프로세스가 0개였다. 잠금 상태가 아니었으므로 **캡처 유효**.
- S2(모달 닫힘, 메인 메뉴에서 `Events.toast("save_failed")` 직접 발생): 0.1초 간격 21프레임(0.06~2.2초) 동안 기준 프레임 대비 **변화 픽셀 0**.
- S1(모달 열림, `after_tmp_write` 실패 구매): 첫 프레임부터 2.2초까지 변화 픽셀이 **3,162로 일정**하다. 이것은 패널 상태 문구 "저장하지 못했습니다…"가 나타난 것이다. 시간이 지나며 사라지는 토스트였다면 변화량이 바뀌었을 것이다.
- 코드 읽기: HEAD에서 `toast` 신호를 받아 그리는 UI는 `src/ui/hud.gd`(전투 HUD)와 `src/gameplay/fallback_hud.gd`뿐이다. `ui_screen.gd`·`main_menu.gd`·`round_select.gd`·`result.gd`에는 toast 처리가 없다(`git grep -l toast`).
- **판정: 결함(표시 경로 없음), 캡처 시점 문제 아님.** 같은 이유로 메뉴에서 발생하는 `save_recovered`(부팅), `save_read_only`(부팅), `round_locked`(메뉴) 토스트도 보이지 않을 것으로 추론한다. §6.4의 "복구 알림" 주장을 이에 맞춰 정정했다.
- 증거(일부 프레임만 커밋): `docs/research/systems/evidence/toast_8302f5d/`(기준·1초 프레임 PNG 4장, launch JSON, 프로브 출력).
### 9.13 경쟁작 공식 문서로 본 밸런스 변경·업데이트·오지급 처리와 R5/D26 대조 (v0.22, Godot 미실행)
코디네이터 결정에 따라 18:00~18:30 KST(08 전용 측정 창)를 포함해 이번 작업에서는 Godot을 실행하지 않았다. 웹 문서만 읽었다. 경쟁사 서버 구조·DB는 추정하지 않는다.

**출처 범위**
- 공식으로 인정한 것: 개발사 도메인 문서(111percent.helpshift.com, policy.111percent.net, gameduo.net)와 개발사가 쓴 Play 등록 정보.
- 제외한 것:
  - 랜덤다이스 공식 디스코드: Play 설명에 공식 채널로 적혀 있지만 로그인해야 볼 수 있다. 패치노트 원문은 확인하지 못했다.
  - random-dice.fandom.com Patch_Notes: 팬 위키라 비공식이다. 접속하면 HTTP 403이 난다.
  - cafe.naver.com/randomdice("랜덤다이스 카페", clubid 29999506): 공개 API로 본 최근 글 30개가 모두 이용자 글이고 운영자 공지가 없다. 공식 카페가 아니라고 판단했다 [I].
  - 아처키우기: Play 설명과 게임듀오 게임 페이지(S31)에 공지 채널(카페·디스코드) 링크가 없고 상담 이메일만 있다. 약관(S25 제16조①)은 "카페 게시판"에 공지한다고 쓰지만, 그 주소는 공개 문서에서 찾지 못했다 [U].
  - 웹 검색(한·영) 12회로도 두 게임의 공식 공지 게시물을 찾지 못했다.
- 랜덤다이스 도움말 센터 전수 조사: FAQ ID 1~860을 ko 경로로 열어, 랜덤다이스 경로로 열리는 26건을 찾았다(계정·결제·크루·확률·정책·실행오류). 그중 밸런스 변경 보상·환불이나 롤백·오지급 공지를 다루는 FAQ는 **0건**이다.
- 식별 갱신: 게임듀오 자사 페이지 gameduo.net/game/archer-forest가 "아처키우기" 스토어 링크로 `com.GameDuo.MadArcher`를 건다 [F, S31]. 따라서 "아처키우기 = com.GameDuo.MadArcher"는 이제 사실이다. 사용자가 말한 "궁수키우기"가 이 앱인지는 여전히 가정이다(§2).
- 결과: **구체 사례(어느 날짜 패치에서 레벨을 깎고 얼마를 돌려줬는지)는 두 게임 모두 UNKNOWN이다.** 아래 표는 공개된 규칙 문서(약관·운영정책·FAQ)가 말한 것이다. 실제 운영에서 그 규칙보다 관대하게 처리했을 수 있으며, 이것이 이 표 전체에 대한 반례 가능성이다.

| # | 게임 | 출처(날짜) | 관찰: 문서가 말한 것(요약) | 등급 | 추론 | 반례·한계 |
|---|---|---|---|---|---|---|
| a1 | 랜덤다이스 | S27 운영정책 §7.3 (2023-08-05) | 운영·기술상 필요하면 패치로 게임 내용을 바꿀 수 있다. 그로 인한 이용 정보의 수정·변경·삭제는 복구가 제한된다 | [F] | 밸런스 패치로 진행이 바뀌어도 복구·보상 의무를 지지 않도록 문서를 짰다 | 실제 패치 때 보상했는지 UNKNOWN |
| a2 | 랜덤다이스 | S28 약관 제14조①⑦ (2021-07-24판) | 게임 내용 제작·변경에 포괄 권한이 있다. 무료 서비스 변경으로 생긴 손해는 따로 보상하지 않는다 | [F] | a1과 같은 방향 | 날짜 목록에 이 판 하나뿐이다 |
| a3 | 게임듀오 공통 | S25 운영정책 6.(7) | 기획·운영 판단으로 회원 게임 정보를 수정·변경·삭제할 수 있다. 사전 공지로 안내하고, 이 경우 복구하지 않는다 | [F] | 플레이어 데이터를 고칠 권리와 **사전 공지**를 함께 둔다 | 회사 공통 문서라 아처키우기 적용 범위가 불명하다(S25 한계) |
| a4 | 두 회사 | S28 제18조②, S25 제20조④ | 유료 상품의 가격·구성은 사전 통지 없이 바꿀 수 있고 책임지지 않는다 | [F] | 가격 변경만으로 소급 환불하지 않는다는 원칙 | 유료 상품 조항이다. 무료 재화 업그레이드 비용 조항은 없다 |
| a5 | 랜덤다이스 | S27 §9.1 | 유료·무료 재화를 함께 가지면 유료부터 쓴다. 청약철회는 선입선출 소비 기록으로 처리한다 | [F] | 회사 쪽에 재화 출처별 소비 기록이 있다 | 구현 UNKNOWN. Q2 보류라 우리와 무관하다 |
| b1 | 랜덤다이스 | S28 제14조③④ | 정기점검 등으로 일시 중지할 수 있다. 사유·기간을 다운로드 페이지나 게임 안에 미리 공지하고, 주·월 단위 정기 중지는 최소 24시간 전에 공지한다 | [F] | 서버에 의존하는 게임이라 점검 창이 있다 | 실제 점검 공지 사례 미확인 |
| b2 | 게임듀오 공통 | S25 제13조②, 제16조① | 점검으로 정지할 때는 앱 초기 화면·공지사항에 미리 알린다. 서비스 변경은 팝업·카페 게시판에 미리 알리고, 버그 수정·긴급 업데이트는 사후에 알릴 수 있다 | [F] | 긴급 수정은 사후 공지를 허용한다 | 카페 주소 미확인 |
| b3 | 랜덤다이스 | S30 Play "새로운 기능"(업데이트 2026-02-11), S29 FAQ 224 | 업데이트가 안 보이면 스토어를 다시 시작하거나 캐시를 지우라고 안내한다 | [D]/[F] | 구버전으로는 진행이 막히는 강제 업데이트가 있을 수 있다 [I] | "강제 업데이트"라는 문구는 없다. 최소 버전 검사 방식 UNKNOWN |
| b4 | 랜덤다이스 | S29 FAQ 750 "모든 상자 (최신화 25.02.20)", FAQ 843 "시즌 랭킹 보상 (25.02.20)" | 공개 보상·확률표 제목에 갱신 날짜를 붙인다 | [F] | 데이터 표에 사람이 읽을 수 있는 버전 표기를 단다 | 게임 내부의 데이터 버전 체계는 UNKNOWN |
| b5 | 랜덤다이스 | S29 FAQ 811 | 크루레이드 종료 뒤 월 12:00~화 10:00가 정산 시간이고 그동안 랭킹이 조정될 수 있다. 제재·탈퇴한 유저 점수는 지운다. 화 10:00에 확정하고 12:00에 보상을 준다 | [F] | 지급 전에 검증·정정하는 구간을 둔다 | — |
| b6 | 아처키우기 | S30 Play "새로운 기능"(업데이트 2026-09-17) | "버그 수정 및 최적화"만 적혀 있다 | [D] | 데이터 변경 내용을 스토어 노트로 알리지 않는다 | 게임 안 공지는 미확인 |
| c1 | 게임듀오 공통 | S25 제29조⑨ | 서버 오류 등으로 잘못 지급한 아이템은 회수하거나 정상 아이템으로 바꿀 수 있다 | [F] | 오지급 회수 권리를 약관에 둔다 | 실제 회수 공지 사례 UNKNOWN |
| c2 | 랜덤다이스 | S27 §5.2 버그 악용 표 | 악용으로 얻은 재화·아이템·경험치는 전부 회수한다. 이미 써서 회수가 어려우면 캐릭터 삭제나 데이터 초기화까지 할 수 있고, 그동안 접속을 임시로 막을 수 있다 | [F] | 획득 경로를 추적할 회사 쪽 기록이 있다 [I] | — |
| c3 | 랜덤다이스 | S27 §5.1 "계정 보호 임시 조치" | 회사 문제로 게임 데이터·재화를 복구할 때 본인 확인까지 로그인을 임시로 막는다 | [F] | 복구(롤백) 작업이 운영 절차로 존재한다 | 빈도·사례 UNKNOWN |
| c4 | 랜덤다이스 | S27 §7.1·§7.5 vs S28 제13조③ | 복구 신청 기한이 운영정책은 7일, 약관은 48시간이다 | [F] | — | **반례: 공식 문서끼리 다르다.** 운영정책 §7은 게임별 정책이 우선한다고 적었다. 어느 쪽이 현행인지 미확인 |
| c5 | 게임듀오 공통 | S25 운영정책 6.(1)(3)(8) | 회사 귀책·기술 오류는 데이터로 확인되는 범위에서 복구한다. 7일 안에 신청해야 하고 게임별 DB 보관 기간에 따라 다르다. 이벤트·보상 지급분은 복구하지 않을 수 있다. 예시 문구로 "기기에 게임 정보를 기록하는 서비스는 앱을 지우면 복구할 수 없다"고 적었다 | [F] | 회사 문서 스스로 기기 저장형 서비스를 상정한다 | "예시" 문구라 아처키우기가 어느 쪽인지 UNKNOWN |
| c6 | 랜덤다이스 | S29 FAQ 816 | 기기 이동, 앱플레이어, 통화, 백그라운드 조작 등으로 플레이 기록이 반영되지 않으면 따로 돕지 않는다 | [F] | 반영 누락은 보전하지 않는다. 중복 지급 위험보다 누락을 택한 정책으로 읽힌다 [I] | — |

**관찰·추론·반례 정리**
- 관찰 [F]: 두 회사 모두 패치로 게임 내용과 플레이어 데이터를 바꿀 권리를 두고, 그 변경을 복구 대상에서 뺀다(a1~a3). 게임듀오는 사전 공지를 조건으로 적었다(a3, b2). 두 회사 모두 오지급·악용분을 회수할 권리를 둔다(c1, c2). 랜덤다이스는 보상 전에 정산 구간을 둔다(b5).
- 추론 [I]: 회수·초기화·정산은 회사 쪽에 획득 기록이 있어야 가능하다. 우리 오프라인 세이브에는 그런 기록이 없다. `applied_battles`는 전투 ID 32개짜리 링 버퍼이고 금액을 담지 않는다.
- 반례: (1) 문서는 권리 유보일 뿐이고 실제로는 보상했을 수 있다. 사례 자료는 UNKNOWN이다. (2) 랜덤다이스 공식 문서끼리 기한이 다르다(c4). (3) 게임듀오 문서는 "예시" 문구가 섞여 있어 게임별 적용이 불명하다.

**우리 규칙(01 D26, R5 제안)과 대조**
현재 사실(코드 읽기, origin/main 3343199): `save.gd`는 업그레이드 레벨만 저장하고, 구매 가격이나 구매 당시 content_version은 기록하지 않는다. `upgrade_cost(id, to_level)`은 현재 `data/meta.json`의 `costs`만 읽는다. `data/**`에 `upgrade_cost_history`·`retired_costs`·`upgrade_renames`·`migrations.json`은 없다. `read_only`는 세이브 스키마 `version`이 더 클 때만 켜지고, content_version과는 관계없다. 01 D26(01→10 R5)은 "실제 지불액(upgrade_cost_history)" 환불을 정했다. 02는 17:45에 01에게 환불 기준을 다시 물었고(d8dd1a8), 답이 오기 전에는 "현재 비용의 합"을 PROVISIONAL로 구현하겠다고 적었다. 두 문서가 서로 다른 안을 들고 있다.

| 규칙 | 경쟁작 근거 | 제안 | 이유 |
|---|---|---|---|
| D26-1 max_level 하향·업그레이드 폐지 → 제거된 레벨에 **실제로 낸** 코인 환불 | 경쟁작은 패치 변경을 보상·복구 대상에서 뺀다(a1~a3) | **수정 후 채택**: 환불은 유지한다. 다만 "실제 지불액"을 알 수단이 지금 없다. (i) 02가 `buy_upgrade` 성공 시 같은 원자 저장 안에 `upgrade_paid[id][level] = cost`를 기록하고, 마이그레이션은 이 값을 합산한다. (ii) 기록이 없는 세이브(현재 빌드로 산 레벨)는 01이 `data/migrations.json`에 함께 넣는 `retired_costs[id]`(제거 직전 비용표)로 계산한다 | 오프라인이라 나중에 회수할 수 없다. 단일 플레이 게임에서 넉넉하게 돌려주는 쪽의 오차는 피해자가 없다 [I]. (i)은 구매당 정수 하나라 작고 정확하다. 02의 임시안(d8dd1a8, "현재 meta.json 비용의 합")은 그대로는 성립하지 않는다. max_level을 낮추면 제거된 레벨의 비용 항목도 meta.json에서 빠지므로 더할 값이 없다. 그래서 (ii)의 `retired_costs`가 어느 안에서든 필요하다 |
| D26-2 비용만 변경 → 환불 없음, 레벨 유지 | a4(가격 변경을 소급하지 않음) | **채택** | 같은 방향이다 |
| D26-3 id 변경 → `upgrade_renames` 매핑, 환불 없음 | 공개 자료 없음 [U] | **채택**. 매핑에 없는 모르는 id는 지우지 않고 보존한다(R5 계약 유지) | 지우면 되돌릴 수 없다 |
| D26-4 폐지 라운드의 별은 세이브에 남기고 지우지 않음 | 공개 자료 없음 [U] | **채택** | 같은 이유 |
| 신규 A 데이터 오류로 코인을 과다 지급한 경우 | c1·c2: 회사 쪽 회수·초기화 | **회수·초기화는 기각**. 앞으로의 보상만 고치고(fix forward) 잔액은 건드리지 않는다 | 세이브에 획득 원장이 없어 정상 플레이어와 구분할 수 없다. 잔액을 깎거나 초기화하면 "데이터를 잃지 않는다"는 세이브 원칙에 어긋난다 |
| 신규 B 진행에 영향을 주는 데이터 변경의 사전 고지 | a3·b2 사전 공지 | **축소 채택(01 결정)**: max_level 하향·폐지·라운드 순서 변경이 든 버전은 스토어 "새로운 기능"에 한 줄 적는다. 게임 안 안내 화면은 04 범위라 지금은 요청하지 않는다 | 비용이 적고 a3와 같은 방향이다. b6처럼 "버그 수정"만 쓰면 플레이어가 레벨이 바뀐 이유를 알 수 없다 |
| 신규 C 마이그레이션 1회·멱등 | b5(정산 뒤 지급) | **채택(기존 R5 제안 유지)**: content_version이 바뀌면 계산 → 검증 → 원자 저장 1회로 반영한다. 키 `refund:<content_version>:<id>`로 두 번 환불하지 않는다. 저장이 실패하면 다음 실행에서 다시 한다 | `buy_upgrade`의 save_failed/save_uncertain 처리와 같은 모양이다 |
| 점검·강제 업데이트 | b1~b3 서버 의존 | **기각** | 서버가 없다. 구버전 앱이 새 세이브를 열면 이미 `read_only`로 막으므로 그 동작만 유지한다 |
| 사람이 읽는 데이터 버전 표기 | b4 날짜 표기 | **보류(선택)** | 버그 제보 때 버전 확인에 쓸모 있지만 UI 작업이다. 지금 요청하지 않는다 |
| 복구 신청 기한 | c4·c5 | **해당 없음** | 지원팀과 서버 기록이 없다. `.bak` 복구만 있다 |

**01 r02~r06 데이터와 경제 기준표**: origin/main 3343199 기준 `data/**`의 마지막 커밋은 여전히 a262640이다(§9.11). 공유 작업 트리에는 커밋되지 않은 data 변경(13개 파일, r01~r10·meta·economy·game_config)이 있지만 커밋이 아니므로 기준표 대상이 아니다. `run_economy_policies.ps1 -Rev HEAD`는 다시 돌리지 않았고 §9.12 표(HEAD 40382b0)가 그대로 유효하다. 이 스크립트는 Godot을 실행하므로 커밋이 들어와도 18:30 KST 이후에 돌린다.

**F1 상태(코드 읽기만)**: 02가 4b5926d에서 F1을 고쳤다(안 a). 저장이 실패한 뒤 "main을 읽을 수 없고 유효한 .tmp가 있으면" `last_failure_uncertain`을 켜고 `save_uncertain`을 돌려준다. 이것은 `load_progress()`의 선택 순서와 같다. 02는 자기 작업 공간에서 내 프로브로 C6 8/8 PASS를 보고했다. 나는 이번 작업에서 Godot을 실행하지 않았으므로 **독립 재실행은 아직 하지 않았다.** 18:30 KST 이후 깨끗한 스냅샷에서 다시 돌린다.

### 9.14 환불 근거 충돌 해소안: 구매 시 지불액 기록(A)과 migrations.json retired_costs(B) (v0.23, Godot 미실행)
18:00~18:30 KST 측정 창 때문에 이번 작업은 문서 읽기, 정적 분석, Python만 썼다. Godot이 필요한 항목은 모두 **미확인**으로 표시했다. 결정은 01이 한다.

**배경(코드 읽기, origin/main 4badc15)**: `buy_upgrade`는 코인 차감과 레벨 상승을 한 번의 `save_progress()`로 저장한다. 실패하면 메모리에서 둘 다 되돌린다. 지불한 가격은 어디에도 남지 않는다. `_migrate`는 `fresh()`에 있는 키만 채우고 정규화하며, 모르는 키는 지우지 않는다. 그래서 새 키를 더해도 `VERSION`을 올릴 필요가 없다. 대신 그 키를 모르는 구버전 빌드는 키를 보존만 하고 갱신하지 않는다 [I, 코드 읽기].

**A. 세이브에 지불액 기록 (02 구현)**: 세이브 payload에 더할 필드. envelope(`version`·`checksum`·`payload`)는 그대로다.
```json
{
  "version": 1,
  "coins": 1234,
  "upgrades": {"up_siege": 5, "up_melee_basic": 3},
  "upgrade_paid": {
    "up_siege": {"2": 90, "3": 150, "4": 230, "5": 350},
    "up_melee_basic": {"2": 60, "3": 100}
  },
  "content_version": "c1-3f9a0b12cd34",
  "migrations_applied": ["m001_siege_cap4"]
}
```
- 키는 도달한 레벨을 10진 문자열로 쓴다("2"~"99"). 값은 실제로 낸 코인(정수 ≥ 0)이다. 레벨 1은 항목이 없다. 앞으로 레벨을 무료로 주는 경우가 생기면 0을 기록한다.
- `buy_upgrade` 성공 경로에서만, 코인·레벨과 **같은** `save_progress()` 안에서 쓴다. 저장이 실패하면 코인·레벨과 함께 되돌린다(키 삭제).
- `fresh()`에 `"upgrade_paid": {}`와 `"migrations_applied": []`를 더한다. `_migrate` 정규화 규칙: id별 값이 사전이 아니면 버린다. 키가 2~99 정수가 아니거나 현재 레벨보다 크면 버린다. 값이 정수가 아니거나 음수면 버린다(`stars`처럼 문자열 "60"도 버린다). 값은 코인 상한으로 자른다. 빈 사전은 지운다. `migrations_applied`는 문자열만 남기고 중복을 없앤다.
- `content_version`은 R5 제안 그대로 감지·진단용이다. 두 번 환불하지 않는 근거는 `migrations_applied`(마이그레이션 id 목록)다. 데이터 해시를 migrations.json 안에 적으면 순환이 생기므로 쓰지 않는다.

**B. data/migrations.json의 retired_costs (01 소유)**:
```json
{
  "schema_version": 1,
  "migrations": [
    {
      "id": "m001_siege_cap4",
      "note": "up_siege max_level 5 -> 4",
      "upgrade_renames": {},
      "round_renames": {},
      "upgrade_caps": {
        "up_siege": {"max_level": 4, "retired_costs": [90, 150, 230, 260]}
      },
      "retired_upgrades": {
        "up_worker": {"retired_costs": [90, 150, 180]}
      }
    }
  ]
}
```
- 덧붙이기만 한다. 출시된 항목은 고치거나 지우지 않는다. `id`는 고유하고, 배열 순서가 적용 순서다.
- `retired_costs`는 직전 출시본 meta.json의 `costs` 배열을 그대로 복사한다. 인덱스 규칙도 같다(`costs[i]` = 레벨 i+1→i+2 가격). 레벨 k > 새 상한을 환불할 때 `retired_costs[k-2]`를 쓴다.
- `upgrade_caps.<id>.max_level`은 새 meta.json의 `max_level`과 같아야 한다. 이 일치 여부는 무결성 프로브에 검사로 넣을 수 있다.
- 적용 순서: renames → caps → retired_upgrades. 폐지된 업그레이드는 환불한 뒤 `upgrades`와 `upgrade_paid`에서 지운다. 남겨 두면 나중에 같은 id가 다시 생길 때 무료 레벨이 된다.
- 레벨별 환불액 선택: A 기록이 있으면 그 값 → 없으면 B `retired_costs` → 둘 다 없으면 0과 `refund_unknown` 로그(§9.6 제안과 같음). 모든 마이그레이션을 계산한 뒤 코인 상한으로 자르고, `migrations_applied`에 id를 더해 **한 번의 원자 저장**으로 끝낸다.

| | A 지불액 기록 | B retired_costs | AB (A 우선, B 대체) |
|---|---|---|---|
| D26 "실제로 낸 코인" | 정확하다. 비용이 여러 번 바뀌어도 맞다 | 직전 출시본 가격만 안다. 실제 이력: 공성 L5는 D26 전 350, 지금 260이다(e42f809→a262640). 350에 산 플레이어에게 260을 돌려줘 90이 모자란다 | A 기록이 있는 레벨은 정확, 없는 레벨은 B |
| 작업량 | 02: `fresh`·`_migrate`·`buy_upgrade` 세 곳과 테스트 | 01: 변경마다 이전 비용을 손으로 복사. 02: 읽기만 | 둘 다 |
| 기존 세이브 | A가 들어가기 전 세이브는 기록이 없다(대체 수단 필요) | 기록이 없어도 동작한다 | 대체 수단이 있다 |
| 실수 위험 | 구매 경로가 바뀐다. E2·E3 장애 테스트로 막는다 | 복사를 잊거나 틀릴 수 있다. 무결성 검사로 막는다 | 둘 다 검사 |
| 기타 | 세이브를 고쳐 환불을 부풀릴 수 있다. 단일 플레이 오프라인이라 피해자가 없고, 체크섬이 가벼운 편집은 막는다. 구버전 빌드로 산 레벨은 기록이 빠진다(Play에서는 보통 다운그레이드가 없다) | 두 방식 모두 세이브에 `migrations_applied`가 필요하다 | — |

권고(결정은 01): **AB**. A를 출시 전에 넣으면 출시 후 구매는 모두 정확해진다. B는 출시 전 테스트 세이브와 `retired_upgrades`를 위한 대체 수단으로 남긴다.

**정적 기준 모델(Python, 실행함)**: `docs/research/systems/probes/refund_reference.py`. 위 규칙을 그대로 옮긴 모델이고, 비용은 git의 실제 meta.json(e42f809, origin/main)에서 읽는다. 엔진 코드가 아니다. `python docs/research/systems/probes/refund_reference.py --rev origin/main` → **10/10 PASS**, exit 0. 모든 사례에서 두 번째 실행은 아무것도 바꾸지 않았다(멱등).
| 사례 | 방식 | 세이브 → 결과 |
|---|---|---|
| R1 상한 5→4, 기록 있음 | AB | 공성 L5, 1,234 → L4, **1,494**(+260) |
| R2 비용 변경 뒤 상한 하향 | A | 350에 산 L5 → **1,584**(+350, 실제 지불) |
| R2b 같은 세이브 | B | → **1,494**(+260, 90 부족) |
| R3 기록 없음 | AB | → 1,494(B로 대체) |
| R4 기록도 retired_costs도 없음 | AB | → L4, 1,234(환불 0, `unknown` 로그) |
| R5 현재 레벨이 새 상한 이하 | AB | L3 → 변화 없음 |
| R6 업그레이드 폐지, 기록 없음 | AB | 일꾼 L4 → 키 삭제, **1,654**(+90+150+180) |
| R7 id 변경 | AB | 근접 L3 → `up_bread_knight` L3, 지불 기록도 이동, 코인 불변 |
| R8 두 마이그레이션 연속 | AB | → **1,914**, `migrations_applied` 2개 |
| R9 코인 상한 | AB | 9,999,989 → 9,999,999로 자름, 로그 남김 |

**엔진 수용 기준(02 구현 뒤 Godot으로 실행, 18:30 이후, 모두 미확인)**
- E1: 새 세이브, 코인 500 → `buy_upgrade("up_melee_basic", 2)` = ok → 디스크 440, L2, `upgrade_paid.up_melee_basic."2" = 60`.
- E2: `_fault = after_tmp_write`(정상 상태) → save_failed → 메모리·디스크 모두 500, L1, "2" 항목 없음.
- E3: `after_bak_rename` → save_uncertain → 다시 로드하면 440, L2, "2" = 60. 레벨과 기록은 항상 함께 움직인다.
- E4: `upgrade_paid = {"up_melee_basic": {"2": "60", "3": -5, "x": 1, "9": 70}, "bad": 7}`에 L2인 payload를 로드 → `upgrade_paid == {}`.
- E5: §9.6 M4 구동(기록 없는 레거시 세이브, 근접 상한 5→3, migrations 항목에 retired_costs) → L3, 코인 기대값은 아래 갱신값. 두 번째 실행에서 그대로.
- E6: 마이그레이션 저장 중 `after_tmp_write` → 다음 실행에서 한 번만 적용.
- E7: 마이그레이션 저장 중 `before_final_rename` → 다음 실행이 .tmp를 채택하고 다시 환불하지 않는다.
- E8: 세이브 `version`이 더 높으면(read_only) 마이그레이션도 저장도 하지 않는다(파일 해시 불변).

**§9.6 수용 기대값 갱신(데이터 산술, Godot 미확인)**: §9.6의 M4 "1,644 / hp 1.16"과 M5b "배율 1.32"는 옛 데이터(근접 비용 [60,100,160,250], 레벨당 0.08) 기준이었다. origin/main(7b93d1f 이후, 근접 비용 [60,100,160,190], D27 레벨당 0.15)에서는 다음과 같다.
- M4: 1,234 + 160 + 190 = **1,584**, hp 1 + 0.15 × 2 = **1.30**.
- M5b: 1 + 0.15 × 4 = **1.60**.
02의 R5 질문(d8dd1a8)도 1,644를 인용하므로 함께 고쳐야 한다. M4 픽스처는 레벨을 직접 써서 만들기 때문에 지불 기록이 없고, AB에서는 B로 대체된다.

**01 데이터 커밋과 경제 기준표**: 01이 17:52에 7b93d1f(D27)로 data를 커밋했다(r01~r10·meta·economy·game_config). 따라서 `run_economy_policies.ps1 -Rev HEAD` 재실행 조건은 충족됐다. Godot이 필요하므로 **18:30 이후 실행 예정이고 지금은 미확인**이다. 01은 R6에서 probe_economy_flow와 타격 횟수·코인당 효과 표의 재계산도 요청했다.
- 정적 사전 확인(git diff a262640..7b93d1f): rounds의 `coins`·`first_clear_coins`·`three_star_bonus_coins`와 meta의 `costs`에 바뀐 줄이 0개다. 적 처치 코인이 들어 있는 `data/units`는 이 커밋에서 바뀌지 않았다. 바뀐 것은 레벨당 배율(유닛 0.08→0.15, 영웅 0.10→0.15, 공성 atk 0.12→0.20), r02~r05 `enemy_scaling`(1.0/1.025/1.05/1.075 → 1.4/1.45/1.45/1.3), 탑 atk 15→30과 `enemy_tower_atk_mult` 절반이다.
- 추론 [I]: 코인과 레벨 열은 §9.12와 같고, 배율 열(적 hp 배율, 카드−적)만 바뀔 것이다. 18:30 이후 실행으로 확인한다.

**F1 독립 재실행**: 18:30 이후 깨끗한 전체 스냅샷에서 실행한다. 현재 미확인(§9.13).

### 9.15 D27 데이터로 경제 기준표·효과 꺾임표 재실행, F1 독립 재실행, R5 대기, 09 코인 흐름 회신 (v0.24)
18:30 KST에 측정 창이 끝난 뒤 실행했다(첫 실행 18:35). 실제 save.json 해시(486C8160…)는 모든 실행 전후 같았다.
- 데이터 프로브: HEAD fca9346(data = 7b93d1f, D27)의 깨끗한 `git archive` 스냅샷에서 autoload를 빼고 돌렸다.
- 저장 프로브: HEAD b4b33a7의 전체 스냅샷(autoload 유지, 프로젝트 이름 변경)에서 돌렸다. fca9346..b4b33a7 사이에 `save.gd`·`app.gd`·`data` 변경은 없다.
- 모든 실행이 exit 0이었고 SCRIPT ERROR는 0건이다.

**(1) 정책별 기준표 (`run_economy_policies.ps1 -Rev HEAD`, 총비용 5,595)**
§9.14의 추론대로 코인·레벨 열은 §9.12(40382b0)와 **완전히 같다**. 바뀐 것은 배율 열뿐이다.
| 라운드 | 적 hp 배율 | P0 카드−적 | P1 진입 코인 → 구매 / 누적 / 카드 hp / 카드−적 | P2 진입 코인 → 구매 / 누적 / 카드 hp / 카드−적 |
|---|---|---|---|---|
| r01 | 1.000 | 0 | 0 → 0 / 0 / 1.00 / 0 | 0 → 0 / 0 / 1.00 / 0 |
| r02 | **1.400** | −0.40 | 100 → 1 / 1 / 1.00 / −0.40 | 191 → 3 / 3 / 1.15 / −0.25 |
| r03 | **1.450** | −0.45 | 190 → 3 / 4 / 1.15 / −0.30 | 239 → 3 / 6 / 1.15 / −0.30 |
| r04 | **1.450** | −0.45 | 180 → 2 / 6 / 1.15 / −0.30 | 293 → 3 / 9 / 1.15 / −0.30 |
| r05 | **1.300** | −0.30 | 260 → 3 / 9 / 1.15 / **−0.15** | 365 → 3 / 12 / 1.225 / **−0.075** |
| r06 | 1.100 | −0.10 | 320 → 3 / 12 / 1.18 / +0.08 | 512 → 4 / 16 / 1.27 / +0.17 |
| r07 | 1.140 | −0.14 | 380 → 3 / 15 / 1.27 / +0.13 | 538 → 3 / 19 / 1.30 / +0.16 |
| r08 | 1.180 | −0.18 | 430 → 3 / 18 / 1.27 / +0.09 | 645 → 4 / 23 / 1.36 / +0.18 |
| r09 | 1.225 | −0.225 | 480 → 3 / 21 / 1.30 / +0.075 | 572 → 3 / 26 / 1.42 / +0.195 |
| r10 | 1.275 | −0.275 | 490 → 3 / 24 / 1.36 / +0.085 | 645 → 3 / 29 / 1.48 / +0.205 |
- P0 코인은 그대로다(r10 진입 2,540 미사용). "카드 hp"는 그 라운드 카드 유닛 hp 배율의 평균이다. 영웅 배율은 P1이 r05부터 1.15, r08부터 1.30이고, P2는 r04부터 1.15, r07부터 1.30이다.
- 바뀐 모양:
  - D26 데이터(§9.12)에서 P1의 카드−적은 r06부터 음수였다. D27에서는 **r02~r05가 음수이고 r06부터 양수**가 됐다.
  - 이 지표에서 업그레이드가 적 배율을 처음 따라잡는 라운드는 두 정책 모두 r06이다.
  - r05에서 P1은 P0 결손(−0.30)을 절반으로 줄인다(−0.15).
- **01 D27 대조**:
  - D27의 "r05 = 첫 막힘"(시뮬: 업그레이드 없이 r05 4/10 승, LOW·opt 10/10)과 같은 방향이다. r05는 결손이 남는 마지막 라운드이고, 결손이 있는 라운드 중 업그레이드로 결손이 가장 많이 준다. P2 기준 감소폭은 r02~r04가 0.15, r05가 0.225다(P1은 r03~r05 모두 0.15).
  - 반례: 이 지표에서는 r02~r04의 결손(P1 −0.30~−0.40)이 r05보다 크다. 그런데 D27 시뮬은 r02~r04를 업그레이드 없이 5/5 승리했고, LOW 최저 기지 체력도 1.00이다.
  - 그러므로 카드−적 hp는 **난이도 지표가 아니다.** 탑 atk 30, 적 구성·수, 보스 유무가 빠져 있다. 막힘 판정 근거는 01의 시뮬이다.
  - 사람 플레이에서 r02~r04가 r05보다 더 버겁게 느껴질 가능성은 이 계산으로 판단할 수 없다(승률·체감 추정 안 함).
- 경제 흐름(`probe_economy_flow.gd`):
  - 총비용 5,595, 챕터 1 후 LOW 27레벨·잔액 60·남은 비용 2,515, HIGH 31·80·1,755다.
  - 최대까지 r10 반복은 LOW 14 / HIGH 10(코인만), 8 / 6(+처치, ASSUME)이다.
  - 01 `upgrade_budgets.json` 재현 일치(diff 0), D22 기준값은 LOW 충족이다. §9.11과 같다.
- 무결성(`probe_content_integrity.gd`): ERROR 0 / WARN 0 / INFO 0.

**(2) 100코인당 체감 지점 (`probe_upgrade_effect.gd` + `probes/effect_points_per_coin.py`, ASSUME 지표, §9.7 정의)**
집계 스크립트 검증: 같은 방법으로 ee30b9d를 다시 돌렸고, §9.11 "후" 표 24칸이 모두 같은 값으로 나왔다. 아래는 이전(ee30b9d, 레벨당 +8%/+10%) → D27(+15%, 공성 atk +20%)이다. 괄호 안은 작은 적(보스 제외) 상대 공격 지점이다.
| 트랙 (비용) | L2 | L3 | L4 | L5 | 꺾이는 레벨 |
|---|---|---|---|---|---|
| melee (60/100/160/190) | 18.3→**20.0** | 8.0→**14.0** | 6.2→6.9 | 5.8→6.3 (3/6) | L3→**L4** |
| ranged (60/100/160/190) | 21.7→23.3 | 8.0→**13.0** | 4.4→7.5 | 6.3→**4.7** (4/7) | L3→**L3·L4 비슷**(−44%/−42%). L5가 L4보다 낮아짐 |
| tank (70/115/180/210) | 24.3→28.6 | 14.8→16.5 | 8.3→8.9 | 7.1→7.6 (5/8) | L3·L4 비슷(−42%/−46%) |
| fast (70/115/180/210) | 21.4→25.7 | 10.4→**14.8** | 5.6→6.1 | 7.6→8.1 (7/9) | L3→**L4** |
| siege (90/150/230/260) | 15.6→17.8 | 8.7→9.3 | 5.2→5.2 (1/9) | 3.8→**5.4** (2/9) | L3(그대로) |
| hero (80/130/200/225) | 16.2→17.5 | 8.5→9.2 | 6.0→6.5 | 5.3→5.3 (2/6) | L3(그대로) |
- 근접·원거리·기동의 L3 효율이 42~75% 올랐다(근접 +75%, 원거리 +63%, 기동 +42%). 그래서 크게 꺾이는 지점이 근접·기동은 **L2→L3에서 L3→L4로** 옮겨 갔다(근접 −30%→−51%, 기동 −42%→−59%). 원거리는 두 구간이 비슷해졌다.
- 공성 L5는 더 이상 최저가 아니다(3.8→5.4). 최저는 원거리 L5(4.7)다. 공성의 작은 적 상대 공격 지점은 여전히 L4 1/9, L5 2/9로 낮다(§9.5 구조 그대로).
- 기력·보급·일꾼·본진은 이 지표에 해당하지 않는다(§9.7과 같음).

**(3) F1 독립 재실행 (`probe_upgrade_transaction.gd`, 전체 스냅샷 b4b33a7)**: **C6 8/8 PASS**, 전체 C1~C13·C5b 통과.
| C6 사례 | 코드 | 메모리 | 다시 로드한 디스크 |
|---|---|---|---|
| after_tmp_write / healthy | save_failed | 500/L1 | 500/L1 |
| after_tmp_write / after_recovery (F1) | **save_uncertain** (이전 save_failed) | 500/L1 | 440/L2 |
| after_bak_rename / healthy·after_recovery | save_uncertain | 500/L1 | 440/L2 |
| before_final_rename / healthy·after_recovery | save_uncertain | 500/L1 | 440/L2 |
| torn_tmp / healthy·after_recovery | save_failed | 500/L1 | 500/L1 |
- 판정: **F1 해결.** 이제 `save_failed`는 모든 경우에 "디스크 불변"을 뜻한다. 04 패널의 "골드와 레벨은 그대로입니다" 문구도 F1 상황에서 사실이 됐다. 이는 코드 경로를 추론한 것이고 화면으로는 다시 확인하지 않았다.
- 같은 스냅샷에서 회귀 확인: `probe_save_rotation` C 8/8 PASS(A2 6), `probe_battle_uid_dedup` **162 / 1** PASS.

**(4) R5 대기**: b4b33a7에서 `git grep content_version -- src`는 0건이다. 그래서 `run_content_migration.ps1` M1/M2/M4/M5b와 E1~E8은 **실행하지 않았다(대기).** 같은 실행의 파트 D는 여전히 실패하고, D27 때문에 수치가 커졌다.
- 레벨 9가 상한 5 위로 유지된다.
- `_upgrade_mult` hp가 **2.20**이다(상한 기준 1.60).
- 세이브에 content_version이 없다.
- 기대값은 §9.14 갱신값(M4 1,584 / 1.30, M5b 1.60)을 쓴다.

**(5) 09 R09-10-2 회신 범위 [(1) 결과로 답할 수 있는 것만]**
- 질문 1, 최저가 우선 정책(P1 = LOW): 라운드 첫 클리어 결과 화면의 보유 코인과, 그 자리에서 싼 것부터 차례로 산 레벨 수(남는 코인)다. r01 100 → 1 (50), r02 190 → 3 (0), r03 180 → 2 (40), r04 260 → 3 (20), r05 320 → 3 (40), r06 380 → 3 (50), r07 430 → 3 (60), r08 480 → 3 (30), r09 490 → 3 (0), r10 600 → 3 (60).
  - 이 경로에서는 **모든 첫 클리어 결과 화면에서 1~3개를 살 수 있다.**
  - "살 수 있는 수"는 연속 구매 수다. 동시에 고를 수 있는 선택지 수와는 다르다.
- 질문 1, 01 우선순위 정책: (1) 결과로 답할 수 없다. 기준표 프로브는 01의 `opt` 정책을 구현하지 않았다. 01 `upgrade_budgets.json`의 `opt` 행이 01 자체 수치다.
- 질문 2: 반복 보상 비율을 바꿨을 때, 챕터 1을 마친 뒤 최대까지 필요한 r10 반복 횟수(코인만). r10 첫 클리어 600, 결손 LOW 2,455 / HIGH 1,675(EF maxout)로 계산한 산술 값이다.
  - 30%(180): LOW **14** / HIGH 10(프로브 값과 일치).
  - 40%(240): LOW **11** / HIGH 7.
  - 50%(300): LOW **9** / HIGH 6.
  - r10 반복만 센 값이다. 비율을 바꾸면 다른 라운드의 재클리어 수입도 바뀌지만 여기에는 넣지 않았다.

### 9.16 01 opt 정책 구현·대조, 원거리 L5 효율 역전 원인과 수정안, R5 수용 기준 실행과 F2 (v0.25)
실행 시각 18:45~18:57 KST. 데이터 프로브는 HEAD f41fd12(data 7b93d1f), 저장 프로브는 같은 HEAD(save.gd 7f2886c = 02 R5)의 깨끗한 `git archive` 스냅샷에서 돌렸다. 모든 실행이 exit 0이었고 SCRIPT ERROR는 0건이다.
- 실제 save.json 해시가 이번에는 실행 중 바뀌었다(486C8160… → 64BE0016…, 수정 시각 18:47:36·18:50:41). 바꾼 것은 내 실행이 아니다.
  - 같은 폴더의 `logs/`에는 그 시각에 다른 작업자의 실행 기록이 있다(01 밸런스 시뮬 `[balance]`, `PRESSURE_CUE_PROBE`, App 부팅).
  - 내 스냅샷은 프로젝트 이름을 "Probe10 Snapshot"으로 바꿔 `app_userdata/Probe10 Snapshot/`에 쓴다.
  - 이번 프로브가 쓰는 `probe10/r5_save.json`은 실제 폴더(`Lane Defence/probe10/`)에 없다. 그 폴더의 파일은 17:38:50의 02 실행분뿐이다.
  - 따라서 "해시 불변"은 이번에는 증거로 쓸 수 없고, 격리 근거는 위 세 가지다.

**(1) 01 opt 정책을 프로브에 구현하고 대조 (`probe_economy_policies.gd` P3_opt, `run_economy_policies.ps1 -Rev HEAD`)**
- 구현 규칙은 `upgrade_budgets.json`의 `policy_opt` 그대로다. 첫 클리어 코인만 쓰고, 우선순위 melee>hero>ranged>tank>supply>fast>siege>worker>energy>base_hp에서 살 수 있는 첫 항목을 산 뒤 처음부터 다시 훑는다.
- 01 시뮬은 라운드별 레벨을 `upgrade_budgets.json[budget][round].levels`에서 그대로 읽는다(`multi_seed_sim.gd.txt` 69행). 그래서 이 표가 01 시뮬의 구매 결과다.
- 대조 결과: **P3_opt vs `opt` r01~r10 레벨·잔액 차이 0건**, P1 vs `low` 차이 0건(구동 스크립트에 자동 대조를 넣었다).

| 첫 클리어 결과 화면 | P1 최저가 우선(LOW): 코인 → 구매(잔액) | P3 01 우선순위(opt): 코인 → 구매(잔액) |
|---|---|---|
| r01 | 100 → 1 (50) | 100 → 1 (40) |
| r02 | 190 → 3 (0) | 180 → 2 (0) |
| r03 | 180 → 2 (40) | 180 → 1 (20) |
| r04 | 260 → 3 (20) | 240 → 2 (0) |
| r05 | 320 → 3 (40) | 300 → 3 (10) |
| r06 | 380 → 3 (50) | 350 → 3 (10) |
| r07 | 430 → 3 (60) | 390 → 2 (5) |
| r08 | 480 → 3 (30) | 425 → 3 (0) |
| r09 | 490 → 3 (0) | 460 → 3 (0) |
| r10 | 600 → 3 (60), 누적 27레벨 | 600 → 4 (15), 누적 24레벨 |
- "구매"는 그 화면에서 규칙대로 연속으로 산 레벨 수다. opt도 **모든 첫 클리어 결과 화면에서 1~4개**를 산다. 비싼 전투 업그레이드를 먼저 사므로 r02·r03·r04·r07에서는 P1보다 1개 적고, r10에서는 1개 많다.
- 최대까지 r10 반복(코인만, 반복 보상 30/40/50%): P1 **14/11/9**, opt **14/11/9**, P2 7/6/5다.
  - 결손(남은 비용 − 잔액)은 P1·opt 모두 2,455다. 같은 수입을 업그레이드에만 쓰면 사는 순서와 관계없이 결손이 같기 때문이다(총비용 5,595 − 수입 3,140). 이 산술을 프로브 출력이 확인했다.

**(2) 원거리 L5 효율 역전(4.7 < L4 7.5): 원인 분리와 수정안**
| 원거리 (D27) | 비용 | 공격 지점 | 방어 지점 | 합 | 100코인당 |
|---|---|---|---|---|---|
| L4 | 160 | 6 | 6 | 12 | 7.5 |
| L5 | 190 | 6 | **3** | 9 | **4.7** |
| (참고) 근접 L4 → L5, 같은 비용 | 160 → 190 | 6 → 5 | 5 → 7 | 11 → 12 | 6.9 → 6.3 |
- 분해: 100코인당 −37% = 효과(지점 12→9, ×0.75) × 비용(160→190, ×0.84). 로그 기준으로 **효과 쪽이 63%, 비용 쪽이 37%**다.
- 효과 쪽 원인은 L5에서 방어 지점 4행(r02 e_grunt, r10 e_grunt, r10 e_brute, r10 boss_overlord)이 사라진 것이다. 원거리 hp는 기본 70에 레벨당 +10.5라서 101.5 → 112로 오른다. 이 증가로는 적의 피격 횟수가 다음 정수에 닿지 않는다(예: e_grunt 상대 9 → 9). 이산화 때문에 생기는 현상이다.
- 근접은 같은 비용에서도 L5 지점이 늘어(11→12) 역전이 없다.
- 시험한 안. 데이터는 바꾸지 않았고, 버리는 스냅샷 안의 meta.json만 바꿔 `probe_upgrade_effect`를 다시 돌렸다.
| 안 | 원거리 L4 / L5 (100코인당) | 역전 | 총비용 | 최대까지 r10 반복 LOW 30/40/50% (HIGH) | 기타 |
|---|---|---|---|---|---|
| 현재 | 7.5 / 4.7 | −37% | 5,595 | 14/11/9 (10/7/6) | — |
| 비용만: L5 190→160 | 7.5 / 5.6 | −25% | 5,565 | 14/11/9 (10/7/6) | 비용은 줄어들 수 없으므로(무결성 규칙) 160이 하한이다. 역전을 없애려면 L5 ≤ 120이 필요해 **불가** |
| 공격력만: atk 0.15→0.20 | 8.1 / 4.2 | 악화 | 5,595 | 변화 없음 | **기각** |
| **안 1** 효과만: hp_mult 0.15→**0.18** | 7.5 / 6.8 (L5 13지점, 방어 7) | −9% (근접과 같은 수준) | 5,595 | 14/11/9 (10/7/6) | hp L2~L5 +2.6~+7.5%(L5 112→120.4). 0.20도 지점 수는 같다(13). 비용이 같아 upgrade_budgets.json은 그대로 |
| **안 2** hp 0.18 + L5 190→160 | 7.5 / **8.1** | **해소** | **5,565** (−30) | 14/11/9 (10/7/6). 결손 2,455→2,425, HIGH 1,675→1,645 | 무결성 ERROR 0. 최저가 우선 경로가 원거리 L5를 일찍 사므로 `upgrade_budgets.json` low r10, high r09·r10 행이 바뀐다(diff 3). 01 재생성과 시뮬 재실행이 필요하다 |
- 이 지표는 모든 적 행을 같은 비중으로 센다(ASSUME). 사람이 역전을 체감하는지는 계산으로 판단하지 않는다. 결정은 01이 한다.

**(3) R5 수용 기준 실행 (02 7f2886c, PROVISIONAL)**
02 구현은 내 §9.14 A안(`upgrade_paid`)이 아니다. 세이브할 때마다 그 시점 data의 비용표를 `content_snapshot`에 적어 두고, 다음 데이터 변경 때 그 가격으로 환불한다. 성격은 **B와 같지만 01이 손으로 복사할 필요가 없다**(자동 스냅샷).
- `run_content_migration.ps1`(HEAD f41fd12): 정정 기대값과 **모두 일치**한다.
  - M1: r08 잠김, r03 별 보존, 코인·업그레이드 불변.
  - M2: r02b·r03~r07 열림.
  - M3: 불변.
  - **M4: L3, 코인 1,584, hp 1.30**, 다시 저장하고 로드해도 같아 두 번째 환불이 없다.
  - M5a: 불변. **M5b: `up_toast_knight` L5, 1.60**, 고아 키 없음.
  - 모든 변이에 `content_version`이 있다.
- `probe_r5_cases.gd`(새 프로브): 데이터 변경은 Content 자동 로드의 메모리에서만 흉내 냈고, 세이브는 격리 경로에 썼다. 결과는 **9개 중 7개 통과**다.
| 사례 | 결과 | 판정 |
|---|---|---|
| E1 구매 시 버전·스냅샷 기록 | 440/L2, 스냅샷 비용 [60,100,160,190] | 통과 |
| E4j 엉터리 스냅샷(문자열 가격, 사전 아님) | 충돌 없음, L7→L5, 환불 0 | 통과. 단, 문자열 가격은 경고 없이 0으로 환불된다(P3) |
| E5 상한 5→3 | 1,584 / L3, 두 번째 로드 1,584 | 통과 |
| E6 이전 저장 실패(after_tmp_write) | 디스크 1,234/L5 그대로, 다음 로드에서 1,584 한 번 | 통과 |
| E7 결과 불명(before_final_rename) | 다음 로드가 .tmp 채택(1,584/L3), 다시 환불 안 함 | 통과 |
| E8 새 버전 세이브(read_only) | 이전 안 함, 파일 바이트 불변 | 통과 |
| **F2a** E6 뒤 같은 세션에서 일반 저장 1회(설정·전투 결과·구매) | 디스크 **1,234 / L5, content_version = 새 버전** → 다시 로드해도 그대로 | **실패** |
| **F2b** E7 뒤 같은 세션에서 일반 저장 1회 | .tmp의 이전 결과를 덮어써 1,234 / L5, 새 버전 | **실패** |
| DL 버전 없는 옛 세이브의 L9 | L5, hp 1.60, 환불 0 + `refund_unknown` 경고, 버전 기록 | 통과 |
- **F2 (P2, 02 소유)**: 이전 저장이 실패하면 메모리는 이전 전 상태(구 버전)로 되돌아간다.
  - 그런데 같은 세션의 다음 일반 `save_progress()`가 `_stamp_content()`로 **새** content_version과 스냅샷을 찍는다.
  - 그러면 다음 로드는 "버전 같음"으로 보고 이전을 건너뛴다. 결과적으로 상한을 넘는 레벨(L5 > 3)이 남고 환불도 없다. 한 번만 이전한다는 보장이 깨진다.
  - F2b에서는 디스크 .tmp에 있던 이전 결과까지 지워진다.
  - 발생 조건은 부팅 시 이전 저장 실패라 드물다. 코인이 줄지는 않는다.
  - 수정안: 이전 저장이 실패하면 `_migration_pending`을 켠다. 켜져 있는 동안 `_stamp_content()`는 이전의 버전·스냅샷을 유지한다(다음 로드에서 재시도). 또는 `save_progress()` 시작에서 이전을 다시 시도한다.
- D26 대조(규칙이 PROVISIONAL이라 결함이 아니라 차이로 기록한다):
  - **R2m**: 비용 변경(L5 250→190) 뒤 상한을 낮추면, 실제로 낸 160+250=410이 아니라 스냅샷 가격 160+190=**350**을 환불한다(1,584, D26대로면 1,644). §9.14 R2b와 같은 B의 성질이다.
  - **R6r**: 업그레이드를 meta.json에서 지우면(같은 target 대체 없음) 모르는 id로 보존된다. 레벨 4는 남고 **환불 0**이다(D26대로면 +420).
- **파트 D 재판정**:
  - 실제로 생길 수 있는 경우는 모두 통과다. 옛 데이터 버전에서 상한이 낮아진 경우(E5·M4)와 버전 없는 옛 세이브(DL)가 그렇다.
  - 옛 파트 D 모양(같은 content_version에서 L9, hp 2.20)은 세이브 파일을 직접 고쳐야만 생긴다. R5는 버전이 같으면 돌지 않으므로 그대로 남는다. 이것은 P3 선택 사항이다(`_migrate`에서 언제나 max_level로 자르기).
- 회귀(같은 스냅샷): `probe_upgrade_transaction` C1~C13·C5b 통과(C6 8/8), `probe_save_rotation` C 8/8, `probe_battle_uid_dedup` 162/1, `probe_save_load_cases` 14건 모두 v0.17과 같은 복구 결과.

### 9.17 실제 사용자 폴더(Lane Defence) 오염 경로 전수 조사와 공통 격리 방법 (v0.26)
조사 기준은 origin/main 65502e8, 19:00~19:12 KST다. 저장소 파일은 읽기만 했다. Godot 실행은 모두 내 비공개 APPDATA에서만 했고, 실제 사용자 폴더에는 아무것도 쓰지 않았다.

**(1) 메커니즘: 실행만 해도 실제 세이브가 바뀐다**
- 엔진 소스(4.7.2-stable, S23 계열):
  - `platform/windows/os_windows.cpp` 2417~2425행: `get_config_path()`·`get_data_path()`는 **APPDATA 환경 변수**를 그대로 쓴다. 2508행: `get_user_data_dir(p)`는 `get_data_path()/p`다.
  - `core/os/os.cpp` 338~353행: user:// = `<data>/Godot/app_userdata/<application/config/name>`이다. 단, `use_custom_user_dir`가 켜져 있으면 `<data>/<custom_user_dir_name>`이다.
  - `config/name_localized`(4b5926d)는 이 경로에 쓰이지 않는다.
  - 결론: 공유 작업 트리나 이름을 바꾸지 않은 스냅샷을 실행하면 user://는 **실제 `%APPDATA%\Godot\app_userdata\Lane Defence`**가 된다.
- `-s` 스크립트로 실행해도 autoload가 올라온다. 그러면 Save의 `_ready()`가 `user://save.json`을 로드하고, R5(7f2886c)부터는 content_version이 다르면 **로드 중에 다시 저장**한다(`prev_cv`가 비어 있지 않으면 바꿀 것이 없어도 저장한다).
- 비공개 APPDATA 실험(`probes/isolated_godot.ps1` + `probes/probe_noop_boot.gd`, 이름을 바꾸지 않은 HEAD 7132525 스냅샷):
| 실험 | 시작 세이브 | 아무것도 하지 않는 부팅 1회 뒤 | 판정 |
|---|---|---|---|
| X1 데이터 버전이 다름 | revision 5, content_version `c1-old000000`, 코인 777 | revision **6**, content_version = 현재 데이터, `.bak` 새로 생김 | 부팅만으로 세이브와 백업이 바뀐다 |
| X2 같은 세이브로 한 번 더 부팅 | (X1 결과) | 해시 같음 | 버전이 같으면 쓰지 않는다 |
| X3 편집 중인 데이터(근접 상한 5→3)로 부팅 | 근접 L5, 코인 777, 옛 버전 | 근접 **L3**, 코인 **1,127**(+350), 새 버전으로 기록 | **편집 중인 data/**로 아무 스크립트를 실행해도 실제 세이브의 레벨이 깎이고 환불된다. 데이터를 되돌려도 레벨은 돌아오지 않는다** |
  - 세 실험 모두 `OS.get_user_data_dir()` = 비공개 폴더였고, 그 실행의 `logs/godot.log`가 비공개 폴더에 생겼다(격리 증거).
- 실제 폴더 관찰(이름·수정 시각만 읽음): `save.json`이 19:07, `.bak`이 19:06에도 바뀌었다.
  - `selftest_save.json` + `.corrupt-*` 15개(08:57~18:53), `selftest_faults/`, `qa07/`, `perf/`, `services_*_report.json` 7개, `atlas_guard_test`, `m3dbg1~3`, `probe10/`(17:38, 02가 내 프로브를 공유 트리에서 실행한 것), `logs/`가 있다.
  - 공유 트리에서 도는 테스트가 모두 같은 폴더를 쓰고 있다는 뜻이다.

**(2) 실행 스크립트 전수 표** — Godot을 띄우는 저장소 파일 전체를 조사했다. "부팅 쓰기"는 autoload Save가 실제 `save.json`을 로드하면서 다시 쓸 수 있는 경우다. 테스트 안에서 `save.path`를 바꾸는 것은 부팅 **이후**라 부팅 쓰기를 막지 못한다.
| 담당 | 파일(실행 줄) | 프로젝트 / user:// | 부팅 쓰기 | 스크립트가 직접 쓰는 user:// 파일 | 격리 |
|---|---|---|---|---|---|
| 01 | `docs/design/balance/sweep.ps1`(11) → multi_seed_sim | 공유 트리(`--path $root`) / 실제 | 예 | `user://multi_seed.json`(기본값, 보통 인자로 TEMP) | **아님** |
| 01 | `confirm_sim`·`paired_sim`·`probe_sim`·`verify_files.gd.txt`(6), `low_budget_sim.gd.txt`(9)의 Run 안내 | `--path .` / 실제 | 예 | `user://paired_sim.json` 등 기본 출력 | **아님** |
| 02 | `src/core/diag/selftest.gd`(3), `pressure_cue_probe.gd`(4), `passive_probe.gd`(3), `wave_clear_probe.gd`(3)의 Run 안내 | `--path .` / 실제 | 예 | selftest: `selftest_report.json`, `selftest_save.json`(+.bak·.corrupt-*), `selftest_faults/` | **아님** |
| 02 | `tools/build/build_android_debug.ps1`(46·47) | 아카이브 사본, import·export만 | 아니오(게임 미실행) | — | 해당 없음 |
| 02 | 로컬 스냅샷 "It02 <sha>" | 이름 바꾼 사본 | — | — | 격리(관찰) |
| 03 | `tools/art/run_godot_*.ps1` | 자체 프로젝트 `defence-art-check`(autoload 없음) | 아니오 | `defence-art-check/…` | **격리** |
| 04 | `tools/build/run_tests.ps1`(21·23·26): ui_tests, engine_selftest, ui_integration | `--path .` / 실제 | 예 | `atlas_guard_test_<pid>`, `test_ui_integration_save_<pid>.json`, selftest 파일 | **아님** |
| 04 | `tools/build/flake_probe.ps1`(16·23·30), `verify_and_publish.ps1`(43·50) | 아카이브 사본, 이름 그대로 / 실제 | 예 | 같은 테스트 파일 | **아님** |
| 04 | `tools/build/visible_launch.ps1`(104·107·112; 기본값은 작업 트리), `capture_ui.ps1`(23, visible_launch 사용) | 호출자 경로 / 사본 이름에 따름. 기본은 실제 | 예. 메인 장면이면 전투 결과까지 저장될 수 있음 | 스크립트별 | **기본값은 아님** |
| 05 | `tools/audio/run_godot_checks.ps1` | 아카이브 사본 + `use_custom_user_dir`(`defence_audio_sandbox`) | 아니오 | 자체 폴더 | **격리** |
| 06 | `tests/services/run_services_suites.ps1`(17) | `--path .` / 실제 | 예 | `services_*_report.json`, `svc_*_test_<pid>/` | **아님**. 스위트의 `_hash_user_save` 비교는 부팅 뒤에 첫 해시를 재므로 부팅 쓰기를 못 잡는다 |
| 06 | `tests/services/run_services_on_head.ps1`(30·35) | 아카이브 사본, 이름 그대로 / 실제 | 예 | 같음 | **아님** |
| 07 | `tools/qa/run_acceptance.ps1`(65·76·82·97; 기본 `.`, `-Head`는 `qa07_head` 사본) | 두 경우 모두 이름 그대로 / 실제 | 예 | `qa07/…`(스위트별 세이브·faults·purchase) | **아님** |
| 08 | `tools/perf/run_perf.ps1`(44·49·95·117~123), `tests/performance/test_bench_semantics.ps1`(26) | `--path .` / 실제 | 예 | `perf/perf_save.json` | **아님** |
| 08 | `tools/perf/ab_retest.ps1`(77·81), `c11_window.ps1`(61·97·116·128·130) | 아카이브 사본, 이름 그대로 / 실제 | 예 | `perf/…` | **아님** |
| 10 | `probes/run_content_migration.ps1`, `run_economy_policies.ps1`, `.local_inspect/run_snapshot.ps1` | 사본, 이름 `Probe10 …`로 변경 | 자체 폴더 | 자체 폴더 | **격리** |
- 요약: 격리된 쪽은 03·05·10이다. 01·02(진단 실행 안내)·04·06·07·08의 Godot 실행은 실제 폴더를 쓴다.

**(3) 공통 격리 방법(권고)**
- **방법 A(권장, 모든 실행에 적용 가능): 자식 프로세스에만 비공개 APPDATA를 준다.**
  - PowerShell 예: `$old=$env:APPDATA; $env:APPDATA=$priv; & $godot …; $env:APPDATA=$old`. `Start-Process`도 현재 환경을 물려받는다.
  - 또는 래퍼 `docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(...)`를 쓴다.
  - 엔진이 APPDATA만 보므로 user://는 실제 폴더로 갈 수 없다. 공유 트리, 사본, 화면 실행 모두 같은 방식으로 된다.
  - `--import`도 이 방식이면 편집기 설정을 비공개 폴더에 만든다.
- 방법 B(사본 전용): 사본의 project.godot에서 `config/name`을 바꾸거나(10, 02 "It02 …", 03 "… snapshot"), `use_custom_user_dir`를 켠다(05). 공유 project.godot은 절대 고치지 않는다(app.gd 83행 주석: 이름을 바꾸면 데스크톱 user:// 폴더가 옮겨진다).
- 방법 C(불충분): 스크립트 안에서 `save.path`를 바꾸는 것만으로는 부족하다. 부팅 쓰기(X1·X3)와 다른 파일 쓰기를 막지 못한다.
- 확인 방법:
  - 1순위는 그 실행의 `godot.log`가 비공개 폴더에 생겼는지(래퍼가 자동으로 확인).
  - 2순위는 실행 전후 실제 `save.json`·`.bak` 해시 비교다. 다른 Godot 프로세스가 같이 돌면 남의 쓰기 때문에 의미가 없으므로, 래퍼는 그 수를 함께 적는다.
  - "Godot 명령은 사용자 폴더 격리 없이 실행하지 않는다"를 각 문서의 Run 안내에 적는다.
- 02 엔진 쪽 방어(선택, 02 판단): `-s`/`--script` 실행이거나 `OS.get_cmdline_user_args()`에 `--isolated-save`가 있으면, Save가 부팅 때 실제 `user://save.json`을 다시 쓰지 않게 한다. 대가: 그 경로로 R5를 확인하는 테스트는 비공개 폴더에서 해야 한다.

**(4) F2 재확인**: save.gd의 마지막 변경은 여전히 7f2886c(18:43)다. F2 수정은 아직 없으므로 **대기**한다. 수정이 들어오면 `probe_r5_cases.gd`의 F2a·F2b를 다시 돌려 9/9를 확인한다.
**(5) .gd.uid**: `probe_r5_cases.gd.uid`(uid://dgt02sxyrkkqk)와 `probe_noop_boot.gd.uid`(uid://b36hgdlu6xa1n)는 비공개 APPDATA에서 한 깨끗한 import(이름 그대로인 HEAD 사본)로 만들었다. 저장소의 다른 uid와 겹치지 않는다(`git grep` 0건).

### 9.18 실제 사용자 폴더 백업, 업데이트·다운그레이드 실측, D26 결정 요청 (v0.27)
**(1) 실제 사용자 폴더 백업 (원본은 읽기만 함)**
- 19:13:53 KST에 `robocopy /E /COPY:DAT`로 `%APPDATA%\Godot\app_userdata\Lane Defence` 전체를 `%LOCALAPPDATA%\defence_userdata_backup\20261031-191353\Lane Defence`에 복사했다. 이 PC에만 있고 git에는 넣지 않았다.
- 결과: 파일 299개, 997,261,387바이트(대부분 `qa07/` 214개 996 MB, 07 캡처). robocopy 종료 코드 1(복사 성공).
- 복사 직후 원본과 SHA-256을 대조했다. 298개가 같았다. 다른 1개는 `logs/godot.log`로, 다른 작업자의 Godot이 쓰는 중이라 열리지 않았다.
  - `save.json`: 1,723바이트, 19:11:11, SHA-256 06ADA98F…2A53, 같음.
  - `save.json.bak`: 19:10:11, A2BE000A…372C, 같음.
- 목록(경로·크기·수정 시각·SHA-256, 내용 없음): `docs/research/systems/evidence/userdata_backup_20261031-191353/MANIFEST.tsv`.
- **복원 방법**(필요할 때만, 사용자 결정 후. 이번에는 실행하지 않음):
  1. 모든 Godot 프로세스를 끝낸다(`Get-Process Godot*`가 0개).
  2. 현재 폴더를 지우지 말고 이름을 바꾼다: `Rename-Item "$env:APPDATA\Godot\app_userdata\Lane Defence" "Lane Defence.before-restore-<시각>"`.
  3. `robocopy "$env:LOCALAPPDATA\defence_userdata_backup\20261031-191353\Lane Defence" "$env:APPDATA\Godot\app_userdata\Lane Defence" /E /COPY:DAT`.
  4. MANIFEST.tsv의 `save.json`·`save.json.bak` SHA-256과 대조한다.
  5. 세이브만 되돌리려면 2~3 대신 그 두 파일만 복사한다.
  - 복원한 뒤 다른 작업자가 격리 없이 Godot을 실행하면 다시 바뀐다(§9.17). 그래서 담당별 격리가 먼저다.

**(2) X3를 업데이트 시나리오로 다시 측정 (실제 부팅, 비공개 APPDATA, `probes/probe_update_scenario.gd`)**
- v1은 HEAD 45c05f0 데이터다(출시본 가정). v2는 v1에서 근접·원거리 상한을 5→3으로 낮추고 일꾼 업그레이드를 meta.json에서 지운 데이터다.
- 진행 세이브는 v1에서 실제 `buy_upgrade`로 만들었다. 각 단계는 별도 프로세스 부팅이고, 이전은 플레이어 기기에서처럼 Save 자동 로드가 부팅 중에 한다.
| 단계 | 디스크 main | 디스크 .bak | 플레이어에게 보이는 것 |
|---|---|---|---|
| S1 v1에서 진행 | 근접 L5, 원거리 L4, 일꾼 L4, 코인 750 (rev 11, v1 버전) | rev 10 | — |
| S2 v2 첫 부팅(업데이트) | 근접 **L3**(+350), 원거리 **L3**(+160), 일꾼 L4 그대로(효과 없음, 환불 0), 코인 **1,260** (rev 12, v2 버전) | **S1 전체**(업데이트 전 상태가 남은 유일한 사본) | 토스트·안내 **없음** |
| S3 v2에서 일반 저장 1회(설정 변경) | S2와 같음 (rev 13) | **S2** → 업데이트 전 상태가 디스크에서 사라짐 | 없음 |
| S4 S3 뒤 v1로 되돌림(다운그레이드) | L3 / L3 / 일꾼 L4(다시 효과 있음), 코인 1,260, v1 버전으로 다시 기록(rev 14) | S3 | 없음. **레벨은 자동으로 돌아오지 않는다** |
| S5 S4에서 플레이어가 다시 구매 | 근접 L4·L5와 원거리 L4를 v1 가격 510에 사면 **L5/L4/L4, 코인 750 = S1과 같음** | — | 직접 다시 사야 함 |
| S4b S2 직후(일반 저장 전) v1로 되돌림 | L3 / L3 / L4, 1,260, v1 버전(rev 13) | **S2**. 되돌림 부팅 자체가 .bak을 돌려서 S1 사본이 사라짐 | 없음 |
- 사라지는 것:
  - 상한을 넘는 레벨의 힘(근접 L4·L5, 원거리 L4)이 사라진다. 환불액은 낸 가격과 같다(가격 변경이 없었으므로).
  - 지운 업그레이드(일꾼)는 레벨이 효과 없이 남고 환불이 없다(420 상당).
  - 업데이트 전 세이브 사본은 다음 저장 한 번(S3)이나 되돌림 부팅(S4b)으로 없어진다.
- 복구: 자동 복구는 없다. 환불받은 코인을 쓰지 않았고 가격이 같다면 플레이어가 다시 사서 같은 상태가 된다(S5). 환불 코인을 다른 데 썼다면 되돌릴 수 없다.
- 안내 확인:
  - 런타임: S1~S5에서 부팅 뒤 `Events.toast`가 0건이다.
  - 코드: App이 부팅 때 내는 토스트는 `save_recovered`·`save_read_only`뿐이다(app.gd 117·119행). `migration_log`를 읽는 UI가 없다(`git grep` 0건). `data/text`에 환불·업데이트 문구 키가 0개다.
  - 메뉴 화면은 토스트를 표시하지 못한다(§9.12).
- 다운그레이드 차단: 없다. 두 데이터 모두 세이브 스키마 `version` 1이라 read_only가 켜지지 않는다.
  - Play는 낮은 versionCode 설치를 보통 막는다. 그러므로 현실의 "되돌리기"는 v1 데이터를 새 버전으로 다시 내는 것이다. 이때도 S4와 같이 레벨은 돌아오지 않고 코인만 남는다(추론, 실기기 미실시).

**(3) 요청**: 01에는 D26 결정(상한 하향 환불액, 폐지 업그레이드, 안내 문구, 다운그레이드 정책)을, 02에는 이전 전 백업 보존·안내 신호를 보냈다(요청 파일 v0.27). 04에는 안내를 표시할 경로가 필요하다는 점만 알렸다.
**(4) F2**: save.gd가 여전히 7f2886c여서 **대기**한다.
**(5) uid**: `probe_update_scenario.gd.uid`(uid://cmid5vrog0el5)는 비공개 APPDATA에서 한 깨끗한 import로 만들었고, 다른 uid와 겹치지 않는다.

### 9.19 실제 사용자 폴더 감시(읽기 전용) 30분과 담당별 쓰기 증거 (v0.28)
**도구**: `docs/research/systems/probes/watch_userdata.ps1`. 감시하는 폴더에서는 아무것도 지우거나 고치지 않는다.
- 5초마다(`-ProcIntervalSec`):
  - Godot 프로세스(시작 시각, 명령줄, 부모·조부모 명령줄)를 CIM으로 읽는다.
  - 실제 `logs/` 폴더의 새 회전 로그 이름을 확인한다.
  - `save.json`·`.bak`의 수정 시각을 확인한다.
- 5분마다(`-FileIntervalSec`) 폴더 전체 목록(경로·크기·시각)과 `save.json`/`.bak` SHA-256을 비교한다.
- 핵심 증거는 **로그 회전**이다. Godot은 새 실행이 시작될 때 `user://logs/godot.log`를 `godot<시작 시각>.log`로 바꾼다. 따라서 실제 폴더에 새 회전 로그가 생기면 그 시각에 시작한 실행이 실제 폴더를 썼다는 뜻이다. 시작 시각이 ±2초 안에 같은 프로세스를 찾으면 명령줄과 담당까지 특정된다.
  - 담당 추정 순서: Godot 명령의 `--path`·`-s`에 든 표지(qa07, ui04, art03, bd02, multi_seed_sim, tests/…)를 먼저 보고, 없으면 부모 명령줄을 본다.
- 처음 시작한 백그라운드 실행은 출력 없이 사라졌다(원인 미확인). 그래서 19:41:12에 별도 프로세스로 다시 시작했다. 감시 창은 **19:41:12~20:11:13**(5분 × 6회)이다. 그 전에 19:25~19:29에 1분짜리 시험 실행 두 번을 했다.

**결과**
| 구간 | 실제 폴더를 쓴 실행(로그 회전·시작 시각 일치) | save.json/.bak 쓰기 |
|---|---|---|
| 19:22~19:29 (시험 실행 두 번과 그 직전 회전 기록) | **01** 19:22:12 `--path . -s %TEMP%\multi_seed_sim.gd …` · **07** 19:23:21·19:26:10 `--path %TEMP%\qa07_head -s res://tests/acceptance/probe_balance.gd` · **04** 19:25:57 `ui04_gate_192515_60012 -s res://tests/ui/test_ui.gd`, 19:26:01 같은 사본 `test_ui_integration.gd`(verify_and_publish) · 19:29:02 회전은 **미귀속**(v0.29 정정). 시작 시각이 같은 표본 프로세스는 03의 `art03_imp` 화면 실행 하나뿐이었다. 그러나 03 회신(A1)에 따르면 그 사본의 `config/name`은 "Lane Defence art03 snapshot"이었고, 셰이더 캐시가 비공개 APPDATA에 생겼다. 그 실행이 실제 `Lane Defence` 로그를 회전시킬 수 없으므로, 5초 표본 간격보다 짧은 다른 실행으로 본다 | save.json 19:25:58·19:28:30·19:29:03, .bak 19:23:46·19:25:58·19:28:30 |
| **19:41~20:11 감시 창** | **0건**. 그동안 본 Godot 실행 26개(콘솔·본체 쌍 포함): 02 `base_damage_probe`·`selftest`(`--path .`), 04 `test_ui_integration`(`--path .`), 07 `acceptance`(`--path .`)와 `qa07_head` probe_balance 4회, 08 `targeting_equivalence`(`--path .`) | **0건**. 299개 파일 목록, save 614A1FAC…·bak E4263BE6…가 6회 내내 같음 |
- 판정:
  - 19:41 이후 실행된 02·04·07·08의 Godot 실행은 실제 폴더를 쓰지 않았다(격리됨).
  - 같은 07 probe_balance 명령이 19:23·19:26에는 실제 로그를 회전시켰고 19:52~19:57에는 회전시키지 않았다. 실행 방식이 바뀐 것이다.
  - 01·03·05·06은 감시 창에 실행이 없어 확인하지 못했다.
- 저장소에 들어간 격리(origin/main, 20:11 기준):
  - 커밋됨: 08 `run_perf`·`test_bench_semantics`·`ab_retest`·`c11_window`(b0fb679), 05 `run_godot_checks`(c47654e), 04 `visible_launch`(aec9c1f, 옵션), 02 `selftest.gd` 안내(eceb9f4).
  - **아직 없음**: 01 `sweep.ps1`, 04 `run_tests`·`flake_probe`·`verify_and_publish`, 06 `run_services_suites`·`run_services_on_head`, 07 `run_acceptance`. 감시 창 동안 07·04 실행이 격리된 것은 실행하는 쪽의 수동 설정으로 보인다. 다음 실행에서 다시 샐 수 있다.
- 증거 파일: `docs/research/systems/evidence/userdata_watch_20261031/`.
  - `watch_30m_summary.md`(감시 창).
  - `smoke_192536_summary.md`·`smoke_192825_summary.md`(시험 실행). 첫 시험판은 회전 대조 기능이 생기기 전이라 담당 추정 범위가 넓다.

**qa07 996 MB의 원인(정정)**
- 정체는 캡처가 아니다. `qa07/faults/tp13.json.corrupt-<ts>` 19개(각 52,428,953바이트, 09:15~18:39)다.
- 07 `suite_faults.gd` 153~154행이 TP-13을 위해 50 MiB 세이브를 쓰면, Save가 `.corrupt-*`로 격리한 뒤 지우지 않는다. 실행할 때마다 약 50 MB씩 늘어난다.
- 07에 알렸다. 정리 여부는 07이 결정하고, 10은 지우지 않았다.

**F2**: save.gd가 여전히 7f2886c여서 **대기**한다.
**참고**: 01이 19:37에 D32(마이그레이션 환불·상한 규칙)와 D33(원거리 L5 보정)을 커밋했다(f01e9d5). 이번 작업 범위 밖이라 대조는 다음 작업에서 한다.

### 9.20 재개(23:00 KST) 후 손실 점검, 01 D32/D33 대조, HEAD 재실행, 재개 시간대 감시 (v0.29)
**손실 점검**
- `origin/checkpoint/quota-20261031-202729/10-research-systems`는 ae6f9af 위에 빈 커밋 30ecd09(20:29) 하나만 있다(파일 변경 0).
- 내 경로(docs/research/systems, 내 status·handoff·요청 파일)는 HEAD·작업 트리 모두 그 브랜치와 차이가 없다. **잃은 작업 없음.**
- 요청 파일의 QUOTA CHECKPOINT 문구는 지난 기록이라 멈추지 않았다.

**격리 방식 변경(내 파일)**: `run_economy_policies.ps1`·`run_content_migration.ps1`과 내 임시 구동 스크립트도 이제 Godot 자식에게 비공개 APPDATA를 준다. 이전에는 이름을 바꾼 사본만 썼다.
- 실행마다 비공개 폴더에 로그가 생기는 것을 확인했다(`logs_present=True`).
- 재개 시간대 감시와 그 뒤의 읽기 전용 검사(아래 (4))에서도 내 실행은 실제 폴더를 건드리지 않았다.

**(1) 01 D32/D33(f01e9d5) 대조**
| 결정 | 내 근거(§) | 현재 코드(save.gd 7f2886c) | 판정 / 남은 일 |
|---|---|---|---|
| D32(1) 상한 하향 환불 = 실제 지불액. 지불 기록 우선, 없으면 스냅샷 가격. 추가 보상·회수 없음 | §9.14 AB 권고, §9.16 R2m(스냅샷 350 vs 실제 410), v0.22 회수 금지 | 스냅샷 가격만 쓴다. 지불 기록(`upgrade_paid`)이 없다 | **방향 일치**. 02가 §9.14 A 형식(구매할 때 같은 원자 저장에 기록)을 구현해야 R2m이 410이 된다. 출시 전에 A가 들어가면 출시 세이브는 모두 기록을 갖는다. 기록도 스냅샷도 없는 경우(R5 이전 개발용 세이브)는 0 + `refund_unknown` 그대로 둬도 된다 |
| D32(2) 폐지 업그레이드 = 지불액 환불 후 삭제. 다시 생기면 L1부터 | §9.14 B 규칙, §9.16 R6r, §9.18 S2(일꾼 약 420 무환불) | 모르는 id로 보존, 환불 0 | **일치, 미구현**(02). 판정 기준을 정해야 한다: "세이브 스냅샷에는 있고 현재 meta에는 없으며 같은 target 대체가 없는 id". 주의: 롤백 출시본이 새 업그레이드를 모르면 그것도 폐지로 보고 환불·삭제한다. 가치는 보존되지만 다시 올리면 L1부터다 |
| D32(3) `notice.content_migrated` ko/en, 메뉴에서 1회 | §9.18 안내 0건 | 문구 키는 HEAD에 있다(ko "업데이트로 강화 상한이 바뀌어 {levels}개 레벨이 조정되었고 {coins} 골드를 돌려드렸습니다." / en 같은 뜻, 무결성 TEXT_PARITY 통과). `src/`에서 이 키를 쓰는 곳은 0건 | 문구 **일치**. 신호(02)와 메뉴 표시(04)가 남았다 |
| D32(4) 출시 후 max_level 하향·폐지 금지(주 규칙). 환불 경로는 개발·시험용 안전망 | §9.18 권고 (a) | 규칙을 확인하는 장치가 없다 | **일치**. 확인 도구로 `probes/release_guard.py`(정적, Godot 없음)를 만들었다. 출시 리비전과 후보의 meta.json·order.json을 비교한다. 결과는 아래 "출시 가드" |
| D32 (c) 거부(롤백 출시본 차단 안 함) | §9.18 S4·S4b | 다운그레이드 차단 없음 | 일치. 롤백하면 레벨은 돌아오지 않고 코인만 남는다(§9.18). 이 사실은 롤백 판단 자료로 남긴다 |
| D33(a) 원거리 hp_mult 0.15→0.18(안 1) | §9.16 안 1 | data에 반영(meta.json) | 아래 재실행 결과 참조 |
| D33(b) r05 enemy_scaling 1.2→1.25 | — | data에 반영 | 아래 기준표 참조 |
- 출시 가드 실행:
  - `--base e42f809`(D26 이전) → HEAD: ERROR 0 / WARN 0. 상한·id 변화가 없다.
  - §9.18 v2 모양(근접·원거리 5→3, 일꾼 삭제)을 `--head-meta`로 넣으면 `UPG_MAX_DOWN` 2건 + `UPG_REMOVED` 1건으로 exit 1이다.
  - 출시 태그가 생기면 `--base <태그>`로 데이터 커밋 전에 돌리도록 01에 제안한다(채택은 01·07 결정).

**(2) HEAD 재실행(비공개 APPDATA, 깨끗한 전체 사본 29d31be = data f01e9d5, save.gd 7f2886c)**: 모두 exit 0, SCRIPT ERROR 0건.
- 02 요청(eceb9f4 D29 battle_sim 변경 뒤):
  - `probe_upgrade_transaction` C1~C5·C5b·C7~C13 통과, **C6 8/8**.
  - `probe_battle_uid_dedup` **162 / 1**(중복 미적용).
  - 전투 결과와 저장 동작은 그대로다.
- 무결성 ERROR 0 / WARN 0 / INFO 0.
- 경제 흐름: 총비용 5,595, 01 `upgrade_budgets.json` 재현 일치. P1↔low, opt↔opt 차이 0건. r10 반복은 LOW 14/11/9, P2 7/6/5다.
- 카드−적 hp(라운드 진입, d09d740 r02~r04 재조정 + D33(b) 반영):
| | r02 | r03 | r04 | r05 | r06 | r10 |
|---|---|---|---|---|---|---|
| 적 hp 배율 | 1.10 | 1.15 | 1.15 | **1.25** | 1.10 | 1.275 |
| P0 | −0.10 | −0.15 | −0.15 | **−0.25** | −0.10 | −0.275 |
| P1(최저가 우선) | −0.10 | +0.01 | +0.008 | **−0.093** | +0.086 | +0.103 |
| P2 | +0.065 | +0.01 | +0.008 | −0.01 | +0.182 | +0.229 |
| opt | −0.025 | −0.05 | −0.037 | **−0.10** | +0.092 | +0.139 |
  - 이제 P1·opt에서 r03·r04는 0 근처이고 r05가 가장 큰 결손이다. §9.15의 반례(r02~r04 결손이 r05보다 큼)는 현재 데이터에서 사라졌고, "r05 = 첫 막힘"과 이 지표가 같은 방향이 됐다. 이 지표는 난이도 지표가 아니라는 단서는 그대로다.
- 100코인당 체감 지점(HEAD, ASSUME 지표) L4 / L5: 근접 6.9 / 6.3, **원거리 8.1 / 7.4**(D27 7.5 / 4.7), 탱크 9.4 / 7.6, **기동 8.3 / 6.7**, 공성 5.2 / 5.4, 영웅 6.5 / 5.3.
  - D33(a)로 원거리의 −37% 역전은 −9%로 줄었다. §9.16 안 1의 예측(−9%)과 같다.
  - 새로 보인 것: 기동은 D27에서 L5 > L4였는데 이제 L5가 19% 낮다. r02~r05 적 배율이 바뀌면서 기동이 처음 보이는 라운드 행의 타격 수가 달라졌다(행 단위로 분해하지는 않음).
  - L5 < L4 차이는 이제 원거리·근접 −9%, 기동·탱크 −19%, 영웅 −18%이고, 튀는 값이 없다. L5 비용이 L4보다 높은 비용 곡선 때문이다. 수정 요청은 하지 않는다(01 판단 자료로만 전달).

**(3) F2·X1**: save.gd가 여전히 7f2886c여서 **대기**한다(23:30 origin/main 07b90c5 기준). 02 회신(c6fbf1f)에 따르면 다음 save.gd 순서는 F2 → X1 → D32 → 이전 전 백업이다. 들어오면 `probe_r5_cases`(F2a·F2b, 9/9 기대)와 업데이트 시나리오(§9.18)를 `heavy_run.ps1` 안에서 하나씩 다시 돌린다.

**(4) 재개 시간대 감시와 23:08 블루스크린**
- 23:00:21에 30분 감시(`watch_userdata.ps1`)를 시작했다. **23:09:33(마지막 기록)에 PC 블루스크린(0x50)으로 중단**됐다.
  - 그때까지 5분 비교 1회(23:05:23)를 했고, 실제 폴더 쓰기 0건, 로그 회전 0건, 파일 299개 그대로였다.
  - 그 9분 동안 Godot 콘솔 실행 37개가 시작됐다(01·02·03·04·05·06·07·08과 10의 내 실행 3개, 23:02~23:03). 모두 격리되어 있었다.
  - 동시 실행 수와 블루스크린의 인과는 확인하지 않았다. 코디네이터 규칙에 따라 이후 무거운 실행은 PC 전체에서 하나씩만 한다.
- 새 규칙 때문에 1분 넘는 연속 감시는 잠금을 잡아 다른 담당의 실행을 30분 동안 막게 된다. 그래서 연속 감시 대신 **한 번에 끝나는 읽기 전용 검사** `probes/userdata_canary.ps1`(몇 초, Godot 없음)을 만들었다. 두 신호를 쓴다.
  1. 실제 `logs/`의 회전 로그 이름. 새 실행마다 시작 시각 이름이 하나씩 생긴다.
  2. 세이브 카나리아. R5 이후 데이터 버전이 다른 부팅은 save.json을 다시 쓴다(X1). 그러므로 실제 세이브의 content_version이 현재 데이터와 다르고 save.json이 데이터 커밋보다 오래됐다면, 그 커밋 이후 격리 없는 부팅은 없었다.
- 23:29 결과:
  - 실제 폴더의 가장 새 회전 로그는 **19:36:56**이다(그 직전 19:35:09 로그의 첫 줄은 01 밸런스 시뮬의 `[balance]`).
  - save.json 수정 시각은 **19:35:09**이고 content_version은 `c1-57b3d7bf44b0`이다. 이 값은 d09d740 데이터(19:30)의 CRLF 해시다.
  - 현재 데이터 f01e9d5(19:37:40)는 CRLF `c1-1a1d45c2fd91` / LF `c1-e8790a4f2e85`다.
  - 판정: **19:37 이후 지금(23:29)까지 실제 사용자 폴더에서 시작한 Godot 실행은 없고, 현재 데이터로 격리 없이 부팅한 Save도 없다.** 23:00~23:09의 동시 실행, 블루스크린, 재부팅 뒤 재개를 모두 포함한다.
  - 한계: `--log-file`로 로그 경로를 바꾼 실행은 신호 1에 안 잡힌다. 옛 데이터(d09d740)로 부팅하면 신호 2에 안 잡힌다.
- 러너 격리 커밋 현황(origin/main 07b90c5): 01 `sweep.ps1`(b06c1f3), 04 `run_tests`·`flake_probe`·`verify_and_publish`·APK·화면 실행(be2abb3), 06 서비스 러너 3개(29d31be), 08(b0fb679), 05(c47654e). **07 `run_acceptance.ps1`만 아직 없다**(17:26이 마지막 변경).
- §9.19 정정: 19:29:02 회전의 03 귀속을 철회했다(위 표). 03 회신에 따르면 그 실행은 이름을 바꾼 사본과 비공개 APPDATA를 썼다. 5초 표본 간격보다 짧은 다른 실행이 원인일 수 있다. 03은 19:05~19:20 일부 실행이 실제 APPDATA 아래 다른 폴더(`Lane Defence art03 snapshot`)를 썼다고 스스로 밝혔다. 플레이어 폴더는 아니다.
- 기존 잔여 파일(06 보고서 7개·`m3dbg1~3`, 07 TP-13 격리 사본 996 MB)은 그대로 있다. 실제 폴더에 쓰는 일이라 누가 지울지는 코디네이터 또는 사용자가 정한다. 백업(§9.18)이 있다.

**(5) 새 발견: content_version이 줄 끝 방식(CRLF/LF)에 따라 달라진다 (P3, 02)**
- `probes/content_version.py`(content.gd 해시를 정적으로 다시 구현)로 확인했다.
  - 같은 데이터 7b93d1f가 LF로는 `c1-a7b265ce4f6f`, CRLF로는 `c1-ea9c929ba40e`다. Godot이 사본에서 보고한 값은 CRLF 쪽이다.
  - 이 PC는 `core.autocrlf=true`라서 `git archive` 사본이 CRLF다. (v0.30 정정: 작업 트리의 data 21개는 현재 LF다. `git ls-files --eol`과 §9.21 참조.)
- 영향(추론):
  - 출시 빌드를 CRLF 체크아웃(이 PC)과 LF 체크아웃(CI·다른 PC)에서 번갈아 만들면, 데이터가 같아도 모든 플레이어 세이브가 "데이터 바뀜"으로 처리된다. 부팅 때 다시 저장하고(X1) 해금을 다시 계산하며 `.bak`이 회전한다.
  - 상한 변화가 없으면 레벨·코인은 바뀌지 않는다. 다만 §9.18처럼 업데이트 전 사본이 회전으로 사라진다.
- 제안: 해시 전에 바이트에서 `\r`을 빼거나, 파싱한 JSON을 정규화해 해시한다. 또는 출시 빌드는 한 가지 체크아웃 방식으로만 만든다는 규칙을 둔다. 02가 결정한다.

**검증 메모**: 블루스크린 뒤 내 작업 트리 파일 5개(분석 문서, 구동 스크립트 2개, release_guard.py, 임시 구동 스크립트)를 검사했다. NUL 0바이트이고 꼬리가 온전하며 UTF-8 엄격 디코딩도 통과했다. §9.20 (2)의 Godot 결과는 블루스크린 전(23:02~23:04)에 끝나 디스크에 남은 출력에서 읽었다. 그 뒤 origin/main에서 `src/`·`data/` 변경은 없다(29d31be..07b90c5). 그래서 다시 돌리지 않았다.

### 9.21 줄 끝(CRLF/LF)과 content_version: 엔진 실측, 출시물 바이트, 업데이트 재현, 정규화 위치 (v0.30)
기준은 HEAD 3e355a8이다(data = f01e9d5, save.gd·content.gd = 7f2886c). Godot 실행은 `coordination/heavy_run.ps1`(라벨 `10-eol-update-scenario`, 잠금 대기 203초, 23:43~23:44) 안에서 **한 번만** 했다. 비공개 APPDATA만 썼고, 실제 save.json 해시는 실행 전후 같았다(614A1FAC…).

**(1) 같은 커밋, 두 줄 끝 방식의 content_version**
- 꺼내기: `git -c core.autocrlf=true archive HEAD`(CRLF), 같은 사본의 `data/`만 `git -c core.autocrlf=false archive HEAD data`(LF)로 바꿨다. 두 사본은 data의 줄 끝만 다르다.
| 사본 | data 21개의 CR / LF 바이트 | 엔진 계산값(실제 `Content._compute_content_version`, 부팅한 Content 자동 로드가 보고) | 정적 재구현(`probes/content_version.py --dir`) |
|---|---|---|---|
| CRLF | 2,756 / 2,756 (21개 모두 CRLF) | **c1-1a1d45c2fd91** | c1-1a1d45c2fd91 |
| LF | 0 / 2,756 | **c1-e8790a4f2e85** | c1-e8790a4f2e85 |
- 정적 재구현은 두 경우 모두 엔진 값과 같다.
- 이 PC의 현재 작업 트리 data 21개는 **LF**다(`git ls-files --eol` = w/lf 21개, `--dir .` = c1-e8790a4f2e85). 따라서 지금 이 PC에서도 같은 커밋이 두 값을 갖는다. 작업 트리에서 하는 개발 실행(`--path .`)은 LF 값이고, `git archive` 사본·APK·AAB는 CRLF 값이다.
  - 실제 세이브의 값(19:35, d09d740 CRLF)은 그때 작업 트리 실행이 CRLF data를 봤다는 뜻이다.
  - pwsh 7의 `ConvertTo-Json`은 CRLF를 쓴다(시험: CR 6 / LF 6). PowerShell로 data를 고치면 작업 트리가 CRLF가 된다.

**(2) 출시물 안의 data 바이트 (압축 해제만, 설치 없음)**
- 06의 시험용 AAB는 실행 뒤 지워져 디스크에 없다(06 handoff: "delete %TEMP%\svc06_aab_*"). 그래서 04의 APK 두 개를 읽었다.
- 두 APK 모두 data를 `assets/data/**.json`에 개별 파일로 담는다(pck 없음).
| APK (빌드 시각) | JSON | CR / LF | 담긴 바이트의 content_version | 일치하는 커밋 |
|---|---|---|---|---|
| `build/qa/apk_q4probe/defence-debug.apk` (17:36) | 21 | 2,715 / 2,715, 21개 모두 CRLF | c1-bfe92b11d6e3 | **a262640의 CRLF 값과 정확히 같다**(LF 값은 c1-477f7918e894) |
| `build/qa/apk_head/defence-debug.apk` (09:03) | 21 | 2,560 / 2,560, 모두 CRLF | c1-e69f89ef205a | 67bf9ca의 CRLF 값과 같다 |
- 결론(사실): 지금까지 이 PC에서 만든 Android 출시물은 `git archive` 사본의 CRLF 바이트를 그대로 담는다. 기기는 이 바이트로 content_version을 계산한다. 이 두 APK는 R5 이전 빌드라 값을 계산하는 코드는 없지만, 담긴 바이트는 같은 방식으로 만들어진다.
- 실기기 미실시. 기기에서 `res://`가 APK의 `assets/`를 그대로 읽는다는 점은 Godot Android 내보내기 방식에 따른 추론이다.

**(3) 업데이트 재현: CRLF 출시본 → 같은 커밋의 LF 출시본 (같은 데이터)**
| 단계 | 부팅한 사본 | 이전 기록 | 디스크 main | .bak | 안내 |
|---|---|---|---|---|---|
| E1 출시 N(CRLF)에서 진행 | CRLF | — | rev 11, cv 1a1d…, 코인 750, 근접 L5·원거리 L4·일꾼 L4 | rev 10 | 0 |
| E2 출시 N+1(LF) 첫 부팅 | LF | 비어 있음(바꿀 것 없음) | **rev 12**, cv **e879…**, 레벨·코인 같음 | **rev 11 = E1** | 0 |
| E3 같은 LF 출시본 두 번째 부팅 | LF | 비어 있음 | rev 12 그대로(쓰지 않음) | rev 11 | 0 |
| E4 출시 N+2(다시 CRLF) | CRLF | 비어 있음 | **rev 13**, cv 1a1d… | **rev 12** | 0 |
- 사실: 데이터가 같아도 출시물의 줄 끝 방식이 바뀔 때마다 첫 부팅에서 세이브 전체가 다시 쓰이고 `.bak`이 한 칸 회전한다. 레벨·코인·해금은 그대로였고 안내는 없었다. 원인은 X1(바꿀 것이 없어도 로드 중 저장)이다.
- 추론(피해의 크기):
  - 바로 잃는 진행은 없다. `.bak`에는 같은 내용의 직전 상태가 들어간다.
  - 남는 위험은 세 가지다. (i) 부팅 때 불필요한 쓰기 1회(쓰는 도중 전원이 꺼질 위험 구간, §9.9). (ii) 02가 계획한 "이전 전 백업 최신 2개"가 버전만 바뀐 경우에도 생기면 진짜 이전 전 사본을 밀어낸다. (iii) 안내 신호를 "버전이 바뀜"에 걸면 거짓 안내가 뜬다. D32(3)는 레벨이 조정됐을 때만 안내하도록 했으므로 구현도 그 조건이어야 한다.
  - 지금은 04·06 빌드가 모두 이 PC의 `git archive`(CRLF)라서 출시물끼리는 일관된다. 다른 PC나 LF 기본값의 CI에서 빌드하는 순간 E2가 모든 플레이어에게 일어난다.

**(4) 정규화 위치 추천(02 결정): 해시 전에 `\r`(0x0D)을 빼는 쪽 하나**
- 근거:
  1. 줄 끝은 한 PC 안에서도 경로마다 다르다. 작업 트리는 LF, `git archive` 사본과 APK는 CRLF, PowerShell로 쓴 JSON은 CRLF다(위 (1)(2)). `.gitattributes eol=lf`는 git이 만드는 체크아웃·아카이브만 고친다. 도구가 작업 트리에 다시 쓴 CRLF, 작업 트리에서 직접 한 내보내기, 다른 저장소 설정은 막지 못한다. 해시 쪽 정규화는 바이트가 어디서 왔든 같은 값을 낸다.
  2. 바꿀 곳이 `content.gd`의 해시 입력 한 곳이다(`FileAccess.get_file_as_bytes(f)`에서 13 바이트를 빼고 `h.update`). JSON 문자열 안에는 날 CR이 올 수 없으므로(이스케이프 `\r`만 허용) 의미 있는 내용은 바뀌지 않는다.
  3. 출시 전이라 지금 바꾸면 대가가 가장 작다. 값이 한 번 바뀌어 개발용 세이브가 한 번 다시 쓰일 뿐이다. 출시 뒤에 바꾸면 그 자체가 모든 플레이어의 E2가 된다.
- `.gitattributes`는 따로 하면 좋은 위생 조치이지 이 문제의 해결책은 아니다. X1 수정(바꿀 것이 없으면 쓰지 않음)도 E2의 쓰기를 없애지만, content_version이 같은 데이터를 다르게 부르는 문제는 남는다. 이전 전 백업과 안내의 조건이 버전 비교에 묶이면 다시 드러난다.
- 02가 채택하면 `probes/content_version.py`와 `userdata_canary.ps1`도 같은 정규화로 바꾼다(10).

**사고 기록(10의 실수)**: 이 실행에서 내 출력 저장용 변수 이름 `$log`가 `heavy_run.ps1` 안의 같은 이름 변수와 겹쳤다. 그래서 `Tee-Object`가 공용 `coordination/.runtime/heavy_run.log`를 **덮어썼다**(23:43~23:44, git 무시 파일). 잠금 자체는 뮤텍스라 영향이 없다. 그러나 23:44 이전의 START/END 기록이 사라졌고 내 START 줄도 없어졌다. 더 고치지 않고 코디네이터에게 알렸다. 내가 그 전에 읽어 둔 마지막 4줄을 함께 전달했다. 재발 방지로, 앞으로 `heavy_run.ps1`에 넘기는 블록에서는 출력 경로를 고유한 이름(`$p10Out`)으로 쓰고 `-Append` 없이 공용 파일 이름을 쓰지 않는다.

### 9.22 정규화 해시(해시 전 `\r` 제거) 도입 전 호환성 공격 사례와 02 수용 기준 (v0.31)
**방법**
- 02의 코드와 실제 사용자 데이터는 고치지 않았다. 정규화 해시는 버리는 사본의 `src/core/content.gd` 안에서만 임시로 넣었다. 77행 `h.update(FileAccess.get_file_as_bytes(f))`를 "바이트 13을 뺀 배열로 `h.update`"로 바꿨고, 사본마다 패치가 들어간 것을 확인했다(`PATCH 1`).
- 구동 스크립트: `.local_inspect/run_norm_scenario.ps1`(git 무시). `coordination/heavy_run.ps1` 안에서 **한 번** 실행했다. 실행 블록은 `GetNewClosure()`로 감쌌고 변수 이름은 모두 `p10` 접두어를 썼다(라벨 `10-norm-hash-compat-rerun`, 00:25~00:26 KST, 잠금 대기 769초).
- 모든 부팅은 `isolated_godot.ps1`(비공개 APPDATA)로 했다. 11개 실행 모두 `isolated=True`, `real_save_changed_during_run=False`였고, 실제 save.json 해시는 전후 같았다(614A1FAC…).
- 첫 실행(00:09~00:11)은 내 구동 스크립트 버그로 **버렸다.** PowerShell 변수는 대소문자를 구분하지 않는다. 사본 경로 변수 `$D`가 바이트 확인 루프 변수 `$d`에 덮여, D·E·F 단계가 엉뚱한 사본을 부팅했다. 변수 이름을 바꿔 다시 돌렸다. 버린 출력은 `.local_inspect/norm_scenario_run1_discarded.txt`에 있다. 이것도 아래 heavy_run 사고와 같은 종류(이름 충돌)다.
- 기준: HEAD 1f34d87(data 4882771, content.gd·save.gd 7f2886c).

**사본(같은 커밋에서 하나씩 바꿈)과 값**: 정적 값은 `content_version.py --dir`의 raw(그대로)와 norm(`\r` 제거)이다. 엔진 값은 부팅한 Content가 보고한 값이다.
| 사본 | 코드 | data | CR / LF | 정적 raw / norm | 엔진 값 |
|---|---|---|---|---|---|
| A | 현재(raw) | CRLF(이 PC의 `git archive`) | 2,758 / 2,758 | 40bd… / 989c… | **c1-40bde75d24c2** |
| B | 정규화 | CRLF | 2,758 / 2,758 | 40bd… / 989c… | **c1-989c3422c910** |
| C | 정규화 | LF(`autocrlf=false` 내보내기) | 0 / 2,758 | 989c… / 989c… | c1-989c3422c910 |
| D | 정규화 | C + r05 `enemy_scaling.hp` 1.25→1.3(바이트 수정, 줄 끝 유지) | 0 | dc5b… | c1-dc5be06f314d |
| E | 정규화 | D + 근접 `max_level` 5→3 | 0 | 754e… | c1-754e6a16b123 |
| F | 정규화 | E의 meta.json을 같은 값으로 다시 정렬(들여쓰기만 바뀜) | 0 | 26f1… | c1-26f19e8f9efd |
- 정규화 엔진 값은 CRLF·LF 모두 같고, 정적 norm 값 및 LF raw 값과도 같다. 즉 `\r` 제거 도입 뒤의 값은 오늘의 LF raw 값과 같다.
  - LF로 찍힌 세이브(06의 LF 고정 AAB, 작업 트리 개발 실행)는 도입해도 바뀌지 않는다.
  - CRLF로 찍힌 세이브(04 APK, `git archive` 사본, 실제 사용자 폴더 세이브)만 한 번 바뀐다.

**측정(한 세이브로 차례로 부팅)**
| 단계 | 상황 | 이전 기록 | main rev / 레벨·코인 | 파일 쓰기 | .bak 내용 | 안내 |
|---|---|---|---|---|---|---|
| N1 | A에서 진행(출시 N, raw·CRLF) | — | 11 / 근접 L5·원거리 L4·일꾼 L4, 750 | — | rev 10 | — |
| **N2** | **정규화 빌드 첫 업데이트**(B, 데이터 같음) | 없음 | **12** / 같음 | **1회** | **N1 main과 바이트 동일**(업데이트 전 사본 보존) | 0 |
| N3 | 같은 빌드 다음 부팅 | 없음 | 12 | 없음(해시 동일) | 그대로 | 0 |
| **N4** | **줄 끝만 바뀐 빌드**(C, LF) | 없음 | 12 | **없음**(해시 동일) | 그대로(N1 사본 아직 보존) | 0 |
| N5 | 실제 값 변경(D, r05 적 hp) | 없음 | 13 / 같음 | 1회 | N2 상태 → **N1 사본 사라짐** | 0 |
| N5b | 다음 부팅 | 없음 | 13 | 없음 | 그대로 | 0 |
| N6 | 상한 하향(E, 근접 5→3) | `refund up_melee_basic L5->L3 +350` | 14 / 근접 L3, 1,100 | 1회 | N5 상태(L5, 750) = 이전 직전 사본 | **0**(안내 코드 없음) |
| N7 | 다음 부팅 | 없음 | 14 | 없음, 두 번째 환불 없음 | 그대로 | 0 |
| **N8** | **들여쓰기만 바뀐 빌드**(F) | 없음 | **15** / 같음 | **1회** | N6 상태 → **이전 직전(L5) 사본이 사라짐** | 0 |
| N9 | 정규화 전 빌드로 롤백(A, 원래 데이터, 근접 상한 5) | 없음 | 16 / **근접 L3 그대로, 1,100** | 1회 | N8 상태 | 0 |

**판정(사실)**
- `\r` 제거만으로 **줄 끝만 다른 빌드 사이의 재기록은 사라진다**(N4: 쓰기 0). §9.21의 E2 문제는 해결된다.
- 도입 첫 업데이트(N2)는 CRLF로 찍힌 세이브에 **한 번 쓴다.** 레벨·코인·해금은 그대로이고, `.bak`은 업데이트 전 파일과 바이트가 같다. 다음 부팅은 쓰지 않는다.
- 실제 값 변경(N5)과 상한 하향(N6)은 정규화 뒤에도 그대로 감지된다. 환불은 한 번만이다(N7).
- **남는 공격 면**
  1. **형식만 바뀐 데이터**(N8: 값이 같은데 들여쓰기만 다름)는 여전히 "데이터 바뀜"이다. X1 때문에 다시 쓰고 `.bak`을 돌려, 상한 하향 직전 사본(L5 상태)을 디스크에서 지운다. 데이터를 PowerShell `ConvertTo-Json`이나 다른 포매터로 다시 쓰면 바로 생긴다.
  2. 업데이트 전·이전 전 사본은 `.bak` 한 칸뿐이라, 다음 쓰기 한 번(N5·N8)으로 사라진다.
  3. 롤백(N9)은 레벨을 돌려주지 않고 다시 쓴다(§9.18과 같음).
  4. 어느 단계에서도 안내가 없다(D32(3) 미구현).

**기존 세이브·마이그레이션 위험(추론 포함)**
- 출시된 플레이어 세이브는 아직 없다(스토어 출시 전). 영향을 받는 것은 CRLF로 찍힌 개발·시험 세이브와 실제 사용자 폴더의 세이브(d09d740 CRLF 값, §9.20)다. 그 세이브들은 정규화 빌드를 처음 부팅할 때 한 번 다시 쓰이고, 진행은 바뀌지 않는다(N2 실측).
- 지금은 공식 빌드 경로가 둘로 갈려 있다. 06 시험용 AAB는 LF 고정(4bf8f74, 06 측정 `c1-e8790a4f2e85`), 04 APK 스크립트는 CRLF다(§9.21). 정규화 전에 두 경로의 출시본이 번갈아 나가면 §9.21 E2가 모든 플레이어에게 생긴다. 정규화 뒤에는 N4대로 생기지 않는다.
- 정규화를 출시 뒤에 넣으면 N2가 모든 CRLF 출시 세이브에 일어난다. 피해는 쓰기 1회와 `.bak` 회전이다. 출시 전에 넣으면 이 비용은 개발 세이브에만 든다.
- **실제 APK/AAB에서의 동작은 미검증이다.** 이번 측정은 데스크톱 헤드리스 부팅이다. 기기 설치와 기기 부팅을 하지 않았고, 정규화 코드를 넣은 APK/AAB도 만들지 않았다. APK 바이트 정적 확인(§9.21)과 06의 AAB 바이트 측정(06 기록, 10 미재검증)만 있다.

**02 수용 기준(정규화 + X1 + D32 구현 뒤, 10이 `heavy_run` 안에서 한 번 재실행. 지금은 모두 미확인)**
| ID | 조건 | 통과 기준 |
|---|---|---|
| AC1 | 같은 커밋의 CRLF·LF 사본 | 엔진 content_version 두 값이 같고 `content_version.py`의 norm 값과 같다 |
| AC2 | raw CRLF 값이 찍힌 세이브로 정규화 빌드 첫 부팅 | 레벨·코인·별·해금 그대로, `migration_log` 비어 있음, `content_migrated` 안내 없음. X1이 고쳐졌다면 **파일 바이트 불변**(새 값은 다음 일반 저장에서 기록). 고쳐지지 않았다면 쓰기 정확히 1회이고 `.bak` = 직전 main(바이트 동일) |
| AC3 | AC2 직후 다시 부팅 | 파일 바이트 불변 |
| AC4 | 줄 끝만 다른 빌드(CRLF↔LF) | 파일 바이트 불변, rev 불변 |
| AC5 | 상한과 무관한 값 변경 | 환불·안내 없음. X1이 고쳐졌다면 로드 중 쓰기 없음 |
| AC6 | 상한 하향 | D32대로 지불액 환불 1회, 다음 부팅 0회, 안내 1회(04 메뉴 표시), `save.pre-<옛 값>.json` 생성 |
| AC7 | AC6 뒤 형식만 바뀐 빌드(N8), 일반 저장 2회, 롤백 빌드(N9) | `save.pre-<옛 값>.json`이 그대로 남는다(내용 = 이전 직전 main). 형식만 바뀐 빌드는 안내·환불 없음. X1이 고쳐졌다면 로드 중 쓰기 없음 |
| AC8 | 롤백 빌드 | 충돌 없음, 레벨 복원 없음(설계대로, 문서화). X1이 고쳐졌다면 상한을 넘는 레벨이 없을 때 로드 중 쓰기 없음 |
| AC9 | 정규화 코드를 넣은 APK/AAB | 담긴 바이트의 norm 값 = 저장소 값. 기기에서 부팅한 값도 같다(에뮬레이터 또는 기기 필요, 지금은 미검증) |
- 순서 권고: 정규화와 X1을 **같은 커밋, 출시 전**에 넣는다. 그러면 AC2에서도 쓰기가 0이라 첫 업데이트 비용이 없다.
- 형식만 바뀐 경우(N8)는 정준 JSON 해시로도 막을 수 있다. 다만 파서 동작에 값이 묶인다. X1과 이전 전 백업 보존(AC7)으로 피해가 없어지므로 필수 요구로 두지 않는다(02 판단).

### 9.23 공용 heavy_run.log 덮어쓰기(23:43)의 원인과 재발 방지
- 원인(코드 읽기 + 재현): `coordination/heavy_run.ps1`은 호출자의 블록을 `& $Script`로 자기 스크립트 범위의 **자식 범위**에서 실행한다. PowerShell의 동적 범위 때문에 heavy_run의 스크립트 변수가 블록 안에서 그대로 보이고, 같은 이름의 호출자 변수를 가린다.
- `probes/heavy_run_scope_test.ps1` 결과: 테스트용 뮤텍스 이름을 쓴 사본에서 실행했다. 실제 잠금·실제 로그는 쓰지 않는다. 현재 파일 해시는 DC0686C7…다.
| 위험 | 현재 heavy_run.ps1 | 증상 |
|---|---|---|
| H1 `$log` 등 이름 가림 | **FAIL** | 블록의 `$log`가 공용 로그 경로가 되어 `Set-Content`/`Tee-Object`가 공용 로그를 덮어쓴다(23:43 사고와 같다). `$root`·`$start`·`$got`·`$mutex`도 보인다. 블록이 뮤텍스 객체를 직접 건드릴 수도 있다 |
| H2 `$ErrorActionPreference='Stop'` 상속 | **FAIL** | 호출자가 Continue여도 블록 안에서는 Stop이다. 없는 파일 `Get-Item` 같은 평범한 오류가 블록을 끝내 버린다 |
| H3 예외 시 END 없음 | **FAIL** | END는 성공 경로에서만 기록된다. 실제 로그에 `23:53:41 START 04-numbers-capture` 뒤 END 없이 9초 뒤 03 START가 있다. 원인이 H2인지는 확인하지 않았다 |
| H4 이전 종료 코드 상속 | **FAIL** | 블록이 cmdlet만 쓰면 그 전의 네이티브 종료 코드(시험: 3)를 END와 자기 종료 코드로 보고한다 |
- `heavy_run.ps1`은 git에 추적되지 않는다(`git status` = `??`). 공용 로그는 git 무시 파일이고 누구나 덮어쓸 수 있다.
- 제안안(코디네이터 결정, 설치하지 않음): `docs/research/systems/evidence/heavy_run_scope_20261101/heavy_run_proposed.ps1.txt`.
  - 내부 변수를 `$private:hr*`로 둔다. 시험해 보니 `$private:`로도 선호 변수는 숨겨지지 않았다. 그래서 스크립트 전역 `$ErrorActionPreference`를 없애고 필요한 호출에만 `-ErrorAction Stop`을 쓴다.
  - 블록 직전에 `$global:LASTEXITCODE = 0`을 둔다.
  - END는 `finally`에서 `status=ok|exception`과 함께 기록한다.
  - 같은 시험에서 **4/4 PASS**다. 결과는 `scope_test_results.txt`에 있다.
- 호출자 쪽 규칙(지금 바로 적용 가능): 블록을 `{ … }.GetNewClosure()`로 넘긴다(시험: 호출자 `$log` 유지). 블록 안 변수는 고유 접두어로 쓰고, 공용 파일 이름에는 쓰지 않는다. 10은 v0.31부터 이렇게 한다.

### 9.24 02 52f9fa3(D32·F2·X1·이전 전 백업·격리본 상한) 재검증 (v0.32)
**실행 조건**
- 모두 `coordination/heavy_run.ps1` 안에서 하나씩 실행했다. 깨끗한 `git archive` 사본(HEAD ≥ 52f9fa3, save.gd = 52f9fa3)과 비공개 APPDATA를 썼고, 실제 save.json은 모든 실행 전후 같았다(614A1FAC…).
- 요약 증거는 `docs/research/systems/evidence/save_d32_verify_20261101/results.txt`에 있다. 세이브 내용은 담지 않았다.
- **(c) 첫 시도는 무효다.** 도구 호출 하나가 잠금 대기(1,742초)와 실행을 함께 하다 30분 제한에 걸렸다. 그때 heavy_run 래퍼가 종료됐는데 자식 Godot은 잠금 밖에서 계속 돌았다. 01:49에 내가 멈췄고, 공용 로그에 NOTE를 덧붙였으며, 결과는 버렸다.
  - 그 뒤로 무거운 작업은 분리된 프로세스로 실행한다(`.local_inspect/hr_job.ps1`, 증거 폴더에 사본). 그 방식으로 다시 실행한 결과만 쓴다.
  - 01·02·05도 같은 일을 겪었다(공용 로그 NOTE 01:47~02:03). 코디네이터에게 H5로 보고했다.

**(a) `probe_r5_cases` + `probe_upgrade_transaction`** (heavy_run `10-v032-a-r5-cases-transaction`, 사본 67fd962)
- `probe_r5_cases` **9/9 PASS**: E1, E4j, E5, E6, E7, E8, **F2a, F2b**, DL. F2는 해결됐다.
  - D26/D32 차이 항목도 이제 일치한다(`matches_D26=true`).
  - R2m: 비용이 바뀐 뒤 상한을 낮추면 실제 지불액 160+250=**410**을 환불한다(1,644). 비용만 바뀐 부팅에서는 X1 때문에 스냅샷이 다시 찍히지 않아 옛 가격이 남은 결과다.
  - R6r: 폐지 업그레이드(일꾼 L4)는 **+420 환불 후 삭제**된다.
- `probe_upgrade_transaction`: C1~C13·C5b 모두 통과, **C6 8/8**.
- 파트 D(같은 content_version에서 손으로 고친 L9가 hp 2.20으로 남음)는 그대로다. 파일을 직접 고쳐야만 생기므로 P3이고, 02 선택 사항이다.

**(b) 업데이트 시나리오 §9.18 S1~S4b** (`run_update_scenario.ps1`, 래퍼 경유, v1 = HEAD 676b105, v2 = 근접·원거리 상한 3 + 일꾼 삭제)
| 단계 | 결과 |
|---|---|
| S1 v1 진행 | 근접 L5·원거리 L4·일꾼 L4, 750. `upgrade_paid` 기록됨(근접 60/100/160/190 …) |
| S2 v2 첫 부팅 | `retire up_worker +420`, `refund melee +350`, `refund ranged +160` → **1,680**, 일꾼 삭제. **`save.pre-c1-40bde75d24c2.json` = S1 상태(rev 11, L5, 750)**. `migration_notice {levels 6, coins 930}` 저장 |
| S3 일반 저장 | 이전 전 백업 그대로 |
| S4 v1 되돌림 | **쓰기 없음**(X1, rev 13 그대로). 레벨은 복원되지 않는다(설계대로) |
| S5 다시 구매 | 근접 L5·원거리 L4, 1,170(일꾼은 삭제됐으므로 L1) |
| S4b S2 직후 되돌림 | 쓰기 없음. 이전 전 백업 그대로 |
- §9.18과 비교하면 폐지 업그레이드 무환불, 업데이트 전 사본 유실(.bak 회전), 되돌림 부팅 재기록이 **모두 해결됐다.**

**(c) `run_content_migration.ps1`** (재시도 heavy_run `10-v032-c-content-migration-retry`, HEAD 1d359bc): **정정 기대값과 모두 일치한다.**
- M1: r08 잠김, r03 별 보존.
- M2: r02b·r03~r07 열림.
- M3·M5a: 불변.
- **M4: L3 / 1,584 / hp 1.30.**
- **M5b: up_toast_knight L5 / 1.60.**
- 모든 변이에서 다시 저장·로드한 결과가 같다. 원거리 hp 1.36은 D33(0.18) 반영 값이다.

**(d) AC1~AC9** (heavy_run `10-v032-d-ac1-ac9`, 사본 5a46675, `.local_inspect/run_ac_scenario.ps1` + 판정 스크립트 `probes/ac_evaluate.py`)
- 코드는 패치하지 않았다. 빌드는 data 바이트만 다르다: A = CRLF, C = LF, D = r05 값 변경, E = 근접 상한 3, F = E를 다시 정렬. 한 세이브로 S01~S12를 차례로 부팅했다.
| AC | 판정 | 측정 |
|---|---|---|
| AC1 같은 커밋 CRLF·LF의 엔진 값 동일 | **FAIL** | CRLF `c1-40bde75d24c2` ≠ LF `c1-989c3422c910`. `content.gd`가 7f2886c 그대로라 정규화가 구현되지 않았다 |
| AC2 줄 끝만 다른 빌드의 첫 부팅에서 진행 보존·무기록 | **PASS**(대체 측정) → **v0.34 정정: 모두 깬 세이브(unlocked 11)는 FAIL**(11→10 쓰기, §9.26) | 정규화 빌드가 없어서, 가장 가까운 전환(CRLF→LF 빌드)으로 쟀다. main 바이트 불변, 로그·안내 없음. X1 덕분이다 |
| AC3 다음 부팅 무기록 | **PASS** | 바이트 불변 |
| AC4 CRLF→LF→CRLF 빌드 | **PASS** | 세 번 모두 main 바이트·rev 11 불변. §9.21 E2 재기록은 X1로 사라졌다 |
| AC5 상한과 무관한 값 변경 | **PASS** | 쓰기·환불·안내 없음 |
| AC6 상한 하향 | **PASS** | 환불 350 = 실제 지불액(L4 160 + L5 190), 다음 부팅 0회. `save.pre-c1-40bde75d24c2.json`이 직전 main과 바이트 동일(0efc5b6c…). `migration_notice {levels 2, coins 350}`이 저장되고 `cmd_ack_content_migrated` 뒤 지워짐 |
| AC7 형식만 바뀐 빌드·일반 저장 2회·롤백 뒤에도 이전 전 백업 유지 | **PASS** | S06~S12 동안 백업 바이트 불변. 형식만 바뀐 부팅은 쓰기·안내·환불 없음 |
| AC8 롤백 빌드 | **PASS** | 쓰기 없음, 근접 L3 유지(복원 없음은 설계대로) |
| AC9 APK/AAB·기기 | **UNVERIFIED** | 10은 52f9fa3 코드로 APK/AAB를 만들거나 설치하지 않았고 기기 부팅도 하지 않았다 |
- 참고: 헤드리스 `-s` 실행에서는 메뉴가 붙지 않아 `Events.content_migrated` 신호가 12단계 모두 0건이었다. 안내 화면 경로(App 신호 → 04 메뉴 표시 → ack)는 이 측정으로 확인하지 않았다. 확인한 것은 세이브의 `migration_notice` 저장과 ack로 지워지는 데까지다.
- 남은 위험(추론): AC1이 FAIL이라 content_version은 여전히 빌드 경로(줄 끝)에 따라 다르다. X1 덕분에 그것만으로는 쓰기·환불이 생기지 않는다(AC2·AC4). 다만 백업 파일 이름, 안내의 `from/to`, `refund:<cv>:<id>` 키가 빌드 경로마다 다른 값으로 남는다. 환불은 레벨이 상한을 넘을 때만 일어나므로 이중 환불 경로는 찾지 못했다.

**카나리 전환(`probes/userdata_canary.ps1`)**: X1 때문에 격리 없는 부팅도 이제 세이브를 다시 쓰지 않는다. 그래서 "content_version이 다르면 부팅이 다시 썼을 것"이라는 신호는 더 쓸 수 없다.
- 새 방식: 기준선 파일(`-SaveBaseline`, git 무시 `.local_inspect/userdata_baseline.json`)과 비교한다. 대상은 save.json·.bak의 SHA-256·크기·수정 시각, 모든 파일의 크기·시각, 회전 로그 이름이다. `-Manifest`로 §9.18 백업 목록과도 비교할 수 있다.
- 00:57:29에 기준선을 만들었다. 02:42에 비교한 결과, **save.json·.bak 변경 0, 실제 폴더에서 시작한 Godot 실행 0**이었다. 다른 변경 214건은 모두 `qa07/*` 삭제다. 코디네이터 결정대로 07이 옮긴 것으로 보이지만, 07의 옮긴 위치는 확인하지 않았다(`%LOCALAPPDATA%\defence_userdata_quarantine`에는 06 항목만 보인다).

**heavy_run.ps1**: 코디네이터가 01:20에 제안안을 설치했다(sha256 52DD6E93…). `heavy_run_scope_test.ps1` 결과 **4/4 PASS**(이전 0/4). 파일은 여전히 git 미추적이다.

### 9.25 출시 빌드 두 경로(04 APK·06 AAB)의 content_version과 이전 안내 UI 경로 독립 검증 (v0.33)
**실행 조건**
- 무거운 실행은 `coordination/heavy_run_detached.ps1`로 작업 하나씩, 두 번만 했다.
  - `10-pkg-bytes`: 03:25:46~03:33:10, 잠금 대기 2,176초.
  - `10-notice-cases`: 03:33:10~03:34:29, 잠금 대기 2,339초.
  - 대기열에 다시 넣은 작업은 없다.
- 고정 커밋은 대기열에 넣을 때의 origin/main인 **eb8d5c43c48500399956a41786a66ac102ba1b2a**다. 03:4x의 origin/main(02ec60f)과 비교해도 data/, content.gd, save.gd, app.gd, main_menu.gd, notice_dialog.gd, 두 빌드 스크립트, 04 시험 파일에는 변경이 없다.
- 모든 Godot 실행은 비공개 APPDATA에서 돌았다. 04·06 빌드 스크립트는 자체 격리를 쓰고, 10 실행은 `isolated_godot.ps1`로 감쌌다(`isolated=true`·`real_save_changed_during_run=false` 11/11).
- 카나리: 기준선 02:49:27, 비교 03:36:33. **save.json·.bak 변경 0, 다른 파일 변경 0, 실제 폴더에서 시작한 실행 0**(614A1FAC560FBB78 그대로).
- 증거는 `docs/research/systems/evidence/pkg_notice_20261101/`에 있다(results.txt, 작업 스크립트 사본 2개, 06 스크립트가 쓴 aab_data_check_06.txt). 플레이어 세이브 내용은 없다. 아래 세이브는 모두 비공개 폴더에 만든 시험용이다.

**(1) 패키지 안 data 바이트: 판정 "두 경로가 같다"**
| 경로 | 명령 | data JSON | CR / LF | 담긴 바이트의 content_version |
|---|---|---|---|---|
| 04 APK | `tools/build/build_android_debug.ps1 -Ref eb8d5c4` (`git -c core.autocrlf=false -c core.eol=lf archive`, 1850c3f부터) | 21 (`assets/data/`) | **0 / 2,758** | **c1-989c3422c910** |
| 06 AAB | `tests/services/try_debug_aab.ps1 -Ref eb8d5c4 -TimeoutSec 900 -JavaHome <svc06 JDK 17> -Bundletool <1.18.3>` (LF 고정·CRLF면 exit 5, 4bf8f74부터) | 21 (`assetPackInstallTime/assets/data/`) | **0 / 2,758** | **c1-989c3422c910** |
| 저장소 eb8d5c4 | `probes/content_version.py eb8d5c4` | 21 | — | LF **c1-989c3422c910** / CRLF c1-40bde75d24c2 |
- 파일 단위로도 같다. APK 21개와 AAB 21개, 커밋 blob 21개가 바이트 단위로 모두 같다(합계 66,187 바이트).
- 06 스크립트가 같은 실행에서 따로 낸 값도 같다. AAB 바이트·blob·빌드 사본에서 돈 Godot 모두 c1-989c3422c910이었다.
- 패키지: APK sha256 5E4B0D07D1044D72…(59,345,027 B, apksigner Verifies), AAB D2B7548EA6C3017C…(59,233,123 B). 둘 다 git 무시 폴더 `.local_inspect/pkg_eb8d5c4/`에 있다.
- **10 도구 오류 1건 정정**: 작업 안의 첫 AAB 측정은 `files 0`, `c1-e3b0c44298fc`(빈 입력의 SHA-256)였다. 내 `content_version.py`가 `base/assets/data/`만 찾았기 때문이다. Godot AAB는 프로젝트 파일을 설치 시 애셋 팩 `assetPackInstallTime/`에 넣는다(항목 330개, base는 116개). 도구가 `<모듈>/assets/data/` 한 곳을 찾고, 0개면 오류를 내도록 고친 뒤 같은 AAB를 다시 읽었다(zip 읽기만, 실행하지 않음).
- **두 경로가 다르면 생길 일**: 이번에는 해당하지 않는다. 다만 다른 경로가 여전히 CRLF를 낼 수 있으므로 실제 값을 남긴다. `-c` 없는 일반 `git archive`는 이 PC(core.autocrlf=true, .gitattributes 없음)에서 CRLF를 냈다(§9.21 측정).
  - eb8d5c4를 CRLF 빌드로 낸 뒤 LF 빌드로 업데이트해도 X1 덕분에 쓰기·환불·안내는 없다(§9.24 AC2·AC4).
  - 실제 상한 하향이 함께 오면 값이 갈린다. 이전 전 백업 이름은 `save.pre-c1-989c3422c910.json`과 `save.pre-c1-40bde75d24c2.json`, 안내 `from`은 c1-989c3422c910과 c1-40bde75d24c2로 달라진다. 환불 키는 새 버전 값을 쓰므로 `refund:<새 cv>:up_melee_basic`이 새 빌드의 줄 끝에 따라 달라진다.
- **AC9 기기 부분은 아직 미검증이다.** 10은 설치·에뮬레이터·실기기 부팅을 하지 않았다. 기기의 Godot이 `assetPackInstallTime`의 data를 `res://data/`로 읽고 같은 값을 계산한다는 것은 추론이다. 06은 3e355a8 AAB를 에뮬레이터에 설치했다고 적었지만(06 상태 00:58), 10은 그 결과를 확인하지 않았다.

**앞선 주장의 사실과 추론 구분**
| 앞선 주장 (절) | 근거 등급 | v0.33 결과 |
|---|---|---|
| `build/qa/apk_q4probe`(17:36)·`apk_head`(09:03)가 CRLF data를 담음 (§9.21) | **사실**(바이트 측정) | 그대로다. 둘 다 1850c3f 이전 스크립트로 만든 파일이다 |
| "`git archive` 사본·APK·AAB는 CRLF 값" (§9.21 (1)) | APK는 측정, AAB는 **추론**(06도 지워진 AAB를 같은 입력으로 추론) | 지금 스크립트에는 맞지 않는다. eb8d5c4의 APK·AAB는 둘 다 **LF로 측정**됐다. 일반 `git archive`가 CRLF라는 부분만 남는다 |
| "04·06 빌드가 모두 CRLF라 출시물끼리는 일관" (§9.21 (3)) | 그때 스크립트를 읽은 **추론** | 지금은 둘 다 LF로 일관된다(측정). 다른 PC·CI의 E2 위험은 두 스크립트가 `core.eol=lf`를 명시하므로 이 두 경로에서는 없어진다. 이 부분은 스크립트 읽기이고, 다른 PC에서는 실행하지 않았다 |
| 남는 위험: 백업 이름·`from/to`·환불 키가 빌드 경로마다 다름 (§9.24) | 조건부 **추론** | 04·06 두 경로 사이에서는 조건이 성립하지 않는다(측정). 일반 `git archive`나 CRLF 작업 트리에서 하는 내보내기에는 남는다 |
| 06: 3e355a8 AAB가 LF, c1-e8790a4f2e85 | **06의 측정** | 10은 3e355a8을 다시 재지 않았다. eb8d5c4에서는 10의 측정과 06 스크립트 출력이 같다 |
| 이 PC 작업 트리 data는 LF (§9.21) | 그때의 측정 | 03:4x에 다시 재도 CR 0, c1-989c3422c910이다. 다만 core.autocrlf=true이고 .gitattributes가 없으므로, 다음 체크아웃이나 PowerShell 쓰기로 바뀔 수 있다(추론) |
- 04 `tools/build/inspect_apk.py`는 data JSON 개수(21)만 보고 줄 끝이나 content_version은 보지 않는다. 06과 같은 CRLF 차단이 04 경로에는 없다. 지금 LF가 나오는 것은 archive 옵션 덕분이다.

**(2) 04 `tests/integration/test_migration_notice.gd`(2de6668) 검토와 실행**
| 질문 | 답 | 근거 |
|---|---|---|
| 실제 App과 04 메뉴를 띄우나 | **예** | 108행 `main.tscn` 인스턴스. 38~43행에서 `app.ui_layer`의 `main_menu.gd`를 찾는다. 116행에서 `notice_dialog.visible`과 문구를 비교한다 |
| 비공개 APPDATA에서 이전 세이브를 실제로 쓰고 읽나 | **절반** | 세이브 파일 `user://test_migration_notice_<pid>.json`은 실제로 쓰고, 디스크에서 다시 읽는다(52~57행 `_file_has_notice`). 그러나 데이터 변경은 메모리 안의 흉내다. 98~103행에서 `content.meta`를 바꾸고 `content_version = orig_cv + "-04test"`로 둔 뒤 `load_progress()`를 부른다. 실제 업데이트 첫 부팅의 순서(Save `_ready`가 App보다 먼저 이전)는 지나가지 않는다. 비공개 APPDATA는 시험 자체가 아니라 04 실행기가 준다(6행). 3행 안내 명령에는 격리가 없다 |
| ack 전에 종료하고 다시 켜면 다시 뜨나 | 프로세스 안에서만 | 59~65행 `_relaunch()`는 `load_progress()`, `_migration_notice_sent=false`, `show_screen(&"menu")`로 다시 켜기를 흉내 낸다. 프로세스 재시작은 없다 |
| ack 뒤 파일에서 지워지나 | **예** | 130행 디스크 확인, 132~133행 다시 켜도 안내 없음. 139~141행은 Android 뒤로가기 = ack |
- 비공개 APPDATA에서 1회 실행한 결과 **16/16 ok, exit 0**이었다. 문구는 "업데이트로 강화 상한이 바뀌어 1개 레벨이 조정되었고 190 골드를 돌려드렸습니다."였고, 판은 2줄로 잘리지 않았다. `to` 값은 실제 버전이 아니라 `c1-989c3422c910-04test`다.
- **발견 N1 (04, P3)**: 시험이 user://에 `test_migration_notice_<pid>.pre-c1-989c3422c910.json`(1,639 B)을 남긴다. `_finish`(150~151행)는 본 파일·.bak·.tmp만 지운다. 이름에 pid가 들어가서 save.gd의 최신 2개 정리에도 걸리지 않는다. 그래서 실행할 때마다 하나씩 쌓인다. 04 실행기에서는 비공개 폴더라 해가 없다. 3행 명령을 그대로 쓰면 실제 폴더에 쌓인다는 것은 추론이다(그렇게 실행하지 않았다).

**10 보완 탐침 `probes/probe_notice_cases.gd`**: 모든 단계를 별도 Godot 프로세스로 실제 부팅했다. data/ 파일이 정말로 다른 사본(E1 = 근접 상한 4, E2 = 상한 3, LF 유지)을 쓰고, 한 비공개 폴더의 기본 `user://save.json`을 이어 썼다. 화면 모양은 판정하지 않았고, 노드와 파일 상태만 봤다.
| 단계 | 부팅 | 이전 기록 | 메뉴 안내(보임 / 문구) | 파일 `migration_notice` | 이전 전 백업 |
|---|---|---|---|---|---|
| K1 원본에서 근접 L2~L5 구매 | A | — | — | 없음, 코인 1,490, rev 5 | — |
| K2 업데이트 1 첫 부팅, 닫지 않고 종료 | E1 | `refund L5->L4 +190` | 예 / "1개 레벨 … 190 골드" | `{1, 190, 989c…→5c3d…}` | `save.pre-c1-989c3422c910.json` = K1 파일 |
| K3 ack 전에 업데이트 2 | E2 | `refund L4->L3 +160` | 예 / "**2개** 레벨 … **350** 골드" | `{2, 350, from 989c…(처음), to c8c8…(마지막)}` | 위 + `save.pre-c1-5c3d62545182.json` = K2 파일 |
| K4 안내 중 일시정지(`APPLICATION_PAUSED`) | E2 | — | 예 / 그대로, ack 0 | 남음(App이 저장, rev 7→8) | 2개 그대로 |
| K5 진짜 재시작 | E2 | — | 예 / 다시 뜸, 신호 1회 | 남음, 파일 바이트 불변 | 그대로 |
| K6 닫기 | E2 | — | 닫힘, ack 1, `migration_acks` 1 | **지워짐**(rev 9) | 그대로 |
| K7 ack 뒤 재시작 | E2 | — | 안 뜸, 신호 0 | 없음, 바이트 불변 | 그대로 |
| L1 지불 기록·스냅샷 없는 옛 세이브(근접 L5) | A | — | — | 없음, 코인 1,000 | — |
| L2 그 세이브로 E2 첫 부팅 | E2 | `refund_unknown [4, 5]`, `+0`, `unlocked_round 6->3` | 예 / "2개 레벨이 조정되었고 **0 골드를 돌려드렸습니다**" | `{2, 0}` | `save.pre-c1-legacy0000.json` = L1 파일 |
- 판정: 두 번 연달아 온 업데이트는 합산된다(레벨 1+1, 코인 190+160, `from`은 처음 값, `to`는 마지막 값). 일시정지와 진짜 재시작 뒤에도 안내는 남고, 닫으면 파일에서 지워진다. 부팅 때 안내가 UI보다 먼저 파일에 저장되므로(K2 파일), 안내 중 강제 종료도 K5와 같은 결과일 것이다(추론, kill로는 시험하지 않음).
- **발견 N2 (01 문구·04 형식, P3)**: 환불이 0이어도 "0 골드를 돌려드렸습니다"가 뜬다. 지불 기록도 스냅샷도 없는 세이브에서만 생긴다. 52f9fa3 이후 세이브는 지불 기록이 있으므로, 출시 뒤 플레이어에게 생기려면 버그가 함께 있어야 한다(추론). 코인 0일 때 쓸 문구 키를 따로 두는 안을 제안한다(예: "업데이트로 강화 상한이 바뀌어 {levels}개 레벨이 조정되었습니다.").
- **관찰 N3 (01, 설계 질문)**: L2에서는 같은 이전이 `unlocked_round`를 6에서 3으로 낮췄는데, 안내는 업그레이드 레벨만 말한다. 이번 값은 내가 만든 세이브가 일관되지 않아서(별은 r01·r02뿐) 생겼다. 다만 라운드 순서가 바뀌는 업데이트(§9.24 (c) M1)에서는 플레이어 라운드가 말없이 잠길 수 있다. D32 안내 범위에 넣을지는 01이 정한다.
- 검사하지 않은 것:
  - 화면에 보이는 모습(헤드리스).
  - Android의 실제 onPause. `_notification`을 직접 불렀다.
  - 같은 세션에서 ack 전에 다른 화면으로 갔다가 메뉴로 돌아오는 경우. `main_menu.gd` 45~46행이 빌드 때 다시 읽으므로 다시 뜰 것으로 보인다(추론).
  - 영어 문구.

**(3) 02 정규화**: eb8d5c4..origin/main(03:4x 확인)에 `src/core/content.gd` 변경이 없다. 77행은 여전히 `h.update(FileAccess.get_file_as_bytes(f))`다. 그래서 AC1·AC4 재실행과 (1) 반복은 하지 않았다. AC1은 계속 FAIL이다(§9.24).

### 9.26 업데이트 뒤 라운드 재잠금의 원인, 에뮬레이터 AC9, `git archive` 줄 끝 위험 표 (v0.34)
**실행 조건**
- 03:55 블루스크린(0x3B) 때 내 작업 두 개(`10-emu-ac9` 03:52, `10-relock-repro` 03:55)는 대기열에만 있었다. heavy_run.log에 START가 없고, `10-relock-repro` 로그는 161바이트가 모두 NUL이다. 남은 결과가 없으므로 버릴 것도 없다. 크래시 직전에 쓰던 파일 4개(`probe_relock.gd`, `relock_variants.py`, `job_relock.ps1`, `job_emu_ac9.ps1`)는 NUL 0, UTF-8 정상, 끝까지 있었다.
- 06:57 재개 뒤 두 작업을 한 번씩만 다시 넣었다. 블루스크린 두 번이 GPU 작업 중에 났으므로 이렇게 줄였다.
  - 재잠금 작업: 헤드리스 import 1회, 그 뒤는 data만 바꾼 사본(JSON은 FileAccess로 읽으므로 다시 import하지 않음). 고친 코드 쪽 비교는 뺐다.
  - 에뮬레이터: `-no-window`, `-gpu swiftshader_indirect`(호스트 GPU를 쓰지 않음).
- `10-relock-repro` 07:14:58~07:18:03(잠금 대기 880초), `10-emu-ac9` 07:18:03~07:23:28(대기 1,060초).
- Godot 부팅 17회 모두 `isolated=true`, `real_save_changed_during_run=false`. 카나리 07:00:17·07:24:22: save.json·.bak과 다른 파일 변경 0(614A1FAC560FBB78).
- 증거: `evidence/relock_20261101/`(results.txt, 시험용 시드 세이브 3개, 작업 사본), `evidence/emu_ac9_20261101/`(results.txt, logcat 3개, 화면 2장, 작업 사본). 플레이어 세이브는 없다.

**(1) unlocked_round 하락의 원인: 확정**
- 코드: `src/core/save.gd`(f606801) `_apply_content_migration` 5단계, **506~517행**.
  - content_version이 바뀐 첫 부팅마다(세이브에 이전 content_version이 있을 때) unlocked_round를 별 기록만으로 다시 계산한다.
  - `order[i]`는 i == 0이거나, 그 라운드에 별이 있거나, `order[i-1]`에 별이 있을 때만 열린다. unlocked_round는 열린 앞부분의 길이다.
  - 처음으로 닫힌 라운드에서 계산을 멈추므로, 그 뒤에 있는 이미 깬 라운드도 함께 닫힌다.
  - 7f2886c(10-31 18:43)에서 들어왔고, 52f9fa3이 로그 줄 `unlocked_round a->b`를 붙였다.
- **규칙의 출처는 D32가 아니다.** DECISIONS.md D32는 업그레이드 환불·폐지·안내 문구·상한 하향 금지만 다루고, 해금 규칙은 DECISIONS.md 어디에도 없다.
  - 이 규칙은 **10이 v0.15 §9.6 "R5 최소 구현 계약" 2번으로 제안한 것**이고, 02는 그대로 구현했다.
  - 나는 라운드 1개를 끼워 넣는 경우(M2)만 확인했고, 연속 삽입·이름 변경·이동은 시험하지 않았다. 결함의 원인은 10의 명세다.
- v0.33 L2(6→3)의 원인: 내 시험 세이브가 unlocked 6인데 별은 r01·r02뿐이었다. 이런 세이브는 data가 어떻게 바뀌든 첫 부팅에서 6→3이 된다. en.json에 줄바꿈 1바이트만 더해도 그렇다(아래 I1).
  - 실제 플레이로는 이런 세이브가 생기지 않는다. unlocked_round를 올리는 곳은 `record_result`(327~345행)뿐이고, 이긴 라운드의 별도 같은 저장에서 기록한다. `git grep`로 다른 쓰기 경로를 찾지 못했다.

시드 세이브는 실제 `Save.record_result`와 `buy_upgrade`로 만들었다. 중간 진행 세이브(M)는 r01~r05의 별이 3/3/2/3/1이고 unlocked 6, 근접 L2, 빠른 유닛 L2다. 모든 업데이트는 같은 시드에서 첫 부팅이다.

| 업데이트(data만 바꾼 사본) | 이전 기록 | 뒤 unlocked | 열린 라운드 | **이미 깼는데 닫힌 라운드** | 안내 |
|---|---|---|---|---|---|
| 변경 없음 | — | 6 | r01~r06 | — | — |
| 근접 상한 5→4 | 없음(쓰기 없음) | 6 | r01~r06 | — | — |
| en.json 끝에 줄바꿈 1개(바이트만) | 없음(쓰기 없음) | 6 | r01~r06 | — | — |
| r03 삭제 | 6→5 | 5 | r01,r02,r04~r06 | — | 없음 |
| r02 뒤에 r02x 1개 삽입 | 6→7 | 7 | r01,r02,r02x,r03~r06 | — | 없음 |
| **r02 뒤에 r02x·r02y 2개 삽입** | **6→3** | 3 | r01,r02,r02x | **r03,r04,r05** (다음 라운드 r06도 닫힘) | **없음** |
| **r02x 1개 삽입 → 다음 업데이트에서 r02y 1개 더**(사이에 r02x를 깨지 않음) | 6→7, **7→3** | 3 | r01,r02,r02x | **r03,r04,r05** | 없음 |
| **r03을 순서 맨 뒤로 이동** | 6→5 | 5 | r01,r02,r04~r06 | **r03** | 없음 |
| **r03→r03n, r04→r04n 이름 변경, migrations.json 없음** | **6→3** | 3 | r01,r02,r03n | **r05**(r06도 닫힘). r03·r04의 별은 고아가 됨 | 없음 |
| 같은 이름 변경 + `round_renames` | 기록만(쓰기·백업) | 6 | r01,r02,r03n,r04n,r05,r06 | — | 없음 |
| 모두 깬 세이브(r01~r10 별 2, unlocked 11) + 바이트만 | **11→10**, 쓰기·백업 | 10 | 모두 | — | 없음 |
| I1 일관되지 않은 세이브(unlocked 6, 별 r01·r02) + 바이트만 | 6→3 | 3 | r01~r03 | — | 없음 |
| I2 같은 세이브 + 근접 상한 4 | 6→3 | 3 | r01~r03 | — | 없음 |
- 재잠금된 경우마다 이전 전 백업 `save.pre-c1-989c3422c910.json`이 시작 세이브와 바이트 동일하다(9e26138fb715). 별도 그대로 남는다. 그래서 순서를 되돌리거나 규칙을 고친 data 업데이트가 오면 다시 열린다(추론, 5단계가 별에서 다시 계산하므로).
  - 다만 408행 `if prev_cv == cur_cv: return` 때문에, 코드만 고치고 data를 그대로 두면 이미 잠긴 세이브는 고쳐지지 않는다(추론, 코드 읽기).
- 부수 영향: 업그레이드 잠금도 unlocked_round 숫자로 정한다(652~660행 `_upgrade_locked`: 유닛의 `unlock_round` > unlocked_round). 2개 삽입·이름 변경 뒤에는 이미 L2를 산 `up_fast`가 잠김이 된다. r03 삭제·이동 뒤에는 `up_siege`(L1)가 잠긴다.
- 모두 깬 세이브의 11→10은 라운드를 잃지는 않는다. 그러나 바이트만 바뀐 업데이트에도 쓰기와 백업이 생긴다. **§9.24 AC2 "줄 끝만 다른 빌드에서 무기록" PASS는 중간 진행 세이브에만 맞고, 모두 깬 세이브에서는 FAIL이다(정정).** 원인은 같은 5단계다. 라운드가 n개면 열린 앞부분은 최대 n인데, record_result는 마지막 라운드를 깨면 n+1을 저장한다.
- 정적 모델: `probes/release_guard.py`에 두 검사를 넣었다. 5단계 규칙을 그대로 옮겨 "기본 순서대로 k개를 깬 플레이어" 모두에 적용한다.
  - `ROUND_RELOCK`(ERROR): 깬 라운드가 닫힌다.
  - `ROUND_FRONTIER_MOVED`(WARN): 아직 안 깬 다음 라운드만 닫힌다.
  - 9개 변이에서 k=5 결과가 엔진과 모두 같았다. ERROR 수: 2개 삽입 7, 연속 삽입(원본 기준) 7, 이동 6, 이름 변경 5. 1개 삽입은 WARN 1이다(r02까지 깬 플레이어는 r03 대신 새 r02x를 먼저 해야 한다). 상한·바이트·삭제·`round_renames` 있는 이름 변경은 0이다. e42f809→f606801은 0건(기존 검사 회귀 없음).
  - 한계: 순서대로 깬 플레이어만 본다. 앞선 업데이트가 남긴 구멍(r02x를 안 깬 채 진행)은 그 이전 출시본을 `--base`로 따로 비교해야 잡힌다. 바로 앞 출시본과만 비교하면 연속 삽입 2단계는 0건이다.
- **판정: 결함이다(출시 전 수정, P1).** 실제 플레이로 만든 세이브도 다음 업데이트에서 이미 깬 라운드를 안내 없이 잃는다.
  - 라운드를 2개 이상 연속으로 끼워 넣을 때. 업데이트 두 번에 걸쳐 끼워 넣고 그 사이에 새 라운드를 깨지 않은 경우도 같다.
  - `round_renames` 없이 연속된 라운드 2개 이상의 이름을 바꿀 때.
  - 깬 라운드를 순서 뒤쪽으로 옮길 때.
  - 상한·비용·문구·바이트만 바뀌거나 라운드 1개를 삽입·삭제하는 업데이트로는 잃지 않는다.

**(2) AC9 기기 부분: 에뮬레이터 확인, 실기기 미검증**
- 기기는 `build/avd` LaneDefence_Phone이다. 이 작업이 직접 띄웠고(`-no-window -read-only -no-snapshot-save -no-snapshot-load -gpu swiftshader_indirect`, 포트 5594), 끝에 `adb emu kill`로 껐다. 남은 qemu는 0이고, 이 작업이 띄운 adb 서버도 껐다. 그 전에 돌던 다른 에뮬레이터는 없었다.
- sdk_gphone64_x86_64, Android 16, API 36, x86_64이고 부팅에 69초 걸렸다. 설치된 base.apk의 sha256은 로컬 eb8d5c4 APK와 같다(5E4B0D07D1044D72). AAB는 이 작업에서 설치하지 않았다.
- 세이브는 `run-as`로 `files/save.json`에 넣고 다시 읽었다. 시드 E1~E3은 시험용이다.

| 단계 | 기기에서 읽은 결과 |
|---|---|
| D0 새로 설치, 첫 실행 → HOME(App이 일시정지 때 저장) | content_version **c1-989c3422c910** = v0.33의 APK·AAB 바이트 값 = 저장소 LF 값. `content_snapshot.version` 같음 |
| E1 이전 버전 세이브(근접 상한 6, L6 지불 250) → 실행 | 환불 250: 코인 1,000→1,250, 근접 6→5. `migration_notice {levels 1, coins 250, from c1-0000000000e1, to c1-989c3422c910}`, 키 `refund:c1-989c3422c910:up_melee_basic`. `save.pre-c1-0000000000e1.json`이 넣은 세이브와 바이트 동일(DB4893796BBDFAC4) |
| E1b ack 전에 강제 종료 → 재실행 | 안내 남음, 파일 바이트 불변 |
| E1c Android 뒤로가기 | 안내 지워짐(rev 8→9) |
| E1d 재실행 | 안내 없음, 바이트 불변 |
| E2 모두 깬 세이브(unlocked 11) | 11→10, 쓰기·백업. 데스크톱 결과와 같다 |
| E3 지불 기록·스냅샷 없는 L6 | logcat `WARNING: [Save] content/refund_unknown up_melee_basic levels [6]`, 안내 coins 0 |
- 6번 실행 모두 `[App] boot ok`였고, 앱 프로세스의 크래시·ANR은 0이었다.
- 판정: content_version 계산, 이전 처리, 안내 저장·ack가 기기 안에서도 패키지 값·데스크톱 결과와 같다(**에뮬레이터 확인, 실기기 미검증**). AAB 설치 경로(설치 시 애셋 팩)는 이 작업에서 확인하지 않았다.
- **화면은 판정할 수 없다.** SwiftShader에서 매 실행 `SceneShaderGLES3`/`CanvasShaderGLES3: Program linking failed: Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`이 2~5건 났다. 게임 화면은 빈 남색이었고, 첫 실행에는 시스템 UI 응답 없음 창이 떴다(앱이 아니라 System UI).
  - 06이 호스트 GPU로 돌린 기록(`docs/services/evidence/logcat_godot_first_launch.txt`, NVIDIA)에는 이 오류가 0건이다. Godot 공개 이슈 #109550에도 같은 메시지가 SwiftShader 기기에서 보고됐다(S33).
  - 그래서 렌더러 한도 문제로 보이고, 게임 로직 결함은 아니다(추론). 실기기 GPU의 한도는 확인하지 않았다. Play 사전 출시 보고서가 SwiftShader 기기를 쓰면 같은 빈 화면이 나올 수 있다(추론).
- 화면이 그려지지 않아도 뒤로가기 입력은 처리됐다(E1c).

**(3) 저장소 안의 `git archive`·내보내기 호출 (f606801, 주석·문서 제외)**
- 이 PC의 줄 끝 설정: `core.autocrlf=true`가 시스템 gitconfig(`C:/Program Files/Git/etc/gitconfig`)에서 오고, `core.eol`은 없으며, `.gitattributes`도 없다(`git check-attr`: text·eol unspecified). 그래서 `-c core.autocrlf=false` 없는 `git archive`는 텍스트 파일을 CRLF로 낸다(§9.21 측정). 이 PC에서 새로 클론한 작업 트리도 CRLF가 된다(추론).

| 파일:줄 | 소유 | 용도 | 줄 끝 옵션 | data 포함·Godot 실행 | 위험 |
|---|---|---|---|---|---|
| tools/build/build_android_debug.ps1:25 | 04 | 디버그 APK(출시 경로) | **LF 고정** | 예 | 없음(v0.33 측정). CRLF 차단은 없음 |
| tests/services/try_debug_aab.ps1:20 | 06 | AAB(출시 경로) | **LF 고정**, CRLF면 exit 5 | 예 | 없음(v0.33 측정) |
| tools/build/verify_and_publish.ps1:21 | 04 | 게시 전 검사 | **LF 고정** | 예 | 없음 |
| tests/services/run_services_on_head.ps1:21 | 06 | 서비스 시험 | **LF 고정** | 예 | 없음 |
| tools/art/ui_art/ui_capture.ps1:38 | 06-art-ui | UI 캡처 | `core.autocrlf=false`만 | 예 | 지금은 LF(.gitattributes 없음). `core.eol=lf`도 붙이면 다른 경로와 같아짐(낮음) |
| tools/qa/run_acceptance.ps1:89 | 07 | 수용 시험 `-Head` | **없음** | 예(세이브·이전 시험 포함) | **중간**: 수용 시험이 출시물과 다른 content_version으로 돈다. 백업 이름·환불 키·안내 from/to를 비교하는 시험은 출시물과 다른 값을 본다 |
| tools/qa/art_compare.ps1:45 | 07 | 그래픽 비교 | 없음 | 예 | 낮음(그림만 비교) |
| tools/build/flake_probe.ps1:17 | 04 | 불안정 시험 탐지 | 없음 | 예 | 낮음 |
| tools/audio/run_godot_checks.ps1:42 | 05 | 소리 검사 | 없음(`git -C`) | 예 | 낮음 |
| tools/perf/ab_retest.ps1:36 | 08 | 성능 A/B | 없음 | 예 | 낮음(JSON 파싱량이 CR만큼 늘 뿐) |
| tools/perf/art_variant_ab.ps1:42 | 08 | 그림 변형 A/B | 없음 | 예 | 낮음 |
| tools/perf/drawcall_run.ps1:53 | 08 | 드로우콜 측정 | 없음 | 예 | 낮음 |
| tools/perf/c11_window.ps1:87 | 08 | 창 측정 | 없음 | 예 | 낮음 |
| tools/perf/asset_budget_check.py:78 | 08 | 용량 예산 | 없음 | data 포함, Godot 없음 | 낮음: 텍스트 파일만 줄 수만큼 커진다(data 66,187 B에 CR 2,758 B). 이미지·소리 무관 |
| docs/research/systems/probes/run_content_migration.ps1:19 | 10 | 콘텐츠 이전 시험 | 없음 → **v0.34에서 LF 고정** | 예 | 고침, 재실행 안 함 |
| docs/research/systems/probes/run_economy_policies.ps1:20 | 10 | 경제 정책 시험 | 없음 → **v0.34에서 LF 고정** | 예 | 고침, 재실행 안 함 |
- Godot 내보내기는 세 곳이다. `build_android_debug.ps1:49`와 `try_debug_aab.ps1:55`(`--export-debug`)는 LF로 고정한 사본에서 내보낸다. `tools/art/run_godot_pack_check.ps1:22`(`--export-pack`)는 작업 트리의 그림 파일 사본만 쓰고 data가 없어 content_version과 무관하다.
- 작업 트리(`--path .`)에서 내보내는 스크립트와 `--export-release` 스크립트는 아직 없다. 앞으로 만들 출시 빌드 스크립트가 남은 가장 큰 위험이다. 06 경로처럼 LF 고정과 CRLF 차단을 같이 넣거나, 02가 AC1(해시 정규화)을 고치면 이 위험이 없어진다.
- `.gitattributes`(`data/** text eol=lf`)는 위생 조치다. 그러나 `Publish-Task.ps1`의 소유 규칙에 이 파일의 담당이 없다(02의 루트 허용 목록에도 없음).

### 9.27 재잠금 수정 검증 준비, ID 기준 해제 저장안, SwiftShader 셰이더 한도 위험, AAB 에뮬레이터 설치 (v0.35)
**(1) 재잠금 수정 검증 준비**
- 준비물(f1af87e):
  - `probes/relock_cases.json`: 사례 25개. U1~U6 정의, 단계별 변형, 마지막 단계 기대값(must_open/must_locked), f606801 예측을 실행 전에 적었다.
  - `probes/relock_suite_job.ps1`: 대상 SHA는 `probes/relock_target.txt`의 첫 줄에서 읽는다.
  - `probes/relock_eval.py`: 판정 스크립트.
  - `relock_variants.py`에 변형을 더했다: 맨 앞 삽입, 같은 업데이트 안의 삭제+삽입, 이름 변경+이동, 세 번째 연속 삽입, 끝에 덧붙이기.
  - 시드도 더했다: 모두 깬 세이브, 새 세이브(깨기 전 저장), 세이브 없음, 이미 잠긴 세이브.
- f606801 실행(`10-relock-suite`, 07:43 대기열)은 이 판 작성 시점에 아직 잠금을 기다리는 중이다. **현재 결과는 아직 기록하지 않았다.**
- f606801 예측(코드 읽기와 정적 모델, 실행 전): 25개 중 12 FAIL이다. 2개 삽입, 연속 2·3회, 이동, 이름 변경+이동, map 없는 이름 변경, 모두 깬 세이브+바이트(U4), 모두 깬 세이브+2개 삽입, 새 세이브+맨 앞 삽입, 일관되지 않은 세이브 2개, 이미 잠긴 세이브+data 변경이 해당한다. 같은 data의 이미 잠긴 세이브는 INFO로 복구되지 않는다.

**(2) ID 기준 해제 저장안**: 별도 문서 `ID_UNLOCK_SAVE_DESIGN.md`에 썼다. 담긴 내용은 저장 필드 3안, 지금 세이브에서 옮기는 규칙, 408행 U6, 읽는 곳 목록, 스토어 되돌림 호환표다. 요약은 다음과 같다.
- 정적 모델(`probes/unlock_options_model.py`, Godot 미실행)로 사례 25개에 적용한 결과다. 지금 규칙은 12 FAIL, 숫자만 고치는 B'는 3 FAIL(라운드 이동 2, 재잠금 복구 1, 모두 U3), ID 집합 A는 0 FAIL이다. U6 사례 1개는 따로 INFO로 셌다.
- 추천은 A(덧붙이는 필드 `open_rounds`, VERSION 1 유지, 모든 로드 때 `_migrate`에서 계산, 줄지 않음)다. 반론으로는 비용(런타임에서 숫자를 직접 읽는 곳 6곳, 시험 30곳 이상)과, B'에 데이터 규칙 C를 더하면 충분하다는 안을 적었다. 결정은 02·01이 한다.
- VERSION을 2로 올리면 옛 빌드가 세이브를 읽기 전용으로 연다(save.gd 12·74행). 그러면 되돌림 빌드에서 한 플레이가 저장되지 않는다. 그래서 덧붙이기만 권했다.

**(3) SwiftShader에서 난 GLES3 셰이더 링크 실패: 실제 폰 위험 판단**
- 실패한 것은 **Godot 기본 셰이더**다. logcat의 실패 이름은 `SceneShaderGLES3`(엔진 시작 때 4건)와 `CanvasShaderGLES3`(첫 2D 그리기 때 1건)다. 우리 프로젝트에는 사용자 셰이더가 없다. `git ls-files '*.gdshader' '*.shader'` 0건이고, `ShaderMaterial`·`shader_type`·`CanvasItemMaterial` 사용도 0건이다. 렌더러는 `project.godot`의 `rendering_method`와 `rendering_method.mobile`이 모두 `gl_compatibility`다.
- 기기 쪽 사실: 기기는 `OpenGL ES 3.0 (OpenGL ES 3.0 SwiftShader 4.0.0.1) - Compatibility`라고 보고했다. 한도 261은 SwiftShader가 보고한 값이다. GLSL ES 3.x의 최소값은 224다(Khronos OpenGL-API 이슈 #59가 ESSL 3.10 §7.2를 인용, S34). 그러니 261은 규격상 정상 범위다.
- Godot 4.7.2 셰이더 원본(S35): `canvas.glsl` 조각 셰이더의 기본 블록 uniform은 sampler 7개와 uint 2개뿐이다. 큰 배열은 모두 uniform 블록(UBO)에 있다. `GlobalShaderUniformData`(vec4 × MAX_GLOBAL_SHADER_UNIFORMS), `CanvasData`, `LightData`(Light × MAX_LIGHTS, Light 하나가 vec4 8개 분량)가 그렇다.
  - 추론: `GL_MAX_FRAGMENT_UNIFORM_VECTORS`는 기본 블록 한도이고 UBO 멤버는 따로 센다(블록 크기 한도). 따라서 261을 넘었다는 보고는 에뮬레이터의 GLES 번역층이나 SwiftShader가 UBO 배열까지 같은 한도로 셌다는 뜻으로 보인다. 이 규격 구분은 이번에 원문으로 다시 확인하지 못했다(미검증).
- 비교 자료:
  - 06이 호스트 GPU(NVIDIA, 같은 에뮬레이터 번역층)로 돌린 logcat에는 이 오류가 0건이다.
  - Godot 공개 이슈 #109550(S33)도 SwiftShader 기기(Play 내부 테스트)에서 같은 메시지를 보고했다.
  - 공개 기기 값 DB(opengles.gpuinfo.org)는 값을 스크립트로만 보여 줘서 이번에 가져오지 못했다. 실제 Adreno·Mali·PowerVR 값은 **미검증**이다.
- 판단:
  - (사실) SwiftShader에서는 게임 화면이 그려지지 않는다.
  - (추론, 중간 확신) 하드웨어 GPU 폰에서 같은 오류가 날 위험은 낮다. 근거는 큰 배열이 UBO에 있다는 점과, 호스트 GPU 실행에서 0건이었다는 점이다.
  - (추론, 높은 확신) Play 사전 출시 보고서나 Firebase Test Lab처럼 SwiftShader 가상 기기를 쓰는 자동 시험은 빈 화면 스크린샷을 낼 수 있다. 그 결과를 실패로 오해하거나, 반대로 화면 검사가 무의미해진다.
- 확인 방법(08·04 요청):
  - 실제 폰 1대 이상에서 첫 실행 logcat에 `Program linking failed`가 없는지 본다.
  - 같은 기기의 `GL_MAX_FRAGMENT_UNIFORM_VECTORS`·`GL_MAX_UNIFORM_BLOCK_SIZE`를 기록한다(Godot `--verbose`나 adb로 GL 정보 확인).
  - SwiftShader에서 줄여 볼 수 있는지 확인하려면 MAX_LIGHTS·MAX_GLOBAL_SHADER_UNIFORMS를 정하는 프로젝트 설정을 낮춘 시험 사본 하나로 확인한다(설정 이름은 미검증).

**(4) AAB 에뮬레이터 설치**
- 로컬에 도구가 있다: `%LOCALAPPDATA%\svc06_tools\bundletool-all-1.18.3.jar`, JDK 17, 디버그 키스토어, v0.33의 eb8d5c4 AAB.
- 작업 `.local_inspect/job_emu_aab.ps1`: `bundletool build-apks --connected-device` 다음 `install-apks`로 설치하고, 설치된 분할 APK마다 data 바이트의 content_version을 잰다. 그 뒤 첫 실행과 E1·E3 시드를 돌린다. 에뮬레이터는 `-no-window`, SwiftShader, 포트 5596이다.
- 07:38에 대기열에 넣었고, 이 판 작성 시점에 아직 잠금을 기다리는 중이다. **결과는 아직 없다.**

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
| S21 | Godot 소스 drivers/unix/file_access_unix.cpp(flush = fflush), dir_access_unix.cpp(rename) | https://raw.githubusercontent.com/godotengine/godot/master/drivers/unix/file_access_unix.cpp · https://raw.githubusercontent.com/godotengine/godot/master/drivers/unix/dir_access_unix.cpp | master 기준. 4.7.2 태그와 Android 경로 미확인 |
| S22 | Android AtomicFile 레퍼런스 | https://developer.android.com/reference/android/util/AtomicFile | 우리 엔진이 쓰는 API가 아님. 비교 기준으로만 인용 |
| S23 | Godot 4.7.2-stable 소스(태그 = 커밋 ed1daf0bf001b6…, 우리 바이너리와 같음): file_access_unix.cpp, dir_access_unix.cpp, os_android.cpp, core/io/file_access.cpp·.h, core/core_bind.cpp | https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/unix/file_access_unix.cpp · https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/os_android.cpp · https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access.cpp | 소스 읽기. 실기기 동작은 미검증 |
| S24 | 랜덤 다이스 공식 도움말 센터 "🔐 계정" 섹션 | https://111percent.helpshift.com/hc/ko/3-random-dice-pvp-defense/section/20-account-4/ · https://111percent.helpshift.com/hc/ko/3-random-dice-pvp-defense/faq/809-account-transfer/ | 문서 게시일 표기 없음 |
| S25 | 게임듀오 서비스 이용약관(회사 공통) | https://gameduo.net/terms-of-service | 게임별 적용 범위 불명, "예시" 문구 |
| S26 | Linux 커널 문서 /proc/sys/vm (dirty writeback 조정값) | https://docs.kernel.org/admin-guide/sysctl/vm.html | 기본값과 Android 기기 값은 인용하지 않음 |
| S27 | 111퍼센트 운영정책 (2023.08.05), 랜덤다이스 도움말 센터 FAQ 747 | https://111percent.helpshift.com/hc/ko/3-random-dice-pvp-defense/faq/747-operation-policy-2023-08-05/ | 회사 공통 정책. 게임별 정책이 우선한다고 스스로 적음 |
| S28 | 랜덤다이스 이용약관(날짜 목록상 유일한 판 2021-07-24) | https://policy.111percent.net/10001/prod/terms-of-service/ko/index.html · 본문 https://policy.111percent.net/10001/prod/terms-of-service/ko/2021-07-24.html | Play 등록 정보가 링크한 약관. 복구 기한이 S27과 다름 |
| S29 | 랜덤다이스 도움말 센터 FAQ: 224(업데이트 버튼), 750(모든 상자, 25.02.20), 811(크루레이드 정산), 816(협동 카드 미지급), 843(시즌 랭킹 보상, 25.02.20). FAQ ID 1~860 전수 조회 결과 26건 | https://111percent.helpshift.com/hc/ko/3-random-dice-pvp-defense/faq/811-crew-raid-ranking-calculation-time-and-criteria-gmt9/ (다른 항목은 같은 경로에 ID-slug) | 대부분 게시일 표기 없음. ID 860 초과는 조회하지 않음 |
| S30 | Play "새로운 기능": 랜덤다이스(업데이트 2026-02-11), 아처키우기(업데이트 2026-09-17) | https://play.google.com/store/apps/details?id=com.percent.royaldice&hl=ko · https://play.google.com/store/apps/details?id=com.GameDuo.MadArcher&hl=ko | 최신 노트 하나만 보임. 이전 노트 기록 없음 |
| S31 | 게임듀오 자사 게임 페이지 "아처키우기" | https://gameduo.net/game/archer-forest | 게시일 없음. 공지 채널 링크 없음 |
| S32 | Godot 4.7.2-stable 소스: platform/windows/os_windows.cpp(get_config_path·get_data_path·get_user_data_dir, 2417~2425·2508행), core/os/os.cpp(OS::get_user_data_dir, 338~353행) | https://github.com/godotengine/godot/blob/4.7.2-stable/platform/windows/os_windows.cpp · https://github.com/godotengine/godot/blob/4.7.2-stable/core/os/os.cpp | 소스 읽기와 비공개 APPDATA 실험 X1~X3으로 확인. Android 경로와는 무관 |
| S33 | Godot 이슈 #109550 "Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS"(2025-08, 4.5 beta5, SwiftShader 기기의 Play 내부 테스트 보고) | https://github.com/godotengine/godot/issues/109550 | 2026-11-01 접근. 우리 4.7.2와 판이 다름. 원인·수정 여부는 확인하지 않음 |
| S34 | Khronos OpenGL-API 이슈 #59 "OpenGL ES 3.1 minimum value for Max Fragment Uniform Vectors?"(2019) | https://github.com/KhronosGroup/OpenGL-API/issues/59 | 2026-11-01 접근. ESSL 3.10 §7.2 = 224, ES 3.1 표 20.44 = 256이라는 불일치 보고. ES 3.0 원문은 직접 확인하지 않음 |
| S35 | Godot 4.7.2-stable `drivers/gles3/shaders/canvas.glsl`, `canvas_uniforms_inc.glsl` | https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/drivers/gles3/shaders/canvas.glsl · https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/drivers/gles3/shaders/canvas_uniforms_inc.glsl | 2026-11-01 접근. 소스 읽기. scene.glsl은 읽지 않음 |