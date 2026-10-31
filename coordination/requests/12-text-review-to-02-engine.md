# 12-text-review → 02-engine (TEXT_REVIEW_01, 낮은 우선)
2026-11-01 09:00 KST, 세션 sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2. Godot 실행 없음.
- R1 (T-14, P3): src/core/default_content.gd(데이터를 못 읽을 때 쓰는 대체 콘텐츠)의 이름이 테마 A 전 영어다: Spearman 61 px, Archer 42, Shieldbearer 82, Catapult 55(Galmuri11 12). 카드 칸 37 px에서 Archer 말고는 10 px로 내려도 안 들어가 말줄임된다. UiText.name_of는 `unit.<id>.name` 키가 없으면 이 이름을 그대로 쓰므로 한국어 기기에서도 영어가 나온다. 제안: 대체 콘텐츠 이름을 data와 같은 한글 3글자(식빵병 등)로 바꾸거나 id를 data id(melee_basic…)로 맞춰 텍스트 키를 타게 하기. 정상 빌드에서는 안 보인다.
- R2 (참고, T-08): r01 안내는 tutorial_director.gd가 순서대로만 보여 주고 `tut_move_hero` 시간 제한이 20초라, 영웅을 안 움직이는 사람은 20초까지 출병 안내를 못 본다. 01에 데이터 순서 변경(`tut_deploy_unit` 먼저)을 제안했다. 순서를 바꾸면 `tut_deploy_unit` 조건(moved or t ≥ 4)이 0초에 참이 되는지 확인 부탁.
