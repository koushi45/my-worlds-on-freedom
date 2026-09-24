extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var governance = preload("res://scripts/game/governance_registry.gd").new()
	var officers = preload("res://scripts/game/officer_registry.gd").new()
	check(governance.load_data() == OK, "governance loads")
	check(officers.load_data() == OK, "officers load")
	var economy = preload("res://scripts/game/district_economy.gd").new()
	economy.setup(governance, officers)
	var management = preload("res://scripts/game/retainer_management.gd").new()
	management.setup(governance, officers, economy)
	var house := "takeda"
	var members: Array = management.house_members[house]
	check(members.size() >= 3, "house has eligible retainers")
	if members.size() < 3: quit(1); return
	var ruler: String = management.ruler_id(house)
	check(ruler not in members and management.role_of(house, ruler) == "大名", "ruler has no stipend")
	check(is_equal_approx(management.monthly_stipend(house), members.size() * 0.1), "all retainers start as direct retainers")
	var original := management.monthly_growth(house)
	check(is_equal_approx(original.governance, float(officers.ability(ruler, "politics"))), "ruler politics drives governance")
	check(is_equal_approx(original.diplomacy, float(officers.ability(ruler, "strategy"))), "ruler strategy drives diplomacy")
	check(is_equal_approx(original.military, (float(officers.ability(ruler, "command")) + float(officers.ability(ruler, "tactics"))) / 2.0), "ruler military average")
	check(management.assign_role(house, members[0], "軍師") == OK, "appoint strategist")
	check(management.assign_role(house, members[1], "軍師") == ERR_ALREADY_EXISTS, "only one strategist")
	check(management.assign_role(house, members[1], "家老") == OK, "appoint elder")
	check(management.assign_role(house, members[2], "所司代") == OK, "appoint deputy")
	var growth := management.monthly_growth(house)
	check(is_equal_approx(growth.governance, (float(officers.ability(ruler, "politics")) + float(officers.ability(members[1], "politics"))) * 0.75), "elder governance formula")
	check(is_equal_approx(growth.diplomacy, (float(officers.ability(ruler, "strategy")) + float(officers.ability(members[2], "strategy"))) * 0.75), "deputy diplomacy formula")
	var ruler_military := (float(officers.ability(ruler, "command")) + float(officers.ability(ruler, "tactics"))) / 2.0
	var adviser_military := (float(officers.ability(members[0], "command")) + float(officers.ability(members[0], "tactics"))) / 2.0
	check(is_equal_approx(growth.military, (ruler_military + adviser_military) * 0.75), "strategist military formula")
	check(is_equal_approx(management.monthly_stipend(house), (members.size() + 57) * 0.1), "senior roles each cost twenty times base")
	economy.house_resources[house].money = 100.0
	management.on_day_advanced(1546, 1, 2)
	check(is_equal_approx(management.technology[house].governance, 0.0), "other days do not grow technology")
	management.on_day_advanced(1546, 2, 1)
	check(is_equal_approx(management.technology[house].governance, growth.governance), "first of month grows technology")
	check(is_equal_approx(economy.house_resources[house].money, 100.0 - management.monthly_stipend(house)), "first of month deducts stipend")
	print("retainer management failures: ", failures)
	quit(0 if failures == 0 else 1)
