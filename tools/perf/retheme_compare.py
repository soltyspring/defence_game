#!/usr/bin/env python3
"""Re-theme budget gate (owner: 08-performance). STATIC evidence only (files on disk / APK zip), no device data.

Compares a committed pre-retheme inventory baseline with the current tree (or another inventory.json) and checks the
re-theme caps agreed with 03 (textures) and 05 (audio) in docs/performance/RETHEME_BUDGET.md.

Usage (workspace root):
  python tools/perf/retheme_compare.py                       # run budget_inventory.py into build/perf/retheme_after, compare
  python tools/perf/retheme_compare.py --after <inventory.json>
  python tools/perf/retheme_compare.py --strict              # exit 1 if any cap is exceeded
Default exit 0 = comparison written (verdict printed as RETHEME caps=PASS|FAIL); 1 = input error, or --strict with a cap breach.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BASELINE = os.path.join(ROOT, "docs", "performance", "baselines", "retheme_before_37b9a93.json")
MiB = 1024 * 1024

# Caps (RETHEME_BUDGET.md §3). Values in bytes unless stated.
CAPS = {
    "atlas_worst_battle_gpu": 12 * MiB,      # low tier 32 MiB textures − ~13 MiB engine/render targets − 2.25 MiB fonts − headroom
    "atlas_menu_gpu": 0.5 * MiB,
    "atlas_all_pages_gpu": 14 * MiB,
    "atlas_page_max_side_px": 1024,
    "atlas_png_disk": 1 * MiB,
    "sfx_pcm_resident": 2 * MiB,             # upper bound: WAV decoded PCM (Godot may store QOA-compressed, smaller)
    "sfx_count": 48,
    "sfx_longest_s": 3.5,
    "music_stream_disk": 1.5 * MiB,
    "music_tracks": 4,
    "audio_disk_total": 3 * MiB,
    "apk_total": 60 * MiB,                   # ENGINE.md provisional, debug universal APK
    "apk_content_growth": 2 * MiB,           # APK assets/ (game content) compressed growth vs baseline
}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def summarize(inv: dict) -> dict:
    atl = inv.get("atlases", [])
    res = inv.get("residency", {})
    rounds = res.get("rounds", {})
    audio = inv.get("audio", {})
    files = audio.get("files", [])
    sfx = [f for f in files if f.get("kind") == "wav"]
    music = [f for f in files if f.get("kind") in ("ogg", "mp3")]
    apk = inv.get("apk") or {}
    content = sum(v["compressed"] for k, v in (apk.get("groups") or {}).items() if k.startswith("assets"))
    return {
        "git": inv.get("git", ""), "generated": inv.get("generated", ""),
        "atlas_pages": len(atl),
        "atlas_all_pages_gpu": sum(p.get("gpu_bytes", 0) for p in atl),
        "atlas_worst_battle_gpu": max((r.get("engine_gpu_bytes", 0) for r in rounds.values()), default=0),
        "atlas_per_round_gpu": {k: r.get("engine_gpu_bytes", 0) for k, r in rounds.items()},
        "atlas_menu_gpu": res.get("menu_gpu_bytes", 0),
        "atlas_page_max_side_px": max((max(p.get("w", 0), p.get("h", 0)) for p in atl), default=0),
        "atlas_page_sizes": {p["id"]: [p.get("w"), p.get("h")] for p in atl},
        "atlas_png_disk": sum(p.get("disk_bytes", 0) for p in atl),
        "sfx_count": len(sfx),
        "sfx_pcm_resident": sum(f.get("pcm_bytes", 0) for f in sfx),
        "sfx_longest_s": max((f.get("seconds", 0) for f in sfx), default=0),
        "music_tracks": len(music),
        "music_stream_disk": sum(f.get("disk_bytes", 0) for f in music),
        "audio_disk_total": sum(f.get("disk_bytes", 0) for f in files),
        "fonts_disk": (inv.get("fonts") or {}).get("disk_bytes", 0),
        "apk_path": apk.get("apk", ""), "apk_total": apk.get("apk_bytes", 0), "apk_content": content,
    }


def fmt(k, v):
    if k.endswith("_px") or k.endswith("_count") or k.endswith("tracks") or k == "atlas_pages":
        return str(v)
    if k.endswith("_s"):
        return f"{v:.2f} s"
    return f"{v / MiB:.2f} MiB"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", default=BASELINE)
    ap.add_argument("--after", default="")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "perf", "retheme_after"))
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()
    if not os.path.isfile(args.baseline):
        print(f"baseline missing: {args.baseline}", file=sys.stderr)
        return 1
    after_path = args.after
    if not after_path:
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "perf", "budget_inventory.py"), "--out", args.out],
                           cwd=ROOT, capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout + r.stderr, file=sys.stderr)
            return 1
        after_path = os.path.join(args.out, "inventory.json")
    b = summarize(load(args.baseline))
    a = summarize(load(after_path))
    rows, fails = [], 0
    keys = ["atlas_pages", "atlas_worst_battle_gpu", "atlas_menu_gpu", "atlas_all_pages_gpu", "atlas_page_max_side_px", "atlas_png_disk",
            "sfx_count", "sfx_pcm_resident", "sfx_longest_s", "music_tracks", "music_stream_disk", "audio_disk_total", "fonts_disk",
            "apk_total", "apk_content"]
    for k in keys:
        cap = CAPS.get(k)
        val = a[k]
        if k == "apk_content":
            cap = (b["apk_content"] + CAPS["apk_content_growth"]) if b["apk_content"] else None
        apk_missing = k.startswith("apk") and not a["apk_total"]
        res = "n/a" if cap is None or apk_missing else ("PASS" if val <= cap else "FAIL")
        if res == "FAIL":
            fails += 1
        rows.append({"metric": k, "before": b[k], "after": val, "cap": cap, "result": res})
    changed_pages = {k: (b["atlas_page_sizes"].get(k), v) for k, v in a["atlas_page_sizes"].items() if b["atlas_page_sizes"].get(k) != v}
    rep = {"evidence_class": "STATIC", "baseline": os.path.relpath(args.baseline, ROOT), "after": os.path.relpath(after_path, ROOT),
           "before_git": b["git"], "after_git": a["git"], "apk_before": b["apk_path"], "apk_after": a["apk_path"],
           "apk_same_file": bool(a["apk_total"]) and b["apk_total"] == a["apk_total"] and os.path.basename(b["apk_path"]) == os.path.basename(a["apk_path"]),
           "rows": rows, "page_size_changes": changed_pages,
           "per_round_gpu": {k: {"before": b["atlas_per_round_gpu"].get(k), "after": v} for k, v in a["atlas_per_round_gpu"].items()},
           "cap_fails": fails}
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "retheme_compare.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rep, f, indent=1, ensure_ascii=False)
    print(f"[retheme] before git {b['git']} -> after git {a['git']}")
    for r in rows:
        cap = "-" if r["cap"] is None else fmt(r["metric"], r["cap"])
        print(f"[retheme] {r['result']:4} {r['metric']:24} before {fmt(r['metric'], r['before']):>11}  after {fmt(r['metric'], r['after']):>11}  cap {cap}")
    if changed_pages:
        print(f"[retheme] page size changes: {changed_pages}")
    if rep["apk_same_file"]:
        print("[retheme] NOTE apk is the same file as the baseline: APK not rebuilt after the re-theme, apk rows are not evidence")
    print(f"RETHEME caps={'PASS' if fails == 0 else 'FAIL'} cap_fails={fails} strict={'on' if args.strict else 'off'}")
    return 1 if (args.strict and fails) else 0


if __name__ == "__main__":
    sys.exit(main())
