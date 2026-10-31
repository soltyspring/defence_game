#!/usr/bin/env python3
"""Evaluate 10's acceptance AC1-AC9 (DATA_AND_BACKEND_ANALYSIS.md §9.22) from the output of the AC driver
(.local_inspect/run_ac_scenario.ps1: steps S01..S12 of probe_update_scenario.gd under isolated_godot.ps1).
Static post-processing, no Godot. Usage: python docs/research/systems/probes/ac_evaluate.py <driver output file>
Output: one "AC <id> PASS|FAIL|UNVERIFIED <detail>" line per criterion and "AC_EVALUATE <json>".
"""
import json, re, subprocess, sys


def steps(path):
    out = {}
    for line in open(path, encoding="utf-8-sig"):
        m = re.match(r"^STEP (\S+) (\{.*)$", line.strip())
        if m:
            out[m.group(1).split("_")[0]] = json.loads(m.group(2))
    return out


def f(step, name):
    for e in step.get("files", []):
        if e["name"] == name:
            return e
    return None


def main_sha(step):
    e = f(step, "save.json")
    return e["sha12"] if e else None


def pre_files(step):
    return [e for e in step.get("files", []) if e["name"].startswith("save.pre-")]


def main():
    s = steps(sys.argv[1])
    need = ["S01", "S02", "S03", "S04", "S05", "S06", "S07", "S08", "S09", "S10", "S11", "S12"]
    missing = [k for k in need if k not in s]
    if missing:
        sys.exit("missing steps: %s" % missing)
    res = {}

    def put(ac, ok, detail, verdict=None):
        v = verdict or ("PASS" if ok else "FAIL")
        res[ac] = {"verdict": v, "detail": detail}
        print("AC", ac, v, detail)

    cv_crlf, cv_lf = s["S01"]["data_content_version"], s["S02"]["data_content_version"]
    put("AC1", cv_crlf == cv_lf, "engine CRLF %s vs LF %s (normalisation needed for equality)" % (cv_crlf, cv_lf))
    a2 = (main_sha(s["S02"]) == main_sha(s["S01"]) and not s["S02"]["boot"]["migration_log"]
          and s["S02"]["disk_main"]["coins"] == s["S01"]["disk_main"]["coins"]
          and s["S02"]["disk_main"]["upgrades"] == s["S01"]["disk_main"]["upgrades"] and not s["S02"]["disk_main"].get("migration_notice"))
    put("AC2", a2, "first boot of a build whose content_version differs only by line endings (no normalised build exists): "
        "main %s->%s, log %s, notice %s" % (main_sha(s["S01"]), main_sha(s["S02"]), s["S02"]["boot"]["migration_log"],
                                           s["S02"]["disk_main"].get("migration_notice")))
    put("AC3", main_sha(s["S03"]) == main_sha(s["S02"]), "next boot main %s->%s" % (main_sha(s["S02"]), main_sha(s["S03"])))
    a4 = main_sha(s["S02"]) == main_sha(s["S01"]) == main_sha(s["S04"]) and s["S04"]["disk_main"]["revision"] == s["S01"]["disk_main"]["revision"]
    put("AC4", a4, "CRLF->LF->CRLF builds: main %s/%s/%s rev %s/%s" % (main_sha(s["S01"]), main_sha(s["S02"]), main_sha(s["S04"]),
        s["S01"]["disk_main"]["revision"], s["S04"]["disk_main"]["revision"]))
    log5 = s["S05"]["boot"]["migration_log"]
    a5 = main_sha(s["S05"]) == main_sha(s["S04"]) and not any("refund" in x for x in log5) and not s["S05"]["disk_main"].get("migration_notice")
    put("AC5", a5, "non-cap value change: main %s->%s, log %s" % (main_sha(s["S04"]), main_sha(s["S05"]), log5))
    paid = s["S01"]["disk_main"].get("upgrade_paid", {}).get("up_melee_basic", {})
    exp_refund = int(paid.get("4", 0)) + int(paid.get("5", 0))
    c5, c6, c7 = s["S05"]["disk_main"]["coins"], s["S06"]["disk_main"]["coins"], s["S07"]["disk_main"]["coins"]
    pre6 = pre_files(s["S06"])
    notice6 = s["S06"]["disk_main"].get("migration_notice") or {}
    notice8 = s["S08"]["disk_main"].get("migration_notice")
    a6_refund = c6 - c5 == exp_refund and c7 == c6 and s["S06"]["disk_main"]["upgrades"].get("up_melee_basic") == 3
    a6_pre = len(pre6) == 1 and pre6[0]["sha12"] == main_sha(s["S05"])
    a6_notice = int(notice6.get("coins", -1)) == exp_refund and not notice8 and main_sha(s["S07"]) == main_sha(s["S06"])
    put("AC6", a6_refund and a6_pre and a6_notice,
        "refund %s (paid %s), next boot coins %s, pre %s == S05 main %s, notice %s, after ack %s"
        % (c6 - c5, exp_refund, c7, [p["name"] + ":" + p["sha12"] for p in pre6], main_sha(s["S05"]), notice6, notice8))
    pre_ids = [[p["name"] + ":" + p["sha12"] for p in pre_files(s[k])] for k in ["S06", "S07", "S08", "S09", "S10", "S11", "S12"]]
    a7 = (all(x == pre_ids[0] for x in pre_ids) and main_sha(s["S09"]) == main_sha(s["S08"])
          and not s["S09"]["boot"]["migration_log"] and not s["S09"]["disk_main"].get("migration_notice"))
    put("AC7", a7, "pre-backup across S06..S12 %s; reformat-only boot main %s->%s log %s"
        % ("unchanged" if all(x == pre_ids[0] for x in pre_ids) else pre_ids, main_sha(s["S08"]), main_sha(s["S09"]), s["S09"]["boot"]["migration_log"]))
    a8 = (main_sha(s["S12"]) == main_sha(s["S11"]) and s["S12"]["disk_main"]["upgrades"].get("up_melee_basic") == 3)
    put("AC8", a8, "rollback build: main %s->%s, melee L%s (no restore by design)" % (main_sha(s["S11"]), main_sha(s["S12"]),
        s["S12"]["disk_main"]["upgrades"].get("up_melee_basic")))
    put("AC9", False, "APK/AAB with the engine change not built or installed by 10; device boot not run", "UNVERIFIED")
    sig = [len(s[k].get("content_migrated_signals", [])) for k in need]
    print("AC_INFO content_migrated signals per step", sig, "(headless -s runs mount no menu)")
    print("AC_EVALUATE", json.dumps({k: v["verdict"] for k, v in res.items()}))


if __name__ == "__main__":
    main()
