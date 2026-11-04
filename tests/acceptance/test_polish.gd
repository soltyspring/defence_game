extends SceneTree
const Tut = preload("res://src/gameplay/tutorial_director.gd")
const Sim = preload("res://src/gameplay/battle_sim.gd")
const ContentScript = preload("res://src/core/content.gd")
const SaveScript = preload("res://src/core/save.gd")
const Layout = preload("res://src/ui/hud_layout.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL polish: ", message)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var tut = Tut.new()
    var mock = {"t": 0.0, "enemies": [], "players": [], "gold": 60.0}
    tut.setup(["tut_deploy_unit", "tut_move_hero", "tut_buy_worker"], [])
    check(tut.update(mock, 0.016) == "tut_deploy_unit", "r01 shows deployment immediately without hero movement")
    tut.moved = true
    tut.deployed = 1
    check(tut.update(mock, 0.016) == "", "deployment guidance hides after deployment")
    check(tut.update(mock, 0.016) == "tut_buy_worker", "already completed movement is skipped, without a one-frame flash")
    check(tut.done.has("tut_move_hero"), "skipped completed action is persisted")
    var warning = Tut.new()
    warning.setup(["tut_bomber_warning"], [])
    mock.t = 2.0
    check(warning.update(mock, 0.016) == null, "bomber warning stays absent before bomber spawn")
    mock.enemies = [{"id": "e_bomber", "dying": false}]
    check(warning.update(mock, 0.016) == "tut_bomber_warning", "warning appears when the bomber is present")
    var content = ContentScript.new()
    content.load_all("res://data")
    var sim = Sim.new()
    sim.setup(content, "r05", 41)
    sim.gold = 1000.0
    sim.deploy("melee_basic")
    var unit = sim.players[0]
    unit.atk_cd = 1.0
    unit.buff_mul = 1.3
    unit.aura_mul = 1.0
    sim._attack_logic(unit, null, false, false, 0.1)
    check(is_equal_approx(unit.atk_cd, 0.9), "Rally does not add undocumented attack speed")
    unit.aura_mul = 1.2
    sim._attack_logic(unit, null, false, false, 0.1)
    check(is_equal_approx(unit.atk_cd, 0.78), "the intended hero-aura attack speed remains")
    var save = SaveScript.new()
    save.path = "user://polish/rounds.json"
    root.add_child(save)
    save.progress = SaveScript.fresh()
    save.progress.unlocked_round = 2
    save.progress.stars = {"r08": 1}
    save.progress.open_rounds = ["r06"]
    check(save.is_unlocked(5) and save.is_unlocked(7) and save.is_unlocked(8), "retained round and cleared round plus its successor remain playable beyond a gap")
    check(not save.is_unlocked(3), "unplayed rounds between retained rounds remain locked")
    check(not save.is_unlocked(-1), "negative round indices cannot be started")
    save.progress.stars["r04"] = 0
    check(not save.is_unlocked(3) and not save.is_unlocked(4), "zero stars are not treated as a clear")
    save.progress.unlocked_round = content.round_order.size()+1
    check(not save.is_unlocked(content.round_order.size()), "all-clear sentinel does not unlock a nonexistent next round")
    save.progress.unlocked_round = 2
    var retained = save._unlock_state(["r01","r02"], 1, {"retired_round":true}, false)
    check(retained.extra.has("retired_round"), "temporarily removed open ids are kept for a later return")
    var select = load("res://scenes/ui/round_select.tscn").instantiate()
    var live_save = root.get_node("Save")
    var original_progress: Dictionary = live_save.progress
    live_save.progress = save.progress
    root.add_child(select)
    await process_frame
    check(select.is_round_unlocked(5) and not select.is_round_unlocked(3), "round-select uses the same unlock rule as the engine")
    select.queue_free()
    live_save.progress = original_progress
    save.progress = SaveScript.fresh()
    save.content_ref = content
    save.progress.coins = 500
    save.progress.upgrades = {"old_melee":6}
    save.progress.upgrade_paid = {"old_melee":{"6":42}}
    save.progress.content_version = "polish-old"
    save.progress.content_snapshot = {"order":Array(content.round_order),"upgrades":{"old_melee":{"target":"unit:melee_basic","costs":[60,100,160,190,42]}}}
    save.progress.migrations_applied = []
    var deep = 1
    for i in 600: deep = [deep]
    save.progress.junk = deep
    save.recovery_source = "main"
    DirAccess.make_dir_recursive_absolute(save.path.get_base_dir())
    save._fault = "after_tmp_write"
    save._apply_content_migration()
    check(save.fault_fired == "after_tmp_write", "migration rollback test reaches the injected write failure")
    check(save.progress.upgrades == {"old_melee":6} and save.progress.coins == 500, "failed rename/refund restores upgrade and coins")
    check(save.progress.upgrade_paid.get("old_melee",{}).get("6") == 42, "failed migration restores nested paid-level history")
    check(not save.progress.content_snapshot.upgrades.has("up_melee_basic") and save.progress.migrations_applied.is_empty(), "failed rename leaves the old snapshot and idempotency keys intact")
    var nested = save.progress.junk
    var depth := 0
    while nested is Array and nested.size() == 1 and depth < 601:
        nested = nested[0]
        depth += 1
    check(depth == 600 and nested == 1, "deep unknown extension data survives migration rollback intact")
    save.queue_free()
    var top = load("res://src/ui/hud_top.gd").new()
    root.add_child(top)
    top.layout = Layout.compute(Vector2(640,360), Rect2(34,0,572,360), 5,3,48)
    top.snap = sim.snapshot()
    top.round_title = "6. Break the Mold Wall"
    await process_frame
    await process_frame
    check(top.income_rect.size.x > 0, "income remains visible in the narrow resource panel")
    for size in [Vector2(640,360),Vector2(640,400),Vector2(640,480),Vector2(800,360)]:
        for target in [40,48]:
            var layout = Layout.compute(size,Rect2(Vector2(34,0),size-Vector2(68,0)),5,3,target)
            check(Layout.validate(layout).is_empty(), "HUD fits and keeps targets apart at %s / %d" % [size,target])
    top.queue_free()
    content.free()
    await process_frame
    print("[polish] passed=", checks-failures, " failed=", failures)
    quit(0 if failures == 0 else 1)
