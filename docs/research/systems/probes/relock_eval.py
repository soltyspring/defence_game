"""Judge a relock_suite_job.ps1 run against relock_cases.json (10-research-systems, v0.35). Reads only.

Usage: python relock_eval.py <out dir> [<job log>]
  <out dir>  the "P10 OUT" folder (holds <case>__s<n>.before.json / .after.json)
  <job log>  build/heavy/10-relock-suite-*.log (RUN lines); default: newest such log
Prints one line per step (generic criteria U1-U5) and one verdict line per case (adds must_open / must_locked),
then "RELOCK_EVAL {...}". Exit 0 always (the verdicts are the result).
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))


def payload(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        env = json.load(f)
    return json.loads(env["payload"]) if isinstance(env.get("payload"), str) else None


def before_open(p):
    """Rounds playable in the save BEFORE the step: old order (content_snapshot.order) cut at unlocked_round."""
    if not p:
        return set(), []
    order = list((p.get("content_snapshot") or {}).get("order") or [])
    u = int(p.get("unlocked_round", 1))
    return set(order[:max(0, u)]), order


def main():
    out = sys.argv[1]
    log = sys.argv[2] if len(sys.argv) > 2 else max(glob.glob(os.path.join(ROOT, "build", "heavy", "10-relock-suite-*.log")), key=os.path.getmtime)
    with open(os.path.join(HERE, "relock_cases.json"), encoding="utf-8") as f:
        cases = json.load(f)["cases"]
    runs = {}
    target = ""
    with open(log, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("P10 TARGET "):
                target = line.split()[2]
            m = re.match(r"^RUN (\S+) sha_before=(\S+) sha_after=(\S+) pre_backups=\[([^\]]*)\] (\{.*\})\s*$", line)
            if m:
                runs[m.group(1)] = {"sha_before": m.group(2), "sha_after": m.group(3), "pre": [x for x in m.group(4).split(",") if x],
                                    "o": json.loads(m.group(5))}
    summary = {"target": target, "log": os.path.relpath(log, ROOT), "cases": 0, "pass": 0, "fail": 0, "info": 0, "missing": 0}
    for c in cases:
        cid = c["id"]
        fails = []
        n_steps = len(c["steps"])
        last = None
        prev_pre = set()
        for n in range(1, n_steps + 1):
            label = "%s__s%d" % (cid, n)
            r = runs.get(label)
            if r is None:
                fails.append("s%d missing" % n)
                continue
            o = r["o"]
            st = o["state"]
            order = list(o["order"])
            ren = {str(k): str(v) for k, v in (o.get("round_renames") or {}).items()}
            opened = set(st["open"])
            cleared = {k for k in st["stars"] if k in order}
            bp = payload(os.path.join(out, label + ".before.json"))
            bopen, border = before_open(bp)
            bopen_m = {ren.get(x, x) for x in bopen}
            bcleared = {ren.get(k, k) for k in ((bp or {}).get("stars") or {})}
            sf = []
            miss1 = sorted(cleared - opened)
            if miss1:
                sf.append("U1 cleared but locked %s" % ",".join(miss1))
            miss2 = sorted((bopen_m & set(order)) - opened)
            if miss2:
                sf.append("U2 was playable, now locked %s" % ",".join(miss2))
            old_ids = {ren.get(x, x) for x in border}
            skips = []
            for i, rid in enumerate(order):
                if rid in opened and rid in old_ids and rid not in bopen_m and rid not in cleared:
                    prev_ok = i == 0 or order[i - 1] in cleared
                    if not prev_ok:
                        skips.append(rid)
            if skips:
                sf.append("U3 opened without its predecessor cleared %s" % ",".join(skips))
            pre_now = set(r["pre"])
            if c.get("no_write") and (r["sha_before"] != r["sha_after"] or (pre_now - prev_pre)):
                sf.append("U4 wrote (sha %s->%s, new backups %s)" % (r["sha_before"], r["sha_after"], ",".join(sorted(pre_now - prev_pre)) or "-"))
            prev_pre = pre_now
            lu = [x for x in st.get("locked_upgrades", []) if int(re.search(r"\(L(\d+)\)", x).group(1)) > 1]
            if lu:
                sf.append("U5 bought upgrade locked %s" % ",".join(lu))
            print("STEP %-22s unlocked=%-3s open=%s log=%s -> %s" % (label, st["unlocked_round"], ",".join(st["open"]),
                  "|".join(o["boot"]["migration_log"]) or "-", "; ".join(sf) or "ok"))
            fails += ["s%d %s" % (n, x) for x in sf]
            last = o
        if last is not None:
            opened = set(last["state"]["open"])
            mo = [x for x in c.get("must_open", []) if x not in opened]
            ml = [x for x in c.get("must_locked", []) if x in opened]
            if mo:
                fails.append("must_open missing %s" % ",".join(mo))
            if ml:
                fails.append("must_locked but open %s" % ",".join(ml))
        summary["cases"] += 1
        if any(f.endswith("missing") for f in fails) and last is None:
            verdict = "MISSING"
            summary["missing"] += 1
        elif c.get("info_u6"):
            verdict = "INFO(U6) " + ("repaired" if not fails else "not repaired: " + "; ".join(fails))
            summary["info"] += 1
        elif fails:
            verdict = "FAIL " + "; ".join(fails)
            summary["fail"] += 1
        else:
            verdict = "PASS"
            summary["pass"] += 1
        print("CASE %-16s %s | predicted at f606801: %s" % (cid, verdict, c.get("predict_f606801", "-")))
    print("RELOCK_EVAL " + json.dumps(summary))


if __name__ == "__main__":
    main()
