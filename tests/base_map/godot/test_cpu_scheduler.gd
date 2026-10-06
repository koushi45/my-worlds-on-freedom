extends SceneTree
const Grid = preload("res://scripts/map/hex_grid.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)

func run() -> void:
	var session: Node = root.get_node("GameSession")
	session.new_game("uesugi_yamanouchi")
	while current_scene == null or not current_scene.initialized: await process_frame
	var main: Node = current_scene
	var cpu: Node = main.cpu_controller
	main.game_clock.set_process(false)
	cpu.set_process(false)
	cpu.enabled = false
	cpu.work_queue.clear()
	var house := "takeda"
	cpu.queue_job(house, "strategy", "", 2)
	cpu.queue_job(house, "strategy", "", 0)
	check(cpu.work_queue.size() == 1 and cpu.work_queue[0].priority == 0, "duplicate jobs promote existing work")
	cpu.queue_job(house, "research", "", 2)
	check(cpu.pending_wait_reason() == "urgent_ai", "urgent decisions have a daily deadline")
	check(cpu.work_queue[cpu._next_job_index()].kind == "strategy", "urgent work precedes routine research")
	cpu.work_queue.clear()
	cpu.queue_job(house, "research", "", 2)
	cpu.queue_job(house, "officers", "", 2)
	cpu.queue_job(house, "district", cpu.holdings[house][0], 1)
	check(cpu._take_job(cpu._next_job_index()).kind == "district", "priority selection survives unordered storage")
	var queue_saved: Dictionary = cpu.save_state()
	cpu.restore_state(JSON.parse_string(JSON.stringify(queue_saved)))
	check(cpu._take_job(cpu._next_job_index()).kind == "research", "equal priority FIFO survives swap removal and reload")
	check(cpu._take_job(cpu._next_job_index()).kind == "officers", "second equal priority job follows first")
	cpu.profile_enabled = true
	cpu.reset_profile()
	cpu.refresh_world(false)
	cpu.refresh_world(false)
	check(int(cpu.profile_counters.get("ownership_rebuilds", 0)) == 0, "unchanged ownership retains holdings index")
	check(int(cpu.profile_counters.get("diplomacy_rebuilds", 0)) == 0, "unchanged diplomacy retains relation index")
	cpu.unit_index_dirty = true
	cpu.unit_positions_dirty = true
	cpu._refresh_unit_index()
	check(int(cpu.profile_counters.get("membership_rebuilds", 0)) == 0, "position refresh does not rebuild unchanged officer membership")
	# Moving inside one spatial bin must still change the exact-distance threat.
	var saved_offices: Dictionary = cpu.office_regions
	var relation_key: String = session.pair(house, "hojo")
	var saved_relation: String = session.relation(house, "hojo")
	session.relations[relation_key] = "enemy"
	cpu.refresh_world(false)
	cpu.office_regions = {Vector2i(1, 1):[{"id":cpu.holdings[house][0], "point":Vector2(100, 100)}]}
	var probe := {"id":"index_probe", "house_id":"hojo", "officers":["probe_officer"], "site_id":Grid.key(Grid.cell_at(Vector2(70, 70))), "next_site":"", "progress":0.0}
	main.army_campaign.units[probe.id] = probe
	cpu.unit_index_dirty = true
	cpu.unit_positions_dirty = true
	cpu._refresh_unit_index()
	check(not cpu.threatened_houses.has(house), "outside defense radius is not a threat")
	var membership_rebuilds: int = cpu.profile_counters.get("membership_rebuilds", 0)
	var region_updates: int = cpu.profile_counters.get("region_updates", 0)
	probe.site_id = Grid.key(Grid.cell_at(Vector2(90, 90)))
	cpu.unit_positions_dirty = true
	cpu._refresh_unit_index()
	check(cpu.threatened_houses.has(house), "same-bin movement entering defense radius wakes the defender")
	check(cpu.profile_counters.get("membership_rebuilds", 0) == membership_rebuilds and cpu.profile_counters.get("region_updates", 0) == region_updates, "same-bin movement retains membership and spatial bins")
	probe["origin"] = "district:" + cpu.holdings["hojo"][0]
	probe.site_id = probe.origin
	probe["orders"] = []
	probe["supply_days"] = 0.0
	probe["soldiers"] = 1
	main.army_campaign._arrive(probe.id)
	check(not main.army_campaign.units.has(probe.id), "at-home return removes a formation without a movement notification")
	cpu.unit_index_dirty = false
	cpu._refresh_unit_index()
	check(probe.id not in cpu.formations.get("hojo", []) and not cpu.deployed_officers.has("probe_officer"), "membership revision catches a silent return before the next daily refresh")
	cpu.office_regions = saved_offices
	session.relations[relation_key] = saved_relation
	cpu.unit_index_dirty = false
	cpu.unit_positions_dirty = true
	cpu.refresh_world(false)
	check(not cpu.deployed_officers.has("probe_officer") and not cpu.unit_cells.has(probe.id), "removed formations leave both indexes")
	cpu.work_queue.clear()
	cpu.queue_job(house, "research", "", 2)
	check(not cpu.has_pending_daily_work(), "ordinary thinking may cross dates")
	cpu.work_queue[0].day = maxi(0, main.game_clock.elapsed_days - 3)
	var old_elapsed: int = main.game_clock.elapsed_days
	main.game_clock.elapsed_days += 3
	check(cpu.pending_wait_reason() == "ai_deadline", "aging prevents starvation")
	main.game_clock.elapsed_days = old_elapsed
	cpu.work_queue.clear()
	cpu.invalidate_routes()
	cpu.route_budget_active = true
	var origin: String = "district:" + cpu.holdings[house][0]
	var start_cell := Grid.cell_at(main.army_campaign.node_point(origin))
	var target := ""
	for offset in Grid.NEIGHBORS:
		if main.hex_tile_layer.can_enter(start_cell + offset): target = Grid.key(start_cell + offset); break
	check(not target.is_empty(), "fixture has a neighboring land tile")
	var pending: Dictionary = cpu.route_info(house, origin, target, true)
	check(pending.status == "deferred", "live AI requests yield instead of blocking")
	for index in range(100):
		cpu._process(0.0)
		await process_frame
		if not cpu.active_routes.is_empty(): check(cpu.active_routes.size() + cpu.retired_routes.size() <= cpu.MAX_ROUTE_WORKERS, "active and retired searches obey the finite worker cap")
		if cpu.route_requests.is_empty() and cpu.active_routes.is_empty(): break
	var result: Dictionary = cpu.route_info(house, origin, target, true)
	check(result.status == "found", "queued search completes without a new game day")
	check(cpu.profile_jobs.has("route:worker") and cpu.profile_jobs.has("route:queue_wait") and cpu.profile_jobs.has("route:pickup"), "search calculation and waits are measured separately")
	check(main.army_campaign.evaluated_path_valid(result, house, origin, target), "evaluated path is reusable by the common command")
	var wrong: Dictionary = result.duplicate(true)
	wrong.actor = session.player_house
	check(not main.army_campaign.evaluated_path_valid(wrong, house, origin, target), "path cannot authorize another house")
	cpu.invalidate_routes("takeda", "hojo")
	check(not main.army_campaign.evaluated_path_valid(result, house, origin, target), "diplomacy change invalidates previously evaluated paths")
	check(cpu.active_routes.is_empty() and cpu.route_requests.is_empty(), "invalidation cancels stale searches")
	var before_road: int = cpu.route_version
	var road: RefCounted = main.developer_tools.network
	var road_document: Dictionary = road.document()
	check(road.toggle(start_cell), "road fixture is editable")
	check(cpu.route_version > before_road and cpu.road_snapshot_dirty, "road change invalidates paths and road snapshot")
	road.load_document(road_document)
	# Serialize a pending request as logical work, not a live search object.
	cpu.work_queue.clear()
	main.game_clock.work_started = false
	main.game_clock._day_fraction = 0.0
	main.game_clock.backlog_days = 0.0
	cpu.queue_job(house, "research")
	cpu.current_job = {"house":house, "kind":"strategy", "target":"", "day":old_elapsed, "priority":2}
	cpu.route_info(house, origin, target, true)
	cpu.current_job = {}
	var saved: Dictionary = session.capture(main)
	check(session.validate(saved), "optional work outside an active day saves")
	check(saved.cpu.work_queue.any(func(job: Dictionary): return job.kind == "strategy" and job.priority == 0), "unfinished urgent search persists its requesting decision")
	cpu.restore_state(JSON.parse_string(JSON.stringify(saved.cpu)))
	check(cpu.route_requests.is_empty() and cpu.active_routes.is_empty() and cpu.save_state() == saved.cpu, "logical decisions restore without serializing live workers")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.clock.backlog = 100
	check(not session.validate(corrupt), "unbounded saved backlog is rejected")
	corrupt = saved.duplicate(true)
	corrupt.cpu.work_queue[0].day = old_elapsed + 100
	check(not session.validate(corrupt), "future jobs are rejected")
	corrupt = saved.duplicate(true)
	corrupt.cpu.work_queue.append(corrupt.cpu.work_queue[0].duplicate(true))
	check(not session.validate(corrupt), "duplicate saved jobs are rejected before indexing")
	corrupt = saved.duplicate(true)
	corrupt.cpu.work_queue[1].sequence = corrupt.cpu.work_queue[0].sequence
	check(not session.validate(corrupt), "ambiguous saved FIFO sequences are rejected")
	print("CPU_SCHEDULER failures=", failures)
	quit(1 if failures else 0)
