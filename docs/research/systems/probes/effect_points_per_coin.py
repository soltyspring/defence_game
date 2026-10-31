#!/usr/bin/env python3
"""Aggregate probe_upgrade_effect.gd output into the "breakpoints per 100 coins" table (10-research-systems, §9.7/§9.11).
A breakpoint ("체감 지점") = one (track, enemy, round) row where the hits-to-kill count changes at that level,
counted separately for offense (ally hits to kill the enemy) and defense (enemy hits to kill the ally).
Per 100 coins = points(L) / cost to reach L * 100. Every enemy row has the same weight (ASSUME metric).
Usage: python effect_points_per_coin.py <probe_upgrade_effect output file> [--rev <git rev for meta.json costs>] [--meta <meta.json file>]
Static post-processing only; the hit counts themselves come from the Godot probe run.
"""
import json, subprocess, sys


def main():
    path = sys.argv[1]
    rev = sys.argv[sys.argv.index("--rev") + 1] if "--rev" in sys.argv else "HEAD"
    rows = None
    for line in open(path, encoding="utf-8-sig"):
        if line.startswith("UE breakpoints "):
            rows = json.loads(line[len("UE breakpoints "):])
    if rows is None:
        sys.exit("no 'UE breakpoints' line in " + path)
    if "--meta" in sys.argv:   # a what-if meta.json file (e.g. a patched snapshot copy) instead of git
        meta = json.load(open(sys.argv[sys.argv.index("--meta") + 1], encoding="utf-8-sig"))
        rev = "file:" + sys.argv[sys.argv.index("--meta") + 1]
    else:
        meta = json.loads(subprocess.run(["git", "show", f"{rev}:data/meta.json"], capture_output=True, check=True).stdout)
    costs = {u["id"]: u["costs"] for u in meta["upgrades"]}
    out = {}
    for tr in sorted({r["track"] for r in rows}):
        rs = [r for r in rows if r["track"] == tr]
        per = {}
        for lv in range(2, len(costs[tr]) + 2):
            off = sum(1 for r in rs if lv in r["offense_breakpoint_levels"])
            dfn = sum(1 for r in rs if lv in r["defense_breakpoint_levels"])
            small_off = sum(1 for r in rs if lv in r["offense_breakpoint_levels"] and not r["enemy"].startswith("boss"))
            small_n = sum(1 for r in rs if not r["enemy"].startswith("boss"))
            c = costs[tr][lv - 2]
            per[f"L{lv}"] = {"points": off + dfn, "offense": off, "defense": dfn, "cost": c,
                             "per_100": round((off + dfn) / c * 100, 1), "small_enemy_offense": f"{small_off}/{small_n}"}
        out[tr] = {"rows": len(rs), "levels": per}
        print("EP", tr, json.dumps(out[tr], ensure_ascii=False))
    print("EFFECT_POINTS_PER_COIN", json.dumps({"rev": rev, "tracks": len(out), "rows": len(rows)}))


if __name__ == "__main__":
    main()
