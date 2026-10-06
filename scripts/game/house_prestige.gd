extends Node
## Prestige events change the current value; rank and territory change its target.
signal prestige_changed(house_id: String, value: float, reason: String)
signal baseline_changed(house_id: String, value: float, reason: String)

const BASE := 50.0
const MAXIMUM := 100.0
const DAILY_RATE := 0.01
const COURT_RANK_BASE_GAIN := 10.0
const MAX_COURT_RANK := 5
const COMPLETE_COUNTRY_BASE_GAIN := 10.0
const WAR_VICTORY_GAIN := 5
const TREATY_BREACH_LOSS := 10
const UNJUSTIFIED_WAR_LOSS := 30

var values: Dictionary = {}
var court_ranks: Dictionary = {}
var governance: RefCounted

func setup(house_ids: Array, registry: RefCounted = null) -> void:
	governance = registry
	values.clear()
	court_ranks.clear()
	for house_id in house_ids: register_house(house_id)

func register_house(house_id: String) -> void:
	values[house_id] = BASE
	court_ranks[house_id] = 0

func value_for(house_id: String) -> float:
	return float(values.get(house_id, BASE))

func complete_country_owners() -> Dictionary:
	# province is the historical country name, not a district name. Island
	# countries (Tsushima/Awaji) keep their country even when map parents differ.
	var owners := {}
	if governance == null: return owners
	for district in governance.districts.values():
		var country: String = str(district.get("province", district.get("parent", "")))
		if country.is_empty(): continue
		var owner: String = district.house_id
		if not owners.has(country): owners[country] = owner
		elif owners[country] != owner: owners[country] = ""
	return owners

func complete_country_counts() -> Dictionary:
	var counts := {}
	for owner in complete_country_owners().values():
		if not str(owner).is_empty(): counts[owner] = int(counts.get(owner, 0)) + 1
	return counts

func baseline_for(house_id: String) -> float:
	return _baseline(house_id, complete_country_counts())

func _baseline(house_id: String, counts: Dictionary) -> float:
	return minf(MAXIMUM, BASE + int(court_ranks.get(house_id, 0)) * COURT_RANK_BASE_GAIN + int(counts.get(house_id, 0)) * COMPLETE_COUNTRY_BASE_GAIN)

func description_for(house_id: String) -> String:
	var counts := complete_country_counts()
	return "威信：%.1f / 100\n基準値：%.1f（初期50・朝廷階位＋%.0f・完全支配%d国＋%.0f）\n毎日、基準値との差の1%%だけ推移" % [value_for(house_id), _baseline(house_id, counts), int(court_ranks.get(house_id, 0)) * COURT_RANK_BASE_GAIN, int(counts.get(house_id, 0)), int(counts.get(house_id, 0)) * COMPLETE_COUNTRY_BASE_GAIN]

func change(house_id: String, amount: float, reason: String) -> Error:
	if not values.has(house_id): return ERR_INVALID_PARAMETER
	_set_value(house_id, clampf(value_for(house_id) + amount, 0.0, MAXIMUM), reason)
	return OK

func _set_value(house_id: String, updated: float, reason: String) -> void:
	if updated != value_for(house_id):
		values[house_id] = updated
		prestige_changed.emit(house_id, updated, reason)

func on_day_advanced(_year: int, _month: int, _day: int) -> void:
	var counts := complete_country_counts()
	for house_id in values:
		var current := value_for(house_id)
		_set_value(house_id, current + (_baseline(house_id, counts) - current) * DAILY_RATE, "基準値へ毎日1%推移")

func on_court_appointment(house_id: String, rank_level := 1) -> Error:
	return on_court_rank_granted(house_id, rank_level)

func on_court_rank_granted(house_id: String, rank_level: int) -> Error:
	if not values.has(house_id) or rank_level < 1 or rank_level > MAX_COURT_RANK: return ERR_INVALID_PARAMETER
	# A repeated award of the same or a lower rank never stacks the bonus.
	if rank_level <= int(court_ranks[house_id]): return OK
	court_ranks[house_id] = rank_level
	baseline_changed.emit(house_id, baseline_for(house_id), "朝廷から階位を授与")
	return OK

func restore_state(current_values: Dictionary, ranks: Dictionary) -> void:
	values = current_values.duplicate(true)
	court_ranks = ranks.duplicate(true)
	for house_id in values: values[house_id] = float(values[house_id])
	for house_id in court_ranks: court_ranks[house_id] = int(court_ranks[house_id])

func on_war_victory(house_id: String) -> Error:
	return change(house_id, WAR_VICTORY_GAIN, "戦争に勝利")

func on_treaty_broken(house_id: String) -> Error:
	return change(house_id, -TREATY_BREACH_LOSS, "条約に違反")

func on_unjustified_war_started(house_id: String) -> Error:
	return change(house_id, -UNJUSTIFIED_WAR_LOSS, "正当性のない戦争を開始")
