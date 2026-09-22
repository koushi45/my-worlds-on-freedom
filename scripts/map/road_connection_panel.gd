extends Node
var main: Node2D
var layer: Node2D
var browser: AcceptDialog
var items: ItemList
var details: RichTextLabel
var search: LineEdit
var matches: Array[String] = []
var current_id := ""

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position=Vector2(410,82)
	main.get_node("Interface").add_child(panel)
	var row := HBoxContainer.new();panel.add_child(row)
	var toggle := CheckButton.new();toggle.text="推定連絡路";toggle.button_pressed=true
	toggle.toggled.connect(layer.set_visible);row.add_child(toggle)
	toggle.toggled.connect(func(_value: bool): main.connection_layer.queue_redraw())
	var button := Button.new();button.text="道・接続状態を調べる"
	button.pressed.connect(show_browser);row.add_child(button)
	var clear := Button.new();clear.text="選択解除"
	clear.pressed.connect(func(): layer.select_route("");current_id="";main.road_focus_active=false);row.add_child(clear)
	var legend := Label.new();legend.text="黄実線＝道　橙丸＝推定渡河　番号※＝推定通過点"
	legend.add_theme_font_size_override("font_size",12);row.add_child(legend)
	browser=AcceptDialog.new();browser.title="1582年の推定連絡路・接続検査"
	main.get_node("Interface").add_child(browser)
	var content := VBoxContainer.new();content.custom_minimum_size=Vector2(890,490);browser.add_child(content)
	search=LineEdit.new();search.placeholder_text="拠点名・路線名・地域の役割で検索"
	search.text_changed.connect(func(_text: String): refresh());content.add_child(search)
	var split := HBoxContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(split)
	items=ItemList.new();items.custom_minimum_size=Vector2(330,370)
	items.item_selected.connect(select_index);split.add_child(items)
	details=RichTextLabel.new();details.custom_minimum_size=Vector2(550,370)
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(details)
	var go := Button.new();go.text="選択した道と通過点を地図で見る"
	go.pressed.connect(focus_current);content.add_child(go)
	refresh()

func refresh() -> void:
	items.clear();matches.clear();current_id=""
	var query := search.text.strip_edges()
	for route in layer.data["routes"]:
		if not query.is_empty() and not query in str(route["name"])+str(route["purpose"])+str(route["id"]): continue
		matches.append(route["id"]);items.add_item(route["name"])
	var counts: Dictionary = layer.data["summary"]["site_status_counts"]
	details.text="対象%d拠点\n接続済み %d / 接続保留 %d / 陸路対象外 %d\n\n接続済みは推定接続域まで。主郭・門・船着場の精密比定は含みません。\n\n全てゲーム用の推定連絡路です。1582年の道・橋の存在を断定しません。\n\n拠点一覧には各拠点の接続状態と残件を表示します。\n黄実線＝道、橙丸＝推定渡河、番号※＝推定通過点、淡青の引出線＝記号と接続域の対応（道路ではありません）。" % [layer.site_connections.size(),counts.get("connected",0),counts.get("held",0),counts.get("land_exempt",0)]

func select_index(index: int) -> void:
	if index < 0 or index >= matches.size(): return
	current_id=matches[index]
	var r: Dictionary=layer.route_lookup[current_id]
	var m: Dictionary=r["metrics"]
	details.text="%s\n\n目的：%s\n採用：ゲーム用の推定連絡路\n対象年：1582年の利用は未確認\n線形：現代の実標高・水系を使った推定\n\n距離 %.1f km / 累積上昇 %.0f m / 下降 %.0f m\n最大勾配 %.1f%%（約453mの標高資料）\n渡河 %d区間：方法・当時の位置は未確認\n\n%s\n\n【出典と閲覧範囲】\n" % [r["name"],r["purpose"],m["length_m"]/1000,m["ascent_m"],m["descent_m"],m["max_grade"]*100,r["crossing_ids"].size(),r["note"]]
	for source in layer.data["sources"]:
		if source["id"] in r["source_refs"]:
			details.text+="%s\n%s\n%s\n" % [source["title"],source["locator"],source["access_scope"]]
			if source["url"] != null: details.text+=str(source["url"])+"\n"
			details.text+="\n"
	details.text+="【順序付き通過点】\n"
	for waypoint in r["waypoints"]: details.text+="%d※ %s\n" % [waypoint["order"],waypoint["name"]]
	details.scroll_to_line(0)

func focus_current() -> void:
	if current_id.is_empty(): return
	layer.show();layer.select_route(current_id)
	var r: Dictionary=layer.route_lookup[current_id]
	var bounds := Rect2(main.elevation.project(layer.point(r["points"][0])),Vector2.ZERO)
	for p in r["points"]: bounds=bounds.expand(main.elevation.project(layer.point(p)))
	bounds=bounds.grow(12)
	var available := main.get_viewport_rect().size-Vector2(430,150)
	var zoom_value := minf(available.x/maxf(bounds.size.x,1),available.y/maxf(bounds.size.y,1))
	zoom_value=clampf(zoom_value,0.18,main.MAX_ZOOM)
	main.set_map_zoom(zoom_value)
	main.camera.position=bounds.get_center()-Vector2(205,65)/zoom_value
	main.road_focus_active=true
	main.current_road_region="connection"
	main._refresh_visible_tiles()
	browser.hide()

func show_browser() -> void:
	refresh();browser.popup_centered()
