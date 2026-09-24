extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var registry = preload("res://scripts/game/governance_registry.gd").new()
	var officers = preload("res://scripts/game/officer_registry.gd").new()
	check(registry.load_data() == OK and officers.load_data() == OK, "source ledgers load")
	for record in registry.districts.values(): check(record.security == 50, "every district begins at security 50")
	var economy = preload("res://scripts/game/district_economy.gd").new()
	economy.setup(registry, officers)
	var retainers = preload("res://scripts/game/retainer_management.gd").new()
	retainers.setup(registry, officers, economy)
	var tree = preload("res://scripts/game/technology_tree.gd").new()
	tree.setup(registry, retainers)
	retainers.technology_tree = tree
	economy.technology_tree = tree
	var house := "takeda"
	var district: Dictionary
	for record in registry.districts.values():
		if record.house_id == house: district = record; break
	check(not district.is_empty(), "test house has a district")
	check(tree.research(house, "governance", "官僚機構制定") == ERR_INVALID_PARAMETER, "prerequisite enforced")
	check(tree.research(house, "governance", "分国法") == ERR_UNAVAILABLE, "insufficient points rejected")
	retainers.technology[house].governance = 10000.0
	var old_population: int = district.population
	check(tree.research(house, "governance", "分国法") == OK and district.security == 55 and tree.security_for(district) == 55, "law adds five base security")
	var officer_id: String = retainers.house_members[house][0]
	check(tree.research(house, "governance", "官僚機構制定") == OK and retainers.loyalty_for(house, officer_id) == 45, "bureaucracy adds five loyalty")
	check(tree.research(house, "governance", "人口台帳") == OK, "population register researched")
	check(district.population == roundi(old_population * 1.1), "population rises once by ten percent")
	check(tree.research(house, "governance", "人口台帳") == ERR_INVALID_PARAMETER, "research cannot repeat")
	check(tree.research(house, "governance", "城下町制度") == OK and tree.cost_for(house, "楽市") == 950, "town system discounts future research")
	var baseline_money := economy.income_for(district, "commerce")
	check(tree.research(house, "governance", "楽市") == OK, "free market researched")
	check(economy.income_for(district, "commerce") >= baseline_money, "market raises money income")
	check(tree.research(house, "governance", "兵農分離") == OK and tree.security_for(district) == 70, "separation raises security")
	check(tree.research(house, "governance", "武家諸法度") == OK and retainers.loyalty_for(house, officer_id) == 65, "house law adds twenty loyalty")
	retainers.technology[house].governance = 10000.0
	check(not retainers.technology[house].has("agriculture"), "agriculture uses governance points instead of a separate pool")
	check(tree.BRANCHES.commerce.is_empty() and tree.research(house, "commerce", "未設定") == ERR_INVALID_PARAMETER, "commerce branch is present without research nodes")
	var original_food := economy.income_for(district, "agriculture")
	var original_points: float = retainers.technology[house].governance
	for technology_id in tree.BRANCHES.agriculture:
		check(tree.research(house, "agriculture", technology_id) == OK, "agriculture node researched: " + technology_id)
	check(is_equal_approx(retainers.technology[house].governance, original_points - 950.0 * tree.BRANCHES.agriculture.size()), "agriculture deducts discounted governance points")
	var modifiers: Dictionary = tree.modifiers(house)
	check(tree.security_for(district) == 80, "agricultural intervention adds ten security")
	check(is_equal_approx(modifiers.provisions, 2.30), "food modifiers add to 130 percent")
	check(is_equal_approx(modifiers.money, 0.70), "money modifiers net minus thirty percent")
	check(is_equal_approx(modifiers.standing_troops, 1.05), "standing troop changes net plus five percent")
	check(modifiers.agriculture_building_cost_reduction == 15 and is_equal_approx(modifiers.population_growth, 1.15), "future building and growth modifiers exposed")
	check(is_equal_approx(modifiers.drought_damage, 0.75) and is_equal_approx(modifiers.flood_damage, 0.5) and is_equal_approx(modifiers.typhoon_damage, 0.5), "disaster modifiers exposed")
	check(tree.disaster_damage_for(house, "flood", 100) == 50 and tree.disaster_damage_for(house, "drought", 100) == 75, "disaster damage uses research")
	check(tree.agriculture_building_cost_for(house, 100) == 85 and tree.standing_troops_for(house, 100) == 105, "building and troop formulas use research")
	check(is_equal_approx(tree.population_growth_for(house, 100.0), 115.0), "population growth formula uses research")
	check(economy.income_for(district, "agriculture") > original_food, "food production reflects research")
	print("Technology tree tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)
