"""Make one data variant inside a THROWAWAY project copy (10-research-systems, v0.34, round re-lock study).

Usage: python relock_variants.py <project_copy_dir> <variant>
Edits only <project_copy_dir>/data/** (and, for `patch_save`, that copy's src/core/save.gd). Files are written with LF.
Variants (each is one "update" compared with the unchanged copy):
  cap4          up_melee_basic max_level 5 -> 4 (no round change)
  bytes_only    data/text/en.json gets one extra trailing newline (content_version changes, nothing else)
  remove_r03    r03 removed from the order (and its file), rounds re-indexed (M1 shape)
  insert1       new round r02x (copy of r02) after r02
  insert1b      apply on an insert1 copy: another new round r02y after r02x (second update)
  insert2       r02x and r02y after r02 in ONE update
  move_r03_end  r03 moved to the end of the order
  rename2       r03 -> r03n and r04 -> r04n (files and ids), no migrations.json entry
  rename2_map   the same plus data/migrations.json round_renames {r03: r03n, r04: r04n}
  patch_save    NOT a data change: candidate rule (i) in the copy's save.gd step 5 (unlocked_round is never below
                last cleared index + 2); prints PATCH 1 when applied. Research only, not a fix.
"""
import json
import os
import sys


def rj(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def wj(p, o):
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(o, ensure_ascii=False, indent=2) + "\n")


def order_path(d):
    return os.path.join(d, "data", "rounds", "order.json")


def reindex(d):
    o = rj(order_path(d))
    for i, rid in enumerate(o["rounds"]):
        p = os.path.join(d, "data", "rounds", rid + ".json")
        r = rj(p)
        r["index"] = i + 1
        wj(p, r)


def new_round(d, src, rid, after):
    r = rj(os.path.join(d, "data", "rounds", src + ".json"))
    r["id"] = rid
    r.pop("name_key", None)
    r["name"] = rid
    wj(os.path.join(d, "data", "rounds", rid + ".json"), r)
    o = rj(order_path(d))
    o["rounds"].insert(o["rounds"].index(after) + 1, rid)
    wj(order_path(d), o)


def rename(d, old, new):
    p = os.path.join(d, "data", "rounds", old + ".json")
    r = rj(p)
    r["id"] = new
    os.remove(p)
    wj(os.path.join(d, "data", "rounds", new + ".json"), r)
    o = rj(order_path(d))
    o["rounds"] = [new if x == old else x for x in o["rounds"]]
    wj(order_path(d), o)


def main(d, v):
    if v == "cap4":
        p = os.path.join(d, "data", "meta.json")
        m = rj(p)
        u = [x for x in m["upgrades"] if x["id"] == "up_melee_basic"][0]
        u["max_level"] = 4
        u["costs"] = u["costs"][:3]
        wj(p, m)
    elif v == "bytes_only":
        with open(os.path.join(d, "data", "text", "en.json"), "ab") as f:
            f.write(b"\n")
    elif v == "remove_r03":
        o = rj(order_path(d))
        o["rounds"].remove("r03")
        wj(order_path(d), o)
        os.remove(os.path.join(d, "data", "rounds", "r03.json"))
        reindex(d)
    elif v == "insert1":
        new_round(d, "r02", "r02x", "r02")
        reindex(d)
    elif v == "insert1b":
        new_round(d, "r02", "r02y", "r02x")
        reindex(d)
    elif v == "insert2":
        new_round(d, "r02", "r02x", "r02")
        new_round(d, "r02", "r02y", "r02x")
        reindex(d)
    elif v == "move_r03_end":
        o = rj(order_path(d))
        o["rounds"].remove("r03")
        o["rounds"].append("r03")
        wj(order_path(d), o)
        reindex(d)
    elif v in ("rename2", "rename2_map"):
        rename(d, "r03", "r03n")
        rename(d, "r04", "r04n")
        if v == "rename2_map":
            wj(os.path.join(d, "data", "migrations.json"), {"schema_version": 1, "round_renames": {"r03": "r03n", "r04": "r04n"}})
    elif v == "patch_save":
        p = os.path.join(d, "src", "core", "save.gd")
        with open(p, encoding="utf-8", newline="") as f:
            t = f.read()
        old = "\t\tif maxi(1, open) != int(progress.unlocked_round):\n"
        new = ("\t\tfor i in order.size():   # 10 v0.34 candidate (i), research copy only\n"
               "\t\t\tif progress.stars.has(str(order[i])): open = maxi(open, mini(i + 2, order.size() + 1))\n") + old
        if t.count(old) != 1:
            raise SystemExit("patch anchor not found exactly once")
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(t.replace(old, new))
        print("PATCH 1")
    else:
        raise SystemExit("unknown variant " + v)
    o = rj(order_path(d))
    print("VARIANT %s order=%s" % (v, ",".join(o["rounds"])))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
