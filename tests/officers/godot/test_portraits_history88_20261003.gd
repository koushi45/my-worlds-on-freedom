extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q22127318": ["久野宗能", "res://assets/officers/portraits/kuno_muneyoshi_history_modern_v1.png"],
	"officer_q124483506": ["乙部八兵衛", "res://assets/officers/portraits/otobe_hachibe_history_modern_v1.png"],
	"officer_q10878858": ["九戸実親", "res://assets/officers/portraits/kunohe_sanechika_history_modern_v1.png"],
	"officer_q10878859": ["九戸政実", "res://assets/officers/portraits/kunohe_masazane_history_modern_v1.png"],
	"officer_q921113": ["九鬼嘉隆", "res://assets/officers/portraits/kuki_yoshitaka_history_modern_v1.png"],
	"officer_q11370616": ["乾和信", "res://assets/officers/portraits/inui_kazunobu_history_modern_v1.png"],
	"officer_q11370766": ["亀井秀綱", "res://assets/officers/portraits/kamei_hidetsuna_history_modern_v1.png"],
	"officer_q11371466": ["二宮俊実", "res://assets/officers/portraits/ninomiya_toshizane_history_modern_v1.png"],
	"officer_q11371474": ["二宮就辰", "res://assets/officers/portraits/ninomiya_naritoki_history_modern_v1.png"],
	"officer_q11371623": ["二本松家泰", "res://assets/officers/portraits/nihonmatsu_ieyasu_history_modern_v1.png"],
	"officer_q11371630": ["二本松晴国", "res://assets/officers/portraits/nihonmatsu_harukuni_history_modern_v1.png"],
	"officer_q11371633": ["二本松義国", "res://assets/officers/portraits/nihonmatsu_yoshikuni_history_modern_v1.png"],
	"officer_q11371635": ["二本松義氏", "res://assets/officers/portraits/nihonmatsu_yoshiuji_history_modern_v1.png"],
	"officer_q119380506": ["二見密蔵院", "res://assets/officers/portraits/futami_mitsuzoin_history_modern_v1.png"],
	"officer_q10880505": ["二階堂盛義 (二階堂照行の嫡男)", "res://assets/officers/portraits/nikaido_moriyoshi_history_modern_v1.png"],
	"officer_q11372012": ["五代友喜", "res://assets/officers/portraits/godai_tomoyoshi_history_modern_v1.png"],
	"officer_q11372815": ["井上之房", "res://assets/officers/portraits/inoue_yukifusa_history_modern_v1.png"],
	"officer_q30936868": ["井上元吉", "res://assets/officers/portraits/inoue_motokichi_history_modern_v1.png"],
	"officer_q57446929": ["井上大九郎", "res://assets/officers/portraits/inoue_daikuro_history_modern_v1.png"],
	"officer_q30936452": ["井上就在", "res://assets/officers/portraits/inoue_nariari_history_modern_v1.png"],
	"officer_q30936910": ["井上有景", "res://assets/officers/portraits/inoue_arikage_history_modern_v1.png"],
	"officer_q5994900": ["井伊直勝", "res://assets/officers/portraits/ii_naokatsu_history_modern_v1.png"],
	"officer_q877175": ["井伊直孝", "res://assets/officers/portraits/ii_naotaka_history_modern_v1.png"],
	"officer_q22123202": ["井伊直平", "res://assets/officers/portraits/ii_naohira_history_modern_v1.png"],
	"officer_q1334437": ["井伊直政", "res://assets/officers/portraits/ii_naomasa_history_modern_v1.png"],
	"officer_q3208778": ["井伊直盛", "res://assets/officers/portraits/ii_naomori_history_modern_v1.png"],
	"officer_q11161448": ["井伊直虎", "res://assets/officers/portraits/ii_naotora_history_modern_v1.png"],
	"officer_q5994890": ["井伊直親", "res://assets/officers/portraits/ii_naochika_history_modern_v1.png"],
	"officer_q17219432": ["亘理元宗", "res://assets/officers/portraits/watari_motomune_history_modern_v1.png"],
	"officer_q11373838": ["亘理重宗", "res://assets/officers/portraits/watari_shigemune_history_modern_v1.png"],
	"officer_q11374423": ["京極忠高", "res://assets/officers/portraits/kyogoku_tadataka_history_modern_v1.png"],
	"officer_q11374455": ["京極高吉", "res://assets/officers/portraits/kyogoku_takayoshi_history_modern_v1.png"],
	"officer_q11374462": ["京極高広", "res://assets/officers/portraits/kyogoku_takahiro_history_modern_v1.png"],
	"officer_q587980": ["京極高次", "res://assets/officers/portraits/kyogoku_takatsugu_history_modern_v1.png"],
	"officer_q11374482": ["京極高知", "res://assets/officers/portraits/kyogoku_takatomo_history_modern_v1.png"],
	"officer_q24872446": ["仁木友梅", "res://assets/officers/portraits/niki_yubai_history_modern_v1.png"],
	"officer_q24872537": ["仁木義広", "res://assets/officers/portraits/niki_yoshihiro_history_modern_v1.png"],
	"officer_q24872437": ["仁木長政", "res://assets/officers/portraits/niki_nagamasa_history_modern_v1.png"],
	"officer_q98082960": ["今井信乂", "res://assets/officers/portraits/imai_nobukata_history_modern_v1.png"],
	"officer_q98082730": ["今井信甫", "res://assets/officers/portraits/imai_nobusuke_history_modern_v1.png"],
	"officer_q102246588": ["今井信良", "res://assets/officers/portraits/imai_nobuyoshi_history_modern_v1.png"],
	"officer_q16199820": ["今井定清", "res://assets/officers/portraits/imai_sadakiyo_history_modern_v1.png"],
	"officer_q3100078": ["今川氏真", "res://assets/officers/portraits/imagawa_ujizane_history_modern_v1.png"],
	"officer_q11376923": ["今川氏豊", "res://assets/officers/portraits/imagawa_ujitoyo_history_modern_v1.png"],
	"officer_q1054305": ["今川義元", "res://assets/officers/portraits/imagawa_yoshimoto_history_modern_v1.png"],
	"officer_q123415655": ["今村勝長", "res://assets/officers/portraits/imamura_katsunaga_history_modern_v1.png"],
	"officer_q24861607": ["今泉盛泰", "res://assets/officers/portraits/imaizumi_moriyasu_history_modern_v1.png"],
	"officer_q24861689": ["今泉盛高", "res://assets/officers/portraits/imaizumi_moritaka_history_modern_v1.png"],
	"officer_q124483511": ["今田長佳", "res://assets/officers/portraits/imaida_nagayoshi_history_modern_v1.png"],
	"officer_q108781068": ["仙石定盛", "res://assets/officers/portraits/sengoku_sadamori_history_modern_v1.png"],
	"officer_q11378173": ["仙石忠政", "res://assets/officers/portraits/sengoku_tadamasa_history_modern_v1.png"],
	"officer_q7450595": ["仙石秀久", "res://assets/officers/portraits/sengoku_hidehisa_history_modern_v1.png"],
	"officer_q11378186": ["仙石秀範", "res://assets/officers/portraits/sengoku_hidenori_history_modern_v1.png"],
	"officer_q109318863": ["仲井市之進", "res://assets/officers/portraits/nakai_ichinoshin_history_modern_v1.png"],
	"officer_q11378778": ["伊丹康直", "res://assets/officers/portraits/itami_yasunao_history_modern_v1.png"],
	"officer_q11378792": ["伊丹総堅", "res://assets/officers/portraits/itami_soken_history_modern_v1.png"],
	"officer_q11379128": ["伊勢貞孝", "res://assets/officers/portraits/ise_sadataka_history_modern_v1.png"],
	"officer_q62601657": ["伊勢貞就", "res://assets/officers/portraits/ise_sadanari_history_modern_v1.png"],
	"officer_q27917417": ["伊勢貞良", "res://assets/officers/portraits/ise_sadayoshi_history_modern_v1.png"],
	"officer_q62601654": ["伊勢貞辰", "res://assets/officers/portraits/ise_sadatatsu_history_modern_v1.png"],
	"officer_q45828776": ["伊奈忠家", "res://assets/officers/portraits/ina_tadaie_history_modern_v1.png"],
	"officer_q109365098": ["伊岐真利", "res://assets/officers/portraits/iki_masatoshi_history_modern_v1.png"],
	"officer_q11379408": ["伊木忠次", "res://assets/officers/portraits/igi_tadatsugu_history_modern_v1.png"],
	"officer_q11266959": ["伊東義益", "res://assets/officers/portraits/ito_yoshimasu_history_modern_v1.png"],
	"officer_q6095349": ["伊東義祐", "res://assets/officers/portraits/ito_yoshisuke_history_modern_v1.png"],
	"officer_q108781571": ["伊東重信", "res://assets/officers/portraits/ito_shigenobu_history_modern_v1.png"],
	"officer_q48765035": ["伊藤信恒", "res://assets/officers/portraits/ito_nobutsune_history_modern_v1.png"],
	"officer_q48764960": ["伊藤実信", "res://assets/officers/portraits/ito_sanenobu_history_modern_v1.png"],
	"officer_q85269821": ["伊藤祐重", "res://assets/officers/portraits/ito_sukeshige_history_modern_v1.png"],
	"officer_q10885140": ["伊達宗利", "res://assets/officers/portraits/date_munetoshi_history_modern_v1.png"],
	"officer_q8514136": ["伊達宗勝", "res://assets/officers/portraits/date_munekatsu_history_modern_v1.png"],
	"officer_q11380713": ["伊達宗実", "res://assets/officers/portraits/date_munezane_history_modern_v1.png"],
	"officer_q11380731": ["伊達宗泰", "res://assets/officers/portraits/date_muneyasu_history_modern_v1.png"],
	"officer_q10885142": ["伊達宗清", "res://assets/officers/portraits/date_munekiyo_history_modern_v1.png"],
	"officer_q11380750": ["伊達宗重", "res://assets/officers/portraits/date_muneshige_history_modern_v1.png"],
	"officer_q11380753": ["伊達定宗", "res://assets/officers/portraits/date_sadamune_history_modern_v1.png"],
	"officer_q11380754": ["伊達実元", "res://assets/officers/portraits/date_sanemoto_history_modern_v1.png"],
	"officer_q115852": ["伊達忠宗", "res://assets/officers/portraits/date_tadamune_history_modern_v1.png"],
	"officer_q1038673": ["伊達成実", "res://assets/officers/portraits/date_shigezane_history_modern_v1.png"],
	"officer_q311183": ["伊達政宗", "res://assets/officers/portraits/date_masamune_history_modern_v1.png"],
	"officer_q10856428": ["伊達政道", "res://assets/officers/portraits/date_masamichi_history_modern_v1.png"],
	"officer_q5227524": ["伊達晴宗", "res://assets/officers/portraits/date_harumune_history_modern_v1.png"],
	"officer_q8190896": ["伊達秀宗", "res://assets/officers/portraits/date_hidemune_history_modern_v1.png"],
	"officer_q5227551": ["伊達稙宗", "res://assets/officers/portraits/date_tanemune_history_modern_v1.png"],
	"officer_q2625556": ["伊達輝宗", "res://assets/officers/portraits/date_terumune_history_modern_v1.png"],
	"officer_q11380978": ["伊集院忠朗", "res://assets/officers/portraits/ijuin_tadaaki_history_modern_v1.png"],
	"officer_q11380979": ["伊集院忠棟", "res://assets/officers/portraits/ijuin_tadamune_history_modern_v1.png"],
	"officer_q11380980": ["伊集院忠真", "res://assets/officers/portraits/ijuin_tadazane_history_modern_v1.png"],
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_history88_20261003"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_history88_20261003/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(FileAccess.file_exists("res://assets/officers/portraits/ATTRIBUTION.txt"))
	assert(Portraits.texture_for("unknown_officer") == null)
	if "--pack-audit" in OS.get_cmdline_user_args():
		for reference_path in ["res://assets/officers/portraits/references/history_modern_20261003_88/kuki_yoshitaka_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/inoue_yukifusa_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/ii_naotaka_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/ii_naomasa_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/kyogoku_takatsugu_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/imagawa_ujizane_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/sengoku_hidehisa_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/ito_yoshimasu_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/date_tadamune_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/date_shigezane_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/date_masamune_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/date_harumune_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/date_tanemune_history_modern_v1_historical.jpg", "res://assets/officers/portraits/references/history_modern_20261003_88/date_terumune_history_modern_v1_historical.jpg"]:
			assert(not FileAccess.file_exists(reference_path))
			assert(not ResourceLoader.exists(reference_path))
		print("REFERENCE_IMAGES_EXCLUDED_14_OK")
	print("HISTORICAL_MODERN_PORTRAITS_88_OK")
	quit()
