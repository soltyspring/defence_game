#!/usr/bin/env python3
"""Static release guard (10-research-systems) for 01 D32 (4): after launch, never lower an upgrade's max_level and
never retire an upgrade. Compares data/meta.json (and round order) of a RELEASED revision with a candidate.
No Godot, writes nothing. The refund path in save.gd stays only as a safety net; this check keeps it unused.

Usage:
  python docs/research/systems/probes/release_guard.py --base <released rev or tag> [--head <rev>] [--head-meta <file>]
Exit 0 = no violation, 1 = violation (ERROR lines), 2 = usage error.
Checks:
  ERROR UPG_REMOVED    an upgrade id of the base is missing in the head (retire = refund + remove, D32 (2))
  ERROR UPG_MAX_DOWN   head max_level < base max_level (levels would be clamped and refunded at first boot)
  WARN  UPG_COST_UP    a cost entry for a level the base already sold went up (no refund; levels kept, D26-2)
  WARN  ROUND_REMOVED  a round id of the base order is missing (stars are kept, unlocks recomputed by id)
  ERROR ROUND_RELOCK   (v0.34) for some player who cleared the first k base rounds in order, the head order makes
                       save.gd step 5 (f606801 lines 506-517: open iff i == 0, or cleared, or previous cleared;
                       unlocked_round = open prefix) close a round the player already CLEARED.
                       Uses head data/migrations.json round_renames when present.
  WARN  ROUND_FRONTIER_MOVED  the same, but only the not-yet-cleared next round closes (e.g. a new round inserted
                       before it must be played first).
  INFO  UPG_ADDED / ROUND_ADDED
  --head-dir <project dir> reads the head data from a folder on disk instead of a revision (for throwaway copies).
"""
import json, os, subprocess, sys


def show(rev, path):
    if rev.startswith("dir:"):
        p = os.path.join(rev[4:], *path.split("/"))
        if not os.path.exists(p):
            return None
        with open(p, encoding="utf-8-sig") as f:
            return json.load(f)
    r = subprocess.run(["git", "show", f"{rev}:{path}"], capture_output=True)
    if r.returncode != 0:
        if path == "data/migrations.json":
            return None
        sys.exit(f"git show {rev}:{path} failed: {r.stderr.decode(errors='replace').strip()}")
    return json.loads(r.stdout.decode("utf-8-sig"))


def open_prefix(order, stars):
    """save.gd f606801 step 5: length of the open prefix of `order` for the set of cleared ids `stars`."""
    n = 0
    for i, rid in enumerate(order):
        if not (i == 0 or rid in stars or order[i - 1] in stars):
            break
        n = i + 1
    return max(1, n)


def relock_cases(bo, ho, renames):
    """Players who cleared bo[:k] in order (k = 0..len-1; real play can only produce such saves)."""
    out = []
    for k in range(0, len(bo)):
        stars = {renames.get(r, r) for r in bo[:k]}
        before = [renames.get(r, r) for r in bo[:k + 1]]   # unlocked_round = k + 1 -> cleared rounds + the next one
        after = ho[:open_prefix(ho, stars)]
        lost = [r for r in before if r in ho and r not in after]
        if lost:
            out.append((k, lost))
    return out


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    base = arg("--base")
    if not base:
        print(__doc__)
        sys.exit(2)
    head = "dir:" + arg("--head-dir") if arg("--head-dir") else arg("--head", "HEAD")
    bm = {u["id"]: u for u in show(base, "data/meta.json")["upgrades"]}
    hmeta = json.load(open(arg("--head-meta"), encoding="utf-8-sig")) if arg("--head-meta") else show(head, "data/meta.json")
    hm = {u["id"]: u for u in hmeta["upgrades"]}
    out = []
    for uid, u in bm.items():
        if uid not in hm:
            out.append(("ERROR", "UPG_REMOVED", f"{uid} (base max_level {u['max_level']})"))
            continue
        h = hm[uid]
        if int(h["max_level"]) < int(u["max_level"]):
            out.append(("ERROR", "UPG_MAX_DOWN", f"{uid} {u['max_level']} -> {h['max_level']}"))
        for i, (a, b) in enumerate(zip(u.get("costs", []), h.get("costs", []))):
            if int(b) > int(a):
                out.append(("WARN", "UPG_COST_UP", f"{uid} L{i + 2} {a} -> {b}"))
    for uid in hm:
        if uid not in bm:
            out.append(("INFO", "UPG_ADDED", uid))
    bo = show(base, "data/rounds/order.json")["rounds"]
    ho = show(head, "data/rounds/order.json")["rounds"] if not arg("--head-meta") else bo
    for r in bo:
        if r not in ho:
            out.append(("WARN", "ROUND_REMOVED", r))
    for r in ho:
        if r not in bo:
            out.append(("INFO", "ROUND_ADDED", r))
    mig = show(head, "data/migrations.json") if not arg("--head-meta") else None
    renames = {str(k): str(v) for k, v in ((mig or {}).get("round_renames") or {}).items()}
    for k, lost in relock_cases(bo, ho, renames):
        cleared = {renames.get(r, r) for r in bo[:k]}
        who = f"player who cleared {k} round(s)" + (f" (up to {bo[k - 1]})" if k else " (new player)")
        lc = [r for r in lost if r in cleared]
        lf = [r for r in lost if r not in cleared]
        if lc:
            out.append(("ERROR", "ROUND_RELOCK", f"{who} loses CLEARED {','.join(lc)}"
                        + (f" and next {','.join(lf)}" if lf else "")))
        else:
            out.append(("WARN", "ROUND_FRONTIER_MOVED", f"{who}: next round {','.join(lf)} closed"))
    for lvl, code, msg in out:
        print("RG", lvl, code, msg)
    n_err = sum(1 for o in out if o[0] == "ERROR")
    print("RELEASE_GUARD", json.dumps({"base": base, "head": arg("--head-meta") or head, "errors": n_err,
          "warnings": sum(1 for o in out if o[0] == "WARN"), "infos": sum(1 for o in out if o[0] == "INFO")}))
    sys.exit(1 if n_err else 0)


if __name__ == "__main__":
    main()
