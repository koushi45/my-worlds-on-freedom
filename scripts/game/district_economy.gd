extends Node
## District agriculture, commerce, income, and monthly development simulation.

signal income_collected(kind: String, total: int)
signal house_income_collected(house_id: String, kind: String, amount: int)
signal development_updated

const MIN_DEVELOPMENT := 1
const MAX_DEVELOPMENT := 30
const BASE_VALUE := 10
const MONTHS_TO_MAX_AT_POLITICS_30 := 180
const PROGRESS_TO_MAX := 30 * MONTHS_TO_MAX_AT_POLITICS_30
# Calibrated against the 653-district, 11,108,276-person 1546 ledger: at
# development 1 the nationwide per-district means are 5 money and 50 provisions.
const COMMERCE_POPULATION_FACTOR := 0.0000267204543547695
const AGRICULTURE_POPULATION_FACTOR := 0.000267204543547695
const MONTHLY_POPULATION_GROWTH_RATE := 0.001
const INFRASTRUCTURE_BONUS_PER_LEVEL := 0.05
const MAX_POPULATION := 2000000000

var registry: RefCounted
var officers: RefCounted
var technology_tree: Node
var district_buildings: Node
var technology_orders: Node
var army_campaign: Node
var diplomacy: Node
var house_resources: Dictionary = {}


func setup(governance_registry: RefCounted, officer_registry: RefCounted) -> void:
	registry = governance_registry
	officers = officer_registry
	house_resources.clear()
	for house_id in registry.houses:
		house_resources[house_id] = {"money": 0, "provisions": 0}


func income_for(record: Dictionary, kind: String, preview_building_id: String = "") -> int:
	if army_campaign != null and army_campaign.office_enemy_present(record.id): return 0
	return potential_income_for(record, kind, preview_building_id)

func potential_income_for(record: Dictionary, kind: String, preview_building_id: String = "") -> int:
	var development := int(record.agriculture_development if kind == "agriculture" else record.commerce_development)
	var factor := AGRICULTURE_POPULATION_FACTOR if kind == "agriculture" else COMMERCE_POPULATION_FACTOR
	var multiplier := 1.0
	if kind == "commerce" and diplomacy != null and diplomacy.effect_active("slander_merchants", record.house_id): multiplier *= 0.75
	if technology_tree != null:
		var modifiers: Dictionary = technology_tree.modifiers(record.house_id)
		multiplier *= float(modifiers.provisions if kind == "agriculture" else modifiers.money)
	var facility_multiplier: float = district_buildings.income_multiplier(record.id, kind) if district_buildings != null else 1.0
	if district_buildings != null and preview_building_id in ["irrigation", "farm_estate", "market", "workshop", "temple"] and not district_buildings.state[record.id].built.has(preview_building_id):
		if (kind == "agriculture" and preview_building_id in ["irrigation", "farm_estate"]) or (kind == "commerce" and preview_building_id in ["market", "workshop", "temple"]):
			facility_multiplier += district_buildings.income_bonus(record.id, preview_building_id)
	var local_multiplier := infrastructure_multiplier(record) * (1.0 - float(record.get("devastation", 0)) / 200.0) * (1.0 - float(record.get("autonomy", 0)) / 200.0)
	if float(record.get("occupation_stability", 100.0)) < 100.0: local_multiplier *= 0.5
	return maxi(0, roundi((BASE_VALUE + development) * int(record.population) * factor * facility_multiplier * multiplier * local_multiplier * float(record.get("tax_rate", 40)) / 40.0))


func infrastructure_multiplier(record: Dictionary) -> float:
	return 1.0 + INFRASTRUCTURE_BONUS_PER_LEVEL * float(clampi(int(record.get("infrastructure", 1)), 1, 10) - 1)


func population_growth_for(record: Dictionary) -> int:
	var population := int(record.population)
	var growth := float(population) * MONTHLY_POPULATION_GROWTH_RATE * infrastructure_multiplier(record)
	if technology_tree != null:
		growth = technology_tree.population_growth_for(record.house_id, growth)
	return clampi(roundi(growth), 0, maxi(0, MAX_POPULATION - population))


func collect_income(kind: String) -> int:
	var resource := "provisions" if kind == "agriculture" else "money"
	var total := 0
	var house_totals := {}
	for record in registry.districts.values():
		var amount := income_for(record, kind)
		var house_id: String = record.house_id
		if not house_resources.has(house_id): house_resources[house_id] = {"money": 0, "provisions": 0}
		house_resources[house_id][resource] += amount
		house_totals[house_id] = int(house_totals.get(house_id, 0)) + amount
		total += amount
	for house_id in house_totals:
		if int(house_totals[house_id]) > 0:
			house_income_collected.emit(house_id, kind, int(house_totals[house_id]))
	income_collected.emit(kind, total)
	return total


func politics_for(officer_id: Variant) -> int:
	if not officer_id is String or officer_id.is_empty(): return 0
	var value: Variant = officers.ability(officer_id, "politics")
	return clampi(int(value), 0, 30) if value != null else 0


func assign_developer(district_id: String, kind: String, officer_id: Variant) -> Error:
	if not registry.districts.has(district_id) or kind not in ["agriculture", "commerce"]:
		return ERR_INVALID_PARAMETER
	if officer_id != null and (not officer_id is String or not officers.is_present_at_start(officer_id)):
		return ERR_INVALID_DATA
	registry.districts[district_id][kind + "_developer_id"] = officer_id
	return OK


func develop(record: Dictionary, kind: String) -> void:
	var development_key := kind + "_development"
	var progress_key := kind + "_progress"
	var developer_key := kind + "_developer_id"
	if int(record[development_key]) >= MAX_DEVELOPMENT: return
	var progress := float(politics_for(record.get(developer_key)))
	if technology_orders != null: progress = technology_orders.development_progress(record.id, progress)
	if kind == "commerce" and technology_tree != null:
		progress = technology_tree.commerce_development_for(record.house_id, progress)
	record[progress_key] = minf(PROGRESS_TO_MAX, float(record[progress_key]) + progress)
	record[development_key] = clampi(MIN_DEVELOPMENT + floori(float(record[progress_key]) * (MAX_DEVELOPMENT - MIN_DEVELOPMENT) / PROGRESS_TO_MAX + 0.0000001), MIN_DEVELOPMENT, MAX_DEVELOPMENT)


func advance_month() -> void:
	# Income uses the value established during the preceding month; development
	# then advances for the new month.
	collect_income("commerce")
	for record in registry.districts.values():
		develop(record, "agriculture")
		develop(record, "commerce")
		record.population += population_growth_for(record)
	development_updated.emit()


func on_day_advanced(_year: int, month: int, day: int) -> void:
	if day != 1: return
	if month == 9: collect_income("agriculture")
	advance_month()
