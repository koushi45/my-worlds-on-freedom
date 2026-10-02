extends SceneTree

const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const ABILITIES := ["command", "tactics", "strategy", "politics", "trust"]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var panel := OfficerPanel.new()
	panel.standalone = true
	root.add_child(panel)
	await process_frame
	var registry = panel.registry
	check(registry.lookup.size() == 1598, "1598 officers load")
	check(registry.data.get("score_policy") == "historical_mean15_v3", "current policy loads")
	var means := {}
	for key in ABILITIES:
		var total := 0.0
		for officer in registry.lookup.values():
			var value: Variant = officer.assessment.scores[key]
			check(value != null and value == floor(value) and value >= 1 and value <= 30, "score bounds " + officer.id + ":" + key)
			total += float(value)
		means[key] = total / registry.lookup.size()
		check(absf(means[key] - 15.0) < 0.01, "mean fifteen " + key)
	for officer in registry.lookup.values():
		var total := 0
		for key in ABILITIES: total += int(officer.assessment.scores[key])
		check(total == int(officer.total_ability), "correct total " + officer.id)
		if officer.assessment.get("major_failure_review", {}).get("status") == "major_unrecovered_failure":
			for key in ABILITIES: check(int(officer.assessment.scores[key]) <= 9, "major failure cap " + officer.id)
	panel.show_browser()
	panel.cohort.select(0)
	panel.search.text = "原田宗輔"
	panel.refresh_list()
	check(panel.matches.size() == 1, "failure officer found")
	if panel.matches.size() == 1:
		panel.select_index(0)
		check("重大な失態・挽回なし" in panel.details.text, "failure reason visible")
		check("全能力の低評価" in panel.details.text, "game rule visible")
	panel.search.text = "六角定治"
	panel.refresh_list()
	if panel.matches.size() == 1:
		panel.select_index(0)
		check("ゲーム用補完" in panel.details.text, "imputation identified")
		check("遂行を推定" in panel.details.text, "participation inference identified")
	else:
		check(false, "inferred officer found")
	panel.search.text = "仙石秀久"
	panel.refresh_list()
	if panel.matches.size() == 1:
		panel.select_index(0)
		check("（重大な失態・挽回なし）" not in panel.details.text, "recovered officer not capped")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/officer_reassessment.png")
	var report := {"failures":failures,"count":registry.lookup.size(),"means":means,"policy":registry.data.score_policy}
	var report_path := "res://builds/qa/officer_reassessment_smoke.json"
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null: report_file.store_string(JSON.stringify(report, "  "))
	print("OFFICER_REASSESSMENT ", JSON.stringify(report))
	panel.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
