extends Node
## Resumable daily jobs share frames with player input and use common game commands.
const Grid = preload("res://scripts/map/hex_grid.gd")
const STRATEGY_INTERVAL := 7
const OFFENSIVE_GRACE_DAYS := 365
const WEAK_RATIO := 0.8
const ATTACK_ADVANTAGE := 1.25
const MAX_ALLIES := 2
const MAX_LOG := 300

var main: Node
var enabled := true
var work_queue: Array = []
var maximum_frame_usec := 0
const FRAME_BUDGET_USEC := 3000
const MAX_FRAME_BUDGET_USEC := 20000
const CPU_SECONDS_FRACTION := 0.35
const CATCHUP_SECONDS_FRACTION := 0.60
const CATCHUP_BACKLOG_DAYS := 0.5
var plans: Dictionary = {}
var missions: Dictionary = {}
var decisions: Array = []
var holdings: Dictionary = {}
var formations: Dictionary = {}
var powers: Dictionary = {}
var power_days: Dictionary = {}
var nearby: Dictionary = {}
var connections: Dictionary = {}
var route_cache: Dictionary = {}
var topology_signature := ""
var ownership_signature := ""
var district_links: Array = []
var route_budget_active := false
var planning_deferred := false
var alliance_index: Dictionary = {}
var enemy_index: Dictionary = {}
var route_version := 0
var route_requests: Array = []
var active_routes: Array = []
var retired_routes: Array = []
var route_land_snapshot: Dictionary = {}
var route_roads_snapshot: Dictionary = {}
var route_exclusions_snapshot: Dictionary = {}
var snapshot_version := -1
var road_snapshot_dirty := true
const MAX_ROUTE_WORKERS := 8
var route_worker_limit := 4
var route_results: Dictionary = {}
var route_cache_bytes := 0
const ROUTE_CACHE_BYTES := 8 * 1024 * 1024
const ROUTE_CACHE_ENTRIES := 2048
const ROUTE_QUEUE_LIMIT := 64
var deployed_officers: Dictionary = {}
var army_regions: Dictionary = {}
var office_regions: Dictionary = {}
var threatened_houses: Dictionary = {}
var unit_index_dirty := true
var profile_enabled := false
var profile_jobs: Dictionary = {}
var profile_frames: Array = []
var profile_routes: Dictionary = {}
var frontier_cache: Dictionary = {}
var current_job: Dictionary = {}
var queued_jobs: Dictionary = {}
var queue_dirty := true
var queue_heap: Array = []
var queue_slots: Dictionary = {}
var queue_sequence := 0
var queue_day := -1
var profile_counters: Dictionary = {}
var cpu_budget_fraction := CPU_SECONDS_FRACTION
var diplomacy_signature := ""
var membership_signature: Array = []
var indexed_membership_revision := -1
var unit_positions_dirty := true
var unit_cells: Dictionary = {}
var unit_positions: Dictionary = {}

func setup(owner: Node) -> void:
	main = owner
	_build_connections()
	_build_frontiers()
	_build_office_regions()
	refresh_world()
	main.diplomacy.war_started.connect(_on_war_started)
	main.army_campaign.changed.connect(func(): unit_index_dirty = true; unit_positions_dirty = true)
	profile_enabled = "--cpu-profile" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cpu-budget="): cpu_budget_fraction = clampf(float(arg.get_slice("=", 1)), 0.1, 0.5)
		if arg.begins_with("--route-workers="): route_worker_limit = clampi(int(arg.get_slice("=", 1)), 1, MAX_ROUTE_WORKERS)

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

func _build_office_regions() -> void:
	office_regions.clear()
	for id in main.governance_registry.districts:
		var point: Vector2 = main.army_campaign.node_point("district:" + id)
		var region := Vector2i(point / 64.0)
		if not office_regions.has(region): office_regions[region] = []
		office_regions[region].append({"id":id, "point":point})

func refresh_world(update_powers := true) -> void:
	var stamp := Time.get_ticks_usec()
	var signature := ""
	for district_id in main.governance_registry.districts:
		var house: String = main.governance_registry.districts[district_id].house_id
		signature += house + ";"
	var ownership_changed := signature != ownership_signature
	ownership_signature = signature
	var topology_changed := signature != topology_signature
	if topology_changed:
		invalidate_routes()
		topology_signature = signature
	if ownership_changed or holdings.is_empty():
		holdings.clear()
		for district_id in main.governance_registry.districts:
			var house: String = main.governance_registry.districts[district_id].house_id
			if not holdings.has(house): holdings[house] = []
			holdings[house].append(district_id)
		_count_profile("ownership_rebuilds")
	var relation_signature := str(GameSession.relations)
	if ownership_changed or relation_signature != diplomacy_signature:
		diplomacy_signature = relation_signature
		alliance_index.clear()
		enemy_index.clear()
		for house in holdings:
			alliance_index[house] = []
			enemy_index[house] = []
		for key in GameSession.relations:
			var pair: PackedStringArray = str(key).split("|")
			if not holdings.has(pair[0]) or not holdings.has(pair[1]): continue
			var relation: String = GameSession.relations[key]
			if relation not in ["ally", "enemy"]: continue
			var index: Dictionary = alliance_index if relation == "ally" else enemy_index
			index[pair[0]].append(pair[1])
			index[pair[1]].append(pair[0])
		unit_positions_dirty = true
		_count_profile("diplomacy_rebuilds")
	if ownership_changed: unit_positions_dirty = true
	# Also catches direct catalog/fixture changes without rebuilding unchanged membership.
	unit_index_dirty = true
	_refresh_unit_index()
	if update_powers:
		powers.clear()
		power_days.clear()
		for house in holdings: power_for(house)
	record_profile("index:world", stamp)
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
	_refresh_unit_index()
	var result: Array = main.retainer_management.house_members.get(house, []).duplicate()
	var ruler: String = main.retainer_management.ruler_id(house)
	if not ruler.is_empty() and main.officer_registry.lookup.has(ruler) and ruler not in result: result.append(ruler)
	for i in range(result.size() - 1, -1, -1):
		if deployed_officers.has(result[i]): result.remove_at(i)
	return result

func _refresh_unit_index() -> void:
	var stamp := Time.get_ticks_usec()
	if unit_index_dirty or indexed_membership_revision != main.army_campaign.membership_revision:
		indexed_membership_revision = main.army_campaign.membership_revision
		unit_index_dirty = false
		var signature: Array = []
		for unit in main.army_campaign.units.values():
			signature.append([unit.id, unit.house_id, main.army_campaign.officer_pool(unit).duplicate()])
		if signature != membership_signature:
			membership_signature = signature
			formations.clear()
			deployed_officers.clear()
			for unit in main.army_campaign.units.values():
				if not formations.has(unit.house_id): formations[unit.house_id] = []
				formations[unit.house_id].append(unit.id)
				for officer in main.army_campaign.officer_pool(unit): deployed_officers[officer] = true
			powers.clear()
			power_days.clear()
			unit_positions_dirty = true
			_count_profile("membership_rebuilds")
		record_profile("index:membership_check", stamp)
	if not unit_positions_dirty: return
	unit_positions_dirty = false
	for id in unit_cells.keys():
		if main.army_campaign.units.has(id): continue
		army_regions[unit_cells[id]].erase(id)
		if army_regions[unit_cells[id]].is_empty(): army_regions.erase(unit_cells[id])
		unit_cells.erase(id)
		unit_positions.erase(id)
	threatened_houses.clear()
	for unit in main.army_campaign.units.values():
		var position: Vector2 = main.army_campaign.unit_position(unit)
		unit_positions[unit.id] = position
		var cell := Vector2i(position / 64.0)
		if not unit_cells.has(unit.id) or unit_cells[unit.id] != cell:
			if unit_cells.has(unit.id):
				var old: Vector2i = unit_cells[unit.id]
				army_regions[old].erase(unit.id)
				if army_regions[old].is_empty(): army_regions.erase(old)
			if not army_regions.has(cell): army_regions[cell] = []
			army_regions[cell].append(unit.id)
			unit_cells[unit.id] = cell
			_count_profile("region_updates")
		for x in range(-1, 2):
			for y in range(-1, 2):
				for office in office_regions.get(cell + Vector2i(x, y), []):
					if office.point.distance_squared_to(position) > Grid.RADIUS * Grid.RADIUS * 25: continue
					var owner: String = main.governance_registry.districts[office.id].house_id
					for friend in [owner] + allies(owner):
						if GameSession.relation(friend, unit.house_id) == "enemy": threatened_houses[friend] = unit.house_id
	record_profile("index:units", stamp)
	_count_profile("threat_refreshes")

func nearby_units(point: Vector2) -> Array:
	_refresh_unit_index()
	var region := Vector2i(point / 64.0)
	var result: Array = []
	for x in range(-1, 2):
		for y in range(-1, 2): result.append_array(army_regions.get(region + Vector2i(x, y), []))
	return result

func power_for(house: String) -> float:
	var today := int(main.game_clock.elapsed_days)
	if int(power_days.get(house, -1)) != today:
		powers[house] = estimate_power(house)
		power_days[house] = today
	return float(powers.get(house, 0.0))

func estimate_power(house: String) -> float:
	_refresh_unit_index()
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
		plans[house] = {"objective":"develop", "target":"", "next_strategy":int(main.game_clock.elapsed_days), "last_admin":-1, "reason":"", "alliance_target":"", "last_dispatch":-1, "operation":{}, "cursors":{}}
	return plans[house]

func log_decision(house: String, action: String, target: String, reason: String) -> void:
	plan_for(house).reason = reason
	decisions.append({"day":int(main.game_clock.elapsed_days), "house":house, "action":action, "target":target, "reason":reason})
	var evaluation: Dictionary = plan_for(house).get("evaluation", {})
	if evaluation.get("target", "") == target and evaluation.get("action", "") in [action, "invade" if action == "war" else action]:
		decisions.back()["evaluation"] = evaluation.duplicate(true)
	if decisions.size() > MAX_LOG: decisions.pop_front()

func _on_war_started(attacker: String, defender: String) -> void:
	var war_id: String = main.diplomacy.defense_war(defender, attacker)
	var defenders: Array = main.diplomacy.wars.get(war_id, {}).get("defenders", [defender])
	for house in defenders:
		if house == GameSession.player_house: continue
		var plan := plan_for(house)
		plan.objective = "defend"
		plan.target = attacker
		plan.next_strategy = int(main.game_clock.elapsed_days)
		log_decision(house, "defend", attacker, "宣戦を受けたため防衛と同盟援軍を優先")

func has_pending_work() -> bool:
	return not work_queue.is_empty()

func pending_wait_reason() -> String:
	for job in work_queue:
		if job.kind in ["daily", "world", "power", "schedule"]: return "daily_rules"
	for job in work_queue:
		if int(job.get("priority", 2)) == 0: return "urgent_ai"
		if int(main.game_clock.elapsed_days) - int(job.get("day", main.game_clock.elapsed_days)) >= 3: return "ai_deadline"
	for request in active_routes + route_requests:
		var age := int(main.game_clock.elapsed_days) - int(request.day)
		if request.urgent and age >= 1: return "urgent_search"
		if age >= 3: return "search_deadline"
	return ""

func has_pending_daily_work() -> bool:
	return not pending_wait_reason().is_empty()

func job_key(house: String, kind: String, target: String) -> String:
	return house + "|" + kind + "|" + target

func queue_job(house: String, kind: String, target := "", priority := 2) -> void:
	if work_queue.is_empty():
		queued_jobs.clear()
		queue_slots.clear()
		queue_heap.clear()
	var key := job_key(house, kind, target)
	if queued_jobs.has(key):
		var existing: Dictionary = queued_jobs[key]
		if priority < int(existing.priority):
			existing.priority = priority
			_push_queue_entry(key, existing)
		return
	var job := {"house":house, "kind":kind, "target":target, "day":int(main.game_clock.elapsed_days), "priority":priority, "sequence":queue_sequence}
	queue_sequence += 1
	queue_slots[key] = work_queue.size()
	work_queue.append(job)
	queued_jobs[key] = job
	_push_queue_entry(key, job)
	_count_profile("jobs_registered")
	if profile_enabled: profile_counters["maximum_queue"] = maxi(int(profile_counters.get("maximum_queue", 0)), work_queue.size())

func _job_rank(job: Dictionary) -> int:
	var priority := int(job.priority)
	if int(main.game_clock.elapsed_days) - int(job.day) >= 3 and priority >= 0: return 0
	return priority

func _push_queue_entry(key: String, job: Dictionary) -> void:
	Grid._heap_push(queue_heap, [_job_rank(job), int(job.sequence), 0, key])

func _index_queue() -> void:
	queue_dirty = true
	queued_jobs.clear()
	queue_slots.clear()
	queue_heap.clear()
	for index in range(work_queue.size()):
		var job: Dictionary = work_queue[index]
		if not job.has("sequence"):
			job["sequence"] = queue_sequence
			queue_sequence += 1
		queue_sequence = maxi(queue_sequence, int(job.sequence) + 1)
		var key := job_key(job.house, job.kind, job.target)
		queued_jobs[key] = job
		queue_slots[key] = index

func begin_day(_year: int, _month: int, _day: int) -> void:
	var mandatory: Array = []
	for subsystem in ["district_buildings", "district_economy", "house_prestige", "retainer_management", "army_campaign", "district_actions", "diplomacy"]:
		mandatory.append({"house":"", "kind":"daily", "target":subsystem, "day":int(main.game_clock.elapsed_days), "priority":-3})
	mandatory.append({"house":"", "kind":"world", "target":"", "day":int(main.game_clock.elapsed_days), "priority":-2})
	work_queue = mandatory + work_queue
	_count_profile("jobs_registered", mandatory.size())
	if profile_enabled: profile_counters["maximum_queue"] = maxi(int(profile_counters.get("maximum_queue", 0)), work_queue.size())
	_index_queue()
	route_budget_active = true
	frontier_cache.clear()

func prepare_cpu_day(year: int, month: int, day: int) -> void:
	if not enabled or GameSession.player_house.is_empty(): return
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
		if day >= 1 + houses.find(house) % 28 and int(plan.last_admin) != year * 12 + month:
			queue_job(house, "officers")
			for district_id in holdings[house]: queue_job(house, "district", district_id)
			queue_job(house, "research")
			plan.last_admin = year * 12 + month
		var war: bool = not enemy_index.get(house, []).is_empty()
		if threatened_houses.has(house): plan.next_strategy = int(main.game_clock.elapsed_days)
		if int(main.game_clock.elapsed_days) >= int(plan.next_strategy): queue_job(house, "strategy", "", 0 if threatened_houses.has(house) else (1 if war else 2))
		for id in formations.get(house, []):
			var unit: Dictionary = main.army_campaign.units[id]
			var urgent := threatened_houses.has(house) or int(unit.supply_days) < 60 or int(unit.soldiers) < int(missions.get(id, {}).get("initial_soldiers", unit.soldiers)) * 0.4
			var origin_id: String = main.army_campaign.district_id_for_node(unit.origin)
			urgent = urgent or main.governance_registry.districts.get(origin_id, {}).get("house_id", "") != house
			queue_job(house, "unit", id, 0 if urgent else 1)
		if war: queue_job(house, "army", "", 0 if threatened_houses.has(house) else 1)

func _next_job_index() -> int:
	var stamp := Time.get_ticks_usec()
	if queue_slots.size() != work_queue.size(): _index_queue()
	if queue_dirty or queue_day != int(main.game_clock.elapsed_days) or queue_heap.size() > work_queue.size() * 2 + 64:
		queue_dirty = false
		queue_day = int(main.game_clock.elapsed_days)
		queue_heap.clear()
		for job in work_queue: _push_queue_entry(job_key(job.house, job.kind, job.target), job)
	while not queue_heap.is_empty():
		var entry: Array = queue_heap[0]
		var key: String = entry[3]
		if not queued_jobs.has(key) or int(queued_jobs[key].sequence) != int(entry[1]) or _job_rank(queued_jobs[key]) != int(entry[0]):
			Grid._heap_pop(queue_heap)
			continue
		record_profile("scheduler:select", stamp)
		return int(queue_slots[key])
	return -1

func _take_job(index: int) -> Dictionary:
	var job: Dictionary = work_queue[index]
	var key := job_key(job.house, job.kind, job.target)
	Grid._heap_pop(queue_heap)
	var last: Dictionary = work_queue.back()
	work_queue[index] = last
	queue_slots[job_key(last.house, last.kind, last.target)] = index
	work_queue.pop_back()
	queue_slots.erase(key)
	queued_jobs.erase(key)
	return job

func _process(_delta: float) -> void:
	if main == null or main.game_clock.paused: return
	# Equal thinking time per real second at 30/60 FPS, with a bounded input latency.
	# Spend available time on transient mandatory/urgent congestion, then return
	# to the regular share. Never enlarge the calendar's bounded backlog.
	var fraction := cpu_budget_fraction
	if main.game_clock.backlog_days >= CATCHUP_BACKLOG_DAYS:
		fraction = maxf(fraction, CATCHUP_SECONDS_FRACTION)
		_count_profile("catchup_budget_frames")
	var frame_budget := FRAME_BUDGET_USEC if _delta <= 0.0 else clampi(roundi(_delta * fraction * 1000000.0), 1500, MAX_FRAME_BUDGET_USEC)
	var started := Time.get_ticks_usec()
	if not _rules_pending(): _process_routes(started, 800)
	while not work_queue.is_empty():
		var index := _next_job_index()
		if index < 0: break
		var job: Dictionary = _take_job(index)
		_count_profile("jobs_processed")
		current_job = job
		var job_started := Time.get_ticks_usec()
		var house: String = job.house
		if job.kind == "daily":
			main[job.target].on_day_advanced(main.game_clock.year, main.game_clock.month, main.game_clock.day)
		elif job.kind == "world":
			refresh_world(false)
			queue_job("", "schedule", "", -1)
		elif job.kind == "power": powers[house] = estimate_power(house)
		elif job.kind == "schedule": prepare_cpu_day(main.game_clock.year, main.game_clock.month, main.game_clock.day)
		elif enabled and house != GameSession.player_house and main.district_economy.house_resources.has(house) and holdings.has(house):
			match job.kind:
				"officers": manage_house_officers(house)
				"district": manage_district(house, job.target)
				"research": manage_research(house)
				"strategy":
					var plan := plan_for(house)
					planning_deferred = false
					choose_strategy(house)
					plan.next_strategy = int(main.game_clock.elapsed_days) + (7 if planning_deferred else (3 if not enemy_index.get(house, []).is_empty() else STRATEGY_INTERVAL))
				"army":
					planning_deferred = false
					command_armies(house, "", true)
				"unit":
					planning_deferred = false
					command_armies(house, job.target, false)
		if profile_enabled:
			var label: String = "daily:" + job.target if job.kind == "daily" else job.kind
			if not profile_jobs.has(label): profile_jobs[label] = []
			profile_jobs[label].append(Time.get_ticks_usec() - job_started)
			profile_routes["maximum_wait_days"] = maxi(int(profile_routes.get("maximum_wait_days", 0)), int(main.game_clock.elapsed_days) - int(job.get("day", main.game_clock.elapsed_days)))
		if Time.get_ticks_usec() - started >= frame_budget: break
	current_job = {}
	if Time.get_ticks_usec() - started < frame_budget: _process_routes(started, frame_budget)
	var duration := Time.get_ticks_usec() - started
	maximum_frame_usec = maxi(maximum_frame_usec, duration)
	if profile_enabled: profile_frames.append(duration)

func route_info(house: String, start: String, target: String, urgent := false) -> Dictionary:
	_count_route("requests")
	var request_priority := 0 if urgent else (1 if current_job.get("kind", "") in ["army", "unit"] else 2)
	var key := house + "|" + start + "|" + target
	if not route_cache.has(house): route_cache[house] = {}
	var cache: Dictionary = route_cache[house]
	var pair := start + "|" + target
	if cache.has(pair):
		var cached: Dictionary = cache[pair]
		if int(cached.get("version", -1)) == route_version and int(main.game_clock.elapsed_days) - int(cached.get("cached_day", 0)) <= 90:
			cached.cached_day = int(main.game_clock.elapsed_days)
			_count_route("cache_hits")
			return cached
		route_cache_bytes = maxi(0, route_cache_bytes - int(cached.get("bytes", 256)))
		cache.erase(pair)
	if route_results.has(key):
		var result: Dictionary = route_results[key]
		route_results.erase(key)
		return result
	var army: Node = main.army_campaign
	if start != target and connections.get(Grid.cell_at(army.node_point(start)), -1) != connections.get(Grid.cell_at(army.node_point(target)), -2):
		return {"status":"unreachable", "reachable":false, "days":INF, "path":[], "deferred":false}
	if not route_budget_active:
		var search: RefCounted = army.new_route_search(start, target, house, 24000, true)
		search.advance(24001)
		var result: Dictionary = army.finish_route_report(search, start, target, house)
		_cache_route(house, pair, result)
		return result
	for request in active_routes + route_requests:
		if request.key == key:
			_register_route_waiter(request)
			if urgent: request.urgent = true
			request.priority = mini(request_priority, int(request.get("priority", 2)))
			planning_deferred = true
			return {"status":"deferred", "reachable":false, "days":INF, "deferred":true}
	var house_pending := 0
	for request in active_routes + route_requests:
		if request.house == house: house_pending += 1
	if request_priority <= 1 and route_requests.size() >= ROUTE_QUEUE_LIMIT:
		for i in range(route_requests.size() - 1, -1, -1):
			if int(route_requests[i].priority) > request_priority: route_requests.remove_at(i); break
	if route_requests.size() < ROUTE_QUEUE_LIMIT and (urgent or house_pending < 2):
		var request := {"key":key, "house":house, "start":start, "target":target, "urgent":urgent, "priority":request_priority, "day":int(main.game_clock.elapsed_days), "version":route_version, "waiters":{}, "queued_usec":Time.get_ticks_usec()}
		_register_route_waiter(request)
		route_requests.append(request)
	planning_deferred = true
	_count_route("deferred")
	return {"status":"deferred", "reachable":false, "days":INF, "deferred":true}

func _register_route_waiter(request: Dictionary) -> void:
	if current_job.get("kind", "") not in ["strategy", "army", "unit"]: return
	var key := job_key(current_job.house, current_job.kind, current_job.target)
	request.waiters[key] = current_job.duplicate()

func _rules_pending() -> bool:
	for job in work_queue:
		if job.kind in ["daily", "world", "power", "schedule"]: return true
	return false

func _process_routes(frame_started: int, budget_usec := FRAME_BUDGET_USEC) -> void:
	# Workers only see immutable value snapshots. Retired tasks count toward the cap.
	for request in retired_routes.duplicate():
		if WorkerThreadPool.is_task_completed(request.task):
			WorkerThreadPool.wait_for_task_completion(request.task)
			if profile_enabled:
				if not profile_jobs.has("route:discarded_worker"): profile_jobs["route:discarded_worker"] = []
				profile_jobs["route:discarded_worker"].append(request.search.worker_finished_usec - request.search.worker_started_usec)
			retired_routes.erase(request)
	while Time.get_ticks_usec() - frame_started < budget_usec:
		while active_routes.size() + retired_routes.size() < route_worker_limit and not route_requests.is_empty():
			var index := 0
			var best := 3
			for i in range(route_requests.size()):
				var rank := int(route_requests[i].priority)
				if int(main.game_clock.elapsed_days) - int(route_requests[i].day) >= 3: rank = mini(rank, 1)
				if rank < best: best = rank; index = i
			var request: Dictionary = route_requests[index]
			route_requests.remove_at(index)
			var stamp := Time.get_ticks_usec()
			request.search = main.army_campaign.new_route_search(request.start, request.target, request.house, 24000, true)
			_snapshot_route_data()
			request.search.allowed = route_land_snapshot
			if not request.search.blocked.is_read_only(): request.search.blocked.make_read_only()
			request.search.road_cells = route_roads_snapshot
			request.search.excluded_edges = route_exclusions_snapshot
			request.search.edge_cost = Callable()
			record_profile("route:snapshot", stamp)
			request.task = WorkerThreadPool.add_task(request.search.advance_worker.bind(24001), false, "CPU weighted route")
			active_routes.append(request)
			_count_route("searches")
		if active_routes.is_empty(): break
		var finished := false
		for request in active_routes.duplicate():
			if not WorkerThreadPool.is_task_completed(request.task): continue
			WorkerThreadPool.wait_for_task_completion(request.task)
			var stamp := Time.get_ticks_usec()
			if profile_enabled:
				for label in ["route:queue_wait", "route:worker", "route:pickup"]:
					if not profile_jobs.has(label): profile_jobs[label] = []
				profile_jobs["route:queue_wait"].append(request.search.worker_started_usec - int(request.queued_usec))
				profile_jobs["route:worker"].append(request.search.worker_finished_usec - request.search.worker_started_usec)
				profile_jobs["route:pickup"].append(stamp - request.search.worker_finished_usec)
			active_routes.erase(request)
			finished = true
			_count_route("expanded", request.search.closed.size())
			var result: Dictionary = main.army_campaign.finish_route_report(request.search, request.start, request.target, request.house)
			_count_route(result.status)
			_cache_route(request.house, request.start + "|" + request.target, result)
			for waiter in request.get("waiters", {}).values():
				queue_job(waiter.house, waiter.kind, waiter.target, mini(1, int(waiter.priority)))
			if result.status == "search_limit":
				# Short lived; never cache a truncated search as an unreachable path.
				route_results[request.key] = result
				if route_results.size() > 64: route_results.erase(route_results.keys()[0])
			record_profile("route:complete", stamp)
		if not finished: break

func _snapshot_route_data() -> void:
	if route_land_snapshot.is_empty():
		route_land_snapshot = main.hex_tile_layer.visible_cells.duplicate()
		route_land_snapshot.make_read_only()
	if not road_snapshot_dirty: return
	road_snapshot_dirty = false
	snapshot_version = route_version
	route_roads_snapshot = main.developer_tools.network.cells.duplicate()
	route_exclusions_snapshot = main.developer_tools.network.excluded_edges.duplicate()
	route_roads_snapshot.make_read_only()
	route_exclusions_snapshot.make_read_only()

func _on_roads_changed() -> void:
	road_snapshot_dirty = true
	invalidate_routes()

func _exit_tree() -> void:
	for request in active_routes + retired_routes:
		WorkerThreadPool.wait_for_task_completion(request.task)

func _cache_route(house: String, pair: String, result: Dictionary) -> void:
	if result.status not in ["found", "unreachable"]: return
	if not route_cache.has(house): route_cache[house] = {}
	if route_cache[house].has(pair):
		route_cache_bytes -= int(route_cache[house][pair].get("bytes", 256))
		route_cache[house].erase(pair)
	var bytes: int = result.get("path", []).size() * 48 + 256
	if bytes > ROUTE_CACHE_BYTES: return
	while route_cache_bytes + bytes > ROUTE_CACHE_BYTES or _route_cache_count() >= ROUTE_CACHE_ENTRIES:
		_count_route("evictions")
		var removed := false
		for owner in route_cache.keys():
			if route_cache[owner].is_empty(): continue
			var oldest: Variant = route_cache[owner].keys()[0]
			route_cache_bytes -= int(route_cache[owner][oldest].get("bytes", 256))
			route_cache[owner].erase(oldest)
			removed = true
			break
		if not removed: route_cache_bytes = 0; break
	result["bytes"] = bytes
	result["cached_day"] = int(main.game_clock.elapsed_days)
	route_cache[house][pair] = result
	route_cache_bytes += bytes

func _route_cache_count() -> int:
	var count := 0
	for cache in route_cache.values(): count += cache.size()
	return count

func invalidate_routes(a := "", b := "") -> void:
	# Ownership and diplomatic dependency changes retain the conservative fallback.
	_count_profile("discarded_searches", active_routes.size() + route_requests.size())
	_count_profile("invalidation:global" if a.is_empty() else "invalidation:diplomacy")
	route_version += 1
	route_cache.clear()
	route_cache_bytes = 0
	route_requests.clear()
	retired_routes.append_array(active_routes)
	active_routes.clear()
	route_results.clear()
	frontier_cache.clear()
	unit_positions_dirty = true
	_count_profile("route_invalidations")
	main.army_campaign.route_obstacles.clear()
	main.army_campaign.weighted_obstacles.clear()
	main.army_campaign.political_version = -1
	for pair in [[a, b], [b, a]]:
		if not alliance_index.has(pair[0]) or not enemy_index.has(pair[0]): continue
		alliance_index[pair[0]].erase(pair[1])
		enemy_index[pair[0]].erase(pair[1])
		var relation: String = GameSession.relation(pair[0], pair[1])
		if relation == "ally": alliance_index[pair[0]].append(pair[1])
		if relation == "enemy": enemy_index[pair[0]].append(pair[1])
		if pair[0] != GameSession.player_house:
			plan_for(pair[0]).next_strategy = int(main.game_clock.elapsed_days)
			queue_job(pair[0], "strategy", "", 0)

func _count_route(kind: String, count := 1) -> void:
	if profile_enabled: profile_routes[kind] = int(profile_routes.get(kind, 0)) + count

func _count_profile(kind: String, count := 1) -> void:
	if profile_enabled: profile_counters[kind] = int(profile_counters.get(kind, 0)) + count

func record_profile(kind: String, started: int) -> void:
	if not profile_enabled: return
	if not profile_jobs.has(kind): profile_jobs[kind] = []
	profile_jobs[kind].append(Time.get_ticks_usec() - started)

func reset_profile() -> void:
	profile_jobs.clear()
	profile_frames.clear()
	profile_routes.clear()
	profile_counters.clear()
	maximum_frame_usec = 0
	main.game_clock.reset_profile()

func _distribution(values: Array) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted: total += float(value)
	return {"count":sorted.size(), "total_ms":total / 1000.0, "p50_ms":sorted[int((sorted.size() - 1) * 0.5)] / 1000.0, "p95_ms":sorted[int((sorted.size() - 1) * 0.95)] / 1000.0, "p99_ms":sorted[int((sorted.size() - 1) * 0.99)] / 1000.0, "max_ms":sorted.back() / 1000.0}

func _search_bytes() -> int:
	# Do not inspect dictionaries while a worker owns them. Conservative capacity estimate.
	return (active_routes.size() + retired_routes.size()) * 24000 * 320 + (route_land_snapshot.size() + route_roads_snapshot.size() + route_exclusions_snapshot.size()) * 64

func profile_report() -> Dictionary:
	var jobs := {}
	for kind in profile_jobs: jobs[kind] = _distribution(profile_jobs[kind])
	return {"frames":_distribution(profile_frames), "jobs":jobs, "counters":profile_counters.duplicate(), "routes":profile_routes.duplicate(), "route_cache_estimated_bytes":route_cache_bytes, "search_estimated_bytes":_search_bytes(), "active_searches":active_routes.size(), "queued_searches":route_requests.size(), "pending_jobs":work_queue.size(), "wars":main.diplomacy.wars.size(), "recent_decisions":decisions.slice(-10), "route_version":route_version, "clock":main.game_clock.profile_report()}

func allies(house: String) -> Array:
	return alliance_index.get(house, [])

func coalition_power(target: String, attacker: String) -> float:
	var result := power_for(target)
	for ally in allies(target):
		if ally == attacker or main.diplomacy.truce_remaining(ally, attacker) > 0: continue
		if nearby.get(ally, {}).has(target) or nearby.get(ally, {}).has(attacker): result += power_for(ally)
	return result

func is_defending(house: String, attacker: String) -> bool:
	for war in main.diplomacy.wars.values():
		if war.attacker == attacker and house in war.defenders: return true
	return false

func choose_strategy(house: String) -> void:
	var plan := plan_for(house)
	var enemy := ""
	var closest := INF
	for other in enemy_index.get(house, []):
		var distance := float(nearby.get(house, {}).get(other, {}).get("distance", INF))
		if enemy.is_empty() or distance < closest: enemy = other; closest = distance
	if not str(plan.target).is_empty() and enemy_index.get(house, []).has(plan.target):
		var old_distance := float(nearby.get(house, {}).get(plan.target, {}).get("distance", INF))
		if old_distance <= closest * 1.25: enemy = plan.target
	if threatened_houses.has(house): enemy = threatened_houses[house]
	if not enemy.is_empty():
		plan.objective = "defend" if threatened_houses.has(house) or is_defending(house, enemy) else "fight"
		plan.target = enemy
		seek_alliance(house)
		if power_for(house) < power_for(enemy) * 0.6:
			if main.diplomacy.reason("peace", house, enemy).is_empty():
				main.diplomacy.act("peace", house, enemy)
				log_decision(house, "peace", enemy, "戦力不足により停戦")
			elif main.diplomacy.reason("envoy", house, enemy).is_empty() and main.diplomacy.opinion(enemy, house) < -20:
				main.diplomacy.act("envoy", house, enemy)
		return
	plan.objective = "develop"
	plan.target = ""
	seek_alliance(house)
	# Only autonomous declarations wait; active wars and defensive aid run above.
	if int(main.game_clock.elapsed_days) < OFFENSIVE_GRACE_DAYS: return
	var own := power_for(house)
	if own <= 0: return
	var best := ""
	var candidates: Array = []
	for other in nearby.get(house, {}):
		if GameSession.relation(house, other) != "neutral" or main.diplomacy.truce_remaining(house, other) > 0: continue
		if power_for(other) > own * WEAK_RATIO: continue
		var defense := coalition_power(other, house)
		if own < maxf(100.0, defense) * ATTACK_ADVANTAGE: continue
		var frontier: Dictionary = nearby[house][other]
		var margin := clampf((own / maxf(100.0, defense) - 1.0) / 3.0, 0.0, 1.0)
		var land := clampf(float(main.governance_registry.districts[frontier.target].population) / 100000.0, 0.0, 1.0)
		var proximity := 1.0 - clampf(sqrt(float(frontier.distance)) / 350.0, 0.0, 1.0)
		var value := margin * 0.5 + land * 0.2 + proximity * 0.3
		candidates.append({"house":other, "value":value, "justified":not main.diplomacy.war_justification(house, other).is_empty(), "scores":{"strength":margin, "land":land, "proximity":proximity}})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.justified if a.justified != b.justified else a.value > b.value)
	for candidate in candidate_window(house, candidates, "strategy"):
		if not attack_frontier(house, candidate.house).is_empty(): best = candidate.house; break
		if planning_deferred: break
	if best.is_empty():
		finish_candidate_window(house, "strategy", candidates.size())
		return
	for candidate in candidates:
		if candidate.house == best:
			plan["evaluation"] = {"action":"invade", "target":best, "value":candidate.value, "scores":candidate.scores}
			break
	var frontier := attack_frontier(house, best)
	if main.diplomacy.war_justification(house, best).is_empty():
		prepare_war_claim(house, best, frontier.target)
		return
	prepare_commander(house, frontier.origin)
	if not can_dispatch(house, frontier.origin):
		log_decision(house, "prepare", best, "兵・武将・120日分の腰兵糧を準備")
		return
	if main.diplomacy.act("war", house, best) == OK:
		plan.objective = "invade"
		plan.target = best
		log_decision(house, "war", best, "自軍戦力 %.0f 対 防衛同盟込み %.0f" % [own, coalition_power(best, house)])
	else: log_decision(house, "wait", best, main.diplomacy.last_message)

func prepare_war_claim(house: String, target: String, district_id: String) -> void:
	var diplomacy: Node = main.diplomacy
	if not diplomacy.has_spy(house, target):
		if diplomacy.act("build_spy_network", house, target) == OK:
			log_decision(house, "spy", target, "宣戦理由の準備：諜報網を構築（月初+5）")
	if diplomacy.act("fabricate_claim", house, target, district_id) == OK:
		log_decision(house, "claim", target, "宣戦理由の準備：郡の請求権を捏造")

func attack_frontier(house: String, other: String) -> Dictionary:
	var cache_key := house + "|" + other
	if frontier_cache.has(cache_key): return frontier_cache[cache_key]
	var sources: Array = holdings.get(house, []).duplicate()
	sources.sort_custom(func(a: String, b: String): return main.district_actions.sortie_available(main.governance_registry.districts[a]) > main.district_actions.sortie_available(main.governance_registry.districts[b]))
	var best: Dictionary = {}
	var days := INF
	for source in candidate_window(house, sources, "frontier_sources:" + other):
		if dispatch_percent(house, source) == 0: continue
		var start: String = "district:" + source
		var targets: Array = holdings.get(other, []).duplicate()
		targets.sort_custom(func(a: String, b: String): return main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point("district:" + a)) < main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point("district:" + b)))
		for target in candidate_window(house, targets, "frontier_targets:" + source + ":" + other):
			if Grid.distance(Grid.cell_at(main.army_campaign.node_point(start)), Grid.cell_at(main.army_campaign.node_point("district:" + target))) * 2 + 25 >= 120: continue
			var trip := route_info(house, start, "district:" + target)
			if trip.get("status", "") == "search_limit": continue
			if trip.get("deferred", false): return {}
			if trip.reachable and round_trip_fits(house, start, "district:" + target, float(trip.days), 120) and trip.days < days:
				days = trip.days
				best = {"origin":source, "target":target, "days":days}
				frontier_cache[cache_key] = best
				return best
			if planning_deferred: return {}
		finish_candidate_window(house, "frontier_targets:" + source + ":" + other, targets.size())
	finish_candidate_window(house, "frontier_sources:" + other, sources.size())
	return best

func seek_alliance(house: String) -> void:
	var own := power_for(house)
	var threatened := false
	for other in nearby.get(house, {}):
		if GameSession.relation(house, other) != "ally" and power_for(other) > maxf(1.0, own) * ATTACK_ADVANTAGE: threatened = true
	if not threatened or allies(house).size() >= MAX_ALLIES: return
	var best := ""
	var candidates: Array = []
	for other in nearby.get(house, {}):
		if GameSession.relation(house, other) != "neutral" or power_for(other) <= own: continue
		if main.diplomacy.truce_remaining(house, other) > 0: continue
		var frontier: Dictionary = nearby[house][other]
		var strength := clampf(power_for(other) / maxf(100.0, own) / 4.0, 0.0, 1.0)
		var friendship := clampf((main.diplomacy.opinion(other, house) + 100.0) / 200.0, 0.0, 1.0)
		var proximity := 1.0 - clampf(sqrt(float(frontier.distance)) / 350.0, 0.0, 1.0)
		var score := strength * 0.5 + friendship * 0.2 + proximity * 0.3
		if plan_for(house).alliance_target == other: score += 0.1
		candidates.append({"house":other, "value":score, "scores":{"strength":strength, "friendship":friendship, "proximity":proximity}})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.value > b.value)
	for candidate in candidate_window(house, candidates, "alliance"):
		var frontier: Dictionary = nearby[house][candidate.house]
		var trip := route_info(house, "district:" + frontier.origin, "district:" + frontier.target)
		if trip.get("status", "") == "search_limit": continue
		if trip.reachable: best = candidate.house; break
		if trip.get("deferred", false): break
	if best.is_empty():
		finish_candidate_window(house, "alliance", candidates.size())
		return
	plan_for(house).alliance_target = best
	for candidate in candidates:
		if candidate.house == best:
			plan_for(house)["evaluation"] = {"action":"ally", "target":best, "value":candidate.value, "scores":candidate.scores}
			break
	if main.diplomacy.reason("ally", house, best).is_empty():
		main.diplomacy.act("ally", house, best)
		log_decision(house, "ally", best, "強い家との防衛同盟を成立")
		return
	if not main.diplomacy.has_envoy(house, best) and main.diplomacy.reason("envoy", house, best).is_empty():
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

func command_armies(house: String, only_unit := "", dispatch_only := false) -> void:
	var army: Node2D = main.army_campaign
	var plan := plan_for(house)
	var dispatch_sources: Array = []
	if dispatch_only:
		# These conditions cannot be changed by objective/path evaluation. Avoid
		# rebuilding defense/attack candidates for an impossible departure.
		if int(plan.last_dispatch) == int(main.game_clock.elapsed_days): return
		if officers_for(house).is_empty(): return
		if formations.get(house, []).size() >= clampi(holdings.get(house, []).size(), 2, 12): return
		dispatch_sources = holdings.get(house, []).duplicate()
		dispatch_sources.sort_custom(func(a: String, b: String): return main.district_actions.sortie_available(main.governance_registry.districts[a]) > main.district_actions.sortie_available(main.governance_registry.districts[b]))
		dispatch_sources = dispatch_sources.slice(0, 3).filter(func(district: String): return dispatch_percent(house, district) > 0)
		if dispatch_sources.is_empty(): return
	var enemy: String = plan.target
	if enemy.is_empty() or GameSession.relation(house, enemy) != "enemy":
		enemy = ""
		for other in enemy_index.get(house, []):
			if GameSession.relation(house, other) == "enemy": enemy = other; break
	if enemy.is_empty() and formations.get(house, []).is_empty(): return
	var objectives: Array = []
	# Query regional bins around threatened offices instead of scanning all armies.
	var seen := {}
	for friend in [house] + allies(house):
		for district_id in holdings.get(friend, []):
			var point: Vector2 = army.node_point("district:" + district_id)
			for id in nearby_units(point):
				if seen.has(id) or not army.units.has(id): continue
				var unit: Dictionary = army.units[id]
				if GameSession.relation(house, unit.house_id) != "enemy" or army.unit_position(unit).distance_to(point) > Grid.RADIUS * 5: continue
				seen[id] = true
				objectives.append({"target":Grid.key(Grid.cell_at(army.unit_position(unit))), "priority":0})
	if not enemy.is_empty():
		for district_id in holdings.get(enemy, []): objectives.append({"target":"district:" + district_id, "priority":1})
	for id in formations.get(house, []).duplicate():
		if dispatch_only or (not only_unit.is_empty() and id != only_unit) or not army.units.has(id): continue
		var unit: Dictionary = army.units[id]
		var start: String = unit.next_site if not unit.next_site.is_empty() else unit.site_id
		var mission: Dictionary = missions.get(id, {"target":"", "initial_soldiers":int(unit.soldiers), "returning":false})
		missions[id] = mission
		if unit.next_site.is_empty() and unit.orders.is_empty():
			for opponent_id in nearby_units(army.unit_position(unit)):
				var opponent: Dictionary = army.units[opponent_id]
				if GameSession.relation(house, opponent.house_id) != "enemy": continue
				var offset: Vector2 = army.unit_position(opponent) - army.unit_position(unit)
				if offset.length() > army.BOW_RANGE or offset.is_zero_approx(): continue
				army.rotate_unit_for_house(house, id, wrapf(offset.angle() + PI / 2.0 - float(unit.facing), -PI, PI))
				break
		var home := {"reachable":false, "days":0.0}
		if int(unit.supply_days) < 60 or int(main.game_clock.elapsed_days) % 7 == 0: home = route_info(house, start, unit.origin, int(unit.supply_days) <= 15 or bool(mission.returning))
		var office_id: String = army.district_id_for_node(unit.site_id)
		var holding_occupation := false
		if not office_id.is_empty() and unit.next_site.is_empty() and unit.orders.is_empty():
			var record: Dictionary = main.governance_registry.districts[office_id]
			holding_occupation = army._hostile_office(unit) or (record.house_id == house and float(record.occupation_stability) < 100.0 and int(unit.soldiers) >= 100)
		if mission.returning or int(unit.soldiers) < int(mission.initial_soldiers) * 0.4 or int(unit.supply_days) < 15 or (home.reachable and int(unit.supply_days) <= ceili(home.days) + 10) or (objectives.is_empty() and not holding_occupation):
			mission.returning = true
			if unit.orders.is_empty() or unit.orders.back() != unit.origin:
				_return_cpu_unit(house, unit, start)
			continue
		if holding_occupation: continue
		if not unit.next_site.is_empty() or not unit.orders.is_empty():
			var current_target: String = mission.target
			var district_id: String = current_target.trim_prefix("district:") if current_target.begins_with("district:") else ""
			if objectives[0].priority > 0 and (district_id.is_empty() or GameSession.relation(house, main.governance_registry.districts[district_id].house_id) == "enemy"): continue
		var target := choose_objective(house, start, objectives, int(unit.supply_days), unit.origin)
		if target.is_empty(): continue
		var destination: String = unit.orders.back() if not unit.orders.is_empty() else (unit.next_site if not unit.next_site.is_empty() else unit.site_id)
		if destination != target and _order_evaluated(house, id, start, target):
			mission.target = target
			log_decision(house, "march", target, "防衛・援軍・攻略の目標へ進軍")
	if not only_unit.is_empty() or objectives.is_empty(): return
	if int(plan.last_dispatch) == int(main.game_clock.elapsed_days): return
	var cap := clampi(holdings.get(house, []).size(), 2, 12)
	if formations.get(house, []).size() >= cap: return
	var sources: Array = dispatch_sources if dispatch_only else holdings.get(house, []).duplicate()
	if not dispatch_only:
		sources.sort_custom(func(a: String, b: String): return main.district_actions.sortie_available(main.governance_registry.districts[a]) > main.district_actions.sortie_available(main.governance_registry.districts[b]))
		sources = sources.slice(0, 3)
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
		_order_evaluated(house, id, origin, target)
		plan.last_dispatch = int(main.game_clock.elapsed_days)
		var trip: Dictionary = route_cache.get(house, {}).get(origin + "|" + target, {})
		plan.operation = {"origin":origin, "target":target, "assembly":origin, "return_to":origin, "started":int(main.game_clock.elapsed_days), "arrival_day":int(main.game_clock.elapsed_days) + ceili(float(trip.get("days", 0.0))), "required_soldiers":_required_soldiers(target)}
		log_decision(house, "dispatch", target, "%d人を出陣、守備兵と腰兵糧を確保" % troops)
		# One departure per house per day bounds work and avoids spending stores twice.
		break

func choose_objective(house: String, start: String, objectives: Array, supply_days: int, home_node := "") -> String:
	var candidates := objectives.duplicate()
	var operation: Dictionary = plan_for(house).operation
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		var av: float = float(a.priority) * 100000000.0 + main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point(a.target)) * (0.8 if operation.get("target", "") == a.target else 1.0)
		var bv: float = float(b.priority) * 100000000.0 + main.army_campaign.node_point(start).distance_squared_to(main.army_campaign.node_point(b.target)) * (0.8 if operation.get("target", "") == b.target else 1.0)
		return av < bv)
	var return_to: String = start if home_node.is_empty() else home_node
	var context := "objective:" + start
	for objective in candidate_window(house, candidates, context):
		if Grid.distance(Grid.cell_at(main.army_campaign.node_point(start)), Grid.cell_at(main.army_campaign.node_point(objective.target))) + Grid.distance(Grid.cell_at(main.army_campaign.node_point(objective.target)), Grid.cell_at(main.army_campaign.node_point(return_to))) + 25 >= supply_days: continue
		if objective.priority > 0 and _reserved_soldiers(house, objective.target) >= _required_soldiers(objective.target): continue
		var trip := route_info(house, start, objective.target)
		if trip.get("status", "") == "search_limit": continue
		if trip.get("deferred", false): return ""
		if trip.reachable and round_trip_fits(house, return_to, objective.target, float(trip.days), supply_days): return objective.target
		if planning_deferred: return ""
	finish_candidate_window(house, context, candidates.size())
	return ""

func candidate_window(house: String, candidates: Array, context := "return") -> Array:
	if candidates.size() <= 3: return candidates
	var plan := plan_for(house)
	var offset := int(plan.cursors.get(context, 0)) % candidates.size()
	return (candidates.slice(offset) + candidates.slice(0, offset)).slice(0, 3)

func finish_candidate_window(house: String, context: String, count: int) -> void:
	if planning_deferred or count <= 3: return
	var plan := plan_for(house)
	if plan.cursors.size() > 64: plan.cursors.clear()
	plan.cursors[context] = (int(plan.cursors.get(context, 0)) + 3) % count

func round_trip_fits(house: String, start: String, target: String, outbound_days: float, supply: int) -> bool:
	if outbound_days + 25.0 >= supply: return false
	var home := route_info(house, target, start)
	return home.reachable and outbound_days + float(home.days) + 25.0 < supply

func _order_evaluated(house: String, id: String, start: String, target: String, urgent := false) -> bool:
	var evaluated := route_info(house, start, target, urgent)
	return evaluated.reachable and main.army_campaign.order_for_house(house, id, target, false, evaluated)

func _return_cpu_unit(house: String, unit: Dictionary, start: String) -> void:
	var army: Node = main.army_campaign
	var origin_id: String = army.district_id_for_node(unit.origin)
	if main.governance_registry.districts.get(origin_id, {}).get("house_id", "") != house:
		var choices: Array = holdings.get(house, []).duplicate()
		choices.sort_custom(func(a: String, b: String): return army.node_point("district:" + a).distance_squared_to(army.unit_position(unit)) < army.node_point("district:" + b).distance_squared_to(army.unit_position(unit)))
		for district in candidate_window(house, choices, "return:" + unit.id):
			var candidate: String = "district:" + district
			var result := route_info(house, start, candidate, true)
			if result.reachable: unit.origin = candidate; break
		if main.governance_registry.districts.get(army.district_id_for_node(unit.origin), {}).get("house_id", "") != house:
			finish_candidate_window(house, "return:" + unit.id, choices.size())
			return
	if unit.site_id == unit.origin and unit.next_site.is_empty():
		army.return_home_for_house(house, unit.id)
	else:
		_order_evaluated(house, unit.id, start, unit.origin, true)

func _reserved_soldiers(house: String, target: String) -> int:
	var count := 0
	for id in missions:
		if not main.army_campaign.units.has(id): continue
		var unit: Dictionary = main.army_campaign.units[id]
		if unit.house_id != house or missions[id].target != target or missions[id].returning: continue
		var destination: String = unit.orders.back() if not unit.orders.is_empty() else (unit.next_site if not unit.next_site.is_empty() else unit.site_id)
		if destination != target: continue
		var remaining := Grid.distance(Grid.cell_at(main.army_campaign.unit_position(unit)), Grid.cell_at(main.army_campaign.node_point(target)))
		if float(unit.supply_days) > remaining + 25: count += int(unit.soldiers)
	return count

func _required_soldiers(target: String) -> int:
	var id := target.trim_prefix("district:")
	var record: Dictionary = main.governance_registry.districts.get(id, {})
	return maxi(1000, ceili(float(record.get("sortie_troops", 1000)) * ATTACK_ADVANTAGE))

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
	var available_budget := budget(house)
	var province: String = record_owner.province
	if management._can_govern(house, administrator) and not management.province_governors.has(house + "|" + province):
		management.appoint_province_governor(house, administrator, province, true)
	var record: Dictionary = main.governance_registry.districts[district_id]
	main.district_economy.assign_developer(district_id, "agriculture", administrator)
	main.district_economy.assign_developer(district_id, "commerce", administrator)
	if management._can_govern(house, administrator) and not management.district_governors.has(district_id): management.appoint_district_governor(house, administrator, district_id, true)
	if int(record.devastation) > 0 and available_budget >= main.district_actions.repair_cost(record):
		main.district_actions.repair(district_id, house)
		available_budget = budget(house)
	var construction: Variant = main.district_buildings.state[district_id].construction
	if construction != null and available_budget < 1 and float(resources.money) < management.monthly_stipend(house): main.district_buildings.cancel_construction(district_id, house)
	var food_need: bool = int(resources.provisions) < main.district_actions.sortie_capacity(record) * 0.4
	var choices: Array = ["irrigation", "farm_estate", "market", "workshop", "office"] if food_need else ["market", "workshop", "irrigation", "office", "temple"]
	if war: choices = ["fort", "barracks"] + choices
	var buildings: Node = main.district_buildings
	if war and construction == null and "fort" not in buildings.state[district_id].built and "temple" in buildings.state[district_id].built and buildings.slots_used(district_id) >= buildings.slot_capacity(record) and available_budget >= buildings.cost_for(district_id, "fort"):
		buildings.demolish(district_id, "temple", house)
	for building in choices:
		if main.district_buildings.reason_for(district_id, building, house).is_empty() and available_budget >= main.district_buildings.cost_for(district_id, building):
			main.district_buildings.start_construction(district_id, building, house, main.game_clock.year, main.game_clock.month, main.game_clock.day)
			available_budget = budget(house)
			break
	if war and int(record.infrastructure) < 3 and available_budget >= main.district_actions.upgrade_cost(record): main.district_actions.upgrade(district_id, house)

func manage_research(house: String) -> void:
	var resources: Dictionary = main.district_economy.house_resources.get(house, {})
	if resources.is_empty(): return
	var branches: Array = ["governance", "commerce", "agriculture"]
	if int(resources.provisions) < 100: branches = ["agriculture", "commerce", "governance"]
	elif float(resources.money) < 100.0: branches = ["commerce", "governance", "agriculture"]
	for branch in branches:
		var technology: String = main.technology_tree.next_technology(house, branch)
		if not technology.is_empty() and main.technology_tree.research(house, branch, technology) == OK:
			log_decision(house, "research", technology, "不足を改善する研究を取得")
			break

func save_state() -> Dictionary:
	var jobs := work_queue.duplicate(true)
	var next_sequence := queue_sequence
	var saved_keys := {}
	for job in jobs: saved_keys[job_key(job.house, job.kind, job.target)] = job
	# Preserve unfinished decisions rather than serializing worker/frontier objects.
	for request in active_routes + route_requests:
		for waiter in request.get("waiters", {}).values():
			var key := job_key(waiter.house, waiter.kind, waiter.target)
			if saved_keys.has(key):
				var existing: Dictionary = saved_keys[key]
				existing.day = mini(int(existing.day), int(request.day))
				existing.priority = mini(int(existing.priority), 0 if request.urgent else int(waiter.priority))
				continue
			var job: Dictionary = waiter.duplicate()
			if not job.has("sequence"):
				job["sequence"] = next_sequence
				next_sequence += 1
			job.day = mini(int(job.day), int(request.day))
			if request.urgent: job.priority = 0
			jobs.append(job)
			saved_keys[key] = job
	return {"plans":plans.duplicate(true), "missions":missions.duplicate(true), "decisions":decisions.duplicate(true), "work_queue":jobs}

func restore_state(state: Dictionary) -> void:
	plans = state.plans.duplicate(true)
	missions = state.missions.duplicate(true)
	decisions = state.decisions.duplicate(true)
	work_queue = state.work_queue.duplicate(true)
	_index_queue()
	route_budget_active = not work_queue.is_empty()
	for plan in plans.values():
		plan.next_strategy = int(plan.next_strategy)
		plan.last_admin = int(plan.last_admin)
		plan.last_dispatch = int(plan.last_dispatch)
		for context in plan.cursors: plan.cursors[context] = int(plan.cursors[context])
		if not plan.operation.is_empty():
			plan.operation.started = int(plan.operation.started)
			plan.operation.arrival_day = int(plan.operation.arrival_day)
			plan.operation.required_soldiers = int(plan.operation.required_soldiers)
	for job in work_queue:
		job.day = int(job.day)
		job.priority = int(job.priority)
		job.sequence = int(job.sequence)
	for mission in missions.values(): mission.initial_soldiers = int(mission.initial_soldiers)
	for decision in decisions: decision.day = int(decision.day)
	invalidate_routes()
	unit_index_dirty = true
