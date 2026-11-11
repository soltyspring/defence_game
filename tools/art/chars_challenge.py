"""Original Nest Depths sprites. Run directly to refresh just this atlas and its index."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from atlas import Atlas
from pixel import Canvas, c

PAGE = "char_challenge"
NOTE = "Nest Depths roster: guard, knot and core. Loaded only when used by a battle."


def frame(unit, pose="idle", step=0):
    w, h, x = {"e_thrall": (42, 40, 16), "e_binder": (32, 36, 14),
               "boss_nestcore": (76, 68, 35), "e_frostshell": (40, 36, 16), "e_icerunner": (50, 28, 20),
               "e_sporesac": (34, 44, 15), "e_burrower": (42, 36, 16)}[unit]
    cv = Canvas(w, h)
    ground = h - 2
    sway = (-2, -1, 1, 2, 1, -1)[step % 6] if pose == "walk" else 0
    bob = abs(sway) // 2 if pose == "walk" else (1 if step % 4 == 2 else 0)
    lift = pose == "heavy_prepare"
    slam = pose in ("attack", "heavy_release")
    open_ = pose in ("heavy_exposed", "hit")

    def box(x0, y0, ww, hh, color):
        cv.rect(x0, y0, ww, hh, c(color))

    def oval(x0, y0, rx, ry, color):
        cv.ellipse(x0, y0, rx, ry, c(color))

    def limb(x0, y0, x1, y1, thick, color, shade="D"):
        cv.thick_line(x0, y0, x1, y1, c(color), thick, c(shade))

    if unit == "e_thrall":
        y = ground - 12 + bob + (3 if open_ else 0)
        # Broad shell plates, twin growths and a single huge striking fist.
        limb(x - 6, y, x - 8 + sway, ground - 1, 5, "l")
        limb(x + 4, y, x + 7 - sway, ground - 1, 5, "t", "l")
        for dx, height in [(-9, 12), (-4, 16)]:
            top = y - height + (3 if open_ else -3 if lift else 0)
            limb(x + dx, y - 3, x + dx - 1, top, 3, "l")
            oval(x + dx - 1, top, 3, 3, "t")
            box(x + dx - 2, top - 1, 2, 1, "z")
        oval(x, y - 3, 12, 10, "D")
        oval(x - 2, y - 7, 10, 6, "l")
        box(x - 8, y - 11, 10, 2, "t")
        box(x - 7, y - 8, 2, 6, "D")
        oval(x + 8, y - 4, 6, 5, "l")
        box(x + 9, y - 6, 4, 2, "Q")
        fx = x + (10 if lift else 16 if slam else 12)
        fy = y - 17 if lift else ground - 5 if slam or open_ else y + 4
        limb(x + 4, y + 1, fx, fy, 5, "l")
        oval(fx, fy, 7, 5, "t")
        box(fx - 4, fy, 8, 3, "l")
        box(fx - 4, fy - 3, 3, 1, "z")
        if open_: box(x - 6, y - 8, 5, 4, "Z")
    elif unit == "e_binder":
        y = ground - 13 + bob
        # The tall tripod carries an open knot; the connecting strand leaves the knot.
        for dx in [-6, 2, 7]:
            limb(x, y + 4, x + dx + (sway if dx > 0 else -sway), ground - 1, 2, "l")
        oval(x - 1, y + 1, 6, 10, "D")
        box(x - 4, y - 4, 3, 11, "t")
        oval(x + 3, y - 1, 5, 4, "l")
        box(x + 4, y - 2, 3, 2, "Q")
        limb(x + 1, y + 4, x + (11 if slam else 8), y + (1 if slam else 6), 2, "t")
        knot_y = y - 11
        oval(x, knot_y, 8, 7, "q")
        oval(x - 1, knot_y - 1, 7, 6, "t")
        oval(x, knot_y, 4, 3, ".")
        box(x - 5, knot_y - 4, 5, 2, "z")
        if slam: oval(x + 11, y - 1, 2, 2, "Q")
    elif unit == "e_frostshell":
        y = ground - 11 + bob
        # Frost Carapace: a tall ice dome over a soft body. Closed = one dome; open = two halves tilted apart.
        limb(x - 5, y + 3, x - 6 + sway, ground - 1, 3, "l")
        limb(x + 4, y + 3, x + 6 - sway, ground - 1, 3, "l")
        oval(x, y, 9, 7, "l")
        oval(x + 10, y + 2, 4, 3, "t")
        box(x + 11, y + 1, 2, 1, "Q")
        if slam: limb(x + 10, y + 3, x + 19, y + 4, 3, "t")
        if open_:
            oval(x - 10, y - 6, 6, 9, "I")
            oval(x - 11, y - 8, 4, 6, "j")
            oval(x + 11, y - 5, 5, 8, "I")
            oval(x + 12, y - 7, 3, 5, "j")
            oval(x, y - 4, 5, 5, "t")
            oval(x, y - 4, 3, 3, "Z")
        else:
            top = y - 8 - (2 if lift else 0)
            oval(x - 1, top, 13, 11, "I")
            oval(x - 3, top - 3, 10, 7, "j")
            oval(x - 5, top - 6, 5, 3, "J")
            box(x - 13, top + 6, 25, 2, "i")
            for dx in (-7, 0, 7): box(x + dx, top - 2, 1, 8, "i")
            if lift: box(x - 11, top + 9, 21, 1, "Q")
    elif unit == "e_icerunner":
        # Rime Charger: low, long, all horn. Coils back to prepare, stretches flat to ram, horn stuck down when spent.
        y = ground - 8 + bob + (2 if lift or open_ else 0)
        bx = x + (-4 if lift else 4 if slam else 0)
        limb(bx - 7, y + 1, bx - 10 + sway, ground - 1, 3, "l")
        limb(bx + 3, y + 2, bx + 5 - sway, ground - 1, 2, "l")
        for i, (dx, dy) in enumerate([(-12, -4), (-14, -1), (-12, 2)]):
            limb(bx - 6, y - 1 + i, bx + dx, y + dy, 2, "j")
        oval(bx, y - 1, 9, 5, "l")
        oval(bx - 2, y - 3, 6, 3, "t")
        hx, hy = bx + (7 if lift else 9), y + (3 if open_ else -5 if lift else 0)
        if lift:
            limb(bx + 1, y + 1, hx, hy, 5, "t", "l")
            limb(bx + 4, y, bx + 9, ground - 6, 2, "j")
        oval(hx, hy, 4, 4, "l")
        box(hx + 1, hy - 2, 2, 1, "Q")
        tip = (hx + (14 if slam else 8 if open_ else 10), hy + (5 if open_ else -7 if lift else -1))
        limb(hx + 2, hy - 1, tip[0], tip[1], 4, "j", "I")
        limb(hx + 2, hy - 2, tip[0] - 2, tip[1] - 1, 2, "J")
        if lift:
            box(tip[0] + 2, tip[1] - 3, 2, 2, "Q")
            box(tip[0] + 5, tip[1] - 5, 1, 2, "j")
        if slam:
            for sy in (-5, 0, 4): box(bx - 22, y + sy, 6, 1, "J")
        if open_: box(hx - 1, hy - 7, 3, 2, "Z")
    elif unit == "e_sporesac":
        # Ferment Sac: thin stalks under a balloon. The balloon swells to prepare and hangs spent afterwards.
        y = ground - 12 + bob
        for dx in (-5, 0, 5): limb(x, y + 2, x + dx + (sway if dx else 0), ground - 1, 2, "l")
        oval(x, y + 1, 4, 5, "D")
        box(x + 2, y, 2, 2, "Q")
        r = 11 if lift else 6 if (open_ or slam) else 8
        sy = y - 6 - r + (4 if open_ else 0)
        oval(x - 1, sy, r, r + 1, "P")
        oval(x - 2, sy - 1, r - 2, r - 1, "V")
        oval(x - 3, sy - 3, max(2, r // 3), max(2, r // 3), "v")
        if lift:
            for dx, dy in ((-5, 3), (4, -2), (1, 5)): box(x + dx, sy + dy, 2, 2, "Z")
        if slam:
            oval(x + 10, sy - 7, 3, 3, "v")
            box(x, sy - r - 1, 3, 2, "D")
        if open_: limb(x - 1, sy + r, x - 6, sy + r + 4, 2, "P")
    elif unit == "e_burrower":
        # Hypha Burrower: a low segmented body behind a cone drill. heavy_release = bursting upright out of the ground.
        y = ground - 6 + bob
        if pose == "heavy_release":
            oval(x, y - 6, 6, 11, "l")
            oval(x - 1, y - 8, 4, 8, "t")
            limb(x, y - 16, x + 2, y - 23, 5, "X", "A")
            box(x + 1, y - 26, 2, 3, "x")
            box(x - 2, y - 12, 2, 2, "Q")
            for dx, dy in ((-11, -3), (9, -5), (-8, -9), (12, -1)): box(x + dx, y + dy, 3, 2, "O")
            box(x - 9, ground - 2, 18, 2, "O")
        else:
            for i, dx in enumerate((-9, -3, 3)):
                oval(x + dx, y - (1 if pose == "walk" and (i + step) % 2 == 0 else 0), 5, 5, "l")
                box(x + dx - 1, y - 8, 2, 4, "t")
            oval(x - 3, y - 2, 9, 3, "t")
            dy = 5 if open_ else -2 if lift else 0
            reach = 20 if pose == "attack" else 17
            limb(x + 7, y - 1, x + reach, y - 1 + dy, 6, "X", "A")
            limb(x + 13, y - 1 + dy // 2, x + reach + 3, y - 1 + dy, 3, "x")
            box(x + 6, y - 3, 2, 2, "Q")
            for dx in (-9, 0): limb(x + dx, y + 3, x + dx + sway, ground - 1, 2, "l")
            if open_: box(x - 2, y - 11, 3, 2, "Z")
    else:
        y = ground - 25 + bob + (5 if open_ else 0)
        # Low rolling shell and hanging limbs; the core opens inside the shell.
        for dx in [-17, -6, 10, 18]:
            limb(x + dx, y + 10, x + dx + (sway if dx > 0 else -sway), ground - 2, 7, "l")
        oval(x - 2, y + 1, 23, 19, "D")
        oval(x - 5, y - 5, 20, 15, "l")
        oval(x - 10, y - 10, 14, 9, "t")
        for dx, dy, r in [(-18, -12, 4), (-8, -16, 5), (5, -13, 3)]:
            oval(x + dx, y + dy, r, r - 1, "q")
            box(x + dx - 1, y + dy - 2, 2, 1, "z")
        for dx, dy in [(0, 0), (4, 3), (-3, 4)]:
            tip = (x + 23 + dx + (7 if slam else 0), y + dy + (-20 if lift else 21 if slam or open_ else 10))
            limb(x + 10, y - 6 + dy, x + 20 + dx, y - 2 + dy, 5, "l")
            limb(x + 20 + dx, y - 2 + dy, *tip, 5, "t")
        oval(x + 7, y - 6, 12, 11, "D")
        oval(x + 7, y - 6, 9, 8, "q")
        if open_:
            oval(x + 7, y - 6, 7, 6, "Z")
            oval(x + 6, y - 8, 3, 3, "z")
        else:
            limb(x + 1, y - 9, x + 12, y - 4, 4, "t")
            box(x + 6, y - 8, 3, 5, "Q")
    cv.outline()
    return cv.a


def make_atlas():
    page = Atlas(PAGE, "character", "battle_roster", NOTE)
    for uid, pivot, hit in [("e_thrall", 16, 3), ("e_binder", 14, 2), ("boss_nestcore", 35, 3)]:
        def anim(pose, n, fps, loop=False, events=None):
            return dict(frames=[frame(uid, pose, i) for i in range(n)], fps=fps, loop=loop, events=events)
        attack = [frame(uid, p) for p in (["idle"] * hit + ["attack", "hit", "idle"])]
        fallen = frame(uid, "hit")
        death = []
        for frac in (1.0, 0.8, 0.6, 0.4, 0.3):
            dst = np.zeros_like(fallen)
            nh = int(len(fallen) * frac)
            dst[-nh:] = fallen[np.linspace(0, len(fallen) - 1, nh).astype(int)]
            death.append(dst)
        anims = dict(idle=anim("idle", 4, 4, True), walk=anim("walk", 6, 8, True),
                     attack=dict(frames=attack, fps=9, loop=False, events={"hit": hit}),
                     hit=anim("hit", 2, 10),
                     death=dict(frames=death, fps=12, loop=False))
        anims["die"] = anims["death"]
        if uid != "e_binder":
            anims.update(heavy_prepare=anim("heavy_prepare", 4, 5, True),
                         heavy_release=anim("heavy_release", 1, 8),
                         heavy_exposed=anim("heavy_exposed", 4, 4, True))
        if uid == "boss_nestcore":
            anims["summon"] = dict(frames=[frame(uid, p) for p in
                                          ("idle", "heavy_prepare", "heavy_prepare", "hit", "idle")],
                                   fps=8, loop=False, events={"summon": 3})
        h, w = fallen.shape
        page.add_sprite(uid, w, h, (pivot, h - 1), anims, meta={"faction": "enemy", "kind": "character"})
    return page


def build_page():
    root = Path(__file__).resolve().parents[2]
    page = make_atlas()
    page.pack(lock_dir=str(Path(__file__).parent / "layout_lock"))
    d, _ = page.write(str(root / "assets/atlases"), "assets/atlases")
    p = root / "assets/manifest.json"
    m = json.loads(p.read_text(encoding="utf-8"))
    m["atlases"] = [a for a in m["atlases"] if a["id"] != PAGE] + [
        {"id": PAGE, "group": page.group, "load_policy": page.load_policy,
         "image": f"res://assets/atlases/{PAGE}.png", "frames": f"res://assets/atlases/{PAGE}.json",
         "size": d["size"], "disk_bytes": d["disk_bytes"], "gpu_bytes": d["gpu_bytes"],
         "biome": "", "anim_sets": sorted(page.sprites), "image_frames": 0}]
    m["anim_sets"].update(dict.fromkeys(page.sprites, PAGE))
    if PAGE not in m["load_groups"]["battle"]:
        m["load_groups"]["battle"].append(PAGE)
    m["totals"]["disk_bytes"] = sum(a["disk_bytes"] for a in m["atlases"])
    m["totals"]["gpu_bytes_all_pages"] = sum(a["gpu_bytes"] for a in m["atlases"])
    p.write_text(json.dumps(m, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    build_page()
