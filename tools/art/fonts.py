"""Font pipeline (owner: 03-art): subset licensed OFL pixel fonts for shipping.

    python tools/art/fonts.py <dir-with-extracted-Galmuri-release>

Source: Galmuri v2.40.4 by Lee Minseo (quiple), SIL OFL 1.1, no Reserved Font Name.
https://github.com/quiple/galmuri/releases/tag/v2.40.4 (Galmuri-v2.40.4.zip)

Subset kept (deterministic):
  * ASCII U+0020-007E, Latin-1 punctuation/symbols U+00A0-00FF
  * General punctuation U+2010-2027,U+2030-203A, arrows U+2190-2199,
    shapes/symbols used by UI (★☆♥♡●○■□▲△▶▷◀◁※·…×÷∞%)
  * CJK symbols U+3000-3011, Hangul compatibility jamo U+3131-318E
  * Hangul syllables: ALL 11,172 (U+AC00-D7A3). validate.py also fails the
    build if any glyph used in data/**/*.json text is missing (no tofu).
  * Fullwidth forms U+FF01-FF5E
Dropped: CJK ideographs, kana, other scripts (not used by ko/en text).
"""
from __future__ import annotations

import glob
import hashlib
import json
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "fonts")

SOURCE = {
    "release": "Galmuri v2.40.4",
    "url": "https://github.com/quiple/galmuri/releases/download/v2.40.4/Galmuri-v2.40.4.zip",
    "zip_sha256": "C8B3D9861A62AE73C8B1178091401CD79994812437EF386413F6DD54856E60E7",
    "license": "SIL Open Font License 1.1 (no Reserved Font Name declared)",
    "copyright": "Copyright (c) 2019-2025 Lee Minseo (quiple@quiple.dev)",
}

# role -> (source file, native pixel grid size, intended use)
FONTS = {
    "Galmuri11.ttf": ("Galmuri11.ttf", 12, "body/labels/buttons (min Hangul size)"),
    "Galmuri11-Bold.ttf": ("Galmuri11-Bold.ttf", 12, "emphasis, numbers, titles at 24/36"),
    "Galmuri9.ttf": ("Galmuri9.ttf", 10, "numerals/short Latin ONLY (costs, timers, x2); subset has no Hangul"),
}

NUMERAL_SET = sorted(set(range(0x20, 0x7F)) | {ord(ch) for ch in "★☆♥×·…%‰▶◀▲"})
SYMBOLS = "★☆♥♡●○■□▲△▶▷◀◁※·…×÷∞‰"


def data_chars():
    chars = set()
    for p in glob.glob(os.path.join(ROOT, "data", "**", "*.json"), recursive=True):
        try:
            t = open(p, encoding="utf-8").read()
        except (OSError, UnicodeDecodeError):
            continue
        chars |= {ch for ch in t if ord(ch) >= 0x20}
    return chars


def ks_x_1001_hangul():
    out = []
    for cp in range(0xAC00, 0xD7A4):
        try:
            chr(cp).encode("euc_kr")
            out.append(cp)
        except UnicodeEncodeError:
            pass
    return out


def unicodes():
    u = set(range(0x20, 0x7F)) | set(range(0xA0, 0x100))
    u |= set(range(0x2010, 0x2028)) | set(range(0x2030, 0x203B)) | set(range(0x2190, 0x219A))
    u |= set(range(0x3000, 0x3012)) | set(range(0x3131, 0x318F)) | set(range(0xFF01, 0xFF5F))
    u |= {ord(ch) for ch in SYMBOLS}
    u |= set(range(0xAC00, 0xD7A4))   # all 11,172 syllables (GSUB closure keeps them anyway; explicit = no tofu for any Korean text)
    u |= {ord(ch) for ch in data_chars() if 0xAC00 <= ord(ch) <= 0xD7A3}
    u |= {ord(ch) for ch in data_chars() if ord(ch) < 0x3000}
    return sorted(u)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest().upper()


def build(src_dir):
    os.makedirs(OUT, exist_ok=True)
    us = unicodes()
    report = {"source": SOURCE, "subset_codepoints": len(us), "fonts": {}}
    for out_name, (src_name, grid, use) in FONTS.items():
        src = os.path.join(src_dir, src_name)
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]          # keep copyright/licence/name records
        opts.name_languages = ["*"]
        opts.notdef_outline = True
        opts.recalc_timestamp = False  # deterministic output
        opts.glyph_names = False
        opts.hinting = False
        font = TTFont(src, recalcTimestamp=False)
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=(NUMERAL_SET if out_name == "Galmuri9.ttf" else us))
        sub.subset(font)
        dst = os.path.join(OUT, out_name)
        font.save(dst)
        cmap = TTFont(dst).getBestCmap()
        report["fonts"][out_name] = {
            "source_file": src_name, "source_sha256": sha256(src), "source_bytes": os.path.getsize(src),
            "bytes": os.path.getsize(dst), "sha256": sha256(dst), "glyphs": len(cmap),
            "hangul_syllables": sum(1 for c in cmap if 0xAC00 <= c <= 0xD7A3),
            "native_px": grid, "use": use,
            "use_sizes_px": [grid, grid * 2, grid * 3],
        }
        print(f"{out_name:20s} {os.path.getsize(src)/1024:8.0f} KiB -> {os.path.getsize(dst)/1024:6.0f} KiB  glyphs={len(cmap)}")
    with open(os.path.join(src_dir, "LICENSE.txt"), encoding="utf-8") as f:
        lic = f.read()
    with open(os.path.join(OUT, "OFL-Galmuri.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(lic.rstrip() + "\n")
    with open(os.path.join(OUT, "fonts_provenance.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, indent=1, ensure_ascii=False)
        f.write("\n")
    return report


def coverage_errors():
    """Used by validate.py: every char in data/** text must exist in every shipped font."""
    errs = []
    need = {ch for ch in data_chars() if ord(ch) >= 0x20 and not ch.isspace()}
    for name in FONTS:
        p = os.path.join(OUT, name)
        if not os.path.exists(p):
            errs.append(f"font missing: assets/fonts/{name}")
            continue
        cmap = TTFont(p).getBestCmap()
        miss = sorted(ch for ch in need if ord(ch) not in cmap)
        if name == "Galmuri9.ttf":
            miss = [ch for ch in need if ord(ch) < 0x7F and ord(ch) not in cmap]
        if miss:
            errs.append(f"{name}: {len(miss)} data glyphs missing: {''.join(miss[:30])}")
    return errs


if __name__ == "__main__":
    build(sys.argv[1])
    e = coverage_errors()
    print("coverage:", "OK" if not e else e)
