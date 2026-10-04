extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const OfficerPanel = preload("res://scripts/game/officer_panel.gd")
const TARGETS := {
	"officer_q10902500": ["北信愛", "res://assets/officers/portraits/kita_nobuchika_history_modern_v1.png"],
	"officer_q4222351": ["北就勝", "res://assets/officers/portraits/kita_narikatsu_history_modern_v1.png"],
	"officer_q10903136": ["北条幻庵", "res://assets/officers/portraits/hojo_genan_history_modern_v1.png"],
	"officer_q18235202": ["北条康種", "res://assets/officers/portraits/hojo_yasutane_history_modern_v1.png"],
	"officer_q10903139": ["北条景広", "res://assets/officers/portraits/kitajo_kagehiro_history_modern_v1.png"],
	"officer_q11402157": ["北条氏尭", "res://assets/officers/portraits/hojo_ujitaka_history_modern_v1.png"],
	"officer_q943643": ["北条氏康", "res://assets/officers/portraits/hojo_ujiyasu-v2_history_modern_v1.png"],
	"officer_q11070033": ["北条氏成", "res://assets/officers/portraits/hojo_ujinari_history_modern_v1.png"],
	"officer_q736948": ["北条氏政", "res://assets/officers/portraits/hojo_ujimasa_history_modern_v1.png"],
	"officer_q2790462": ["北条氏照", "res://assets/officers/portraits/hojo_ujiteru_history_modern_v1.png"],
	"officer_q1156668": ["北条氏直", "res://assets/officers/portraits/hojo_ujinao_history_modern_v1.png"],
	"officer_q10903144": ["北条氏繁", "res://assets/officers/portraits/hojo_ujishige_history_modern_v1.png"],
	"officer_q1968898": ["北条氏規", "res://assets/officers/portraits/hojo_ujinori_history_modern_v1.png"],
	"officer_q3138651": ["北条氏邦", "res://assets/officers/portraits/hojo_ujikuni_history_modern_v1.png"],
	"officer_q11402184": ["北条直定", "res://assets/officers/portraits/hojo_naosada_history_modern_v1.png"],
	"officer_q636998": ["北条綱成", "res://assets/officers/portraits/hojo_tsunashige_history_modern_v1.png"],
	"officer_q11070093": ["北条綱房", "res://assets/officers/portraits/hojo_tsunafusa_history_modern_v1.png"],
	"officer_q11402189": ["北条綱高", "res://assets/officers/portraits/hojo_tsunataka_history_modern_v1.png"],
	"officer_q11402209": ["北条高広", "res://assets/officers/portraits/kitajo_takahiro_history_modern_v1.png"],
	"officer_q10903777": ["北畠具教", "res://assets/officers/portraits/kitabatake_tomonori_history_modern_v1.png"],
	"officer_q11403858": ["北畠晴具", "res://assets/officers/portraits/kitabatake_harutomo_history_modern_v1.png"],
	"officer_q11404199": ["北郷忠虎", "res://assets/officers/portraits/hongo_tadatora_history_modern_v1.png"],
	"officer_q5895942": ["北郷時久", "res://assets/officers/portraits/hongo_tokihisa_history_modern_v1.png"],
	"officer_q17228557": ["十時惟忠", "res://assets/officers/portraits/totoki_koretada_history_modern_v1.png"],
	"officer_q17223035": ["十時惟次", "res://assets/officers/portraits/totoki_koretsugu_history_modern_v1.png"],
	"officer_q1007730": ["十河一存", "res://assets/officers/portraits/sogo_kazumasa_history_modern_v1.png"],
	"officer_q11405125": ["十河景滋", "res://assets/officers/portraits/sogo_kageshige_history_modern_v1.png"],
	"officer_q11405203": ["千々石直員", "res://assets/officers/portraits/chijiwa_naokazu_history_modern_v1.png"],
	"officer_q10904841": ["千坂景親", "res://assets/officers/portraits/chisaka_kagechika_history_modern_v1.png"],
	"officer_q108781073": ["千坂長朝", "res://assets/officers/portraits/chisaka_nagatomo_history_modern_v1.png"],
	"officer_q11405498": ["千徳政武", "res://assets/officers/portraits/sentoku_masatake_history_modern_v1.png"],
	"officer_q11405598": ["千本義隆", "res://assets/officers/portraits/senbon_yoshitaka_history_modern_v1.png"],
	"officer_q11405599": ["千本資俊", "res://assets/officers/portraits/senbon_suketoshi_history_modern_v1.png"],
	"officer_q11405793": ["千秋季忠", "res://assets/officers/portraits/senshu_suetada_history_modern_v1.png"],
	"officer_q133699096": ["千種忠治", "res://assets/officers/portraits/chigusa_tadaharu_history_modern_v1.png"],
	"officer_q11405932": ["千葉利胤", "res://assets/officers/portraits/chiba_toshitane_history_modern_v1.png"],
	"officer_q11406115": ["千葉直重", "res://assets/officers/portraits/chiba_naoshige_history_modern_v1.png"],
	"officer_q11406725": ["千葉胤宗", "res://assets/officers/portraits/chiba_tanemune_history_modern_v1.png"],
	"officer_q11406739": ["千葉胤頼", "res://assets/officers/portraits/chiba_taneyori_history_modern_v1.png"],
	"officer_q11406741": ["千葉興常", "res://assets/officers/portraits/chiba_okitsune_history_modern_v1.png"],
	"officer_q11406760": ["千葉親胤", "res://assets/officers/portraits/chiba_chikatane_history_modern_v1.png"],
	"officer_q109288022": ["千賀信親", "res://assets/officers/portraits/senga_nobuchika_history_modern_v1.png"],
	"officer_q11407944": ["南条信正", "res://assets/officers/portraits/nanjo_nobumasa_history_modern_v1.png"],
	"officer_q11407950": ["南条宗勝", "res://assets/officers/portraits/nanjo_munekatsu_history_modern_v1.png"],
	"officer_q3137467": ["南部信直", "res://assets/officers/portraits/nanbu_nobunao_history_modern_v1.png"],
	"officer_q5365538": ["南部晴政", "res://assets/officers/portraits/nanbu_harumasa_history_modern_v1.png"],
	"officer_q3055475": ["原昌胤", "res://assets/officers/portraits/hara_masatane_history_modern_v1.png"],
	"officer_q5653572": ["原田宗時", "res://assets/officers/portraits/harada_munetoki_history_modern_v1.png"],
	"officer_q11409810": ["原田宗資", "res://assets/officers/portraits/harada_munesuke_history_modern_v1.png"],
	"officer_q11409811": ["原田宗輔", "res://assets/officers/portraits/harada_munesuke_kai_history_modern_v1.png"],
	"officer_q55528532": ["原胤従", "res://assets/officers/portraits/hara_taneyori_history_modern_v1.png"],
	"officer_q11410031": ["原胤義", "res://assets/officers/portraits/hara_taneyoshi_history_modern_v1.png"],
	"officer_q11410050": ["原虎吉", "res://assets/officers/portraits/hara_torayoshi_history_modern_v1.png"],
	"officer_q2509259": ["原虎胤", "res://assets/officers/portraits/hara_toratane_history_modern_v1.png"],
	"officer_q5653532": ["原長頼", "res://assets/officers/portraits/hara_nagayori_history_modern_v1.png"],
	"officer_q10913013": ["口羽通良", "res://assets/officers/portraits/kuchiba_michiyoshi_history_modern_v1.png"],
	"officer_q126006441": ["古川済堯", "res://assets/officers/portraits/officer_q126006441_history_modern_v1.png"],
	"officer_q1058793": ["古田重然", "res://assets/officers/portraits/furuta_shigenari_history_modern_v1.png"],
	"officer_q11412173": ["右田隆次", "res://assets/officers/portraits/officer_q11412173_history_modern_v1.png"],
	"officer_q859673": ["吉川元春", "res://assets/officers/portraits/kikkawa_motoharu_history_modern_v1.png"],
	"officer_q1049766": ["吉川広家", "res://assets/officers/portraits/kikkawa_hiroie_history_modern_v1.png"],
	"officer_q10917128": ["吉川興経", "res://assets/officers/portraits/kikkawa_okitsune_history_modern_v1.png"],
	"officer_q11413125": ["吉弘鎮信", "res://assets/officers/portraits/yoshihiro_shigenobu_history_modern_v1.png"],
	"officer_q11413413": ["吉江景資", "res://assets/officers/portraits/yoshie_kagesuke_history_modern_v1.png"],
	"officer_q108781135": ["吉田康俊", "res://assets/officers/portraits/yoshida_yasutoshi_history_modern_v1.png"],
	"officer_q109287667": ["吉田弥三", "res://assets/officers/portraits/officer_q109287667_history_modern_v1.png"],
	"officer_q24885353": ["吉田長利", "res://assets/officers/portraits/yoshida_nagatoshi_history_modern_v1.png"],
	"officer_q11414257": ["吉良義堯", "res://assets/officers/portraits/kira_yoshitaka_history_modern_v1.png"],
	"officer_q11414260": ["吉良義安", "res://assets/officers/portraits/kira_yoshiyasu_history_modern_v1.png"],
	"officer_q9605578": ["吉良親貞", "res://assets/officers/portraits/kira_chikasada_history_modern_v1.png"],
	"officer_q10917380": ["吉見正頼", "res://assets/officers/portraits/yoshimi_masayori_history_modern_v1.png"],
	"officer_q109360147": ["和仁親宗", "res://assets/officers/portraits/officer_q109360147_history_modern_v1.png"],
	"officer_q7958754": ["和智誠春", "res://assets/officers/portraits/wachi_masaharu_history_modern_v1.png"],
	"officer_q11417913": ["和田信維", "res://assets/officers/portraits/officer_q11417913_history_modern_v1.png"],
	"officer_q7958925": ["和田惟政", "res://assets/officers/portraits/wada_koremasa_history_modern_v1.png"],
	"officer_q108781568": ["和賀義忠", "res://assets/officers/portraits/waga_yoshitada_history_modern_v1.png"],
	"officer_q7497244": ["品川将員", "res://assets/officers/portraits/shinagawa_masakazu_history_modern_v1.png"],
	"officer_q6368627": ["唐沢玄蕃", "res://assets/officers/portraits/karasawa_genba_history_modern_v1.png"],
	"officer_q11162231": ["喜入季久", "res://assets/officers/portraits/kiire_suehisa_history_modern_v1.png"],
	"officer_q109288049": ["喜多村政信", "res://assets/officers/portraits/officer_q109288049_history_modern_v1.png"],
	"officer_q11420554": ["国分盛廉", "res://assets/officers/portraits/officer_q11420554_history_modern_v1.png"],
	"officer_q11420557": ["国分盛氏", "res://assets/officers/portraits/kokubun_moriuji_history_modern_v1.png"],
	"officer_q11420562": ["国分盛顕", "res://assets/officers/portraits/kokubun_moriaki_history_modern_v1.png"],
	"officer_q6444764": ["国司元相", "res://assets/officers/portraits/kunishi_motosuke_history_modern_v1.png"],
	"officer_q124426307": ["国富貞次", "res://assets/officers/portraits/officer_q124426307_history_modern_v1.png"],
	"officer_q38279385": ["国重信正", "res://assets/officers/portraits/officer_q38279385_history_modern_v1.png"],
	"officer_q1042428": ["土井利勝", "res://assets/officers/portraits/doi_toshikatsu_history_modern_v1.png"],
	"officer_q11423192": ["土居清良", "res://assets/officers/portraits/doi_kiyora_history_modern_v1.png"],
	"officer_q2295119": ["土屋昌続", "res://assets/officers/portraits/tsuchiya_masatsugu_history_modern_v1.png"],
	"officer_q11473873": ["土屋貞綱", "res://assets/officers/portraits/tsuchiya_sadatsuna_history_modern_v1.png"],
	"officer_q119927069": ["土岐頼春", "res://assets/officers/portraits/toki_yoriharu_history_modern_v1.png"],
	"officer_q11423418": ["土岐頼純", "res://assets/officers/portraits/toki_yorizumi_history_modern_v1.png"],
	"officer_q837179": ["土岐頼芸", "res://assets/officers/portraits/toki_yorinori_history_modern_v1.png"],
	"officer_q55531376": ["坂崎成政", "res://assets/officers/portraits/officer_q55531376_history_modern_v1.png"],
	"officer_q108781555": ["坂本貞吉", "res://assets/officers/portraits/officer_q108781555_history_modern_v1.png"],
	"officer_q108781567": ["坂本貞次", "res://assets/officers/portraits/officer_q108781567_history_modern_v1.png"],
	"officer_q11425729": ["坪内利定", "res://assets/officers/portraits/tsubouchi_toshisada_history_modern_v1.png"],
	"officer_q108781574": ["坪内勝長", "res://assets/officers/portraits/officer_q108781574_history_modern_v1.png"],
	"officer_q109598880": ["坪内友定", "res://assets/officers/portraits/officer_q109598880_history_modern_v1.png"],
	"officer_q108703373": ["坪内広綱", "res://assets/officers/portraits/officer_q108703373_history_modern_v1.png"],
	"officer_q108701318": ["坪内忠勝", "res://assets/officers/portraits/officer_q108701318_history_modern_v1.png"],
	"officer_q108701507": ["坪内昌家", "res://assets/officers/portraits/officer_q108701507_history_modern_v1.png"],
	"officer_q108701254": ["坪内頼定", "res://assets/officers/portraits/officer_q108701254_history_modern_v1.png"],
	"officer_q11425978": ["城井鎮房", "res://assets/officers/portraits/kii_shigefusa_history_modern_v1.png"],
	"officer_q108781510": ["埴原八蔵", "res://assets/officers/portraits/officer_q108781510_history_modern_v1.png"],
	"officer_q11427258": ["堀内俊胤", "res://assets/officers/portraits/horiuchi_toshitane_history_modern_v1.png"],
	"officer_q8190645": ["堀尾吉晴", "res://assets/officers/portraits/horio_yoshiharu_history_modern_v1.png"],
	"officer_q5903277": ["堀尾忠晴", "res://assets/officers/portraits/horio_tadaharu_history_modern_v1.png"],
	"officer_q3140540": ["堀尾忠氏", "res://assets/officers/portraits/horio_tadauji_history_modern_v1.png"],
	"officer_q108781589": ["堀無手右衛門", "res://assets/officers/portraits/hori_muteemon_history_modern_v1.png"],
	"officer_q11427678": ["堀直之", "res://assets/officers/portraits/hori_naoyuki_history_modern_v1.png"],
	"officer_q11427691": ["堀直定", "res://assets/officers/portraits/hori_naosada_history_modern_v1.png"],
	"officer_q11427694": ["堀直寄", "res://assets/officers/portraits/hori_naoyori_history_modern_v1.png"],
	"officer_q11427700": ["堀直政", "res://assets/officers/portraits/hori_naomasa_history_modern_v1.png"],
	"officer_q8190166": ["堀秀政", "res://assets/officers/portraits/hori_hidemasa_history_modern_v1.png"],
	"officer_q866169": ["塙直之", "res://assets/officers/portraits/hanawa_naoyuki_history_modern_v1.png"],
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
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds/qa/portraits_history116_20261003"))
			root.get_texture().get_image().save_png("res://builds/qa/portraits_history116_20261003/" + officer_id + ".png")
		print("ADOPTED_PORTRAIT_OK " + officer_id)
	assert(FileAccess.file_exists("res://assets/officers/portraits/ATTRIBUTION.txt"))
	assert(Portraits.texture_for("unknown_officer") == null)
	if "--pack-audit" in OS.get_cmdline_user_args():
		for reference_path in ["res://assets/officers/portraits/references/history_modern_20261003_116/002_Hojo Gennann.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/006_Ujiyasu Hojo.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/008_Hojo Ujimasa.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/010_Hojo Ujinao.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/019_Kitabatake Tomonori.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/040_\u5343\u8449\u89aa\u80e4.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/044_Nanbu Nobunao01.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/055_Kuchiba Michiyoshi.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/057_Furutaoribe.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/059_Kikkawa Motoharu01.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/060_Kikkawa Hiroie.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/066_Yoshida Nagatoshi.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/070_Yoshimi Masayori.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/083_Kunishi Motosuke.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/086_Doi Toshikatu.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/091_Toki Yorizumi.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/103_Kii Shigehusa.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/106_Horio Yoshiharu.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/108_Horio Tadauji.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/112_HORI Naoyori Juzo.jpg", "res://assets/officers/portraits/references/history_modern_20261003_116/114_Hori Hidemasa01.jpg"]:
			assert(not FileAccess.file_exists(reference_path))
			assert(not ResourceLoader.exists(reference_path))
		print("REFERENCE_IMAGES_EXCLUDED_21_OK")
	print("HISTORICAL_MODERN_PORTRAITS_116_OK")
	quit()
