extends RefCounted
## Explicit player orders; terrain affects travel time, never battle estimates.
const Grid = preload("res://scripts/map/hex_grid.gd")
var army: Node
var searches: Dictionary = {}
var political_blocks: Dictionary = {}
var political_version := -1

func _init(campaign: Node) -> void: army = campaign

func invalidate_routes() -> void:
	searches.clear()
	political_blocks.clear()
	political_version = -1

func start(id: String, mode: String, target_house: String) -> bool:
	if not army.units.has(id) or army.units[id].house_id != GameSession.player_house or mode not in ["occupy", "battle"]:
		army.last_error = "自家の部隊を選択してください。"; return false
	if GameSession.relation(GameSession.player_house, target_house) != "enemy" or army.main.diplomacy.truce_remaining(GameSession.player_house, target_house) > 0:
		army.last_error = "停戦中ではない敵対家を選択してください。"; return false
	if army.main.technology_orders.training(id):
		army.last_error = "調練完了まで自動命令を出せません。"; return false
	var unit: Dictionary = army.units[id]
	unit.automatic = {"mode":mode, "house_id":target_house, "initial_soldiers":int(unit.soldiers), "returning":false, "target_unit":"", "status":"目標を選定中"}
	unit.orders.clear()
	unit.movement_hold = false
	command(id)
	army.changed.emit()
	return true

func stop(id: String) -> void:
	if not army.units.has(id): return
	army.units[id].automatic = null
	army.cancel_movement_for_house(GameSession.player_house, id)

func advance() -> void:
	for id in army.units.keys():
		if army.units[id].house_id == GameSession.player_house and army.units[id].get("automatic") is Dictionary: command(id)

func power(unit: Dictionary) -> float:
	return float(unit.soldiers) * (0.5 + army.unit_valor(unit) / 30.0)

func opposition(point: Vector2, actor: String) -> float:
	var strength := 0.0
	for other in army.units.values():
		if GameSession.relation(actor, other.house_id) != "enemy" or army.main.diplomacy.truce_remaining(actor, other.house_id) > 0: continue
		if army.unit_position(other).distance_to(point) <= Grid.ROOT_3 * Grid.RADIUS * 1.01: strength += power(other)
	return strength

func retreat(id: String, reason: String) -> void:
	var unit: Dictionary = army.units[id]
	if not unit.automatic.returning: unit.automatic.status = "帰還：" + reason
	unit.automatic.returning = true
	if not unit.next_site.is_empty() and (unit.next_site == unit.origin or (not unit.orders.is_empty() and unit.orders.back() == unit.origin)): return
	if not army.return_home_for_house(unit.house_id, id) and army.units.has(id): unit.automatic.status = "帰還経路なし：手動指示が必要"

func command(id: String) -> void:
	if not army.units.has(id): return
	var unit: Dictionary = army.units[id]
	var state: Dictionary = unit.automatic
	if state.returning: retreat(id, "命令継続"); return
	if GameSession.relation(unit.house_id, state.house_id) != "enemy" or army.main.diplomacy.truce_remaining(unit.house_id, state.house_id) > 0:
		retreat(id, "対象家との敵対が終了"); return
	var start_node: String = unit.next_site if not unit.next_site.is_empty() else unit.site_id
	if int(unit.soldiers) < int(state.initial_soldiers) * 0.4 or int(unit.supply_days) < 15:
		retreat(id, "兵力・兵糧不足"); return
	var home := fastest_route(start_node, unit.origin, unit.house_id, state.house_id, float(unit.supply_days))
	if home.get("pending", false): state.status = "帰還経路を確認中"; return
	if home.reachable and float(unit.supply_days) <= float(home.days) + 10.0:
		retreat(id, "帰還用の兵糧を確保"); return
	if opposition(army.unit_position(unit), unit.house_id) * 1.25 > power(unit):
		retreat(id, "周辺の敵戦力が優勢"); return
	var office: String = army.district_id_for_node(unit.site_id)
	if state.mode == "occupy" and not office.is_empty() and unit.next_site.is_empty():
		var record: Dictionary = army.main.governance_registry.districts[office]
		if record.house_id == state.house_id:
			var rate := minf(50.0, 20.0 * sqrt(float(unit.soldiers) / 1000.0) * (0.75 + army.score(unit.officers[0]) / 60.0) / (1.0 + maxi(0, int(record.defense) + army.main.district_buildings.defense_bonus(office) - 1) * 0.05))
			var progress: float = float(army.occupations.get(office, {}).get("progress", 0.0))
			if (100.0 - progress) / rate + (float(home.days) if home.reachable else 0.0) + 10.0 >= float(unit.supply_days): retreat(id, "制圧に必要な兵糧が不足"); return
			state.status = "奉行所を制圧中"; return
		if record.house_id == unit.house_id and float(record.occupation_stability) < 100.0:
			state.status = "占領後の統治を安定化中"; return
	var candidates: Array = []
	if state.mode == "occupy":
		for district_id in army.main.district_office_layer.records:
			if army.main.governance_registry.districts[district_id].house_id == state.house_id: candidates.append({"node":"district:" + district_id, "unit":""})
	else:
		for target_id in army.units:
			var enemy: Dictionary = army.units[target_id]
			if enemy.house_id != state.house_id or power(unit) < opposition(army.unit_position(enemy), unit.house_id) * 1.25: continue
			var target := Grid.key(Grid.cell_at(army.unit_position(enemy)))
			candidates.append({"node":target, "unit":target_id})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return Grid.distance(Grid.cell_at(army.node_point(start_node)), Grid.cell_at(army.node_point(a.node))) < Grid.distance(Grid.cell_at(army.node_point(start_node)), Grid.cell_at(army.node_point(b.node))))
	var best: Dictionary = {}
	var best_days := INF
	for candidate in candidates:
		if Grid.distance(Grid.cell_at(army.node_point(start_node)), Grid.cell_at(army.node_point(candidate.node))) > best_days: break
		var trip := fastest_route(start_node, candidate.node, unit.house_id, state.house_id, minf(float(unit.supply_days) - 10.0, best_days))
		if trip.get("pending", false): state.status = "最短経路を探索中"; return
		if not trip.reachable: continue
		var reserve := 25.0 if state.mode == "occupy" else 10.0
		if float(trip.days) * 2.0 + reserve >= float(unit.supply_days): continue
		if state.mode == "occupy" and opposition(army.node_point(candidate.node), unit.house_id) * 1.25 > power(unit): continue
		if float(trip.days) < best_days:
			best = candidate.duplicate(); best["trip"] = trip; best_days = float(trip.days)
	if best.is_empty(): retreat(id, "攻略可能な目標なし" if state.mode == "occupy" else "勝てる敵部隊なし"); return
	state.target_unit = best.unit
	state.status = "占領へ進軍" if state.mode == "occupy" else "勝てる敵部隊を追撃"
	var destination: String = unit.orders.back() if not unit.orders.is_empty() else (unit.next_site if not unit.next_site.is_empty() else unit.site_id)
	if destination != best.node:
		unit.orders = best.trip.path.duplicate()
		unit.movement_hold = false
		army._start_next_leg(unit)
	if state.mode == "battle" and army.units.has(best.unit):
		var offset: Vector2 = army.unit_position(army.units[best.unit]) - army.unit_position(unit)
		if not offset.is_zero_approx(): unit.facing = offset.angle() + PI / 2.0

func fastest_route(start: String, target: String, actor: String, enemy: String, maximum_days: float) -> Dictionary:
	var from_cell := Grid.cell_at(army.node_point(start))
	var to_cell := Grid.cell_at(army.node_point(target))
	if not army.main.hex_tile_layer.can_enter(from_cell) or not army.main.hex_tile_layer.can_enter(to_cell): return {"reachable":false, "days":INF, "path":[]}
	if from_cell == to_cell: return {"reachable":true, "days":0.0, "path":[]}
	var connections: Dictionary = army.main.cpu_controller.connections
	if connections.has(from_cell) and connections.has(to_cell) and connections[from_cell] != connections[to_cell]: return {"reachable":false, "days":INF, "path":[]}
	if Grid.distance(from_cell, to_cell) > maximum_days: return {"reachable":false, "days":INF, "path":[]}
	var version: int = army.main.cpu_controller.route_version
	if political_version != version:
		political_version = version
		political_blocks.clear()
		searches.clear()
	var key := start + "|" + target + "|" + actor + "|" + enemy
	if searches.has(key) and searches[key].has("result"): return searches[key].result
	var blocked: Dictionary = army.route_blocked(actor, from_cell, to_cell)
	if blocked.has(to_cell): return {"reachable":false, "days":INF, "path":[]}
	if not searches.has(key):
		if searches.size() > 128: searches.clear()
		var heap: Array = []
		Grid._heap_push(heap, [Grid.distance(from_cell, to_cell), 0, 0, from_cell])
		searches[key] = {"heap":heap, "cost":{from_cell:0.0}, "previous":{}, "closed":{}, "sequence":1}
	var search: Dictionary = searches[key]
	if search.has("result"): return search.result
	var processed := 0
	while not search.heap.is_empty() and processed < 1500:
		var current: Vector2i = Grid._heap_pop(search.heap)[3]
		if search.closed.has(current): continue
		processed += 1
		if current == to_cell:
			var path: Array = []
			while current != from_cell:
				path.push_front(Grid.key(current)); current = search.previous[current]
			path[-1] = target
			search.result = {"reachable":true, "days":float(search.cost[to_cell]), "path":path}
			return search.result
		search.closed[current] = true
		for delta in Grid.NEIGHBORS:
			var neighbor: Vector2i = current + delta
			if search.closed.has(neighbor) or blocked.has(neighbor) or not Grid.WORLD.has_point(Grid.center(neighbor)) or not army.main.hex_tile_layer.can_enter(neighbor): continue
			var cost: float = float(search.cost[current]) + army.route_edge_days(current, neighbor)
			if not search.cost.has(neighbor) or cost < float(search.cost[neighbor]):
				search.cost[neighbor] = cost; search.previous[neighbor] = current
				var estimate: float = cost + Grid.distance(neighbor, to_cell)
				if estimate > 120.0: continue
				Grid._heap_push(search.heap, [estimate, estimate - cost, search.sequence, neighbor]); search.sequence += 1
	if not search.heap.is_empty(): return {"reachable":false, "pending":true, "days":INF, "path":[]}
	search.result = {"reachable":false, "days":INF, "path":[]}
	return search.result
