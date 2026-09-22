extends Node
var main: Node2D
var layer: Node2D
var browser: AcceptDialog
var search: LineEdit
var regions: OptionButton
var items: ItemList
var details: RichTextLabel
var matches: Array[String] = []
var current_id := ""
var region_ids: Array[String] = ["all"]

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position=Vector2(410,16)
	main.get_node("Interface").add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var toggle := CheckButton.new()
	toggle.text="1582年・%d拠点" % int(layer.data["allocation_policy"]["total"]);toggle.button_pressed=true
	toggle.toggled.connect(layer.set_visible);row.add_child(toggle)
	layer.visibility_changed.connect(func(): toggle.set_pressed_no_signal(layer.visible);main.connection_layer.queue_redraw())
	for role in ["castle","settlement","port"]:
		var button := Button.new()
		button.text={"castle":"城","settlement":"集落","port":"港"}[role]
		button.toggle_mode=true;button.button_pressed=true
		button.toggled.connect(func(value: bool): layer.set_role(value,role); main.connection_layer.queue_redraw();refresh_list())
		row.add_child(button)
	var browse := Button.new()
	browse.text="拠点一覧・検索";browse.pressed.connect(show_browser);row.add_child(browse)
	var south := Button.new()
	south.text="南九州へ";south.pressed.connect(main.focus_road_region.bind("sites:south_kyushu"));row.add_child(south)
	var legend := Label.new()
	legend.text="城郭＝城　丸＝集落　錨＝港　※＝年代・位置に推定を含む"
	legend.add_theme_font_size_override("font_size",12);box.add_child(legend)
	browser=AcceptDialog.new();browser.title="1582年の城・集落・港／全国%d拠点" % int(layer.data["allocation_policy"]["total"])
	main.get_node("Interface").add_child(browser)
	var content := VBoxContainer.new();content.custom_minimum_size=Vector2(840,480);browser.add_child(content)
	var filters := HBoxContainer.new();content.add_child(filters)
	search=LineEdit.new();search.placeholder_text="名前・別名・IDで検索";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String): refresh_list());filters.add_child(search)
	regions=OptionButton.new();regions.add_item("全国")
	for region in layer.data["regions"]:
		regions.add_item("%s（%d）" % [region["name"],region["counts"].get("accepted",0)]);region_ids.append(region["id"])
	regions.item_selected.connect(func(_index: int): refresh_list());filters.add_child(regions)
	var deferred := CheckButton.new();deferred.text="保留も表示"
	deferred.toggled.connect(func(value: bool): layer.show_deferred=value;layer.queue_redraw();refresh_list())
	filters.add_child(deferred)
	var split := HBoxContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(split)
	items=ItemList.new();items.custom_minimum_size=Vector2(280,380);items.size_flags_vertical=Control.SIZE_EXPAND_FILL
	items.item_selected.connect(select_index);split.add_child(items)
	details=RichTextLabel.new();details.bbcode_enabled=false;details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.custom_minimum_size=Vector2(530,380)
	split.add_child(details)
	var go := Button.new();go.text="選択した拠点を地図で見る"
	go.pressed.connect(func():
		if not current_id.is_empty(): focus_site(current_id); browser.hide())
	content.add_child(go)
	refresh_list()

func refresh_list() -> void:
	if items==null: return
	items.clear();matches.clear();current_id=""
	var query:=search.text.strip_edges().to_lower()
	for site in layer.data["sites"]:
		if not layer.eligible(site): continue
		if regions.selected>0 and site["region_id"]!=region_ids[regions.selected]: continue
		var haystack: String=(str(site["display_name"])+str(site["aliases"])+str(site["id"])).to_lower()
		if not query.is_empty() and not query in haystack: continue
		matches.append(site["id"])
		items.add_item(str(site["display_name"])+( "［保留］" if site["adoption_status"]=="deferred" else ""))
		if main.connection_layer.site_connections.has(site["id"]):
			var state: String=main.connection_layer.site_connections[site["id"]]["status"]
			items.set_item_text(items.item_count-1,items.get_item_text(items.item_count-1)+"［"+{"connected":"接続済み","held":"接続保留","land_exempt":"陸路対象外"}[state]+"］")
	details.text="%d地点を表示。地域・種類・名前で絞り込めます。\n全国%d拠点。同じ城下の城・町・港は1拠点として数えます。\n年代・位置は推定を含みます。\n\n地点を選ぶと、年代・位置・出典を表示します。" % [matches.size(),int(layer.data["allocation_policy"]["total"])]

func select_index(index: int) -> void:
	if index<0 or index>=matches.size(): return
	current_id=matches[index]
	var s: Dictionary=layer.lookup[current_id]
	var role_names: Array[String]=[]
	for role in s["roles"]: role_names.append({"castle":"城・館","settlement":"集落","port":"港"}[role])
	details.text="%s\n種類：%s\n旧国：%s\n採用：%s\n\n【対象時点】1582年・本能寺の変の直前\n%s\n\n【位置】地域代表点（精密比定ではありません）\n%s\n\n【名称】%s\n\n【選定理由】%s\n\n【出典】\n" % [s["display_name"]," / ".join(role_names),s["province_name"],{"accepted":"採用済み","deferred":"保留","excluded":"対象外"}[s["adoption_status"]],s["temporal_note"],s["location_note"],s["name_note"],s["selection_reason"]]
	if s.has("components"):
		details.text+="【一拠点にまとめた場所・機能】\n"
		for component in s["components"]: details.text+="・%s\n" % component["display_name"]
		details.text+="\n"
	for ref in s["source_refs"]:
		for source in layer.data["sources"]:
			if source["id"]==ref:
				details.text+="%s\n%s\n%s\n\n" % [source["title"],source["locator"],source["url"]]
				if source.has("attribution"): details.text+="%s / %s\n\n" % [source["attribution"],source["license"]]
	details.scroll_to_line(0)
	if main.connection_layer.site_connections.has(current_id):
		var connection: Dictionary=main.connection_layer.site_connections[current_id]
		details.text="【道路接続】%s\n%s\n残件：%s\n接続案ID：%s\n\n" % [{"connected":"接続済み","held":"接続保留","land_exempt":"陸路対象外"}[connection["status"]],connection["reason"],connection["remaining"],", ".join(connection["route_ids"])]+details.text

func show_browser() -> void:
	refresh_list();browser.popup_centered()

func show_site(id: String) -> void:
	search.text="";regions.select(0);refresh_list()
	var index:=matches.find(id)
	if index>=0: items.select(index);select_index(index)
	browser.popup_centered()

func focus_site(id: String) -> void:
	layer.selected_id=id;layer.show();layer.queue_redraw()
	main.focus_road_region("site:"+id)
