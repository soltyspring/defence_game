"""Theme Q1 = A "빵집 기사단 vs 곰팡이 군단" (decided by the user 2026-10-31). Owner: 03-art.

The theme is applied as a deterministic palette remap of the already-posed frames, so
silhouettes, frame sizes, pivots, hit/spawn frames and frame names stay byte-for-byte the
same geometry (only colours change). The remap is simultaneous (one pass on the original
indices).

Faction colour rule (ART_AUDIT A17/A25):
  allies  = warm + LIGHT: crust tan/cream, egg-wash gold, jam-red accents, toast faces.
  enemies = cool + DARK: mould grey-green, blue-mould teal, spore-white accents.
Separation is carried on the blue-yellow axis (preserved in protan/deutan vision) AND by
a luminance step (allies lighter), measured by tools/art/cvd_check.py.
"""
from __future__ import annotations

from pixel import IDX

ALLY = {
    # steel armour -> baked crust (baguette blades, bread helmets)
    "m": "O", "M": "o", "N": "T", "W": "U",
    # blue cloth -> egg-wash gold tabards
    "b": "y", "B": "Y", "C": "Z", "c": "U",
    # gold trim -> jam red (hot-cross on the bun shield, belts)
    "y": "R", "Y": "E", "Z": "e",
    # skin -> toast (cream crumb, crust edge) = bread people
    "s": "T", "S": "U", "L": "W",
    # hair -> crust
    "h": "O", "H": "o",
    # pony / catapult stone greys -> flour + crust (greys belong to the mould side)
    "x": "U", "X": "T", "A": "o", "a": "O",
}
ENEMY = {
    # green skin -> mould grey-green
    "g": "D", "G": "l", "F": "t", "f": "z",
    # purple cloth -> blue mould (A17: no purple masses near ally colours)
    "p": "D", "P": "q", "V": "t", "v": "z",
    # red rags -> grey
    "r": "a", "R": "A", "E": "X", "e": "x",
    # wood gear -> rotten grey wood
    "w": "a", "O": "A", "o": "X", "T": "x",
    # bone -> spore white; gold -> spore crown
    "U": "z", "Y": "t", "Z": "z", "y": "l",
}
OVERRIDE = {
    # little baker: white chef hat instead of the jam-red that gold would become
    "worker": {"Y": "W", "Z": "W", "y": "x"},
    # 제빵 대장 (art 0.11.0): chef hat + jacket drawn in J -> pure white
    "hero_captain": {"J": "W", "L": "U", "S": "T", "s": "o"},   # face toast-cream, darker than the white hat
    # bomber keeps its orange fuse/bandana = the one hazard accent
    "e_bomber": {"E": "E", "e": "e", "Z": "Z"},
    # overlord keeps the lilac eyes/orb glow (small area, boss-only cue)
    "boss_overlord": {"V": "V", "v": "v"},
}


def mapping(faction: str, sid: str) -> dict:
    base = dict(ALLY if faction == "player" else ENEMY)
    base.update(OVERRIDE.get(sid, {}))
    return {IDX[k]: IDX[v] for k, v in base.items() if k != v}


def apply(cv, faction: str, sid: str):
    import chars_retheme
    if sid in chars_retheme.NATIVE:      # drawn directly in the final theme palette
        return cv
    m = mapping(faction, sid)
    if m:
        cv.recolor(m)
    return cv


def remap_keys(cv, table: dict):
    cv.recolor({IDX[k]: IDX[v] for k, v in table.items()})
    return cv


# --- non-character remaps (bases, props, fx, biome, ui) ---------------------------------
BAKERY_KEEP = {   # stone keep -> bakery: dough-brick walls, crust trims, jam-red roof + banners
    "X": "T", "x": "U", "J": "W", "A": "o", "a": "O",
    "B": "R", "b": "r", "C": "E", "c": "e",
    "y": "R", "Y": "Z",
}
MOULD_FORT = ENEMY    # palisade/purple/bramble -> rotten grey wood, blue mould, spores
FLOUR_STORE = {"X": "T", "x": "U", "A": "o", "a": "O", "M": "o", "N": "T", "m": "O"}   # mine -> flour store
SPORE_FX = {"G": "l", "F": "t", "f": "t", "Z": "z"}    # enemy spit -> spore glob (0.11.0: sage body, white only in the core, reads on light walls)
DOUGH_ROCK = {"X": "o", "x": "T", "J": "U", "A": "O", "a": "w"}   # siege rock -> hard-baked loaf
WHEAT_FRONT = {"G": "y", "F": "Y", "g": "O"}            # front grass tufts -> wheat stalks
ENEMY_PORTRAIT = dict(bg="D", rim="l", hi="t")
