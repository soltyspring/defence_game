"""Build an art variant into a separate folder (owner: 03-art).

    python tools/art/variant_build.py <A|B|base> <out_dir>

Sets ART_VARIANT before the art modules load, redirects atlas pages, previews and layout locks to
<out_dir> (the lock dir is a copy of tools/art/layout_lock, so the shipped locks are untouched), then
restores assets/manifest.json and docs/art/ATLAS_BUDGET.md, which build() always writes in place.
Used for A/B comparisons; the shipped art is still built only by tools/art/build.py.
"""
from __future__ import annotations

import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def main(variant, out):
    os.environ["ART_VARIANT"] = "0" if variant == "base" else variant
    sys.path.insert(0, HERE)
    keep = {p: open(os.path.join(ROOT, p), "rb").read() for p in ("assets/manifest.json", "docs/art/ATLAS_BUDGET.md")}
    os.makedirs(out, exist_ok=True)
    lock = os.path.join(out, "layout_lock")
    if os.path.exists(lock):
        shutil.rmtree(lock)
    shutil.copytree(os.path.join(HERE, "layout_lock"), lock)
    import build
    build.ATLAS_DIR = os.path.join(out, "atlases")
    build.PREV = os.path.join(out, "previews")
    build.LOCK_DIR = lock
    try:
        build.build()
        shutil.copy(os.path.join(ROOT, "assets", "manifest.json"), os.path.join(out, "manifest.json"))
    finally:
        for p, b in keep.items():
            with open(os.path.join(ROOT, p), "wb") as f:
                f.write(b)
    print("variant", variant, "->", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
