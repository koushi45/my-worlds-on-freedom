extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q11354865": ["三好吉房", "res://assets/officers/portraits/miyoshi_yoshifusa_oil_v2.png"],
	"officer_q5370666": ["三好宗渭", "res://assets/officers/portraits/miyoshi_soi_oil_v2.png"],
	"officer_q1058953": ["三好実休", "res://assets/officers/portraits/miyoshi_jikkyu_oil_v2.png"],
	"officer_q11354925": ["三好政長", "res://assets/officers/portraits/miyoshi_masanaga_oil_v2.png"],
	"officer_q11242378": ["三好為三", "res://assets/officers/portraits/miyoshi_tamezo_oil_v2.png"],
	"officer_q10865734": ["三好義興", "res://assets/officers/portraits/miyoshi_yoshioki_oil_v2.png"],
	"officer_q11354963": ["三好長之", "res://assets/officers/portraits/miyoshi_nagayuki_oil_v2.png"],
	"officer_q1064909": ["三好長慶", "res://assets/officers/portraits/miyoshi_nagayoshi_oil_v2.png"],
	"officer_q23986581": ["三好長虎", "res://assets/officers/portraits/miyoshi_nagatora_oil_v2.png"],
	"officer_q11354967": ["三好長逸", "res://assets/officers/portraits/miyoshi_nagayasu_oil_v2.png"],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture: root.size = Vector2i(1280, 720)
	var panel := OfficerPanel.new()
	panel.standalone = true
	root.add_child(panel)
	await process_frame
	panel.show_browser()
	panel.cohort.select(0)
	for officer_id in TARGETS:
		var expected: Array = TARGETS[officer_id]
		assert(panel.registry.lookup.has(officer_id))
		assert(panel.registry.lookup[officer_id]["display_name"] == expected[0])
		assert(Portraits.PATH_BY_OFFICER_ID[officer_id] == expected[1])
		assert(ResourceLoader.exists(expected[1]))
		var texture := Portraits.texture_for(officer_id)
		assert(texture != null)
		panel.search.text = expected[0]
		panel.refresh_list()
		var index := panel.matches.find(officer_id)
		assert(index >= 0)
		var deadline := Time.get_ticks_msec()+5000
		while panel.items.get_item_icon(index)!=texture and Time.get_ticks_msec()<deadline: await process_frame
		assert(panel.items.get_item_icon(index) == texture)
		panel.items.select(index)
		panel.select_index(index)
		assert(panel.portrait.visible)
		assert(panel.portrait.texture == texture)
		assert(panel.details.text.begins_with(expected[0]))
		if capture:
			await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_20260930_batch3"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_20260930_batch3/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(Portraits.texture_for("unknown_officer") == null)
	print("ADOPTED_PORTRAITS_10_OK")
	quit()

