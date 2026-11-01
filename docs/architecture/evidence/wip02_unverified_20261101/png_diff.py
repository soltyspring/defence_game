"""Pixel diff of two capture folders (same relative PNG names). Prints one line per pair and a total. 02 local tool."""
import os
import sys

import numpy as np
from PIL import Image


def main(a, b):
    pairs = 0
    diff_files = 0
    total = 0
    for dp, _, fs in os.walk(a):
        for f in sorted(fs):
            if not f.endswith(".png"):
                continue
            pa = os.path.join(dp, f)
            pb = os.path.join(b, os.path.relpath(pa, a))
            if not os.path.exists(pb):
                print("MISSING_IN_B", os.path.relpath(pa, a))
                continue
            ia = np.array(Image.open(pa).convert("RGBA"))
            ib = np.array(Image.open(pb).convert("RGBA"))
            pairs += 1
            if ia.shape != ib.shape:
                print("SIZE_DIFF", os.path.relpath(pa, a), ia.shape, ib.shape)
                diff_files += 1
                continue
            n = int(np.any(ia != ib, axis=2).sum())
            total += n
            if n:
                diff_files += 1
            print(f"{os.path.relpath(pa, a)} {ia.shape[1]}x{ia.shape[0]} diff_px={n}")
    print(f"PNG_DIFF pairs={pairs} files_with_diff={diff_files} diff_px_total={total}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
