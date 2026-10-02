extends CanvasLayer
## Lacquer-and-gold district sortie and placement controls.
const UI = preload("res://scripts/game/menu_style.gd")
const Style = preload("res://scripts/game/district_panel_style.gd")
var main: Node2D
var panel: PanelContainer
var body: VBoxContainer
var right_panel: PanelContainer
var roster: VBoxContainer
var district_id := ""
var unit_id := ""
var mode := ""
var choosing_target := false
var append_target := false
var selected_officers: Array[String] = ["", "", ""]
var strength: OptionButton
var horses: CheckButton
var guns: CheckButton
var status: Label

func _ready() -> void:
	layer = 25
	panel = _panel(Vector2(16, 160), 410)
	body = VBoxContainer.new(); body.add_theme_constant_override("separation", 8); panel.add_child(body)
	right_panel = _panel(Vector2(438, 160), 450)
	var right_body := VBoxContainer.new(); right_body.add_theme_constant_override("separation", 8); right_panel.add_child(right_body)
	Style.heading("武将を選ぶ", right_body, 19)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Style.field(scroll); right_body.add_child(scroll)
	roster = VBoxContainer.new(); roster.custom_minimum_size.x = 410; roster.add_theme_constant_override("separation", 5); scroll.add_child(roster)
	_button("閉じる", hide_roster, right_body)
	panel.hide(); right_panel.hide()
	main.army_campaign.changed.connect(refresh)
	main.retainer_management.updated.connect(_on_placement_changed)

func _panel(location: Vector2, width: float) -> PanelContainer:
	var result := PanelContainer.new()
	result.position = location
	result.custom_minimum_size.x = width
	var decoration := StyleBoxFlat.new()
	decoration.bg_color = Color("#171311")
	decoration.border_color = Color("#c5a15f")
	decoration.set_border_width_all(2)
	decoration.set_corner_radius_all(6)
	decoration.set_content_margin_all(14)
	result.add_theme_stylebox_override("panel", decoration)
	add_child(result)
	return result

func _clear(target: Node) -> void:
	for child in target.get_children(): target.remove_child(child); child.queue_free()

func _label(value: String, font_size := 15, parent: Node = body) -> Label:
	return UI.label(value, parent, font_size)

func _button(value: String, action: Callable, parent: Control = body) -> Button:
	var result := Style.button(value, parent, action)
	result.custom_minimum_size = Vector2(0, 39)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", 16)
	return result

func show_district(id: String) -> void:
	mode = "formation"; district_id = id; unit_id = ""
	selected_officers = ["", "", ""]
	hide_roster(); refresh()

func show_placement(id: String) -> void:
	mode = "placement"; district_id = id; unit_id = ""
	hide_roster(); refresh()

func show_unit(id: String) -> void:
	mode = "unit"; district_id = ""; unit_id = id; choosing_target = false
	hide_roster()
	main.army_campaign.selected_id = id
	main.army_campaign.queue_redraw()
	refresh()

func refresh() -> void:
	if not is_inside_tree(): return
	_clear(body)
	if mode == "unit" and main.army_campaign.units.has(unit_id): _build_unit()
	elif mode == "formation" and main.governance_registry.districts.has(district_id): _build_formation()
	elif mode == "placement" and main.governance_registry.districts.has(district_id): _build_placement()
	else: panel.hide(); hide_roster()

func _own_district() -> bool:
	return main.governance_registry.districts[district_id].house_id == GameSession.player_house

func _build_formation() -> void:
	if not _own_district(): panel.hide(); return
	var district: Dictionary = main.governance_registry.districts[district_id]
	panel.show()
	Style.heading("%sから出陣" % district.name, body, 20)
	_label("出陣可能 %d人　兵糧 %d" % [main.district_actions.sortie_available(district), int(main.district_economy.house_resources[district.house_id].provisions)])
	var available: Array[String] = main.army_campaign.available_officers(district_id)
	_label("この郡の配置武将 %d人" % available.size(), 13)
	for index in 3:
		var officer_id: String = selected_officers[index]
		if not officer_id.is_empty() and officer_id not in available: selected_officers[index] = ""; officer_id = ""
		var officer_name: String = main.officer_registry.lookup[officer_id].display_name if not officer_id.is_empty() else ("選択してください" if index == 0 else "なし")
		_button("%s　%s" % [["大将", "副将 一", "副将 二"][index], officer_name], _open_officer_roster.bind(index))
	strength = OptionButton.new()
	strength.add_theme_font_size_override("font_size", 16)
	var selected_percent := -1
	for percent in [25, 50, 75, 100]:
		strength.add_item("兵数 %d%%" % percent, percent)
		var soldiers := floori(float(main.district_actions.sortie_available(district)) * percent / 100.0)
		var affordable := soldiers >= 100 and ceili(soldiers * 0.4) <= int(main.district_economy.house_resources[district.house_id].provisions)
		strength.set_item_disabled(strength.item_count - 1, not affordable)
		if affordable: selected_percent = strength.item_count - 1
	if selected_percent >= 0: strength.select(selected_percent)
	body.add_child(strength)
	horses = CheckButton.new(); horses.text = "軍馬を配備（兵数の2割）"; body.add_child(horses)
	guns = CheckButton.new(); guns.text = "鉄砲を配備（兵数の2割）"; body.add_child(guns)
	horses.disabled = int(main.district_economy.house_resources[district.house_id].get("horses", 0)) == 0
	guns.disabled = int(main.district_economy.house_resources[district.house_id].get("guns", 0)) == 0
	_button("出陣", _dispatch)
	status = _label("大将・副将の枠を押すと右側に武将一覧が開きます。", 13)
	_button("閉じる", hide_panel)

func _open_officer_roster(index: int) -> void:
	_clear(roster)
	var available: Array[String] = main.army_campaign.available_officers(district_id)
	if index > 0: _button("なし", _choose_officer.bind(index, ""), roster)
	var count := 0
	for officer_id in available:
		if officer_id in selected_officers and selected_officers[index] != officer_id: continue
		var officer: Dictionary = main.officer_registry.lookup[officer_id]
		var command: Variant = main.officer_registry.ability(officer_id, "command")
		_button("%s　統率 %s" % [officer.display_name, str(command) if command != null else "—"], _choose_officer.bind(index, officer_id), roster)
		count += 1
	if count == 0: _label("選べる武将がいません。郡へ家臣を配置してください。", 14, roster)
	right_panel.show()

func _choose_officer(index: int, officer_id: String) -> void:
	selected_officers[index] = officer_id
	hide_roster(); refresh()

func _dispatch() -> void:
	if selected_officers[0].is_empty(): status.text = "大将を選んでください。"; return
	var chosen := []
	for officer_id in selected_officers:
		if not officer_id.is_empty(): chosen.append(officer_id)
	var id: String = main.army_campaign.dispatch(district_id, chosen, strength.get_selected_id(), horses.button_pressed, guns.button_pressed)
	if id.is_empty(): status.text = main.army_campaign.last_error
	else: show_unit(id)

func _build_placement() -> void:
	if not _own_district(): panel.hide(); return
	panel.show()
	Style.heading("%sの武将配置" % main.governance_registry.districts[district_id].name, body, 20)
	_label("配置は出陣の候補にのみ反映されます。", 13)
	var placed: Array[String] = main.retainer_management.officers_in_district(GameSession.player_house, district_id)
	_label("配置中 %d人" % placed.size())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(370, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Style.field(scroll); body.add_child(scroll)
	var rows := VBoxContainer.new(); rows.custom_minimum_size.x = 360; scroll.add_child(rows)
	for officer_id in placed:
		_button("%s　配置を解除" % main.officer_registry.lookup[officer_id].display_name, _place_officer.bind(officer_id, ""), rows)
	if placed.is_empty(): _label("配置武将なし", 14, rows)
	_button("家臣を配置", _open_placement_roster)
	status = _label("家臣は一度に一つの郡へ配置できます。", 13)
	_button("閉じる", hide_panel)

func _open_placement_roster() -> void:
	_clear(roster)
	var house_id: String = GameSession.player_house
	var ids: Array[String] = []
	var ruler_id: String = main.retainer_management.ruler_id(house_id)
	if not ruler_id.is_empty() and main.officer_registry.lookup.has(ruler_id): ids.append(ruler_id)
	for officer_id in main.retainer_management.house_members.get(house_id, []):
		if officer_id not in ids: ids.append(officer_id)
	ids.sort_custom(func(a: String, b: String): return main.army_campaign.score(a) > main.army_campaign.score(b))
	for officer_id in ids:
		var placed_id: String = str(main.retainer_management.officer_districts.get(officer_id, ""))
		var placed_name := "未配置" if placed_id.is_empty() else str(main.governance_registry.districts.get(placed_id, {}).get("name", "他の郡"))
		var button := _button("%s　[%s]" % [main.officer_registry.lookup[officer_id].display_name, placed_name], _place_officer.bind(officer_id, district_id), roster)
		button.disabled = placed_id == district_id or _deployed(officer_id)
	right_panel.show()

func _deployed(officer_id: String) -> bool:
	for unit in main.army_campaign.units.values():
		if officer_id in unit.officers: return true
	return false

func _place_officer(officer_id: String, destination: String) -> void:
	var result: Error = main.retainer_management.place_officer(GameSession.player_house, officer_id, destination)
	if result != OK: status.text = "出陣中の武将や他家の武将は配置を変更できません。"; return
	hide_roster(); refresh()

func _on_placement_changed() -> void:
	if mode == "placement" or mode == "formation": refresh()

func _build_unit() -> void:
	var unit: Dictionary = main.army_campaign.units[unit_id]
	panel.show()
	var names := PackedStringArray()
	for id in unit.officers: names.append(main.officer_registry.lookup[id].display_name)
	Style.heading("部隊　%s" % names[0], body, 20)
	_label("大将・副将：" + " / ".join(names), 13)
	_label("兵数 %d人　腰兵糧 %d日" % [unit.soldiers, maxi(0, unit.supply_days)])
	_label("現在：%s%s" % [main.army_campaign.node_name(unit.site_id), " → " + main.army_campaign.node_name(unit.next_site) if not unit.next_site.is_empty() else ""])
	if not unit.next_site.is_empty():
		var cell: Vector2i = preload("res://scripts/map/hex_grid.gd").cell_at(main.army_campaign.node_point(unit.next_site))
		var terrain = preload("res://scripts/map/hex_terrain.gd")
		var days: float = main.army_campaign.travel_days_for_leg(unit.site_id, unit.next_site)
		_label("進入先：%s（%s）" % [terrain.name_for(main.hex_tile_layer.terrain_for(cell)), "通行不可" if is_inf(days) else "1タイル %.1f日" % days], 13)
	var destination: String = main.army_campaign.node_name(unit.orders.back()) if not unit.orders.is_empty() else (main.army_campaign.node_name(unit.next_site) if not unit.next_site.is_empty() else ("占領中" if main.army_campaign._hostile_office(unit) else ("攻城中" if main.army_campaign._hostile_castle(unit) else "待機中")))
	if unit.house_id == GameSession.player_house:
		_button("目標：%s" % destination, func(): choosing_target = true; append_target = false; status.text = "地図上の六角形をクリックしてください。")
	else:
		_label("目標：%s" % destination)
	if main.army_campaign._hostile_office(unit):
		var office_id: String = main.army_campaign.district_id_for_node(unit.site_id)
		_label("奉行所の防御：%d" % int(main.army_campaign.office_defenses.get(office_id, 0)))
	if unit.house_id == GameSession.player_house:
		_button("経由点を追加", func(): choosing_target = true; append_target = true; status.text = "経由するタイルをクリックしてください。")
		_button("帰郡", func():
			if not main.army_campaign.return_home(unit_id): status.text = main.army_campaign.last_error)
		status = _label("六角形をクリックで移動。部隊からドラッグで経路を描けます。Shift＋クリックで経由点を追加。", 12)
	_button("閉じる", hide_panel)

func handle_site_click(id: String, shift: bool) -> bool:
	return handle_node_click(id, shift)

func handle_district_click(id: String, shift: bool) -> bool:
	return handle_node_click("district:" + id, shift)

func handle_node_click(id: String, shift: bool) -> bool:
	if not main.army_campaign.units.has(unit_id) or main.army_campaign.units[unit_id].house_id != GameSession.player_house: return false
	if not main.army_campaign.order(unit_id, id, (append_target if choosing_target else false) or shift):
		status.text = main.army_campaign.last_error
	else:
		choosing_target = false
		refresh()
	return true

func hide_roster() -> void:
	right_panel.hide()

func hide_panel() -> void:
	panel.hide(); hide_roster()
	mode = ""; choosing_target = false; district_id = ""; unit_id = ""
	main.army_campaign.selected_id = ""
	main.army_campaign.queue_redraw()
