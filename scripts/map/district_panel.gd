extends Node
var main: Node2D
var layer: Node2D
var browser: AcceptDialog
var search: LineEdit
var items: ItemList
var details: RichTextLabel
var mode: OptionButton
var toggle: CheckButton
var matches: Array = []
var filter_keys: Array = []
var current_key := ""

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(410,126)
	main.get_node("Interface").add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	toggle = CheckButton.new()
	toggle.text = "郡境"
	toggle.button_pressed = true
	toggle.toggled.connect(layer.set_enabled)
	row.add_child(toggle)
	mode = OptionButton.new()
	mode.add_item("国を選択")
	mode.add_item("郡を選択")
	mode.item_selected.connect(set_mode)
	row.add_child(mode)
	var browse := Button.new()
	browse.text = "郡一覧・検索"
	browse.pressed.connect(show_browser)
	row.add_child(browse)
	var legend := Label.new()
	legend.text = "比較表示：保留を含む" if layer.review_mode else "採用済みのみ・破線＝ゲーム用推定"
	if layer.unconfirmed_mode: legend.text = "未確定版：全郡候補・破線＝推定"
	legend.add_theme_font_size_override("font_size",12)
	row.add_child(legend)
	browser = AcceptDialog.new()
	browser.title = "郡・未確定領域の選択"
	main.get_node("Interface").add_child(browser)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(960,480)
	browser.add_child(content)
	search = LineEdit.new()
	search.placeholder_text = "国名・郡名・IDを検索（地図で省略された郡名も表示）"
	search.text_changed.connect(func(_text: String): refresh())
	content.add_child(search)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(split)
	items = ItemList.new()
	items.custom_minimum_size = Vector2(290,380)
	items.item_selected.connect(select_index)
	split.add_child(items)
	details = RichTextLabel.new()
	details.custom_minimum_size = Vector2(650,380)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(details)
	var go := Button.new()
	go.text = "選択した郡を地図で見る"
	go.pressed.connect(focus_current)
	content.add_child(go)
	refresh()

func set_mode(index: int) -> void:
	main.district_selection_mode = index == 1
	if index == 1:
		main.political_layer.selected_id = ""
		main.political_layer.queue_redraw()
		toggle.set_pressed_no_signal(true)
		layer.set_enabled(true)
		main.selection_label.text = "郡をクリック（境界付近は候補一覧）"
	else:
		layer.select_key("")
		main.selection_label.text = "国をクリックで選択"

func refresh() -> void:
	items.clear()
	matches.clear()
	current_key = ""
	var query := search.text.strip_edges().to_lower()
	var keys: Array = layer.records.keys() if filter_keys.is_empty() else filter_keys
	keys.sort()
	for key in keys:
		var r: Dictionary = layer.records[key]
		if not query.is_empty() and not query in (r["parent_name"]+r["name"]+key+str(r.get("search_aliases", ""))).to_lower(): continue
		matches.append(key)
		items.add_item(r["parent_name"]+" / "+r["name"]+"［"+r["adoption"]+"］")
	details.text = "%d候補。選択すると詳細を表示します。\n境界付近の候補は自動で一つに割り当てません。\n\n※後世の比較形状です。1582年の確定郡境ではありません。\n出典：CODH／人間文化研究機構\ndoi:10.20676/00000454　CC BY-NC 4.0" % matches.size()
	if not layer.initialized: details.text = "郡の比較データがありません。開発用の工程F表示データを生成してください。"
	elif layer.records.is_empty(): details.text = "採用済みの国はまだありません。\n保留形状は通常表示から除外しています。\n国別の比較案は工程Gの作成記録にまとめています。"

func select_index(index: int) -> void:
	if index < 0 or index >= matches.size(): return
	current_key = matches[index]
	layer.select_key(current_key)
	main.show_district_info(current_key)
	var r: Dictionary = layer.records[current_key]
	details.text = "%s / %s\n対象：%d年　資料年代：%s\n採否：%s　確度：%s\n\n【所属拠点】\n確定所属は未設定。以下は登録座標の包含・近傍候補です。\n" % [r["parent_name"],r["name"],r["target_year"],r["source_epoch"],r["adoption"],r["confidence"]]
	if layer.unconfirmed_mode: details.text = "【未確定版・史料上の採用は保留】\n" + details.text
	if r.has("provisional_name"):
		details.text = "【便宜的な仮称・郡所属は未確定】\n%s\n史料の郡名を借用したゲーム用名称です。\n\n" % r["provisional_name"]["method"] + details.text
	if r.has("merge_members"):
		var former_names: PackedStringArray = []
		for member in r["merge_members"]: former_names.append(member["name"])
		details.text = "【表示用合併】%s\n合併後の面積：%.3f km²\n\n" % ["・".join(former_names), r["merge_area_km2"]] + details.text
	for s in r["sites"]:
		details.text += "・%s：%s（%s）\n" % [s["name"],s["basis"],{"ambiguous":"曖昧","unresolved":"未確定","candidate":"候補"}.get(s["status"],s["status"])]
		if s["history"] == "conflict_requires_individual_review": details.text += "  史料所属と面判定が不一致。個別確認待ち。\n"
	if r["sites"].is_empty(): details.text += "該当候補なし\n"
	details.text += "\n【史料】\n"
	for s in r["sources"]: details.text += "%s\n%s\n%s\n\n" % [s["title"],s["locator"],s["url"]]
	if r["sources"].is_empty(): details.text += "郡の形状根拠が不足、または対象年除外。近隣郡へ自動割当しません。\n"
	details.text += "\n【残件】\n"+r["remaining"]+"\n\n出典：CODH／人間文化研究機構（加工）\nCC BY-NC 4.0 / doi:10.20676/00000454"
	details.scroll_to_line(0)

func show_browser() -> void:
	filter_keys = []
	search.text = ""
	refresh()
	browser.popup_centered()

func show_candidates(keys: Array) -> void:
	if keys.is_empty():
		layer.select_key("")
		main.selection_label.text = "郡候補なし（現行区画外）"
		return
	filter_keys = keys
	search.text = ""
	refresh()
	if keys.size()==1:
		items.select(0)
		select_index(0)
	else: layer.select_key("")
	browser.popup_centered()

func focus_current() -> void:
	if current_key.is_empty(): return
	var r: Dictionary = layer.records[current_key]
	mode.select(1)
	set_mode(1)
	main.road_focus_active = false
	main.set_map_zoom(main.MAX_ZOOM)
	main.camera.position = main.elevation.project(Vector2(r["label"][0],r["label"][1]))-Vector2(45,0)
	main._clamp_camera()
	main._refresh_visible_tiles()
	browser.hide()
