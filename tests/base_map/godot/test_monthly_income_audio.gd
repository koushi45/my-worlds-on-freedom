extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session: Node = root.get_node("GameSession")
	session.player_house = "takeda"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	while not main.initialized or main.game_menu == null:
		await process_frame
	main.game_clock.set_process(false)
	var audio: Node = root.get_node("InteractionAudio")
	var initial_plays: int = audio.income_play_count
	var income_kinds: Array[String] = []
	main.district_economy.house_income_collected.connect(func(house_id: String, kind: String, _amount: int):
		if house_id == session.player_house: income_kinds.append(kind)
	)
	check(audio.income_player.stream.resource_path.ends_with("income_coins_kenney.ogg"), "Kenney coin sound is loaded")
	check(not audio.income_player.stream == audio.player.stream, "income and click have separate streams")
	var original_volume: float = root.get_node("DisplaySettings").sfx_volume
	root.get_node("DisplaySettings").set_sfx_volume(0.35, false)
	check(is_equal_approx(audio.income_player.volume_linear, 0.35), "income respects sound effect volume")
	main.game_clock.day = 31
	var money_before: int = int(main.district_economy.house_resources.takeda.money)
	main.game_clock.advance_real_seconds(1.0)
	check(main.game_clock.month == 2 and main.game_clock.day == 1, "calendar advanced to February")
	check(int(main.district_economy.house_resources.takeda.money) > money_before, "player received monthly money")
	check(income_kinds == ["commerce"], "February has one player income event")
	check(audio.income_play_count == initial_plays + 1, "February income plays one sound")
	main.district_economy.house_income_collected.emit("hojo", "commerce", 100)
	main.district_economy.house_income_collected.emit("takeda", "commerce", 0)
	check(audio.income_play_count == initial_plays + 1, "other houses and zero income stay silent")
	income_kinds.clear()
	main.game_clock.month = 8
	main.game_clock.day = 31
	var provisions_before: int = int(main.district_economy.house_resources.takeda.provisions)
	main.game_clock.advance_real_seconds(1.0)
	check(main.game_clock.month == 9 and main.game_clock.day == 1, "calendar advanced to September")
	check(int(main.district_economy.house_resources.takeda.provisions) > provisions_before, "player received harvest provisions")
	check(income_kinds == ["agriculture", "commerce"], "September records food and money income")
	check(audio.income_play_count == initial_plays + 2, "September plays once for both income types")
	session.player_house = ""
	main.game_clock.month = 9
	main.game_clock.day = 30
	main.game_clock.advance_real_seconds(1.0)
	check(audio.income_play_count == initial_plays + 2, "no selected player stays silent")
	root.get_node("DisplaySettings").set_sfx_volume(original_volume, false)
	main.queue_free()
	await process_frame
	print("Monthly income audio tests: %d failures" % failures)
	quit(1 if failures else 0)
