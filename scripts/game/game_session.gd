extends Node
## Lightweight session and validated JSON saves; never preload the map scene here.
const CATALOG := "res://data/derived/scenarios/house_selection_1546.json"
const DIPLOMACY := "res://data/derived/scenarios/diplomacy_1546.json"
const Clock = preload("res://scripts/game/game_clock.gd")
var catalog: Dictionary = {}
var player_house := ""
var relations: Dictionary = {}
var pending: Dictionary = {}
var last_error := ""
var save_directory := "user://saves"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if "--cpu-release-check" in OS.get_cmdline_user_args() or "--cpu-speed-check" in OS.get_cmdline_user_args(): call_deferred("new_game", "uesugi_yamanouchi")

func relation(a: String, b: String) -> String:
	if a == b: return "self"
	return relations.get(pair(a,b), "neutral")

func pair(a: String, b: String) -> String:
	return a+"|"+b if a < b else b+"|"+a

func new_game(house: String) -> Error:
	if not catalog.houses.has(house) or not catalog.houses[house].playable: return ERR_INVALID_PARAMETER
	player_house = house
	relations.clear()
	var initial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIPLOMACY))
	for r in initial.relations: relations[pair(r.a,r.b)] = r.status
	pending.clear()
	return open_map()

func open_map() -> Error:
	get_tree().paused = false
	# A string path defers loading all map resources until Start / Load is chosen.
	return get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func return_to_title() -> void:
	get_tree().paused = false
	MapDiagnostics.main = null
	pending.clear()
	player_house = ""
	relations.clear()
	get_tree().change_scene_to_file("res://scenes/start/start.tscn")

func path_for(slot: int) -> String:
	return save_directory.path_join("slot_%d.json" % slot)

func capture(main: Node) -> Dictionary:
	main.governance_registry.flush_assignment_recount()
	main.retainer_management.reconcile_officer_placements()
	main.governance_registry.recount_assignments()
	var territories := {}
	for kind in ["districts", "sites"]:
		territories[kind] = {}
		for id in main.governance_registry[kind]:
			var r: Dictionary = main.governance_registry[kind][id]
			territories[kind][id] = {"house_id":r.house_id,"governor":r.governor,"ruler":r.ruler}
			if kind == "districts":
				for field in ["population", "security", "agriculture_development", "commerce_development", "agriculture_progress", "commerce_progress", "agriculture_developer_id", "commerce_developer_id", "tax_rate", "infrastructure", "devastation", "autonomy", "defense", "sortie_troops", "occupation_stability", "loot_available_day"]:
					territories[kind][id][field] = r[field]
	var c: Node = main.game_clock
	return {"version":30,"saved_at":Time.get_datetime_string_from_system(),"player_house":player_house,
		"clock":{"year":c.year,"month":c.month,"day":c.day,"elapsed_days":c.elapsed_days,"speed":c.speed,"paused":c.paused,"fraction":c._day_fraction,"work_started":c.work_started,"backlog":c.backlog_days},
		"camera":{"x":main.camera.position.x,"y":main.camera.position.y,"zoom":main.camera.zoom.x,"oblique":main.is_oblique(),"manual_angle":main.map_view.manual_angle,"yaw":main.map_view.yaw},
		"relations":relations.duplicate(true),"diplomacy":main.diplomacy.save_state(),"cpu":main.cpu_controller.save_state(),"territories":territories,
		"economy":{"house_resources":main.district_economy.house_resources.duplicate(true)},
		"buildings":main.district_buildings.state.duplicate(true),
		"building_history":main.district_buildings.history.duplicate(true),
		"retainers":{"appointments":main.retainer_management.appointments.duplicate(true),"technology":main.retainer_management.technology.duplicate(true),
			"loyalty_state":main.retainer_management.loyalty_state.duplicate(true), "house_members":main.retainer_management.house_members.duplicate(true),
			"district_governors":main.retainer_management.district_governors.duplicate(true), "province_governors":main.retainer_management.province_governors.duplicate(true),
			"officer_districts":main.retainer_management.officer_districts.duplicate(true),
			"rebel_houses":main.retainer_management.rebel_houses.duplicate(true)},
		"prestige":main.house_prestige.values.duplicate(true),
		"prestige_court_ranks":main.house_prestige.court_ranks.duplicate(true),
		"technology_orders":main.technology_orders.save_state(),
		"research":main.technology_tree.researched.duplicate(true),
		"armies":{"units":main.army_campaign.units.duplicate(true),"garrisons":main.army_campaign.garrisons.duplicate(true),"occupations":main.army_campaign.occupations.duplicate(true),"next_id":main.army_campaign.next_id}}

func valid_number(v: Variant, minimum: float, maximum: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) >= minimum and float(v) <= maximum

func valid_integer(v: Variant, minimum: int, maximum: int) -> bool:
	return valid_number(v,minimum,maximum) and float(v) == floor(float(v))

func valid_person(v: Variant) -> bool:
	if v == null: return true
	if not v is Dictionary or not v.get("name") is String: return false
	return v.get("officer_id") == null or (v.officer_id is String and v.officer_id in catalog.officer_ids)

func validate(d: Variant) -> bool:
	if not d is Dictionary or not valid_integer(d.get("version"),30,30): return false
	var version := int(d.version)
	var known_houses: Dictionary = catalog.houses.duplicate()
	if version >= 6:
		if not d.get("retainers") is Dictionary or not d.retainers.get("rebel_houses") is Dictionary: return false
		for rebel_id in d.retainers.rebel_houses:
			var rebel: Variant = d.retainers.rebel_houses[rebel_id]
			if not rebel_id is String or not rebel_id.begins_with("rebel_officer_") or not rebel is Dictionary: return false
			if rebel.get("officer_id") not in catalog.officer_ids or rebel_id != "rebel_" + rebel.officer_id or not catalog.houses.has(rebel.get("former_house")): return false
			known_houses[rebel_id] = true
	if not d.get("player_house") is String or not catalog.houses.has(d.player_house) or not catalog.houses[d.player_house].get("loadable", catalog.houses[d.player_house].playable): return false
	if not d.get("clock") is Dictionary or not d.get("camera") is Dictionary or not d.get("territories") is Dictionary or not d.get("relations") is Dictionary: return false
	var c: Dictionary = d.clock
	if not valid_integer(c.get("year"),1546,9999) or not valid_integer(c.get("month"),1,12): return false
	if not valid_integer(c.get("day"),1,preload("res://scripts/game/game_clock.gd").days_in_month(int(c.year),int(c.month))): return false
	if not valid_integer(c.get("elapsed_days"),0,3100000) or not valid_integer(c.get("speed"),1,Clock.SPEEDS.back()) or int(c.speed) not in Clock.SPEEDS or not c.get("paused") is bool or not valid_number(c.get("fraction"),0,1.0): return false
	if not valid_number(c.get("backlog"), 0, Clock.MAX_BACKLOG_DAYS): return false
	if not c.get("work_started") is bool or (not c.work_started and float(c.fraction) != 0.0): return false
	var expected := 0
	for y in range(1546,int(c.year)): expected += 366 if preload("res://scripts/game/game_clock.gd").days_in_month(y,2) == 29 else 365
	for m in range(1,int(c.month)): expected += preload("res://scripts/game/game_clock.gd").days_in_month(int(c.year),m)
	if expected+int(c.day)-1 != int(c.elapsed_days): return false
	var view: Dictionary = d.camera
	if not valid_number(view.get("manual_angle",-1.0),-1.0,90.0) or not valid_number(view.get("yaw",0.0),-180.0,180.0): return false
	if float(view.get("manual_angle",-1.0)) != -1.0 and float(view.get("manual_angle",-1.0)) < 15.0: return false
	if not valid_number(view.get("x"),-20000,20000) or not valid_number(view.get("y"),-20000,20000) or not valid_number(view.get("zoom"),0.001,8) or not view.get("oblique") is bool: return false
	for key in d.relations:
		var ids: PackedStringArray = str(key).split("|")
		if ids.size()!=2 or not known_houses.has(ids[0]) or not known_houses.has(ids[1]) or ids[0]>=ids[1] or d.relations[key] not in ["ally","enemy","neutral"]: return false
	if version >= 12:
		if not d.get("diplomacy") is Dictionary: return false
		for field in ["opinions", "envoys", "truces", "last_actions", "spy_networks", "spies", "claims", "spy_effects"]:
			if not d.diplomacy.get(field) is Dictionary: return false
		for key in d.diplomacy.spy_networks:
			var ids: PackedStringArray = str(key).split(">")
			if ids.size() != 2 or ids[0] == ids[1] or not known_houses.has(ids[0]) or not known_houses.has(ids[1]) or not valid_integer(d.diplomacy.spy_networks[key], 0, 100): return false
		for field in ["envoys", "spies"]:
			for actor in d.diplomacy[field]:
				var targets: Variant = d.diplomacy[field][actor]
				if not known_houses.has(actor) or not targets is Array or targets.is_empty(): return false
				var seen := {}
				for target in targets:
					if not target is String or not known_houses.has(target) or actor == target or seen.has(target): return false
					seen[target] = true
					if field == "spies" and not d.diplomacy.spy_networks.has(actor + ">" + target): return false
		for actor in known_houses:
			if d.diplomacy.envoys.get(actor, []).size() + d.diplomacy.spies.get(actor, []).size() > preload("res://scripts/game/diplomacy.gd").DIPLOMAT_LIMIT: return false
		for actor in d.diplomacy.claims:
			if not known_houses.has(actor) or not d.diplomacy.claims[actor] is Dictionary: return false
			for district_id in d.diplomacy.claims[actor]:
				if not catalog.district_ids.has(district_id) or not valid_integer(d.diplomacy.claims[actor][district_id], 0, 3101825): return false
		for key in d.diplomacy.spy_effects:
			var ids: PackedStringArray = str(key).split(">")
			if ids.size() != 2 or ids[0] not in ["sow_discontent", "sabotage_reputation", "sabotage_recruitment", "slander_merchants"] or not known_houses.has(ids[1]) or not valid_integer(d.diplomacy.spy_effects[key], 0, 3100360): return false
		for key in d.diplomacy.opinions:
			var ids: PackedStringArray = str(key).split(">")
			if ids.size() != 2 or ids[0] == ids[1] or not known_houses.has(ids[0]) or not known_houses.has(ids[1]) or not valid_integer(d.diplomacy.opinions[key], -100, 100): return false
		for key in d.diplomacy.truces:
			var ids: PackedStringArray = str(key).split("|")
			if ids.size() != 2 or ids[0] >= ids[1] or not known_houses.has(ids[0]) or not known_houses.has(ids[1]) or not valid_integer(d.diplomacy.truces[key], 0, 3100000): return false
		for key in d.diplomacy.last_actions:
			var ids: PackedStringArray = str(key).split(">")
			if ids.size() != 2 or ids[0] == ids[1] or not known_houses.has(ids[0]) or not known_houses.has(ids[1]) or not valid_integer(d.diplomacy.last_actions[key], 0, int(c.elapsed_days)): return false
		if not d.diplomacy.get("wars") is Dictionary or not valid_integer(d.diplomacy.get("next_war_id"), 1, 2000000000): return false
		for war_id in d.diplomacy.wars:
			if not war_id is String or not war_id.begins_with("war_") or not war_id.trim_prefix("war_").is_valid_int(): return false
			if int(war_id.trim_prefix("war_")) < 1 or int(war_id.trim_prefix("war_")) >= int(d.diplomacy.next_war_id): return false
			var war: Variant = d.diplomacy.wars[war_id]
			if not war is Dictionary or not known_houses.has(war.get("attacker")) or not known_houses.has(war.get("defender")) or war.attacker == war.defender: return false
			if not war.get("defenders") is Array or war.defender not in war.defenders or not war.get("requests") is Dictionary or not war.get("called") is bool: return false
			if not valid_integer(war.get("started"), 0, int(c.elapsed_days)): return false
			var seen_defenders := {}
			for defender in war.defenders:
				if not defender is String or not known_houses.has(defender) or defender == war.attacker or seen_defenders.has(defender): return false
				seen_defenders[defender] = true
			for ally in war.requests:
				if not known_houses.has(ally) or ally in [war.attacker, war.defender] or war.requests[ally] not in ["pending", "accepted", "declined"]: return false
				if (war.requests[ally] == "accepted") != (ally in war.defenders): return false
	if not d.get("cpu") is Dictionary or not d.cpu.get("plans") is Dictionary or not d.cpu.get("missions") is Dictionary or not d.cpu.get("decisions") is Array or d.cpu.decisions.size() > 300: return false
	if not d.cpu.get("work_queue") is Array or d.cpu.work_queue.size() > 10000: return false
	if not c.work_started:
		for job in d.cpu.work_queue:
			if job is Dictionary and job.get("kind") in ["daily", "world", "power", "schedule"]: return false
	var job_keys := {}
	var job_sequences := {}
	for job in d.cpu.work_queue:
		if not job is Dictionary or not job.get("target") is String: return false
		if job.has("sequence") and not valid_integer(job.sequence, 0, 1000000000000): return false
		var key: String = str(job.get("house")) + "|" + str(job.get("kind")) + "|" + job.target
		if job_keys.has(key): return false
		job_keys[key] = true
		if job.has("sequence"):
			if job_sequences.has(int(job.sequence)): return false
			job_sequences[int(job.sequence)] = true
		if not valid_integer(job.get("day"), 0, int(c.elapsed_days)) or not valid_integer(job.get("priority"), -3, 2): return false
		if job.get("kind") == "daily":
			if job.get("house") != "" or job.target not in ["district_buildings", "district_economy", "house_prestige", "retainer_management", "army_campaign", "district_actions", "diplomacy"]: return false
		elif job.get("kind") in ["world", "schedule"]:
			if job.get("house") != "" or job.target != "": return false
		elif job.get("kind") == "power":
			if not known_houses.has(job.get("house")) or job.target != "": return false
		else:
			if not known_houses.has(job.get("house")) or job.house == d.player_house: return false
			if job.get("kind") not in ["officers", "district", "research", "strategy", "army", "unit"]: return false
			if job.kind == "district":
				if job.target not in catalog.district_ids: return false
			elif job.kind == "unit":
				if not job.target.begins_with("army_") or not job.target.trim_prefix("army_").is_valid_int(): return false
			elif job.target != "": return false
	for house_id in d.cpu.plans:
		if not known_houses.has(house_id) or house_id == d.player_house: return false
		var plan: Variant = d.cpu.plans[house_id]
		if not plan is Dictionary or plan.get("objective") not in ["develop", "defend", "fight", "invade"] or not plan.get("reason") is String: return false
		for field in ["target", "alliance_target"]:
			if not plan.get(field) is String or (plan[field] != "" and not known_houses.has(plan[field])): return false
		if not valid_integer(plan.get("next_strategy"), 0, 3100007) or not valid_integer(plan.get("last_admin"), -1, 120000): return false
		if not valid_integer(plan.get("last_dispatch"), -1, int(c.elapsed_days)): return false
		if not plan.get("cursors") is Dictionary or plan.cursors.size() > 65: return false
		for context in plan.cursors:
			if not context is String or not valid_integer(plan.cursors[context], 0, 10000): return false
		if not plan.get("operation") is Dictionary: return false
		if plan.has("evaluation"):
			var evaluation: Variant = plan.evaluation
			if not evaluation is Dictionary or evaluation.get("action") not in ["invade", "ally"] or not known_houses.has(evaluation.get("target")): return false
			if not valid_number(evaluation.get("value"), 0, 2) or not evaluation.get("scores") is Dictionary or evaluation.scores.size() != 3: return false
			for score in evaluation.scores.values():
				if not valid_number(score, 0, 1): return false
		if not plan.operation.is_empty():
			for field in ["origin", "target", "assembly"]:
				if not valid_army_node(plan.operation.get(field), 26): return false
			if not valid_integer(plan.operation.get("started"), 0, int(c.elapsed_days)) or not valid_integer(plan.operation.get("required_soldiers"), 100, 2000000000): return false
			if not valid_army_node(plan.operation.get("return_to"), 26) or not valid_integer(plan.operation.get("arrival_day"), int(plan.operation.started), 3100120): return false
	for unit_id in d.cpu.missions:
		if not unit_id is String: return false
		var mission: Variant = d.cpu.missions[unit_id]
		if not mission is Dictionary or not mission.get("target") is String or (mission.target != "" and not valid_army_node(mission.target, 18)): return false
		if not valid_integer(mission.get("initial_soldiers"), 100, 2000000000) or not mission.get("returning") is bool: return false
	for decision in d.cpu.decisions:
		if not decision is Dictionary or not known_houses.has(decision.get("house")) or not valid_integer(decision.get("day"), 0, int(c.elapsed_days)): return false
		for field in ["action", "target", "reason"]:
			if not decision.get(field) is String: return false
	for kind in ["districts", "sites"]:
		var ids: Array = catalog.district_ids if kind == "districts" else catalog.site_ids
		if kind == "districts" and d.territories.get(kind) is Dictionary:
			var matched := false
			for layout in [catalog.district_ids, catalog.get("original_district_ids", []), catalog.get("previous_layout_ids", []), catalog.get("overlap_layout_ids", [])]:
				if d.territories[kind].size() != layout.size(): continue
				var complete := true
				for id in layout:
					if not d.territories[kind].has(id): complete = false; break
				if complete: ids = layout; matched = true; break
			if not matched: return false
		if not d.territories.get(kind) is Dictionary or d.territories[kind].size()!=ids.size(): return false
		for id in ids:
			var r: Variant = d.territories[kind].get(id)
			if not r is Dictionary or not r.get("house_id") is String or not known_houses.has(r.house_id) or not r.has("governor") or not r.has("ruler") or not valid_person(r.governor) or not valid_person(r.ruler): return false
			if version == 2 and kind == "districts" and not valid_integer(r.get("population"),0,2000000000): return false
			if version >= 3 and kind == "districts":
				if not valid_number(r.get("occupation_stability"),0,100): return false
				if not valid_integer(r.get("loot_available_day"),0,3100030): return false
				if not valid_integer(r.get("population"),0,2000000000): return false
				if version >= 7 and not valid_integer(r.get("security"),0,100): return false
				for field in ["agriculture_development", "commerce_development"]:
					if not valid_integer(r.get(field),1,30): return false
				for field in ["agriculture_progress", "commerce_progress"]:
					if not valid_number(r.get(field),0,5400): return false
				for field in ["agriculture_developer_id", "commerce_developer_id"]:
					if r.get(field) != null and (not r.get(field) is String or r.get(field) not in catalog.officer_ids): return false
				if version >= 10:
					if not valid_integer(r.get("tax_rate"),20,60) or int(r.tax_rate) % 10 != 0: return false
					if not valid_integer(r.get("infrastructure"),1,10) or not valid_integer(r.get("devastation"),0,100) or not valid_integer(r.get("autonomy"),0,100) or not valid_integer(r.get("defense"),1,10): return false
					if version >= 13 and not valid_integer(r.get("sortie_troops"),0,2000000000): return false
					if version < 13 and not valid_integer(r.get("levied"),0,2000000000): return false
			if r.governor != null and r.governor.get("appointment") not in ["existing_office","historical_office","scenario_direct","scenario_appointment","reference_direct"]: return false
	if version >= 3:
		if not d.get("economy") is Dictionary or not d.economy.get("house_resources") is Dictionary: return false
		for house_id in d.economy.house_resources:
			var resources: Variant = d.economy.house_resources[house_id]
			if not known_houses.has(house_id) or not resources is Dictionary: return false
			if not valid_number(resources.get("money"),0,2000000000) or not valid_integer(resources.get("provisions"),0,2000000000): return false
	if version >= 9:
		if not d.get("buildings") is Dictionary or d.buildings.size() != catalog.district_ids.size(): return false
		if not d.get("building_history") is Array or d.building_history.size() > 2000: return false
		var definitions: Dictionary = preload("res://scripts/game/district_buildings.gd").DEFINITIONS
		for event in d.building_history:
			if not event is Dictionary or event.get("event") not in ["start", "cancel", "complete"]: return false
			if event.get("district_id") not in catalog.district_ids or not definitions.has(event.get("building_id")) or not known_houses.has(event.get("house_id")): return false
			if not valid_integer(event.get("money_change"),-2000000000,2000000000): return false
			if not valid_integer(event.get("year"),1546,9999) or not valid_integer(event.get("month"),1,12): return false
			if not valid_integer(event.get("day"),1,preload("res://scripts/game/game_clock.gd").days_in_month(int(event.year),int(event.month))): return false
		for district_id in catalog.district_ids:
			var entry: Variant = d.buildings.get(district_id)
			if not entry is Dictionary or not entry.get("built") is Array or not entry.has("construction"): return false
			var seen := {}
			for building_id in entry.built:
				if not building_id is String or not definitions.has(building_id) or seen.has(building_id): return false
				seen[building_id] = true
			var construction: Variant = entry.construction
			if construction == null: continue
			if not construction is Dictionary or not definitions.has(construction.get("building_id")) or seen.has(construction.building_id): return false
			if not known_houses.has(construction.get("payer_house_id")): return false
			if not valid_integer(construction.get("paid_cost"),0,2000000000): return false
			for prefix in ["start", "finish"]:
				if not valid_integer(construction.get(prefix + "_year"),1546,9999) or not valid_integer(construction.get(prefix + "_month"),1,12): return false
				if not valid_integer(construction.get(prefix + "_day"),1,preload("res://scripts/game/game_clock.gd").days_in_month(int(construction[prefix + "_year"]),int(construction[prefix + "_month"]))): return false
			if construction.finish_day != 1: return false
			var base_months: int = int(definitions[construction.building_id].months)
			if not valid_integer(construction.get("months"),1,base_months): return false
			if int(construction.months) != base_months and not (construction.building_id == "workshop" and int(construction.months) == base_months - 2): return false
			var expected_finish: Dictionary = preload("res://scripts/game/district_buildings.gd").completion_date(int(construction.start_year),int(construction.start_month),int(construction.start_day),int(construction.months))
			if construction.finish_year != expected_finish.year or construction.finish_month != expected_finish.month: return false
	if version >= 4:
		if not d.get("retainers") is Dictionary or not d.retainers.get("appointments") is Dictionary or not d.retainers.get("technology") is Dictionary: return false
		for house_id in d.retainers.appointments:
			if not known_houses.has(house_id) or not d.retainers.appointments[house_id] is Dictionary: return false
			for officer_id in d.retainers.appointments[house_id]:
				if officer_id not in catalog.officer_ids or d.retainers.appointments[house_id][officer_id] not in ["侍大将", "軍師", "家老", "所司代"]: return false
		for house_id in known_houses:
			var values: Variant = d.retainers.technology.get(house_id)
			if not values is Dictionary: return false
			for field in (["governance", "diplomacy", "military", "agriculture"] if version == 7 else ["governance", "diplomacy", "military"]):
				if not valid_number(values.get(field),0,1000000000): return false
	if version >= 5:
		if not d.get("prestige") is Dictionary or d.prestige.size() != known_houses.size(): return false
		for house_id in known_houses:
			if not valid_number(d.prestige.get(house_id), 0, 100): return false
		if not d.get("prestige_court_ranks") is Dictionary or d.prestige_court_ranks.size() != known_houses.size(): return false
		for house_id in known_houses:
			if not valid_integer(d.prestige_court_ranks.get(house_id), 0, 5): return false
	if version >= 6:
		var retainers: Dictionary = d.retainers
		if not retainers.get("loyalty_state") is Dictionary or not retainers.get("house_members") is Dictionary or not retainers.get("district_governors") is Dictionary or not retainers.get("province_governors") is Dictionary: return false
		if retainers.loyalty_state.size() != catalog.officer_ids.size() or retainers.house_members.size() != known_houses.size(): return false
		for officer_id in catalog.officer_ids:
			var state: Variant = retainers.loyalty_state.get(officer_id)
			if not state is Dictionary: return false
			if not valid_integer(state.get("loyalty"),0,100) or not valid_integer(state.get("required"),0,90): return false
			if not valid_integer(state.get("base_wage_tenths"),1,100) or not valid_integer(state.get("required_wage_tenths"),1,100): return false
			if not valid_integer(state.get("service_start_year"),1546,int(c.year)) or not valid_integer(state.get("last_service_year"),1546,int(c.year)): return false
		for house_id in known_houses:
			if not retainers.house_members.get(house_id) is Array: return false
			for officer_id in retainers.house_members[house_id]:
				if officer_id not in catalog.officer_ids: return false
		for district_id in retainers.district_governors:
			if district_id not in catalog.district_ids or retainers.district_governors[district_id] not in catalog.officer_ids: return false
		for key in retainers.province_governors:
			if not key is String or retainers.province_governors[key] not in catalog.officer_ids: return false
		if not retainers.get("officer_districts") is Dictionary: return false
		for officer_id in retainers.officer_districts:
			var district_id: Variant = retainers.officer_districts[officer_id]
			if officer_id not in catalog.officer_ids or district_id not in catalog.district_ids: return false
			var owner: String = d.territories.districts[district_id].house_id
			var ruler: Variant = d.territories.districts[district_id].ruler
			var is_ruler: bool = ruler is Dictionary and ruler.get("officer_id") == officer_id
			if officer_id not in retainers.house_members.get(owner, []) and not is_ruler: return false
	if version >= 7:
		if not d.get("research") is Dictionary or d.research.size() != known_houses.size(): return false
		var tree = preload("res://scripts/game/technology_tree.gd")
		for house_id in known_houses:
			var progress: Variant = d.research.get(house_id)
			if not progress is Dictionary: return false
			for branch in (["governance", "agriculture"] if version == 7 else tree.BRANCHES.keys()):
				var unlocked: Variant = progress.get(branch)
				if not unlocked is Array or unlocked.size() > tree.BRANCHES[branch].size(): return false
				for index in unlocked.size():
					if unlocked[index] != tree.BRANCHES[branch][index]: return false
	if version >= 11:
		if not d.get("armies") is Dictionary or not d.armies.get("units") is Dictionary or not d.armies.get("garrisons") is Dictionary or not valid_integer(d.armies.get("next_id"),1,100000000): return false
		if not d.armies.get("occupations") is Dictionary: return false
		for district_id in d.armies.occupations:
			var occupation: Variant = d.armies.occupations[district_id]
			if district_id not in catalog.district_ids or not occupation is Dictionary: return false
			if not known_houses.has(occupation.get("house_id")) or not valid_number(occupation.get("progress"),0,99.999999999): return false
			if occupation.house_id == d.territories.districts[district_id].house_id: return false
		for site_id in d.armies.garrisons:
			if site_id not in catalog.site_ids or not valid_integer(d.armies.garrisons[site_id],0,2000000000): return false
		for id in d.armies.units:
			var unit: Variant = d.armies.units[id]
			if not id is String or not unit is Dictionary or unit.get("id") != id: return false
			if not known_houses.has(unit.get("house_id")): return false
			var automatic: Variant = unit.get("automatic")
			if automatic != null:
				if not automatic is Dictionary or unit.house_id != d.player_house: return false
				if automatic.get("mode") not in ["occupy", "battle"] or not known_houses.has(automatic.get("house_id")) or automatic.house_id == unit.house_id: return false
				if not valid_integer(automatic.get("initial_soldiers"),1,2000000000) or not automatic.get("returning") is bool or not automatic.get("target_unit") is String or not automatic.get("status") is String: return false
			if not valid_army_node(unit.get("origin"), version) or not valid_army_node(unit.get("site_id"), version): return false
			if unit.get("next_site") != "" and not valid_army_node(unit.get("next_site"), version): return false
			if not valid_number(unit.get("facing"),-TAU,TAU) or not unit.get("movement_hold") is bool: return false
			if not valid_number(unit.get("bow_reload"),0,10) or not valid_number(unit.get("bow_damage"),0,1) or not valid_number(unit.get("melee_damage"),0,1): return false
			if not valid_number(unit.get("progress"),0,1) or not valid_integer(unit.get("soldiers"),1,2000000000) or not valid_number(unit.get("supply_days"),-100000,120): return false
			if not unit.get("orders") is Array or not unit.get("officers") is Array or unit.officers.is_empty() or unit.officers.size()>3: return false
			if not unit.get("horses") is bool or not unit.get("guns") is bool: return false
			for kind in ["horse", "gun"]:
				if unit.has(kind + "_count") and not valid_integer(unit[kind + "_count"],0,2000000000): return false
			var pool: Variant = unit.get("officer_pool", unit.officers)
			if not pool is Array or pool.is_empty() or pool.size() > catalog.officer_ids.size(): return false
			var unique := {}
			for officer_id in pool:
				if officer_id not in catalog.officer_ids or unique.has(officer_id): return false
				unique[officer_id] = true
			unique.clear()
			for site_id in unit.orders:
				if not valid_army_node(site_id, version): return false
			for officer_id in unit.officers:
				if officer_id not in pool or unique.has(officer_id): return false
				unique[officer_id] = true
	if not valid_technology_orders(d, known_houses): return false
	return true

func valid_technology_orders(d: Dictionary, houses: Dictionary) -> bool:
	var orders: Variant = d.get("technology_orders")
	if not orders is Dictionary or not orders.get("districts") is Dictionary or not orders.get("drills") is Dictionary: return false
	var definitions: Dictionary = preload("res://scripts/game/technology_orders.gd").DEFINITIONS
	for id in orders.districts:
		var j: Variant = orders.districts[id]
		if id not in catalog.district_ids or not j is Dictionary or j.get("kind") not in definitions: return false
		if j.get("house") not in houses or j.has("officer") or not j.get("applied") is bool: return false
		for field in ["start", "ready", "end", "last"]:
			if not valid_integer(j.get(field),0,3100030): return false
		var definition: Dictionary = definitions[j.kind]
		if int(j.ready) != int(j.start)+int(definition.prepare) or int(j.end) != int(j.ready)+int(definition.duration): return false
		if int(j.start) > int(d.clock.elapsed_days) or int(j.last) < int(j.start) or int(j.last) > int(d.clock.elapsed_days): return false
		if not valid_integer(j.get("previous_tax"),20,60) or int(j.previous_tax)%10 != 0: return false
		if j.kind != "negotiation" and j.applied: return false
	for id in orders.drills:
		var drill: Variant = orders.drills[id]
		if not drill is Dictionary or not d.armies.units.has(id): return false
		if not valid_integer(drill.get("ready"),0,3100030) or not valid_integer(drill.get("end"),0,3100030) or int(drill.end) <= int(drill.ready) or int(drill.end)-int(drill.ready)>90: return false
		if not valid_integer(drill.get("soldiers"),1,2000000000): return false
	return true

func valid_army_node(value: Variant, version: int) -> bool:
	if not value is String: return false
	if preload("res://scripts/map/hex_grid.gd").valid(value): return true
	if value in catalog.site_ids: return true
	return version >= 13 and value.begins_with("district:") and value.trim_prefix("district:") in catalog.district_ids

func save_game(main: Node, slot: int) -> Error:
	last_error = ""
	if slot < 1 or slot > 5: return ERR_INVALID_PARAMETER
	var d := capture(main)
	if not validate(d): last_error = "保存するゲーム情報が不正です。"; return ERR_INVALID_DATA
	var payload := JSON.stringify(d)
	var bytes := JSON.stringify({"payload":payload,"sha256":payload.sha256_text()})
	var directory := ProjectSettings.globalize_path(save_directory)
	var err := DirAccess.make_dir_recursive_absolute(directory)
	if err != OK: last_error = "保存フォルダを作成できません。"; return err
	var path := ProjectSettings.globalize_path(path_for(slot))
	var file := FileAccess.open(path+".tmp", FileAccess.WRITE)
	if file == null: last_error = "セーブを書き込めません。"; return FileAccess.get_open_error()
	file.store_string(bytes)
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK: last_error = "セーブの書き込みに失敗しました。"; return err
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(path+".bak")
		err = DirAccess.rename_absolute(path,path+".bak")
		if err != OK: last_error = "既存セーブを保護できません。"; return err
	err = DirAccess.rename_absolute(path+".tmp",path)
	if err != OK:
		if FileAccess.file_exists(path+".bak"): DirAccess.rename_absolute(path+".bak",path)
		last_error = "セーブを確定できません。"
	return err

func read_save(slot: int) -> Dictionary:
	last_error = ""
	if slot < 1 or slot > 5: last_error = "スロットが不正です。"; return {}
	var file := FileAccess.open(path_for(slot),FileAccess.READ)
	if file == null: last_error = "セーブデータがありません。"; return {}
	if file.get_length()>20000000: last_error = "セーブの容量が不正です。"; return {}
	var wrapper: Variant = JSON.parse_string(file.get_as_text())
	if not wrapper is Dictionary or not wrapper.get("payload") is String or wrapper.get("sha256") != str(wrapper.get("payload")).sha256_text():
		last_error = "セーブが破損しています。"; return {}
	var d: Variant = JSON.parse_string(wrapper.payload)
	if not validate(d): last_error = "セーブの形式・年代・人物情報に互換性がありません。"; return {}
	if d.territories.districts.size()!=catalog.district_ids.size():
		for id in catalog.get("district_origins",{}):
			var origin: String = catalog.district_origins[id]
			if not d.territories.districts.has(id):
				d.territories.districts[id] = catalog.get("district_defaults",{}).get(id,d.territories.districts[origin]).duplicate(true)
		for id in d.territories.districts.keys():
			if id not in catalog.district_ids: d.territories.districts.erase(id)
	if int(d.version) < 3:
		d.migration = {"from_version":int(d.version),"economy":"1546年初期人口・開発度・資源から補完"}
	return d

func load_game(slot: int) -> Error:
	var d := read_save(slot)
	if d.is_empty(): return ERR_INVALID_DATA
	player_house = d.player_house
	relations = d.relations.duplicate(true)
	pending = d
	return open_map()

func apply_to(main: Node) -> void:
	if pending.is_empty(): return
	var d := pending
	if int(d.version) >= 6:
		for rebel_id in d.retainers.rebel_houses:
			var rebel: Dictionary = d.retainers.rebel_houses[rebel_id]
			var name: String = main.officer_registry.lookup[rebel.officer_id].display_name
			main.governance_registry.houses[rebel_id] = {"display_name":name + "独立勢力", "ruler":{"officer_id":rebel.officer_id,"name":name,"basis":"gameplay_independence","source_urls":[]}, "governance_type":"personal"}
	for kind in ["districts","sites"]:
		for id in d.territories[kind]:
			for field in ["house_id","ruler","governor"]: main.governance_registry[kind][id][field] = d.territories[kind][id][field]
			if kind == "districts":
				for field in ["population", "security", "agriculture_development", "commerce_development", "agriculture_progress", "commerce_progress", "agriculture_developer_id", "commerce_developer_id", "tax_rate", "infrastructure", "devastation", "autonomy", "defense", "sortie_troops", "occupation_stability", "loot_available_day"]:
					if d.territories[kind][id].has(field): main.governance_registry.districts[id][field] = d.territories[kind][id][field]
	if int(d.version) >= 3:
		main.district_economy.house_resources = d.economy.house_resources.duplicate(true)
	if int(d.version) >= 9:
		main.district_buildings.state = d.buildings.duplicate(true)
		main.district_buildings.history = d.building_history.duplicate(true)
	if int(d.version) >= 4:
		main.retainer_management.appointments = d.retainers.appointments.duplicate(true)
		main.retainer_management.technology = d.retainers.technology.duplicate(true)
		if int(d.version) == 7:
			for house_id in main.retainer_management.technology:
				var points: Dictionary = main.retainer_management.technology[house_id]
				points.governance += points.agriculture
				points.erase("agriculture")
		if int(d.version) >= 6:
			main.retainer_management.loyalty_state = d.retainers.loyalty_state.duplicate(true)
			main.retainer_management.house_members = d.retainers.house_members.duplicate(true)
			main.retainer_management.district_governors = d.retainers.district_governors.duplicate(true)
			main.retainer_management.province_governors = d.retainers.province_governors.duplicate(true)
			main.retainer_management.officer_districts = d.retainers.officer_districts.duplicate(true)
			main.retainer_management.rebel_houses = d.retainers.rebel_houses.duplicate(true)
	else:
		main.retainer_management.appointments.clear()
		for house_id in main.retainer_management.technology:
			main.retainer_management.technology[house_id] = {"governance":0.0,"diplomacy":0.0,"military":0.0}
	if int(d.version) >= 7:
		main.technology_tree.researched = d.research.duplicate(true)
		if int(d.version) == 7:
			for house_id in main.technology_tree.researched:
				main.technology_tree.researched[house_id].commerce = []
	else:
		main.technology_tree.setup(main.governance_registry, main.retainer_management)
		if int(d.version) >= 6:
			for rebel_id in d.retainers.rebel_houses:
				main.technology_tree.researched[rebel_id] = {"governance":[],"agriculture":[],"commerce":[]}
	main.house_prestige.restore_state(d.prestige, d.prestige_court_ranks)
	if int(d.version) >= 12: main.diplomacy.restore_state(d.diplomacy)
	main.cpu_controller.restore_state(d.cpu)
	if int(d.version) < 6:
		main.retainer_management.advance_service_year(int(d.clock.year))
	if int(d.version) >= 11:
		main.technology_orders.districts = d.technology_orders.districts.duplicate(true)
		main.technology_orders.drills = d.technology_orders.drills.duplicate(true)
		main.army_campaign.units = d.armies.units.duplicate(true)
		main.army_campaign.garrisons = d.armies.garrisons.duplicate(true)
		main.army_campaign.occupations = d.armies.occupations.duplicate(true)
		main.army_campaign.next_id = int(d.armies.next_id)
		main.army_campaign.automation.searches.clear()
		main.army_panel.hide_panel()
	main.retainer_management.reconcile_officer_placements()
	main.governance_registry.recount_assignments()
	main.game_clock.restore_state(d.clock)
	main.cpu_controller.refresh_world()
	main.map_view.manual_angle = float(d.camera.get("manual_angle",-1.0))
	main.map_view.yaw = float(d.camera.get("yaw",0.0))
	main.set_oblique(d.camera.oblique)
	main.set_map_zoom(float(d.camera.zoom))
	main.camera.position = Vector2(d.camera.x,d.camera.y)
	main._clamp_camera()
	main._refresh_visible_tiles()
	if is_instance_valid(main.house_status_hud): main.house_status_hud.invalidate()
	pending = {}
