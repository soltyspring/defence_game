"""Deterministic art build (owner: 03-art).

    python tools/art/build.py            # generate atlases, manifest, previews, budget doc
    python tools/art/validate.py         # independent checks on the written files

Outputs (all paths relative to the workspace root):
    assets/atlases/<id>.png + <id>.json                     runtime pages (shipped; .import made by Godot)
    assets/manifest.json                                    index (INTERFACES.md §5.1)
    docs/art/palette/hearth48.{gpl,hex}, swatch png         palette (outside res:// game content)
    docs/art/previews/**                                    contact sheets (never shipped)
    docs/art/ATLAS_BUDGET.md                                generated disk/GPU table
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import atlas as atl  # noqa: E402
import bases  # noqa: E402
import biome  # noqa: E402
import chars_enemy  # noqa: E402
import chars_player  # noqa: E402
import fx  # noqa: E402
import ui  # noqa: E402
from pixel import RGBA, write_palette_files  # noqa: E402
from preview import anim_sheet, checker  # noqa: E402

ATLAS_DIR = os.path.join(ROOT, "assets", "atlases")
REL_ATLAS = "assets/atlases"
PREV = os.path.join(ROOT, "docs", "art", "previews")
ART_VERSION = "0.4.0"

REQUIRED_CHAR_ANIMS = ("idle", "walk", "attack", "death")


def add_char(a: atl.Atlas, sid, body, fn, faction):
    anims = fn()
    out = {}
    for name, an in anims.items():
        out[name] = dict(frames=[f.a for f in an["frames"]], fps=an["fps"], loop=an["loop"],
                         events=an.get("events"), points=an.get("points"))
    # alias for 01 data naming ("die") - no extra pixels, frames are shared
    if "death" in out:
        out["die"] = dict(out["death"])
    a.add_sprite(sid, body.W, body.H, (body.px, body.H - 1), out, facing="right",
                 meta={"faction": faction, "kind": "character"})
    return anims


def build():
    os.makedirs(ATLAS_DIR, exist_ok=True)
    write_palette_files(os.path.join(ROOT, "docs", "art", "palette"))
    pages = []
    sheets = {}

    # --- characters --------------------------------------------------------
    cp = atl.Atlas("char_player", "character", "battle",
                   "Player roster: hero, worker, infantry. Acquire on battle enter, release on exit.")
    for sid, (body, fn) in chars_player.ALL.items():
        an = add_char(cp, sid, body, fn, "player")
        sheets[sid] = (an, body.W, body.H, (body.px, body.H - 1))
    pages.append(cp)

    ce = atl.Atlas("char_enemy", "character", "battle_roster",
                   "Enemy faction 'bramble' (default theme). Split per faction/boss as roster grows.")
    for sid, (body, fn) in chars_enemy.ALL.items():
        an = add_char(ce, sid, body, fn, "enemy")
        sheets[sid] = (an, body.W, body.H, (body.px, body.H - 1))
    pages.append(ce)

    # --- bases ---------------------------------------------------------------
    bp = atl.Atlas("bases", "base", "battle", "Both bases, 3 damage states each. NOT flipped by engine.")
    for sid, fn, facing in [("base_player", bases.player_keep, "right"), ("base_enemy", bases.enemy_fort, "left")]:
        anims = bases.base_anims(fn)
        bp.add_sprite(sid, bases.W, bases.H, bases.PIVOT,
                      {k: dict(frames=[f.a for f in v["frames"]], fps=v["fps"], loop=v["loop"]) for k, v in anims.items()},
                      facing=facing, meta={"kind": "base", "no_flip": True,
                                           "states": {"idle": ">0.5 hp", "damaged": "<=0.5 hp", "ruined": "0 hp"}})
        bp.add_image(sid, anims["idle"]["frames"][0].a, pivot=bases.PIVOT)
        sheets[sid] = (anims, bases.W, bases.H, bases.PIVOT)
    mine_frames = [bases.mine(0), bases.mine(1)]
    bp.add_sprite("prop_mine", bases.MINE_W, bases.MINE_H, bases.MINE_PIVOT,
                  {"idle": dict(frames=[f.a for f in mine_frames], fps=3, loop=True)},
                  facing="right", meta={"kind": "prop", "no_flip": True,
                                        "note": "worker destination behind the player keep"})
    bp.add_image("prop_mine", mine_frames[0].a, pivot=bases.MINE_PIVOT)
    sheets["prop_mine"] = ({"idle": dict(frames=mine_frames, fps=3, loop=True)}, bases.MINE_W, bases.MINE_H, bases.MINE_PIVOT)
    pages.append(bp)

    # --- fx ------------------------------------------------------------------
    fp = atl.Atlas("fx_combat", "fx", "battle", "Projectiles, impacts, skill FX, shadows. Pivot centre unless noted.")
    for sid, (fn, w, h, piv) in fx.SETS.items():
        anims = fn()
        fp.add_sprite(sid, w, h, piv,
                      {k: dict(frames=[f.a for f in v["frames"]], fps=v["fps"], loop=v["loop"]) for k, v in anims.items()},
                      facing="right", meta={"kind": "projectile" if sid.startswith("proj_") else "fx"})
        sheets[sid] = (anims, w, h, piv)
    for sid, cv in fx.shadows().items():
        meta = {"blend": "alpha", "note": "translucent 96/255"} if sid.startswith("shadow") else \
            {"note": "faction ground marker, draw under unit after shadow"}
        fp.add_image(sid, cv.a, pivot=(cv.w // 2, cv.h // 2), meta=meta)
    pages.append(fp)

    # --- ui ------------------------------------------------------------------
    up = atl.Atlas("ui_main", "ui", "always", "HUD/menu icons, cards, 9-slice frames, bars, digits.")
    for k, cv in ui.icons16().items():
        up.add_image(k, cv.a)
    for sk, fn in [("skill_slam", ui.skill_slam), ("skill_rally", ui.skill_rally), ("skill_barrage", ui.skill_barrage)]:
        cv = fn()
        up.add_image("icon_" + sk, cv.a)          # 01 data: skills[].icon
        up.add_image("skill_" + sk, cv.a)         # 02 rule: skill_<skill_id>
    for k, (cv, m) in ui.frames9().items():
        up.add_image(k, cv.a, nine_slice=m)
    for k, cv in ui.bar_fills().items():
        up.add_image(k, cv.a, nine_slice=(1, 1, 1, 1))
    for k, cv in ui.digits().items():
        up.add_image(k, cv.a, pivot=(0, 0))
    for k, cv in ui.digits(col="Z", name_prefix="digit_gold_").items():
        up.add_image(k, cv.a, pivot=(0, 0))
    for k, cv in ui.digits(col="E", name_prefix="digit_red_").items():
        up.add_image(k, cv.a, pivot=(0, 0))
    up.add_image("btn_move_right", ui.move_button(1).a)
    up.add_image("btn_move_left", ui.move_button(-1).a)
    # portraits for deploy cards (01 unit ids) and enemies (wave preview)
    card_map = {k: k for k in ("worker", "melee_basic", "ranged_basic", "tank", "hero_captain")}
    for uid, sid in card_map.items():
        fr = sheets[sid][0]["idle"]["frames"][0].a
        up.add_image("card_" + uid, ui.portrait(fr).a)
    for eid, sid in {k: k for k in ("e_grunt", "e_swarm", "e_spitter")}.items():
        fr = sheets[sid][0]["idle"]["frames"][0].a
        up.add_image("portrait_" + eid, ui.portrait(fr, bg="p", rim="P", hi="V").a)
    pages.append(up)

    # --- biome ---------------------------------------------------------------
    bm = atl.Atlas("biome_meadow", "biome", "per_round",
                   "Meadow parallax layers (640 px seamless period). Acquire for rounds with biome=meadow.")
    meadow = biome.build_meadow()
    layer_meta = []
    for name, cv, meta in meadow:
        bm.add_image(name, cv.a, pivot=(0, 0), meta={k: v for k, v in meta.items()})
        layer_meta.append(dict(frame=name, **meta, size=[cv.w, cv.h]))
    pages.append(bm)

    # --- pack + write ----------------------------------------------------------
    docs = {}
    for p in pages:
        p.pack()
        doc, page = p.write(ATLAS_DIR, REL_ATLAS)
        # No .png.import is written here: Godot must generate it (uid + remap path),
        # see 02-engine R2. project.godot [importer_defaults] gives Lossless/no-mip.
        docs[p.id] = (doc, page)
        print(f"{p.id:14s} {p.size[0]}x{p.size[1]}  regions={doc['unique_regions']:4d}  "
              f"occ={doc['occupancy']:.2f}  disk={doc['disk_bytes']/1024:.1f}KiB  gpu={doc['gpu_bytes']/1048576:.2f}MiB")

    write_manifest(pages, docs, layer_meta)
    write_previews(pages, docs, sheets, meadow)
    write_budget(pages, docs)
    for d in (os.path.join(ROOT, "docs", "art"), HERE):
        open(os.path.join(d, ".gdignore"), "w").close()
    return docs


def write_manifest(pages, docs, layer_meta):
    anim_sets = {}
    for p in pages:
        for sid in p.sprites:
            anim_sets[sid] = p.id
    m = {
        "version": 1,
        "art_version": ART_VERSION,
        "schema": "INTERFACES.md §5.1 (02-engine) + additive keys",
        "pixel_scale": 1,
        "reference_view": [640, 360],
        "conventions": {
            "facing": "characters/projectiles drawn facing RIGHT; engine flip_h for enemy faction. Bases are pre-oriented (no_flip).",
            "pivot": "frame pixel placed on the world point: characters = feet ground point (W/2-ish, H-1); fx/projectiles = centre unless their atlas entry says otherwise",
            "flip_pivot": "when flip_h is used with offset=-pivot, mirrored pivot_x = frame_w - pivot_x",
            "filter": "nearest", "mipmaps": False, "repeat": False,
            "padding": atl.GAP, "extrude": atl.EXTRUDE,
            "scaling": "integer scale only (canvas_items stretch, viewport 640x360 expand)",
            "anim_names": {"character": ["idle", "walk", "attack", "death", "die(alias of death)", "hit", "cast", "work", "carry"],
                           "fx": ["play", "loop"], "projectile": ["fly"], "base": ["idle", "damaged", "ruined"]},
            "events": "anims[*].hit_frame = damage frame index; anims[*].events = named frame indices; points = frame-space offsets (e.g. projectile_spawn)",
        },
        "atlases": [],
        "anim_sets": anim_sets,
        "bases": {
            "player": {"atlas": "bases", "frame": "base_player", "anim_set": "base_player", "states": ["idle", "damaged", "ruined"]},
            "enemy": {"atlas": "bases", "frame": "base_enemy", "anim_set": "base_enemy", "states": ["idle", "damaged", "ruined"]},
        },
        "biomes": {
            bid: {"atlas": "biome_meadow", "clear_color": "#3b5aa8", "layers": layer_meta,
                  "repeat_period": biome.PERIOD,
                  "ground_feet_line": "ground layer row 15 (lane_line); layer view_y = lane ground_y - 15",
                  "aliases": ["biome_01", "meadow"]}
            for bid in ("biome_01", "meadow")
        },
        "ui": {"atlas": "ui_main"},
        "fonts": {
            "ui": "res://assets/fonts/Galmuri11.ttf",
            "ui_bold": "res://assets/fonts/Galmuri11-Bold.ttf",
            "numerals": "res://assets/fonts/Galmuri9.ttf",
            "sizes_px": {"ui": [12, 24, 36], "ui_bold": [12, 24, 36], "numerals": [10, 20]},
            "numerals_charset": "ASCII + ★☆♥×·…%‰▶◀▲ only (no Hangul)",
            "render": {"antialiasing": "none", "hinting": "none", "subpixel_positioning": "disabled",
                       "msdf": False, "mipmaps": False, "allow_system_fallback": False},
            "license": "SIL OFL 1.1 — res://assets/fonts/OFL-Galmuri.txt (Galmuri © Lee Minseo)",
            "doc": "docs/art/TYPOGRAPHY.md",
        },
        "icons": {
            "resource": {"in_round_currency": "icon_gold (alias icon_supply)", "skill_energy": "icon_mana (alias icon_energy)",
                         "worker": "icon_worker", "meta_currency_candidate": "icon_gem"},
            "cards": "card_<unit_id> (worker, melee_basic, ranged_basic, tank, hero_captain)",
            "skills": "icon_<skill_id> and skill_<skill_id>",
            "enemy_portraits": "portrait_<enemy_id>",
        },
        "load_groups": {
            "always": [p.id for p in pages if p.load_policy == "always"],
            "battle": [p.id for p in pages if p.load_policy in ("battle", "battle_roster")],
            "per_biome": {"biome_01": ["biome_meadow"], "meadow": ["biome_meadow"]},
        },
        "provenance": {
            "author": "03-art (Claude, claude-opus-5.5) via hand-written deterministic code in tools/art/*.py",
            "method": "ASCII pixel maps + Bresenham line rig + procedural shapes, rendered with Python 3.11 / Pillow 11.2 / numpy 2.2. "
                      "No AI image generation, no external/stock/reference images, no fonts.",
            "palette": "Hearth-48 (original, docs/art/palette/hearth48.gpl)",
            "reproduce": "python tools/art/build.py && python tools/art/validate.py",
            "license": "Original work created for this project; owned by the project owner. No third-party assets included.",
        },
    }
    total_gpu = total_disk = 0
    for p in pages:
        d, _ = docs[p.id]
        total_gpu += d["gpu_bytes"]
        total_disk += d["disk_bytes"]
        m["atlases"].append({
            "id": p.id, "group": p.group, "load_policy": p.load_policy,
            "image": f"res://{REL_ATLAS}/{p.id}.png", "frames": f"res://{REL_ATLAS}/{p.id}.json",
            "size": d["size"], "disk_bytes": d["disk_bytes"], "gpu_bytes": d["gpu_bytes"],
            "biome": "meadow" if p.id == "biome_meadow" else "",
            "anim_sets": sorted(p.sprites), "image_frames": len(p.images),
        })
    m["totals"] = {"disk_bytes": total_disk, "gpu_bytes_all_pages": total_gpu,
                   "note": "GPU = w*h*4 (RGBA8, lossless import, no mipmaps). See docs/art/ATLAS_BUDGET.md"}
    with open(os.path.join(ROOT, "assets", "manifest.json"), "w", newline="\n", encoding="utf-8") as f:
        json.dump(m, f, indent=1, ensure_ascii=False)
        f.write("\n")


def write_previews(pages, docs, sheets, meadow):
    os.makedirs(os.path.join(PREV, "sheets"), exist_ok=True)
    for old in os.listdir(os.path.join(PREV, "sheets")):   # prune sheets of renamed/removed sets
        if old.endswith(".png") and old[:-4] not in sheets:
            os.remove(os.path.join(PREV, "sheets", old))
    for p in pages:
        _, page = docs[p.id]
        img = Image.fromarray(RGBA[page], "RGBA")
        sc = 2 if max(p.size) <= 1024 else 1
        big = img.resize((p.size[0] * sc, p.size[1] * sc), Image.NEAREST)
        bg = checker(big.width, big.height, 8)
        bg.alpha_composite(big)
        bg.save(os.path.join(PREV, f"atlas_{p.id}.png"))
    for sid, (an, w, h, piv) in sheets.items():
        anim_sheet(sid, {k: [f.a for f in v["frames"]] for k, v in an.items()}, w, h, piv,
                   scale=4 if max(w, h) <= 48 else 2, path=os.path.join(PREV, "sheets", f"{sid}.png"))
    battle_mock(sheets, meadow, docs)


def battle_mock(sheets, meadow, docs):
    """Approximate in-game composition at 640x360 (1x) and 2x, for readability review."""
    from ui import icons16
    W = 640
    img = biome.compose_preview(meadow, W, cam=0)
    ground_y = 295

    def put(sid, anim, fi, x, flip=False):
        an, w, h, piv = sheets[sid]
        f = an[anim]["frames"][fi % len(an[anim]["frames"])].a
        if flip:
            f = f[:, ::-1]
            pvx = w - piv[0]
        else:
            pvx = piv[0]
        im = Image.fromarray(RGBA[f], "RGBA")
        img.alpha_composite(im, (int(x - pvx), int(ground_y - piv[1])))

    # shadows + faction markers
    shadow = Image.fromarray(RGBA[fx.shadows()["shadow_m"].a], "RGBA")
    mk = {k: Image.fromarray(RGBA[v.a], "RGBA") for k, v in fx.shadows().items() if k.startswith("marker_")}
    put("base_player", "idle", 0, 40)
    put("base_enemy", "damaged", 0, 600)
    ally = [("worker", "work", 3, 92), ("tank", "walk", 1, 190), ("melee_basic", "attack", 2, 260),
            ("melee_basic", "walk", 3, 232), ("ranged_basic", "attack", 1, 205), ("hero_captain", "attack", 3, 300)]
    enemy = [("e_grunt", "attack", 2, 335), ("e_swarm", "walk", 1, 360), ("e_grunt", "walk", 2, 390),
             ("e_spitter", "attack", 2, 430), ("e_swarm", "walk", 3, 452)]
    for sid, a, fi, x in ally + enemy:
        img.alpha_composite(shadow, (x - 10, ground_y - 3))
    for sid, a, fi, x in ally:
        img.alpha_composite(mk["marker_ally_m"], (x - 10, ground_y - 3))
    for sid, a, fi, x in enemy:
        img.alpha_composite(mk["marker_enemy_m"], (x - 10, ground_y - 3))
    for sid, a, fi, x in ally:
        put(sid, a, fi, x)
    for sid, a, fi, x in enemy:
        put(sid, a, fi, x, flip=True)
    # fx
    for sid, a, fi, (x, y) in [("hit_spark", "play", 2, (318, 272)), ("arrow", "fly", 0, (300, 262)),
                               ("spit", "fly", 1, (360, 255)), ("coin", "loop", 0, (340, 250))]:
        an, w, h, piv = sheets[sid]
        f = an[a]["frames"][fi].a
        img.alpha_composite(Image.fromarray(RGBA[f], "RGBA"), (x - piv[0], y - piv[1]))
    # minimal HUD sketch (04 owns real layout): icons + cards + buttons
    ic = icons16()
    for i, k in enumerate(["icon_gold", "icon_mana", "icon_worker"]):
        img.alpha_composite(Image.fromarray(RGBA[ic[k].a], "RGBA"), (8 + i * 54, 6))
    ui_doc, ui_page = docs["ui_main"]
    uim = Image.fromarray(RGBA[ui_page], "RGBA")

    def ui_put(name, x, y, s=1):
        fr = ui_doc["frames"][name]
        crop = uim.crop((fr["x"], fr["y"], fr["x"] + fr["w"], fr["y"] + fr["h"]))
        if s != 1:
            crop = crop.resize((fr["w"] * s, fr["h"] * s), Image.NEAREST)
        img.alpha_composite(crop, (x, y))
    ui_put("btn_move_left", 8, 318)
    ui_put("btn_move_right", 46, 318)
    for i, k in enumerate(["card_worker", "card_melee_basic", "card_ranged_basic", "card_tank"]):
        ui_put(k, 200 + i * 30, 326)
    for i, k in enumerate(["icon_skill_slam", "icon_skill_rally", "icon_skill_barrage"]):
        ui_put(k, 540 + i * 30, 326)
    ui_put("icon_pause", 620, 8)
    img.save(os.path.join(PREV, "battle_mock_1x.png"))
    img.resize((W * 2, 720), Image.NEAREST).save(os.path.join(PREV, "battle_mock_2x.png"))


def write_budget(pages, docs):
    rows = []
    tg = td = 0
    for p in pages:
        d, _ = docs[p.id]
        tg += d["gpu_bytes"]
        td += d["disk_bytes"]
        rows.append(f"| `{p.id}` | {p.group} | {p.load_policy} | {d['size'][0]}×{d['size'][1]} | "
                    f"{d['disk_bytes']/1024:.1f} KiB | {d['gpu_bytes']/1048576:.2f} MiB | {d['occupancy']:.2f} | {d['unique_regions']} |")
    battle = sum(docs[p.id][0]["gpu_bytes"] for p in pages if p.load_policy in ("always", "battle", "battle_roster", "per_round"))
    menu = sum(docs[p.id][0]["gpu_bytes"] for p in pages if p.load_policy == "always")
    txt = f"""# ATLAS_BUDGET.md (generated by tools/art/build.py — do not hand-edit)
Art version {ART_VERSION}. Numbers are measured from the written files. GPU bytes = width × height × 4
(RGBA8; import mode Lossless, no VRAM compression, mipmaps off). Godot keeps the decoded image in VRAM only
(no CPU copy for CompressedTexture2D in Lossless mode); add ~0 for mipmaps (disabled).

| Page | Group | Load policy | Size | Disk (PNG, 8-bit indexed) | GPU (RGBA8) | Occupancy | Unique regions |
|---|---|---|---|---|---|---|---|
{chr(10).join(rows)}
| **Total** | | | | **{td/1024:.1f} KiB** | **{tg/1048576:.2f} MiB** | | |

Residency by scene (provisional, matches ENGINE.md §8 load rules):
- Menu / round select: `always` pages only = **{menu/1048576:.2f} MiB**.
- Battle (one biome, current roster): all pages above = **{battle/1048576:.2f} MiB** (budget: low tier ≤ 32 MiB total textures, ENGINE.md §7).
- Each extra biome adds one `biome_<id>` page (~2 MiB at 1024×512) but only one biome is resident at a time.

Disk sizes are the source PNGs. Godot's Lossless import re-encodes into `.ctex` (PNG/WebP lossless) inside the PCK; the
exported size has to be measured by 04's export (untested here).
"""
    with open(os.path.join(ROOT, "docs", "art", "ATLAS_BUDGET.md"), "w", newline="\n", encoding="utf-8") as f:
        f.write(txt)


if __name__ == "__main__":
    build()
