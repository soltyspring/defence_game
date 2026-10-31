#!/usr/bin/env python3
"""Per-commit static asset budget gate (owner: 08-performance). Evidence class STATIC: file headers + git trees, no engine, no device.

Compares a base tree (default: the pre-retheme commit 37b9a93) with a target tree (a commit, the working tree, or a directory) and checks
the re-theme caps of docs/performance/RETHEME_BUDGET.md. Measures, per file and in total:
  * atlas PNG: disk bytes, pixel size (IHDR), GPU memory estimate from the Godot .import settings
      lossless/lossy (compress/mode 0/1) -> w*h*4, VRAM compressed (mode 2, ETC2/ASTC class) -> w*h*1, +1/3 if mipmaps/generate=true;
  * page residency per round (roster -> pages, same rules as tools/perf/budget_inventory.py; reuses it on the extracted tree);
  * WAV: disk, decoded PCM bytes (data chunk), duration, rate/channels/bits;
  * OGG Vorbis: disk, duration and decoded PCM size if it were fully decoded (granule position x channels x 2) — streamed music stays
    near its disk size in RAM, the decoded figure is reported for completeness;
  * optional APK(s): total size and compressed game content (zip entries under assets/).
Git trees are read with `git archive` (no checkout, no index change), so other workers' uncommitted WIP never leaks into a commit check.

Usage (workspace root):
  python tools/perf/asset_budget_check.py                         # base 37b9a93 vs HEAD
  python tools/perf/asset_budget_check.py --rev <commit>          # base vs that commit
  python tools/perf/asset_budget_check.py --worktree              # base vs current working tree (WIP preview, not a commit result)
  python tools/perf/asset_budget_check.py --range 37b9a93..HEAD   # every commit in the range that touched assets/ or data/
  python tools/perf/asset_budget_check.py --tree <dir>            # any extracted project tree (used by the self-test)
  options: --base <commit>  --apk-before <apk> --apk-after <apk>  --report-only (never exit 1 on a cap breach)
Exit: 0 = all caps PASS (or --report-only); 1 = at least one cap FAIL; 2 = input error.
Output: build/perf/asset_check/<label>/report.json + report.md, and one ASSET_CHECK line per checked tree.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import glob
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tarfile
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MiB = 1024 * 1024
DEFAULT_BASE = "37b9a93"
TREE_PATHS = ["assets", "data", "src/gameplay/battle.gd", "export_presets.cfg"]

# Caps: docs/performance/RETHEME_BUDGET.md §3 (provisional, set with 03/05 on 2026-10-31).
CAPS = {
    "atlas_worst_battle_gpu": 12 * MiB,
    "atlas_menu_gpu": 0.5 * MiB,
    "atlas_all_pages_gpu": 14 * MiB,
    "atlas_page_max_side_px": 1024,
    "atlas_png_disk": 1 * MiB,
    "sfx_pcm_resident": 2 * MiB,
    "sfx_count": 48,
    "sfx_longest_s": 3.5,
    "music_tracks": 4,
    "music_stream_disk": 1.5 * MiB,
    "audio_disk_total": 3 * MiB,
    "apk_total": 60 * MiB,
    "apk_content_growth": 2 * MiB,
}
CAP_OWNER = {"atlas": "03-art", "sfx": "05-audio", "music": "05-audio", "audio": "05-audio", "apk": "04-client (build) / 03+05 (content)"}


# ------------------------------------------------------------------ trees
def git(*args) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def extract_commit(rev: str, dest: str) -> str:
    sha = git("rev-parse", "--short", rev)
    paths = []
    for p in TREE_PATHS:
        try:
            git("cat-file", "-e", f"{sha}:{p}")
            paths.append(p)
        except subprocess.CalledProcessError:
            pass
    data = subprocess.check_output(["git", "archive", "--format=tar", sha, *paths], cwd=ROOT)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    with tarfile.open(fileobj=io.BytesIO(data)) as tf:
        tf.extractall(dest, filter="data")
    return sha


def copy_worktree(dest: str) -> None:
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for p in TREE_PATHS:
        src = os.path.join(ROOT, p)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(dest, p), ignore=shutil.ignore_patterns("*.import"), dirs_exist_ok=True)
            for imp in glob.glob(os.path.join(src, "**", "*.import"), recursive=True):   # keep .import next to sources
                rel = os.path.relpath(imp, ROOT)
                os.makedirs(os.path.dirname(os.path.join(dest, rel)), exist_ok=True)
                shutil.copy2(imp, os.path.join(dest, rel))
        elif os.path.isfile(src):
            os.makedirs(os.path.dirname(os.path.join(dest, p)) or dest, exist_ok=True)
            shutil.copy2(src, os.path.join(dest, p))


# ------------------------------------------------------------------ file measurements
def png_size(path: str):
    with open(path, "rb") as f:
        h = f.read(26)
    if h[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    return struct.unpack(">II", h[16:24])


def import_params(path: str) -> dict:
    p = path + ".import"
    out = {"import_found": os.path.isfile(p), "compress_mode": 0, "mipmaps": False}
    if out["import_found"]:
        for line in open(p, encoding="utf-8", errors="replace"):
            line = line.strip()
            if line.startswith("compress/mode="):
                out["compress_mode"] = int(line.split("=", 1)[1] or 0)
            elif line.startswith("mipmaps/generate="):
                out["mipmaps"] = line.split("=", 1)[1].strip().lower() == "true"
    return out


def gpu_estimate(w: int, h: int, imp: dict) -> int:
    bpp = 1 if imp["compress_mode"] == 2 else 4      # mode 2 = VRAM compressed (ETC2/ASTC 4x4 ~ 8 bpp RGBA)
    b = w * h * bpp
    return int(b * 4 / 3) if imp["mipmaps"] else b


def wav_info(path: str) -> dict:
    data = open(path, "rb").read()
    out = {"pcm_bytes": 0, "seconds": 0.0}
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        out["error"] = "not RIFF/WAVE"
        return out
    pos, fmt = 12, None
    while pos + 8 <= len(data):
        cid, size = data[pos:pos + 4], struct.unpack("<I", data[pos + 4:pos + 8])[0]
        if cid == b"fmt ":
            _tag, ch, rate, _br, _al, bits = struct.unpack("<HHIIHH", data[pos + 8:pos + 24])
            fmt = {"channels": ch, "rate": rate, "bits": bits}
        elif cid == b"data":
            out["pcm_bytes"] = size
        pos += 8 + size + (size & 1)
    if fmt:
        out.update(fmt)
        bps = fmt["rate"] * fmt["channels"] * fmt["bits"] // 8
        out["seconds"] = round(out["pcm_bytes"] / bps, 3) if bps else 0.0
    return out


def ogg_info(path: str) -> dict:
    """Vorbis identification header (channels, rate) + last page granule position = total samples per channel."""
    data = open(path, "rb").read()
    out = {"seconds": 0.0, "decoded_pcm_bytes": 0}
    i = data.find(b"\x01vorbis")
    if i < 0:
        out["error"] = "no vorbis id header"
        return out
    ch = data[i + 11]
    rate = struct.unpack("<I", data[i + 12:i + 16])[0]
    last = data.rfind(b"OggS")
    granule = struct.unpack("<q", data[last + 6:last + 14])[0] if last >= 0 else 0
    out.update({"channels": ch, "rate": rate, "samples": granule})
    if rate and granule > 0:
        out["seconds"] = round(granule / rate, 3)
        out["decoded_pcm_bytes"] = granule * ch * 2
    return out


def apk_info(apk: str) -> dict:
    z = zipfile.ZipFile(apk)
    content = sum(i.compress_size for i in z.infolist() if i.filename.startswith("assets/"))
    libs = sum(i.compress_size for i in z.infolist() if i.filename.startswith("lib/"))
    return {"apk": os.path.relpath(apk, ROOT), "bytes": os.path.getsize(apk), "content_compressed": content, "libs_compressed": libs,
            "mtime": _dt.datetime.fromtimestamp(os.path.getmtime(apk)).isoformat(timespec="seconds")}


# ------------------------------------------------------------------ tree summary
def measure_tree(tree: str, label: str, work: str) -> dict:
    man_path = os.path.join(tree, "assets", "manifest.json")
    if not os.path.isfile(man_path):
        raise FileNotFoundError(f"{label}: assets/manifest.json missing")
    manifest = json.load(open(man_path, encoding="utf-8"))
    pages = {}
    for a in manifest.get("atlases", []):
        img = os.path.join(tree, str(a.get("image", "")).replace("res://", "").replace("/", os.sep))
        row = {"id": a.get("id"), "png": os.path.relpath(img, tree).replace(os.sep, "/"), "exists": os.path.isfile(img)}
        if row["exists"]:
            w, h = png_size(img)
            imp = import_params(img)
            row.update({"w": w, "h": h, "disk": os.path.getsize(img), "gpu": gpu_estimate(w, h, imp), **imp})
        pages[row["id"]] = row
    audio = {}
    for p in sorted(glob.glob(os.path.join(tree, "assets", "audio", "**", "*.*"), recursive=True)):
        ext = os.path.splitext(p)[1].lower()
        rel = os.path.relpath(p, tree).replace(os.sep, "/")
        if ext == ".wav":
            audio[rel] = {"kind": "wav", "disk": os.path.getsize(p), **wav_info(p)}
        elif ext == ".ogg":
            audio[rel] = {"kind": "ogg", "disk": os.path.getsize(p), **ogg_info(p)}
    # residency per round: run the existing inventory tool inside the extracted tree (same rules as for the working tree)
    inv_dir = os.path.join(tree, "tools", "perf")
    os.makedirs(inv_dir, exist_ok=True)
    shutil.copy2(os.path.join(ROOT, "tools", "perf", "budget_inventory.py"), inv_dir)
    out_dir = os.path.join(work, f"inventory_{label}")
    r = subprocess.run([sys.executable, os.path.join(inv_dir, "budget_inventory.py"), "--out", out_dir], cwd=tree, capture_output=True, text=True)
    rounds, menu = {}, 0
    if r.returncode == 0 and os.path.isfile(os.path.join(out_dir, "inventory.json")):
        inv = json.load(open(os.path.join(out_dir, "inventory.json"), encoding="utf-8"))
        # recompute with the import-aware GPU estimate per page
        gpu_of = {k: v.get("gpu", 0) for k, v in pages.items()}
        for rid, row in inv["residency"]["rounds"].items():
            rounds[rid] = {"pages": row["engine_pages"], "gpu": sum(gpu_of.get(p, 0) for p in row["engine_pages"])}
        menu = sum(gpu_of.get(p, 0) for p in inv["residency"]["menu_pages"])
        missing_art = sorted({s for v in inv["residency"]["anim_sets_without_art"].values() for s in v})
    else:
        # Never report a silent 0 MiB residency (it would PASS every cap): treat as an input error.
        raise RuntimeError(f"{label}: residency inventory failed (exit {r.returncode}): " + (r.stderr or r.stdout)[-300:])
    if not rounds:
        raise RuntimeError(f"{label}: residency inventory produced no rounds")
    sfx = [v for v in audio.values() if v["kind"] == "wav"]
    music = [v for v in audio.values() if v["kind"] == "ogg"]
    present = [p for p in pages.values() if p["exists"]]
    return {
        "label": label, "pages": pages, "audio": audio, "rounds": rounds, "missing_art": missing_art,
        "missing_pngs": [p["id"] for p in pages.values() if not p["exists"]],
        "totals": {
            "atlas_pages": len(present),
            "atlas_all_pages_gpu": sum(p["gpu"] for p in present),
            "atlas_worst_battle_gpu": max((x["gpu"] for x in rounds.values()), default=0),
            "atlas_menu_gpu": menu,
            "atlas_page_max_side_px": max((max(p["w"], p["h"]) for p in present), default=0),
            "atlas_png_disk": sum(p["disk"] for p in present),
            "sfx_count": len(sfx),
            "sfx_pcm_resident": sum(v["pcm_bytes"] for v in sfx),
            "sfx_longest_s": max((v["seconds"] for v in sfx), default=0.0),
            "music_tracks": len(music),
            "music_stream_disk": sum(v["disk"] for v in music),
            "music_decoded_if_not_streamed": sum(v.get("decoded_pcm_bytes", 0) for v in music),
            "audio_disk_total": sum(v["disk"] for v in audio.values()),
        },
    }


# ------------------------------------------------------------------ compare + report
def human(k: str, v) -> str:
    if v is None:
        return "-"
    if k.endswith("_px") or k.endswith("_count") or k in ("music_tracks", "atlas_pages"):
        return str(v)
    if k.endswith("_s"):
        return f"{v:.2f} s"
    return f"{v / MiB:.2f} MiB" if abs(v) >= 0.1 * MiB else f"{v / 1024:.1f} KiB"


def compare(base: dict, tgt: dict, apk_b: dict | None, apk_a: dict | None) -> dict:
    rows, fails = [], []
    for k, cap in CAPS.items():
        if k.startswith("apk"):
            continue
        val = tgt["totals"][k]
        res = "PASS" if val <= cap else "FAIL"
        rows.append({"metric": k, "base": base["totals"][k], "target": val, "cap": cap, "result": res,
                     "owner": CAP_OWNER[k.split("_")[0]]})
        if res == "FAIL":
            fails.append(k)
    for k in ("music_decoded_if_not_streamed",):
        rows.append({"metric": k, "base": base["totals"][k], "target": tgt["totals"][k], "cap": None, "result": "info", "owner": "05-audio"})
    if apk_a:
        res = "PASS" if apk_a["bytes"] <= CAPS["apk_total"] else "FAIL"
        rows.append({"metric": "apk_total", "base": apk_b["bytes"] if apk_b else None, "target": apk_a["bytes"], "cap": CAPS["apk_total"],
                     "result": res, "owner": CAP_OWNER["apk"]})
        if res == "FAIL":
            fails.append("apk_total")
        if apk_b:
            same = apk_b["bytes"] == apk_a["bytes"] and apk_b["mtime"] == apk_a["mtime"]
            cap = apk_b["content_compressed"] + CAPS["apk_content_growth"]
            res = "n/a" if same else ("PASS" if apk_a["content_compressed"] <= cap else "FAIL")
            rows.append({"metric": "apk_content", "base": apk_b["content_compressed"], "target": apk_a["content_compressed"], "cap": cap,
                         "result": res, "owner": CAP_OWNER["apk"], "note": "same APK file: not evidence" if same else ""})
            if res == "FAIL":
                fails.append("apk_content")
    # per-file changes and per-file caps
    files = []
    for pid in sorted(set(base["pages"]) | set(tgt["pages"])):
        b, t = base["pages"].get(pid), tgt["pages"].get(pid)
        bs = (b or {}).get("w"), (b or {}).get("h")
        ts = (t or {}).get("w"), (t or {}).get("h")
        changed = (b or {}).get("disk") != (t or {}).get("disk") or bs != ts
        over = bool(t and t.get("exists") and max(t["w"], t["h"]) > CAPS["atlas_page_max_side_px"])
        noimp = bool(t and t.get("exists") and not t.get("import_found"))
        if changed or over or noimp or b is None or t is None:
            files.append({"type": "atlas", "id": pid, "status": "added" if b is None else ("removed" if t is None else "changed"),
                          "base": {"size": bs, "disk": (b or {}).get("disk"), "gpu": (b or {}).get("gpu")},
                          "target": {"size": ts, "disk": (t or {}).get("disk"), "gpu": (t or {}).get("gpu"),
                                     "compress_mode": (t or {}).get("compress_mode"), "mipmaps": (t or {}).get("mipmaps")},
                          "size_changed": bs != ts, "over_side_cap": over,
                          "no_import_file": noimp})
            if over:
                fails.append(f"page_side:{pid}")
    for f in sorted(set(base["audio"]) | set(tgt["audio"])):
        b, t = base["audio"].get(f), tgt["audio"].get(f)
        if b and t and b["disk"] == t["disk"]:
            continue
        long_sfx = bool(t and t["kind"] == "wav" and t["seconds"] > CAPS["sfx_longest_s"])
        files.append({"type": t["kind"] if t else b["kind"], "id": f, "status": "added" if b is None else ("removed" if t is None else "changed"),
                      "base": {k: (b or {}).get(k) for k in ("disk", "pcm_bytes", "decoded_pcm_bytes", "seconds", "rate", "channels")},
                      "target": {k: (t or {}).get(k) for k in ("disk", "pcm_bytes", "decoded_pcm_bytes", "seconds", "rate", "channels")},
                      "over_length_cap": long_sfx})
        if long_sfx:
            fails.append(f"sfx_length:{f}")
    fails = sorted(set(fails))
    rounds = {rid: {"base": base["rounds"].get(rid, {}).get("gpu"), "target": v["gpu"]} for rid, v in tgt["rounds"].items()}
    return {"rows": rows, "files": files, "rounds": rounds, "fails": fails}


def write_report(out_dir: str, meta: dict, base: dict, tgt: dict, cmp: dict) -> None:
    os.makedirs(out_dir, exist_ok=True)
    rep = {"evidence_class": "STATIC", **meta, "verdict": "PASS" if not cmp["fails"] else "FAIL", "fails": cmp["fails"],
           "rows": cmp["rows"], "files": cmp["files"], "rounds": cmp["rounds"],
           "missing_art_target": tgt["missing_art"], "missing_pngs_target": tgt["missing_pngs"], "caps": CAPS}
    with open(os.path.join(out_dir, "report.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rep, f, indent=1, ensure_ascii=False)
    L = [f"# Asset budget check {meta['target_label']} vs {meta['base_label']} — {rep['verdict']}",
         f"Generated {meta['generated']} (STATIC; caps: docs/performance/RETHEME_BUDGET.md §3). Target source: {meta['target_source']}.", "",
         "| metric | base | target | cap | result | owner |", "|---|---|---|---|---|---|"]
    for r in cmp["rows"]:
        L.append(f"| {r['metric']} | {human(r['metric'], r['base'])} | {human(r['metric'], r['target'])} | "
                 f"{human(r['metric'], r['cap'])} | {r['result']} | {r['owner']} |")
    L += ["", "| round | base GPU | target GPU |", "|---|---|---|"]
    for rid, v in cmp["rounds"].items():
        L.append(f"| {rid} | {human('x', v['base'])} | {human('x', v['target'])} |")
    L += ["", "## Changed files"]
    if not cmp["files"]:
        L.append("none")
    for fl in cmp["files"]:
        L.append(f"- {fl['type']} `{fl['id']}` {fl['status']}: base {json.dumps(fl['base'], ensure_ascii=False)} -> target "
                 f"{json.dumps(fl['target'], ensure_ascii=False)}" + (" **OVER CAP**" if fl.get("over_side_cap") or fl.get("over_length_cap") else "")
                 + (" (no .import file)" if fl.get("no_import_file") else ""))
    if tgt["missing_art"] or tgt["missing_pngs"]:
        L += ["", f"Missing art in target: anim sets {tgt['missing_art']}, PNGs {tgt['missing_pngs']}"]
    with open(os.path.join(out_dir, "report.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")


def run_one(base_tree, base_label, tgt_tree, tgt_label, tgt_source, work, apk_b, apk_a, base_cache={}):
    if base_label not in base_cache:
        base_cache[base_label] = measure_tree(base_tree, f"base_{base_label}", work)
    base = base_cache[base_label]
    tgt = measure_tree(tgt_tree, f"target_{tgt_label}", work)
    cmp = compare(base, tgt, apk_b, apk_a)
    out_dir = os.path.join(work, tgt_label)
    meta = {"generated": _dt.datetime.now().astimezone().isoformat(timespec="seconds"), "base_label": base_label,
            "target_label": tgt_label, "target_source": tgt_source, "apk_before": apk_b, "apk_after": apk_a}
    write_report(out_dir, meta, base, tgt, cmp)
    t = tgt["totals"]
    print(f"ASSET_CHECK target={tgt_label} base={base_label} verdict={'PASS' if not cmp['fails'] else 'FAIL'} fails={cmp['fails']} "
          f"worst_battle={human('x', t['atlas_worst_battle_gpu'])} all_pages={human('x', t['atlas_all_pages_gpu'])} "
          f"menu={human('x', t['atlas_menu_gpu'])} png={human('x', t['atlas_png_disk'])} sfx={t['sfx_count']}/{human('x', t['sfx_pcm_resident'])} "
          f"music={t['music_tracks']}/{human('x', t['music_stream_disk'])} changed_files={len(cmp['files'])} report={os.path.relpath(out_dir, ROOT)}")
    return cmp["fails"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=DEFAULT_BASE)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--rev", default="")
    g.add_argument("--worktree", action="store_true")
    g.add_argument("--range", default="")
    g.add_argument("--tree", default="")
    ap.add_argument("--apk-before", default="")
    ap.add_argument("--apk-after", default="")
    ap.add_argument("--report-only", action="store_true")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "perf", "asset_check"))
    args = ap.parse_args()
    work = os.path.abspath(args.out)   # the inventory subprocess runs with cwd=<tree>; a relative path would point elsewhere
    os.makedirs(work, exist_ok=True)
    try:
        base_sha = git("rev-parse", "--short", args.base)
        base_tree = os.path.join(work, "_trees", f"base_{base_sha}")
        extract_commit(base_sha, base_tree)
        apk_b = apk_info(args.apk_before) if args.apk_before else None
        apk_a = apk_info(args.apk_after) if args.apk_after else None
        all_fails = []
        if args.range:
            revs = git("rev-list", "--reverse", args.range, "--", "assets", "data").split()
            if not revs:
                print(f"ASSET_CHECK range={args.range}: no commit touched assets/ or data/")
            for rv in revs:
                sha = git("rev-parse", "--short", rv)
                tree = os.path.join(work, "_trees", sha)
                extract_commit(sha, tree)
                all_fails += [f"{sha}:{x}" for x in run_one(base_tree, base_sha, tree, sha, f"commit {sha}", work, apk_b, None)]
        elif args.worktree:
            tree = os.path.join(work, "_trees", "worktree")
            copy_worktree(tree)
            all_fails += run_one(base_tree, base_sha, tree, "worktree", "working tree (includes uncommitted WIP; preview only)", work, apk_b, apk_a)
        elif args.tree:
            all_fails += run_one(base_tree, base_sha, os.path.abspath(args.tree), os.path.basename(os.path.abspath(args.tree)),
                                 f"directory {args.tree}", work, apk_b, apk_a)
        else:
            sha = git("rev-parse", "--short", args.rev or "HEAD")
            tree = os.path.join(work, "_trees", sha)
            extract_commit(sha, tree)
            all_fails += run_one(base_tree, base_sha, tree, sha, f"commit {sha}", work, apk_b, apk_a)
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError, RuntimeError, zipfile.BadZipFile) as e:
        print(f"ASSET_CHECK error: {e}", file=sys.stderr)
        return 2
    print(f"ASSET_CHECK_SUMMARY verdict={'PASS' if not all_fails else 'FAIL'} fails={len(all_fails)} report_only={args.report_only}")
    return 0 if (args.report_only or not all_fails) else 1


if __name__ == "__main__":
    sys.exit(main())
