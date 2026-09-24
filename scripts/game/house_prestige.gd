extends Node
## House prestige. Events are called when the corresponding game action resolves.

signal prestige_changed(house_id: String, value: int, reason: String)

const BASE := 50
const MAXIMUM := 100
const COURT_APPOINTMENT_GAIN := 10
const WAR_VICTORY_GAIN := 5
const TREATY_BREACH_LOSS := 10
const UNJUSTIFIED_WAR_LOSS := 10

var values: Dictionary = {}

func setup(house_ids: Array) -> void:
	values.clear()
	for house_id in house_ids:
		values[house_id] = BASE

func value_for(house_id: String) -> int:
	return int(values.get(house_id, BASE))

func change(house_id: String, amount: int, reason: String) -> Error:
	if not values.has(house_id): return ERR_INVALID_PARAMETER
	if amount == 0: return OK
	var updated := clampi(value_for(house_id) + amount, 0, MAXIMUM)
	if updated != value_for(house_id):
		values[house_id] = updated
		prestige_changed.emit(house_id, updated, reason)
	return OK

func on_court_appointment(house_id: String) -> Error:
	return change(house_id, COURT_APPOINTMENT_GAIN, "朝廷から官職を授与")

func on_war_victory(house_id: String) -> Error:
	return change(house_id, WAR_VICTORY_GAIN, "戦争に勝利")

func on_treaty_broken(house_id: String) -> Error:
	return change(house_id, -TREATY_BREACH_LOSS, "条約に違反")

func on_unjustified_war_started(house_id: String) -> Error:
	return change(house_id, -UNJUSTIFIED_WAR_LOSS, "正当性のない戦争を開始")
