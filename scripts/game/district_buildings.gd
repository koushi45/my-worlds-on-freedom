extends Node
## District construction and completed building effects.

signal changed(district_id: String)

const DEFINITIONS = preload("res://scripts/game/building_definitions.gd").DEFINITIONS

var registry: RefCounted
var economy: Node
var technology_tree: Node
var clock: Node
var state: Dictionary = {}
var history: Array = []
var last_error := ""
var historical_facilities: Dictionary = {}


func setup(governance_registry: RefCounted, district_economy: Node, tree: Node) -> void:
	registry = governance_registry
	economy = district_economy
	technology_tree = tree
	state.clear()
	history.clear()
	historical_facilities.clear()
	for id in registry.districts:
		state[id] = {"built": [], "construction": null}
		historical_facilities[id] = []
	for site_id in registry.sites:
		var site: Dictionary = registry.sites[site_id]
		if "castle" not in site.get("roles", []) and "port" not in site.get("roles", []): continue
		var district_id := str(site.get("district_key", ""))
		if not registry.districts.has(district_id):
			# Unassigned coastal sites use the nearest district in their province.
			var best := INF
			var location := Vector2(float(site.point[0]), float(site.point[1]))
			var candidates := []
			for id in registry.districts:
				if registry.districts[id].parent == site.parent: candidates.append(id)
			# Some source province IDs differ from the active map's region IDs.
			if candidates.is_empty(): candidates = registry.districts.keys()
			for id in candidates:
				var district: Dictionary = registry.districts[id]
				var distance := location.distance_squared_to(Vector2(float(district.point[0]), float(district.point[1])))
				if distance < best: best = distance; district_id = id
		if not registry.districts.has(district_id):
			push_error("No district for historical building: " + site_id)
			continue
		site.district_key = district_id
		if site_id not in registry.districts[district_id].site_ids: registry.districts[district_id].site_ids.append(site_id)
		historical_facilities[district_id].append(site_id)


func existing_facilities(district_id: String) -> Array:
	return historical_facilities.get(district_id, [])


func slot_capacity(record: Dictionary) -> int:
	# Existing named facilities occupy reserved slots alongside development slots.
	return existing_facilities(str(record.id)).size() + mini(6, 2 + floori(float(int(record.agriculture_development) + int(record.commerce_development)) / 10.0))


func slots_used(district_id: String) -> int:
	var value: Dictionary = state[district_id]
	return existing_facilities(district_id).size() + value.built.size() + (1 if value.construction != null else 0)


func cost_for(district_id: String, building_id: String) -> int:
	if not state.has(district_id) or not DEFINITIONS.has(building_id): return -1
	var base: int = DEFINITIONS[building_id].cost
	if building_id in ["irrigation", "farm_estate"]:
		return technology_tree.agriculture_building_cost_for(registry.districts[district_id].house_id, base)
	return base


func reason_for(district_id: String, building_id: String, house_id: String) -> String:
	if not state.has(district_id) or not DEFINITIONS.has(building_id): return "郡または施設が不正です"
	if house_id != registry.districts[district_id].house_id: return "自家の支配郡ではありません"
	if state[district_id].built.has(building_id): return "建設済みです"
	if state[district_id].construction != null: return "この郡で工事中です"
	if slots_used(district_id) >= slot_capacity(registry.districts[district_id]): return "空き枠がありません"
	if not economy.house_resources.has(house_id) or float(economy.house_resources[house_id].money) < cost_for(district_id, building_id): return "金銭が不足しています"
	return ""


static func completion_date(start_year: int, start_month: int, start_day: int, months: int) -> Dictionary:
	var month_index := start_year * 12 + start_month - 1 + months
	var year := floori(float(month_index) / 12.0)
	var month := month_index % 12 + 1
	if start_day > 1:
		month += 1
		if month > 12:
			month = 1
			year += 1
	return {"year": year, "month": month, "day": 1}


func start_construction(district_id: String, building_id: String, house_id: String, year: int, month: int, day: int) -> Error:
	last_error = reason_for(district_id, building_id, house_id)
	if not last_error.is_empty(): return ERR_UNAVAILABLE
	if year < 1546 or year > 9998 or month < 1 or month > 12: return ERR_INVALID_PARAMETER
	if day < 1 or day > preload("res://scripts/game/game_clock.gd").days_in_month(year, month): return ERR_INVALID_PARAMETER
	var paid := cost_for(district_id, building_id)
	var finish := completion_date(year, month, day, int(DEFINITIONS[building_id].months))
	economy.house_resources[house_id].money -= paid
	_record("start", district_id, building_id, house_id, -paid, year, month, day)
	state[district_id].construction = {"building_id":building_id, "payer_house_id":house_id, "paid_cost":paid,
		"start_year":year, "start_month":month, "start_day":day,
		"finish_year":finish.year, "finish_month":finish.month, "finish_day":finish.day}
	changed.emit(district_id)
	return OK


func cancel_construction(district_id: String, house_id: String) -> Error:
	if not state.has(district_id) or state[district_id].construction == null: return ERR_INVALID_PARAMETER
	if registry.districts[district_id].house_id != house_id: return ERR_UNAUTHORIZED
	_cancel(district_id)
	return OK

func demolish(district_id: String, building_id: String, house_id: String) -> Error:
	if not state.has(district_id) or registry.districts[district_id].house_id != house_id: return ERR_UNAUTHORIZED
	if building_id not in state[district_id].built: return ERR_INVALID_PARAMETER
	state[district_id].built.erase(building_id)
	changed.emit(district_id)
	return OK


func _cancel(district_id: String) -> void:
	var construction: Dictionary = state[district_id].construction
	var payer: String = construction.payer_house_id
	if not economy.house_resources.has(payer): economy.house_resources[payer] = {"money":0, "provisions":0}
	economy.house_resources[payer].money += int(construction.paid_cost)
	if clock != null:
		_record("cancel", district_id, construction.building_id, payer, int(construction.paid_cost), clock.year, clock.month, clock.day)
	state[district_id].construction = null
	changed.emit(district_id)


func on_day_advanced(year: int, month: int, day: int) -> void:
	if day != 1: return
	reconcile_owners()
	for district_id in state:
		var construction: Variant = state[district_id].construction
		if construction == null: continue
		if year * 12 + month < int(construction.finish_year) * 12 + int(construction.finish_month): continue
		state[district_id].built.append(construction.building_id)
		state[district_id].construction = null
		_record("complete", district_id, construction.building_id, construction.payer_house_id, 0, year, month, day)
		changed.emit(district_id)


func reconcile_owners() -> void:
	for district_id in state:
		var construction: Variant = state[district_id].construction
		if construction != null and registry.districts[district_id].house_id != construction.payer_house_id:
			_cancel(district_id)


func income_multiplier(district_id: String, kind: String) -> float:
	if not state.has(district_id): return 1.0
	var bonus := 0.0
	var built: Array = state[district_id].built
	if kind == "agriculture":
		if built.has("irrigation"): bonus += 0.10
		if built.has("farm_estate"): bonus += 0.15
	elif kind == "commerce":
		if built.has("market"): bonus += 0.10
		if built.has("workshop"): bonus += 0.15
		if built.has("temple"): bonus += 0.05
	return 1.0 + bonus


func security_bonus(district_id: String) -> int:
	if not state.has(district_id): return 0
	return (5 if state[district_id].built.has("office") else 0) + (2 if state[district_id].built.has("temple") else 0)


func levy_multiplier(district_id: String) -> float:
	return 1.5 if state.has(district_id) and state[district_id].built.has("barracks") else 1.0


func defense_bonus(district_id: String) -> int:
	return 3 if state.has(district_id) and state[district_id].built.has("fort") else 0


func _record(event: String, district_id: String, building_id: String, house_id: String, amount: int, year: int, month: int, day: int) -> void:
	history.append({"event":event, "district_id":district_id, "building_id":building_id,
		"house_id":house_id, "money_change":amount, "year":year, "month":month, "day":day})
	if history.size() > 2000: history.pop_front()
