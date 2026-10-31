"""Static model of three unlock rules on the relock_cases.json cases (10-research-systems, v0.35). No Godot, read only.

Rules modelled (save.gd semantics as read at f606801; A and B' are PROPOSALS for 02, not code):
  CUR  f606801 step 5: on a content_version change, unlocked_round = open prefix (i == 0 / cleared / previous cleared).
  B'   integer only: on a content_version change, unlocked_round = max(open prefix, shortest prefix of the new order that
       holds every id that was playable before, every cleared id and the round after each cleared id); n + 1 when
       every round is cleared; never written if equal.
  A    id set `open_rounds` (additive field): derived on EVERY load (old saves: content_snapshot.order cut at
       unlocked_round), then union with cleared ids, the round after each cleared id, and order[0]; never shrinks.
       unlocked_round is kept as the longest prefix inside the set (for old builds); no write during the load.
Upgrade locks: CUR/B' use unlocked_round; A uses the number of ids in open_rounds (monotonic).
Usage: python unlock_options_model.py   -> one line per case and rule, then "UNLOCK_MODEL {...}".
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
import relock_variants as rv  # noqa: E402

BASE_SHA = "f606801"
FAST_UNLOCK = 4   # data/units/units.json fast.unlock_round at f606801 (up_fast bought L2 in the make_mid seed)


def order_for(variants, cache, tmp):
    key = "+".join(variants) or "none"
    if key not in cache:
        d = os.path.join(tmp, "v%d" % len(cache))
        shutil.copytree(os.path.join(tmp, "base"), d)
        for v in variants:
            rv.main(d, v)
        o = rv.rj(rv.order_path(d))["rounds"]
        mp = os.path.join(d, "data", "migrations.json")
        ren = (rv.rj(mp).get("round_renames") or {}) if os.path.exists(mp) else {}
        cache[key] = (o, ren, key)
    return cache[key]


def prefix(order, cleared):
    n = 0
    for i, r in enumerate(order):
        if not (i == 0 or r in cleared or order[i - 1] in cleared):
            break
        n = i + 1
    return max(1, n)


def seeds(base_order, insert2_order):
    mid = {"stars": {"r01", "r02", "r03", "r04", "r05"}, "unlocked": 6, "snap": base_order, "key": "none", "open_rounds": None}
    return {
        "make_mid": dict(mid, fast_bought=True),
        "make_complete": {"stars": set(base_order), "unlocked": 11, "snap": base_order, "key": "none", "open_rounds": None},
        "make_new": {"stars": set(), "unlocked": 1, "snap": base_order, "key": "none", "open_rounds": None},
        "make_incons": {"stars": {"r01", "r02"}, "unlocked": 6, "snap": base_order, "key": "none", "open_rounds": None},
        "none": None,
        "relocked": {"stars": {"r01", "r02", "r03", "r04", "r05"}, "unlocked": 3, "snap": insert2_order, "key": "insert2",
                     "open_rounds": None, "fast_bought": True},
    }


def step(rule, s, order, ren, key):
    """Return (new state, playable ids, wrote)."""
    if s is None:   # no file: fresh, nothing saved during the load
        return None, {order[0]}, False
    st = {ren.get(k, k) for k in s["stars"]}
    cleared = st & set(order)
    s2 = dict(s, stars=st)
    changed = key != s["key"]
    wrote = False
    if rule in ("CUR", "B'"):
        u = s["unlocked"]
        if changed:
            pre = prefix(order, cleared)
            if rule == "CUR":
                nu = pre
            else:
                before = {ren.get(x, x) for x in s["snap"][:s["unlocked"]]} | cleared
                before |= {order[i + 1] for i, r in enumerate(order[:-1]) if r in cleared}
                idx = [order.index(x) + 1 for x in before if x in order]
                nu = max([pre] + idx)
                if all(r in cleared for r in order):
                    nu = len(order) + 1
            nu = min(nu, len(order) + 1)
            if nu != u:
                wrote = True
            u = nu
            s2.update(unlocked=u, snap=order, key=key)
        playable = set(order[:u])
        lock_measure = u
    else:   # A
        base_set = s["open_rounds"] if s["open_rounds"] is not None else set(s["snap"][:s["unlocked"]])
        op = {ren.get(x, x) for x in base_set} | cleared | {order[0]}
        for i, r in enumerate(order[:-1]):
            if r in cleared:
                op.add(order[i + 1])
        s2.update(open_rounds=op, key=key, snap=order if changed else s["snap"])
        playable = op & set(order)
        lock_measure = len(op)
        u = len(order) + 1 if all(r in cleared for r in order) else prefix(order, op | cleared)
        s2["unlocked"] = u
    return s2, playable, wrote, lock_measure


def main():
    cases = json.load(open(os.path.join(HERE, "relock_cases.json"), encoding="utf-8"))["cases"]
    tmp = tempfile.mkdtemp(prefix="p10_unlock_model_")
    try:
        z = os.path.join(tmp, "a.zip")
        subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf", "archive", "--format=zip", "-o", z, BASE_SHA, "data"],
                       cwd=ROOT, check=True)
        shutil.unpack_archive(z, os.path.join(tmp, "base"))
        cache = {}
        base_order = order_for([], cache, tmp)[0]
        ins2 = order_for(["insert2"], cache, tmp)[0]
        sd = seeds(base_order, ins2)
        tally = {}
        for c in cases:
            for rule in ("CUR", "B'", "A"):
                s = sd[c["seed"]]
                fails = []
                playable = set()
                for n, vs in enumerate(c["steps"], 1):
                    order, ren, key = order_for(list(vs), cache, tmp)
                    before_play = set() if s is None else {ren.get(x, x) for x in (s["open_rounds"] if rule == "A" and s["open_rounds"] is not None else s["snap"][:s["unlocked"]])}
                    old_ids = set() if s is None else {ren.get(x, x) for x in s["snap"]}
                    res = step(rule, s, order, ren, key)
                    s2, playable, wrote = res[0], res[1], res[2]
                    lm = res[3] if len(res) > 3 else 99
                    cleared = (s2["stars"] & set(order)) if s2 else set()
                    if cleared - playable:
                        fails.append("s%d U1 %s" % (n, ",".join(sorted(cleared - playable))))
                    if (before_play & set(order)) - playable:
                        fails.append("s%d U2 %s" % (n, ",".join(sorted((before_play & set(order)) - playable))))
                    sk = [r for i, r in enumerate(order) if r in playable and r in old_ids and r not in before_play and r not in cleared
                          and not (i == 0 or order[i - 1] in cleared)]
                    if sk:
                        fails.append("s%d U3 %s" % (n, ",".join(sk)))
                    if c.get("no_write") and wrote:
                        fails.append("s%d U4 write" % n)
                    if s and s.get("fast_bought") and lm < FAST_UNLOCK:
                        fails.append("s%d U5 up_fast" % n)
                    s = s2
                mo = [x for x in c.get("must_open", []) if x not in playable]
                ml = [x for x in c.get("must_locked", []) if x in playable]
                if mo:
                    fails.append("must_open %s" % ",".join(mo))
                if ml:
                    fails.append("must_locked %s" % ",".join(ml))
                v = "INFO" if c.get("info_u6") else ("PASS" if not fails else "FAIL")
                tally.setdefault(rule, {"PASS": 0, "FAIL": 0, "INFO": 0})[v] += 1
                print("MODEL %-16s %-4s %s %s" % (c["id"], rule, v, "; ".join(fails)))
        print("UNLOCK_MODEL " + json.dumps(tally))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
