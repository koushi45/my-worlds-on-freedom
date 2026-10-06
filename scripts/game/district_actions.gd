extends Node
## Player orders and local conditions for each district.

signal changed(district_id: String)

var registry: RefCounted
var economy: Node
var technology_orders: Node
var buildings: Node
var diplomacy: Node

func setup(governance: RefCounted, district_economy: Node) -> void:
	registry = governance
	economy = district_economy
	for record in registry.districts.values():
		record.infrastructure = 1
		record.tax_rate = 40
		record.devastation = 0
		record.autonomy = 0
		record.defense = 1
		record.occupation_stability = 100.0
		record.loot_available_day = 0
		record.sortie_troops = sortie_capacity(record)

func sortie_capacity(record: Dictionary) -> int:
	var multiplier: float = buildings.levy_multiplier(record.id) if buildings != null else 1.0
	return maxi(0, floori(float(record.population) * 0.05 * multiplier))

func sortie_available(record: Dictionary) -> int:
	if float(record.get("occupation_stability", 100.0)) < 100.0: return 0
	return mini(sortie_capacity(record), int(record.get("sortie_troops", 0)))

func upgrade_cost(record: Dictionary) -> int:
	return 100 * int(record.infrastructure)

func repair_cost(record: Dictionary) -> int:
	return maxi(0, int(record.devastation) * 2)

func _owned(district_id: String, house_id: String) -> bool:
	return registry.districts.has(district_id) and not house_id.is_empty() and registry.districts[district_id].house_id == house_id

func upgrade(district_id: String, house_id: String) -> Error:
	if not _owned(district_id, house_id): return ERR_UNAUTHORIZED
	var record: Dictionary = registry.districts[district_id]
	if int(record.infrastructure) >= 10: return ERR_UNAVAILABLE
	var cost := upgrade_cost(record)
	if float(economy.house_resources[house_id].money) < cost: return ERR_UNAVAILABLE
	economy.house_resources[house_id].money -= cost
	record.infrastructure += 1
	record.defense = int(record.infrastructure)
	changed.emit(district_id)
	return OK

func on_day_advanced(_year: int, _month: int, day: int) -> void:
	if day != 1: return
	for district_id in registry.districts:
		var record: Dictionary = registry.districts[district_id]
		if float(record.get("occupation_stability", 100.0)) < 100.0: continue
		var capacity := sortie_capacity(record)
		var previous := int(record.sortie_troops)
		var recovery := maxi(1, ceili(capacity * 0.01))
		if diplomacy != null and diplomacy.effect_active("sabotage_recruitment", record.house_id): recovery = floori(recovery * 0.8)
		record.sortie_troops = mini(capacity, previous + recovery)
		if int(record.sortie_troops) != previous: changed.emit(district_id)

func repair(district_id: String, house_id: String) -> Error:
	if not _owned(district_id, house_id): return ERR_UNAUTHORIZED
	var record: Dictionary = registry.districts[district_id]
	if int(record.devastation) <= 0: return ERR_UNAVAILABLE
	var cost := repair_cost(record)
	if float(economy.house_resources[house_id].money) < cost: return ERR_UNAVAILABLE
	economy.house_resources[house_id].money -= cost
	record.devastation = 0
	changed.emit(district_id)
	return OK

func set_tax_rate(district_id: String, house_id: String, rate: int) -> Error:
	if not _owned(district_id, house_id): return ERR_UNAUTHORIZED
	if rate < 20 or rate > 60 or rate % 10 != 0: return ERR_INVALID_PARAMETER
	if technology_orders != null and rate > technology_orders.tax_limit(district_id): return ERR_UNAVAILABLE
	registry.districts[district_id].tax_rate = rate
	changed.emit(district_id)
	return OK
