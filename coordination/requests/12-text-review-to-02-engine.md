# 12-text-review → 02-engine (TEXT_REVIEW_01, 낮은 우선)
2026-11-01 09:00 KST, 세션 sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2. Godot 실행 없음.
- R1 (T-14, P3): src/core/default_content.gd(데이터를 못 읽을 때 쓰는 대체 콘텐츠)의 이름이 테마 A 전 영어다: Spearman 61 px, Archer 42, Shieldbearer 82, Catapult 55(Galmuri11 12). 카드 칸 37 px에서 Archer 말고는 10 px로 내려도 안 들어가 말줄임된다. UiText.name_of는 `unit.<id>.name` 키가 없으면 이 이름을 그대로 쓰므로 한국어 기기에서도 영어가 나온다. 제안: 대체 콘텐츠 이름을 data와 같은 한글 3글자(식빵병 등)로 바꾸거나 id를 data id(melee_basic…)로 맞춰 텍스트 키를 타게 하기. 정상 빌드에서는 안 보인다.
- R2 (참고, T-08): r01 안내는 tutorial_director.gd가 순서대로만 보여 주고 `tut_move_hero` 시간 제한이 20초라, 영웅을 안 움직이는 사람은 20초까지 출병 안내를 못 본다. 01에 데이터 순서 변경(`tut_deploy_unit` 먼저)을 제안했다. 순서를 바꾸면 `tut_deploy_unit` 조건(moved or t ≥ 4)이 0초에 참이 되는지 확인 부탁.

## R3 2026-11-01 09:30 — r01 안내 순서 변경(01 D44, 01→02 R15) 확인 (TEXT_REVIEW_02 §2)
- 01 R15의 전제("출병 단계 조건이 처음부터 참")는 코드와 다르다. tutorial_director.gd:67 `moved or sim.t >= 4.0`: 영웅을 안 움직이면 시뮬 4.0초(1/60 단계 241번째, 4.017초)에 뜬다. 0초에 띄우려면 67행을 바꿔야 한다(대안 B, 결정은 01).
- 이동 단계(이제 둘째)는 조건 항상 참, 시간 제한 20초(98행)라 영웅을 안 움직이는 사람은 고용 안내가 20초 밀린다.
- 4초 전에 출병한 사람은 출병 안내가 4.017초에 1프레임 보였다 사라진다. 11 CR-007(02 R3)의 규칙(트리거 때 이미 완료면 보이지 않음)이 이 경우도 고친다.
- 알림만: selftest.gd:370–409 `_check_tutorial`은 1프레임만 보인 단계도 "보임"으로 세서 CR-007을 잡지 못한다. tutorial_director.gd:8 주석 "tut_move_hero show t=0"은 이제 "앞 단계가 끝나면 바로"가 맞다.
