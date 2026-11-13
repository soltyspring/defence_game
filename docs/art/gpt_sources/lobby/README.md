# 로비 및 강화 훈련장 아트

ChatGPT 생성 원본은 이 폴더의 `lobby_cards.png`, `upgrade_training.png`다. 사용자가 제공한 시트이며 별도 제3자 에셋 팩은 사용하지 않았다. `python tools/art/import_lobby_art.py`로 실제 이미지 경계에서 자른 결과를 `assets/art/lobby/`에 만든다.

| 출력 | 규격 | 게임 내 위치 |
| --- | --- | --- |
| round_select.png | RGB 224×148 | 로비 왼쪽 카드 |
| upgrades.png | RGB 224×148 | 로비 오른쪽 카드 |
| training.png | RGB 576×118 | 강화 공격 예시의 배경. 바닥 경계는 y=98이며 유닛 발 기준선에 맞춘다. |

세 파일은 크기, RGB 형식, 자홍 여백 제거, 재생성 일치를 확인했다. 글자·배지·버튼 입력·훈련장 애니메이션은 게임 코드가 그린다.
