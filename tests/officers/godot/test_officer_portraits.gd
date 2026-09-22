extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture: root.size = Vector2i(1280, 720)
	assert(Portraits.PATH_BY_OFFICER_ID.size() == 10)
	var panel := OfficerPanel.new()
	panel.standalone = true
	root.add_child(panel)
	await process_frame
	assert(panel.registry.lookup.size() == 1598)
	for officer_id in Portraits.PATH_BY_OFFICER_ID:
		assert(panel.registry.lookup.has(officer_id))
		assert(ResourceLoader.exists(Portraits.PATH_BY_OFFICER_ID[officer_id]))
		assert(Portraits.texture_for(officer_id) != null)
	panel.show_browser()
	assert(panel.matches.size() == 60)
	var portrait_index := panel.matches.find("officer_q171411")
	assert(portrait_index >= 0)
	panel.select_index(portrait_index)
	assert(panel.portrait.visible)
	assert(panel.portrait.texture != null)
	if capture:
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa"))
		root.get_texture().get_image().save_png("res://builds/qa/officer_portraits.png")
	print("OFFICER_PORTRAITS_OK")
	quit()
