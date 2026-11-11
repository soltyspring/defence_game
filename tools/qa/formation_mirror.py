"""Python mirror of the column rule in battle_view.gd _update_formation (2026-11-10), old vs new.

    python tools/qa/formation_mirror.py

Model only (no Godot): mixed-speed allies stream from the keep and stack at a front line that advances
30 px every 6 s. Counts how often an
already seated unit is moved to another column, and how many same-row pairs end up drawn on top of each other.
"""
STEP, OVERLAP, COLS, REACH = 9.0, 7.0, 7, 9.0 * 7 + 7.0


class U:
    def __init__(s, uid, speed, stop):
        s.uid, s.speed, s.stop, s.x = uid, speed, stop, 62.0
        s.row, s.col, s.conf, s.moves = 0, 0, 0.0, 0


def run(new, seconds=45.0, seed_speeds=(40.0, 80.0, 28.0, 40.0, 36.0)):
    units, t, uid, timer, spawn = [], 0.0, 0, 0.0, 0.0
    dt = 1.0 / 60.0
    rows = [0, 0, 0]
    while t < seconds:
        born = set()
        spawn -= dt
        if spawn <= 0 and len(units) < 24:
            spawn = 0.7
            uid += 1
            sp = seed_speeds[uid % len(seed_speeds)]
            u = U(uid, sp, 700.0 if sp != 36.0 else 610.0)      # 36 = ranged, stops earlier
            u.row = min(range(3), key=lambda r: (rows[r], r)); rows[u.row] += 1
            units.append(u); born.add(u.uid)
        if int((t + dt) / 6.0) != int(t / 6.0):                 # the front advances 30 px every 6 s (an enemy fell)
            for u in units:
                u.stop += 30.0
        for u in units:
            u.x = min(u.stop, u.x + u.speed * dt)
        timer -= dt
        if timer <= 0 or born:
            interval = max(dt, 0.15); timer = 0.15
            for u in units:
                if new:
                    walking = u.x < u.stop - 1e-6
                    is_born = u.uid in born
                    occ = [o.x - o.col * STEP for o in units if o.uid < u.uid and abs(o.x - u.x) < REACH and o.row == u.row
                           and (is_born or o.x >= o.stop - 1e-6)]
                    here = u.x - u.col * STEP
                    blocked = (is_born or not walking) and any(abs(ox - here) < OVERLAP for ox in occ)
                    u.conf = u.conf + interval if blocked else 0.0
                    if blocked and (is_born or u.conf >= 0.3):
                        col = -1
                        for step in range(COLS):
                            for d in (1, -1):
                                c = u.col + step * d
                                if c < 0 or c >= COLS or (step == 0 and d < 0):
                                    continue
                                if not any(abs(ox - (u.x - c * STEP)) < OVERLAP for ox in occ):
                                    col = c; break
                            if col >= 0:
                                break
                        if col >= 0:
                            if not is_born: u.moves += 1
                            u.col = col; u.conf = 0.0
                else:
                    used = {o.col for o in units if o.uid < u.uid and abs(o.x - u.x) < 32 and o.row == u.row}
                    hit = u.col in used
                    u.conf = u.conf + interval if hit else 0.0
                    if hit and (u.uid in born or u.conf >= 0.3):
                        for c in range(COLS):
                            if c not in used:
                                if u.uid not in born: u.moves += 1
                                u.col = c; u.conf = 0.0
                                break
        t += dt
    overl = 0
    for i, a in enumerate(units):
        for b in units[i + 1:]:
            if a.row == b.row and abs((a.x - a.col * STEP) - (b.x - b.col * STEP)) < OVERLAP:
                overl += 1
    return sum(u.moves for u in units), sum(1 for u in units if u.moves), overl, len(units)


if __name__ == "__main__":
    for name, new in (("before (column numbers within 32 px)", False), ("after (stopped units, drawn overlap)", True)):
        moves, movers, overl, n = run(new)
        print(f"{name}: {n} units, re-seats of seated units = {moves} (units affected {movers}), overlapping pairs at the end = {overl}")
