extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q10524017": ["三宅康貞", "res://assets/officers/portraits/miyake_yasusada_oil_v2.png"],
	"officer_q108781564": ["三宅正次", "res://assets/officers/portraits/miyake_masatsugu_oil_v2.png"],
	"officer_q11355078": ["三宅総広", "res://assets/officers/portraits/miyake_fusahiro_oil_v2.png"],
	"officer_q11355442": ["三戸景道", "res://assets/officers/portraits/mito_kagemichi_oil_v2.png"],
	"officer_q11355591": ["三木国綱", "res://assets/officers/portraits/miki_kunitsuna_oil_v2.png"],
	"officer_q27920679": ["三木清閑", "res://assets/officers/portraits/miki_seikan_oil_v2.png"],
	"officer_q11355682": ["三木直頼", "res://assets/officers/portraits/miki_naoyori_oil_v2.png"],
	"officer_q11355703": ["三木通秋", "res://assets/officers/portraits/miki_michiaki_oil_v2.png"],
	"officer_q11355719": ["三木顕綱", "res://assets/officers/portraits/miki_akitsuna_oil_v2.png"],
	"officer_q6862455": ["三村家親", "res://assets/officers/portraits/mimura_iechika_oil_v2.png"],
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_20260930_batch4"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_20260930_batch4/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(Portraits.texture_for("unknown_officer") == null)
	print("ADOPTED_PORTRAITS_10_OK")
	quit()

