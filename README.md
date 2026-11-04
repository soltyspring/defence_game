# 빵집 기사단: 곰팡이 디펜스

빵집 기사단을 이끌고 곰팡이 군단의 둥지를 부수는 가로 화면 도트 디펜스 게임입니다. 제빵사를 고용해 밀가루를 모으고, 병사를 출병시키며 영웅을 직접 움직입니다. 30개 라운드와 강화·진행 저장을 제공합니다.

## Windows에서 바로 실행

**[Windows v0.1.4 다운로드](https://github.com/soltyspring/defence_game/releases/tag/windows-v0.1.4-20261105)** · [ZIP 바로 받기](https://github.com/soltyspring/defence_game/releases/download/windows-v0.1.4-20261105/BakeryKnights-Windows-x64.zip)

1. 릴리스의 **`BakeryKnights-Windows-x64.zip`**을 내려받습니다. `Source code`는 실행 파일이 아닙니다.
2. ZIP을 폴더에 모두 압축 해제합니다.
3. **`BakeryKnights.exe`**를 더블클릭합니다. Godot 설치나 별도 빌드는 필요 없습니다.
4. **게임 시작** → 병사 출병 → 적 둥지 파괴 순서로 플레이합니다. 전투 중 **밀가루**로 제빵사를 고용하고 병사를 보냅니다. 라운드 보상 **골드**는 메인 화면의 **강화**에서 사용합니다.

Windows 64비트용입니다. 게임 데이터가 EXE 안에 들어 있어 `.pck`를 따로 찾을 필요가 없습니다. 함께 제공하는 `licenses` 폴더에는 엔진과 글꼴의 사용 고지가 있습니다. EXE는 코드 서명되지 않았습니다. 보안 경고가 뜨면 다운로드 출처와 릴리스의 SHA-256을 확인하세요.

## 조작

화면 버튼을 마우스로 눌러 플레이할 수 있습니다. 전투 중에는 아래 키도 지원합니다.

| 조작 | 키 / 마우스 |
| --- | --- |
| 영웅 이동 | `A` / `D` 또는 `←` / `→`, 화면 이동 버튼 누르고 있기 |
| 병사 출병 | `1`~`5` 또는 아래쪽 유닛 카드 클릭. 라운드에서 열린 카드만 사용 가능 |
| 제빵사 고용 | `E` 또는 제빵사 버튼 |
| 스킬 | `Q` / `W` / `R` 또는 스킬 버튼. 해금·기력·재사용 대기 조건 적용 |
| 일시정지 / 계속 | `P` / `Esc` 또는 일시정지 버튼 |
| 먼 전장 둘러보기 | 상단 미니맵 클릭·드래그 또는 전장 드래그 |
| 영웅으로 카메라 복귀 | 정찰 중 나타나는 **영웅** 버튼 또는 영웅 이동 |

메인 화면의 **설정**, 또는 전투 중 **일시정지 → 설정**에서 효과음·음악 음량을 각각 **0~100%**로 조절할 수 있습니다. 슬라이더를 끌면 즉시 반영되고 놓으면 자동 저장됩니다. 0%는 음소거이며, 슬라이더 선택 후 `←` / `→`로 1%씩 조절할 수도 있습니다. 30/60 FPS, 피해 숫자, 화면 흔들림도 설정할 수 있습니다. 한국어 환경에서는 한국어, 그 외에는 영어를 자동으로 사용합니다.

## 저장과 빌드 상태

- 진행도·강화·설정은 자동으로 로컬에 저장합니다. Windows 경로는 `%APPDATA%\Godot\app_userdata\Lane Defence\`입니다. 폴더 이름에는 초기 개발명이 남아 있습니다.
- PC 변경 전에는 이 폴더를 복사해 보관하세요. 계정 연동·클라우드 동기화는 제공하지 않습니다.
- 광고·인앱 결제는 비활성 상태입니다.
- v0.1.4은 효과음·음악의 켜기/끄기 버튼을 퍼센트 슬라이더로 바꿨습니다. [음량 조절 검증](docs/qa/VOLUME_SETTINGS_20261105.md).
- v0.1.2는 이동 중 배경의 픽셀 정렬을 고치고, 마을·제분소와 밀가루 포대 운반을 새로 표현했습니다. 먼 전장을 보는 미니맵, 영웅 복귀 버튼, 부드러운 타격음과 운반·정찰 효과음을 추가했습니다. 기존 전투·라운드·수입·강화 수치는 유지했습니다.
- EXE·ZIP의 해시와 원본 커밋은 릴리스 및 ZIP 안의 `BUILD_INFO.json` / `SHA256SUMS.txt`에서 확인할 수 있습니다. 현재 확인한 실행 범위는 릴리스 설명에 적습니다.

수락 156개, UI 3,415개, 실제 엔진 UI 통합 49개, 기존 수정 회귀 29개가 통과했습니다. 새 미니맵·운반 검사는 57개, 실제 화면 이동 검사는 창 크기별 71개입니다. 카메라 수학 검사 8,992개도 통과했습니다. 실제 폰 성능과 사람의 청감 평가는 포함하지 않습니다. [v0.1.2 검토 기록](docs/qa/QUALITY_UPGRADE_20261104.md)에 조건·파형·전후 비용과 한계를 정리했습니다.

![제분소·밀가루 운반과 미니맵](docs/qa/quality-20261105/home.png)

![미니맵으로 먼 전장 정찰](docs/qa/quality-20261105/scout.png)

## 30라운드 캠페인

1~10라운드의 전투 수치는 유지했습니다. 11~20은 과수원, 21~30은 서리 구간입니다. 껍질 방패병·솜털 질주자·포자 포격수와 15·20·25·30라운드의 구간 보스를 추가했습니다. 후반 강화 단계는 11·16·21·26라운드에서 열립니다. 기존 저장과 효과음·음악 0~100% 설정을 이어서 사용할 수 있습니다.

기지 피해 숫자는 되감기 없이 떠오르며 사라집니다. 겹친 병력은 전투 판정을 유지한 채 3열 대형으로 보이고, 같은 종류가 많이 모이면 병력 수가 표시됩니다. 미니맵은 상단 한 줄로 줄였습니다.

![작아진 미니맵과 겹친 병력 대형 비교용 장면](docs/qa/campaign-20261105/after.png)

[전후 화면·30라운드 진행·리소스 검증 기록](docs/qa/CAMPAIGN30_20261105.md). 위 화면은 겹침 비교를 위해 병력 18명씩을 같은 위치에 놓은 검증 장면입니다.

## 소스에서 실행

이 저장소는 **Godot 4.7.2 Standard / GDScript** 기준입니다. .NET 버전은 필요 없습니다.

```powershell
git clone https://github.com/soltyspring/defence_game.git
cd defence_game
& 'C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe' --editor --path .
```

Godot에서 `project.godot`를 가져와 연 다음 리소스 가져오기가 끝나면 **F5(프로젝트 실행)**를 누릅니다. 엔진과 export templates는 저장소에 포함하지 않습니다.

## Windows EXE 직접 빌드

같은 버전의 Godot Windows export templates를 설치하세요. Godot의 **편집기 → 내보내기 템플릿 관리**에서 설치할 수 있습니다. **프로젝트 → 내보내기 → Windows Desktop → 프로젝트 내보내기**를 선택하면 됩니다. `export_presets.cfg`의 Windows 프리셋은 x86_64·데이터 내장 EXE로 설정되어 있습니다.

커밋된 소스만 사용해 재현하려면 PowerShell에서 실행합니다. 스크립트는 Git 스냅샷을 만들므로 다른 작업 중인 미커밋 게임 코드는 포함하지 않습니다.

```powershell
pwsh -NoProfile -File .\tools\build\build_windows.ps1 `
  -Godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
```

결과는 `build/windows/<빌드시각>/BakeryKnights-Windows-x64.zip`입니다. 엔진 버전, 소스 SHA, 라이선스, EXE SHA-256과 메뉴·r01 자동 실행 확인을 함께 남깁니다. 빌드 로그와 개인 저장 데이터는 배포 ZIP에 포함하지 않습니다.

개발용 공유 PC에서는 Godot·빌드를 동시에 돌리지 않도록 `coordination/HEAVY_RUN.md`의 분리 실행 규칙을 따릅니다.

## 구조와 참고

- `src/`, `scenes/`: 전투·저장·UI·오디오 코드와 씬
- `data/`: 라운드·유닛·강화·한국어/영어 문구
- `assets/`: 도트 아틀라스·효과음·갈무리 글꼴
- `tests/`, `tools/qa/`: 검증 도구. [검증 안내](docs/verification/README.md)
- `docs/design/`, `docs/verification/`: 기획 결정·검증 결과·남은 문제

글꼴은 [갈무리](https://galmuri.quiple.dev/)를 사용하며 [SIL Open Font License 1.1](assets/fonts/OFL-Galmuri.txt)을 포함합니다. Godot 및 엔진의 외부 구성요소 사용 고지는 배포본 `licenses`에 있습니다. [Godot 라이선스](https://godotengine.org/license/), [Windows 내보내기 공식 안내](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)를 참고하세요.
