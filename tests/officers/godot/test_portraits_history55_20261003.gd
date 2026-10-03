extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q108781592": ["三田村国定", "res://assets/officers/portraits/mitamura_kunisada_history_modern_v1.png"],
	"officer_q17212681": ["三田綱秀", "res://assets/officers/portraits/mita_tsunahide_history_modern_v1.png"],
	"officer_q109358474": ["三箇頼照", "res://assets/officers/portraits/sanga_yoriteru_history_modern_v1.png"],
	"officer_q10867117": ["三雲成持", "res://assets/officers/portraits/mikumo_narimochi_history_modern_v1.png"],
	"officer_q7903777": ["上井覚兼", "res://assets/officers/portraits/uwai_kakuken_history_modern_v1.png"],
	"officer_q121643707": ["上坂勘解由", "res://assets/officers/portraits/uesaka_kageyu_history_modern_v1.png"],
	"officer_q8514762": ["上杉定勝", "res://assets/officers/portraits/uesugi_sadakatsu_history_modern_v1.png"],
	"officer_q11359151": ["上杉定実", "res://assets/officers/portraits/uesugi_sadazane_history_modern_v1.png"],
	"officer_q906593": ["上杉憲政", "res://assets/officers/portraits/uesugi_norimasa_history_modern_v1.png"],
	"officer_q1376605": ["上杉景勝", "res://assets/officers/portraits/uesugi_kagekatsu_history_modern_v1.png"],
	"officer_q1190934": ["上杉景虎", "res://assets/officers/portraits/uesugi_kagetora_history_modern_v1.png"],
	"officer_q277361": ["上杉朝定", "res://assets/officers/portraits/uesugi_tomosada_history_modern_v1.png"],
	"officer_q311080": ["上杉謙信", "res://assets/officers/portraits/uesugi_kenshin_history_modern_v1.png"],
	"officer_q6127646": ["上条政繁", "res://assets/officers/portraits/jojo_masashige_history_modern_v1.png"],
	"officer_q119926786": ["上林政重", "res://assets/officers/portraits/kanbayashi_masashige_history_modern_v1.png"],
	"officer_q1375744": ["上泉信綱", "res://assets/officers/portraits/kamiizumi_nobutsuna_history_modern_v1.png"],
	"officer_q17213585": ["下曾根出羽守", "res://assets/officers/portraits/shimosone_dewanokami_history_modern_v1.png"],
	"officer_q17213578": ["下曾根浄喜", "res://assets/officers/portraits/shimosone_joki_history_modern_v1.png"],
	"officer_q50640323": ["下田直久", "res://assets/officers/portraits/shimoda_naohisa_history_modern_v1.png"],
	"officer_q11361411": ["下間仲世", "res://assets/officers/portraits/shimotsuma_nakayo_history_modern_v1.png"],
	"officer_q6606038": ["下間真頼", "res://assets/officers/portraits/shimotsuma_sanrai_history_modern_v1.png"],
	"officer_q11361416": ["下間頼亮", "res://assets/officers/portraits/shimotsuma_yorisuke_history_modern_v1.png"],
	"officer_q7497031": ["下間頼廉", "res://assets/officers/portraits/shimotsuma_rairen_history_modern_v1.png"],
	"officer_q6606120": ["下間頼照", "res://assets/officers/portraits/shimotsuma_raisho_history_modern_v1.png"],
	"officer_q11363126": ["中原善左衛門", "res://assets/officers/portraits/nakahara_zenzaemon_history_modern_v1.png"],
	"officer_q11364066": ["中山勝政", "res://assets/officers/portraits/nakayama_katsumasa_history_modern_v1.png"],
	"officer_q11364086": ["中山勝時", "res://assets/officers/portraits/nakayama_katsutoki_history_modern_v1.png"],
	"officer_q20041913": ["中山田泰吉", "res://assets/officers/portraits/nakayamada_yasuyoshi_history_modern_v1.png"],
	"officer_q11364434": ["中島可之助", "res://assets/officers/portraits/nakajima_kanosuke_history_modern_v1.png"],
	"officer_q11364532": ["中島正時", "res://assets/officers/portraits/nakajima_masatoki_history_modern_v1.png"],
	"officer_q11364622": ["中島豊後守", "res://assets/officers/portraits/nakajima_bungonokami_history_modern_v1.png"],
	"officer_q11364629": ["中島重房", "res://assets/officers/portraits/nakajima_shigefusa_history_modern_v1.png"],
	"officer_q6960145": ["中川清秀", "res://assets/officers/portraits/nakagawa_kiyohide_history_modern_v1.png"],
	"officer_q11364924": ["中川秀成", "res://assets/officers/portraits/nakagawa_hidenari_history_modern_v1.png"],
	"officer_q851268": ["中川秀政", "res://assets/officers/portraits/nakagawa_hidemasa_history_modern_v1.png"],
	"officer_q121648626": ["中村元勝", "res://assets/officers/portraits/nakamura_motokatsu_history_modern_v1.png"],
	"officer_q11365321": ["中村元明", "res://assets/officers/portraits/nakamura_motoaki_history_modern_v1.png"],
	"officer_q45830232": ["中村可近", "res://assets/officers/portraits/nakamura_yoshichika_history_modern_v1.png"],
	"officer_q11365740": ["中村次郎兵衛", "res://assets/officers/portraits/nakamura_jirobe_history_modern_v1.png"],
	"officer_q11366019": ["中村豊重", "res://assets/officers/portraits/nakamura_toyoshige_history_modern_v1.png"],
	"officer_q11366154": ["中条景資", "res://assets/officers/portraits/chujou_kagesuke_history_modern_v1.png"],
	"officer_q11366171": ["中条藤資", "res://assets/officers/portraits/chujou_fujisuke_history_modern_v1.png"],
	"officer_q124483507": ["中西元如", "res://assets/officers/portraits/nakanishi_motoyuki_history_modern_v1.png"],
	"officer_q124426163": ["中野一安", "res://assets/officers/portraits/nakano_kazuyasu_history_modern_v1.png"],
	"officer_q11367555": ["中野宗時", "res://assets/officers/portraits/nakano_munetoki_history_modern_v1.png"],
	"officer_q108459152": ["丸尾義清", "res://assets/officers/portraits/maruo_yoshikiyo_history_modern_v1.png"],
	"officer_q123415498": ["丸毛光兼", "res://assets/officers/portraits/marumo_mitsukane_history_modern_v1.png"],
	"officer_q10877248": ["丸目長恵", "res://assets/officers/portraits/marume_nagayoshi_history_modern_v1.png"],
	"officer_q11368644": ["丹羽氏勝", "res://assets/officers/portraits/niwa_ujikatsu_history_modern_v1.png"],
	"officer_q2900560": ["丹羽長秀", "res://assets/officers/portraits/niwa_nagahide_history_modern_v1.png"],
	"officer_q7048552": ["乃美宗勝", "res://assets/officers/portraits/nomi_munekatsu_history_modern_v1.png"],
	"officer_q123415143": ["乃美景継", "res://assets/officers/portraits/nomi_kagetsugu_history_modern_v1.png"],
	"officer_q123415134": ["乃美景興", "res://assets/officers/portraits/nomi_kageoki_history_modern_v1.png"],
	"officer_q11369424": ["久松俊勝", "res://assets/officers/portraits/hisamatsu_toshikatsu_history_modern_v1.png"],
	"officer_q114590862": ["久松定益", "res://assets/officers/portraits/hisamatsu_sadamasu_history_modern_v1.png"],
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
		assert(texture.get_size() == Vector2(512, 512))
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_history55_20261003"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_history55_20261003/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(FileAccess.file_exists("res://assets/officers/portraits/ATTRIBUTION.txt"))
	assert(Portraits.texture_for("unknown_officer") == null)
	if "--pack-audit" in OS.get_cmdline_user_args():
		for reference_path in ["res://assets/officers/portraits/references/history_modern_20261002/mitamura_kunisada_history_modern_v1_historical.jpg","res://assets/officers/portraits/references/history_modern_20261002/uesugi_sadakatsu_history_modern_v1_historical.jpg","res://assets/officers/portraits/references/history_modern_20261002/uesugi_kagekatsu_history_modern_v1_historical.jpg","res://assets/officers/portraits/references/history_modern_20261002/uesugi_kenshin_history_modern_v1_historical.jpg","res://assets/officers/portraits/references/history_modern_20261002/nakagawa_kiyohide_history_modern_v1_historical.jpg","res://assets/officers/portraits/references/history_modern_20261002/nakagawa_hidenari_history_modern_v1_historical.jpg","res://assets/officers/portraits/references/history_modern_20261002/niwa_nagahide_history_modern_v1_historical.jpg","res://assets/officers/portraits/references/history_modern_20261002/nomi_munekatsu_history_modern_v1_historical.jpg"]:
			assert(not FileAccess.file_exists(reference_path))
			assert(not ResourceLoader.exists(reference_path))
		print("REFERENCE_IMAGES_EXCLUDED_8_OK")
	print("HISTORICAL_MODERN_PORTRAITS_55_OK")
	quit()
