extends Node
## Lightweight session and validated JSON saves; never preload the map scene here.
const CATALOG := "res://data/derived/scenarios/house_selection_1546.json"
const DIPLOMACY := "res://data/derived/scenarios/diplomacy_1546.json"
var catalog: Dictionary = {}
var player_house := ""
var relations: Dictionary = {}
var pending: Dictionary = {}
var last_error := ""
var save_directory := "user://saves"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))

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
	main.governance_registry.recount_assignments()
	var territories := {}
	for kind in ["districts", "sites"]:
		territories[kind] = {}
		for id in main.governance_registry[kind]:
			var r: Dictionary = main.governance_registry[kind][id]
			territories[kind][id] = {"house_id":r.house_id,"governor":r.governor,"ruler":r.ruler}
			if kind == "districts":
				for field in ["population", "security", "agriculture_development", "commerce_development", "agriculture_progress", "commerce_progress", "agriculture_developer_id", "commerce_developer_id"]:
					territories[kind][id][field] = r[field]
	var c: Node = main.game_clock
	return {"version":8,"saved_at":Time.get_datetime_string_from_system(),"player_house":player_house,
		"clock":{"year":c.year,"month":c.month,"day":c.day,"elapsed_days":c.elapsed_days,"speed":c.speed,"paused":c.paused,"fraction":c._day_fraction},
		"camera":{"x":main.camera.position.x,"y":main.camera.position.y,"zoom":main.camera.zoom.x,"oblique":main.elevation.enabled},
		"relations":relations.duplicate(true),"territories":territories,
		"economy":{"house_resources":main.district_economy.house_resources.duplicate(true)},
		"retainers":{"appointments":main.retainer_management.appointments.duplicate(true),"technology":main.retainer_management.technology.duplicate(true),
			"loyalty_state":main.retainer_management.loyalty_state.duplicate(true), "house_members":main.retainer_management.house_members.duplicate(true),
			"district_governors":main.retainer_management.district_governors.duplicate(true), "province_governors":main.retainer_management.province_governors.duplicate(true),
			"rebel_houses":main.retainer_management.rebel_houses.duplicate(true)},
		"prestige":main.house_prestige.values.duplicate(true),
		"research":main.technology_tree.researched.duplicate(true)}

func valid_number(v: Variant, minimum: float, maximum: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) >= minimum and float(v) <= maximum

func valid_integer(v: Variant, minimum: int, maximum: int) -> bool:
	return valid_number(v,minimum,maximum) and float(v) == floor(float(v))

func valid_person(v: Variant) -> bool:
	if v == null: return true
	if not v is Dictionary or not v.get("name") is String: return false
	return v.get("officer_id") == null or (v.officer_id is String and v.officer_id in catalog.officer_ids)

func validate(d: Variant) -> bool:
	if not d is Dictionary or not valid_integer(d.get("version"),1,8): return false
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
	if not valid_integer(c.get("elapsed_days"),0,3100000) or not valid_integer(c.get("speed"),1,8) or int(c.speed) not in [1,2,4,8] or not c.get("paused") is bool or not valid_number(c.get("fraction"),0,0.999999999): return false
	var expected := 0
	for y in range(1546,int(c.year)): expected += 366 if preload("res://scripts/game/game_clock.gd").days_in_month(y,2) == 29 else 365
	for m in range(1,int(c.month)): expected += preload("res://scripts/game/game_clock.gd").days_in_month(int(c.year),m)
	if expected+int(c.day)-1 != int(c.elapsed_days): return false
	var view: Dictionary = d.camera
	if not valid_number(view.get("x"),-20000,20000) or not valid_number(view.get("y"),-20000,20000) or not valid_number(view.get("zoom"),0.001,4) or not view.get("oblique") is bool: return false
	for key in d.relations:
		var ids: PackedStringArray = str(key).split("|")
		if ids.size()!=2 or not known_houses.has(ids[0]) or not known_houses.has(ids[1]) or ids[0]>=ids[1] or d.relations[key] not in ["ally","enemy","neutral"]: return false
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
				if not valid_integer(r.get("population"),0,2000000000): return false
				if version >= 7 and not valid_integer(r.get("security"),0,100): return false
				for field in ["agriculture_development", "commerce_development"]:
					if not valid_integer(r.get(field),1,30): return false
				for field in ["agriculture_progress", "commerce_progress"]:
					if not valid_number(r.get(field),0,5400): return false
				for field in ["agriculture_developer_id", "commerce_developer_id"]:
					if r.get(field) != null and (not r.get(field) is String or r.get(field) not in catalog.officer_ids): return false
			if r.governor != null and r.governor.get("appointment") not in ["existing_office","historical_office","scenario_direct","scenario_appointment","reference_direct"]: return false
	if version >= 3:
		if not d.get("economy") is Dictionary or not d.economy.get("house_resources") is Dictionary: return false
		for house_id in d.economy.house_resources:
			var resources: Variant = d.economy.house_resources[house_id]
			if not known_houses.has(house_id) or not resources is Dictionary: return false
			if not valid_number(resources.get("money"),0,2000000000) or not valid_integer(resources.get("provisions"),0,2000000000): return false
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
			if not valid_integer(d.prestige.get(house_id), 0, 100): return false
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
	return true

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
				for field in ["population", "security", "agriculture_development", "commerce_development", "agriculture_progress", "commerce_progress", "agriculture_developer_id", "commerce_developer_id"]:
					if d.territories[kind][id].has(field): main.governance_registry.districts[id][field] = d.territories[kind][id][field]
	if int(d.version) >= 3:
		main.district_economy.house_resources = d.economy.house_resources.duplicate(true)
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
	if int(d.version) >= 5:
		main.house_prestige.values = d.prestige.duplicate(true)
	else:
		main.house_prestige.setup(main.governance_registry.houses.keys())
	if int(d.version) < 6:
		main.retainer_management.advance_service_year(int(d.clock.year))
	main.governance_registry.recount_assignments()
	main.game_clock.restore_state(d.clock)
	if main.elevation.enabled != d.camera.oblique: main.set_oblique(d.camera.oblique)
	main.set_map_zoom(float(d.camera.zoom))
	main.camera.position = Vector2(d.camera.x,d.camera.y)
	main._clamp_camera()
	main._refresh_visible_tiles()
	pending = {}
