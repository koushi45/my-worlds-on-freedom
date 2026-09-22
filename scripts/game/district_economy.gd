extends Node
## District agriculture, commerce, income, and monthly development simulation.

signal income_collected(kind: String, total: int)
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

var registry: RefCounted
var officers: RefCounted
var house_resources: Dictionary = {}


func setup(governance_registry: RefCounted, officer_registry: RefCounted) -> void:
	registry = governance_registry
	officers = officer_registry
	house_resources.clear()
	for house_id in registry.houses:
		house_resources[house_id] = {"money": 0, "provisions": 0}


func income_for(record: Dictionary, kind: String) -> int:
	var development := int(record.agriculture_development if kind == "agriculture" else record.commerce_development)
	var factor := AGRICULTURE_POPULATION_FACTOR if kind == "agriculture" else COMMERCE_POPULATION_FACTOR
	return maxi(0, roundi((BASE_VALUE + development) * int(record.population) * factor))


func collect_income(kind: String) -> int:
	var resource := "provisions" if kind == "agriculture" else "money"
	var total := 0
	for record in registry.districts.values():
		var amount := income_for(record, kind)
		var house_id: String = record.house_id
		if not house_resources.has(house_id): house_resources[house_id] = {"money": 0, "provisions": 0}
		house_resources[house_id][resource] += amount
		total += amount
	income_collected.emit(kind, total)
	return total


func politics_for(officer_id: Variant) -> int:
	if not officer_id is String or officer_id.is_empty(): return 0
	var value: Variant = officers.ability(officer_id, "politics")
	return clampi(int(value), 0, 30) if value != null else 0


func develop(record: Dictionary, kind: String) -> void:
	var development_key := kind + "_development"
	var progress_key := kind + "_progress"
	var developer_key := kind + "_developer_id"
	if int(record[development_key]) >= MAX_DEVELOPMENT: return
	record[progress_key] = minf(PROGRESS_TO_MAX, float(record[progress_key]) + politics_for(record.get(developer_key)))
	record[development_key] = clampi(MIN_DEVELOPMENT + floori(float(record[progress_key]) * (MAX_DEVELOPMENT - MIN_DEVELOPMENT) / PROGRESS_TO_MAX + 0.0000001), MIN_DEVELOPMENT, MAX_DEVELOPMENT)


func advance_month() -> void:
	# Income uses the value established during the preceding month; development
	# then advances for the new month.
	collect_income("commerce")
	for record in registry.districts.values():
		develop(record, "agriculture")
		develop(record, "commerce")
	development_updated.emit()


func on_day_advanced(_year: int, month: int, day: int) -> void:
	if day != 1: return
	if month == 9: collect_income("agriculture")
	advance_month()
