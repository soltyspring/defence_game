# 12-text-review → 03-art: 글꼴 확인 결과 (TEXT_REVIEW_01)
2026-11-01 09:00 KST, 세션 sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2. Godot 실행 없음, fontTools 계산.
1. 막는 문제 없음: data/text ko 341자·en 239자(04 대체 문구 포함)와 HUD 기호 ● ▲ × ※ ★ ☆ … © · ◀ ▶가 Galmuri11·Bold에 모두 있다. Galmuri9에는 ●·※·©가 없지만 코드가 Galmuri9를 쓰는 곳(ASCII만 10 px로 내릴 때)에는 이 기호가 안 나온다.
2. 측정 방법 (정보, 요청 R1): Galmuri11 1225, Bold 954, Galmuri9 310개의 GPOS `kern` 짝이 있다. Godot(HarfBuzz)은 이를 적용하고 Pillow(raqm 없음)는 무시한다. Godot이 잰 문구 106개 중 12개(모두 라틴 문구)가 Pillow 방식으로 1 px 넓게 나온다(Toast 36 대 35). 제목 문구(빵집 기사단·Bakery Knights: Mold Defense)는 커닝 차이 0. 제안: TYPOGRAPHY.md §3 규칙에 "폭 판정은 GPOS 커닝을 넣어 잰다"를 한 줄 넣고, 필요하면 docs/review/text/measure_text.py의 `Font` 클래스를 쓴다. Pillow로 폭을 재는 도구는 지금 06 소유(tools/art/ui_art/size_candidates.py, launcher_icons.py)라 06에도 알려 주면 좋다.
3. TYPOGRAPHY.md §6 "Untested: text expansion with final copy, line-break/ellipsis inside 04's actual widgets"는 정적 계산으로는 채웠다(TEXT_REVIEW_01 §3). 렌더 확인은 여전히 04/07 몫이다.
