extends CanvasLayer
## Lacquer-and-gold district sortie and placement controls.
const UI = preload("res://scripts/game/menu_style.gd")
const Style = preload("res://scripts/game/district_panel_style.gd")
var main: Node2D
var loot_context_id := ""
var panel: PanelContainer
var body: VBoxContainer
var right_panel: PanelContainer
var roster: VBoxContainer
var occupation_panel: PanelContainer
var occupation_body: VBoxContainer
var occupation_scroll: ScrollContainer
var army_scroll: ScrollContainer
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
var automatic_dialog: ConfirmationDialog
var automatic_mode: OptionButton
var automatic_house: OptionButton
var automatic_houses: Array[String] = []
var merge_dialog: ConfirmationDialog
var merge_house_units: OptionButton
var merge_ids: Array[String] = []
var commanders_dialog: AcceptDialog
var commander_choices: Array[OptionButton] = []
var commander_pool: Array = []

func _ready() -> void:
	layer = 25
	panel = _panel(Vector2(16, 160), 410)
	army_scroll = ScrollContainer.new()
	army_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(army_scroll)
	body = VBoxContainer.new(); body.add_theme_constant_override("separation", 8); army_scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	occupation_panel = _panel(Vector2.ZERO, 350)
	occupation_panel.name = "OccupationPanel"
	occupation_scroll = ScrollContainer.new()
	occupation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	occupation_panel.add_child(occupation_scroll)
	occupation_body = VBoxContainer.new()
	occupation_body.add_theme_constant_override("separation", 10)
	occupation_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	occupation_body.custom_minimum_size.x = 322
	occupation_scroll.add_child(occupation_body)
	occupation_panel.hide()
	get_viewport().size_changed.connect(_layout_panels)
	_layout_panels()
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
	automatic_dialog = ConfirmationDialog.new()
	automatic_dialog.title = "部隊の自動操作"
	automatic_dialog.min_size = Vector2i(420, 240)
	automatic_dialog.get_ok_button().text = "命令"
	automatic_dialog.get_cancel_button().text = "取消"
	var dialog_border := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	dialog_border.content_margin_top = 32
	dialog_border.set_expand_margin_all(8)
	dialog_border.set_expand_margin(SIDE_TOP, 32)
	automatic_dialog.add_theme_stylebox_override("embedded_border", dialog_border)
	automatic_dialog.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel").duplicate())
	automatic_dialog.add_theme_color_override("title_color", Style.GOLD)
	add_child(automatic_dialog)
	var automatic_rows := VBoxContainer.new()
	automatic_dialog.add_child(automatic_rows)
	automatic_mode = OptionButton.new()
	automatic_mode.add_item("占領：指定家の郡を順に制圧", 0)
	automatic_mode.add_item("戦闘：勝てる敵部隊を追撃", 1)
	automatic_rows.add_child(automatic_mode)
	automatic_house = OptionButton.new()
	Style.field(automatic_mode)
	Style.field(automatic_house)
	automatic_rows.add_child(automatic_house)
	var hint := UI.label("兵力・兵糧不足や攻略困難時は帰還。\n戦闘の勝敗判断に地形補正は使いません。", automatic_rows, 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("自動操作を解除", _stop_automatic, automatic_rows)
	automatic_dialog.confirmed.connect(_set_automatic)
	merge_dialog = ConfirmationDialog.new()
	merge_dialog.title = "部隊の合流"
	merge_dialog.min_size = Vector2i(420, 190)
	merge_dialog.get_ok_button().text = "合流"
	merge_dialog.get_cancel_button().text = "取消"
	_style_dialog(merge_dialog)
	var merge_rows := VBoxContainer.new()
	merge_dialog.add_child(merge_rows)
	merge_house_units = OptionButton.new()
	Style.field(merge_house_units); merge_rows.add_child(merge_house_units)
	var merge_hint := UI.label("同じ六角形に停止中の自家部隊を合流します。\n帰還先は選択中の部隊を引き継ぎます。\n移動・自動命令を解除し、合流後に武将を編集できます。", merge_rows, 13)
	merge_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	merge_dialog.confirmed.connect(_merge_selected)
	commanders_dialog = AcceptDialog.new()
	commanders_dialog.title = "大将・副将の編集"
	commanders_dialog.min_size = Vector2i(440, 240)
	commanders_dialog.get_ok_button().text = "閉じる"
	_style_dialog(commanders_dialog)
	var commanders_rows := VBoxContainer.new()
	commanders_rows.add_theme_constant_override("separation", 8)
	commanders_dialog.add_child(commanders_rows)
	for index in 3:
		var row := HBoxContainer.new(); commanders_rows.add_child(row)
		UI.label(["大将", "副将 一", "副将 二"][index], row, 15)
		var choice := OptionButton.new(); choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Style.field(choice); row.add_child(choice); commander_choices.append(choice)
		choice.item_selected.connect(_change_commander.bind(index))
	UI.label("部隊に随伴する武将から選択できます。\n変更は即時反映。役職にない武将も交代できます。", commanders_rows, 13)
	main.army_campaign.changed.connect(refresh)
	main.game_clock.pause_changed.connect(func(_paused: bool): refresh())
	main.retainer_management.updated.connect(_on_placement_changed)

func _style_dialog(dialog: AcceptDialog) -> void:
	var border := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	border.set_expand_margin_all(8); border.set_expand_margin(SIDE_TOP, 32)
	dialog.add_theme_stylebox_override("embedded_border", border)
	dialog.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel").duplicate())
	dialog.add_theme_color_override("title_color", Style.GOLD)
	add_child(dialog)

func _panel(location: Vector2, width: float) -> PanelContainer:
	var result := PanelContainer.new()
	result.position = location
	result.custom_minimum_size.x = width
	var decoration := StyleBoxFlat.new()
	decoration.bg_color = Color("#0c1422")
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
	loot_context_id = ""
	mode = "formation"; district_id = id; unit_id = ""
	selected_officers = ["", "", ""]
	var recommended: Array[String] = main.army_campaign.recommended_officers(id)
	for index in recommended.size(): selected_officers[index] = recommended[index]
	hide_roster(); refresh()

func show_placement(id: String) -> void:
	loot_context_id = ""
	mode = "placement"; district_id = id; unit_id = ""
	hide_roster(); refresh()

func show_unit(id: String, from_map_click := false) -> void:
	loot_context_id = ""
	if from_map_click and main.army_campaign.units.has(id):
		var unit: Dictionary = main.army_campaign.units[id]
		if unit.site_id.begins_with("district:") and unit.next_site.is_empty() and unit.orders.is_empty(): loot_context_id = id
	mode = "unit"; district_id = ""; unit_id = id; choosing_target = false
	hide_roster()
	main.army_campaign.selected_id = id
	main.army_campaign.queue_redraw()
	refresh()

func refresh() -> void:
	if not is_inside_tree(): return
	occupation_panel.hide()
	_clear(occupation_body)
	_clear(body)
	if mode == "unit" and main.army_campaign.units.has(unit_id): _build_unit()
	elif mode == "formation" and main.governance_registry.districts.has(district_id): _build_formation()
	elif mode == "placement" and main.governance_registry.districts.has(district_id): _build_placement()
	else: panel.hide(); hide_roster()
	_layout_panels()

func _layout_panels() -> void:
	var view_size := get_viewport().get_visible_rect().size
	army_scroll.custom_minimum_size = Vector2(382, maxf(100, view_size.y - 244))
	occupation_scroll.custom_minimum_size = Vector2(322, maxf(100, view_size.y - 154))
	occupation_panel.position = Vector2(view_size.x - 366, 110)
	panel.size = Vector2.ZERO
	occupation_panel.size = Vector2.ZERO

func _occupation_label(value: String, font_size := 15) -> Label:
	var label := _label(value, font_size, occupation_body)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_occupation(id: String) -> void:
	var info: Dictionary = main.army_campaign.occupation_display(id)
	if info.is_empty(): return
	occupation_panel.show()
	_occupation_label("制圧状況", 20).add_theme_color_override("font_color", Style.GOLD)
	_occupation_label(info.title, 22).add_theme_color_override("font_color", Style.GOLD)
	_occupation_label("制圧率 %.0f%%" % info.progress, 24)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 16
	bar.show_percentage = false
	bar.value = info.progress
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#171b25")
	track.border_color = Style.GOLD
	track.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Style.GOLD
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	occupation_body.add_child(bar)
	_occupation_label(info.estimate, 22)
	_occupation_label(info.change, 17)
	if float(info.rate) > 0.0: _occupation_label("現在の兵数・敵情が続く場合", 12)
	occupation_body.add_child(HSeparator.new())
	# Individual troop count and supplies belong exclusively to the left panel.
	_occupation_label("制圧参加部隊：%d部隊" % info.count)
	_occupation_label("周辺の敵部隊：" + ("あり" if info.contested else "なし"))
	_occupation_label(info.reason, 14)
	occupation_body.add_child(HSeparator.new())
	_occupation_label("制圧が完了すると", 17).add_theme_color_override("font_color", Style.GOLD)
	_occupation_label("この郡と郡内の城・港が自家領になります。", 14)
	_occupation_label("制圧後の統治", 17).add_theme_color_override("font_color", Style.GOLD)
	_occupation_label("収入50%・徴兵と出陣は統治安定後に可能。奉行所への100人以上の駐屯と郡代の任命で安定化が早まります。", 14)

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
	status = _label("統率優先の大将と、平均武勇を高める副将を自動選択。\n各枠を押すと変更できます。" if not available.is_empty() else "出陣できる武将がいません。郡へ武将を配置してください。", 13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	if count == 0: _label("選べる武将がいません。郡へ武将を配置してください。", 14, roster)
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
	_button("武将を配置", _open_placement_roster)
	status = _label("大名・家臣は一度に一つの郡へ配置できます。", 13)
	_button("閉じる", hide_panel)

func _open_placement_roster() -> void:
	_clear(roster)
	var house_id: String = GameSession.player_house
	var ids: Array[String] = main.retainer_management.officers_for_house(house_id)
	ids.sort_custom(func(a: String, b: String): return main.army_campaign.score(a) > main.army_campaign.score(b))
	for officer_id in ids:
		var placed_id: String = str(main.retainer_management.officer_districts.get(officer_id, ""))
		var placed_name := "未配置" if placed_id.is_empty() else str(main.governance_registry.districts.get(placed_id, {}).get("name", "他の郡"))
		var role: String = main.retainer_management.role_of(house_id, officer_id)
		var button := _button("%s（%s）　[%s]" % [main.officer_registry.lookup[officer_id].display_name, role, placed_name], _place_officer.bind(officer_id, district_id), roster)
		button.disabled = placed_id == district_id or _deployed(officer_id)
	right_panel.show()

func _deployed(officer_id: String) -> bool:
	for unit in main.army_campaign.units.values():
		if officer_id in main.army_campaign.officer_pool(unit): return true
	return false

func _place_officer(officer_id: String, destination: String) -> void:
	var result: Error = main.retainer_management.place_officer(GameSession.player_house, officer_id, destination)
	if result != OK: status.text = "出陣中の武将や他家の武将は配置を変更できません。"; return
	hide_roster(); refresh()

func _on_placement_changed() -> void:
	if mode == "placement" or mode == "formation": refresh()

func _build_unit() -> void:
	var unit: Dictionary = main.army_campaign.units[unit_id]
	if not unit.next_site.is_empty() or not unit.orders.is_empty(): loot_context_id = ""
	panel.show()
	var names := PackedStringArray()
	for id in unit.officers: names.append(main.officer_registry.lookup[id].display_name)
	Style.heading("部隊　%s" % names[0], body, 20)
	var lineup := "大将：%s\n副将：%s" % [names[0], " / ".join(names.slice(1)) if names.size() > 1 else "なし"]
	if unit.house_id == GameSession.player_house: _button(lineup, _open_commanders)
	else: _label(lineup, 13)
	var accompanying: int = main.army_campaign.officer_pool(unit).size() - unit.officers.size()
	if accompanying > 0: _label("役職なしの随伴武将：%d人（武将枠から交代可能）" % accompanying, 12)
	_label("兵数 %d人　腰兵糧 %d日" % [unit.soldiers, maxi(0, unit.supply_days)])
	_label("部隊武勇：%.1f（大将・副将の平均）" % main.army_campaign.unit_valor(unit), 13)
	_label("現在：%s%s" % [main.army_campaign.node_name(unit.site_id), " → " + main.army_campaign.node_name(unit.next_site) if not unit.next_site.is_empty() else ""])
	var in_melee: bool = main.army_campaign.melee_engagements().has(unit_id)
	_label("接近戦中：人数と武勇で攻撃" if in_melee else "弓射程：1.5マス　%s" % ("静止射撃" if unit.next_site.is_empty() or unit.get("movement_hold", false) else "移動射撃"), 13)
	_label("敵軍を狙って射撃。射線上の自軍・味方にも命中。", 12)
	if not unit.next_site.is_empty():
		var cell: Vector2i = preload("res://scripts/map/hex_grid.gd").cell_at(main.army_campaign.node_point(unit.next_site))
		var terrain = preload("res://scripts/map/hex_terrain.gd")
		var days: float = main.army_campaign.travel_days_for_leg(unit.site_id, unit.next_site)
		_label("進入先：%s（%s）" % [terrain.name_for(main.hex_tile_layer.terrain_for(cell)), "通行不可" if is_inf(days) else "1タイル %.1f日" % days], 13)
	var capturing: bool = main.army_campaign.may_capture_office(unit)
	var destination: String = main.army_campaign.node_name(unit.orders.back()) if not unit.orders.is_empty() else (main.army_campaign.node_name(unit.next_site) if not unit.next_site.is_empty() else (main.army_campaign.node_name(unit.site_id) if capturing and main.army_campaign._hostile_office(unit) else ("攻城中" if capturing and main.army_campaign._hostile_castle(unit) else "待機中")))
	if unit.house_id == GameSession.player_house:
		_button("目標：%s" % destination, func(): choosing_target = true; append_target = false; status.text = "地図上の六角形をクリックしてください。")
	else:
		_label("目標：%s" % destination)
	var occupation_id: String = main.army_campaign.unit_occupation_district(unit_id)
	if not occupation_id.is_empty():
		_build_occupation(occupation_id)
	elif unit.site_id.begins_with("district:") and not main.army_campaign._hostile_office(unit):
		var stability_label := _label(main.army_campaign.stability_summary(main.army_campaign.district_id_for_node(unit.site_id)), 13)
		stability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if unit.house_id == GameSession.player_house:
		var commands := HBoxContainer.new()
		commands.add_theme_constant_override("separation", 8)
		body.add_child(commands)
		var loot_district: String = main.army_campaign.district_id_for_node(unit.site_id)
		if not loot_district.is_empty() and unit.next_site.is_empty() and main.army_campaign.selected_id == unit_id and loot_context_id == unit_id:
			var loot_reason: String = main.army_campaign.loot_unavailable_reason(unit_id)
			var loot_button := _button("略奪", _loot_selected, commands)
			loot_button.disabled = not loot_reason.is_empty()
			loot_button.tooltip_text = loot_reason if not loot_reason.is_empty() else "敵家の金銭・兵糧を奪う。荒廃+10・治安-10。同じ郡は30日に1回。"
		_button("経由点を追加", func(): choosing_target = true; append_target = true; status.text = "経由するタイルをクリックしてください。", commands)
		var merge_button := _button("合流", _open_merge, commands)
		merge_button.disabled = main.army_campaign.merge_candidates(unit_id).is_empty()
		merge_button.tooltip_text = "同じ六角形に停止中の自家部隊が必要です。接近戦中は合流できません。"
		var drill: Dictionary = main.technology_orders.drills.get(unit_id, {})
		var drill_text := "出陣前の調練（軍事%d・兵糧%d）" % [main.technology_orders.point_cost(GameSession.player_house, 100), ceili(int(unit.soldiers)*0.1)]
		if not drill.is_empty() and main.technology_orders.today() < int(drill.end):
			drill_text = "調練 あと%d日" % (int(drill.ready)-main.technology_orders.today()) if main.technology_orders.training(unit_id) else "調練効果 +%.1f%%／あと%d日" % [(main.technology_orders.combat_multiplier(unit)-1.0)*100, int(drill.end)-main.technology_orders.today()]
		var drill_button := _button(drill_text, _start_drill)
		var drill_reason: String = main.technology_orders.drill_reason(unit_id, GameSession.player_house)
		drill_button.disabled = not drill_reason.is_empty()
		drill_button.tooltip_text = "14日準備後、90日間戦闘効率+15%。合流で未調練兵が増えると効果低下。\n" + drill_reason
		var orders_row := HBoxContainer.new()
		orders_row.add_theme_constant_override("separation", 8)
		body.add_child(orders_row)
		_button("帰郡", func():
			if not main.army_campaign.return_home(unit_id): status.text = main.army_campaign.last_error, orders_row)
		var automatic: Variant = unit.get("automatic")
		var automatic_name := "手動" if not automatic is Dictionary else ("占領" if automatic.mode == "occupy" else "戦闘")
		_button("自動：" + automatic_name, _open_automatic, orders_row)
		status = _label("クリックで経由点追加・同じ目的地で取消。\nドラッグで区間取消／回転で向き変更／右クリックで解除。" if not automatic is Dictionary else "対象：%s\n%s" % [main.governance_registry.houses[automatic.house_id].display_name, automatic.status], 12)
		if automatic is Dictionary and not occupation_id.is_empty(): status.text = "自動操作の対象：%s" % main.governance_registry.houses[automatic.house_id].display_name
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("閉じる", hide_panel)

func _start_drill() -> void:
	var reason: String = main.technology_orders.drill_reason(unit_id, GameSession.player_house)
	if main.technology_orders.start_drill(unit_id, GameSession.player_house) != OK:
		status.text = reason
	else:
		refresh()

func _open_merge() -> void:
	merge_ids = main.army_campaign.merge_candidates(unit_id)
	merge_house_units.clear()
	for id in merge_ids:
		var unit: Dictionary = main.army_campaign.units[id]
		merge_house_units.add_item("%s隊　%d人" % [main.officer_registry.lookup[unit.officers[0]].display_name, unit.soldiers])
	merge_dialog.get_ok_button().disabled = merge_ids.is_empty()
	merge_dialog.popup_centered()

func _merge_selected() -> void:
	var index := merge_house_units.selected
	if index < 0 or index >= merge_ids.size(): return
	if not main.army_campaign.merge(unit_id, merge_ids[index]):
		if is_instance_valid(status): status.text = main.army_campaign.last_error
		return
	loot_context_id = ""; hide_roster(); refresh()
	_open_commanders()

func _open_commanders() -> void:
	if not main.army_campaign.units.has(unit_id): return
	var unit: Dictionary = main.army_campaign.units[unit_id]
	if unit.house_id != GameSession.player_house: return
	commander_pool = main.army_campaign.officer_pool(unit).duplicate()
	for index in 3:
		var choice: OptionButton = commander_choices[index]
		choice.clear()
		if index > 0: choice.add_item("なし")
		for officer_id in commander_pool:
			choice.add_item("%s（統率%d・武勇%d）" % [main.officer_registry.lookup[officer_id].display_name, main.army_campaign.score(officer_id), main.officer_registry.ability(officer_id, "tactics")])
	_update_commander_choices()
	commanders_dialog.popup_centered()

func _update_commander_choices() -> void:
	if not main.army_campaign.units.has(unit_id): commanders_dialog.hide(); return
	var officers: Array = main.army_campaign.units[unit_id].officers
	for index in 3:
		var selected: int = commander_pool.find(officers[index]) + (1 if index > 0 else 0) if index < officers.size() else 0
		commander_choices[index].select(selected)

func _change_commander(selected: int, slot: int) -> void:
	if not main.army_campaign.units.has(unit_id): commanders_dialog.hide(); return
	var officers: Array = main.army_campaign.units[unit_id].officers.duplicate()
	while officers.size() < 3: officers.append("")
	var officer_id: String = "" if slot > 0 and selected == 0 else commander_pool[selected - (1 if slot > 0 else 0)]
	var previous: String = officers[slot]
	var existing := officers.find(officer_id) if not officer_id.is_empty() else -1
	if existing >= 0 and existing != slot: officers[existing] = previous
	officers[slot] = officer_id
	var chosen: Array = []
	for id in officers:
		if not id.is_empty(): chosen.append(id)
	main.army_campaign.set_commanders(unit_id, chosen)
	_update_commander_choices()

func _loot_selected() -> void:
	var result: String = main.army_campaign.loot_selected(unit_id)
	status.text = result if not result.is_empty() else main.army_campaign.last_error

func _open_automatic() -> void:
	if not main.army_campaign.units.has(unit_id): return
	automatic_houses.clear(); automatic_house.clear()
	var current: Variant = main.army_campaign.units[unit_id].get("automatic")
	for house_id in main.governance_registry.houses:
		if GameSession.relation(GameSession.player_house, house_id) != "enemy" or main.diplomacy.truce_remaining(GameSession.player_house, house_id) > 0: continue
		automatic_houses.append(house_id)
		automatic_house.add_item(main.governance_registry.houses[house_id].display_name)
		if current is Dictionary and current.house_id == house_id: automatic_house.select(automatic_houses.size() - 1)
	automatic_mode.select(1 if current is Dictionary and current.mode == "battle" else 0)
	automatic_dialog.get_ok_button().disabled = automatic_houses.is_empty()
	automatic_dialog.dialog_text = "指定できる敵対家がありません。" if automatic_houses.is_empty() else ""
	automatic_dialog.popup_centered()

func _set_automatic() -> void:
	if automatic_house.selected < 0 or automatic_house.selected >= automatic_houses.size(): return
	if not main.army_campaign.automation.start(unit_id, "occupy" if automatic_mode.selected == 0 else "battle", automatic_houses[automatic_house.selected]): status.text = main.army_campaign.last_error

func _stop_automatic() -> void:
	automatic_dialog.hide()
	main.army_campaign.automation.stop(unit_id)

func handle_site_click(id: String, shift: bool) -> bool:
	return handle_node_click(id, shift)

func handle_district_click(id: String, shift: bool) -> bool:
	return handle_node_click("district:" + id, shift)

func handle_node_click(id: String, shift: bool) -> bool:
	if not main.army_campaign.units.has(unit_id) or main.army_campaign.units[unit_id].house_id != GameSession.player_house: return false
	if not main.army_campaign.order_from_click(unit_id, id, (append_target if choosing_target else true) or shift):
		status.text = main.army_campaign.last_error
	else:
		choosing_target = false
		refresh()
	return true

func hide_roster() -> void:
	right_panel.hide()

func hide_panel() -> void:
	if automatic_dialog != null: automatic_dialog.hide()
	if merge_dialog != null: merge_dialog.hide()
	if commanders_dialog != null: commanders_dialog.hide()
	loot_context_id = ""
	panel.hide(); hide_roster()
	occupation_panel.hide()
	mode = ""; choosing_target = false; district_id = ""; unit_id = ""
	main.army_campaign.selected_id = ""
	main.army_campaign.queue_redraw()
