extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var prestige = preload("res://scripts/game/house_prestige.gd").new()
	prestige.setup(["oda", "takeda"])
	check(prestige.value_for("oda") == 50 and prestige.value_for("takeda") == 50, "each house starts at base prestige")
	check(prestige.on_court_appointment("oda") == OK and prestige.value_for("oda") == 60, "court appointment raises prestige")
	check(prestige.on_war_victory("oda") == OK and prestige.value_for("oda") == 65, "war victory raises prestige")
	check(prestige.on_treaty_broken("oda") == OK and prestige.value_for("oda") == 55, "treaty violation lowers prestige")
	check(prestige.on_unjustified_war_started("oda") == OK and prestige.value_for("oda") == 45, "unjustified war lowers prestige")
	check(prestige.value_for("takeda") == 50, "other houses are unaffected")
	prestige.change("oda", 1000, "test")
	check(prestige.value_for("oda") == 100, "prestige is capped at 100")
	prestige.change("oda", -1000, "test")
	check(prestige.value_for("oda") == 0, "prestige does not fall below zero")
	check(prestige.on_war_victory("missing") == ERR_INVALID_PARAMETER, "unknown house is rejected")
	print("House prestige tests: %d failures" % failures)
	quit(0 if failures == 0 else 1)
