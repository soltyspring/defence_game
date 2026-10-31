"""Snapshot-only patch for scale-option measurements (owner: 03-art). NEVER run on the main tree.

    python tools/art/scale_option_patch.py <snapshot_dir> <O2|O3>

Reads <snapshot>/project.godot.orig and src/core/app.gd.orig (copies made before the run) and writes
patched copies: O2 = stretch scale_mode "fractional"; O3 = stretch aspect "keep" (letterbox). Both disable
App._apply_pixel_scale (early return) so Godot's own stretch decides the scale. Used for ART_AUDIT round 14.
"""
import sys,re
h,mode=sys.argv[1],sys.argv[2]
pg=open(h+r"\project.godot.orig","rb").read().decode("utf-8")
if mode=="O2": pg=pg.replace('scale_mode="integer"','scale_mode="fractional"')
if mode=="O3": pg=pg.replace('aspect="expand"','aspect="keep"')
open(h+r"\project.godot","wb").write(pg.encode("utf-8"))
a=open(h+r"\src\core\app.gd.orig","rb").read()
a=a.replace(b"func _apply_pixel_scale() -> void:\r\n",b"func _apply_pixel_scale() -> void:\r\n\treturn  # art03 snapshot-only measurement patch\r\n",1)
open(h+r"\src\core\app.gd","wb").write(a)
print(mode, b"art03 snapshot-only" in a, ('fractional' in pg) if mode=="O2" else ('aspect="keep"' in pg))
