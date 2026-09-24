extends Node
## House appointments, monthly stipends, and accumulated technology.

signal updated
signal loyalty_crisis(officer_id: String, house_id: String, outcome: String)

const BASE_STIPEND := 0.1
const SENIOR_MULTIPLIER := 20.0
const SAMURAI_MULTIPLIER := 5.0
const MAX_LOYALTY := 100
const MAX_REQUIRED_LOYALTY := 90
const ROLES := ["直臣", "侍大将", "軍師", "家老", "所司代"]
const SENIOR_ROLES := ["軍師", "家老", "所司代"]

var governance: RefCounted
var officers: RefCounted
var economy: Node
var appointments: Dictionary = {}
var technology: Dictionary = {}
var house_members: Dictionary = {}
var loyalty_state: Dictionary = {}
var district_governors: Dictionary = {}
var province_governors: Dictionary = {}
var rebel_houses: Dictionary = {}
var prestige: Node
var technology_tree: Node

func setup(governance_registry: RefCounted, officer_registry: RefCounted, district_economy: Node) -> void:
	governance = governance_registry
	officers = officer_registry
	economy = district_economy
	appointments.clear()
	technology.clear()
	house_members.clear()
	loyalty_state.clear()
	district_governors.clear()
	province_governors.clear()
	rebel_houses.clear()
	for house_id in governance.houses:
		house_members[house_id] = []
		technology[house_id] = {"governance": 0.0, "diplomacy": 0.0, "military": 0.0}
	for officer in officers.data.get("officers", []):
		var initial: Dictionary = officers.loyalty_data[officer.id]
		loyalty_state[officer.id] = {"loyalty":int(initial.initial_loyalty), "required":int(initial.initial_required_loyalty), "base_wage_tenths":1, "required_wage_tenths":1, "service_start_year":1546, "last_service_year":1546}
		var affiliation: Dictionary = officer.get("affiliation_1546", {})
		var house_id: Variant = affiliation.get("house_id")
		if house_id is String and house_members.has(house_id) and affiliation.get("can_serve_at_start", false):
			if officer.id != ruler_id(house_id): house_members[house_id].append(officer.id)

func ruler_id(house_id: String) -> String:
	var ruler: Variant = governance.houses.get(house_id, {}).get("ruler")
	return str(ruler.get("officer_id", "")) if ruler is Dictionary else ""

func role_of(house_id: String, officer_id: String) -> String:
	if officer_id == ruler_id(house_id) and not officer_id.is_empty(): return "大名"
	return appointments.get(house_id, {}).get(officer_id, "直臣")

func assign_role(house_id: String, officer_id: String, role: String) -> Error:
	if not house_members.has(house_id) or officer_id not in house_members[house_id] or role not in ROLES:
		return ERR_INVALID_PARAMETER
	if role in SENIOR_ROLES:
		for existing_id in house_members[house_id]:
			if existing_id != officer_id and role_of(house_id, existing_id) == role:
				return ERR_ALREADY_EXISTS
	if not appointments.has(house_id): appointments[house_id] = {}
	if role == "直臣": appointments[house_id].erase(officer_id)
	else: appointments[house_id][officer_id] = role
	if role == "直臣": _remove_governorships(officer_id)
	updated.emit()
	return OK

func stipend_for(house_id: String, officer_id: String) -> float:
	if not house_members.has(house_id) or officer_id not in house_members[house_id]: return 0.0
	var role := role_of(house_id, officer_id)
	var multiplier := SENIOR_MULTIPLIER if role in SENIOR_ROLES else (SAMURAI_MULTIPLIER if role == "侍大将" else 1.0)
	return float(loyalty_state[officer_id].base_wage_tenths) * BASE_STIPEND * multiplier

func set_base_stipend(house_id: String, officer_id: String, amount: float) -> Error:
	if not house_members.has(house_id) or officer_id not in house_members[house_id]: return ERR_INVALID_PARAMETER
	var tenths := roundi(amount * 10.0)
	if tenths < 1 or tenths > 100 or not is_equal_approx(amount, tenths * 0.1): return ERR_INVALID_PARAMETER
	loyalty_state[officer_id].base_wage_tenths = tenths
	updated.emit()
	return OK

func required_loyalty_for(officer_id: String) -> int:
	return mini(MAX_REQUIRED_LOYALTY, int(loyalty_state.get(officer_id, {}).get("required", 35)))

func loyalty_for(house_id: String, officer_id: String) -> int:
	var state: Dictionary = loyalty_state.get(officer_id, {})
	if state.is_empty(): return 0
	var result := int(state.loyalty)
	if house_members.has(house_id) and officer_id in house_members[house_id]:
		var role := role_of(house_id, officer_id)
		result += 10 if role in SENIOR_ROLES else (5 if role == "侍大将" else 0)
		var wage_difference := int(state.base_wage_tenths) - int(state.required_wage_tenths)
		result += wage_difference * (5 if wage_difference > 0 else 10)
		if officer_id in province_governors.values(): result += 10
		elif officer_id in district_governors.values(): result += 5
		if prestige != null:
			var prestige_difference: int = prestige.value_for(house_id) - 50
			if prestige_difference != 0:
				result += signi(prestige_difference) * mini(15, maxi(1, roundi(absi(prestige_difference) * 0.3)))
		if technology_tree != null:
			result += int(technology_tree.modifiers(house_id).loyalty)
	return clampi(result, 0, MAX_LOYALTY)

func is_disloyal(house_id: String, officer_id: String) -> bool:
	return loyalty_for(house_id, officer_id) < required_loyalty_for(officer_id)

func _can_govern(house_id: String, officer_id: String) -> bool:
	return house_members.has(house_id) and officer_id in house_members[house_id] and role_of(house_id, officer_id) != "直臣"

func appoint_district_governor(house_id: String, officer_id: String, district_id: String) -> Error:
	if not _can_govern(house_id, officer_id) or not governance.districts.has(district_id) or governance.districts[district_id].house_id != house_id: return ERR_INVALID_PARAMETER
	district_governors[district_id] = officer_id
	_set_governor(governance.districts[district_id], officer_id, "郡代")
	governance.recount_assignments()
	updated.emit()
	return OK

func appoint_province_governor(house_id: String, officer_id: String, province: String) -> Error:
	if not _can_govern(house_id, officer_id): return ERR_INVALID_PARAMETER
	var found := false
	for district in governance.districts.values():
		if district.house_id == house_id and district.province == province:
			found = true
			district_governors.erase(district.id)
			_set_governor(district, officer_id, "国代")
	if not found: return ERR_INVALID_PARAMETER
	province_governors[house_id + "|" + province] = officer_id
	governance.recount_assignments()
	updated.emit()
	return OK

func _set_governor(district: Dictionary, officer_id: String, title: String) -> void:
	district.governor = {"officer_id": officer_id, "name": officers.lookup[officer_id].display_name, "appointment": "scenario_appointment", "note": title + "として任命（ゲーム設定）。"}

func _remove_governorships(officer_id: String) -> void:
	for district_id in district_governors.keys():
		if district_governors[district_id] == officer_id:
			district_governors.erase(district_id)
			_restore_house_governor(governance.districts[district_id])
	for key in province_governors.keys():
		if province_governors[key] == officer_id:
			province_governors.erase(key)
			for district in governance.districts.values():
				if key == district.house_id + "|" + district.province and district.governor is Dictionary and district.governor.get("officer_id") == officer_id:
					_restore_house_governor(district)
	governance.recount_assignments()

func _restore_house_governor(district: Dictionary) -> void:
	var ruler: Variant = governance.houses.get(district.house_id, {}).get("ruler")
	district.governor = ruler.duplicate(true) if ruler is Dictionary else null
	if district.governor is Dictionary:
		district.governor.appointment = "scenario_direct"
		district.governor.note = "任命解除後の直轄（ゲーム設定）。"

func advance_service_year(year: int) -> void:
	for house_id in house_members:
		for officer_id in house_members[house_id]:
			var state: Dictionary = loyalty_state[officer_id]
			while int(state.last_service_year) < year:
				state.last_service_year += 1
				state.loyalty = mini(MAX_LOYALTY, int(state.loyalty) + 1)
				state.required = mini(MAX_REQUIRED_LOYALTY, int(state.required) + 1)
				if (int(state.last_service_year) - int(state.service_start_year)) % 5 == 0:
					state.required_wage_tenths += 1
					state.base_wage_tenths += 1
	updated.emit()

func transfer_service(officer_id: String, from_house: String, to_house: String, year: int, reason: String = "他家へ出奔") -> Error:
	if not house_members.has(from_house) or not house_members.has(to_house) or officer_id not in house_members[from_house] or from_house == to_house: return ERR_INVALID_PARAMETER
	_remove_governorships(officer_id)
	house_members[from_house].erase(officer_id)
	appointments.get(from_house, {}).erase(officer_id)
	house_members[to_house].append(officer_id)
	var state: Dictionary = loyalty_state[officer_id]
	state.service_start_year = year
	state.last_service_year = year
	state.loyalty = mini(MAX_LOYALTY, maxi(int(state.loyalty), required_loyalty_for(officer_id) + 5))
	updated.emit()
	loyalty_crisis.emit(officer_id, from_house, reason)
	return OK

func hire_officer(house_id: String, officer_id: String, year: int) -> Error:
	if not house_members.has(house_id) or not officers.lookup.has(officer_id) or year < 1546: return ERR_INVALID_PARAMETER
	for existing_house in governance.houses:
		if officer_id == ruler_id(existing_house): return ERR_INVALID_PARAMETER
	for members in house_members.values():
		if officer_id in members: return ERR_ALREADY_EXISTS
	var officer: Dictionary = officers.lookup[officer_id]
	var birth: Variant = officer.get("birth_year_range")
	var death: Variant = officer.get("death_year_range")
	if birth is Array and not birth.is_empty() and birth[0] != null and year < int(birth[0]): return ERR_UNAVAILABLE
	if death is Array and not death.is_empty() and death[1] != null and year > int(death[1]): return ERR_UNAVAILABLE
	house_members[house_id].append(officer_id)
	loyalty_state[officer_id].service_start_year = year
	loyalty_state[officer_id].last_service_year = year
	updated.emit()
	return OK

func on_battle_defection(officer_id: String, from_house: String, opposing_house: String, year: int, unit: Dictionary) -> Error:
	# A future battle system can pass its live unit record when a commander changes sides.
	if unit.get("house_id") != from_house or unit.get("commander_id") != officer_id: return ERR_INVALID_PARAMETER
	if not is_disloyal(from_house, officer_id): return ERR_UNAVAILABLE
	var result := transfer_service(officer_id, from_house, opposing_house, year, "部隊ごと寝返り")
	if result == OK: unit.house_id = opposing_house
	return result

func resolve_loyalty_crises(year: int) -> void:
	var candidates: Array = []
	for house_id in house_members:
		if rebel_houses.has(house_id): continue
		for officer_id in house_members[house_id]:
			if is_disloyal(house_id, officer_id): candidates.append([house_id, officer_id])
	for pair in candidates:
		var house_id: String = pair[0]
		var officer_id: String = pair[1]
		if officer_id not in house_members.get(house_id, []): continue
		var holdings := _governed_districts(house_id, officer_id)
		if not holdings.is_empty():
			declare_independence(house_id, officer_id, holdings)
		else:
			var target := _preferred_new_house(house_id)
			if not target.is_empty(): transfer_service(officer_id, house_id, target, year)

func _governed_districts(house_id: String, officer_id: String) -> Array:
	var result: Array = []
	for district_id in governance.districts:
		var district: Dictionary = governance.districts[district_id]
		if district.house_id != house_id: continue
		if (district_governors.get(district_id) == officer_id if district_governors.has(district_id) else province_governors.get(house_id + "|" + district.province) == officer_id):
			result.append(district_id)
	return result

func _preferred_new_house(from_house: String) -> String:
	var target := ""
	var best := -1
	for house_id in house_members:
		if house_id == from_house or rebel_houses.has(house_id): continue
		var value: int = prestige.value_for(house_id) if prestige != null else 50
		if value > best or (value == best and (target.is_empty() or house_id < target)):
			target = house_id
			best = value
	return target

func declare_independence(house_id: String, officer_id: String, holdings: Array) -> Error:
	if not house_members.has(house_id) or officer_id not in house_members[house_id] or holdings.is_empty(): return ERR_INVALID_PARAMETER
	for district_id in holdings:
		if not governance.districts.has(district_id) or governance.districts[district_id].house_id != house_id: return ERR_INVALID_PARAMETER
	var rebel_id := "rebel_" + officer_id
	if governance.houses.has(rebel_id): return ERR_ALREADY_EXISTS
	var name: String = officers.lookup[officer_id].display_name
	var ruler := {"officer_id":officer_id, "name":name, "basis":"gameplay_independence", "source_urls":[]}
	governance.houses[rebel_id] = {"display_name":name + "独立勢力", "ruler":ruler, "governance_type":"personal"}
	rebel_houses[rebel_id] = {"officer_id":officer_id, "former_house":house_id}
	house_members[rebel_id] = []
	technology[rebel_id] = {"governance":0.0,"diplomacy":0.0,"military":0.0}
	if technology_tree != null: technology_tree.researched[rebel_id] = {"governance":[],"agriculture":[],"commerce":[]}
	economy.house_resources[rebel_id] = {"money":0.0,"provisions":0}
	if prestige != null: prestige.values[rebel_id] = 50
	_remove_governorships(officer_id)
	house_members[house_id].erase(officer_id)
	appointments.get(house_id, {}).erase(officer_id)
	for district_id in holdings:
		var district: Dictionary = governance.districts[district_id]
		district.house_id = rebel_id
		district.ruler = ruler.duplicate(true)
		district.governor = ruler.duplicate(true)
		district.governor.appointment = "scenario_direct"
		district.governor.note = "旧主家から独立（ゲーム内の忠誠危機）。"
		for site_id in district.get("site_ids", []):
			if governance.sites.has(site_id) and governance.sites[site_id].house_id == house_id:
				governance.sites[site_id].house_id = rebel_id
				governance.sites[site_id].ruler = ruler.duplicate(true)
				governance.sites[site_id].governor = district.governor.duplicate(true)
	governance.recount_assignments()
	updated.emit()
	loyalty_crisis.emit(officer_id, house_id, "領地を独立")
	return OK

func monthly_stipend(house_id: String) -> float:
	var total := 0.0
	for officer_id in house_members.get(house_id, []): total += stipend_for(house_id, officer_id)
	return snappedf(total, 0.1)

func _score(officer_id: String, ability_name: String) -> float:
	var score: Variant = officers.ability(officer_id, ability_name)
	return float(score) if score != null else 0.0

func _military(officer_id: String) -> float:
	return (_score(officer_id, "command") + _score(officer_id, "tactics")) / 2.0

func monthly_growth(house_id: String) -> Dictionary:
	var ruler := ruler_id(house_id)
	var growth := {"governance": _score(ruler, "politics"), "diplomacy": _score(ruler, "strategy"), "military": _military(ruler)}
	for officer_id in house_members.get(house_id, []):
		match role_of(house_id, officer_id):
			"軍師": growth.military = (_military(ruler) + _military(officer_id)) * 0.75
			"家老": growth.governance = (_score(ruler, "politics") + _score(officer_id, "politics")) * 0.75
			"所司代": growth.diplomacy = (_score(ruler, "strategy") + _score(officer_id, "strategy")) * 0.75
	return growth

func on_day_advanced(year: int, month: int, day: int) -> void:
	if day != 1: return
	if month == 1 and year > 1546: advance_service_year(year)
	resolve_loyalty_crises(year)
	for house_id in house_members:
		var growth := monthly_growth(house_id)
		for field in growth: technology[house_id][field] += growth[field]
		var resources: Dictionary = economy.house_resources[house_id]
		resources.money = snappedf(maxf(0.0, float(resources.money) - monthly_stipend(house_id)), 0.1)
	updated.emit()
