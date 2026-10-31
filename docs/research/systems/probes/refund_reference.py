#!/usr/bin/env python3
"""Reference model (10-research-systems) for the R5 / D26 refund contract. Static, no Godot, writes nothing.

It computes the expected save state after a content migration for two refund sources:
  A  = the save records what was paid per level at purchase:  progress.upgrade_paid[id][str(level)] = coins
  B  = data/migrations.json carries retired_costs[id] = the meta.json `costs` list just before the change
  AB = A first, B as the fallback for levels without a record (recommended)
Cost data for the cases comes from the real git history of data/meta.json (e42f809 = before D26, HEAD = after).

Run:  python docs/research/systems/probes/refund_reference.py [--rev HEAD]
Output: one "RR <case> <json>" line per case and "REFUND_REFERENCE {pass, fail}". Exit 1 if a case fails.
This is a model of the proposed contract, not the engine. Engine acceptance must be run with Godot (probe part D).
"""
import copy, json, subprocess, sys

COINS_CAP = 9_999_999


def meta_at(rev):
    txt = subprocess.run(["git", "show", f"{rev}:data/meta.json"], capture_output=True, check=True).stdout
    return {u["id"]: u for u in json.loads(txt.decode("utf-8"))["upgrades"]}


def migrate(save, migrations, mode):
    """Apply every migration whose id is not in save.migrations_applied, in file order. Returns (save, log)."""
    s = copy.deepcopy(save)
    s.setdefault("upgrade_paid", {})
    s.setdefault("migrations_applied", [])
    log = []
    refund = 0

    def level_price(uid, level, retired_costs):
        rec = s["upgrade_paid"].get(uid, {}).get(str(level))
        if mode in ("A", "AB") and isinstance(rec, int) and rec >= 0:
            return rec, "paid_record"
        if mode in ("B", "AB") and retired_costs is not None and 0 <= level - 2 < len(retired_costs):
            return int(retired_costs[level - 2]), "retired_costs"
        return 0, "unknown"

    for m in migrations["migrations"]:
        if m["id"] in s["migrations_applied"]:
            continue
        for old, new in m.get("upgrade_renames", {}).items():
            if old in s["upgrades"]:
                if new in s["upgrades"]:
                    log.append(f"rename_conflict:{old}->{new}:kept_new")
                else:
                    s["upgrades"][new] = s["upgrades"].pop(old)
                    if old in s["upgrade_paid"]:
                        s["upgrade_paid"][new] = s["upgrade_paid"].pop(old)
        for uid, cap in m.get("upgrade_caps", {}).items():
            cur = int(s["upgrades"].get(uid, 1))
            new_max = int(cap["max_level"])
            for lv in range(new_max + 1, cur + 1):
                amt, src = level_price(uid, lv, cap.get("retired_costs"))
                refund += amt
                log.append(f"cap:{uid}:L{lv}:{amt}:{src}")
                s["upgrade_paid"].get(uid, {}).pop(str(lv), None)
            if cur > new_max:
                s["upgrades"][uid] = new_max
        for uid, ret in m.get("retired_upgrades", {}).items():
            cur = int(s["upgrades"].get(uid, 1))
            for lv in range(2, cur + 1):
                amt, src = level_price(uid, lv, ret.get("retired_costs"))
                refund += amt
                log.append(f"retire:{uid}:L{lv}:{amt}:{src}")
            s["upgrades"].pop(uid, None)
            s["upgrade_paid"].pop(uid, None)
        s["migrations_applied"].append(m["id"])
    total = s["coins"] + refund
    if total > COINS_CAP:
        log.append(f"coins_clamped:{total}")
    s["coins"] = min(total, COINS_CAP)
    return s, log


def paid_from(costs, top_level):
    return {str(lv): int(costs[lv - 2]) for lv in range(2, top_level + 1)}


def main():
    rev = sys.argv[sys.argv.index("--rev") + 1] if "--rev" in sys.argv else "HEAD"
    old, now = meta_at("e42f809"), meta_at(rev)
    siege_old, siege_now = old["up_siege"]["costs"], now["up_siege"]["costs"]
    worker_now = now["up_worker"]["costs"]
    cap_siege4 = {"schema_version": 1, "migrations": [{"id": "m001_siege_cap4", "upgrade_caps": {
        "up_siege": {"max_level": 4, "retired_costs": siege_now}}}]}
    cap_siege4_nocosts = {"schema_version": 1, "migrations": [{"id": "m001_siege_cap4", "upgrade_caps": {
        "up_siege": {"max_level": 4}}}]}
    retire_worker = {"schema_version": 1, "migrations": [{"id": "m002_retire_worker", "retired_upgrades": {
        "up_worker": {"retired_costs": worker_now}}}]}
    rename = {"schema_version": 1, "migrations": [{"id": "m003_rename", "upgrade_renames": {
        "up_melee_basic": "up_bread_knight"}}]}
    chain = {"schema_version": 1, "migrations": cap_siege4["migrations"] + retire_worker["migrations"]}

    def base(**kw):
        s = {"coins": 1234, "upgrades": {}, "upgrade_paid": {}, "migrations_applied": []}
        s.update(kw)
        return s

    l5_now = base(upgrades={"up_siege": 5}, upgrade_paid={"up_siege": paid_from(siege_now, 5)})
    l5_old_price = base(upgrades={"up_siege": 5}, upgrade_paid={"up_siege": paid_from(siege_old, 5)})
    l5_no_record = base(upgrades={"up_siege": 5}, upgrade_paid={})
    cases = [
        # id, save, migrations, mode, expect coins, expect upgrades
        ("R1_cap_paid_record", l5_now, cap_siege4, "AB", 1234 + siege_now[3], {"up_siege": 4}),
        ("R2_cap_after_cost_change_A", l5_old_price, cap_siege4, "A", 1234 + siege_old[3], {"up_siege": 4}),
        ("R2b_cap_after_cost_change_B", l5_old_price, cap_siege4, "B", 1234 + siege_now[3], {"up_siege": 4}),
        ("R3_cap_no_record_fallback", l5_no_record, cap_siege4, "AB", 1234 + siege_now[3], {"up_siege": 4}),
        ("R4_cap_no_record_no_costs", l5_no_record, cap_siege4_nocosts, "AB", 1234, {"up_siege": 4}),
        ("R5_cap_below_new_max", base(upgrades={"up_siege": 3}, upgrade_paid={"up_siege": paid_from(siege_now, 3)}),
         cap_siege4, "AB", 1234, {"up_siege": 3}),
        ("R6_retire_no_record", base(upgrades={"up_worker": 4}), retire_worker, "AB", 1234 + sum(worker_now), {}),
        ("R7_rename_moves_level_and_paid", base(upgrades={"up_melee_basic": 3},
         upgrade_paid={"up_melee_basic": paid_from(now["up_melee_basic"]["costs"], 3)}), rename, "AB", 1234,
         {"up_bread_knight": 3}),
        ("R8_chain_two_migrations", base(upgrades={"up_siege": 5, "up_worker": 4},
         upgrade_paid={"up_siege": paid_from(siege_now, 5)}), chain, "AB", 1234 + siege_now[3] + sum(worker_now),
         {"up_siege": 4}),
        ("R9_coins_cap", base(coins=COINS_CAP - 10, upgrades={"up_siege": 5},
         upgrade_paid={"up_siege": paid_from(siege_now, 5)}), cap_siege4, "AB", COINS_CAP, {"up_siege": 4}),
    ]
    ok = bad = 0
    for cid, save, mig, mode, exp_coins, exp_ups in cases:
        got, log = migrate(save, mig, mode)
        again, log2 = migrate(got, mig, mode)          # second launch: must change nothing
        passed = got["coins"] == exp_coins and got["upgrades"] == exp_ups and again == got and not log2
        ok += passed
        bad += not passed
        print("RR", cid, json.dumps({"mode": mode, "pass": passed, "coins": got["coins"], "expect_coins": exp_coins,
              "upgrades": got["upgrades"], "upgrade_paid": got["upgrade_paid"], "applied": got["migrations_applied"],
              "second_run_changed": again != got, "log": log}, ensure_ascii=False))
    print("RR SOURCE", json.dumps({"rev": rev, "siege_costs_e42f809": siege_old, "siege_costs_rev": siege_now,
          "worker_costs_rev": worker_now}))
    print("REFUND_REFERENCE", json.dumps({"pass": ok, "fail": bad}))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
