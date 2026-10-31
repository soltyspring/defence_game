#!/usr/bin/env python3
"""Static re-implementation (10-research-systems) of Content._compute_content_version (src/core/content.gd, 7f2886c):
"c1-" + first 12 hex of sha256 over every data/**/*.json, sorted by path, each entry = "<path under data>\n<bytes>\n".
The engine hashes the bytes ON DISK, so the value depends on the checkout's line endings. This PC has
core.autocrlf=true, so working trees and `git archive` snapshots hold CRLF files; a Linux/CI checkout holds LF.
Both values are printed. Verified: data 7b93d1f -> CRLF c1-ea9c929ba40e = the value Godot reported (§9.16, §9.17).
Usage: python docs/research/systems/probes/content_version.py <rev> [<rev> ...]
       python docs/research/systems/probes/content_version.py --save <save.json>   (prints the save's content_version; read-only)
       python docs/research/systems/probes/content_version.py --apk <file.apk>     (data inside an APK: CR/LF counts and value)
       python docs/research/systems/probes/content_version.py --dir <project dir>  (data of a folder on disk, same output)
No Godot, writes nothing.
"""
import hashlib, json, re, subprocess, sys


def cv(rev, crlf):
    names = subprocess.run(["git", "ls-tree", "-r", "--name-only", rev, "--", "data"], capture_output=True, check=True,
                           text=True).stdout.split()
    files = sorted(n for n in names if n.endswith(".json") and not any(p.startswith(".") for p in n.split("/")))
    h = hashlib.sha256()
    for f in files:
        b = subprocess.run(["git", "show", f"{rev}:{f}"], capture_output=True, check=True).stdout
        if crlf:
            b = re.sub(rb"(?<!\r)\n", b"\r\n", b)
        h.update(f[len("data"):].encode("utf-8"))   # "/meta.json", "/rounds/r01.json", ...
        h.update(b"\n")
        h.update(b)
        h.update(b"\n")
    return "c1-" + h.hexdigest()[:12], len(files)


def cv_bytes(entries):
    """entries: {"/meta.json": bytes, ...} -> content_version, same order and framing as content.gd."""
    h = hashlib.sha256()
    for path in sorted(entries):
        h.update(path.encode("utf-8"))
        h.update(b"\n")
        h.update(entries[path])
        h.update(b"\n")
    return "c1-" + h.hexdigest()[:12]


def apk_data(apk):
    """Read the packed data/**/*.json from an APK (assets/data/...) or an AAB (<module>/assets/data/...), read only.
    Godot's AAB export puts the project files in the install-time asset pack (assetPackInstallTime/assets/...),
    not in base/ (10 v0.33, measured on the 06 try_debug_aab.ps1 output). Exactly one module may hold data/."""
    import re
    import zipfile
    out = {}
    with zipfile.ZipFile(apk) as z:
        names = z.namelist()
        mods = sorted({m.group(1) for m in (re.match(r"^((?:[^/]+/)?assets/data/)", n) for n in names) if m})
        if len(mods) != 1:
            raise SystemExit("expected exactly one assets/data/ location in %s, found %s" % (apk, mods))
        prefix = mods[0]
        for n in names:
            if n.startswith(prefix) and n.endswith(".json"):
                out[n[len(prefix) - 1:]] = z.read(n)
    if not out:
        raise SystemExit("no data/**/*.json found in %s" % apk)
    return out


def dir_data(root):
    """Read <root>/data/**/*.json from a folder on disk (bytes as stored)."""
    import os
    out = {}
    base = os.path.join(root, "data")
    for dp, dn, fn in os.walk(base):
        dn[:] = [d for d in dn if not d.startswith(".")]
        for f in fn:
            if f.endswith(".json"):
                p = os.path.join(dp, f)
                out["/" + os.path.relpath(p, base).replace(os.sep, "/")] = open(p, "rb").read()
    return out


def main():
    if len(sys.argv) > 2 and sys.argv[1] in ("--apk", "--dir"):
        e = apk_data(sys.argv[2]) if sys.argv[1] == "--apk" else dir_data(sys.argv[2])
        cr = sum(b.count(b"\r") for b in e.values())
        lf = sum(b.count(b"\n") for b in e.values())
        crlf_files = sum(1 for b in e.values() if b.count(b"\r\n") == b.count(b"\n") and b.count(b"\n") > 0)
        stripped = {k: v.replace(b"\r\n", b"\n") for k, v in e.items()}
        print("FILES_CONTENT_VERSION", json.dumps({"source": sys.argv[1][2:] + ":" + sys.argv[2], "files": len(e), "cr": cr, "lf": lf, "crlf_files": crlf_files,
              "as_packed": cv_bytes(e), "if_lf": cv_bytes(stripped)}))
        return
    if len(sys.argv) > 2 and sys.argv[1] == "--save":
        env = json.load(open(sys.argv[2], encoding="utf-8-sig"))
        p = json.loads(env["payload"])
        print("SAVE_CONTENT_VERSION", json.dumps({"content_version": p.get("content_version", ""), "revision": p.get("revision")}))
        return
    for rev in sys.argv[1:]:
        lf, n = cv(rev, False)
        crlf, _ = cv(rev, True)
        print("CONTENT_VERSION", json.dumps({"rev": rev, "lf": lf, "crlf": crlf, "files": n}))


if __name__ == "__main__":
    main()
