extends Control
## Select a district on the left and edit its live values on the right.
signal closed
const UI = preload("res://scripts/game/council_panel_style.gd")
const Portraits = preload("res://scripts/game/officer_portraits.gd")
const NativeIcons = preload("res://scripts/game/district_panel_style.gd")
const Compact = preload("res://scripts/game/compact_hud_style.gd")
const TABS := ["施設管理", "武将管理", "インフラ管理", "税率変更", "技術力命令"]
const TAB_ICONS := ["bulk_facilities", "bulk_officers", "bulk_infrastructure", "bulk_tax", "bulk_technology_orders"]
var main: Node
var selected := ""
var district_ids: Array[String] = []
var search: LineEdit
var district_list: ItemList
var tab := 0
var tabs: Array[Button] = []
var body: HBoxContainer
var left: VBoxContainer
var roster: VBoxContainer
var count_label: Label
var status: Label
var choices: PopupMenu
var choice_action := ""
var choice_values: Array = []
var building_id := "market"
var officer_id := ""
var technology_order := "integration"
var technology_buttons: Dictionary = {}
var tax_rate := 40
var content: VBoxContainer
var close_button: Button
var facility_picker: ScrollContainer
var facility_choices: VBoxContainer
var slot_grid: GridContainer
var choosing_facility := false
var tax_increase_button: Button
var tax_decrease_button: Button
var tax_value: Label
var governor_buttons: Dictionary = {}
var governor_district_scroll: ScrollContainer
var governor_district_rows: VBoxContainer
var governor_district_buttons: Dictionary = {}

func _ready() -> void:
	name = "DistrictManagementPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	Compact.frame(self, "council_management")
	content = VBoxContainer.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 20
	content.offset_right = -20
	content.offset_top = 18
	content.offset_bottom = -18
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UI.heading("郡一括管理", header)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(TABS.size()):
		var button := Compact.button(self, TABS[i], _select_tab.bind(i))
		button.name = "DistrictTab_%d" % i
		button.toggle_mode = true
		Compact.icon(button, TAB_ICONS[i])
		tabs.append(button)
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	content.add_child(body)
	var roster_column := VBoxContainer.new()
	body.add_child(roster_column)
	count_label = UI.heading("支配郡", roster_column)
	search = LineEdit.new()
	search.placeholder_text = "国名・郡名で探す"
	search.text_changed.connect(func(_value: String): _refresh_roster())
	UI.field(search)
	roster_column.add_child(search)
	district_list = ItemList.new()
	district_list.select_mode = ItemList.SELECT_SINGLE
	district_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	district_list.item_selected.connect(_select_index)
	UI.field(district_list)
	roster_column.add_child(district_list)
	governor_district_scroll = ScrollContainer.new()
	governor_district_scroll.name = "DistrictGovernorRoster"
	governor_district_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	governor_district_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_column.add_child(governor_district_scroll)
	governor_district_rows = VBoxContainer.new()
	governor_district_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	governor_district_scroll.add_child(governor_district_rows)
	governor_district_scroll.hide()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	scroll.add_child(left)
	facility_picker = ScrollContainer.new()
	facility_picker.name = "FacilityPicker"
	facility_picker.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	facility_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(facility_picker)
	facility_choices = VBoxContainer.new()
	facility_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facility_picker.add_child(facility_choices)
	facility_picker.hide()
	status = UI.label("左の支配郡を選択してください。", content)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices = PopupMenu.new()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("#101821")
	popup_style.border_color = UI.GOLD
	popup_style.set_border_width_all(1)
	popup_style.set_content_margin_all(8)
	choices.add_theme_stylebox_override("panel", popup_style)
	choices.id_pressed.connect(_choose)
	add_child(choices)
	close_button = Compact.button(self, "閉じる（Esc）", func(): closed.emit())
	close_button.text = "×"
	close_button.add_theme_color_override("font_color", UI.GOLD)
	get_viewport().size_changed.connect(_resize)
	get_window().size_changed.connect(_on_facility_window_resized)
	UI.follow_window(self)
	_resize()

func _resize() -> void:
	Compact.update_frame(self, "council_management")
	var u := Compact.unit(self)
	position = Compact.council_position(self, main.house_status_hud)
	content.offset_left = 14 * u
	content.offset_right = -14 * u
	content.offset_top = 16 * u
	content.offset_bottom = -14 * u
	body.add_theme_constant_override("separation", roundi(18 * u))
	for i in range(tabs.size()):
		var button := tabs[i]
		button.position = Vector2(40 * i, -30) * u
		button.size = Vector2(36, 30) * u
		var picture: TextureRect = button.get_child(0)
		Compact.update_icon(picture, TAB_ICONS[i])
		picture.position += Vector2(5, 1) * u
	close_button.position = Vector2(size.x - 42 * u, 12 * u)
	close_button.size = Vector2(28, 30) * u
	close_button.add_theme_font_size_override("font_size", roundi(12 * u))
	body.get_child(0).custom_minimum_size.x = size.x * (0.42 if tab == 1 else (0.25 if choosing_facility else 0.32))
	left.get_parent().custom_minimum_size.x = size.x * 0.23 if choosing_facility else 0
	district_list.fixed_icon_size = Vector2i(48, 48) * u if tab == 1 else Vector2i.ZERO
	district_list.icon_scale = 1.0
	district_list.max_text_lines = 2 if tab == 1 else 1
	if slot_grid != null: slot_grid.columns = 2 if choosing_facility else 3

func open() -> void:
	show()
	_resize()
	_refresh_roster()
	_select_tab(tab)
	status.text = "左の支配郡を選択してください。"

func targets() -> Array[String]:
	var result: Array[String] = []
	if main.governance_registry.districts.has(selected) and main.governance_registry.districts[selected].house_id == GameSession.player_house:
		result.append(selected)
	return result

func _refresh_roster() -> void:
	district_ids.clear()
	district_list.clear()
	var ids: Array = main.governance_registry.districts.keys()
	ids.sort_custom(func(a, b): return str(main.governance_registry.districts[a].province) + str(main.governance_registry.districts[a].name) < str(main.governance_registry.districts[b].province) + str(main.governance_registry.districts[b].name))
	var owned := 0
	for id in ids:
		var r: Dictionary = main.governance_registry.districts[id]
		if r.house_id != GameSession.player_house: continue
		owned += 1
		var caption := "%s・%s" % [r.province, r.name]
		if not search.text.is_empty() and not caption.contains(search.text): continue
		district_ids.append(id)
		district_list.add_item(caption)
	if selected not in district_ids:
		selected = district_ids[0] if not district_ids.is_empty() else ""
	if not selected.is_empty():
		district_list.select(district_ids.find(selected))
	count_label.text = "支配郡 %d" % owned
	_select_tab(tab)

func _select_index(index: int) -> void:
	if index < 0 or index >= district_ids.size(): return
	selected = district_ids[index]
	district_list.select(index)
	choices.hide()
	_select_tab(tab)
	status.text = "選択した郡の編集ができます。"

func _summary(r: Dictionary) -> String:
	match tab:
		0:
			var state: Dictionary = main.district_buildings.state[r.id]
			return "施設 %d/%d　%s" % [main.district_buildings.slots_used(r.id), main.district_buildings.slot_capacity(r), "工事中" if state.construction != null else "工事なし"]
		1: return "郡代：%s" % (str(r.governor.get("name", "未任命")) if r.governor is Dictionary else "未任命")
		2: return "整備 Lv.%d　荒廃 %d" % [int(r.infrastructure), int(r.devastation)]
		4: return main.technology_orders.summary(r.id)
		_: return "税率 %d%%　治安 %d\n金銭 %d/月・兵糧 %d/年" % [int(r.tax_rate), main.technology_tree.security_for(r), main.district_economy.income_for(r, "commerce"), main.district_economy.income_for(r, "agriculture")]

func _select_tab(index: int) -> void:
	tab = index
	choosing_facility = false
	facility_picker.hide()
	slot_grid = null
	_resize()
	choices.hide()
	_update_district_items()
	governor_buttons.clear()
	for i in range(tabs.size()): tabs[i].set_pressed_no_signal(i == tab)
	for child in left.get_children():
		left.remove_child(child)
		child.queue_free()
	if targets().is_empty():
		_hint("表示する支配郡がありません。")
		return
	var record: Dictionary = main.governance_registry.districts[selected]
	if tab != 1: UI.heading("%s・%s" % [record.province, record.name], left)
	UI.heading("武将一覧" if tab == 1 else TABS[tab], left)
	if tab in [0, 4]: _hint(_summary(record))
	match tab:
		0:
			_show_facility_slots(record)

		1:
			_show_governor_roster(record)

		2:
			_hint("インフラ整備：現在Lv. × 金銭100。上限Lv.10。1段階ごとに収入+5%・防御+1・人口増加数+5%（Lv.1基準）。人口は毎月0.1%を基本に増加します。")
			_button("インフラ Lv.%d（整備・金銭%d）" % [record.infrastructure, main.district_actions.upgrade_cost(record)], left, _apply.bind("upgrade"))
			_hint("復旧：荒廃度 × 金銭2。荒廃度を0に戻します。")
			_button("荒廃度 %d（復旧・金銭%d）" % [record.devastation, main.district_actions.repair_cost(record)], left, _apply.bind("repair"))
		3:
			tax_rate = int(record.tax_rate)
			_show_tax_controls(record)
			_hint("治安 %d／金銭 %d/月／兵糧 %d/年" % [main.technology_tree.security_for(record), main.district_economy.income_for(record, "commerce"), main.district_economy.income_for(record, "agriculture")])
			_hint("標準40%。税率10ポイント増加ごとに金銭・兵糧収入が標準比25%増加し、治安が10低下します。減税は逆の効果です。")

		4:
			_show_technology_orders()
	UI.resize(self)

func _hint(text: String) -> void:
	var label := UI.label(text, left)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _show_choices(kind: String) -> void:
	choice_action = kind
	choice_values.clear()
	choices.clear()
	match kind:
		"technology":
			for id in main.technology_orders.DEFINITIONS:
				choice_values.append(id)
				choices.add_item(main.technology_orders.DEFINITIONS[id].name)
		"officer", "governor":
			var candidates: Array = main.retainer_management.governor_candidates(GameSession.player_house) if kind == "governor" else main.retainer_management.officers_for_house(GameSession.player_house)
			for id in candidates:
				choice_values.append(id)
				choices.add_item(main.officer_registry.lookup[id].display_name)
	choices.position = Vector2i(left.get_global_rect().position + Vector2(0, 80))
	choices.popup()

func _choose(index: int) -> void:
	if index < 0 or index >= choice_values.size(): return
	match choice_action:
		"technology": technology_order = choice_values[index]
		"officer": officer_id = choice_values[index]
		"governor":
			officer_id = choice_values[index]
			_apply(choice_action)
			return
	_select_tab(tab)

func _apply(order: String) -> void:
	var ids := targets()
	var success := 0
	var errors: Dictionary = {}
	for id in ids:
		var result: Error = ERR_UNAVAILABLE
		var reason := "条件を満たしていません（資金・上限・対象を確認）"
		match order:
			"end_technology":
				if main.technology_orders.districts.has(id):
					var job: Dictionary = main.technology_orders.districts[id]
					if job.kind == "negotiation" and job.applied and main.technology_orders.today() < int(job.end):
						reason = "減税の約束期間中は折衝を終了できません"
					else:
						main.technology_orders.finish(id)
						result = OK
			"technology":
				reason = main.technology_orders.reason(id, technology_order, GameSession.player_house)
				result = main.technology_orders.start(id, technology_order, GameSession.player_house)
			"build":
				reason = main.district_buildings.reason_for(id, building_id, GameSession.player_house)
				result = main.district_buildings.start_construction(id, building_id, GameSession.player_house, main.game_clock.year, main.game_clock.month, main.game_clock.day)
			"cancel": result = main.district_buildings.cancel_construction(id, GameSession.player_house)
			"demolish": result = main.district_buildings.demolish(id, building_id, GameSession.player_house)
			"upgrade": result = main.district_actions.upgrade(id, GameSession.player_house)
			"repair": result = main.district_actions.repair(id, GameSession.player_house)
			"tax":
				if tax_rate > main.technology_orders.tax_limit(id): reason = "在地勢力との折衝による減税の約束期間中です"
				result = main.district_actions.set_tax_rate(id, GameSession.player_house, tax_rate)
			"governor":
				reason = "郡代に任命可能な武将を選んでください"
				result = main.retainer_management.appoint_district_governor(GameSession.player_house, officer_id, id)
			"clear_governor":
				result = main.retainer_management.clear_district_governor(GameSession.player_house, id)
			"agriculture", "commerce", "clear_agriculture", "clear_commerce":
				var kind := order.replace("clear_", "")
				if order.begins_with("clear_"):
					result = main.district_economy.assign_developer(id, kind, null)
				elif officer_id in main.retainer_management.officers_for_house(GameSession.player_house):
					result = main.district_economy.assign_developer(id, kind, officer_id)
				else: reason = "自家の武将を選んでください"
		if result == OK: success += 1
		else: errors[reason] = true
	_refresh_roster()
	main.house_status_hud.invalidate()
	main.district_economy.development_updated.emit()
	status.text = "対象郡を選択してください。" if ids.is_empty() else "変更しました。" if success > 0 else "／".join(errors.keys())

func _button(text: String, parent: Control, action: Callable) -> Button:
	var result := UI.button(text, parent, action)
	result.custom_minimum_size = Vector2(100, 32) * Compact.unit(self)
	return result

func _demolish(id: String) -> void:
	building_id = id
	_apply("demolish")

func _facility_card(parent: Control, icon_name: String, caption: String, action: Callable, enabled: bool = true) -> Button:
	var button := UI.button("", parent, action)
	button.name = "Facility_" + icon_name
	button.disabled = not enabled
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 4
	column.offset_top = 4
	column.offset_right = -4
	column.offset_bottom = -4
	var icon := NativeIcons.icon(column, "res://assets/ui/district/" + icon_name)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := UI.label(caption, column)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.custom_minimum_size = Vector2(icon.custom_minimum_size.x + 16, icon.custom_minimum_size.y + 28 * Compact.unit(self))
	return button

func _show_facility_slots(record: Dictionary) -> void:
	var buildings: Node = main.district_buildings
	var state: Dictionary = buildings.state[selected]
	_hint("空き枠を押して建設、建設済み施設を押して解体。")
	slot_grid = GridContainer.new()
	slot_grid.name = "FacilitySlots"
	slot_grid.columns = 3
	slot_grid.add_theme_constant_override("h_separation", 6)
	slot_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(slot_grid)
	for site_id in buildings.existing_facilities(selected):
		var site: Dictionary = main.governance_registry.sites[site_id]
		# Named castles and ports are reserved historical facilities, as in the district window.
		var label := UI.label(str(site.name) + "\n既存建築物", slot_grid)
		label.name = "Historical_" + str(site_id)
		label.custom_minimum_size = Vector2(96, 72) * Compact.unit(self)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.tooltip_text = str(site.name) + "（既存建築物）"
	for id in state.built:
		var button := _facility_card(slot_grid, id, buildings.DEFINITIONS[id].name, _demolish.bind(id))
		button.tooltip_text = "%s：%s\n押して解体" % [buildings.DEFINITIONS[id].name, buildings.effect_for(selected, id)]
	if state.construction != null:
		var job: Dictionary = state.construction
		var button := _facility_card(slot_grid, "construction", "工事中", _apply.bind("cancel"))
		button.tooltip_text = "%s：%d年%d月完成\n押して工事を中止（返金）" % [buildings.DEFINITIONS[job.building_id].name, job.finish_year, job.finish_month]
	for i in buildings.slot_capacity(record) - buildings.slots_used(selected):
		_facility_card(slot_grid, "plus", "空き枠", _open_facility_picker)

func _open_facility_picker() -> void:
	if tab != 0 or targets().is_empty(): return
	choosing_facility = true
	facility_picker.show()
	for child in facility_choices.get_children():
		facility_choices.remove_child(child)
		child.queue_free()
	UI.heading("新施設建設", facility_choices)
	var buildings: Node = main.district_buildings
	var record: Dictionary = main.governance_registry.districts[selected]
	for id in buildings.DEFINITIONS:
		var definition: Dictionary = buildings.DEFINITIONS[id]
		var reason: String = buildings.reason_for(selected, id, GameSession.player_house)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		facility_choices.add_child(row)
		var button := _facility_card(row, id, definition.name, _build_facility.bind(id), reason.is_empty())
		button.name = "Build_" + id
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var effect: String = buildings.effect_for(selected, id)
		if id in ["irrigation", "farm_estate", "market", "workshop", "temple"]:
			var kind := "agriculture" if id in ["irrigation", "farm_estate"] else "commerce"
			effect += "\n%d → %d" % [main.district_economy.income_for(record, kind), main.district_economy.income_for(record, kind, id)]
		for text in ["金銭%d・%dか月" % [buildings.cost_for(selected, id), buildings.months_for(selected, id)], effect, reason]:
			if text.is_empty(): continue
			var label := UI.label(text, details)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = effect if reason.is_empty() else reason
	_resize()
	UI.resize(self)

func _build_facility(id: String) -> void:
	building_id = id
	_apply("build")

func close_facility_picker() -> void:
	choosing_facility = false
	facility_picker.hide()
	_resize()

func _refresh_facility_layout() -> void:
	if not visible: return
	if tab in [1, 3]:
		_select_tab(tab)
		return
	if tab != 0: return
	var reopen := choosing_facility
	_select_tab(0)
	if reopen: _open_facility_picker()

func _on_facility_window_resized() -> void:
	_refresh_facility_layout.call_deferred()

func _governor_id(record: Dictionary) -> String:
	return str(record.governor.get("officer_id", "")) if record.governor is Dictionary else ""

func _update_district_items() -> void:
	district_list.visible = tab != 1
	governor_district_scroll.visible = tab == 1
	governor_district_buttons.clear()
	for child in governor_district_rows.get_children():
		governor_district_rows.remove_child(child)
		child.queue_free()
	for index in district_ids.size():
		var record: Dictionary = main.governance_registry.districts[district_ids[index]]
		var caption := "%s・%s" % [record.province, record.name]
		var texture: Texture2D
		if tab == 1:
			caption += "　／郡代：" + (str(record.governor.get("name", "未任命")) if record.governor is Dictionary else "未任命")
			texture = _officer_texture(_governor_id(record)) if record.governor is Dictionary else null
		district_list.set_item_text(index, caption)
		district_list.set_item_icon(index, texture)
		district_list.set_item_tooltip(index, caption)
		if tab == 1: _governor_district_card(record, index)

func _show_governor_roster(record: Dictionary) -> void:
	_hint("左で郡を選び、武将を押して郡代を変更。任命中の武将を再度押すと解除します。")
	var management: Node = main.retainer_management
	var current := _governor_id(record)
	var eligible: Array = management.governor_candidates(GameSession.player_house)
	for id in management.officers_for_house(GameSession.player_house):
		var officer: Dictionary = main.officer_registry.lookup[id]
		var button := UI.button("", left, _toggle_governor.bind(id))
		button.name = "Governor_" + id
		button.custom_minimum_size = Vector2(100, 62) * Compact.unit(self)
		button.disabled = id not in eligible and id != current
		button.toggle_mode = true
		button.set_pressed_no_signal(id == current)
		governor_buttons[id] = button
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		row.offset_right = -6
		row.offset_top = 4
		row.offset_bottom = -4
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = _officer_texture(id)
		portrait.custom_minimum_size = Vector2(48, 48) * Compact.unit(self)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(details)
		var name_label := UI.label(str(officer.display_name), details)
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var role: String = management.role_of(GameSession.player_house, id)
		var politics: Variant = main.officer_registry.ability(id, "politics")
		var info := "%s・政治 %s" % [role, str(politics) if politics != null else "―"]
		if id == current: info += "・任命中（押して解除）"
		elif id not in eligible: info += "・侍大将以上で任命可能"
		var label := UI.label(info, details)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.tooltip_text = str(officer.display_name) + "\n" + info

func _toggle_governor(id: String) -> void:
	if tab != 1 or targets().is_empty(): return
	var record: Dictionary = main.governance_registry.districts[selected]
	officer_id = id
	_apply("clear_governor" if id == _governor_id(record) else "governor")

func _officer_texture(id: String) -> Texture2D:
	var texture := Portraits.texture_for(id)
	return texture if texture != null else preload("res://assets/ui/hud/samurai.png")

func _governor_district_card(record: Dictionary, index: int) -> void:
	var button := UI.button("", governor_district_rows, _select_index.bind(index))
	button.name = "District_" + str(record.id)
	button.custom_minimum_size = Vector2(100, 62) * Compact.unit(self)
	button.toggle_mode = true
	button.set_pressed_no_signal(record.id == selected)
	governor_district_buttons[record.id] = button
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.offset_top = 4
	row.offset_bottom = -4
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = _officer_texture(_governor_id(record)) if record.governor is Dictionary else null
	portrait.custom_minimum_size = Vector2(48, 48) * Compact.unit(self)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(details)
	var district_label := UI.label("%s・%s" % [record.province, record.name], details)
	district_label.name = "DistrictName"
	district_label.clip_text = true
	district_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var governor_label := UI.label("郡代：" + (str(record.governor.name) if record.governor is Dictionary else "未任命"), details)
	governor_label.name = "GovernorName"
	governor_label.clip_text = true
	governor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.tooltip_text = district_label.text + "\n" + governor_label.text

func _show_tax_controls(record: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "TaxControls"
	row.add_theme_constant_override("separation", roundi(12 * Compact.unit(self)))
	left.add_child(row)
	tax_decrease_button = _facility_card(row, "tax_decrease", "－10", _change_tax.bind(-10), int(record.tax_rate) > 20)
	tax_decrease_button.name = "TaxDecrease"
	tax_decrease_button.tooltip_text = "税率を10ポイント下げる（下限20%）"
	tax_value = UI.label("税率 %d%%" % int(record.tax_rate), row, 18)
	tax_value.name = "TaxValue"
	tax_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tax_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tax_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var limit: int = mini(60, main.technology_orders.tax_limit(selected))
	tax_increase_button = _facility_card(row, "tax_increase", "＋10", _change_tax.bind(10), int(record.tax_rate) + 10 <= limit)
	tax_increase_button.name = "TaxIncrease"
	tax_increase_button.tooltip_text = "税率を10ポイント上げる（上限%d%%）" % limit
	if limit < 60: _hint("折衝による減税の約束期間中：税率の上限は%d%%です。" % limit)

func _change_tax(delta: int) -> void:
	if tab != 3 or targets().is_empty() or delta not in [-10, 10]: return
	var record: Dictionary = main.governance_registry.districts[selected]
	var next_rate := int(record.tax_rate) + delta
	if next_rate < 20 or next_rate > mini(60, main.technology_orders.tax_limit(selected)): return
	tax_rate = next_rate
	_apply("tax")

func _show_technology_orders() -> void:
	technology_buttons.clear()
	var orders: Node = main.technology_orders
	var points: Dictionary = main.retainer_management.technology[GameSession.player_house]
	_hint("保有技術力：統治 %.1f／外交 %.1f／軍事 %.1f" % [points.governance, points.diplomacy, points.military])
	var grid := GridContainer.new()
	grid.name = "TechnologyOrders"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", roundi(10 * Compact.unit(self)))
	grid.add_theme_constant_override("v_separation", roundi(12 * Compact.unit(self)))
	left.add_child(grid)
	for kind in orders.DEFINITIONS:
		var definition: Dictionary = orders.DEFINITIONS[kind]
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = size.x * 0.28
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var reason: String = orders.reason(selected, kind, GameSession.player_house)
		var button := _button(definition.name, card, _execute_technology_order.bind(kind))
		button.name = "Order_" + kind
		button.disabled = not reason.is_empty()
		button.tooltip_text = definition.hint if reason.is_empty() else reason
		technology_buttons[kind] = button
		var field: String = {"governance":"統治", "diplomacy":"外交", "military":"軍事"}[definition.field]
		for text in ["%s技術力%d・金銭%d・兵糧%d" % [field, orders.point_cost(GameSession.player_house, definition.points), definition.money, definition.food], definition.hint, reason]:
			if text.is_empty(): continue
			var label := UI.label(text, card)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if orders.valid_job(selected):
		var job: Dictionary = orders.districts[selected]
		var button := _button("命令を終了（返金なし）", left, _apply.bind("end_technology"))
		button.disabled = job.kind == "negotiation" and job.applied and orders.today() < int(job.end)
		if button.disabled: _hint("減税の約束期間中は折衝を終了できません。")

func _execute_technology_order(kind: String) -> void:
	if tab != 4 or targets().is_empty(): return
	technology_order = kind
	_apply("technology")
