# 런처 아이콘·타이틀 로고 기준 (06-art-ui, 2026-11-01 08:2x KST, 측정·다시 그리기 전에 적음)

대상: `assets/branding/launcher_*`(03이 10-31 19:06에 만든 것, `tools/art/launcher_icons.py`·`branding.py`),
`ui_title_ko`·`ui_title_en` 페이지(`logo_title_<loc>`, `_2line`). 홈 화면 이름은 Q4 확정값 ko "빵집 기사단", en "Bakery Knights".
게임 안 제목은 Q3 작업 제목 "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense". 기준 숫자는 이 프로젝트의 작업 기준이다.
실제 런처·실제 폰 확인은 하지 않는다(데스크톱 Python 측정만).

## 아이콘
| ID | 질문 | 기준 |
|---|---|---|
| B1 | 적응형 아이콘 안전 영역 | 108 dp 전경에서 지름 66 dp 원 밖의 불투명 픽셀 0(외곽선 포함). 마스크 4종(원·둥근 사각·squircle·물방울)에서 잘리는 핵심 픽셀 0 |
| B2 | 작게 줄였을 때 실루엣 | 48 dp와 36 dp(mdpi 기준 48·36 px, box 축소)에서 주인공 마스크 면적 ≥ 아이콘의 25 %, 주인공 평균 L*와 배경 평균 L* 차 ≥ 25, 주인공 대 곰팡이 ΔE76 ≥ 20(일반·protan·deutan) |
| B3 | 배경화면 대비 | 아이콘 바깥 가장자리 2 dp 띠 평균색 대 밝은 배경화면(#f2f2f2)·어두운 배경화면(#202124) WCAG ≥ 1.5:1 둘 다(아이콘 모양이 배경화면에서 보임) |
| B4 | 단색 테마 아이콘 | monochrome 층을 Android 13 테마 색 두 가지(밝은 #d8e2ff 위 #001a41, 어두운 #001a41 위 #d8e2ff)로 칠했을 때 48 dp에서 실루엣 면적 15–60 %, 주인공 머리(요리모자)와 몸이 하나의 덩어리로 끊기지 않음(연결 성분 ≤ 3) |
| B5 | 장르 아이콘과 구분 | 이미 관찰한 공식 스토어 아이콘 5개(Battle Cats, Cat War2, Stick War: Legacy, Grow Castle, Age of War 2, 512 px)와 48 dp 축소본 비교: 평균색 ΔE76 ≥ 15 그리고 16×16 L* 패턴 평균 차 ≥ 12, 각 게임과 모두 |
| B6 | 스토어 512·그래픽 이미지 | 같은 그림에서 만들 수 있음: 512 아이콘 64 그리드 ×8 정수배, 투명 0 px, 그래픽 이미지 1024×500 RGB(알파 없음), 크기 요구는 `docs/services/STORE_GRAPHICS.md` |

## 타이틀 로고
| ID | 질문 | 기준 |
|---|---|---|
| T1 | 잘림 | 393 dp(800×360 논리, 안전 영역 34·0·34·0) 메뉴에서 로고가 화면 폭의 92 % 이하, 한 줄이 안 맞으면 2줄 프레임으로 바뀌고 2줄도 92 % 이하 |
| T2 | 줄바꿈 위치 | 2줄은 콜론 위치에서만 나뉨: ko "빵집 기사단" / "곰팡이 디펜스", en "Bakery Knights" / "Mold Defense". 단어 중간 줄바꿈 0 |
| T3 | 작은 화면 가독성 | 393 dp 폰에서 글자 높이(한글 획 높이) ≥ 2.5 mm(1 논리 px = 0.1733 mm), 글자 면 픽셀 중 메뉴 하늘과 3:1 이상 ≥ 80 %(ui-art 1.0 C7, 지금 100 %) |
| T4 | 예산·계약 | `ui_title_ko`·`ui_title_en` 각 페이지 크기 그대로(메뉴 0.50 MiB 상한, 08 U8-1), 프레임 이름 그대로 |

## 지금 것 측정 (2026-11-01 08:22 KST, 다시 그리기 전) — `tools/art/ui_art/branding_audit.py`, `docs/art/evidence/ui_art/branding_before.json`
| ID | 값 | 판정 |
|---|---|---|
| B1 | 66 dp 원 밖 0 px, 마스크 4종 잘림 0 px | PASS |
| B2 | 48 dp: 주인공 면적 23.7 %, 배경과 ΔL* 33.4, 주인공 대 곰팡이 ΔE 27.6 / protan **18.5** / deutan 23.3. 36 dp: 24.2 %, 30.7, 25.6 / **18.2** / 22.8 | **FAIL** (면적 < 25 %, protan < 20) |
| B3 | 가장자리 대 밝은 배경화면 5.93–6.66:1, 어두운 배경화면 2.16–2.43:1 | PASS |
| B4 | 단색 층 48 dp 면적 27.3 %, 덩어리 1개 | PASS |
| B5 | 장르 아이콘 5개와 평균색 ΔE 24.7–44.4, 패턴 차 22.2–29.0 | PASS |
| B6 | 512 아이콘 512×512 RGBA 알파 최소 255, 그래픽 이미지 ko·en 1024×500 RGB | PASS (같은 그림에서 생성됨) |
| T1–T3 | 메뉴 캡처의 로고 범위 측정이 로고 밖 픽셀까지 잡아(ko 512×143) 믿을 수 없음 | 측정 다시 해야 함 |

다음: B2를 위해 주인공을 키우고(면적 ≥ 25 %) 곰팡이 덩어리 색을 protan에서도 갈리게 바꾼 뒤 같은 도구로 전후 비교한다.
T1–T3은 `title_block.gd`의 슬롯·정수배 규칙으로 계산하는 방식으로 바꿔 다시 잰다. 실제 런처·폰 확인은 하지 않았다.

## 다시 그린 뒤 (2026-11-01 08:3x KST) — 깨끗한 HEAD 복사본(f0c1879)에서 `launcher_icons.py` 실행, `branding_after.json`
바꾼 것(`tools/art/branding.py` `icon48_fg`): 요리모자 1 px 넓고 높게, 재킷 1 px 넓게, 망토 1 px 넓게, 곰팡이 덩어리를 세이지(t/z/l)에서
청곰팡이 청록(q/Q/d)으로. 감사 도구는 곰팡이 덩어리를 찾는 색 목록에 q/Q/d를 더했다(같은 물체를 찾기 위한 것, 기준은 그대로).

| ID | 전 | 후 | 판정 |
|---|---|---|---|
| B1 | 원 밖 0, 잘림 0 | 원 밖 0, 잘림 0 | PASS |
| B2 48 dp | 면적 23.7 %, ΔL* 33.4, protan 18.5 | 면적 25.1 %, ΔL* 34.7, 주인공 대 곰팡이 53.8 / protan 39.8 / deutan 50.5 | **PASS** |
| B2 36 dp | 24.2 %, 30.7, protan 18.2 | 25.7 %, 32.0, 50.3 / 37.6 / 47.6 | **PASS** |
| B3 | 밝은 5.93–6.66, 어두운 2.16–2.43 | 같음(배경 층 그대로) | PASS |
| B4 | 27.3 %, 1덩어리 | 28.8 %, 1덩어리 | PASS |
| B5 | ΔE 24.7–44.4, 패턴 22.2–29.0 | ΔE 22.9–42.2, 패턴 21.8–29.1 | PASS |
| B6 | 512 RGBA 알파 255, 그래픽 1024×500 RGB | 같은 그림에서 다시 생성됨(같은 크기·형식) | PASS |
| T1–T3 | 측정 방식 수정 필요 | 아직 안 함 | 미정 |

- 커밋한 것: `assets/branding/launcher_adaptive_foreground_432.png`, `launcher_adaptive_monochrome_432.png`, `launcher_main_192.png`
  (배경 층은 바뀌지 않음). 전후 그림: `docs/art/evidence/ui_art/branding/`.
- 커밋하지 않은 것: `launcher_icons.py`가 같이 다시 쓰는 `docs/art/branding/**`(스토어 512·그래픽 이미지·미리보기)와
  `docs/art/evidence/branding/launcher_metrics.json`. OWNERSHIP.md의 06 목록에 없는 경로라 담당 확인을 요청한다. 깨끗한 복사본에서는
  같은 그림에서 생성됨을 확인했다(B6).
- 바뀐 PNG는 Godot import를 다시 해야 기기에 반영된다(빌드 파이프라인의 `--import`). 실제 런처·실제 폰 확인은 하지 않았다.

## 정정과 스토어 그림 맞추기 (2026-11-01 08:4x KST)
- **정정:** 1f15719의 B1 "원 밖 0 px"는 틀렸다. 내 도구는 픽셀 중심으로 쟀고, 06-services `tests/services/check_store_graphics.py`는
  픽셀의 가장 먼 모서리로 잰다. 그 규칙으로는 망토 아래 외곽선 1 px가 66 dp 원 밖이었다(48 그리드 (7, 37)).
  `branding_audit.py` B1을 같은 규칙으로 바꿨고, 망토는 y ≥ 34에서 원래 폭으로 되돌렸다. 줄어든 면적은 장화 한 줄(`O`, y 38)로 메웠다.
- 다시 잰 값(깨끗한 HEAD 복사본 85d22bd + 고친 branding.py, `branding_after.json`): B1 원 밖 0 px(엄격 규칙)·마스크 잘림 0,
  B2 48 dp 면적 25.5 %·ΔL* 33.9·protan 39.7, 36 dp 26.2 %·31.1·37.7, B3·B4·B5 PASS. 06-services 검사기도 원 안 PASS.
- **스토어 그림:** 같은 실행에서 `docs/art/branding/**`(512 아이콘, 그래픽 이미지 ko·en·바탕·제목 층, 적응형 층, 미리보기)과
  `docs/art/evidence/branding/*`를 다시 만들어 커밋한다(08:35 소유 결정). 512 아이콘 512×512 RGBA 투명 0 px, 그래픽 이미지
  1024×500 RGB(알파 없음). 그래픽 이미지 바탕은 지금 HEAD의 게임 그림(09 새 배경 포함)이다.
- 06-services 검사기의 "Feature graphic MISSING"은 최종 업로드 폴더 `docs/services/store_assets/`에 파일이 없다는 뜻이다. 그 폴더는
  Q2 보류로 얼어 있어 쓰지 않았다(읽기만 함).
