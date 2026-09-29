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
const ROUTE_BLUE := Color("#3298ef")
signal changed

var main: Node2D
var units: Dictionary = {}
var garrisons: Dictionary = {}
var office_defenses: Dictionary = {}
var next_id := 1
var selected_id := ""
var graph: Dictionary = {}
var last_error := ""
var move_accumulator := 0.0
var preview_id := ""
var preview_nodes: Array[String] = []
var last_icon_size := 0
var last_pixel_scale := 0.0

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
		var starter_provisions := 0
		for district in main.governance_registry.districts.values():
			if district.house_id == GameSession.player_house:
				var possible: int = main.district_actions.sortie_available(district)
				if possible >= 100: starter_provisions += ceili(float(maxi(100, roundi(float(possible) * 0.25))) * 0.4)
		if main.district_economy.house_resources.has(GameSession.player_house):
			main.district_economy.house_resources[GameSession.player_house].provisions += starter_provisions
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
	if main == null or main.game_clock == null or main.game_clock.paused or not main.game_clock.is_processing():
		move_accumulator = 0.0
		return
	move_accumulator += delta
	while move_accumulator >= MOVE_STEP:
		move_accumulator -= MOVE_STEP
		_march_step(MOVE_STEP * float(main.game_clock.speed))

func _march_step(game_days: float) -> void:
	var moved := false
	for id in units.keys():
		if not units.has(id): continue
		var unit: Dictionary = units[id]
		if unit.next_site.is_empty(): _start_next_leg(unit)
		if unit.next_site.is_empty(): continue
		var remaining_days := game_days
		while units.has(id) and not unit.next_site.is_empty() and remaining_days > 0.0:
			var leg_days := travel_days_for_leg(unit.site_id, unit.next_site)
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
	if moved: queue_redraw()

func travel_days_for_leg(from_node: String, to_node: String) -> float:
	var from_cell := Grid.cell_at(node_point(from_node))
	var to_cell := Grid.cell_at(node_point(to_node))
	var connected_road: bool = main.developer_tools != null and main.developer_tools.network.connected(from_cell, to_cell)
	return Terrain.days_for(main.hex_tile_layer.terrain_for(to_cell), connected_road)

func _start_next_leg(unit: Dictionary) -> void:
	if unit.next_site.is_empty() and not unit.orders.is_empty():
		unit.next_site = unit.orders.pop_front()
		unit.progress = 0.0

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
	last_error = ""
	var origin := "district:" + district_id
	if not main.governance_registry.districts.has(district_id) or not graph.has(origin): last_error = "出陣できる郡を選んでください。"; return ""
	var district: Dictionary = main.governance_registry.districts[district_id]
	var house_id: String = district.house_id
	if house_id != GameSession.player_house: last_error = "自家の郡からのみ出陣できます。"; return ""
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
		"orders":[], "officers":officers.duplicate(), "soldiers":soldiers, "supply_days":120, "horses":horses, "guns":guns}
	selected_id = id
	changed.emit(); queue_redraw()
	return id

func route(start: String, target: String) -> Array:
	if start == target: return []
	var path := Grid.path(Grid.cell_at(node_point(start)), Grid.cell_at(node_point(target)))
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
	last_error = ""
	if not units.has(id) or (not graph.has(target) and not Grid.valid(target)): last_error = "目標を指定できません。"; return false
	var unit: Dictionary = units[id]
	if unit.house_id != GameSession.player_house: last_error = "自家の部隊にのみ命令できます。"; return false
	var start: String = unit.orders.back() if append_waypoint and not unit.orders.is_empty() else (unit.next_site if not unit.next_site.is_empty() else unit.site_id)
	var path := route(start, target)
	if path.is_empty() and start != target: last_error = "移動先のタイルがありません。"; return false
	if not append_waypoint: unit.orders.clear()
	unit.orders.append_array(path)
	_start_next_leg(unit)
	changed.emit(); queue_redraw()
	return true

func order_path(id: String, drawn_nodes: Array[String]) -> bool:
	last_error = ""
	if not units.has(id) or units[id].house_id != GameSession.player_house:
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
		steps.append(node_id)
		previous = cell
	if steps.is_empty(): last_error = "移動先のタイルがありません。"; return false
	steps[-1] = target_at(node_point(steps[-1]))
	unit.orders = steps
	_start_next_leg(unit)
	clear_route_preview()
	changed.emit(); queue_redraw()
	return true

func return_home(id: String) -> bool:
	if not units.has(id) or units[id].house_id != GameSession.player_house: return false
	if units[id].site_id == units[id].origin and units[id].next_site.is_empty():
		units[id].orders.clear()
		_arrive(id)
		changed.emit(); queue_redraw()
		return true
	return order(id, units[id].origin)

func on_day_advanced(_year: int, _month: int, _day: int) -> void:
	for id in units.keys():
		var unit: Dictionary = units[id]
		unit.supply_days -= 1
		if unit.supply_days < 0: unit.soldiers = maxi(0, int(unit.soldiers) - 20)
		if unit.soldiers == 0:
			units.erase(id)
			if selected_id == id: selected_id = ""
			continue
		if unit.next_site.is_empty() and _hostile_office(unit):
			_occupy_office(id)
			continue
		if unit.next_site.is_empty() and _hostile_castle(unit):
			_besiege(id)
			continue
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
		selected_id = ""
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
	for unit in units.values():
		if unit.site_id == "district:" + district_id and unit.next_site.is_empty() and _hostile_office(unit):
			return str(unit.house_id)
	return ""

func _occupy_office(id: String) -> void:
	if not units.has(id): return
	var unit: Dictionary = units[id]
	if not _hostile_office(unit): return
	var district_id := district_id_for_node(unit.site_id)
	var district: Dictionary = main.governance_registry.districts[district_id]
	if GameSession.relation(unit.house_id, district.house_id) == "neutral":
		main.diplomacy.on_hostile_attack(unit.house_id, district.house_id)
	var defense := int(office_defenses.get(district_id, 0))
	var fortification := 1.0 + float(int(district.get("defense", 1)) + main.district_buildings.defense_bonus(district_id)) * 0.08
	var command := 0.8 + score(unit.officers[0]) / 200.0
	var defender_loss := mini(defense, maxi(10, roundi(float(unit.soldiers) * 0.12 * command / fortification)))
	var attacker_loss := mini(int(unit.soldiers), maxi(1, roundi(float(defense) * 0.02 * fortification / command))) if defense > 0 else 0
	office_defenses[district_id] = maxi(0, defense - defender_loss)
	unit.soldiers -= attacker_loss
	if unit.soldiers <= 0:
		units.erase(id)
		if selected_id == id: selected_id = ""
		return
	if int(office_defenses[district_id]) == 0:
		_capture_district(district_id, unit.house_id)

func _besiege(id: String) -> void:
	if not units.has(id): return
	var unit: Dictionary = units[id]
	var site_id: String = unit.site_id
	var site: Dictionary = main.governance_registry.sites[site_id]
	if GameSession.relation(unit.house_id, site.house_id) == "neutral":
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
	for site_id in district.get("site_ids", []):
		if not main.governance_registry.sites.has(site_id): continue
		var site: Dictionary = main.governance_registry.sites[site_id]
		site.house_id = house_id
		site.ruler = district.ruler.duplicate(true)
		site.governor = null
		if garrisons.has(site_id): garrisons[site_id] = 0
	main.district_buildings.reconcile_owners()
	_refresh_ownership()

func _refresh_ownership() -> void:
	main.retainer_management.reconcile_officer_placements()
	main.governance_registry.recount_assignments()
	if main.territory_borders != null:
		main.territory_borders.rebuild.call_deferred()
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
	if unit.next_site.is_empty(): return 0.0
	var from: Vector2 = main.elevation.project(unit_position(unit))
	var to: Vector2 = main.elevation.project(node_point(unit.next_site))
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
		var own_position: Vector2 = get_global_transform_with_canvas() * main.elevation.project(unit_position(units[id]))
		if own_position.distance_to(screen) <= 18: return id
	for id in units:
		var p: Vector2 = get_global_transform_with_canvas() * main.elevation.project(unit_position(units[id]))
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
	var side := icon_size()
	for id in units:
		var unit: Dictionary = units[id]
		var p: Vector2 = main.elevation.project(unit_position(unit))
		var icon: Texture2D = ARMY_ICONS[icon_color_key(unit)][side]
		draw_set_transform(p, facing_angle(unit), Vector2.ONE / (zoom * scale))
		draw_texture(icon, Vector2.ONE * (-side * 0.5))
		if id == selected_id: draw_arc(Vector2.ZERO,side * 0.27,0,TAU,32,Color.WHITE,2,true)
		draw_set_transform(Vector2.ZERO)
