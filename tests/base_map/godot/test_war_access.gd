extends SceneTree
const Grid = preload("res://scripts/map/hex_grid.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        printerr("FAIL: " + message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    change_scene_to_file("res://scenes/start/start.tscn")
    await process_frame
    await process_frame
    current_scene.show_houses()
    current_scene.select_house(current_scene.house_ids.find("uesugi_yamanouchi"))
    current_scene.begin()
    var deadline := Time.get_ticks_msec() + 45000
    while (current_scene == null or current_scene.name != "Main" or not current_scene.initialized) and Time.get_ticks_msec() < deadline:
        await process_frame
    if current_scene == null or current_scene.name != "Main" or not current_scene.initialized:
        check(false, "main initialized"); quit(1); return
    var main: Node = current_scene
    var session: Node = root.get_node("GameSession")
    main.game_clock.set_process(false)
    main.cpu_controller.enabled = false
    var army: Node = main.army_campaign
    var diplomacy: Node = main.diplomacy
    var actor: String = session.player_house
    army._index_district_cells()
    var a := Vector2i.ZERO
    var b := Vector2i.ZERO
    var target := ""
    for cell in army.district_cells:
        if army.cell_owner(cell) != actor or not main.hex_tile_layer.can_enter(cell): continue
        for delta in Grid.NEIGHBORS:
            var neighbor: Vector2i = cell + delta
            var owner: String = army.cell_owner(neighbor)
            if owner.is_empty() or owner == actor or session.relation(actor, owner) != "neutral": continue
            if not main.hex_tile_layer.can_enter(neighbor) or army.target_at(Grid.center(neighbor)) != Grid.key(neighbor): continue
            a = cell; b = neighbor; target = owner; break
        if not target.is_empty(): break
    check(not target.is_empty(), "land frontier with a neutral foreign ordinary tile exists")
    if target.is_empty(): quit(1); return
    var start := Grid.key(a)
    var goal := Grid.key(b)
    var unit := {"id":"access_test", "house_id":actor, "origin":start, "site_id":start, "next_site":"", "progress":0.0, "orders":[], "facing":0.0, "soldiers":100, "officers":[], "movement_hold":false, "automatic":null, "bow_reload":0.0}
    army.units[unit.id] = unit
    var drawn: Array[String] = [goal]
    check(not army.order(unit.id, goal), "player ordinary-tile order rejects neutral territory")
    check(not army.order_path(unit.id, drawn), "dragged route rejects neutral territory")
    check(not army.order_for_house(actor, unit.id, goal), "CPU order rejects neutral territory")
    check(army.route(start, goal, actor).is_empty(), "route cannot use a neutral endpoint")
    var search: RefCounted = army.new_route_search(start, goal, actor)
    search.advance(24001)
    check(not search.report().reachable, "weighted route rejects neutral territory")
    var planned: RefCounted = army.new_route_search(start, goal, actor, 24000, true)
    planned.advance(24001)
    var proposed: Dictionary = army.finish_route_report(planned, start, goal, actor)
    check(proposed.reachable, "CPU can assess a proposed war before declaring")
    check(not army.order_for_house(actor, unit.id, goal, false, proposed), "hypothetical CPU route cannot authorize undeclared entry")
    unit.orders = [goal]
    army._start_next_leg(unit)
    check(unit.next_site.is_empty() and unit.orders.is_empty(), "queued undeclared entry is stopped at leg start")
    diplomacy.on_hostile_attack(actor, target)
    check(session.relation(actor, target) == "neutral" and diplomacy.wars.is_empty(), "attack does not silently declare war")
    diplomacy._set_relation(actor, target, "ally")
    check(not army.order(unit.id, goal), "alliance alone does not authorize intrusion")
    diplomacy._set_relation(actor, target, "neutral")
    var before: float = main.house_prestige.value_for(actor)
    var defender_before: float = main.house_prestige.value_for(target)
    check(diplomacy.act("war", actor, target) == OK, "explicit diplomatic declaration succeeds")
    check(main.house_prestige.value_for(actor) == maxf(0.0, before - 30.0), "unjustified declaration costs 30 prestige")
    check(main.house_prestige.value_for(target) == defender_before, "defender pays no declaration penalty")
    check(army.order(unit.id, goal), "declared war unlocks ordinary foreign tiles")
    unit.next_site = ""; unit.orders.clear()
    check(army.order_path(unit.id, drawn), "declared war unlocks drawn paths")
    check(army.automation.fastest_route(start, goal, actor, target, 120).reachable, "automation shares territory access")
    check(army.may_enter_territory(target, a), "defender may enter aggressor territory")
    check(diplomacy.act("war", actor, target) == ERR_UNAVAILABLE and main.house_prestige.value_for(actor) == maxf(0.0, before - 30.0), "rejected repeat declaration has no additional cost")
    var district_id: String = army.district_cells[b]
    var new_owner := ""
    for house in main.governance_registry.houses:
        if house != actor and house != target and session.relation(actor, house) == "neutral":
            new_owner = house; break
    check(not new_owner.is_empty(), "neutral third house exists")
    main.governance_registry.districts[district_id].house_id = new_owner
    main.cpu_controller.invalidate_routes()
    check(not army.may_enter_territory(actor, b), "ownership changes immediately update tile access")
    main.governance_registry.districts[district_id].house_id = target
    main.cpu_controller.invalidate_routes()
    unit.progress = 0.25
    diplomacy.finish_peace(actor, target)
    army._march_step(0.1)
    check(unit.site_id == start and unit.next_site.is_empty() and unit.orders.is_empty(), "peace halts an existing march before foreign entry")
    check(not army.order(unit.id, goal), "truce blocks new movement")
    army.units.clear()
    session.save_directory = "user://qa_war_access_%d" % OS.get_process_id()
    check(session.save_game(main, 1) == OK, "current state saves")
    var saved: Dictionary = session.read_save(1)
    check(not saved.is_empty() and is_equal_approx(float(saved.prestige[actor]), maxf(0.0, before - 30.0)) and saved.diplomacy.truces.has(session.pair(actor, target)), "disk save preserves prestige penalty and truce")
    main.house_prestige.values = saved.prestige.duplicate(true)
    diplomacy.restore_state(saved.diplomacy)
    check(not army.may_enter_territory(actor, b), "restored truce keeps frontier closed")
    print("War access tests: %d failures" % failures)
    quit(1 if failures else 0)
