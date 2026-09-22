extends SceneTree
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	var registry = preload("res://scripts/game/officer_registry.gd").new()
	check(registry.load_data() == OK, "registry load")
	check(registry.scenario.get("start_year") == 1546, "start year")
	check(registry.scenario.get("map_reference_year") == 1582, "map year")
	check(registry.is_present_at_start("officer_q171411"), "Nobunaga present")
	check(not registry.is_present_at_start("officer_q907019"), "same-year birth held")
	check(registry.search_ids("官兵衛").has("officer_q907019"), "alias search")
	check(registry.search_ids("家康", "child").has("officer_q171977"), "child filter")
	check(registry.ability("missing_officer", "trust") == null, "unknown ability remains null")
	var rated_ids: Array[String] = registry.search_ids("", "all", true)
	check(rated_ids.size() == 1598, "1598 fully assessed officers")
	for id in rated_ids:
		for key in ["command", "tactics", "strategy", "politics", "trust"]:
			var value: Variant = registry.ability(id, key)
			check(value != null and value >= 1 and value <= 30 and value == floor(value), "integer 1 to 30: " + id + ":" + key)
	var scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(3).timeout
	check(scene.officer_panel.registry.lookup.size() == registry.lookup.size(), "panel roster count")
	scene.officer_panel.show_browser()
	check(scene.officer_panel.matches.size() == 18, "default panel shows eighteen")
	check(scene.officer_panel.matches[0] == "officer_q120403158", "remaining cohort order")
	check(registry.lookup["officer_q311183"].get("total_ability") == 132, "Masamune total")
	check(registry.lookup["officer_q11392554"].get("total_ability") == 60, "provisional total")
	scene.officer_panel.sort_order.select(1)
	scene.officer_panel.refresh_list()
	var previous_total := 151.0
	for id in scene.officer_panel.matches:
		var total: float = registry.lookup[id]["total_ability"]
		check(total <= previous_total, "descending total sort")
		previous_total = total
	scene.officer_panel.search.text = "定治"
	scene.officer_panel.refresh_list()
	check(scene.officer_panel.matches.has("officer_q120403158"), "panel search")
	scene.officer_panel.select_index(scene.officer_panel.matches.find("officer_q120403158"))
	check("総合能力：86 / 150" in scene.officer_panel.details.text, "total displayed")
	check("生涯の能力案" in scene.officer_panel.details.text, "details rendered")
	check("30点満点・1点刻み" in scene.officer_panel.details.text, "new score scale displayed")
	check("項目別の評価理由" in scene.officer_panel.details.text, "per-ability reasons displayed")
	check("成否材料なし" in scene.officer_panel.details.text, "new evidence classification displayed")
	check("標準遂行" in scene.officer_panel.details.text, "standard participation interpretation displayed")
	check(registry.search_ids("", "all", true, "major_60").size() == 60, "old cohort preserved")
	check(registry.search_ids("", "all", false, "notable").size() == 353, "notable selection count")
	check(registry.search_ids("本田忠勝", "unborn").has("officer_q467417"), "Tadakatsu spelling alias")
	check(not registry.is_present_at_start("officer_q467417"), "Tadakatsu unborn at start")
	check(not registry.is_present_at_start("officer_q311183"), "Masamune unborn at start")
	var reference_count := 0
	for officer in registry.lookup.values():
		var assignment: Dictionary = officer.get("affiliation_1546", {})
		if not assignment.get("reference_placement_only", false): continue
		reference_count += 1
		check(officer.get("start_district_id") == null and officer.get("start_affiliation") == null, "reference has no start assignment")
		check(officer.get("reference_district_id") == assignment["district_key"], "reference district retained")
		check(not assignment["can_serve_at_start"], "reference cannot serve")
	check(reference_count == 62, "62 reference-only placements")
	var reserved_count := 0
	for officer in registry.lookup.values():
		var assignment: Dictionary = officer.get("affiliation_1546", {})
		if not assignment.get("future_placement_reserved", false): continue
		reserved_count += 1
		check(not registry.is_present_at_start(officer["id"]), "reserved officer not present: " + officer["id"])
		check(officer.get("start_district_id") == null and officer.get("start_affiliation") == null, "reservation has no start assignment")
		check(officer.get("reserved_district_id") == assignment["district_key"], "reserved district retained")
		check(not assignment["can_serve_at_start"], "reservation cannot serve")
	check(reserved_count == 397, "397 future reservations")
	await create_timer(0.5).timeout
	if "--screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/officers/game_officer_panel.png")
	scene.officer_panel.cohort.select(3)
	scene.officer_panel.cohort.item_selected.emit(3)
	scene.officer_panel.search.text = "伊達政宗"
	scene.officer_panel.refresh_list()
	check(scene.officer_panel.matches.has("officer_q311183"), "unborn visible in notable group")
	scene.officer_panel.select_index(scene.officer_panel.matches.find("officer_q311183"))
	check("未誕生" in scene.officer_panel.details.text, "unborn UI status")
	check("将来用仮配置" in scene.officer_panel.details.text, "future reservation UI status")
	check(not "満年齢目安：0" in scene.officer_panel.details.text, "unborn is not age zero")
	check(registry.search_ids("大友家").has("officer_q6379490"), "house search finds Dosetsu")
	var dosetsu: Dictionary = registry.lookup["officer_q6379490"]["affiliation_1546"]
	check(dosetsu["house_id"] == "otomo", "Dosetsu serves Otomo in 1546")
	check(str(dosetsu["district_display"]).begins_with("豊後国"), "Dosetsu placed in Bungo")
	check(registry.search_ids(dosetsu["district_display"]).has("officer_q6379490"), "district search")
	scene.officer_panel.cohort.select(0)
	scene.officer_panel.search.text = "立花道雪"
	scene.officer_panel.refresh_list()
	scene.officer_panel.select_index(scene.officer_panel.matches.find("officer_q6379490"))
	check("所属家：大友家" in scene.officer_panel.details.text, "affiliation detail displayed")
	check("立場：武将" in scene.officer_panel.details.text, "1546 role displayed")
	check("配置郡：豊後国" in scene.officer_panel.details.text, "district detail displayed")
	check(registry.search_ids("本多家（忠勝系）").has("officer_q467417"), "personal family search")
	check("本人の家系" in scene.officer_panel.details.text, "family details displayed")
	check("戸次家" in scene.officer_panel.details.text, "1546 family distinct from employer")
	check(registry.lookup["officer_q5367620"]["lineage"]["family_id"] != registry.lookup["officer_q7402768"]["lineage"]["family_id"], "same-name Sakai branches distinct")
	check("【父・母・子" in scene.officer_panel.details.text, "relationships displayed")
	check(registry.lookup["officer_q467417"]["relationships"]["father"][0]["external_id"] == "Q11093359", "Tadakatsu father exported")
	var report := {"failures":failures,"registered":registry.lookup.size(),"start_year":registry.scenario.get("start_year"),"map_year":registry.scenario.get("map_reference_year"),"memory_static_bytes":OS.get_static_memory_usage()}
	var file := FileAccess.open("res://docs/officers/godot_smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("OFFICER_SMOKE ", JSON.stringify(report))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
