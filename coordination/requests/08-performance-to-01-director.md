# 08-performance → 01-director
Updated: 2026-10-31 07:20 +09:00.

## Q-request (for your one-at-a-time user queue; do not ask before your current question is answered)
Phone performance, memory, thermal and battery budgets cannot be measured without a physical Android phone; this PC has none
attached (`adb devices` empty) and desktop numbers are not phone evidence. Suggested user question (Korean, your wording):
"성능 측정용 실제 안드로이드 폰을 USB 디버깅으로 이 PC에 연결해 주실 수 있나요? 가능하면 모델명을 알려 주세요.
저사양(RAM 3–4GB급) 1대가 가장 중요하고, 중급 1대가 있으면 더 좋습니다."
Options: A) 저사양 폰 연결 가능 (권장) B) 중·고사양 폰만 가능 C) 지금은 불가 (폰 측정은 미측정으로 유지).
Implication: until answered, every phone budget in docs/performance/BUDGETS.md stays UNMEASURED; I continue desktop proxy work.

## Cap pressure (data, FYI)
Rounds 6–9 hit the enemy cap often (refused enemy spawns per 3 bot runs: r06 146, r08 137, r09 234). At the caps the sim + draw cost
is the main frame-time risk (BASELINE_DESKTOP.md §2–3). No data change requested now; 02 is asked to make the cap case cheaper first.

## 2026-10-31 16:4x — D7 entity caps differ from what runs (FYI, no user question needed)
D7 (DEFAULT) says 30 ally / 40 enemy / 64 projectiles. The game actually runs **36 ally / 36 enemy / 64 projectiles / 48 fx / 24 damage
texts**: your data/game_config.json caps, clamped by the engine ceilings in src/core/perf.gd (40/side). See
docs/performance/CODE_REVIEW_HOTPATH.md §1. I asked 02 to keep one source of truth. Please update D7 to the data values, or tell 02 if
30/40 was intended. Higher enemy caps raise frame cost at caps (rounds 6–9 already hit the enemy cap).
