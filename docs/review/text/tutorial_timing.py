"""r01 tutorial timing, pure-Python model of src/gameplay/tutorial_director.gd driven the way
src/gameplay/battle.gd drives it (no Godot). 12-text-review, TEXT_REVIEW_02.

Frame order copied from the code:
  input (TouchButton -> Events.cmd_*) -> battle._on_deploy / _on_worker / _on_hero_move   (sim.deploy appends "deploy")
  battle._process: sim.step(1/60) ... _drain_events(): _step_tutorial() FIRST
      (moved = true while _ui_dir != 0; tutorial.update(sim, process_delta))
      then the event loop (deploy -> tutorial.deployed += 1, worker -> workers_bought += 1)
So an action is seen by the director one frame after it happens, except the move flag (same frame).
Economy from data: r01 start_gold 60, base_income 4.0/s, worker_income 1.5/s, worker cost 40*1.3^n, melee cost 30,
gold_max 200. Not modelled: combat, so the tut_destroy_base trigger (an ally past 50 % of the lane) is a parameter.

Run: python docs/review/text/tutorial_timing.py
"""
import json
import os

DT = 1.0 / 60.0
ACTION_TIMEOUT = 20.0
DEFAULT_TIMEOUT = 8.0
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


class Sim:
    def __init__(self):
        self.t = 0.0
        self.gold = 60.0
        self.workers = 0

    def income(self):
        return 4.0 + self.workers * 1.5

    def step(self):
        self.t += DT
        self.gold = min(200.0, self.gold + self.income() * DT)


class Director:
    def __init__(self, steps, half_lane_t, deploy_at_start=False):
        self.steps, self.idx, self.shown, self.shown_t = list(steps), 0, "", 0.0
        self.moved, self.deployed, self.workers_bought, self.enemy_base_hit = False, 0, 0, False
        self.half_lane_t = half_lane_t
        self.deploy_at_start = deploy_at_start      # what-if: 02 makes the deploy trigger true at t = 0

    def trigger(self, key, sim):
        if key == "tut_move_hero":
            return True
        if key == "tut_deploy_unit":
            return self.deploy_at_start or self.moved or sim.t >= 4.0
        if key == "tut_buy_worker":
            return self.deployed > 0 and sim.gold >= 40.0
        if key == "tut_destroy_base":
            return self.half_lane_t is not None and sim.t >= self.half_lane_t
        return sim.t >= 1.0

    def completed(self, key, sim):
        return {"tut_move_hero": self.moved, "tut_deploy_unit": self.deployed > 0,
                "tut_buy_worker": self.workers_bought > 0, "tut_destroy_base": self.enemy_base_hit}.get(key, False)

    def timeout(self, key):
        return ACTION_TIMEOUT if key in ("tut_move_hero", "tut_deploy_unit", "tut_buy_worker") else DEFAULT_TIMEOUT

    def update(self, sim, dt):
        if self.idx >= len(self.steps):
            if self.shown != "":
                self.shown = ""
                return ""
            return None
        key = self.steps[self.idx]
        if self.shown == "":
            if self.trigger(key, sim):
                self.shown, self.shown_t = key, 0.0
                return key
            return None
        self.shown_t += dt
        if self.completed(key, sim) or self.shown_t >= self.timeout(key):
            self.idx += 1
            self.shown = ""
            return ""
        return None


def run(order, policy, until=70.0, half_lane_t=None, base_hit_t=None, deploy_at_start=False):
    """policy: dict with optional absolute action times or 'react': seconds after the matching hint appears.
    keys: deploy_at, move_at (hold 0.5 s), worker_at, react (deploy/move/worker this long after their hint)."""
    sim, d = Sim(), Director(order, half_lane_t, deploy_at_start)
    log, cur, hint_seen = [], "", {}
    ui_dir_until = -1.0
    done_actions = set()
    while sim.t < until:
        # ---- input phase (before _process)
        def due(name, key):
            if name in done_actions:
                return False
            if name + "_at" in policy and policy[name + "_at"] is not None:
                return sim.t >= policy[name + "_at"]
            if "react" in policy and key in hint_seen and name in policy.get("follows", ()):
                return sim.t >= hint_seen[key] + policy["react"]
            return False
        deploy_event = worker_event = False
        if due("deploy", "tut_deploy_unit") and sim.gold >= 30.0:
            sim.gold -= 30.0
            deploy_event = True
            done_actions.add("deploy")
        if due("worker", "tut_buy_worker") and sim.gold >= 40.0 * 1.3 ** sim.workers:
            sim.gold -= 40.0 * 1.3 ** sim.workers
            sim.workers += 1
            worker_event = True
            done_actions.add("worker")
        if due("move", "tut_move_hero"):
            ui_dir_until = sim.t + 0.5
            done_actions.add("move")
        # ---- _process: sim.step then _drain_events (_step_tutorial first, then events)
        sim.step()
        if base_hit_t is not None and sim.t >= base_hit_t:
            d.enemy_base_hit = True
        if sim.t < ui_dir_until:
            d.moved = True
        k = d.update(sim, DT)
        if k is not None and k != cur:
            if cur:
                log.append({"key": cur, "event": "hide", "t": round(sim.t, 3)})
            if k:
                log.append({"key": k, "event": "show", "t": round(sim.t, 3)})
                hint_seen[k] = sim.t
            cur = k
        if deploy_event:
            d.deployed += 1
        if worker_event:
            d.workers_bought += 1
    if cur:
        log.append({"key": cur, "event": "still shown at end", "t": round(sim.t, 3)})
    return log, {"idx": d.idx, "steps_done": d.steps[:d.idx]}


def table(log):
    rows, open_ = [], {}
    for e in log:
        if e["event"] == "show":
            open_[e["key"]] = e["t"]
        else:
            s = open_.pop(e["key"], None)
            rows.append((e["key"], s, e["t"] if e["event"] == "hide" else None, None if s is None else round(e["t"] - s, 3)))
    for k, s in open_.items():
        rows.append((k, s, None, None))
    return rows


def main():
    r01 = json.load(open(os.path.join(ROOT, "data", "rounds", "r01.json"), encoding="utf-8"))
    new = r01["tutorial"]
    old = ["tut_move_hero", "tut_deploy_unit", "tut_buy_worker", "tut_destroy_base"]
    # tut_destroy_base: no combat model. Use the 02 selftest point (competent bot, old order: shown 18.5 s) only as
    # an illustration for the active profiles; the idle profile never deploys so it never triggers.
    profiles = {
        "P1a 영웅을 안 움직이고 아무것도 안 함": {"policy": {}, "half": None},
        "P1b 영웅을 안 움직이고, 안내가 뜨면 2초 뒤 출병·고용": {"policy": {"react": 2.0, "follows": ("deploy", "worker")}, "half": 30.0, "base": 33.0},
        "P2a 0.5초에 바로 출병, 안내가 뜨면 2초 뒤 이동·고용": {"policy": {"deploy_at": 0.5, "react": 2.0, "follows": ("move", "worker")}, "half": 30.0, "base": 33.0},
        "P2b 0.5초에 바로 출병, 영웅은 끝까지 안 움직임, 고용은 안내 2초 뒤": {"policy": {"deploy_at": 0.5, "react": 2.0, "follows": ("worker",)}, "half": 30.0, "base": 33.0},
    }
    out = {}
    alt = ["tut_deploy_unit", "tut_buy_worker", "tut_move_hero", "tut_destroy_base"]
    cases = (("new_140daeb", new, False), ("old_3f70e92", old, False),
             ("whatif_A deploy->worker->move->base (data only)", alt, False),
             ("whatif_B same order as 140daeb + deploy trigger true at t=0 (02 code)", new, True),
             ("whatif_C deploy->worker->move->base + deploy trigger true at t=0", alt, True))
    for order_name, order, das in cases:
        for pname, p in profiles.items():
            log, st = run(order, p["policy"], half_lane_t=p.get("half"), base_hit_t=p.get("base"), deploy_at_start=das)
            out["%s | %s" % (order_name, pname)] = {"rows": table(log), "state": st}
            print("== %s | %s" % (order_name, pname))
            for key, s, h, dur in table(log):
                print("   %-18s show %-7s hide %-7s for %s s" % (key, s, h, dur))
            print("   steps done at 70 s:", st["steps_done"])
    os.makedirs(os.path.join(ROOT, "docs", "review", "text", "evidence"), exist_ok=True)
    with open(os.path.join(ROOT, "docs", "review", "text", "evidence", "tutorial_timing_02.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
