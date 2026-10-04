extends Node
## Resumable daily jobs share frames with player input and use common game commands.
const Grid = preload("res://scripts/map/hex_grid.gd")
const STRATEGY_INTERVAL := 7
const WEAK_RATIO := 0.8
const ATTACK_ADVANTAGE := 1.25
const MAX_ALLIES := 2
const MAX_LOG := 300

var main: Node
var enabled := true
var work_queue: Array = []
var maximum_frame_usec := 0
const FRAME_BUDGET_USEC := 3000
var plans: Dictionary = {}
var missions: Dictionary = {}
var decisions: Array = []
var holdings: Dictionary = {}
var formations: Dictionary = {}
var powers: Dictionary = {}
var nearby: Dictionary = {}
var connections: Dictionary = {}
var route_cache: Dictionary = {}
var topology_signature := ""
var ownership_signature := ""
var district_links: Array = []
var route_budget_active := false
var route_work_usec := 0
var route_queries := 0
var planning_deferred := false
var alliance_index: Dictionary = {}
var enemy_index: Dictionary = {}
const ROUTE_BUDGET_USEC := 8000
const ROUTE_QUERIES_PER_DAY := 8

func setup(owner: Node) -> void:
	main = owner
	_build_connections()
	_build_frontiers()
	refresh_world()
	main.diplomacy.war_started.connect(_on_war_started)

func _build_connections() -> void:
	# Land components cheaply reject sea crossings before attempting pathfinding.
	connections.clear()
	var component := 0
	for cell in main.hex_tile_layer.visible_cells:
		if connections.has(cell) or not main.hex_tile_layer.can_enter(cell): continue
		var queue: Array = [cell]
		connections[cell] = component
		var index := 0
		while index < queue.size():
			var current: Vector2i = queue[index]
			index += 1
			for delta in Grid.NEIGHBORS:
				var adjacent: Vector2i = current + delta
				if connections.has(adjacent) or not main.hex_tile_layer.can_enter(adjacent): continue
				connections[adjacent] = component
				queue.append(adjacent)
		component += 1

func _build_frontiers() -> void:
	var ids: Array = main.governance_registry.districts.keys()
	var points := {}
	for id in ids: points[id] = main.army_campaign.node_point("district:" + id)
	for i in range(ids.size()):
		var a: String = ids[i]
		var cell_a := Grid.cell_at(points[a])
		if not connections.has(cell_a): continue
		for j in range(i + 1, ids.size()):
			var b: String = ids[j]
			var distance: float = points[a].distance_squared_to(points[b])
			if distance > 350.0 * 350.0: continue
			if connections.get(Grid.cell_at(points[b]), -1) != connections[cell_a]: continue
			district_links.append([a, b, distance])

func refresh_world() -> void:
	holdings.clear()
	formations.clear()
	powers.clear()
	var signature := ""
	for district_id in main.governance_registry.districts:
		var house: String = main.governance_registry.districts[district_id].house_id
		if not holdings.has(house): holdings[house] = []
		holdings[house].append(district_id)
		signature += house + ";"
	var ownership_changed := signature != ownership_signature
	ownership_signature = signature
	var topology_changed := signature != topology_signature
	if topology_changed:
		route_cache.clear()
		main.army_campaign.route_obstacles.clear()
		topology_signature = signature
	for unit in main.army_campaign.units.values():
		if not formations.has(unit.house_id): formations[unit.house_id] = []
		formations[unit.house_id].append(unit.id)
	alliance_index.clear()
	enemy_index.clear()
	for house in holdings:
		alliance_index[house] = []
		enemy_index[house] = []
	for key in GameSession.relations:
		var pair: PackedStringArray = str(key).split("|")
		if not holdings.has(pair[0]) or not holdings.has(pair[1]): continue
		var index: Dictionary = alliance_index if GameSession.relations[key] == "ally" else enemy_index
		if GameSession.relations[key] not in ["ally", "enemy"]: continue
		index[pair[0]].append(pair[1])
		index[pair[1]].append(pair[0])
	for house in holdings:
		powers[house] = estimate_power(house)
	if not ownership_changed and not nearby.is_empty(): return
	nearby.clear()
	for house in holdings:
		nearby[house] = {}
	# Retain the nearest connected frontier for each pair of houses.
	for link in district_links:
		var a: String = link[0]
		var b: String = link[1]
		var owner_a: String = main.governance_registry.districts[a].house_id
		var owner_b: String = main.governance_registry.districts[b].house_id
		if owner_a == owner_b: continue
		var distance: float = link[2]
		if distance < float(nearby[owner_a].get(owner_b, {}).get("distance", INF)):
			nearby[owner_a][owner_b] = {"origin":a, "target":b, "distance":distance}
			nearby[owner_b][owner_a] = {"origin":b, "target":a, "distance":distance}

func officers_for(house: String) -> Array:
	var result: Array = main.retainer_management.house_members.get(house, []).duplicate()
	var ruler: String = main.retainer_management.ruler_id(house)
	if not ruler.is_empty() and main.officer_registry.lookup.has(ruler) and ruler not in result: result.append(ruler)
	for unit in main.army_campaign.units.values():
		for officer in unit.officers: result.erase(officer)
	return result

func estimate_power(house: String) -> float:
	var result := 0.0
	for id in formations.get(house, []):
		var unit: Dictionary = main.army_campaign.units[id]
		result += float(unit.soldiers) * (0.8 + main.army_campaign.score(unit.officers[0]) / 100.0)
	var candidates := officers_for(house)
	if candidates.is_empty(): return result
	var supply := int(main.district_economy.house_resources.get(house, {}).get("provisions", 0))
	var reserves: Array = []
	for id in holdings.get(house, []): reserves.append(main.district_actions.sortie_available(main.governance_registry.districts[id]))
	reserves.sort()
	reserves.reverse()
	var commander := 0.0
	for officer in candidates: commander = maxf(commander, main.army_campaign.score(officer))
	for i in range(mini(reserves.size(), candidates.size())):
		var troops := mini(floori(float(reserves[i]) * 0.7), floori(supply / 0.4))
		if troops < 100: continue
		supply -= ceili(troops * 0.4)
		result += troops * (0.8 + commander / 100.0)
	return result

func plan_for(house: String) -> Dictionary:
	if not plans.has(house):
		plans[house] = {"objective":"develop", "target":"", "next_strategy":int(main.game_clock.elapsed_days), "last_admin":-1, "reason":"", "alliance_target":""}
	return plans[house]

func log_decision(house: String, action: String, target: String, reason: String) -> void:
	plan_for(house).reason = reason
	decisions.append({"day":int(main.game_clock.elapsed_days), "house":house, "action":action, "target":target, "reason":reason})
	if decisions.size() > MAX_LOG: decisions.pop_front()

func _on_war_started(attacker: String, defender: String) -> void:
	if defender != GameSession.player_house:
		var plan := plan_for(defender)
		plan.objective = "defend"
		plan.target = attacker
		plan.next_strategy = int(main.game_clock.elapsed_days)
		log_decision(defender, "defend", attacker, "宣戦を受けたため防衛と同盟援軍を優先")

func has_pending_work() -> bool:
	return not work_queue.is_empty()

func begin_day(_year: int, _month: int, _day: int) -> void:
	for subsystem in ["district_buildings", "district_economy", "retainer_management", "army_campaign", "district_actions", "diplomacy"]:
		work_queue.append({"house":"", "kind":"daily", "target":subsystem})
	work_queue.append({"house":"", "kind":"world", "target":""})

func prepare_cpu_day(year: int, month: int, day: int) -> void:
	if not enabled or GameSession.player_house.is_empty(): return
	route_budget_active = true
	route_work_usec = 0
	route_queries = 0
	refresh_world()
	for house in plans.keys():
		if not holdings.has(house): plans.erase(house)
	for id in missions.keys():
		if not main.army_campaign.units.has(id): missions.erase(id)
	var houses: Array = holdings.keys()
	houses.sort()
	var offset := int(main.game_clock.elapsed_days) % maxi(1, houses.size())
	var ordered := houses.slice(offset) + houses.slice(0, offset)
	for house in ordered:
		if house == GameSession.player_house: continue
		var fresh := not plans.has(house)
		var plan := plan_for(house)
		if fresh: plan.next_strategy = int(main.game_clock.elapsed_days) + houses.find(house) % STRATEGY_INTERVAL
		# Spread monthly administration across 28 dates, including February.
		if day >= 1 + houses.find(house) % 28 and int(plan.last_admin) != year * 12 + month:
			work_queue.append({"house":house, "kind":"officers", "target":""})
			for district_id in holdings[house]: work_queue.append({"house":house, "kind":"district", "target":district_id})
			work_queue.append({"house":house, "kind":"research", "target":""})
			plan.last_admin = year * 12 + month
		work_queue.append({"house":house, "kind":"strategy", "target":""})
		work_queue.append({"house":house, "kind":"army", "target":""})

func _process(_delta: float) -> void:
	if main == null or work_queue.is_empty() or main.game_clock.paused: return
	var started := Time.get_ticks_usec()
	while not work_queue.is_empty():
		var job_started := Time.get_ticks_usec()
		var job: Dictionary = work_queue.pop_front()
		var house: String = job.house
		# Player actions can change ownership while the queue is running.
		if job.kind == "daily":
			main[job.target].on_day_advanced(main.game_clock.year, main.game_clock.month, main.game_clock.day)
		elif job.kind == "world":
			prepare_cpu_day(main.game_clock.year, main.game_clock.month, main.game_clock.day)
		elif house != GameSession.player_house and main.district_economy.house_resources.has(house):
			match job.kind:
				"officers": manage_house_officers(house)
				"district": manage_district(house, job.target)
				"research": manage_research(house)
				"strategy":
					var plan := plan_for(house)
					if int(main.game_clock.elapsed_days) >= int(plan.next_strategy):
						planning_deferred = false
						choose_strategy(house)
						plan.next_strategy = int(main.game_clock.elapsed_days) + (1 if planning_deferred else STRATEGY_INTERVAL)
				"army": command_armies(house)
		if "--cpu-profile" in OS.get_cmdline_user_args() and Time.get_ticks_usec() - job_started > 8000:
			print("CPU_JOB ", job.kind, " ", job.house, " ", job.target, " ms=", (Time.get_ticks_usec() - job_started) / 1000.0)
		if Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC: break
	maximum_frame_usec = maxi(maximum_frame_usec, Time.get_ticks_usec() - started)
	if work_queue.is_empty(): route_budget_active = false

func route_info(house: String, start: String, target: String) -> Dictionary:
	var key := start + "|" + target
	if not route_cache.has(house): route_cache[house] = {}
	var cache: Dictionary = route_cache[house]
	if cache.has(key): return cache[key]
	if route_budget_active and (route_work_usec >= ROUTE_BUDGET_USEC or route_queries >= ROUTE_QUERIES_PER_DAY):
		planning_deferred = true
		return {"reachable":false, "days":INF, "deferred":true}
	var started := Time.get_ticks_usec()
	var army: Node2D = main.army_campaign
	var from_cell := Grid.cell_at(army.node_point(start))
	var to_cell := Grid.cell_at(army.node_point(target))
	var path: Array = []
	if connections.has(from_cell) and connections.get(to_cell, -1) == connections[from_cell]: path = army.route(start, target, house)
	var days := 0.0
	var previous := start
	for step in path:
		days += army.travel_days_for_leg(previous, step)
		previous = step
	var info := {"reachable":start == target or not path.is_empty(), "days":days}
	if cache.size() >= 512: cache.clear()
	cache[key] = info
	route_queries += 1
	route_work_usec += Time.get_ticks_usec() - started
	return info

func invalidate_routes(a := "", b := "") -> void:
	if a.is_empty():
		route_cache.clear()
		main.army_campaign.route_obstacles.clear()
	else:
		route_cache.erase(a)
		route_cache.erase(b)
		for pair in [[a, b], [b, a]]:
			if not alliance_index.has(pair[0]) or not enemy_index.has(pair[0]): continue
			alliance_index[pair[0]].erase(pair[1])
			enemy_index[pair[0]].erase(pair[1])
			var relation: String = GameSession.relation(pair[0], pair[1])
			if relation == "ally": alliance_index[pair[0]].append(pair[1])
			if relation == "enemy": enemy_index[pair[0]].append(pair[1])

func allies(house: String) -> Array:
	return alliance_index.get(house, [])

func coalition_power(target: String, attacker: String) -> float:
	var result := float(powers.get(target, 0.0))
	for ally in allies(target):
		if ally == attacker or main.diplomacy.truce_remaining(ally, attacker) > 0: continue
		if nearby.get(ally, {}).has(target) or nearby.get(ally, {}).has(attacker): result += float(powers.get(ally, 0.0))
	return result

func choose_strategy(house: String) -> void:
	var plan := plan_for(house)
	var enemy := ""
	var closest := INF
	for other in enemy_index.get(house, []):
		var distance := float(nearby.get(house, {}).get(other, {}).get("distance", INF))
		if enemy.is_empty() or distance < closest: enemy = other; closest = distance
	if not enemy.is_empty():
		plan.objective = "defend" if not main.diplomacy.defense_war(house, enemy).is_empty() else "fight"
		plan.target = enemy
		seek_alliance(house)
		if float(powers.get(house, 0.0)) < float(powers.get(enemy, 0.0)) * 0.6:
			if main.diplomacy.reason("peace", house, enemy).is_empty():
				main.diplomacy.act("peace", house, enemy)
				log_decision(house, "peace", enemy, "戦力不足により停戦")
			elif main.diplomacy.reason("envoy", house, enemy).is_empty() and main.diplomacy.opinion(enemy, house) < -20:
				main.diplomacy.act("envoy", house, enemy)
		return
	plan.objective = "develop"
	plan.target = ""
	seek_alliance(house)
	var own := float(powers.get(house, 0.0))
	if own <= 0: return
	var best := ""
	var candidates: Array = []
	for other in nearby.get(house, {}):
		if GameSession.relation(house, other) != "neutral" or main.diplomacy.truce_remaining(house, other) > 0: continue
		if float(powers.get(other, 0.0)) > own * WEAK_RATIO: continue
		var defense := coalition_power(other, house)
		if own < maxf(100.0, defense) * ATTACK_ADVANTAGE: continue
		var frontier: Dictionary = nearby[house][other]
		var value := own / maxf(100.0, defense) + float(main.governance_registry.districts[frontier.target].population) / 100000.0 - sqrt(float(frontier.distance)) / 350.0
		candidates.append({"house":other, "value":value})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.value > b.value)
	for candidate in candidates.slice(0, 3):
		if not attack_frontier(house, candidate.house).is_empty(): best = candidate.house; break
	if best.is_empty(): return
	var frontier := attack_frontier(house, best)
	prepare_commander(house, frontier.origin)
	if not can_dispatch(house, frontier.origin):
		log_decision(house, "prepare", best, "兵・武将・120日分の腰兵糧を準備")
		return
	if main.diplomacy.act("war", house, best) == OK:
		plan.objective = "invade"
		plan.target = best
		log_decision(house, "war", best, "自軍戦力 %.0f 対 防衛同盟込み %.0f" % [own, coalition_power(best, house)])
	else: log_decision(house, "wait", best, main.diplomacy.last_message)

func attack_frontier(house: String, other: String) -> Dictionary:
	var sources: Array = holdings.get(house, []).duplicate()
	sources.sort_custom(func(a: String, b: String): return main.district_actions.sortie_available(main.governance_registry.districts[a]) > main.district_actions.sortie_available(main.governance_registry.districts[b]))
	var best: Dictionary = {}
	var days := INF
	for source in sources.slice(0, 3):
		if dispatch_percent(house, source) == 0: continue
		var start: String = "district:" + source
		var targets: Array = holdings.get(other, []).duplicate()
		targets.sort_custom(func(a: String, b: String): return main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point("district:" + a)) < main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point("district:" + b)))
		for target in targets.slice(0, 2):
			if Grid.distance(Grid.cell_at(main.army_campaign.node_point(start)), Grid.cell_at(main.army_campaign.node_point("district:" + target))) * 2 + 25 >= 120: continue
			var trip := route_info(house, start, "district:" + target)
			if trip.reachable and trip.days * 2 + 25 < 120 and trip.days < days:
				days = trip.days
				best = {"origin":source, "target":target, "days":days}
				return best
	return best

func seek_alliance(house: String) -> void:
	var own := float(powers.get(house, 0.0))
	var threatened := false
	for other in nearby.get(house, {}):
		if GameSession.relation(house, other) != "ally" and float(powers.get(other, 0.0)) > maxf(1.0, own) * ATTACK_ADVANTAGE: threatened = true
	if not threatened or allies(house).size() >= MAX_ALLIES: return
	var best := ""
	var candidates: Array = []
	for other in nearby.get(house, {}):
		if GameSession.relation(house, other) != "neutral" or float(powers.get(other, 0.0)) <= own: continue
		if main.diplomacy.truce_remaining(house, other) > 0: continue
		var frontier: Dictionary = nearby[house][other]
		var score: float = float(powers.get(other, 0.0)) / maxf(100.0, own) + main.diplomacy.opinion(other, house) / 20.0 - sqrt(float(frontier.distance)) / 350.0
		candidates.append({"house":other, "value":score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.value > b.value)
	for candidate in candidates.slice(0, 3):
		var frontier: Dictionary = nearby[house][candidate.house]
		if route_info(house, "district:" + frontier.origin, "district:" + frontier.target).reachable: best = candidate.house; break
	if best.is_empty(): return
	plan_for(house).alliance_target = best
	if main.diplomacy.reason("ally", house, best).is_empty():
		main.diplomacy.act("ally", house, best)
		log_decision(house, "ally", best, "強い家との防衛同盟を成立")
		return
	if main.diplomacy.reason("envoy", house, best).is_empty():
		main.diplomacy.act("envoy", house, best)
		log_decision(house, "envoy", best, "強い家へ使節を派遣して同盟を準備")
	if budget(house) >= main.diplomacy.GIFT_COST and main.diplomacy.reason("gift", house, best).is_empty():
		main.diplomacy.act("gift", house, best)
		log_decision(house, "gift", best, "同盟成立のため友好度を改善")

func budget(house: String) -> float:
	return maxf(0.0, float(main.district_economy.house_resources[house].money) - main.retainer_management.monthly_stipend(house) * 2.0)

func prepare_commander(house: String, district_id: String) -> void:
	if not main.army_campaign.available_officers(district_id).is_empty(): return
	var candidates := officers_for(house)
	candidates.sort_custom(func(a: String, b: String): return main.army_campaign.score(a) > main.army_campaign.score(b))
	if not candidates.is_empty(): main.retainer_management.place_officer(house, candidates[0], district_id)

func dispatch_percent(house: String, district_id: String) -> int:
	var record: Dictionary = main.governance_registry.districts[district_id]
	var available: int = main.district_actions.sortie_available(record)
	var supply: int = main.district_economy.house_resources[house].provisions
	# Leave at least 30% of the district's capacity as a home reserve.
	var limit := maxi(0, available - ceili(main.district_actions.sortie_capacity(record) * 0.3))
	for percent in [50, 25]:
		var troops := floori(available * percent / 100.0)
		if troops >= 100 and troops <= limit and ceili(troops * 0.4) <= supply: return percent
	return 0

func can_dispatch(house: String, district_id: String) -> bool:
	return not main.army_campaign.available_officers(district_id).is_empty() and dispatch_percent(house, district_id) > 0

func command_armies(house: String) -> void:
	var army: Node2D = main.army_campaign
	var plan := plan_for(house)
	var enemy: String = plan.target
	if enemy.is_empty() or GameSession.relation(house, enemy) != "enemy":
		enemy = ""
		for other in enemy_index.get(house, []):
			if GameSession.relation(house, other) == "enemy": enemy = other; break
	if enemy.is_empty() and formations.get(house, []).is_empty(): return
	var objectives: Array = []
	# Actual invaders take priority over a planned offensive, including allied land.
	for unit in army.units.values():
		if GameSession.relation(house, unit.house_id) != "enemy": continue
		for friend in [house] + allies(house):
			var threatened := false
			for district_id in holdings.get(friend, []):
				if army.unit_position(unit).distance_to(army.node_point("district:" + district_id)) <= Grid.RADIUS * 5:
					threatened = true; break
			if threatened:
				objectives.append({"target":Grid.key(Grid.cell_at(army.unit_position(unit))), "priority":0})
				break
	if not enemy.is_empty():
		for district_id in holdings.get(enemy, []): objectives.append({"target":"district:" + district_id, "priority":1})
	for id in formations.get(house, []).duplicate():
		if not army.units.has(id): continue
		var unit: Dictionary = army.units[id]
		var start: String = unit.next_site if not unit.next_site.is_empty() else unit.site_id
		var mission: Dictionary = missions.get(id, {"target":"", "initial_soldiers":int(unit.soldiers), "returning":false})
		missions[id] = mission
		if unit.next_site.is_empty() and unit.orders.is_empty():
			for opponent in army.units.values():
				if GameSession.relation(house, opponent.house_id) != "enemy": continue
				var offset: Vector2 = army.unit_position(opponent) - army.unit_position(unit)
				if offset.length() > army.BOW_RANGE or offset.is_zero_approx(): continue
				army.rotate_unit_for_house(house, id, wrapf(offset.angle() + PI / 2.0 - float(unit.facing), -PI, PI))
				break
		var home := {"reachable":false, "days":0.0}
		if int(unit.supply_days) < 60 or int(main.game_clock.elapsed_days) % 7 == 0: home = route_info(house, start, unit.origin)
		if mission.returning or int(unit.soldiers) < int(mission.initial_soldiers) * 0.4 or (home.reachable and int(unit.supply_days) <= ceili(home.days) + 10) or objectives.is_empty():
			mission.returning = true
			if unit.orders.is_empty() or unit.orders.back() != unit.origin:
				army.return_home_for_house(house, id)
			continue
		if not unit.next_site.is_empty() or not unit.orders.is_empty():
			var current_target: String = mission.target
			var district_id: String = current_target.trim_prefix("district:") if current_target.begins_with("district:") else ""
			if objectives[0].priority > 0 and (district_id.is_empty() or GameSession.relation(house, main.governance_registry.districts[district_id].house_id) == "enemy"): continue
		var target := choose_objective(house, start, objectives, int(unit.supply_days))
		if target.is_empty(): continue
		var destination: String = unit.orders.back() if not unit.orders.is_empty() else (unit.next_site if not unit.next_site.is_empty() else unit.site_id)
		if destination != target and army.order_for_house(house, id, target):
			mission.target = target
			log_decision(house, "march", target, "防衛・援軍・攻略の目標へ進軍")
	if objectives.is_empty(): return
	var cap := clampi(holdings.get(house, []).size(), 2, 12)
	if formations.get(house, []).size() >= cap: return
	var sources: Array = holdings.get(house, []).duplicate()
	sources.sort_custom(func(a: String, b: String): return main.district_actions.sortie_available(main.governance_registry.districts[a]) > main.district_actions.sortie_available(main.governance_registry.districts[b]))
	for district_id in sources:
		if dispatch_percent(house, district_id) == 0 or officers_for(house).is_empty(): continue
		var origin: String = "district:" + district_id
		var target := choose_objective(house, origin, objectives, 120)
		if target.is_empty(): continue
		prepare_commander(house, district_id)
		if not can_dispatch(house, district_id): continue
		var candidates: Array = army.available_officers(district_id)
		var selected: Array = candidates.slice(0, mini(3, candidates.size()))
		var percent := dispatch_percent(house, district_id)
		var troops := floori(main.district_actions.sortie_available(main.governance_registry.districts[district_id]) * percent / 100.0)
		var resources: Dictionary = main.district_economy.house_resources[house]
		var equipment := ceili(troops * 0.2)
		var id: String = army.dispatch_for_house(house, district_id, selected, percent, int(resources.get("horses", 0)) >= equipment, int(resources.get("guns", 0)) >= equipment)
		if id.is_empty(): continue
		missions[id] = {"target":target, "initial_soldiers":troops, "returning":false}
		army.order_for_house(house, id, target)
		log_decision(house, "dispatch", target, "%d人を出陣、守備兵と腰兵糧を確保" % troops)
		# One departure per house per day bounds work and avoids spending stores twice.
		break

func choose_objective(house: String, start: String, objectives: Array, supply_days: int) -> String:
	var candidates := objectives.duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		var av: float = float(a.priority) * 100000000.0 + main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point(a.target))
		var bv: float = float(b.priority) * 100000000.0 + main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point(b.target))
		return av < bv)
	for objective in candidates.slice(0, 3):
		if Grid.distance(Grid.cell_at(main.army_campaign.node_point(start)), Grid.cell_at(main.army_campaign.node_point(objective.target))) * 2 + 25 >= supply_days: continue
		var trip := route_info(house, start, objective.target)
		if trip.reachable and float(trip.days) * 2 + 25 < supply_days: return objective.target
	return ""

func manage_house(house: String) -> void:
	manage_house_officers(house)
	for district_id in holdings.get(house, []): manage_district(house, district_id)
	manage_research(house)

func manage_house_officers(house: String) -> void:
	var management: Node = main.retainer_management
	var candidates := officers_for(house)
	if candidates.is_empty(): return
	candidates.sort_custom(func(a: String, b: String): return main.district_economy.politics_for(a) > main.district_economy.politics_for(b))
	for role in ["家老", "軍師", "所司代"]:
		var incumbent := ""
		for officer in management.house_members.get(house, []):
			if management.role_of(house, officer) == role: incumbent = officer; break
		if not incumbent.is_empty(): continue
		var ability := "politics" if role == "家老" else ("command" if role == "軍師" else "strategy")
		var best := ""
		var score := -1.0
		for officer in candidates:
			if officer not in management.house_members.get(house, []) or management.role_of(house, officer) != "直臣": continue
			var value: Variant = main.officer_registry.ability(officer, ability)
			if value != null and float(value) > score: best = officer; score = float(value)
		if not best.is_empty() and budget(house) > management.monthly_stipend(house) + 5.0: management.assign_role(house, best, role)
	for officer in management.house_members.get(house, []):
		if not management.is_disloyal(house, officer): continue
		var state: Dictionary = management.loyalty_state[officer]
		var wage := mini(100, int(state.base_wage_tenths) + 1)
		if budget(house) > 5.0: management.set_base_stipend(house, officer, wage / 10.0)

func manage_district(house: String, district_id: String) -> void:
	var management: Node = main.retainer_management
	var record_owner: Dictionary = main.governance_registry.districts.get(district_id, {})
	if record_owner.get("house_id", "") != house: return
	var candidates := officers_for(house)
	if candidates.is_empty(): return
	candidates.sort_custom(func(a: String, b: String): return main.district_economy.politics_for(a) > main.district_economy.politics_for(b))
	var administrator: String = candidates[0]
	var war: bool = not enemy_index.get(house, []).is_empty()
	var resources: Dictionary = main.district_economy.house_resources[house]
	var province: String = record_owner.province
	if management._can_govern(house, administrator) and not management.province_governors.has(house + "|" + province):
		management.appoint_province_governor(house, administrator, province)
	var record: Dictionary = main.governance_registry.districts[district_id]
	main.district_economy.assign_developer(district_id, "agriculture", administrator)
	main.district_economy.assign_developer(district_id, "commerce", administrator)
	if management._can_govern(house, administrator) and not management.district_governors.has(district_id): management.appoint_district_governor(house, administrator, district_id)
	if int(record.devastation) > 0 and budget(house) >= main.district_actions.repair_cost(record): main.district_actions.repair(district_id, house)
	var construction: Variant = main.district_buildings.state[district_id].construction
	if construction != null and budget(house) < 1 and float(resources.money) < management.monthly_stipend(house): main.district_buildings.cancel_construction(district_id, house)
	var food_need: bool = int(resources.provisions) < main.district_actions.sortie_capacity(record) * 0.4
	var choices: Array = ["irrigation", "farm_estate", "market", "workshop", "office"] if food_need else ["market", "workshop", "irrigation", "office", "temple"]
	if war: choices = ["fort", "barracks"] + choices
	var buildings: Node = main.district_buildings
	if war and construction == null and "fort" not in buildings.state[district_id].built and "temple" in buildings.state[district_id].built and buildings.slots_used(district_id) >= buildings.slot_capacity(record) and budget(house) >= buildings.cost_for(district_id, "fort"):
		buildings.demolish(district_id, "temple", house)
	for building in choices:
		if main.district_buildings.reason_for(district_id, building, house).is_empty() and budget(house) >= main.district_buildings.cost_for(district_id, building):
			main.district_buildings.start_construction(district_id, building, house, main.game_clock.year, main.game_clock.month, main.game_clock.day)
			break
	if war and int(record.infrastructure) < 3 and budget(house) >= main.district_actions.upgrade_cost(record): main.district_actions.upgrade(district_id, house)

func manage_research(house: String) -> void:
	var resources: Dictionary = main.district_economy.house_resources.get(house, {})
	if resources.is_empty(): return
	var branches: Array = ["agriculture", "governance"] if int(resources.provisions) < 100 else ["governance", "agriculture"]
	for branch in branches:
		var technology: String = main.technology_tree.next_technology(house, branch)
		if not technology.is_empty() and main.technology_tree.research(house, branch, technology) == OK:
			log_decision(house, "research", technology, "不足を改善する研究を取得")
			break

func save_state() -> Dictionary:
	return {"plans":plans.duplicate(true), "missions":missions.duplicate(true), "decisions":decisions.duplicate(true), "work_queue":work_queue.duplicate(true)}

func restore_state(state: Dictionary) -> void:
	plans = state.plans.duplicate(true)
	missions = state.missions.duplicate(true)
	decisions = state.decisions.duplicate(true)
	work_queue = state.work_queue.duplicate(true)
	route_budget_active = not work_queue.is_empty()
	route_work_usec = 0
	route_queries = 0
	for plan in plans.values():
		plan.next_strategy = int(plan.next_strategy)
		plan.last_admin = int(plan.last_admin)
	for mission in missions.values(): mission.initial_soldiers = int(mission.initial_soldiers)
	for decision in decisions: decision.day = int(decision.day)
	route_cache.clear()
	main.army_campaign.route_obstacles.clear()
