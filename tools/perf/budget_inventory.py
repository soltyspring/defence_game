#!/usr/bin/env python3
"""Resource budget inventory (owner: 08-performance).

Static, engine-free measurement of what the game will make resident and download:
  * atlas pages: real PNG dimensions (re-read from the file, not trusted from the manifest),
    decompressed RGBA8 GPU bytes (w*h*4, no mipmaps), disk bytes, occupancy, wasted bytes,
    size-limit compliance (ENGINE.md §8: 1024 preferred, 2048 hard);
  * per-round texture residency, both the CONTRACT plan (only pages the round's roster needs)
    and the CURRENT ENGINE behaviour (src/gameplay/battle.gd acquires every enemy anim_set);
  * anim_sets referenced by data/** that have no art (placeholder rendering);
  * audio: decoded PCM RAM for WAV (resident if imported uncompressed), disk for streamed OGG;
  * optional APK breakdown when build/android/*.apk exists.
Compares against PROVISIONAL tier budgets (ENGINE.md §7). Desktop/static numbers only.

Usage (workspace root):
  python tools/perf/budget_inventory.py [--out build/perf] [--write-doc] [--apk path.apk]
Exit 0 = inventory written; 1 = could not read inputs, or --strict and an ADOPTED check failed (contract rules such as the
2048 px hard page limit), or --strict-all and any check failed. Provisional budgets never fail the default or --strict run.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import glob
import json
import os
import struct
import subprocess
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MiB = 1024 * 1024

# PROVISIONAL budgets (ENGINE.md §7 / docs/performance/BUDGETS.md). Texture = resident GPU bytes.
TIERS = {
    "low": {"texture": 32 * MiB, "pss": 250 * MiB, "sfx_ram": 8 * MiB},
    "mid": {"texture": 48 * MiB, "pss": 300 * MiB, "sfx_ram": 12 * MiB},
    "high": {"texture": 64 * MiB, "pss": 350 * MiB, "sfx_ram": 16 * MiB},
}
APK_BUDGET = 60 * MiB
ASSETS_BUDGET = 20 * MiB
PAGE_PREFERRED = 1024
PAGE_HARD = 2048


def res_to_path(p: str) -> str:
    if p.startswith("res://"):
        p = p[len("res://"):]
    return os.path.join(ROOT, p.replace("/", os.sep))


def load_json(path: str):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def png_info(path: str) -> dict:
    """Reads IHDR without decoding: width, height, bit depth, colour type."""
    with open(path, "rb") as f:
        head = f.read(33)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        raise ValueError(f"not a PNG: {path}")
    w, h, depth, ctype = struct.unpack(">IIBB", head[16:26])
    kinds = {0: "gray", 2: "rgb", 3: "indexed", 4: "gray+alpha", 6: "rgba"}
    return {"w": w, "h": h, "bit_depth": depth, "color": kinds.get(ctype, str(ctype))}


def wav_info(path: str) -> dict:
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        return {"error": "not RIFF/WAVE"}
    pos, fmt, pcm_bytes = 12, None, 0
    while pos + 8 <= len(data):
        cid, size = data[pos:pos + 4], struct.unpack("<I", data[pos + 4:pos + 8])[0]
        if cid == b"fmt ":
            tag, ch, rate, _br, _al, bits = struct.unpack("<HHIIHH", data[pos + 8:pos + 24])
            fmt = {"format_tag": tag, "channels": ch, "rate": rate, "bits": bits}
        elif cid == b"data":
            pcm_bytes = size
        pos += 8 + size + (size & 1)
    out = {"pcm_bytes": pcm_bytes}
    if fmt:
        out.update(fmt)
        bps = fmt["rate"] * fmt["channels"] * fmt["bits"] // 8
        out["seconds"] = round(pcm_bytes / bps, 3) if bps else 0
    return out


def git_sha() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return ""


# ---------------------------------------------------------------- atlases
def inventory_atlases(manifest: dict) -> list[dict]:
    pages = []
    for a in manifest.get("atlases", []):
        img = res_to_path(str(a.get("image", "")))
        row = {"id": a.get("id"), "group": a.get("group", ""), "load_policy": a.get("load_policy", ""),
               "biome": a.get("biome", ""), "manifest_size": a.get("size"), "issues": []}
        if not os.path.isfile(img):
            row["issues"].append(f"image missing: {a.get('image')}")
            pages.append(row)
            continue
        info = png_info(img)
        w, h = info["w"], info["h"]
        row.update({"w": w, "h": h, "png_color": info["color"], "png_bit_depth": info["bit_depth"],
                    "disk_bytes": os.path.getsize(img), "gpu_bytes": w * h * 4})
        if a.get("size") and list(a["size"]) != [w, h]:
            row["issues"].append(f"manifest size {a['size']} != PNG {w}x{h}")
        if a.get("gpu_bytes") not in (None, w * h * 4):
            row["issues"].append(f"manifest gpu_bytes {a['gpu_bytes']} != {w * h * 4}")
        if max(w, h) > PAGE_HARD:
            row["issues"].append(f"exceeds hard max {PAGE_HARD}")
        elif max(w, h) > PAGE_PREFERRED:
            row["issues"].append(f"exceeds preferred max {PAGE_PREFERRED}")
        frames_path = res_to_path(str(a.get("frames", "")))
        if os.path.isfile(frames_path):
            fj = load_json(frames_path)
            rects = {(f["x"], f["y"], f["w"], f["h"]) for f in fj.get("frames", {}).values()}
            used = sum(r[2] * r[3] for r in rects)
            row["frames"] = len(fj.get("frames", {}))
            row["unique_rects"] = len(rects)
            row["occupancy"] = round(used / (w * h), 3)
            row["unused_gpu_bytes"] = (w * h - used) * 4
            row["anim_sets"] = sorted(fj.get("anims", {}).keys())
            # tight power-of-two estimate: smallest POT page that could hold the used area at 100% packing
            row["max_frame"] = [max((r[2] for r in rects), default=0), max((r[3] for r in rects), default=0)]
        else:
            row["issues"].append("frames json missing")
        pages.append(row)
    return pages


def round_needs(content_rounds: dict, units: dict, hero: dict, skills: dict) -> dict:
    """anim_sets referenced by each round: cards, every enemy spawn source, hero, projectiles, skill fx."""
    out = {}
    for rid, r in content_rounds.items():
        enemy_ids = set()
        for w in r.get("waves", []):
            for s in w.get("spawns", []):
                enemy_ids.add(s.get("unit"))
        for t in r.get("enemy_base_spawns_on_hp", []):
            for s in t.get("spawns", []):
                enemy_ids.add(s.get("unit"))
        enemy_ids.update(r.get("enemy_ai", {}).get("pool", []))
        enemy_ids.update(r.get("trickle", {}).get("pattern", []))
        for e in list(enemy_ids):  # boss summons
            sm = units.get(e, {}).get("summon")
            if isinstance(sm, dict) and sm.get("unit"):
                enemy_ids.add(sm["unit"])
        player_ids = set(r.get("cards", []))
        need = set()
        for uid in player_ids | enemy_ids:
            u = units.get(uid, {})
            need.add(u.get("anim_set") or uid)
            if u.get("projectile"):
                need.add(u["projectile"])
        hid = r.get("hero") or "hero_captain"
        need.add(hero.get(hid, {}).get("anim_set", hid))
        for sid in r.get("skills", hero.get(hid, {}).get("skills", [])):
            fx = skills.get(sid, {}).get("fx")
            if fx:
                need.add(fx)
        need.add("worker")
        out[rid] = {"biome": r.get("biome", ""), "anim_sets": sorted(x for x in need if x),
                    "enemy_units": sorted(x for x in enemy_ids if x), "player_units": sorted(player_ids)}
    return out


def residency(manifest: dict, pages: list[dict], needs: dict, units: dict) -> dict:
    by_id = {p["id"]: p for p in pages}
    aset_page = manifest.get("anim_sets", {})
    biomes = manifest.get("biomes", {})
    always = [p["id"] for p in pages if p.get("group") == "ui" or p.get("load_policy") == "always"]
    all_enemy_sets = sorted({u.get("anim_set") or u["id"] for u in units.values() if u.get("faction") == "enemy"})
    # Current engine behaviour: battle.gd acquires the round roster via Content.round_enemy_roster (02 e9dfaa4, same sources as
    # round_needs: waves, ai pool, trickle, hp triggers, boss summons) or, in older code, every enemy anim set.
    battle_src = os.path.join(ROOT, "src", "gameplay", "battle.gd")
    engine_uses_roster = os.path.isfile(battle_src) and "round_enemy_roster" in open(battle_src, encoding="utf-8").read()
    rows = {}
    missing_art = {}
    for rid, n in needs.items():
        biome_page = biomes.get(n["biome"], {}).get("atlas")

        def pages_for(sets):
            out = set(always)
            for s in sets:
                if s in aset_page:
                    out.add(aset_page[s])
            for p in pages:  # fx + base groups are always taken by Atlas.pages_for_battle()
                if p.get("group") in ("fx", "base"):
                    out.add(p["id"])
            if biome_page:
                out.add(biome_page)
            return sorted(out)

        contract = pages_for(n["anim_sets"])
        engine = pages_for(n["anim_sets"]) if engine_uses_roster else pages_for(sorted(set(n["anim_sets"]) | set(all_enemy_sets)))
        rows[rid] = {
            "biome": n["biome"], "biome_page": biome_page or "(none: procedural fallback)",
            "contract_pages": contract,
            "contract_gpu_bytes": sum(by_id.get(p, {}).get("gpu_bytes", 0) for p in contract),
            "engine_pages": engine,
            "engine_gpu_bytes": sum(by_id.get(p, {}).get("gpu_bytes", 0) for p in engine),
        }
        miss = [s for s in n["anim_sets"] if s not in aset_page]
        if miss:
            missing_art[rid] = miss
    # Menu screens: always pages + pages with load_policy "menu" (e.g. per-language title logos). Conservative: all menu pages are
    # counted together even if the UI loads only the current locale's logo (gate must never undercount; see RETHEME_BUDGET 17:57).
    menu = sorted(set(always) | {p["id"] for p in pages if p.get("load_policy") == "menu"})
    return {"engine_model": "roster (battle.gd uses Content.round_enemy_roster)" if engine_uses_roster else "all enemy anim sets",
            "menu_pages": menu, "menu_gpu_bytes": sum(by_id.get(p, {}).get("gpu_bytes", 0) for p in menu),
            "rounds": rows, "anim_sets_without_art": missing_art}


# ---------------------------------------------------------------- audio
def inventory_audio() -> dict:
    files = []
    for path in sorted(glob.glob(os.path.join(ROOT, "assets", "audio", "**", "*.*"), recursive=True)):
        ext = os.path.splitext(path)[1].lower()
        if ext not in (".wav", ".ogg", ".mp3"):
            continue
        rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
        row = {"file": rel, "disk_bytes": os.path.getsize(path), "kind": ext[1:]}
        if ext == ".wav":
            row.update(wav_info(path))
        files.append(row)
    wav = [f for f in files if f["kind"] == "wav"]
    return {"files": files,
            "wav_count": len(wav), "wav_disk_bytes": sum(f["disk_bytes"] for f in wav),
            "wav_pcm_bytes": sum(f.get("pcm_bytes", 0) for f in wav),
            "stream_disk_bytes": sum(f["disk_bytes"] for f in files if f["kind"] != "wav"),
            "note": "WAV imported uncompressed stays fully resident as PCM (AudioStreamWAV). OGG streams; RAM ~ decoder buffers."}


# ---------------------------------------------------------------- fonts
def inventory_fonts() -> dict:
    files = []
    for path in sorted(glob.glob(os.path.join(ROOT, "assets", "fonts", "**", "*.*"), recursive=True)):
        ext = os.path.splitext(path)[1].lower()
        if ext in (".ttf", ".otf", ".woff", ".woff2", ".fnt", ".font", ".fontdata"):
            files.append({"file": os.path.relpath(path, ROOT).replace(os.sep, "/"), "disk_bytes": os.path.getsize(path), "kind": ext[1:]})
    return {"files": files, "disk_bytes": sum(f["disk_bytes"] for f in files),
            "note": "Dynamic TTF/OTF: runtime cost = glyph cache textures created on first use per size/outline; measure with "
                    "tests/performance/perf_frame_probe.gd (tex_mem) and on device. Disk cost lands in the APK."}


# ---------------------------------------------------------------- apk
def inventory_apk(apk: str) -> dict:
    z = zipfile.ZipFile(apk)
    groups = {}
    for i in z.infolist():
        top = i.filename.split("/")[0]
        if top == "assets":
            parts = i.filename.split("/")
            top = "/".join(parts[:3]) if len(parts) > 3 else "/".join(parts[:2])
        g = groups.setdefault(top, {"files": 0, "compressed": 0, "uncompressed": 0})
        g["files"] += 1
        g["compressed"] += i.compress_size
        g["uncompressed"] += i.file_size
    biggest = sorted(z.infolist(), key=lambda i: -i.compress_size)[:15]
    return {"apk": os.path.relpath(apk, ROOT), "apk_bytes": os.path.getsize(apk), "groups": groups,
            "largest": [{"name": i.filename, "compressed": i.compress_size, "uncompressed": i.file_size} for i in biggest]}


# ---------------------------------------------------------------- report
def mib(b) -> str:
    return f"{b / MiB:.2f} MiB" if b >= 0.1 * MiB else f"{b / 1024:.1f} KiB"


def build_markdown(inv: dict) -> str:
    L = []
    L.append("# RESOURCE_INVENTORY.md (generated by tools/perf/budget_inventory.py — do not hand-edit)")
    L.append(f"Generated {inv['generated']} at git `{inv['git'] or 'uncommitted'}`. Evidence class: **STATIC (files on disk)**. "
             "No device readings. Budgets are PROVISIONAL (ENGINE.md §7, docs/performance/BUDGETS.md).")
    L.append("")
    L.append("## Atlas pages (decompressed GPU = w×h×4, RGBA8 lossless, no mipmaps)")
    L.append("| Page | Group | Policy | PNG | Disk | GPU | Occupancy | Unused GPU | Issues |")
    L.append("|---|---|---|---|---|---|---|---|---|")
    for p in inv["atlases"]:
        L.append(f"| `{p['id']}` | {p.get('group','')} | {p.get('load_policy','')} | {p.get('w','?')}×{p.get('h','?')} {p.get('png_color','')} | "
                 f"{mib(p.get('disk_bytes',0))} | {mib(p.get('gpu_bytes',0))} | {p.get('occupancy','?')} | {mib(p.get('unused_gpu_bytes',0))} | "
                 f"{'; '.join(p['issues']) or '—'} |")
    t = inv["totals"]
    L.append(f"| **All pages** | | | | **{mib(t['atlas_disk_bytes'])}** | **{mib(t['atlas_gpu_bytes'])}** | | **{mib(t['atlas_unused_gpu_bytes'])}** | |")
    L.append("")
    r = inv["residency"]
    L.append("## Texture residency per scene")
    L.append(f"Current engine residency model: {r.get('engine_model', '?')}. Atlas inputs are the working tree (may include 03 WIP).")
    L.append(f"Menu / round select: {', '.join('`'+x+'`' for x in r['menu_pages'])} = **{mib(r['menu_gpu_bytes'])}**.")
    L.append("")
    L.append("| Round | Biome page | Contract pages (roster only) | Contract GPU | Current engine GPU | Low-tier headroom (32 MiB) |")
    L.append("|---|---|---|---|---|---|")
    for rid, row in r["rounds"].items():
        L.append(f"| {rid} | `{row['biome_page']}` | {', '.join(row['contract_pages'])} | {mib(row['contract_gpu_bytes'])} | "
                 f"{mib(row['engine_gpu_bytes'])} | {mib(TIERS['low']['texture'] - row['engine_gpu_bytes'])} |")
    L.append("")
    L.append("Atlas pages only. Fonts, UI StyleBoxes, the framebuffer (e.g. 2400×1080×4 ≈ 9.9 MiB per buffer on a FHD+ phone) and "
             "driver copies are not included; read `Perf.texture_report()` / `RENDER_TEXTURE_MEM_USED` at runtime and "
             "`dumpsys meminfo` Graphics on device (docs/performance/ANDROID_PROFILING.md).")
    if r["anim_sets_without_art"]:
        L.append("")
        L.append("### anim_sets referenced by data but absent from the atlas manifest (procedural placeholder today)")
        allm = sorted({s for v in r["anim_sets_without_art"].values() for s in v})
        L.append(", ".join(f"`{s}`" for s in allm))
        L.append("Each future page adds its own GPU bytes; re-run this tool after 03 adds them.")
    a = inv["audio"]
    L.append("")
    L.append("## Audio")
    L.append(f"WAV SFX: {a['wav_count']} files, disk {mib(a['wav_disk_bytes'])}, decoded PCM {mib(a['wav_pcm_bytes'])} "
             f"(resident if all loaded uncompressed; low-tier SFX RAM budget {mib(TIERS['low']['sfx_ram'])}). "
             f"Streamed (OGG): disk {mib(a['stream_disk_bytes'])}.")
    fo = inv.get("fonts", {})
    L.append("")
    L.append("## Fonts")
    if fo.get("files"):
        L.append(", ".join(f"`{f['file'].split('/')[-1]}` {mib(f['disk_bytes'])}" for f in fo["files"]) + f" — total {mib(fo['disk_bytes'])} on disk.")
        L.append(fo["note"])
    else:
        L.append("No font files under assets/fonts (engine fallback font only).")
    L.append("")
    L.append("## Download size")
    L.append(f"Source assets on disk (atlases + audio + manifests): **{mib(t['assets_disk_bytes'])}** (budget {mib(ASSETS_BUDGET)}). "
             "Godot re-encodes on import (.ctex / .sample / .oggvorbisstr), so the APK number below is the real one.")
    if inv.get("apk"):
        ap = inv["apk"]
        L.append(f"APK `{ap['apk']}`: **{mib(ap['apk_bytes'])}** (budget {mib(APK_BUDGET)}).")
        L.append("| Group | Files | Compressed | Uncompressed |")
        L.append("|---|---|---|---|")
        for g, v in sorted(ap["groups"].items(), key=lambda kv: -kv[1]["compressed"]):
            L.append(f"| `{g}` | {v['files']} | {mib(v['compressed'])} | {mib(v['uncompressed'])} |")
    else:
        L.append("APK: **not built yet** (no build/android/*.apk). UNMEASURED.")
    L.append("")
    L.append("## Budget checks")
    for c in inv["checks"]:
        L.append(f"- {c['result']} ({c.get('status', 'provisional')}) `{c['id']}`: {c['value']} (budget {c['budget']})")
    return "\n".join(L) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "perf"))
    ap.add_argument("--write-doc", action="store_true", help="also write docs/performance/RESOURCE_INVENTORY.md")
    ap.add_argument("--apk", default="")
    ap.add_argument("--strict", action="store_true", help="exit 1 when an ADOPTED check fails")
    ap.add_argument("--strict-all", action="store_true", help="exit 1 when ANY check (incl. provisional) fails")
    args = ap.parse_args()

    man_path = os.path.join(ROOT, "assets", "manifest.json")
    if not os.path.isfile(man_path):
        print("no assets/manifest.json yet; nothing to inventory", file=sys.stderr)
        return 1
    manifest = load_json(man_path)
    units = {u["id"]: u for u in load_json(os.path.join(ROOT, "data", "units", "units.json")).get("units", [])}
    heroes = {}
    for p in glob.glob(os.path.join(ROOT, "data", "heroes", "*.json")):
        h = load_json(p)
        heroes[h["id"]] = h
    skills = {}
    for p in glob.glob(os.path.join(ROOT, "data", "skills", "*.json")):
        s = load_json(p)
        skills[s["id"]] = s
    order = load_json(os.path.join(ROOT, "data", "rounds", "order.json")).get("rounds", [])
    rounds = {rid: load_json(os.path.join(ROOT, "data", "rounds", f"{rid}.json")) for rid in order}

    pages = inventory_atlases(manifest)
    needs = round_needs(rounds, units, heroes, skills)
    res = residency(manifest, pages, needs, units)
    audio = inventory_audio()
    fonts = inventory_fonts()
    apk_path = args.apk or next(iter(sorted(glob.glob(os.path.join(ROOT, "build", "android", "*.apk")))), "")
    apk = inventory_apk(apk_path) if apk_path and os.path.isfile(apk_path) else None

    assets_disk = 0
    for path in glob.glob(os.path.join(ROOT, "assets", "**", "*"), recursive=True):
        if os.path.isfile(path) and not path.endswith(".import"):
            assets_disk += os.path.getsize(path)
    totals = {"atlas_disk_bytes": sum(p.get("disk_bytes", 0) for p in pages),
              "atlas_gpu_bytes": sum(p.get("gpu_bytes", 0) for p in pages),
              "atlas_unused_gpu_bytes": sum(p.get("unused_gpu_bytes", 0) for p in pages),
              "assets_disk_bytes": assets_disk}
    worst_round = max((v["engine_gpu_bytes"] for v in res["rounds"].values()), default=0)
    checks = []

    def check(cid, value, budget, fmt=mib, adopted=False):
        checks.append({"id": cid, "value": fmt(value), "budget": fmt(budget), "raw": value, "raw_budget": budget,
                       "status": "adopted" if adopted else "provisional",
                       "result": "PASS" if value <= budget else "FAIL"})

    check("battle_texture_resident_low_tier", worst_round, TIERS["low"]["texture"])
    check("sfx_pcm_resident_low_tier", audio["wav_pcm_bytes"], TIERS["low"]["sfx_ram"])
    check("assets_disk", assets_disk, ASSETS_BUDGET)
    if apk:
        check("apk_size", apk["apk_bytes"], APK_BUDGET)
    for p in pages:
        # ENGINE.md §8 hard page limit is a contract rule, so it is ADOPTED (every page reported, pass or fail)
        if "w" in p:
            side = max(p["w"], p["h"])
            checks.append({"id": f"page_size_{p['id']}", "value": f"{p['w']}x{p['h']}", "budget": f"<= {PAGE_HARD}",
                           "status": "adopted", "result": "PASS" if side <= PAGE_HARD else "FAIL"})

    inv = {"generated": _dt.datetime.now().astimezone().isoformat(timespec="seconds"), "git": git_sha(),
           "evidence_class": "STATIC", "tiers_provisional": TIERS, "atlases": pages, "round_needs": needs,
           "residency": res, "audio": audio, "fonts": fonts, "apk": apk, "totals": totals, "checks": checks}
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "inventory.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(inv, f, indent=1, ensure_ascii=False)
    md = build_markdown(inv)
    with open(os.path.join(args.out, "inventory.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(md)
    if args.write_doc:
        with open(os.path.join(ROOT, "docs", "performance", "RESOURCE_INVENTORY.md"), "w", encoding="utf-8", newline="\n") as f:
            f.write(md)
    for c in checks:
        print(f"[inventory] {c['result']:4} {c['status']:11} {c['id']}: {c['value']} (budget {c['budget']})")
    print(f"[inventory] atlas pages={len(pages)} gpu_all={mib(totals['atlas_gpu_bytes'])} worst_battle={mib(worst_round)} "
          f"wav_pcm={mib(audio['wav_pcm_bytes'])} assets_disk={mib(assets_disk)} apk={'%s' % mib(apk['apk_bytes']) if apk else 'none'}")
    print(f"[inventory] wrote {os.path.join(args.out, 'inventory.md')}")
    fails = sum(1 for c in checks if c["result"] == "FAIL")
    adopted_fails = sum(1 for c in checks if c["result"] == "FAIL" and c["status"] == "adopted")
    print(f"INVENTORY fails={fails} adopted_fails={adopted_fails} provisional_fails={fails - adopted_fails} "
          f"strict={'all' if args.strict_all else ('adopted' if args.strict else 'off')}")
    if args.strict_all:
        return 1 if fails else 0
    return 1 if (args.strict and adopted_fails) else 0


if __name__ == "__main__":
    sys.exit(main())
