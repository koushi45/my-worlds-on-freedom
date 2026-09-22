extends Node

signal closed

const STATUS_NAMES := {"alive":"年代上対象", "same_year_ambiguous":"1546年内の前後不明", "unresolved":"年代要調査", "unborn":"開始時は未誕生"}
const FILTERS := ["all", "alive", "same_year_ambiguous", "unresolved", "child", "unborn"]
const COHORTS := ["all", "next_60", "major_60", "notable", "third_60", "fourth_100", "fifth_100", "sixth_100", "seventh_100", "eighth_100", "ninth_100", "tenth_100", "eleventh_100", "twelfth_100", "thirteenth_100", "fourteenth_100", "fifteenth_100", "sixteenth_100", "seventeenth_100", "remaining_40"]
const ABILITIES := {"command":"統率", "tactics":"武勇", "strategy":"知略", "politics":"政治", "trust":"人望"}
const Portraits = preload("res://scripts/game/officer_portraits.gd")
var main: Node2D
var standalone := false
var registry = preload("res://scripts/game/officer_registry.gd").new()
var browser: AcceptDialog
var search: LineEdit
var filter: OptionButton
var cohort: OptionButton
var sort_order: OptionButton
var rated: CheckButton
var count_label: Label
var items: ItemList
var portrait: TextureRect
var details: RichTextLabel
var matches: Array[String] = []

func _ready() -> void:
	var result: Error = registry.load_data()
	if standalone:
		if result != OK: push_error(registry.last_error)
		return
	var host: VBoxContainer = main.get_node("Interface/InfoPanel/Margin/VBox")
	var title := Label.new()
	title.text = "開始：1546年（信長元服）｜地図：1582年"
	title.add_theme_font_size_override("font_size", 14)
	host.add_child(title)
	host.move_child(title, 0)
	var button := Button.new()
	button.text = "武将一覧・生涯能力案" if result == OK else registry.last_error
	button.disabled = result != OK
	button.pressed.connect(show_browser)
	host.add_child(button)
	host.move_child(button, 1)
	if result != OK: push_error(registry.last_error)

func show_browser() -> void:
	if browser == null: _create_browser()
	refresh_list()
	browser.popup_centered(Vector2i(1180, 650))
	search.grab_focus()

func _create_browser() -> void:
	browser = AcceptDialog.new()
	browser.title = "1546年の武将台帳 ／ 能力は生涯評価の初稿"
	if standalone: add_child(browser)
	else: main.get_node("Interface").add_child(browser)
	browser.confirmed.connect(func(): closed.emit())
	browser.canceled.connect(func(): closed.emit())
	browser.close_requested.connect(func(): closed.emit())
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(1100, 560)
	browser.add_child(content)
	var note := Label.new()
	note.text = "年代不詳・幼少者も収録。評価済み1598人・各30点、総合150点満点。未誕生の著名人物も名簿に収録。"
	note.add_theme_font_size_override("font_size", 14)
	content.add_child(note)
	var row := HBoxContainer.new()
	content.add_child(row)
	search = LineEdit.new()
	search.placeholder_text = "武将名・家系・所属家・郡で検索"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String): refresh_list())
	row.add_child(search)
	filter = OptionButton.new()
	for text in ["名簿すべて", "年代上対象", "1546年内の前後不明", "年代要調査", "幼少者", "開始時は未誕生"]: filter.add_item(text)
	filter.item_selected.connect(func(_index: int): refresh_list())
	row.add_child(filter)
	cohort = OptionButton.new()
	for text in ["全グループ", "第2組60人", "第1組60人", "生年不問の著名人物", "第3組60人", "第4組100人", "第5組100人", "第6組100人", "第7組100人", "第8組100人", "第9組100人", "第10組100人", "第11組100人", "第12組100人", "第13組100人", "第14組100人", "第15組100人", "第16組100人", "第17組100人", "今回の評価18人（残件整理）"]: cohort.add_item(text)
	# The in-game dictionary opens on the principal 60 officers, which includes
	# every portrait currently available. Keep the editorial view's prior default.
	cohort.select(2 if standalone else 19)
	cohort.item_selected.connect(func(index: int):
		if index == 3: rated.set_pressed_no_signal(false)
		refresh_list())
	row.add_child(cohort)
	rated = CheckButton.new()
	rated.text = "能力評価済み"
	rated.button_pressed = true
	rated.toggled.connect(func(_value: bool): refresh_list())
	row.add_child(rated)
	count_label = Label.new()
	var sort_row := HBoxContainer.new()
	content.add_child(sort_row)
	sort_row.add_child(count_label)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_order = OptionButton.new()
	for text in ["掲載順（知名度は編集判断）", "総合が高い順", "総合が低い順", "名前順"]: sort_order.add_item(text)
	sort_order.item_selected.connect(func(_index: int): refresh_list())
	sort_row.add_child(sort_order)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(split)
	items = ItemList.new()
	items.custom_minimum_size = Vector2(365, 440)
	items.fixed_icon_size = Vector2i(58, 58)
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items.item_selected.connect(select_index)
	split.add_child(items)
	var detail_area := HBoxContainer.new()
	detail_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_area.add_theme_constant_override("separation", 14)
	split.add_child(detail_area)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(185, 260)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.hide()
	detail_area.add_child(portrait)
	details = RichTextLabel.new()
	details.custom_minimum_size = Vector2(515, 440)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.bbcode_enabled = false
	detail_area.add_child(details)

func refresh_list() -> void:
	if items == null: return
	matches = registry.search_ids(search.text, FILTERS[filter.selected], rated.button_pressed, COHORTS[cohort.selected])
	matches.sort_custom(_sort_officers)
	items.clear()
	for id in matches:
		var officer: Dictionary = registry.lookup[id]
		var suffix: String = "［幼少］" if officer["life_stage"] == "child" else ""
		if officer["life_stage"] == "genpuku_recorded": suffix = "［元服］"
		if officer["temporal_status"] != "alive": suffix += "［" + STATUS_NAMES[officer["temporal_status"]] + "］"
		items.add_item(str(officer["display_name"]) + "  総合 " + _total_text(officer) + suffix, Portraits.texture_for(id))
		var affiliation: Dictionary = officer.get("affiliation_1546", {})
		items.set_item_tooltip(items.item_count - 1, items.get_item_text(items.item_count - 1) + "\n家系：" + str(officer.get("lineage", {}).get("display_name", "家系未確認")) + "\n所属家：" + str(affiliation.get("house_display", "所属不明")) + " ／ " + str(affiliation.get("role", "立場不明")) + " ／ " + str(affiliation.get("district_display", "未配置")))
	count_label.text = "%d人を表示 ／ 名簿%d人 ／ 年代上対象%d人" % [matches.size(), registry.lookup.size(), registry.data["stats"].get("alive", 0)]
	details.text = "名前を選ぶと能力案と評価理由を表示します。\n\n幼少者の能力は、生涯の実績による評価案です。\n所属家・立場・郡配置の案を詳細に表示します。郡は家の本拠圏内へのゲーム用分散配置です。\n1546年内の前後不明・年代要調査は、開始時の存命確定とは分けています。\n\n人望は家臣の定着・登用人材の活用で評価します。本人の主君への忠義や一般的人気とは区別します。"
	portrait.texture = null
	portrait.hide()

func select_index(index: int) -> void:
	if index < 0 or index >= matches.size(): return
	var officer_id := matches[index]
	var officer: Dictionary = registry.lookup[officer_id]
	portrait.texture = Portraits.texture_for(officer_id)
	portrait.visible = portrait.texture != null
	var assessment: Dictionary = officer["assessment"]
	var birth_text := str(officer["birth_display"]) + ("（推定）" if officer.get("birth_year_estimated", false) else "")
	var death_text := str(officer["death_display"]) + ("（推定）" if officer.get("death_year_estimated", false) else "")
	details.text = "%s\n%s年 ～ %s年\n%s\n\n【1546年の判定】\n%s\n\n" % [officer["display_name"], birth_text, death_text, STATUS_NAMES[officer["temporal_status"]], officer["temporal_note"]]
	if officer["age_range_at_start"] != null:
		details.text += "満年齢目安：%d〜%d歳\n" % [officer["age_range_at_start"][0], officer["age_range_at_start"][1]]
	if officer["life_stage"] == "genpuku_recorded": details.text += "元服を開始条件として記録済み\n"
	if officer["temporal_status"] == "unborn": details.text += "開始時は未誕生のため出仕・配属対象外\n"
	var relationships: Dictionary = officer.get("relationships", {})
	details.text += "\n【父・母・子（生涯・資料照合待ち）】\n"
	for relation_key in ["father", "mother", "children", "parents_unspecified"]:
		var relation_names: PackedStringArray = []
		for relative in relationships.get(relation_key, []):
			relation_names.append(str(relative["display_name"]) + "（" + str(relative["kind"]) + "）")
		details.text += str({"father":"父", "mother":"母", "children":"子（収録分）", "parents_unspecified":"父母区分未確認"}[relation_key]) + "：" + ("、".join(relation_names) if not relation_names.is_empty() else "未確認") + "\n"
	details.text += str(relationships.get("note", "")) + "\n"
	var lineage: Dictionary = officer.get("lineage", {})
	details.text += "\n【本人の家系】\n" + str(lineage.get("display_name", "家系未確認")) + "\n" + str(lineage.get("note", "")) + "\n"
	if lineage.get("birth_family_display") != null: details.text += "出生家：" + str(lineage["birth_family_display"]) + "\n"
	if lineage.get("family_at_1546_display") != null: details.text += "1546年の家名：" + str(lineage["family_at_1546_display"]) + "\n"
	if not str(lineage.get("source_clan_text", "")).is_empty(): details.text += "資料の氏族表記：" + str(lineage["source_clan_text"]) + "\n"
	details.text += str(lineage.get("transition_note", "")) + "\n"
	for url in lineage.get("source_urls", []): details.text += str(url) + "\n"
	var affiliation: Dictionary = officer.get("affiliation_1546", {})
	details.text += "\n【1546年の所属・配置】\n所属家：%s\n立場：%s\n配置郡：%s\n%s\n" % [affiliation.get("house_display", "所属不明"), affiliation.get("role", "立場不明"), affiliation.get("district_display", "未配置"), affiliation.get("reason", "")]
	if affiliation.get("reference_placement_only", false):
		details.text += "参照用配置：上記の郡は開始時の配属・領有には使用しません。\n"
	if affiliation.get("future_placement_reserved", false):
		details.text += "将来用仮配置：上記の所属・郡は予約情報です。1546年には登場・出仕しません。\n"
	details.text += "郡はゲーム用分散配置で、史実の居所ではありません。部隊への配属は未実装。\n"
	if affiliation.has("historical_role"):
		details.text += "史料上の立場：" + str(affiliation["historical_role"]) + "\n"
	if affiliation.has("placement_reason"):
		details.text += "配置の根拠・設定：" + str(affiliation["placement_reason"]) + "\n"
	if affiliation.get("availability", "") in ["deceased", "not_born"]:
		details.text += "開始時対象外：" + ("故人" if affiliation["availability"] == "deceased" else "未誕生") + "\n"
	details.text += "後年を含む参考所属：" + str(affiliation.get("reference_house_display", "未確認")) + "\n"
	for url in affiliation.get("source_urls", []): details.text += str(url) + "\n"
	details.text += "\n【生涯の能力案：30点満点・1点刻み】\n"
	details.text += "総合能力：" + _total_text(officer) + " / 150（5能力の合計）\n"
	for key in ABILITIES:
		var value: Variant = assessment["scores"].get(key)
		details.text += "%s：%s\n" % [ABILITIES[key], "未評価" if value == null else str(int(value))]
	if assessment.has("score_reasons"):
		details.text += "\n【項目別の評価理由】\n"
		for key in ABILITIES:
			var basis_labels := {"achievement":"功績あり", "mixed":"功績・失敗を比較", "participation_standard":"参加実績から標準遂行", "no_record":"成否材料なし", "failure_only":"参照範囲で失敗のみ"}
			var confidence: String = basis_labels.get(assessment.get("score_basis", {}).get(key, ""), "暫定推定" if assessment.get("score_confidence", {}).get(key) == "limited_evidence" else "編集評価")
			details.text += "%s（%s）：%s\n" % [ABILITIES[key], confidence, assessment["score_reasons"].get(key, "")]
	details.text += "\n【資料から参照した事項】\n%s\n\n【評価上の留保】\n%s\n%s\n" % [assessment["evidence"], assessment["caveat"], assessment["score_method"]]
	if officer["decision"].has("reason"): details.text += "\n【個別判断】\n" + str(officer["decision"]["reason"]) + "\n"
	details.text += "\n【別名】\n" + " / ".join(officer["aliases"]) + "\n\n【出典】\n"
	for ref in assessment["source_refs"]:
		for source in registry.data["sources"]:
			if source["id"] == ref: details.text += str(source["title"]) + "\n" + str(source["url"]) + "\n"
	for url in officer["identity_sources"]: details.text += str(url) + "\n"
	for url in officer["decision"].get("source_urls", []): details.text += str(url) + "\n"

func _total_text(officer: Dictionary) -> String:
	var value: Variant = officer.get("total_ability")
	return "未評価" if value == null else str(int(value))

func _sort_officers(a: String, b: String) -> bool:
	var left: Dictionary = registry.lookup[a]
	var right: Dictionary = registry.lookup[b]
	if sort_order.selected != 3:
		var lv: Variant = left.get("total_ability") if sort_order.selected != 0 else left["assessment"].get("selection_rank")
		var rv: Variant = right.get("total_ability") if sort_order.selected != 0 else right["assessment"].get("selection_rank")
		if lv == null and rv != null: return false
		if lv != null and rv == null: return true
		if lv != null and lv != rv: return lv > rv if sort_order.selected == 1 else lv < rv
	return str(left["display_name"]) < str(right["display_name"])
