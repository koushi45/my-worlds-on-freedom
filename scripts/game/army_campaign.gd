extends Node2D
## Marches between adjacent hex tiles with 30 Hz position updates.
const Grid = preload("res://scripts/map/hex_grid.gd")
const Terrain = preload("res://scripts/map/hex_terrain.gd")
const ARMY_ICONS = {
    "blue": {64: preload("res://assets/ui/army/totsu_blue_64.png"), 96: preload("res://assets/ui/army/totsu_blue_96.png"), 128: preload("res://assets/ui/army/totsu_blue_128.png"), 192: preload("res://assets/ui/army/totsu_blue_192.png"), 256: preload("res://assets/ui/army/totsu_blue_256.png")},
    "green": {64: preload("res://assets/ui/army/totsu_green_64.png"), 96: preload("res://assets/ui/army/totsu_green_96.png"), 128: preload("res://assets/ui/army/totsu_green_128.png"), 192: preload("res://assets/ui/army/totsu_green_192.png"), 256: preload("res://assets/ui/army/totsu_green_256.png")},
    "red": {64: preload("res://assets/ui/army/totsu_red_64.png"), 96: preload("res://assets/ui/army/totsu_red_96.png"), 128: preload("res://assets/ui/army/totsu_red_128.png"), 192: preload("res://assets/ui/army/totsu_red_192.png"), 256: preload("res://assets/ui/army/totsu_red_256.png")},
    "neutral": {64: preload("res://assets/ui/army/totsu_neutral_64.png"), 96: preload("res://assets/ui/army/totsu_neutral_96.png"), 128: preload("res://assets/ui/army/totsu_neutral_128.png"), 192: preload("res://assets/ui/army/totsu_neutral_192.png"), 256: preload("res://assets/ui/army/totsu_neutral_256.png")},
}
const MOVE_STEP := 1.0 / 30.0
const BOW_RANGE := Grid.ROOT_3 * Grid.RADIUS * 1.5
const BOW_HIT_RADIUS := Grid.RADIUS * 0.45
const BOW_VOLLEY_LANES := 9
const MELEE_LOSS_RATE := 0.06
const ROUTE_BLUE := Color("#3298ef")
signal changed

var membership_revision := 0
var main: Node2D
var units: Dictionary = {}
var garrisons: Dictionary = {}
var occupations: Dictionary = {} # District progress survives army replacement and retreat.
var automation: RefCounted
var next_id := 1
var selected_id := ""
var graph: Dictionary = {}
var last_error := ""
var move_accumulator := 0.0
var preview_id := ""
var preview_nodes: Array[String] = []
var last_icon_size := 0
var last_pixel_scale := 0.0
var route_obstacles: Dictionary = {}
var weighted_obstacles: Dictionary = {}
var political_cells: Dictionary = {}
var political_version := -1
var district_cells: Dictionary = {} # Static geometry; owners are read live.
var hex_node_points: Dictionary = {} # Immutable hex centres; bounded, never saved.

func setup(owner: Node2D) -> void:
    main = owner
    automation = preload("res://scripts/game/army_automation.gd").new(self)
    for site_id in main.governance_registry.sites:
        var site: Dictionary = main.governance_registry.sites[site_id]
        if "castle" not in site.get("roles", []): continue
        var district: Dictionary = main.governance_registry.districts.get(site.get("district_key", ""), {})
        garrisons[site_id] = clampi(roundi(float(district.get("population", 20000)) * 0.025), 100, 3000)
    # A new house begins with stores for a quarter-strength departure from each
    # district; loaded sessions restore their exact saved resource stock.
    if GameSession.pending.is_empty() and not GameSession.player_house.is_empty():
        var starter_provisions := {}
        for district in main.governance_registry.districts.values():
            var possible: int = main.district_actions.sortie_available(district)
            if possible >= 100:
                starter_provisions[district.house_id] = int(starter_provisions.get(district.house_id, 0)) + ceili(float(maxi(100, roundi(float(possible) * 0.25))) * 0.4)
        for house_id in starter_provisions:
            if main.district_economy.house_resources.has(house_id):
                main.district_economy.house_resources[house_id].provisions += starter_provisions[house_id]
    # Site lookup is used for dispatch and arrival effects only, never pathfinding.
    for site_id in main.governance_registry.sites: graph[site_id] = []
    for district_id in main.governance_registry.districts:
        var district: Dictionary = main.governance_registry.districts[district_id]
        var center := Vector2(float(district.point[0]), float(district.point[1]))
        var closest := ""
        var best := INF
        for site_id in graph:
            if site_id.begins_with("district:"): continue
            var site: Dictionary = main.governance_registry.sites[site_id]
            var location := Vector2(float(site.point[0]), float(site.point[1]))
            var distance := center.distance_squared_to(location)
            if site.house_id == district.house_id: distance *= 0.5
            if distance < best: best = distance; closest = site_id
        if closest.is_empty(): continue
        var node_id: String = "district:" + district_id
        graph[node_id] = [closest]
        graph[closest].append(node_id)
    z_index = 30

func _invalidate_unit_membership() -> void:
    membership_revision += 1
    if main != null and is_instance_valid(main.cpu_controller):
        main.cpu_controller.unit_index_dirty = true
        main.cpu_controller.unit_positions_dirty = true
        main.cpu_controller.powers.clear()
        main.cpu_controller.power_days.clear()

func _process(delta: float) -> void:
    var side := icon_size()
    var scale := pixel_scale()
    if side != last_icon_size or not is_equal_approx(scale, last_pixel_scale):
        last_icon_size = side
        last_pixel_scale = scale
        queue_redraw()

func advance_simulation(game_days: float) -> void:
    # Movement/combat consume exactly the time accepted by the calendar.
    var remaining := game_days
    while remaining > 0.0000001:
        var step := minf(MOVE_STEP, remaining)
        _march_step(step)
        remaining -= step

func _march_step(game_days: float) -> void:
    var moved := false
    for id in units.keys():
        if not units.has(id): continue
        var unit: Dictionary = units[id]
        if unit.get("movement_hold", false): continue
        if unit.next_site.is_empty(): _start_next_leg(unit)
        if unit.next_site.is_empty(): continue
        unit.facing = (node_point(unit.next_site) - node_point(unit.site_id)).angle() + PI / 2.0
        var remaining_days := game_days
        while units.has(id) and not unit.next_site.is_empty() and remaining_days > 0.0:
            var leg_days := travel_days_for_leg(unit.site_id, unit.next_site)
            if is_inf(leg_days) or not may_enter_territory(unit.house_id, Grid.cell_at(node_point(unit.next_site))):
                last_error = blocked_reason(Grid.cell_at(node_point(unit.next_site))) if is_inf(leg_days) else territory_blocked_reason()
                unit.next_site = ""
                unit.orders.clear()
                unit.progress = 0.0
                changed.emit()
                break
            var needed_days := (1.0 - float(unit.progress)) * leg_days
            if remaining_days < needed_days - 0.000001:
                unit.progress += remaining_days / leg_days
                break
            remaining_days = maxf(0.0, remaining_days - needed_days)
            unit.site_id = unit.next_site
            if Grid.valid(unit.site_id): unit.site_id = target_at(node_point(unit.site_id))
            unit.next_site = ""
            unit.progress = 0.0
            _arrive(id)
            if not units.has(id): break
            _start_next_leg(unit)
            changed.emit()
        moved = true
    var positions := {}
    for id in units: positions[id] = unit_position(units[id])
    _melee_step(game_days, positions)
    _bow_step(game_days, positions)
    if moved:
        queue_redraw()
        if is_instance_valid(main.cpu_controller): main.cpu_controller.unit_positions_dirty = true

func travel_days_for_leg(from_node: String, to_node: String) -> float:
    var from_cell := Grid.cell_at(node_point(from_node))
    var to_cell := Grid.cell_at(node_point(to_node))
    var connected_road: bool = main.developer_tools != null and main.developer_tools.network.connected(from_cell, to_cell)
    return Terrain.days_for(main.hex_tile_layer.terrain_for(to_cell), connected_road)

func blocked_reason(cell: Vector2i) -> String:
    if main.hex_tile_layer.terrain_for(cell) == Terrain.HIGH_MOUNTAIN: return "高山地は通行できません。"
    return "陸地のないタイルは通行できません。"

func _start_next_leg(unit: Dictionary) -> void:
    if unit.next_site.is_empty() and not unit.orders.is_empty():
        var next_node: String = unit.orders.pop_front()
        var next_cell := Grid.cell_at(node_point(next_node))
        if not main.hex_tile_layer.can_enter(next_cell):
            unit.orders.clear()
            unit.progress = 0.0
            last_error = blocked_reason(next_cell)
            return
        if not may_enter_territory(unit.house_id, next_cell):
            unit.orders.clear()
            unit.progress = 0.0
            last_error = territory_blocked_reason()
            return
        unit.next_site = next_node
        unit.progress = 0.0
        unit.facing = (node_point(next_node) - node_point(unit.site_id)).angle() + PI / 2.0

func district_id_for_node(node_id: String) -> String:
    return node_id.trim_prefix("district:") if node_id.begins_with("district:") else ""

func node_name(node_id: String) -> String:
    if Grid.valid(node_id):
        var cell := Grid.parse(node_id)
        return "タイル (%d, %d)" % [cell.x, cell.y]
    var district_id := district_id_for_node(node_id)
    if not district_id.is_empty(): return "%s・郡奉行所" % str(main.governance_registry.districts[district_id].name)
    return str(main.governance_registry.sites[node_id].name)

func node_point(node_id: String) -> Vector2:
    if hex_node_points.has(node_id): return hex_node_points[node_id]
    if Grid.valid(node_id):
        var point := Grid.center(Grid.parse(node_id))
        if hex_node_points.size() >= 4096: hex_node_points.clear()
        hex_node_points[node_id] = point
        return point
    var district_id := district_id_for_node(node_id)
    if not district_id.is_empty() and main.district_office_layer.records.has(district_id):
        return main.district_office_layer.office_point(district_id)
    var record: Dictionary = main.governance_registry.districts[district_id] if not district_id.is_empty() else main.governance_registry.sites[node_id]
    return Grid.center(Grid.cell_at(Vector2(float(record.point[0]),float(record.point[1]))))

func available_officers(district_id: String) -> Array[String]:
    if not main.governance_registry.districts.has(district_id): return []
    var house_id: String = main.governance_registry.districts[district_id].house_id
    var result: Array[String] = main.retainer_management.officers_in_district(house_id, district_id)
    for unit in units.values():
        for id in officer_pool(unit): result.erase(id)
    result.sort_custom(func(a: String, b: String): return score(a) > score(b))
    return result

func score(officer_id: String) -> float:
    var value: Variant = main.officer_registry.ability(officer_id, "command")
    return float(value) if value != null else 50.0

func recommended_officers(district_id: String) -> Array[String]:
    var candidates := available_officers(district_id)
    var result: Array[String] = []
    if candidates.is_empty(): return result
    # Command governs the general's siege/occupation strength. Break ties by
    # valor, then ID so opening the panel always produces the same formation.
    candidates.sort_custom(func(a: String, b: String):
        if score(a) != score(b): return score(a) > score(b)
        var av := unit_valor({"officers": [a]})
        var bv := unit_valor({"officers": [b]})
        return av > bv if av != bv else a < b)
    result.append(candidates.pop_front())
    candidates.sort_custom(func(a: String, b: String):
        var av := unit_valor({"officers": [a]})
        var bv := unit_valor({"officers": [b]})
        return av > bv if av != bv else a < b)
    # Melee uses the average valor, so filling every slot can weaken the unit.
    for officer_id in candidates:
        if result.size() == 3: break
        if unit_valor({"officers": [officer_id]}) <= unit_valor({"officers": result}): break
        result.append(officer_id)
    return result

func dispatch(district_id: String, officers: Array, percent: int, horses: bool, guns: bool) -> String:
    return dispatch_for_house(GameSession.player_house, district_id, officers, percent, horses, guns)

func dispatch_for_house(actor: String, district_id: String, officers: Array, percent: int, horses: bool, guns: bool) -> String:
    last_error = ""
    var origin := "district:" + district_id
    if not main.governance_registry.districts.has(district_id) or not graph.has(origin): last_error = "出陣できる郡を選んでください。"; return ""
    var district: Dictionary = main.governance_registry.districts[district_id]
    var house_id: String = district.house_id
    if actor.is_empty() or house_id != actor: last_error = "自家の郡からのみ出陣できます。"; return ""
    if float(district.occupation_stability) < 100.0: last_error = "占領後の統治が安定するまで徴兵・出陣できません。"; return ""
    if percent not in [25, 50, 75, 100] or officers.is_empty() or officers.size() > 3: last_error = "部隊編成が不正です。"; return ""
    var available := available_officers(district_id)
    var unique := {}
    for officer_id in officers:
        if officer_id not in available or unique.has(officer_id): last_error = "選択した武将は出陣できません。"; return ""
        unique[officer_id] = true
    var waiting := 0
    for unit in units.values():
        if unit.site_id == origin and unit.get("next_site", "").is_empty(): waiting += 1
    if waiting >= 3: last_error = "郡内の待機部隊は3部隊までです。"; return ""
    var soldiers := int(floor(float(main.district_actions.sortie_available(district)) * percent / 100.0))
    if soldiers < 100: last_error = "出陣には100人以上必要です。"; return ""
    var provisions := ceili(soldiers * 120.0 / 300.0) # Economy units: one provision feeds ten soldiers for 30 days.
    var resources: Dictionary = main.district_economy.house_resources[house_id]
    if int(resources.provisions) < provisions: last_error = "120日分の腰兵糧が不足しています。"; return ""
    var equipment := ceili(soldiers * 0.2)
    if horses and int(resources.get("horses", 0)) < equipment: last_error = "軍馬が不足しています。"; return ""
    if guns and int(resources.get("guns", 0)) < equipment: last_error = "鉄砲が不足しています。"; return ""
    resources.provisions -= provisions
    if horses: resources.horses -= equipment
    if guns: resources.guns -= equipment
    district.sortie_troops -= soldiers
    var id := "army_%d" % next_id
    next_id += 1
    units[id] = {"id":id, "house_id":house_id, "origin":origin, "site_id":origin, "next_site":"", "progress":0.0,
        "orders":[], "officers":officers.duplicate(), "officer_pool":officers.duplicate(), "soldiers":soldiers, "supply_days":120, "horses":horses, "guns":guns,
        "horse_count":equipment if horses else 0, "gun_count":equipment if guns else 0,
        "facing":0.0, "movement_hold":false, "bow_reload":0.0, "bow_damage":0.0, "melee_damage":0.0, "automatic":null}
    if actor == GameSession.player_house: selected_id = id
    _invalidate_unit_membership()
    changed.emit(); queue_redraw()
    return id

func officer_pool(unit: Dictionary) -> Array:
    return unit.get("officer_pool", unit.officers)

func equipment_count(unit: Dictionary, kind: String) -> int:
    return mini(int(unit.get(kind + "_count", ceili(int(unit.soldiers) * 0.2) if unit.get("horses" if kind == "horse" else "guns", false) else 0)), ceili(int(unit.soldiers) * 0.2))

func merge_reason(id: String, other_id: String) -> String:
    if id == other_id or not units.has(id) or not units.has(other_id): return "別の部隊を選択してください。"
    var unit: Dictionary = units[id]
    var other: Dictionary = units[other_id]
    if unit.house_id != GameSession.player_house or other.house_id != unit.house_id: return "自家の部隊同士だけ合流できます。"
    if not unit.next_site.is_empty() or not other.next_site.is_empty(): return "両部隊を停止させてください。"
    if Grid.cell_at(unit_position(unit)) != Grid.cell_at(unit_position(other)): return "同じ六角形にいる部隊同士だけ合流できます。"
    if main.technology_orders.training(id) or main.technology_orders.training(other_id): return "調練中は合流できません。"
    if melee_engagements().has(id): return "接近戦中は合流できません。"
    if int(unit.soldiers) + int(other.soldiers) > 2000000000: return "合流後の兵数が上限を超えます。"
    return ""

func merge_candidates(id: String) -> Array[String]:
    var result: Array[String] = []
    for other_id in units:
        if merge_reason(id, other_id).is_empty(): result.append(other_id)
    result.sort()
    return result

func merge(id: String, other_id: String) -> bool:
    last_error = merge_reason(id, other_id)
    if not last_error.is_empty(): return false
    var unit: Dictionary = units[id]
    var other: Dictionary = units[other_id]
    var pool: Array = officer_pool(unit).duplicate()
    for officer_id in officer_pool(other):
        if officer_id not in pool: pool.append(officer_id)
    var candidates: Array = unit.officers.duplicate()
    for officer_id in other.officers:
        if officer_id not in candidates: candidates.append(officer_id)
    candidates.sort_custom(func(a: String, b: String): return score(a) > score(b) if not is_equal_approx(score(a), score(b)) else a < b)
    var commanders: Array = [candidates[0]]
    var deputies := candidates.slice(1)
    deputies.sort_custom(func(a: String, b: String):
        var av := float(main.officer_registry.ability(a, "tactics"))
        var bv := float(main.officer_registry.ability(b, "tactics"))
        return av > bv if not is_equal_approx(av, bv) else a < b)
    commanders.append_array(deputies.slice(0, 2))
    main.technology_orders.merge_drills(id, other_id)
    var soldiers := int(unit.soldiers) + int(other.soldiers)
    var food := float(unit.soldiers) * maxf(0.0, float(unit.supply_days)) + float(other.soldiers) * maxf(0.0, float(other.supply_days))
    var horse_count := equipment_count(unit, "horse") + equipment_count(other, "horse")
    var gun_count := equipment_count(unit, "gun") + equipment_count(other, "gun")
    unit.soldiers = soldiers; unit.supply_days = food / soldiers
    unit.horse_count = horse_count; unit.gun_count = gun_count
    unit.horses = horse_count > 0; unit.guns = gun_count > 0
    unit.officer_pool = pool; unit.officers = commanders
    unit.site_id = target_at(unit_position(unit))
    unit.orders.clear(); unit.automatic = null; unit.movement_hold = false
    unit.bow_reload = maxf(float(unit.bow_reload), float(other.bow_reload))
    unit.bow_damage = 0.0; unit.melee_damage = 0.0
    units.erase(other_id)
    _invalidate_unit_membership()
    selected_id = id
    clear_route_preview()
    automation.invalidate_routes()
    changed.emit(); queue_redraw()
    return true

func set_commanders(id: String, officers: Array) -> bool:
    last_error = ""
    if not units.has(id) or units[id].house_id != GameSession.player_house: last_error = "自家の部隊を選択してください。"; return false
    if officers.is_empty() or officers.size() > 3: last_error = "大将1名・副将2名まで選択してください。"; return false
    var pool := officer_pool(units[id])
    var unique := {}
    for officer_id in officers:
        if officer_id not in pool or unique.has(officer_id): last_error = "部隊に随伴する武将を重複せず選択してください。"; return false
        unique[officer_id] = true
    units[id].officers = officers.duplicate()
    _invalidate_unit_membership()
    changed.emit(); queue_redraw()
    return true

func _index_district_cells() -> void:
    if not district_cells.is_empty(): return
    for district_id in main.district_layer.records:
        if not main.governance_registry.districts.has(district_id): continue
        var rect: Rect2 = main.district_layer.records[district_id].rect
        for r in range(floori(rect.position.y / (Grid.RADIUS * 1.5)), ceili(rect.end.y / (Grid.RADIUS * 1.5)) + 1):
            for q in range(floori(rect.position.x / (Grid.ROOT_3 * Grid.RADIUS) - r * 0.5), ceili(rect.end.x / (Grid.ROOT_3 * Grid.RADIUS) - r * 0.5) + 1):
                var cell := Vector2i(q, r)
                if not main.hex_tile_layer.visible_cells.has(cell): continue
                if main.district_layer.contains_point(district_id, Grid.center(cell)):
                    district_cells[cell] = district_id
    for district_id in main.district_office_layer.records:
        district_cells[Grid.cell_at(node_point("district:" + district_id))] = district_id

func cell_owner(cell: Vector2i) -> String:
    _index_district_cells()
    var district_id: String = district_cells.get(cell, "")
    return str(main.governance_registry.districts[district_id].house_id) if not district_id.is_empty() else ""

func may_enter_territory(actor: String, cell: Vector2i) -> bool:
    var owner := cell_owner(cell)
    return owner.is_empty() or owner == actor or (GameSession.relation(actor, owner) == "enemy" and main.diplomacy.truce_remaining(actor, owner) == 0)

func territory_blocked_reason() -> String:
    return "他国の郡には侵入できません。外交でその家に宣戦布告してください。"

func route(start: String, target: String, actor := "") -> Array:
    if start == target: return []
    var start_cell := Grid.cell_at(node_point(start))
    var target_cell := Grid.cell_at(node_point(target))
    if not main.hex_tile_layer.can_enter(start_cell) or not main.hex_tile_layer.can_enter(target_cell): return []
    var obstacles := route_blocked(actor, start_cell, target_cell).duplicate()
    obstacles.merge(main.hex_tile_layer.impassable_cells)
    if obstacles.has(target_cell): return []
    var path := Grid.path(start_cell, target_cell)
    for node_id in path:
        if not main.hex_tile_layer.can_enter(Grid.parse(node_id)) or obstacles.has(Grid.parse(node_id)):
            path = Grid.path_avoiding(start_cell, target_cell, obstacles, main.hex_tile_layer.visible_cells)
            break
    if path.is_empty() and start_cell != target_cell: return []
    if path.is_empty(): path.append(target)
    else: path[-1] = target
    return path

func route_blocked(actor: String, _start_cell: Vector2i, _target_cell: Vector2i, prospective_enemy := "") -> Dictionary:
    _index_district_cells()
    var version: int = main.cpu_controller.route_version
    if political_version != version:
        political_version = version
        political_cells.clear()
        weighted_obstacles.clear()
        for cell in district_cells:
            var owner: String = main.governance_registry.districts[district_cells[cell]].house_id
            if not political_cells.has(owner): political_cells[owner] = []
            political_cells[owner].append(cell)
    var key := actor + "|" + prospective_enemy
    if not weighted_obstacles.has(key):
        var blocked := {}
        for owner in political_cells:
            if actor.is_empty() or owner == actor or owner == prospective_enemy: continue
            if GameSession.relation(actor, owner) == "enemy" and main.diplomacy.truce_remaining(actor, owner) == 0: continue
            for cell in political_cells[owner]: blocked[cell] = true
        if weighted_obstacles.size() >= 16: weighted_obstacles.erase(weighted_obstacles.keys()[0])
        weighted_obstacles[key] = blocked
    return weighted_obstacles[key]

func route_edge_days(a: Vector2i, b: Vector2i) -> float:
    var road: bool = main.developer_tools != null and main.developer_tools.network.connected(a, b)
    return Terrain.days_for(main.hex_tile_layer.terrain_for(b), road)

func new_route_search(start: String, target: String, actor: String, node_limit := 24000, planning := false) -> RefCounted:
    var search := preload("res://scripts/game/army_route_search.gd").new()
    var a := Grid.cell_at(node_point(start))
    var b := Grid.cell_at(node_point(target))
    # CPU may assess a proposed war; actual orders always revalidate strict access.
    var prospective_enemy := ""
    if planning:
        for cell in [a, b]:
            var owner := cell_owner(cell)
            if not owner.is_empty() and owner != actor and GameSession.relation(actor, owner) == "neutral" and main.diplomacy.truce_remaining(actor, owner) == 0:
                prospective_enemy = owner
    search.setup(a, b, route_blocked(actor, a, b, prospective_enemy), main.hex_tile_layer.visible_cells, route_edge_days, node_limit)
    search.terrain_costs = true
    if main.developer_tools != null:
        search.road_cells = main.developer_tools.network.cells
        search.excluded_edges = main.developer_tools.network.excluded_edges
    if not main.hex_tile_layer.can_enter(a) or not main.hex_tile_layer.can_enter(b): search.status = "unreachable"
    return search

func finish_route_report(search: RefCounted, start: String, target: String, actor: String) -> Dictionary:
    var info: Dictionary = search.report()
    if info.reachable:
        if info.path.is_empty() and start != target: info.path.append(target)
        elif not info.path.is_empty(): info.path[-1] = target
    info.merge({"start":start, "target":target, "actor":actor, "version":main.cpu_controller.route_version}, true)
    return info

func evaluated_path_valid(info: Dictionary, actor: String, start: String, target: String) -> bool:
    if not info.get("reachable", false) or info.get("actor") != actor or info.get("start") != start or info.get("target") != target: return false
    if int(info.get("version", -1)) != main.cpu_controller.route_version: return false
    var previous := Grid.cell_at(node_point(start))
    var end_cell := Grid.cell_at(node_point(target))
    var obstacles := route_blocked(actor, previous, end_cell)
    for node_id in info.path:
        var cell := Grid.cell_at(node_point(node_id))
        if Grid.distance(previous, cell) > 1 or not main.hex_tile_layer.can_enter(cell) or obstacles.has(cell): return false
        previous = cell
    return previous == end_cell

func target_at(point: Vector2) -> String:
    var cell := Grid.cell_at(point)
    var id := Grid.key(cell)
    if not Grid.valid(id): return ""
    var office_id: String = str(main.district_office_layer.cell_districts.get(cell, ""))
    if not office_id.is_empty(): return "district:" + office_id
    # Castles and supply sites occupy tiles, including clicks away from their marker.
    for site_id in main.governance_registry.sites:
        if Grid.cell_at(node_point(site_id)) == cell: return site_id
    return id

func order(id: String, target: String, append_waypoint := false) -> bool:
    if units.has(id) and units[id].house_id == GameSession.player_house: units[id].automatic = null
    return order_for_house(GameSession.player_house, id, target, append_waypoint)

func order_for_house(actor: String, id: String, target: String, append_waypoint := false, evaluated: Dictionary = {}) -> bool:
    last_error = ""
    if not units.has(id) or (not graph.has(target) and not Grid.valid(target)): last_error = "目標を指定できません。"; return false
    var unit: Dictionary = units[id]
    if actor.is_empty() or unit.house_id != actor: last_error = "自家の部隊にのみ命令できます。"; return false
    if main.technology_orders.training(id): last_error = "調練完了まで移動できません。"; return false
    var target_cell := Grid.cell_at(node_point(target))
    if not main.hex_tile_layer.can_enter(target_cell): last_error = blocked_reason(target_cell); return false
    if not may_enter_territory(actor, target_cell): last_error = territory_blocked_reason(); return false
    var start: String = unit.orders.back() if append_waypoint and not unit.orders.is_empty() else (unit.next_site if not unit.next_site.is_empty() else unit.site_id)
    var path: Array
    if not evaluated.is_empty():
        if not evaluated_path_valid(evaluated, actor, start, target): last_error = "経路の再評価が必要です。"; return false
        path = evaluated.path.duplicate()
    else:
        path = route(start, target, actor)
    if path.is_empty() and start != target: last_error = "移動先のタイルがありません。"; return false
    if not append_waypoint: unit.orders.clear()
    unit.orders.append_array(path)
    unit.movement_hold = false
    _start_next_leg(unit)
    changed.emit(); queue_redraw()
    return true

func cancel_movement(id: String) -> bool:
    if units.has(id) and units[id].house_id == GameSession.player_house: units[id].automatic = null
    return cancel_movement_for_house(GameSession.player_house, id)

func cancel_movement_for_house(actor: String, id: String) -> bool:
    if not units.has(id) or actor.is_empty() or units[id].house_id != actor: return false
    var unit: Dictionary = units[id]
    unit.orders.clear()
    # An underway leg keeps its position and ends at the adjacent tile.
    if is_zero_approx(float(unit.progress)): unit.next_site = ""; unit.progress = 0.0
    if actor == GameSession.player_house: clear_route_preview()
    changed.emit(); queue_redraw()
    return true

func order_from_click(id: String, target: String, append_waypoint := true) -> bool:
    if units.has(id) and units[id].house_id == GameSession.player_house:
        var unit: Dictionary = units[id]
        var destination: String = unit.orders.back() if not unit.orders.is_empty() else unit.next_site
        if not destination.is_empty() and Grid.cell_at(node_point(destination)) == Grid.cell_at(node_point(target)):
            return cancel_movement(id)
    return order(id, target, append_waypoint)

func order_path(id: String, drawn_nodes: Array[String]) -> bool:
    if units.has(id) and units[id].house_id == GameSession.player_house: units[id].automatic = null
    return order_path_for_house(GameSession.player_house, id, drawn_nodes)

func order_path_for_house(actor: String, id: String, drawn_nodes: Array[String]) -> bool:
    last_error = ""
    if not units.has(id) or actor.is_empty() or units[id].house_id != actor:
        last_error = "自家の部隊にのみ命令できます。"
        return false
    var unit: Dictionary = units[id]
    if main.technology_orders.training(id): last_error = "調練完了まで移動できません。"; return false
    var anchor: String = unit.next_site if not unit.next_site.is_empty() else unit.site_id
    var previous := Grid.cell_at(node_point(anchor))
    var steps: Array[String] = []
    for node_id in drawn_nodes:
        if not Grid.valid(node_id): last_error = "六角形の経路を指定してください。"; return false
        var cell := Grid.parse(node_id)
        if cell == previous: continue
        if Grid.distance(previous, cell) != 1: last_error = "経路は隣接する六角形を通してください。"; return false
        if not main.hex_tile_layer.can_enter(cell): last_error = blocked_reason(cell); return false
        if not may_enter_territory(actor, cell): last_error = territory_blocked_reason(); return false
        steps.append(node_id)
        previous = cell
    if steps.is_empty(): last_error = "移動先のタイルがありません。"; return false
    steps[-1] = target_at(node_point(steps[-1]))
    unit.orders = steps
    unit.movement_hold = false
    _start_next_leg(unit)
    if actor == GameSession.player_house: clear_route_preview()
    changed.emit(); queue_redraw()
    return true

func return_home(id: String) -> bool:
    if units.has(id) and units[id].house_id == GameSession.player_house: units[id].automatic = null
    return return_home_for_house(GameSession.player_house, id)

func return_home_for_house(actor: String, id: String) -> bool:
    if not units.has(id) or actor.is_empty() or units[id].house_id != actor: return false
    var origin_id := district_id_for_node(units[id].origin)
    if main.governance_registry.districts[origin_id].house_id != actor:
        var nearest := ""
        var distance := INF
        for district_id in main.governance_registry.districts:
            if main.governance_registry.districts[district_id].house_id != actor: continue
            var candidate: String = "district:" + district_id
            var length := node_point(candidate).distance_squared_to(unit_position(units[id]))
            if length < distance and not route(units[id].site_id, candidate, actor).is_empty():
                nearest = candidate; distance = length
        if nearest.is_empty(): return false
        units[id].origin = nearest
    if main.technology_orders.training(id): last_error = "調練完了まで帰郡できません。"; return false
    if units[id].site_id == units[id].origin and units[id].next_site.is_empty():
        units[id].orders.clear()
        _arrive(id)
        changed.emit(); queue_redraw()
        return true
    return order_for_house(actor, id, units[id].origin)

func on_day_advanced(_year: int, _month: int, _day: int) -> void:
    var stamp := Time.get_ticks_usec()
    main.technology_orders.advance()
    _profile_phase("technology", stamp)
    stamp = Time.get_ticks_usec()
    for id in units.keys():
        var unit: Dictionary = units[id]
        unit.supply_days -= 1
        if unit.supply_days < 0: unit.soldiers = maxi(0, int(unit.soldiers) - 20)
        if unit.soldiers == 0:
            units.erase(id)
            _invalidate_unit_membership()
            if selected_id == id: selected_id = ""
            continue
        if unit.next_site.is_empty() and _hostile_office(unit): continue
        if unit.next_site.is_empty() and _hostile_castle(unit) and may_capture_office(unit):
            _besiege(id)
            continue
    _profile_phase("supply_siege", stamp)
    stamp = Time.get_ticks_usec()
    _advance_stability()
    _profile_phase("stability", stamp)
    stamp = Time.get_ticks_usec()
    _advance_occupations()
    _profile_phase("occupations", stamp)
    stamp = Time.get_ticks_usec()
    automation.advance()
    _profile_phase("player_automation", stamp)
    stamp = Time.get_ticks_usec()
    changed.emit(); queue_redraw()
    _profile_phase("notifications", stamp)

func _profile_phase(label: String, stamp: int) -> void:
    if not main.cpu_controller.profile_enabled: return
    var jobs: Dictionary = main.cpu_controller.profile_jobs
    var key := "army_phase:" + label
    if not jobs.has(key): jobs[key] = []
    jobs[key].append(Time.get_ticks_usec() - stamp)

func _arrive(id: String) -> void:
    if not units.has(id): return
    var unit: Dictionary = units[id]
    if _hostile_office(unit) and may_capture_office(unit):
        unit.orders.clear()
        _occupy_office(id)
        return
    if _hostile_castle(unit) and may_capture_office(unit):
        unit.orders.clear()
        _besiege(id)
        return
    var automatic: Variant = unit.get("automatic")
    var automatic_outbound: bool = automatic is Dictionary and not automatic.returning
    if unit.site_id == unit.origin and unit.orders.is_empty() and not automatic_outbound:
        var district_id := district_id_for_node(unit.origin)
        var district: Dictionary = main.governance_registry.districts[district_id]
        district.sortie_troops = mini(main.district_actions.sortie_capacity(district), int(district.sortie_troops) + int(unit.soldiers))
        main.district_economy.house_resources[unit.house_id].provisions += ceili(unit.soldiers * maxf(0.0, float(unit.supply_days)) / 300.0)
        var stores: Dictionary = main.district_economy.house_resources[unit.house_id]
        for kind in ["horse", "gun"]:
            var amount := equipment_count(unit, kind)
            if amount > 0:
                var field: String = "horses" if kind == "horse" else "guns"
                stores[field] = int(stores.get(field, 0)) + amount
        units.erase(id)
        _invalidate_unit_membership()
        if selected_id == id: selected_id = ""
        main.district_info.refresh_if_open()
        return
    if unit.site_id.begins_with("district:") or Grid.valid(unit.site_id): return
    var site: Dictionary = main.governance_registry.sites[unit.site_id]
    if site.house_id == unit.house_id and unit.supply_days < 120:
        var need := ceili(unit.soldiers * (120 - int(unit.supply_days)) / 300.0)
        var resources: Dictionary = main.district_economy.house_resources[unit.house_id]
        if int(resources.provisions) >= need:
            resources.provisions -= need
            unit.supply_days = 120

func _hostile_castle(unit: Dictionary) -> bool:
    if unit.site_id.begins_with("district:") or Grid.valid(unit.site_id): return false
    var site: Dictionary = main.governance_registry.sites[unit.site_id]
    return "castle" in site.get("roles", []) and site.house_id != unit.house_id and GameSession.relation(unit.house_id, site.house_id) == "enemy" and main.diplomacy.truce_remaining(unit.house_id, site.house_id) == 0

func _hostile_office(unit: Dictionary) -> bool:
    var district_id := district_id_for_node(unit.site_id)
    if district_id.is_empty() or not main.governance_registry.districts.has(district_id): return false
    var owner: String = main.governance_registry.districts[district_id].house_id
    return owner != unit.house_id and GameSession.relation(unit.house_id, owner) == "enemy" and main.diplomacy.truce_remaining(unit.house_id, owner) == 0

func occupying_house(district_id: String) -> String:
    if occupations.has(district_id): return str(occupations[district_id].house_id)
    for unit in units.values():
        if unit.site_id == "district:" + district_id and unit.next_site.is_empty() and _hostile_office(unit) and may_capture_office(unit):
            return str(unit.house_id)
    return ""

func _occupy_office(id: String) -> void:
    # Start only; all formations are aggregated by the daily district pass.
    if not units.has(id): return
    var unit: Dictionary = units[id]
    if not _hostile_office(unit): return
    if not may_capture_office(unit): return
    var district_id := district_id_for_node(unit.site_id)
    var district: Dictionary = main.governance_registry.districts[district_id]
    main.diplomacy.on_hostile_attack(unit.house_id, district.house_id)
    if not occupations.has(district_id): occupations[district_id] = {"house_id":unit.house_id, "progress":0.0}

func may_capture_office(unit: Dictionary) -> bool:
    var automatic: Variant = unit.get("automatic")
    if not automatic is Dictionary: return true
    if automatic.mode != "occupy" or automatic.returning: return false
    var district_id := district_id_for_node(unit.site_id)
    if not district_id.is_empty(): return main.governance_registry.districts[district_id].house_id == automatic.house_id
    return main.governance_registry.sites.has(unit.site_id) and main.governance_registry.sites[unit.site_id].house_id == automatic.house_id

func _office_troops(district_id: String, house_id: String, for_control := false) -> Dictionary:
    var soldiers := 0
    var command := 0.0
    for unit in units.values():
        if for_control and not may_capture_office(unit): continue
        if unit.house_id != house_id or unit.site_id != "district:" + district_id or not unit.next_site.is_empty() or int(unit.soldiers) <= 0: continue
        soldiers += int(unit.soldiers)
        command += int(unit.soldiers) * (0.75 + score(unit.officers[0]) / 60.0)
    return {"soldiers":soldiers, "command":command / soldiers if soldiers > 0 else 0.0}

func _office_contested(district_id: String, house_id: String) -> bool:
    var point := node_point("district:" + district_id)
    for unit in units.values():
        if int(unit.soldiers) <= 0 or unit.house_id == house_id: continue
        if GameSession.relation(house_id, unit.house_id) != "enemy" or main.diplomacy.truce_remaining(house_id, unit.house_id) > 0: continue
        if unit_position(unit).distance_to(point) <= Grid.ROOT_3 * Grid.RADIUS * 1.01: return true
    return false

func office_enemy_present(district_id: String) -> bool:
    if not main.district_office_layer.records.has(district_id): return false
    var owner: String = main.governance_registry.districts[district_id].house_id
    var cell := Grid.cell_at(main.district_office_layer.office_point(district_id))
    for unit in units.values():
        if int(unit.soldiers) <= 0 or GameSession.relation(owner, unit.house_id) != "enemy": continue
        if main.diplomacy.truce_remaining(owner, unit.house_id) > 0: continue
        if Grid.cell_at(unit_position(unit)) == cell: return true
    return false

func loot_unavailable_reason(id: String) -> String:
    if not units.has(id) or units[id].house_id != GameSession.player_house: return "自家の部隊だけ略奪できます。"
    var unit: Dictionary = units[id]
    var district_id := district_id_for_node(unit.site_id)
    if district_id.is_empty() or not main.district_office_layer.records.has(district_id) or not unit.next_site.is_empty() or not unit.orders.is_empty(): return "郡奉行所に停止中の部隊だけ略奪できます。"
    var district: Dictionary = main.governance_registry.districts[district_id]
    if GameSession.relation(unit.house_id, district.house_id) != "enemy" or main.diplomacy.truce_remaining(unit.house_id, district.house_id) > 0: return "敵家の郡奉行所だけ略奪できます。"
    if _office_contested(district_id, unit.house_id): return "敵部隊が周辺にいる間は略奪できません。"
    var remaining := int(district.loot_available_day) - int(main.game_clock.elapsed_days)
    if remaining > 0: return "この郡は再び略奪できるまであと%d日です。" % remaining
    var amount := loot_yield(id)
    if int(amount.money) == 0 and int(amount.provisions) == 0: return "略奪できる金銭・兵糧がありません。"
    return ""

func loot_yield(id: String) -> Dictionary:
    var unit: Dictionary = units[id]
    var district: Dictionary = main.governance_registry.districts[district_id_for_node(unit.site_id)]
    var economy: Node = main.district_economy
    var victim: Dictionary = economy.house_resources[district.house_id]
    var scale := minf(1.0, float(unit.soldiers) / 1000.0)
    return {"money":mini(floori(float(victim.money)), maxi(1, roundi(economy.potential_income_for(district, "commerce") * scale))),
        "provisions":mini(int(victim.provisions), maxi(1, roundi(economy.potential_income_for(district, "agriculture") * scale / 12.0)))}

func loot_selected(id: String) -> String:
    last_error = ""
    if selected_id != id or main.army_panel.loot_context_id != id: last_error = "奉行所にいる部隊をクリックして選択してください。"; return ""
    last_error = loot_unavailable_reason(id)
    if not last_error.is_empty(): return ""
    var unit: Dictionary = units[id]
    var district_id := district_id_for_node(unit.site_id)
    var district: Dictionary = main.governance_registry.districts[district_id]
    var amount := loot_yield(id)
    var victim: Dictionary = main.district_economy.house_resources[district.house_id]
    var resources: Dictionary = main.district_economy.house_resources[unit.house_id]
    victim.money -= int(amount.money); victim.provisions -= int(amount.provisions)
    resources.money += int(amount.money); resources.provisions += int(amount.provisions)
    district.devastation = mini(100, int(district.devastation) + 10)
    district.security = maxi(0, int(district.security) - 10)
    district.loot_available_day = int(main.game_clock.elapsed_days) + 30
    changed.emit()
    return "略奪：金銭%d・兵糧%dを獲得。荒廃+10・治安-10。" % [int(amount.money), int(amount.provisions)]

func occupation_rate(district_id: String) -> float:
    if not occupations.has(district_id): return 0.0
    var house_id: String = occupations[district_id].house_id
    var troops := _office_troops(district_id, house_id, true)
    if int(troops.soldiers) == 0 or _office_contested(district_id, house_id): return 0.0
    var district: Dictionary = main.governance_registry.districts[district_id]
    var defense := int(district.defense) + int(main.district_buildings.defense_bonus(district_id))
    return minf(50.0, 20.0 * sqrt(float(troops.soldiers) / 1000.0) * float(troops.command) / (1.0 + maxi(0, defense - 1) * 0.05)) / main.technology_orders.defense_multiplier(district_id)

func _advance_occupations() -> void:
    var ids: Array = units.keys()
    ids.sort() # Simultaneous arrivals choose a reproducible claimant.
    for id in ids:
        var unit: Dictionary = units[id]
        if unit.next_site.is_empty() and _hostile_office(unit) and may_capture_office(unit): _occupy_office(id)
    for district_id in occupations.keys():
        var state: Dictionary = occupations[district_id]
        var owner: String = main.governance_registry.districts[district_id].house_id
        if owner == state.house_id or GameSession.relation(state.house_id, owner) != "enemy" or main.diplomacy.truce_remaining(state.house_id, owner) > 0:
            occupations.erase(district_id)
            continue
        var troops := _office_troops(district_id, state.house_id, true)
        if int(troops.soldiers) == 0:
            state.progress = maxf(0.0, float(state.progress) - 10.0)
            if float(state.progress) == 0.0: occupations.erase(district_id)
            continue
        state.progress = minf(100.0, float(state.progress) + occupation_rate(district_id))
        if float(state.progress) >= 100.0:
            occupations.erase(district_id)
            _capture_district(district_id, state.house_id)

func stability_rate(district_id: String) -> float:
    var district: Dictionary = main.governance_registry.districts[district_id]
    var troops := _office_troops(district_id, district.house_id)
    var stationed := int(troops.soldiers) >= 100
    if _office_contested(district_id, district.house_id): return 0.0 if stationed else -2.0
    var politics := 0
    if district.governor is Dictionary:
        politics = main.district_economy.politics_for(district.governor.get("officer_id"))
    return main.technology_orders.stability_multiplier(district_id) * (100.0 / 60.0) * (1.0 + (1.0 if stationed else 0.0) + clampf(float(politics) / 30.0, 0.0, 1.0))

func _advance_stability() -> void:
    for district_id in main.governance_registry.districts:
        var district: Dictionary = main.governance_registry.districts[district_id]
        if float(district.occupation_stability) >= 100.0: continue
        var value := clampf(float(district.occupation_stability) + stability_rate(district_id), 0.0, 100.0)
        district.occupation_stability = 100.0 if value >= 99.999999 else value

func occupation_summary(district_id: String) -> String:
    if not occupations.has(district_id): return ""
    var state: Dictionary = occupations[district_id]
    var house_name: String = str(main.governance_registry.houses[state.house_id].get("display_name", state.house_id))
    var text := "制圧率 %.0f%%（%s）" % [float(state.progress), house_name]
    if int(_office_troops(district_id, state.house_id, true).soldiers) == 0: return text + "・撤退中：毎日10低下"
    var rate := occupation_rate(district_id)
    if rate <= 0.0: return text + "・敵部隊接近で停止"
    return text + "・あと約%d日" % ceili((100.0 - float(state.progress)) / rate)

func occupation_display(district_id: String) -> Dictionary:
    # Read-only snapshot shared by the map badge and the selected army panel.
    if not occupations.has(district_id): return {}
    var state: Dictionary = occupations[district_id]
    var owner: String = main.governance_registry.districts[district_id].house_id
    if owner == state.house_id or GameSession.relation(state.house_id, owner) != "enemy" or main.diplomacy.truce_remaining(state.house_id, owner) > 0: return {}
    var troops := _office_troops(district_id, state.house_id, true)
    var count := 0
    for unit in units.values():
        if unit.house_id == state.house_id and unit.site_id == "district:" + district_id and unit.next_site.is_empty() and int(unit.soldiers) > 0 and may_capture_office(unit): count += 1
    var contested := _office_contested(district_id, state.house_id)
    var rate := occupation_rate(district_id)
    var title := "奉行所を制圧中"
    var badge := "制圧中"
    var reason := "日付が進むごとに制圧が進行します。"
    var estimate := "完了まで約%d日" % ceili((100.0 - float(state.progress)) / rate) if rate > 0.0 else "完了見込み：未定"
    var change := "毎日 +%.1fポイント" % rate
    if int(troops.soldiers) == 0:
        title = "撤退により制圧率低下中"; badge = "制圧率低下中"
        reason = "制圧部隊が不在です。奉行所に再配置すると再開します。"
        change = "毎日 −10ポイント"
    elif contested:
        title = "敵接近により制圧停止"; badge = "制圧停止"
        reason = "周辺の敵部隊を排除すると制圧が再開します。"
    if main.game_clock.paused:
        badge = "時間停止中"
        reason = "時間停止中です。時間を進めると日ごとの処理を再開します。\n" + reason
    return {"house_id":state.house_id, "progress":float(state.progress), "rate":rate,
        "count":count, "soldiers":int(troops.soldiers), "contested":contested,
        "title":title, "badge":badge, "reason":reason, "estimate":estimate, "change":change}

func unit_occupation_district(id: String) -> String:
    if not units.has(id): return ""
    var unit: Dictionary = units[id]
    if not unit.next_site.is_empty() or not may_capture_office(unit): return ""
    var district_id := district_id_for_node(unit.site_id)
    var info := occupation_display(district_id)
    return district_id if not info.is_empty() and info.house_id == unit.house_id else ""

func stability_summary(district_id: String) -> String:
    var district: Dictionary = main.governance_registry.districts[district_id]
    if office_enemy_present(district_id): return "敵部隊が奉行所に駐留：金銭・兵糧収入停止（統治安定度 %.0f%%）" % float(district.occupation_stability)
    if float(district.occupation_stability) >= 100.0: return "統治：安定"
    var text := "統治安定度 %.0f%%・収入50%%・徴兵不可" % float(district.occupation_stability)
    var rate := stability_rate(district_id)
    if rate <= 0.0: return text + ("・敵部隊接近で悪化" if rate < 0.0 else "・敵部隊接近で停止")
    return text + "・あと約%d日" % ceili((100.0 - float(district.occupation_stability)) / rate)

func _besiege(id: String) -> void:
    if not units.has(id): return
    var unit: Dictionary = units[id]
    var site_id: String = unit.site_id
    var site: Dictionary = main.governance_registry.sites[site_id]
    main.diplomacy.on_hostile_attack(unit.house_id, site.house_id)
    var defense: int = int(garrisons.get(site_id, 0))
    var district: Dictionary = main.governance_registry.districts.get(site.get("district_key", ""), {})
    var district_id: String = str(site.get("district_key", ""))
    var building_defense: int = main.district_buildings.defense_bonus(district_id)
    var fortification: float = 1.0 + float(int(district.get("defense", 1)) + building_defense) * 0.08
    fortification *= main.technology_orders.defense_multiplier(district_id) if district.get("house_id") == site.house_id else 1.0
    var command: float = (0.8 + score(unit.officers[0]) / 200.0) * main.technology_orders.combat_multiplier(unit)
    var defender_loss := mini(defense, maxi(10, roundi(float(unit.soldiers) * 0.12 * command / fortification)))
    var attacker_loss := mini(int(unit.soldiers), maxi(1, roundi(float(defense) * 0.06 * fortification / command)))
    garrisons[site_id] = maxi(0, defense - defender_loss)
    main.technology_orders.reduce_trained(id, int(unit.soldiers)-attacker_loss, int(unit.soldiers))
    unit.soldiers -= attacker_loss
    if unit.soldiers <= 0:
        units.erase(id)
        _invalidate_unit_membership()
        if selected_id == id: selected_id = ""
        return
    if int(garrisons[site_id]) == 0:
        _capture_site(site_id, unit.house_id)
        # Survivors hold the captured castle until the player gives another order.

func _capture_site(site_id: String, house_id: String) -> void:
    var site: Dictionary = main.governance_registry.sites[site_id]
    site.house_id = house_id
    var ruler: Variant = main.governance_registry.houses[house_id].ruler
    site.ruler = ruler.duplicate(true) if ruler is Dictionary else null
    site.governor = null
    _refresh_ownership()

func _capture_district(district_id: String, house_id: String) -> void:
    var stamp := Time.get_ticks_usec()
    if main.technology_orders.districts.has(district_id): main.technology_orders.finish(district_id)
    var district: Dictionary = main.governance_registry.districts[district_id]
    district.house_id = house_id
    var ruler: Variant = main.governance_registry.houses[house_id].ruler
    district.ruler = ruler.duplicate(true) if ruler is Dictionary else null
    district.governor = null
    main.retainer_management.district_governors.erase(district_id)
    district.agriculture_developer_id = null
    district.commerce_developer_id = null
    district.occupation_stability = 0.0
    district.sortie_troops = 0
    for site_id in district.get("site_ids", []):
        if not main.governance_registry.sites.has(site_id): continue
        var site: Dictionary = main.governance_registry.sites[site_id]
        site.house_id = house_id
        site.ruler = district.ruler.duplicate(true) if district.ruler is Dictionary else null
        site.governor = null
        if garrisons.has(site_id): garrisons[site_id] = 0
    main.district_buildings.reconcile_owners()
    _refresh_ownership(district_id)
    main.cpu_controller.record_profile("ownership:capture", stamp)

func _refresh_ownership(district_id := "") -> void:
    var stamp := Time.get_ticks_usec()
    route_obstacles.clear()
    if is_instance_valid(main.cpu_controller):
        main.cpu_controller.invalidate_routes()
        var signature := ""
        for district in main.governance_registry.districts.values(): signature += str(district.house_id) + ";"
        main.cpu_controller.topology_signature = signature
    automation.invalidate_routes()
    main.retainer_management.reconcile_officer_placements()
    main.governance_registry.recount_assignments()
    main.cpu_controller.record_profile("ownership:logical", stamp)
    stamp = Time.get_ticks_usec()
    if main.territory_borders != null:
        if not district_id.is_empty(): main.territory_borders.update_district_owner(district_id)
        main.kamon_layer.queue_redraw.call_deferred()
        main.district_office_layer.queue_redraw.call_deferred()
    main.district_info.refresh_if_open()
    main.cpu_controller.record_profile("ownership:visual_request", stamp)

func unit_position(unit: Dictionary) -> Vector2:
    var from := node_point(unit.site_id)
    if unit.next_site.is_empty(): return from
    return from.lerp(node_point(unit.next_site), float(unit.progress))

func icon_size() -> int:
    var height := DisplayServer.window_get_size().y
    return 256 if height >= 3600 else (192 if height >= 2700 else (128 if height >= 1800 else (96 if height >= 1200 else 64)))

func pixel_scale() -> float:
    return maxf(0.1, float(DisplayServer.window_get_size().x) / maxf(1.0, main.get_viewport_rect().size.x)) if main != null else 1.0

func icon_color_key(unit: Dictionary) -> String:
    if unit.house_id == GameSession.player_house: return "blue"
    match GameSession.relation(str(unit.house_id), GameSession.player_house):
        "ally": return "green"
        "enemy": return "red"
    return "neutral"

func facing_angle(unit: Dictionary) -> float:
    var from: Vector2 = main.world_to_screen(unit_position(unit))
    var to: Vector2 = main.world_to_screen(unit_position(unit) + Vector2.UP.rotated(float(unit.get("facing", 0.0))) * Grid.RADIUS)
    var direction := to - from
    return direction.angle() + PI / 2.0 if direction.length_squared() > 0.000001 else 0.0

func route_points_for(id: String) -> PackedVector2Array:
    var points := PackedVector2Array()
    if not units.has(id) or units[id].house_id != GameSession.player_house: return points
    var unit: Dictionary = units[id]
    points.append(main.elevation.project(unit_position(unit)))
    if not unit.next_site.is_empty(): points.append(main.elevation.project(node_point(unit.next_site)))
    var targets: Array = preview_nodes if preview_id == id and preview_nodes.size() > 1 else unit.orders
    for target in targets:
        var point: Vector2 = main.elevation.project(node_point(target))
        if not points[-1].is_equal_approx(point): points.append(point)
    return points

func set_route_preview(id: String, nodes: Array[String]) -> void:
    preview_id = id
    preview_nodes = nodes.duplicate()
    queue_redraw()

func clear_route_preview() -> void:
    preview_id = ""
    preview_nodes.clear()
    queue_redraw()

func pick(screen: Vector2) -> String:
    # When units share a tile, make the player's unit easiest to select.
    for id in units:
        if units[id].house_id != GameSession.player_house: continue
        if main.map_view != null and not main.map_view.marker_visible(unit_position(units[id]),id==selected_id,"army:"+str(id),true): continue
        var own_position: Vector2 = main.world_to_screen(unit_position(units[id]))
        if own_position.distance_to(screen) <= 18: return id
    for id in units:
        if main.map_view != null and not main.map_view.marker_visible(unit_position(units[id]),id==selected_id,"army:"+str(id),true): continue
        var p: Vector2 = main.world_to_screen(unit_position(units[id]))
        if p.distance_to(screen) <= 18: return id
    return ""

func _draw_arrow(tip: Vector2, direction: Vector2, size: float, color: Color) -> void:
    if direction.length_squared() < 0.000001: return
    var forward := direction.normalized()
    var side := forward.orthogonal()
    var back := tip - forward * size
    draw_colored_polygon(PackedVector2Array([tip, back + side * size * 0.56, back - side * size * 0.56]), color)

func _draw_route(points: PackedVector2Array, zoom: float, scale: float) -> void:
    if points.size() < 2: return
    var width := 4.0 / (zoom * scale)
    draw_polyline(points, Color("#102f55"), width + 2.0 / (zoom * scale), true)
    draw_polyline(points, ROUTE_BLUE, width, true)
    draw_circle(points[-1], 4.5 / (zoom * scale), ROUTE_BLUE)
    var spacing := 36.0 / (zoom * scale)
    var since_arrow := 0.0
    for i in range(1, points.size()):
        var segment := points[i] - points[i - 1]
        since_arrow += segment.length()
        if since_arrow >= spacing or i == points.size() - 1:
            _draw_arrow(points[i], segment, 11.0 / (zoom * scale), ROUTE_BLUE)
            since_arrow = 0.0

func _draw() -> void:
    if main != null and main.map_view != null and is_instance_valid(main.map_view.markers.army_markers): main.map_view.markers.army_markers.invalidate()
    if main == null: return
    var zoom: float = main.camera.zoom.x
    var scale := pixel_scale()
    for id in units:
        _draw_route(route_points_for(id), zoom, scale)
    if units.has(selected_id):
        var selected: Dictionary = units[selected_id]
        if zoom >= Grid.MIN_DRAW_ZOOM:
            var polygon := Grid.polygon(Grid.cell_at(unit_position(selected)))
            for i in polygon.size(): polygon[i] = main.elevation.project(polygon[i])
            draw_colored_polygon(polygon, Color(0.2,0.57,0.96,0.24))
    if main.map_view != null: return
    var side := icon_size()
    for id in units:
        var unit: Dictionary = units[id]
        var p: Vector2 = main.elevation.project(unit_position(unit))
        var icon: Texture2D = ARMY_ICONS[icon_color_key(unit)][side]
        draw_set_transform(p, facing_angle(unit), Vector2.ONE / (zoom * scale))
        draw_texture(icon, Vector2.ONE * (-side * 0.5))
        if id == selected_id: draw_arc(Vector2.ZERO,side * 0.27,0,TAU,32,Color.WHITE,2,true)
        draw_set_transform(Vector2.ZERO)


func rotate_unit(id: String, radians: float) -> bool:
    return rotate_unit_for_house(GameSession.player_house, id, radians)

func rotate_unit_for_house(actor: String, id: String, radians: float) -> bool:
    if not units.has(id) or actor.is_empty() or units[id].house_id != actor or not is_finite(radians): return false
    var unit: Dictionary = units[id]
    # Hold an unfinished leg without snapping to either tile center.
    unit.movement_hold = true
    unit.facing = wrapf(float(unit.get("facing", 0.0)) + radians, -PI, PI)
    changed.emit(); queue_redraw()
    return true

func bow_profile(unit: Dictionary, target: Vector2) -> Dictionary:
    return _bow_profile_offset(unit, target - unit_position(unit))

func _bow_profile_offset(unit: Dictionary, offset: Vector2) -> Dictionary:
    var alignment := Vector2.UP.rotated(float(unit.get("facing", 0.0))).dot(offset.normalized()) if not offset.is_zero_approx() else 1.0
    # Front 100%, flank 35%, rear 3%; each firing parameter deteriorates.
    var direction := lerpf(0.35, 1.0, alignment) if alignment >= 0.0 else lerpf(0.03, 0.35, alignment + 1.0)
    var moving: bool = not unit.next_site.is_empty() and not unit.get("movement_hold", false)
    return {"in_range":offset.length() <= BOW_RANGE + 0.000001,
        "accuracy":(0.25 if moving else 0.55) * direction,
        "reload":(0.45 if moving else 0.2) / sqrt(direction),
        "arrows":float(unit.soldiers) * (0.08 if moving else 0.2) * direction}

func _bow_step(game_days: float, positions: Dictionary = {}) -> void:
    var damage := {}
    var fired := false
    var engagements := melee_engagements(positions)
    # Positions are constant throughout this simultaneous volley. Reject distant
    # formations before diplomacy and firing-profile work, preserving target order.
    var bins := {}
    var ranks := {}
    var nearby := {}
    var bin_size := BOW_RANGE + BOW_HIT_RADIUS + 0.000001
    for id in units:
        if not positions.has(id): positions[id] = unit_position(units[id])
        # floor is required for negative coordinates at bucket boundaries.
        var cell := Vector2i(floori(positions[id].x / bin_size), floori(positions[id].y / bin_size))
        if not bins.has(cell): bins[cell] = []
        bins[cell].append(id)
        ranks[id] = ranks.size()
    # Resolve simultaneous volleys so dictionary order cannot prevent return fire.
    for id in units:
        var unit: Dictionary = units[id]
        unit.bow_reload = maxf(0.0, float(unit.get("bow_reload", 0.0)) - game_days)
        if engagements.has(id): continue
        if float(unit.bow_reload) > 0.000001: continue
        var source: Vector2 = positions[id]
        var cell := Vector2i(floori(source.x / bin_size), floori(source.y / bin_size))
        if not nearby.has(cell):
            var candidates: Array = []
            for x in range(cell.x - 1, cell.x + 2):
                for y in range(cell.y - 1, cell.y + 2):
                    candidates.append_array(bins.get(Vector2i(x, y), []))
            # Preserve original target tie-breaking and simultaneous hit order.
            candidates.sort_custom(func(a: String, b: String): return ranks[a] < ranks[b])
            nearby[cell] = candidates
        var target_id := ""
        var best := -1.0
        var profile := {}
        for other_id in nearby[cell]:
            var other: Dictionary = units[other_id]
            if other_id == id: continue
            if source.distance_squared_to(positions[other_id]) > (BOW_RANGE + 0.000001) * (BOW_RANGE + 0.000001): continue
            if not _enemy_armies(unit, other): continue
            var candidate := _bow_profile_offset(unit, positions[other_id] - source)
            if not candidate.in_range: continue
            var efficiency: float = candidate.accuracy * candidate.arrows / candidate.reload
            if efficiency > best:
                best = efficiency; target_id = other_id; profile = candidate
        if target_id.is_empty(): continue
        unit.bow_reload = profile.reload
        var volley := _bow_volley_hits(id, target_id, profile, positions, nearby[cell])
        for hit_id in volley:
            damage[hit_id] = float(damage.get(hit_id, 0.0)) + float(volley[hit_id])
        fired = true
    _apply_combat_damage(damage, "bow_damage")
    if fired:
        changed.emit(); queue_redraw()

func _enemy_armies(a: Dictionary, b: Dictionary) -> bool:
    return a.house_id != b.house_id and GameSession.relation(a.house_id, b.house_id) == "enemy" and main.diplomacy.truce_remaining(a.house_id, b.house_id) == 0

func unit_valor(unit: Dictionary) -> float:
    var officers: Array = unit.get("officers", [])
    if officers.is_empty(): return 15.0
    var total := 0.0
    for officer_id in officers:
        var value: Variant = main.officer_registry.ability(str(officer_id), "tactics")
        total += clampf(float(value), 1.0, 30.0) if value != null else 15.0
    return total / officers.size()

func melee_engagements(positions: Dictionary = {}) -> Dictionary:
    var tiles := {}
    var engagements := {}
    for id in units:
        var point: Vector2 = positions[id] if positions.has(id) else unit_position(units[id])
        var cell := Grid.cell_at(point)
        if not tiles.has(cell): tiles[cell] = []
        tiles[cell].append(id)
    for ids in tiles.values():
        for i in ids.size():
            for j in range(i + 1, ids.size()):
                var a: String = ids[i]
                var b: String = ids[j]
                if not _enemy_armies(units[a], units[b]): continue
                if not engagements.has(a): engagements[a] = []
                if not engagements.has(b): engagements[b] = []
                engagements[a].append(b)
                engagements[b].append(a)
    return engagements

func melee_power(unit: Dictionary, game_days: float) -> float:
    return float(unit.soldiers) * MELEE_LOSS_RATE * (0.5 + unit_valor(unit) / 30.0) * game_days * main.technology_orders.combat_multiplier(unit)

func _melee_step(game_days: float, positions: Dictionary = {}) -> void:
    var engagements := melee_engagements(positions)
    if engagements.is_empty(): return
    var damage := {}
    # Each formation splits its attack among enemies in the same tile.
    # All attacks use pre-combat troop counts and resolve simultaneously.
    for id in engagements:
        var targets: Array = engagements[id]
        var hits := melee_power(units[id], game_days) / targets.size()
        for target_id in targets:
            damage[target_id] = float(damage.get(target_id, 0.0)) + hits
    _apply_combat_damage(damage, "melee_damage")
    changed.emit(); queue_redraw()

func _apply_combat_damage(damage: Dictionary, fraction_key: String) -> void:
    for id in damage:
        var unit: Dictionary = units[id]
        var hits: float = float(unit.get(fraction_key, 0.0)) + float(damage[id])
        var survivors := maxi(0, int(unit.soldiers) - floori(hits))
        main.technology_orders.reduce_trained(id, survivors, int(unit.soldiers))
        unit.soldiers = survivors
        unit[fraction_key] = hits - floorf(hits)
        if unit.soldiers == 0:
            units.erase(id)
            _invalidate_unit_membership()
            if selected_id == id: selected_id = ""

func _bow_volley_hits(shooter_id: String, target_id: String, profile: Dictionary, positions: Dictionary = {}, candidates: Array = []) -> Dictionary:
    var hits := {}
    var source: Vector2 = positions[shooter_id] if positions.has(shooter_id) else unit_position(units[shooter_id])
    var target: Vector2 = positions[target_id] if positions.has(target_id) else unit_position(units[target_id])
    # No movement or damage is applied during a volley. Share these exact
    # offsets across all nine lanes, including friendly interception checks.
    var offsets := {}
    for other_id in (units.keys() if candidates.is_empty() else candidates):
        if other_id == shooter_id: continue
        var point: Vector2 = positions[other_id] if positions.has(other_id) else unit_position(units[other_id])
        # A circle farther than ray length plus its radius cannot intercept it.
        if source.distance_squared_to(point) > (BOW_RANGE + BOW_HIT_RADIUS + 0.000001) * (BOW_RANGE + BOW_HIT_RADIUS + 0.000001): continue
        offsets[other_id] = point - source
    var direction := (target - source).normalized()
    if direction.is_zero_approx(): direction = Vector2.UP.rotated(float(units[shooter_id].facing))
    var perpendicular := Vector2(-direction.y, direction.x)
    var spread: float = BOW_HIT_RADIUS * 0.9 * (1.0 - float(profile.accuracy))
    var lane_damage: float = profile.arrows * profile.accuracy * 0.05 / BOW_VOLLEY_LANES * main.technology_orders.combat_multiplier(units[shooter_id])
    # Fan the volley toward the enemy. Each lane strikes the first formation
    # it crosses, regardless of house or diplomacy; the firing unit is exempt.
    for lane in BOW_VOLLEY_LANES:
        var endpoint := target + perpendicular * spread * (2.0 * lane / (BOW_VOLLEY_LANES - 1) - 1.0)
        var ray := endpoint - source
        var length := minf(ray.length(), BOW_RANGE)
        var forward := ray.normalized() if not ray.is_zero_approx() else direction
        var nearest := INF
        var struck: Array[String] = []
        for other_id in offsets:
            var offset: Vector2 = offsets[other_id]
            var along := offset.dot(forward)
            var across_squared := maxf(0.0, offset.length_squared() - along * along)
            if across_squared > BOW_HIT_RADIUS * BOW_HIT_RADIUS: continue
            var half_chord := sqrt(BOW_HIT_RADIUS * BOW_HIT_RADIUS - across_squared)
            if along + half_chord < 0.0: continue
            var entry := maxf(0.0, along - half_chord)
            if entry > length: continue
            if entry < nearest - 0.000001:
                nearest = entry
                struck = [str(other_id)]
            elif absf(entry - nearest) <= 0.000001:
                struck.append(str(other_id))
        # Overlapping formations share hits without depending on insertion order.
        for hit_id in struck:
            hits[hit_id] = float(hits.get(hit_id, 0.0)) + lane_damage / struck.size()
    return hits
