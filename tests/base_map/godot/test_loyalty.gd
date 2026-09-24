extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var governance = preload("res://scripts/game/governance_registry.gd").new()
	var officers = preload("res://scripts/game/officer_registry.gd").new()
	check(governance.load_data() == OK and officers.load_data() == OK, "source ledgers load")
	check(officers.loyalty_data.size() == officers.lookup.size(), "every officer has loyalty settings")
	for values in officers.loyalty_data.values():
		check(values.initial_loyalty == 40 and int(values.initial_required_loyalty) <= 70, "initial values meet the roster rules")
	check(officers.loyalty_data["officer_q313320"].initial_required_loyalty == 70, "Mitsuhide initial requirement is 70")
	check(officers.loyalty_data["officer_q1143038"].initial_required_loyalty == 70, "Hisahide initial requirement is 70")
	var economy = preload("res://scripts/game/district_economy.gd").new()
	economy.setup(governance, officers)
	var management = preload("res://scripts/game/retainer_management.gd").new()
	management.setup(governance, officers, economy)
	var prestige = preload("res://scripts/game/house_prestige.gd").new()
	prestige.setup(governance.houses.keys())
	management.prestige = prestige
	var house := "takeda"
	var officer_id: String = management.house_members[house][0]
	check(management.loyalty_for(house, officer_id) == 40 and management.required_loyalty_for(officer_id) == 35, "initial active loyalty and requirement")
	check(management.set_base_stipend(house, officer_id, 0.2) == OK, "raise base wage")
	check(management.loyalty_for(house, officer_id) == 45, "0.1 extra wage grants five loyalty")
	check(management.assign_role(house, officer_id, "侍大将") == OK, "promote to samurai captain")
	check(management.loyalty_for(house, officer_id) == 50, "captain adds five loyalty")
	check(is_equal_approx(management.stipend_for(house, officer_id), 1.0), "captain stipend is five times base")
	var district_id := ""
	for id in governance.districts:
		if governance.districts[id].house_id == house: district_id = id; break
	check(not district_id.is_empty(), "house has a district")
	check(management.appoint_district_governor(house, officer_id, district_id) == OK, "captain can govern district")
	check(management.loyalty_for(house, officer_id) == 55, "district office adds loyalty")
	prestige.change(house, 1, "test")
	check(management.loyalty_for(house, officer_id) == 56, "prestige 51 already raises loyalty")
	prestige.change(house, -1, "test")
	prestige.change(house, 50, "test")
	check(management.loyalty_for(house, officer_id) == 70, "prestige contribution is capped at fifteen")
	prestige.change(house, -100, "test")
	check(management.loyalty_for(house, officer_id) == 40, "low prestige subtracts at most fifteen")
	prestige.change(house, 50, "test")
	management.advance_service_year(1551)
	check(management.loyalty_state[officer_id].loyalty == 45 and management.required_loyalty_for(officer_id) == 40, "five service years add five to loyalty and requirement")
	check(management.loyalty_state[officer_id].required_wage_tenths == 2 and management.loyalty_state[officer_id].base_wage_tenths == 3, "five-year demand and automatic raise")
	check(management.set_base_stipend(house, officer_id, 0.1) == OK, "wage may fall below demand")
	check(management.loyalty_for(house, officer_id) == 45, "underpayment deducts ten for each 0.1")
	management.loyalty_state[officer_id].loyalty = 0
	management.loyalty_state[officer_id].required = 90
	management.resolve_loyalty_crises(1551)
	var rebel_id := "rebel_" + officer_id
	check(management.rebel_houses.has(rebel_id), "disloyal governor becomes independent")
	check(governance.districts[district_id].house_id == rebel_id, "governed district changes owner")
	var wanderer: String = management.house_members[house][0]
	management.loyalty_state[wanderer].loyalty = 0
	management.loyalty_state[wanderer].required = 90
	management.resolve_loyalty_crises(1551)
	check(wanderer not in management.house_members[house], "disloyal retainer leaves for another house")
	var battle_officer: String = management.house_members[house][0]
	management.loyalty_state[battle_officer].loyalty = 0
	management.loyalty_state[battle_officer].required = 90
	var unit := {"house_id":house,"commander_id":battle_officer,"troops":100}
	check(management.on_battle_defection(battle_officer, house, "oda_nobuhide", 1551, unit) == OK, "battle defection succeeds")
	check(unit.house_id == "oda_nobuhide" and unit.troops == 100, "entire unit changes sides")
	print("Loyalty tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)
