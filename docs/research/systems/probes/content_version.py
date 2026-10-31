#!/usr/bin/env python3
"""Static re-implementation (10-research-systems) of Content._compute_content_version (src/core/content.gd, 7f2886c):
"c1-" + first 12 hex of sha256 over every data/**/*.json, sorted by path, each entry = "<path under data>\n<bytes>\n".
The engine hashes the bytes ON DISK, so the value depends on the checkout's line endings. This PC has
core.autocrlf=true, so working trees and `git archive` snapshots hold CRLF files; a Linux/CI checkout holds LF.
Both values are printed. Verified: data 7b93d1f -> CRLF c1-ea9c929ba40e = the value Godot reported (§9.16, §9.17).
Usage: python docs/research/systems/probes/content_version.py <rev> [<rev> ...]
       python docs/research/systems/probes/content_version.py --save <save.json>   (prints the save's content_version; read-only)
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


def main():
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
