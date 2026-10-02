extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q10856548": ["一宮成助", "res://assets/officers/portraits/ichinomiya_narisuke_oil_v2.png"],
	"officer_q11353119": ["一色数馬", "res://assets/officers/portraits/isshiki_kazuma_oil_v2.png"],
	"officer_q11353127": ["一色氏久", "res://assets/officers/portraits/isshiki_ujihisa_oil_v2.png"],
	"officer_q11353137": ["一色直朝", "res://assets/officers/portraits/isshiki_naotomo_oil_v2.png"],
	"officer_q18700613": ["一色義清", "res://assets/officers/portraits/isshiki_yoshikiyo_oil_v2.png"],
	"officer_q11353173": ["一萬田鑑実", "res://assets/officers/portraits/ichimanda_akizane_oil_v2.png"],
	"officer_q7496112": ["七里頼周", "res://assets/officers/portraits/shichiri_yorichika_oil_v2.png"],
	"officer_q123415684": ["三上季直", "res://assets/officers/portraits/mikami_suenao_oil_v2.png"],
	"officer_q11354142": ["三上輝房", "res://assets/officers/portraits/mikami_terufusa_oil_v2.png"],
	"officer_q22127284": ["三刀屋宗忠", "res://assets/officers/portraits/mitoya_munetada_oil_v2.png"],
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_20260930_batch2"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_20260930_batch2/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(Portraits.texture_for("unknown_officer") == null)
	print("ADOPTED_PORTRAITS_10_OK")
	quit()

