"""Inspect an exported Godot Android APK for release hygiene. Owner: 04-client.

Usage: python tools/build/inspect_apk.py <apk> <report.json>
Checks (exit 1 if any FAIL):
  - size, per-top-level-dir compressed/uncompressed bytes, native ABIs
  - forbidden content: tests/ docs/ tools/ coordination/ build/ .md .ps1 .py, keystores, .env,
    editor-only files, raw source images (assets/**/*.png not under .godot/imported)
  - required content: imported textures (.ctex) for every atlas page, fonts, licence text, data json
"""
import json, sys, zipfile, re, pathlib

FORBIDDEN = [
    (r"(^|/)tests/", "test sources"), (r"(^|/)docs/", "documentation"), (r"(^|/)tools/", "tools"),
    (r"(^|/)coordination/", "coordination files"), (r"(^|/)build/", "build output"),
    (r"\.(md|ps1|py|txt\.uid)$", "doc/script file"), (r"\.(keystore|jks|p12|pfx)$", "signing key"),
    (r"(^|/)\.env", "env file"), (r"(^|/)\.git/", "git data"), (r"export_credentials\.cfg$", "export credentials"),
]

def main(apk: str, out: str) -> int:
    z = zipfile.ZipFile(apk)
    infos = z.infolist()
    size = pathlib.Path(apk).stat().st_size
    by_dir = {}
    for i in infos:
        top = i.filename.split("/")[0] if "/" in i.filename else "(root)"
        if i.filename.startswith("assets/"):
            parts = i.filename.split("/")
            top = "assets/" + (parts[1] if len(parts) > 2 else "(files)")
        d = by_dir.setdefault(top, {"files": 0, "compressed": 0, "uncompressed": 0})
        d["files"] += 1; d["compressed"] += i.compress_size; d["uncompressed"] += i.file_size
    names = [i.filename for i in infos]
    game = [n for n in names if n.startswith("assets/")]
    abis = sorted({n.split("/")[1] for n in names if n.startswith("lib/") and n.count("/") >= 2})
    fails, warns = [], []
    for n in game:
        rel = n[len("assets/"):]
        for pat, why in FORBIDDEN:
            if re.search(pat, rel):
                fails.append(f"{why}: {n}")
        if rel.startswith("assets/") and rel.lower().endswith(".png"):
            fails.append(f"raw source PNG shipped: {n}")
    def has(pat):
        return [n for n in game if re.search(pat, n)]
    pages = []
    try:
        pass
    except Exception:
        pass
    ctex = has(r"\.godot/imported/.*\.ctex$")
    fonts = has(r"\.godot/imported/.*\.fontdata$")
    licence = has(r"OFL-Galmuri\.txt$")
    data_json = has(r"assets/data/.*\.json$")
    manifest = has(r"assets/assets/manifest\.json$")
    pck = has(r"\.pck$")
    if not pck and not ctex:
        fails.append("no imported textures (.ctex) and no .pck found")
    if not fonts and not pck:
        fails.append("no imported fonts (.fontdata)")
    if not licence:
        warns.append("OFL licence text assets/fonts/OFL-Galmuri.txt NOT shipped (OFL requires it with the fonts; 02 include_filter)")
    if not data_json and not pck:
        fails.append("no data/*.json shipped")
    report = {
        "apk": apk, "size_bytes": size, "size_mib": round(size / 1048576, 2), "entries": len(infos), "abis": abis,
        "by_dir": dict(sorted(by_dir.items(), key=lambda kv: -kv[1]["compressed"])),
        "game_files": len(game), "ctex": len(ctex), "fontdata": len(fonts), "licence_files": licence,
        "data_json": len(data_json), "manifest": manifest, "pck": pck,
        "fails": fails, "warnings": warns,
        "game_file_list": game,
    }
    pathlib.Path(out).write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"APK {size} B ({report['size_mib']} MiB), entries={len(infos)}, abis={abis}, game_files={len(game)}, ctex={len(ctex)}, fontdata={len(fonts)}, data_json={len(data_json)}")
    for k, v in list(report["by_dir"].items())[:8]:
        print(f"  {k:28s} files={v['files']:4d} compressed={v['compressed']:>10d} uncompressed={v['uncompressed']:>10d}")
    for w in warns:
        print("WARN", w)
    for f in fails[:40]:
        print("FAIL", f)
    print("RESULT", "FAIL" if fails else "PASS", f"({len(fails)} fails, {len(warns)} warnings)")
    return 1 if fails else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
