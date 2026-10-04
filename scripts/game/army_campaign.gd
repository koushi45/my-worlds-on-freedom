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

var main: Node2D
var units: Dictionary = {}
var garrisons: Dictionary = {}
var office_defenses: Dictionary = {}
var occupations: Dictionary = {} # District progress survives army replacement and retreat.
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

func setup(owner: Node2D) -> void:
    main = owner
    for site_id in main.governance_registry.sites:
        var site: Dictionary = main.governance_registry.sites[site_id]
        if "castle" not in site.get("roles", []): continue
        var district: Dictionary = main.governance_registry.districts.get(site.get("district_key", ""), {})
        garrisons[site_id] = clampi(roundi(float(district.get("population", 20000)) * 0.025), 100, 3000)
    for district_id in main.governance_registry.districts:
        office_defenses[district_id] = office_defense_capacity(district_id)
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

func office_defense_capacity(district_id: String) -> int:
    var district: Dictionary = main.governance_registry.districts[district_id]
    var level: int = int(district.get("defense", 1)) + int(main.district_buildings.defense_bonus(district_id))
    return clampi(roundi(float(district.get("population", 20000)) * 0.0025) + maxi(0, level - 1) * 25, 50, 1500)

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
            if is_inf(leg_days):
                last_error = blocked_reason(Grid.cell_at(node_point(unit.next_site)))
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
    _melee_step(game_days)
    _bow_step(game_days)
    if moved: queue_redraw()

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
    if Grid.valid(node_id): return Grid.center(Grid.parse(node_id))
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
        for id in unit.officers: result.erase(id)
    result.sort_custom(func(a: String, b: String): return score(a) > score(b))
    return result

func score(officer_id: String) -> float:
    var value: Variant = main.officer_registry.ability(officer_id, "command")
    return float(value) if value != null else 50.0

func dispatch(district_id: String, officers: Array, percent: int, horses: bool, guns: bool) -> String:
    return dispatch_for_house(GameSession.player_house, district_id, officers, percent, horses, guns)

func dispatch_for_house(actor: String, district_id: String, officers: Array, percent: int, horses: bool, guns: bool) -> String:
    last_error = ""
    var origin := "district:" + district_id
    if not main.governance_registry.districts.has(district_id) or not graph.has(origin): last_error = "出陣できる郡を選んでください。"; return ""
    var district: Dictionary = main.governance_registry.districts[district_id]
    var house_id: String = district.house_id
    if actor.is_empty() or house_id != actor: last_error = "自家の郡からのみ出陣できます。"; return ""
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
        "orders":[], "officers":officers.duplicate(), "soldiers":soldiers, "supply_days":120, "horses":horses, "guns":guns,
        "facing":0.0, "movement_hold":false, "bow_reload":0.0, "bow_damage":0.0, "melee_damage":0.0}
    if actor == GameSession.player_house: selected_id = id
    changed.emit(); queue_redraw()
    return id

func route(start: String, target: String, actor := "") -> Array:
    if start == target: return []
    var start_cell := Grid.cell_at(node_point(start))
    var target_cell := Grid.cell_at(node_point(target))
    if not main.hex_tile_layer.can_enter(start_cell) or not main.hex_tile_layer.can_enter(target_cell): return []
    var obstacles: Dictionary = main.hex_tile_layer.impassable_cells
    if not actor.is_empty():
        if not route_obstacles.has(actor):
            var blocked := obstacles.duplicate()
            for district_id in main.governance_registry.districts:
                var owner: String = main.governance_registry.districts[district_id].house_id
                if owner == actor or GameSession.relation(actor, owner) in ["ally", "enemy"]: continue
                blocked[Grid.cell_at(node_point("district:" + district_id))] = true
            for site_id in main.governance_registry.sites:
                var owner: String = main.governance_registry.sites[site_id].house_id
                if owner == actor or GameSession.relation(actor, owner) in ["ally", "enemy"]: continue
                blocked[Grid.cell_at(node_point(site_id))] = true
            route_obstacles[actor] = blocked
        obstacles = route_obstacles[actor]
        # Planning may end at a neutral frontier, but must not cross other neutral offices.
        if obstacles.has(start_cell) or obstacles.has(target_cell):
            obstacles = obstacles.duplicate()
            if main.hex_tile_layer.can_enter(start_cell): obstacles.erase(start_cell)
            if main.hex_tile_layer.can_enter(target_cell): obstacles.erase(target_cell)
    var path := Grid.path(start_cell, target_cell)
    for node_id in path:
        if not main.hex_tile_layer.can_enter(Grid.parse(node_id)) or obstacles.has(Grid.parse(node_id)):
            path = Grid.path_avoiding(start_cell, target_cell, obstacles, main.hex_tile_layer.visible_cells)
            break
    if path.is_empty() and start_cell != target_cell: return []
    # Preserve the target site identity for siege, supply and return effects.
    if path.is_empty(): path.append(target)
    else: path[-1] = target
    return path

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
    return order_for_house(GameSession.player_house, id, target, append_waypoint)

func order_for_house(actor: String, id: String, target: String, append_waypoint := false) -> bool:
    last_error = ""
    if not units.has(id) or (not graph.has(target) and not Grid.valid(target)): last_error = "目標を指定できません。"; return false
    var unit: Dictionary = units[id]
    if actor.is_empty() or unit.house_id != actor: last_error = "自家の部隊にのみ命令できます。"; return false
    var target_cell := Grid.cell_at(node_point(target))
    if not main.hex_tile_layer.can_enter(target_cell): last_error = blocked_reason(target_cell); return false
    var start: String = unit.orders.back() if append_waypoint and not unit.orders.is_empty() else (unit.next_site if not unit.next_site.is_empty() else unit.site_id)
    var path := route(start, target, actor if actor != GameSession.player_house else "")
    if path.is_empty() and start != target: last_error = "移動先のタイルがありません。"; return false
    if not append_waypoint: unit.orders.clear()
    unit.orders.append_array(path)
    unit.movement_hold = false
    _start_next_leg(unit)
    changed.emit(); queue_redraw()
    return true

func cancel_movement(id: String) -> bool:
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
    return order_path_for_house(GameSession.player_house, id, drawn_nodes)

func order_path_for_house(actor: String, id: String, drawn_nodes: Array[String]) -> bool:
    last_error = ""
    if not units.has(id) or actor.is_empty() or units[id].house_id != actor:
        last_error = "自家の部隊にのみ命令できます。"
        return false
    var unit: Dictionary = units[id]
    var anchor: String = unit.next_site if not unit.next_site.is_empty() else unit.site_id
    var previous := Grid.cell_at(node_point(anchor))
    var steps: Array[String] = []
    for node_id in drawn_nodes:
        if not Grid.valid(node_id): last_error = "六角形の経路を指定してください。"; return false
        var cell := Grid.parse(node_id)
        if cell == previous: continue
        if Grid.distance(previous, cell) != 1: last_error = "経路は隣接する六角形を通してください。"; return false
        if not main.hex_tile_layer.can_enter(cell): last_error = blocked_reason(cell); return false
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
    if units[id].site_id == units[id].origin and units[id].next_site.is_empty():
        units[id].orders.clear()
        _arrive(id)
        changed.emit(); queue_redraw()
        return true
    return order_for_house(actor, id, units[id].origin)

func on_day_advanced(_year: int, _month: int, _day: int) -> void:
    for id in units.keys():
        var unit: Dictionary = units[id]
        unit.supply_days -= 1
        if unit.supply_days < 0: unit.soldiers = maxi(0, int(unit.soldiers) - 20)
        if unit.soldiers == 0:
            units.erase(id)
            if selected_id == id: selected_id = ""
            continue
        if unit.next_site.is_empty() and _hostile_office(unit): continue
        if unit.next_site.is_empty() and _hostile_castle(unit):
            _besiege(id)
            continue
    _advance_stability()
    _advance_occupations()
    changed.emit(); queue_redraw()

func _arrive(id: String) -> void:
    if not units.has(id): return
    var unit: Dictionary = units[id]
    if _hostile_office(unit):
        unit.orders.clear()
        return
    if _hostile_castle(unit):
        unit.orders.clear()
        _besiege(id)
        return
    if unit.site_id == unit.origin and unit.orders.is_empty():
        var district_id := district_id_for_node(unit.origin)
        var district: Dictionary = main.governance_registry.districts[district_id]
        district.sortie_troops = mini(main.district_actions.sortie_capacity(district), int(district.sortie_troops) + int(unit.soldiers))
        main.district_economy.house_resources[unit.house_id].provisions += ceili(unit.soldiers * maxi(0, int(unit.supply_days)) / 300.0)
        if unit.horses: main.district_economy.house_resources[unit.house_id].horses += ceili(unit.soldiers * 0.2)
        if unit.guns: main.district_economy.house_resources[unit.house_id].guns += ceili(unit.soldiers * 0.2)
        units.erase(id)
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
    return "castle" in site.get("roles", []) and site.house_id != unit.house_id and GameSession.relation(unit.house_id, site.house_id) != "ally" and main.diplomacy.truce_remaining(unit.house_id, site.house_id) == 0

func _hostile_office(unit: Dictionary) -> bool:
    var district_id := district_id_for_node(unit.site_id)
    if district_id.is_empty() or not main.governance_registry.districts.has(district_id): return false
    var owner: String = main.governance_registry.districts[district_id].house_id
    return owner != unit.house_id and GameSession.relation(unit.house_id, owner) != "ally" and main.diplomacy.truce_remaining(unit.house_id, owner) == 0

func occupying_house(district_id: String) -> String:
    if occupations.has(district_id): return str(occupations[district_id].house_id)
    for unit in units.values():
        if unit.site_id == "district:" + district_id and unit.next_site.is_empty() and _hostile_office(unit):
            return str(unit.house_id)
    return ""

func _occupy_office(id: String) -> void:
    # Start only; all formations are aggregated by the daily district pass.
    if not units.has(id): return
    var unit: Dictionary = units[id]
    if not _hostile_office(unit): return
    var district_id := district_id_for_node(unit.site_id)
    var district: Dictionary = main.governance_registry.districts[district_id]
    main.diplomacy.on_hostile_attack(unit.house_id, district.house_id)
    if not occupations.has(district_id): occupations[district_id] = {"house_id":unit.house_id, "progress":0.0}

func _office_troops(district_id: String, house_id: String) -> Dictionary:
    var soldiers := 0
    var command := 0.0
    for unit in units.values():
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

func occupation_rate(district_id: String) -> float:
    if not occupations.has(district_id): return 0.0
    var house_id: String = occupations[district_id].house_id
    var troops := _office_troops(district_id, house_id)
    if int(troops.soldiers) == 0 or _office_contested(district_id, house_id): return 0.0
    var district: Dictionary = main.governance_registry.districts[district_id]
    var defense := int(district.defense) + int(main.district_buildings.defense_bonus(district_id))
    return minf(50.0, 20.0 * sqrt(float(troops.soldiers) / 1000.0) * float(troops.command) / (1.0 + maxi(0, defense - 1) * 0.05))

func _advance_occupations() -> void:
    var ids: Array = units.keys()
    ids.sort() # Simultaneous arrivals choose a reproducible claimant.
    for id in ids:
        var unit: Dictionary = units[id]
        if unit.next_site.is_empty() and _hostile_office(unit): _occupy_office(id)
    for district_id in occupations.keys():
        var state: Dictionary = occupations[district_id]
        var owner: String = main.governance_registry.districts[district_id].house_id
        if owner == state.house_id or GameSession.relation(state.house_id, owner) != "enemy" or main.diplomacy.truce_remaining(state.house_id, owner) > 0:
            occupations.erase(district_id)
            continue
        var troops := _office_troops(district_id, state.house_id)
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
    return (100.0 / 60.0) * (1.0 + (1.0 if stationed else 0.0) + clampf(float(politics) / 30.0, 0.0, 1.0))

func _advance_stability() -> void:
    for district_id in main.governance_registry.districts:
        var district: Dictionary = main.governance_registry.districts[district_id]
        if float(district.occupation_stability) >= 100.0: continue
        var value := clampf(float(district.occupation_stability) + stability_rate(district_id), 0.0, 100.0)
        district.occupation_stability = 100.0 if value >= 99.999999 else value

func occupation_summary(district_id: String) -> String:
    if not occupations.has(district_id): return ""
    var state: Dictionary = occupations[district_id]
    var house_name: String = str(main.governance_registry.houses[state.house_id].get("name", state.house_id))
    var text := "制圧率 %.0f%%（%s）" % [float(state.progress), house_name]
    if int(_office_troops(district_id, state.house_id).soldiers) == 0: return text + "・撤退中：毎日10低下"
    var rate := occupation_rate(district_id)
    if rate <= 0.0: return text + "・敵部隊接近で停止"
    return text + "・あと約%d日" % ceili((100.0 - float(state.progress)) / rate)

func stability_summary(district_id: String) -> String:
    var district: Dictionary = main.governance_registry.districts[district_id]
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
    var command: float = 0.8 + score(unit.officers[0]) / 200.0
    var defender_loss := mini(defense, maxi(10, roundi(float(unit.soldiers) * 0.12 * command / fortification)))
    var attacker_loss := mini(int(unit.soldiers), maxi(1, roundi(float(defense) * 0.06 * fortification / command)))
    garrisons[site_id] = maxi(0, defense - defender_loss)
    unit.soldiers -= attacker_loss
    if unit.soldiers <= 0:
        units.erase(id)
        if selected_id == id: selected_id = ""
        return
    if int(garrisons[site_id]) == 0:
        _capture_site(site_id, unit.house_id)
        # Survivors hold the captured castle until the player gives another order.

func _capture_site(site_id: String, house_id: String) -> void:
    var site: Dictionary = main.governance_registry.sites[site_id]
    site.house_id = house_id
    site.ruler = main.governance_registry.houses[house_id].ruler.duplicate(true)
    site.governor = null
    _refresh_ownership()

func _capture_district(district_id: String, house_id: String) -> void:
    var district: Dictionary = main.governance_registry.districts[district_id]
    district.house_id = house_id
    district.ruler = main.governance_registry.houses[house_id].ruler.duplicate(true)
    district.governor = null
    district.occupation_stability = 0.0
    district.sortie_troops = 0
    office_defenses[district_id] = office_defense_capacity(district_id)
    for site_id in district.get("site_ids", []):
        if not main.governance_registry.sites.has(site_id): continue
        var site: Dictionary = main.governance_registry.sites[site_id]
        site.house_id = house_id
        site.ruler = district.ruler.duplicate(true)
        site.governor = null
        if garrisons.has(site_id): garrisons[site_id] = 0
    main.district_buildings.reconcile_owners()
    _refresh_ownership(district_id)

func _refresh_ownership(district_id := "") -> void:
    route_obstacles.clear()
    main.retainer_management.reconcile_officer_placements()
    main.governance_registry.recount_assignments()
    if main.territory_borders != null:
        if not district_id.is_empty(): main.territory_borders.update_district_owner(district_id)
        main.kamon_layer.queue_redraw.call_deferred()
        main.district_office_layer.queue_redraw.call_deferred()
    main.district_info.refresh_if_open()

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
    var offset := target - unit_position(unit)
    var alignment := Vector2.UP.rotated(float(unit.get("facing", 0.0))).dot(offset.normalized()) if not offset.is_zero_approx() else 1.0
    # Front 100%, flank 35%, rear 3%; each firing parameter deteriorates.
    var direction := lerpf(0.35, 1.0, alignment) if alignment >= 0.0 else lerpf(0.03, 0.35, alignment + 1.0)
    var moving: bool = not unit.next_site.is_empty() and not unit.get("movement_hold", false)
    return {"in_range":offset.length() <= BOW_RANGE + 0.000001,
        "accuracy":(0.25 if moving else 0.55) * direction,
        "reload":(0.45 if moving else 0.2) / sqrt(direction),
        "arrows":float(unit.soldiers) * (0.08 if moving else 0.2) * direction}

func _bow_step(game_days: float) -> void:
    var damage := {}
    var fired := false
    var engagements := melee_engagements()
    # Resolve simultaneous volleys so dictionary order cannot prevent return fire.
    for id in units:
        var unit: Dictionary = units[id]
        unit.bow_reload = maxf(0.0, float(unit.get("bow_reload", 0.0)) - game_days)
        if engagements.has(id): continue
        if float(unit.bow_reload) > 0.000001: continue
        var target_id := ""
        var best := -1.0
        var profile := {}
        for other_id in units:
            var other: Dictionary = units[other_id]
            if other_id == id or not _enemy_armies(unit, other): continue
            var candidate := bow_profile(unit, unit_position(other))
            if not candidate.in_range: continue
            var efficiency: float = candidate.accuracy * candidate.arrows / candidate.reload
            if efficiency > best:
                best = efficiency; target_id = other_id; profile = candidate
        if target_id.is_empty(): continue
        unit.bow_reload = profile.reload
        var volley := _bow_volley_hits(id, target_id, profile)
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

func melee_engagements() -> Dictionary:
    var tiles := {}
    var engagements := {}
    for id in units:
        var cell := Grid.cell_at(unit_position(units[id]))
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
    return float(unit.soldiers) * MELEE_LOSS_RATE * (0.5 + unit_valor(unit) / 30.0) * game_days

func _melee_step(game_days: float) -> void:
    var engagements := melee_engagements()
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
        unit.soldiers = maxi(0, int(unit.soldiers) - floori(hits))
        unit[fraction_key] = hits - floorf(hits)
        if unit.soldiers == 0:
            units.erase(id)
            if selected_id == id: selected_id = ""

func _bow_volley_hits(shooter_id: String, target_id: String, profile: Dictionary) -> Dictionary:
    var hits := {}
    var source := unit_position(units[shooter_id])
    var target := unit_position(units[target_id])
    var direction := (target - source).normalized()
    if direction.is_zero_approx(): direction = Vector2.UP.rotated(float(units[shooter_id].facing))
    var perpendicular := Vector2(-direction.y, direction.x)
    var spread: float = BOW_HIT_RADIUS * 0.9 * (1.0 - float(profile.accuracy))
    var lane_damage: float = profile.arrows * profile.accuracy * 0.05 / BOW_VOLLEY_LANES
    # Fan the volley toward the enemy. Each lane strikes the first formation
    # it crosses, regardless of house or diplomacy; the firing unit is exempt.
    for lane in BOW_VOLLEY_LANES:
        var endpoint := target + perpendicular * spread * (2.0 * lane / (BOW_VOLLEY_LANES - 1) - 1.0)
        var ray := endpoint - source
        var length := minf(ray.length(), BOW_RANGE)
        var forward := ray.normalized() if not ray.is_zero_approx() else direction
        var nearest := INF
        var struck: Array[String] = []
        for other_id in units:
            if other_id == shooter_id: continue
            var offset := unit_position(units[other_id]) - source
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
