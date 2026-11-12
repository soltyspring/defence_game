"""Before/after pair sheets and the 40-round table for the lane backdrop (docs/art/fable52/backdrop/).

Input: 640x360 game frames from tests/acceptance/capture_backdrop.gd
    <before dir>/rNN_<shot>_before_640x360.png, <after dir>/rNN_<shot>_after_640x360.png,
    <all dir>/rNN_fight_all_640x360.png (every round), <core dir>/r40_<far|exposed>_core_640x360.png
Usage: python tools/art/world/backdrop_sheets.py <before dir> <after dir> <all dir> <core dir> <out dir>
Writes pair_chN.png (left before, right after), rounds_all.png (8 x 5, half size), core_states.png and
BACKDROP_ROUNDS.md (from the tables in src/gameplay/backdrop_scenes.gd).
"""
import os
import re
import sys
from PIL import Image

W, H = 640, 360
KEY = [["r01", "r05", "r10"], ["r11", "r15", "r20"], ["r21", "r25", "r30"], ["r31", "r35", "r40"]]
CHAPTER = ["R01–R10 밀밭 마을", "R11–R20 오염 과수원", "R21–R30 서리길", "R31–R40 둥지 심부"]
PLANE = {"far": "능선", "mid": "중경", "near": "길가", "home": "아군 기지 옆", "enemy": "적 기지 뒤"}


def load(path):
    return Image.open(path).convert("RGB") if os.path.exists(path) else Image.new("RGB", (W, H), (40, 40, 40))


def main():
    before, after, all_dir, core_dir, out = sys.argv[1:6]
    os.makedirs(out, exist_ok=True)
    for ci, rounds in enumerate(KEY):
        sheet = Image.new("RGB", (W * 2 + 4, (H + 4) * len(rounds) * 2), (20, 20, 24))
        row = 0
        for rid in rounds:
            for shot in ("fight", "far"):
                sheet.paste(load(os.path.join(before, f"{rid}_{shot}_before_{W}x{H}.png")), (0, row * (H + 4)))
                sheet.paste(load(os.path.join(after, f"{rid}_{shot}_after_{W}x{H}.png")), (W + 4, row * (H + 4)))
                row += 1
        sheet.save(os.path.join(out, f"pair_ch{ci + 1}_left-before_right-after.png"))
    grid = Image.new("RGB", (8 * 322, 5 * 182), (20, 20, 24))
    for n in range(1, 41):
        img = load(os.path.join(all_dir, f"r{n:02d}_fight_all_{W}x{H}.png")).resize((320, 180), Image.NEAREST)
        grid.paste(img, (((n - 1) % 8) * 322, ((n - 1) // 8) * 182))
    grid.save(os.path.join(out, "rounds_all_r01-r40_fight_half-size.png"))
    core = Image.new("RGB", (W * 2 + 4, H), (20, 20, 24))
    core.paste(load(os.path.join(core_dir, f"r40_far_core_{W}x{H}.png")), (0, 0))
    core.paste(load(os.path.join(core_dir, f"r40_exposed_core_{W}x{H}.png")), (W + 4, 0))
    core.save(os.path.join(out, "r40_core_left-linked_right-exposed.png"))

    src = open("src/gameplay/backdrop_scenes.gd", encoding="utf-8").read()
    table = src[src.index("const ROUNDS := {"):src.index("## One line per round")]
    notes = dict((int(a), b) for a, b in re.findall(r'(\d+): "([^"]+)"', src[src.index("const NOTES := {"):src.index("static func chapter_of")]))
    lines = ["# 배경 변경표 R01–R40", "",
             "생성: `python tools/art/world/backdrop_sheets.py` (표는 `src/gameplay/backdrop_scenes.gd`의 `ROUNDS`·`NOTES`에서 만든다). "
             "캡처는 640×360 실제 게임 화면(`tests/acceptance/capture_backdrop.gd`).", "",
             "- 전후 비교: `pair_ch1..4_left-before_right-after.png` (챕터별 초입·중간·보스, 교전 장면과 적 기지 앞 장면)",
             "- 40개 라운드 교전 장면: `rounds_all_r01-r40_fight_half-size.png`",
             "- R40 연결/노출: `r40_core_left-linked_right-exposed.png`", ""]
    for ci in range(4):
        lines += [f"## {CHAPTER[ci]}", "", "| 라운드 | 이 라운드에서 달라지는 것 | 랜드마크 (위치) | 캡처 |", "|---|---|---|---|"]
        for n in range(ci * 10 + 1, ci * 10 + 11):
            m = re.search(r"^\t%d: \[(.*)\],?$" % n, table, re.M)
            items = re.findall(r'\["(\w+)", "(\w+)", ([-0-9.]+), ([-0-9.]+)', m.group(1)) if m else []
            marks = ", ".join(f"{k}({PLANE[p]})" for k, p, _, _ in items)
            shot = "있음" if os.path.exists(os.path.join(all_dir, f"r{n:02d}_fight_all_{W}x{H}.png")) else "**없음**"
            lines.append(f"| R{n:02d} | {notes.get(n, '')} | {marks} | {shot} |")
        lines.append("")
    open(os.path.join(out, "BACKDROP_ROUNDS.md"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("sheets written to", out)


if __name__ == "__main__":
    main()
