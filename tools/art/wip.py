"""Quick iteration: python tools/art/wip.py <sprite_id> -> docs/art/previews/wip/<id>.png"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

import chars_player  # noqa: E402
from preview import anim_sheet  # noqa: E402

REG = {}
REG.update(chars_player.ALL)
import chars_r04  # noqa: E402
REG.update(chars_r04.ALL)
try:
    import chars_enemy  # noqa: E402
    REG.update(chars_enemy.ALL)
except ImportError:
    pass

import time  # noqa: E402

tag = os.environ.get("WIP_TAG", time.strftime("%H%M%S"))
ids = sys.argv[1:] or list(REG)
for sid in ids:
    body, fn = REG[sid]
    anims = fn()
    out = os.path.join(ROOT, "docs", "art", "previews", "wip", f"{sid}_{tag}.png")
    anim_sheet(sid, {k: [f.a for f in v["frames"]] for k, v in anims.items()}, body.W, body.H, (body.px, body.H - 1),
               scale=int(os.environ.get("WIP_SCALE", "4")), path=out)
    print("wrote", out)
