extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q705860": ["ヤジロウ", "res://assets/officers/portraits/yajiro_oil_v1.png"],
	"officer_q11352614": ["一宮随波斎", "res://assets/officers/portraits/ichinomiya_zuihasai_oil_v1.png"],
	"officer_q2266090": ["一条信龍", "res://assets/officers/portraits/ichijo_nobutatsu_oil_v1.png"],
	"officer_q370505": ["一条兼定", "res://assets/officers/portraits/ichijo_kanesada_oil_v1.png"],
	"officer_q11352818": ["一条房基", "res://assets/officers/portraits/ichijo_fusamoto_oil_v1.png"],
	"officer_q108530286": ["一柳宣高", "res://assets/officers/portraits/ichiyanagi_nobutaka_oil_v1.png"],
	"officer_q11352868": ["一柳直末", "res://assets/officers/portraits/ichiyanagi_naosue_oil_v1.png"],
	"officer_q11352874": ["一柳直高", "res://assets/officers/portraits/ichiyanagi_naotaka_oil_v1.png"],
	"officer_q11352887": ["一栗放牛", "res://assets/officers/portraits/ichikuri_hogyu_oil_v1.png"],
	"officer_q136520820": ["一色政煕", "res://assets/officers/portraits/isshiki_masahiro_oil_v1.png"],
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_20260930"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_20260930/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(Portraits.texture_for("unknown_officer") == null)
	print("ADOPTED_PORTRAITS_10_OK")
	quit()

