"""Test copy only: flag every biome 'sky' layer `opaque: true` in a manifest.json (02 P11 A/B). 02 local tool."""
import json
import sys

p = sys.argv[1]
with open(p, encoding="utf-8") as f:
    m = json.load(f)
n = 0
for b in m.get("biomes", {}).values():
    for layer in b.get("layers", []):
        if layer.get("frame") == "sky":
            layer["opaque"] = True
            n += 1
with open(p, "w", encoding="utf-8", newline="\n") as f:
    json.dump(m, f, ensure_ascii=False, indent=2)
print("opaque flags set:", n)
