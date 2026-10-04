extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q121648896": ["伴盛兼", "res://assets/officers/portraits/ban_morikane_history_modern_v1.png"],
	"officer_q121355878": ["伴盛陰", "res://assets/officers/portraits/ban_morikage_history_modern_v1.png"],
	"officer_q1186700": ["佐々成政", "res://assets/officers/portraits/sassa_narimasa_history_modern_v1.png"],
	"officer_q11382585": ["佐世元嘉", "res://assets/officers/portraits/sase_motoyoshi_history_modern_v1.png"],
	"officer_q11382588": ["佐世正勝", "res://assets/officers/portraits/sase_masakatsu_history_modern_v1.png"],
	"officer_q115596090": ["佐久間信晴", "res://assets/officers/portraits/sakuma_nobuharu_history_modern_v1.png"],
	"officer_q3275789": ["佐久間信盛", "res://assets/officers/portraits/sakuma_nobumori_history_modern_v1.png"],
	"officer_q11382677": ["佐久間信辰", "res://assets/officers/portraits/sakuma_nobutatsu_history_modern_v1.png"],
	"officer_q7403147": ["佐久間盛重", "res://assets/officers/portraits/sakuma_morishige_history_modern_v1.png"],
	"officer_q120908029": ["佐渡長重", "res://assets/officers/portraits/sado_nagashige_history_modern_v1.png"],
	"officer_q11383353": ["佐田九郎左衛門", "res://assets/officers/portraits/sada_kurozaemon_history_modern_v1.png"],
	"officer_q64782964": ["佐竹義喬", "res://assets/officers/portraits/satake_yoshitaka_history_modern_v1.png"],
	"officer_q1071525": ["佐竹義宣", "res://assets/officers/portraits/satake_yoshinobu_history_modern_v1.png"],
	"officer_q11383447": ["佐竹義昭", "res://assets/officers/portraits/satake_yoshiaki_history_modern_v1.png"],
	"officer_q1133798": ["佐竹義重", "res://assets/officers/portraits/satake_yoshishige_history_modern_v1.png"],
	"officer_q11385038": ["佐野昌綱", "res://assets/officers/portraits/sano_masatsuna_history_modern_v1.png"],
	"officer_q11385059": ["佐野泰綱", "res://assets/officers/portraits/sano_yasutsuna_history_modern_v1.png"],
	"officer_q11385090": ["佐野秀綱", "res://assets/officers/portraits/sano_hidetsuna_history_modern_v1.png"],
	"officer_q11385105": ["佐野豊綱", "res://assets/officers/portraits/sano_toyotsuna_history_modern_v1.png"],
	"officer_q118697796": ["依田信政", "res://assets/officers/portraits/yoda_nobumasa_history_modern_v1.png"],
	"officer_q11385712": ["保土原行藤", "res://assets/officers/portraits/hodohara_yukifuji_history_modern_v1.png"],
	"officer_q837236": ["保科正之", "res://assets/officers/portraits/hoshina_masayuki_history_modern_v1.png"],
	"officer_q2040645": ["保科正俊", "res://assets/officers/portraits/hoshina_masatoshi_history_modern_v1.png"],
	"officer_q2405649": ["保科正直", "res://assets/officers/portraits/hoshina_masanao_history_modern_v1.png"],
	"officer_q767309": ["保科正貞", "res://assets/officers/portraits/hoshina_masasada_history_modern_v1.png"],
	"officer_q11388721": ["児玉就光", "res://assets/officers/portraits/kodama_narimitsu_history_modern_v1.png"],
	"officer_q123414963": ["児玉景唯", "res://assets/officers/portraits/kodama_kagetada_history_modern_v1.png"],
	"officer_q15838932": ["入来院重聡", "res://assets/officers/portraits/irikiin_shigetoshi_history_modern_v1.png"],
	"officer_q6069556": ["入田親誠", "res://assets/officers/portraits/nyuta_chikazane_history_modern_v1.png"],
	"officer_q10892188": ["八戸政栄", "res://assets/officers/portraits/hachinohe_masahide_history_modern_v1.png"],
	"officer_q120403158": ["六角定治", "res://assets/officers/portraits/rokkaku_sadaharu_history_modern_v1.png"],
	"officer_q5365763": ["六角定頼", "res://assets/officers/portraits/rokkaku_sadayori_history_modern_v1.png"],
	"officer_q7360045": ["六角義介", "res://assets/officers/portraits/rokkaku_yoshisuke_history_modern_v1.png"],
	"officer_q11392554": ["六角義実", "res://assets/officers/portraits/rokkaku_yoshizane_history_modern_v1.png"],
	"officer_q837217": ["六角義治", "res://assets/officers/portraits/rokkaku_yoshiharu_history_modern_v1.png"],
	"officer_q282529": ["六角義賢", "res://assets/officers/portraits/rokkaku_yoshikata_history_modern_v1.png"],
	"officer_q6361995": ["兼松正吉", "res://assets/officers/portraits/kanematsu_masayoshi_history_modern_v1.png"],
	"officer_q27920507": ["内田実久", "res://assets/officers/portraits/uchida_sanehisa_history_modern_v1.png"],
	"officer_q6959828": ["内藤信成", "res://assets/officers/portraits/naito_nobunari_history_modern_v1.png"],
	"officer_q11394459": ["内藤信正", "res://assets/officers/portraits/naito_nobumasa_history_modern_v1.png"],
	"officer_q8513870": ["内藤信照", "res://assets/officers/portraits/naito_nobuteru_history_modern_v1.png"],
	"officer_q124483515": ["内藤元家", "res://assets/officers/portraits/naito_motoie_history_modern_v1.png"],
	"officer_q30934526": ["内藤元康", "res://assets/officers/portraits/naito_motoyasu_history_modern_v1.png"],
	"officer_q124483516": ["内藤元忠", "res://assets/officers/portraits/naito_mototada_history_modern_v1.png"],
	"officer_q8010346": ["内藤家長", "res://assets/officers/portraits/naito_ienaga_history_modern_v1.png"],
	"officer_q8514885": ["内藤忠興", "res://assets/officers/portraits/naito_tadaoki_history_modern_v1.png"],
	"officer_q58139879": ["内藤忠郷", "res://assets/officers/portraits/naito_tadasato_history_modern_v1.png"],
	"officer_q8514891": ["内藤政長", "res://assets/officers/portraits/naito_masanaga_history_modern_v1.png"],
	"officer_q2148507": ["内藤昌豊", "res://assets/officers/portraits/naito_masatoyo_history_modern_v1.png"],
	"officer_q10514826": ["内藤正成 (四郎左衛門)", "res://assets/officers/portraits/naito_masanari_shirozaemon_history_modern_v1.png"],
	"officer_q10514860": ["内藤清成", "res://assets/officers/portraits/naito_kiyonari_history_modern_v1.png"],
	"officer_q10514870": ["内藤清次", "res://assets/officers/portraits/naito_kiyotsugu_history_modern_v1.png"],
	"officer_q6959827": ["内藤清長", "res://assets/officers/portraits/naito_kiyonaga_history_modern_v1.png"],
	"officer_q6959822": ["内藤源左衛門", "res://assets/officers/portraits/naito_genzaemon_history_modern_v1.png"],
	"officer_q10514879": ["内藤興盛", "res://assets/officers/portraits/naito_okimori_history_modern_v1.png"],
	"officer_q10514902": ["内藤隆世", "res://assets/officers/portraits/naito_takayo_history_modern_v1.png"],
	"officer_q10514906": ["内藤隆春", "res://assets/officers/portraits/naito_takaharu_history_modern_v1.png"],
	"officer_q124483513": ["内藤隆貞", "res://assets/officers/portraits/naito_takasada_history_modern_v1.png"],
	"officer_q11395365": ["冷泉為純", "res://assets/officers/portraits/reizei_tamezumi_history_modern_v1.png"],
	"officer_q121652181": ["冷泉興豊", "res://assets/officers/portraits/reizei_okitoyo_history_modern_v1.png"],
	"officer_q11395368": ["冷泉隆豊", "res://assets/officers/portraits/reizei_takatoyo_history_modern_v1.png"],
	"officer_q6147327": ["出浦盛清", "res://assets/officers/portraits/ideura_morikiyo_history_modern_v1.png"],
	"officer_q5639952": ["初鹿野信昌", "res://assets/officers/portraits/hajikano_nobumasa_history_modern_v1.png"],
	"officer_q5639955": ["初鹿野忠次", "res://assets/officers/portraits/hajikano_tadatsugu_history_modern_v1.png"],
	"officer_q11396766": ["別所吉親", "res://assets/officers/portraits/bessho_yoshichika_history_modern_v1.png"],
	"officer_q11396808": ["別所重宗", "res://assets/officers/portraits/bessho_shigemune_history_modern_v1.png"],
	"officer_q837435": ["別所長治", "res://assets/officers/portraits/bessho_nagaharu_history_modern_v1.png"],
	"officer_q6729067": ["前波吉継", "res://assets/officers/portraits/maenami_yoshitsugu_history_modern_v1.png"],
	"officer_q6729106": ["前田光高", "res://assets/officers/portraits/maeda_mitsutaka_history_modern_v1.png"],
	"officer_q1196817": ["前田利家", "res://assets/officers/portraits/maeda_toshiie_history_modern_v1.png"],
	"officer_q587204": ["前田利常", "res://assets/officers/portraits/maeda_toshitsune_history_modern_v1.png"],
	"officer_q1082927": ["前田利春", "res://assets/officers/portraits/maeda_toshiharu_history_modern_v1.png"],
	"officer_q1150951": ["前田利益", "res://assets/officers/portraits/maeda_keiji_history_modern_v1.png"],
	"officer_q1186742": ["前田利長", "res://assets/officers/portraits/maeda_toshinaga_history_modern_v1.png"],
	"officer_q6729101": ["前田玄以", "res://assets/officers/portraits/maeda_geni_history_modern_v1.png"],
	"officer_q108781559": ["前野三七郎", "res://assets/officers/portraits/maeno_sanshichiro_history_modern_v1.png"],
	"officer_q109288071": ["前野嘉兵次", "res://assets/officers/portraits/maeno_kaheiji_history_modern_v1.png"],
	"officer_q108781599": ["前野宗康", "res://assets/officers/portraits/maeno_muneyasu_history_modern_v1.png"],
	"officer_q109597454": ["前野定時", "res://assets/officers/portraits/maeno_sadatoki_history_modern_v1.png"],
	"officer_q109288021": ["前野時之", "res://assets/officers/portraits/maeno_tokiyuki_history_modern_v1.png"],
	"officer_q108781653": ["前野時正", "res://assets/officers/portraits/maeno_tokimasa_history_modern_v1.png"],
	"officer_q108781550": ["前野正吉", "res://assets/officers/portraits/maeno_masayoshi_history_modern_v1.png"],
	"officer_q108781570": ["前野泰道", "res://assets/officers/portraits/maeno_yasumichi_history_modern_v1.png"],
	"officer_q108701282": ["前野為定", "res://assets/officers/portraits/maeno_tamesada_history_modern_v1.png"],
	"officer_q108781551": ["前野義康", "res://assets/officers/portraits/maeno_yoshiyasu_history_modern_v1.png"],
	"officer_q108781596": ["前野義高", "res://assets/officers/portraits/maeno_yoshitaka_history_modern_v1.png"],
	"officer_q108781547": ["前野豊成", "res://assets/officers/portraits/maeno_toyonari_history_modern_v1.png"],
	"officer_q121643823": ["前野長宗", "res://assets/officers/portraits/maeno_nagamune_history_modern_v1.png"],
	"officer_q1059898": ["前野長康", "res://assets/officers/portraits/maeno_nagayasu_history_modern_v1.png"],
	"officer_q108781612": ["前野長義", "res://assets/officers/portraits/maeno_nagayoshi_history_modern_v1.png"],
	"officer_q123406307": ["加木屋正則", "res://assets/officers/portraits/kagiya_masanori_history_modern_v1.png"],
	"officer_q5354334": ["加藤光泰", "res://assets/officers/portraits/kato_mitsuyasu_history_modern_v1.png"],
	"officer_q1371657": ["加藤嘉明", "res://assets/officers/portraits/kato_yoshiaki_history_modern_v1.png"],
	"officer_q11399205": ["加藤弥三郎", "res://assets/officers/portraits/kato_yasaburo_history_modern_v1.png"],
	"officer_q11399251": ["加藤昌頼", "res://assets/officers/portraits/kato_masayori_history_modern_v1.png"],
	"officer_q8012693": ["加藤明成", "res://assets/officers/portraits/kato_akinari_history_modern_v1.png"],
	"officer_q1069843": ["加藤清正", "res://assets/officers/portraits/kato_kiyomasa_history_modern_v1.png"],
	"officer_q17211617": ["加藤重徳", "res://assets/officers/portraits/kato_shigenori_history_modern_v1.png"],
	"officer_q108781572": ["加藤順盛", "res://assets/officers/portraits/kato_yorimori_history_modern_v1.png"],
	"officer_q108781565": ["加賀井重宗", "res://assets/officers/portraits/kagai_shigemune_history_modern_v1.png"],
	"officer_q6639661": ["勝沼信元", "res://assets/officers/portraits/katsunuma_nobumoto_history_modern_v1.png"],
	"officer_q121648730": ["勝重久", "res://assets/officers/portraits/katsu_shigehisa_history_modern_v1.png"],
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_history102_20261003"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_history102_20261003/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(FileAccess.file_exists("res://assets/officers/portraits/ATTRIBUTION.txt"))
	assert(Portraits.texture_for("unknown_officer") == null)
	if "--pack-audit" in OS.get_cmdline_user_args():
		for reference_path in ["res://assets/officers/portraits/references/history_modern_20261003_102/002_Kuniyoshi.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/012_Satake Yoshinobu.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/015_official.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/021_Hoshina Masayuki.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/036_Kanematsu Masayoshi.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/038_Nait\u014d Nobunari.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/039_official.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/040_official.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/047_Nait\u014d Masanaga.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/049_Nait\u014d Masanari.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/054_Nait\u014d Okimori.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/069_Maeda Toshiie.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/070_Maeda Toshitsune.png", "res://assets/officers/portraits/references/history_modern_20261003_102/071_official.gif", "res://assets/officers/portraits/references/history_modern_20261003_102/073_MaedaToshinaga1.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/074_Maeda Gen'i.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/092_Kat\u014d Yoshiaki.jpg", "res://assets/officers/portraits/references/history_modern_20261003_102/096_Kat\u014d Kiyomasa.jpg"]:
			assert(not FileAccess.file_exists(reference_path))
			assert(not ResourceLoader.exists(reference_path))
		print("REFERENCE_IMAGES_EXCLUDED_18_OK")
	print("HISTORICAL_MODERN_PORTRAITS_102_OK")
	quit()
