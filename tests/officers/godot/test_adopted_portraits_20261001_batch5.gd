extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q2436811": ["三枝昌貞", "res://assets/officers/portraits/saegusa_masasada_oil_v2.png"],
	"officer_q11355934": ["三枝虎吉", "res://assets/officers/portraits/saegusa_torayoshi_oil_v2.png"],
	"officer_q45829921": ["三沢為清", "res://assets/officers/portraits/misawa_tamekiyo_oil_v2.png"],
	"officer_q11356537": ["三浦義就", "res://assets/officers/portraits/miura_yoshinari_oil_v2.png"],
	"officer_q11356568": ["三浦貞久", "res://assets/officers/portraits/miura_sadahisa_oil_v2.png"],
	"officer_q11356567": ["三浦貞勝", "res://assets/officers/portraits/miura_sadakatsu_oil_v2.png"],
	"officer_q11356569": ["三浦貞広", "res://assets/officers/portraits/miura_sadahiro_oil_v2.png"],
	"officer_q11356570": ["三浦貞盛", "res://assets/officers/portraits/miura_sadamori_oil_v2.png"],
	"officer_q11356601": ["三浦高救", "res://assets/officers/portraits/miura_takasuke_oil_v2.png"],
	"officer_q11356604": ["三淵晴員", "res://assets/officers/portraits/mitsubuchi_harukazu_oil_v2.png"],
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_20261001_batch5"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_20261001_batch5/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(Portraits.texture_for("unknown_officer") == null)
	print("ADOPTED_PORTRAITS_10_OK")
	quit()

