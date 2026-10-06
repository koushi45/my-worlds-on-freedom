extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var prestige = preload("res://scripts/game/house_prestige.gd").new()
	prestige.setup(["oda", "takeda"])
	check(prestige.value_for("oda") == 50.0 and prestige.baseline_for("oda") == 50.0, "initial current value and target are 50")
	prestige.on_day_advanced(1546, 1, 1)
	check(prestige.value_for("oda") == 50.0, "at-target value is unchanged")
	prestige.on_unjustified_war_started("oda")
	prestige.on_day_advanced(1546, 1, 2)
	check(is_equal_approx(prestige.value_for("oda"), 20.3), "20 moves toward 50 by one percent of the difference")
	prestige.values.oda = 80.0
	prestige.on_day_advanced(1546, 1, 3)
	check(is_equal_approx(prestige.value_for("oda"), 79.7), "above-target prestige declines at the same rate")
	prestige.values.oda = 20.0
	for day in range(100): prestige.on_day_advanced(1546, 1, 4)
	check(is_equal_approx(prestige.value_for("oda"), 50.0 - 30.0 * pow(0.99, 100)), "fractional changes accumulate without integer rounding")
	var before: float = prestige.value_for("oda")
	check(prestige.on_court_appointment("oda") == OK and prestige.baseline_for("oda") == 60.0 and prestige.value_for("oda") == before, "court award raises target, leaving current prestige to converge")
	prestige.on_court_appointment("oda")
	check(prestige.baseline_for("oda") == 60.0, "repeated award is not duplicated")
	prestige.on_court_rank_granted("oda", 2)
	prestige.on_court_rank_granted("oda", 1)
	check(prestige.baseline_for("oda") == 70.0, "higher court rank replaces rather than stacks previous rank")
	check(prestige.on_court_rank_granted("oda", 6) == ERR_INVALID_PARAMETER, "invalid rank rejected")
	check(prestige.on_court_appointment("missing") == ERR_INVALID_PARAMETER, "unknown house rejected")
	var registry = preload("res://scripts/game/governance_registry.gd").new()
	registry.districts = {"a1":{"province":"A", "house_id":"oda"}, "a2":{"province":"A", "house_id":"takeda"}, "b1":{"province":"B", "house_id":"oda"}, "c1":{"province":"C", "house_id":"oda"}}
	prestige.governance = registry
	check(prestige.baseline_for("oda") == 90.0 and prestige.baseline_for("takeda") == 50.0, "only fully controlled countries contribute, one bonus per country")
	registry.districts["a3"] = {"province":"A", "house_id":"oda"}
	check(prestige.baseline_for("oda") == 90.0, "additional district in an incomplete country does not change the baseline")
	check(prestige.complete_country_owners().A == "" and prestige.complete_country_counts().oda == 2, "divided country is excluded from country totals")
	registry.districts.a2.house_id = "oda"
	check(prestige.baseline_for("oda") == 100.0, "conquest completes a country and raises baseline")
	registry.districts.a1.house_id = "takeda"
	check(prestige.baseline_for("oda") == 90.0, "losing one district removes full-control bonus")
	registry.districts["b2"] = {"province":"B", "house_id":"oda"}
	check(prestige.baseline_for("oda") == 90.0 and prestige.complete_country_counts().oda == 2, "multiple districts in a complete country still count as exactly one country")
	check("完全支配2国" in prestige.description_for("oda"), "prestige description shows country count explicitly")
	prestige.on_court_rank_granted("oda", 5)
	check(prestige.baseline_for("oda") == 100.0, "rank and country bonuses cap target at 100")
	var saved: Dictionary = JSON.parse_string(JSON.stringify({"values":prestige.values,"ranks":prestige.court_ranks}))
	prestige.setup(["oda", "takeda"], registry)
	prestige.restore_state(saved.values, saved.ranks)
	check(is_equal_approx(prestige.value_for("oda"), before) and prestige.baseline_for("oda") == 100.0, "fractional values and court ranks round-trip through JSON")
	prestige.change("oda", 1000, "test")
	check(prestige.value_for("oda") == 100.0, "current prestige caps at 100")
	prestige.change("oda", -1000, "test")
	check(prestige.value_for("oda") == 0.0, "current prestige floors at zero")
	prestige.on_war_victory("oda")
	prestige.on_treaty_broken("oda")
	check(prestige.value_for("oda") == 0.0 and prestige.value_for("takeda") == 50.0, "event effects and other houses remain independent")
	prestige.register_house("rebel")
	check(prestige.value_for("rebel") == 50.0 and prestige.court_ranks.rebel == 0, "new independent house starts at 50 without inherited court rank")
	prestige.free()
	print("House prestige tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)
