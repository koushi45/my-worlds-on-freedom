extends CanvasLayer
const UI = preload("res://scripts/game/menu_style.gd")
const DistrictStyle = preload("res://scripts/game/district_panel_style.gd")
var main: Node
var shade: ColorRect
var modal: Control
var council_menu: Control
var council_origin := false
var slots: Control
var confirmation: ConfirmationDialog
var territory_fill_toggle: CheckButton
const ZOOM_PERCENTAGES := [50, 100, 200, 400, 600, 800]
var zoom_label: Button
var zoom_choices: PopupMenu
var last_zoom := -1.0
var action := ""
var options: Control
var officer_dictionary: Node
var retainer_panel: Control
var technology_panel: Control
var diplomacy_panel: Control
const Compact = preload("res://scripts/game/compact_hud_style.gd")
var council_tabs: Array[Button] = []
var council_content: VBoxContainer
var council_tab := 0
var crisis_label: Label

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	crisis_label = UI.label("", overlay, 15)
	crisis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crisis_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	crisis_label.offset_left = -370
	crisis_label.offset_right = -16
	crisis_label.offset_top = 230
	crisis_label.offset_bottom = 255
	crisis_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crisis_label.add_theme_color_override("font_color", Color("#ffc4aa"))
	main.retainer_management.loyalty_crisis.connect(_show_loyalty_crisis)
	zoom_label = DistrictStyle.button("",overlay,_show_zoom_choices)
	zoom_label.custom_minimum_size = Vector2(240,32)
	zoom_label.add_theme_font_size_override("font_size",15)
	zoom_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	zoom_label.offset_left = 20
	zoom_label.offset_right = 260
	zoom_label.offset_top = -44
	zoom_label.offset_bottom = -12
	zoom_label.focus_mode = Control.FOCUS_NONE
	zoom_choices = PopupMenu.new()
	zoom_choices.name = "MapZoomChoices"
	var zoom_background := StyleBoxFlat.new()
	zoom_background.bg_color = Color("#10131bf5")
	zoom_background.border_color = DistrictStyle.GOLD
	zoom_background.set_border_width_all(1)
	zoom_background.set_content_margin_all(8)
	zoom_choices.add_theme_stylebox_override("panel",zoom_background)
	zoom_choices.add_theme_color_override("font_color",DistrictStyle.PAPER)
	zoom_choices.add_theme_color_override("font_hover_color",DistrictStyle.GOLD)
	for percent in ZOOM_PERCENTAGES:
		zoom_choices.add_radio_check_item("%d%%" % percent,percent)
	zoom_choices.id_pressed.connect(_select_zoom)
	add_child(zoom_choices)
	zoom_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	zoom_label.add_theme_constant_override("shadow_offset_x",2)
	zoom_label.add_theme_constant_override("shadow_offset_y",2)
	_update_zoom_label()
	var display_options := PanelContainer.new()
	display_options.add_theme_stylebox_override("panel",UI.panel())
	display_options.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	display_options.offset_left = -320
	display_options.offset_right = -16
	display_options.offset_top = -76
	display_options.offset_bottom = -16
	display_options.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(display_options)
	territory_fill_toggle = CheckButton.new()
	territory_fill_toggle.text = "領有色を半透明で塗り分け"
	territory_fill_toggle.button_pressed = false
	territory_fill_toggle.add_theme_font_size_override("font_size",15)
	territory_fill_toggle.toggled.connect(main.territory_borders.set_fill_enabled)
	display_options.add_child(territory_fill_toggle)
	shade = ColorRect.new()
	shade.color = Color(0,0,0,0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	modal = _framed_menu(shade, Vector2(420, 550), true)
	modal.name = "GameMenuPanel"
	var rows := _menu_rows(modal)
	rows.add_theme_constant_override("separation",8)
	DistrictStyle.heading("ゲームメニュー", rows, 23).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button("セーブ", rows, show_slots.bind(true))
	_menu_button("ロード", rows, show_slots.bind(false))
	_menu_button("辞典", rows, show_dictionary)
	_menu_button("オプション", rows, show_options)
	_menu_button("開発者モード", rows, func(): _close_all(); main.developer_tools.open())
	DistrictStyle.heading("終える", rows, 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button("スタートメニューに戻る", rows, confirm_action.bind("title"))
	_menu_button("ゲーム終了", rows, confirm_action.bind("quit"))
	DistrictStyle.heading("戻る", rows, 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button("ゲームに戻る", rows, toggle)
	council_menu = Control.new()
	council_menu.name = "CouncilMenuPanel"
	council_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(council_menu)
	Compact.frame(council_menu, "council")
	var tab_names := ["役職", "配下", "技術", "外交"]
	var tab_icons := ["castle", "people", "governance", "diplomacy"]
	for index in range(tab_names.size()):
		var tab := Compact.button(council_menu, tab_names[index], _select_council_tab.bind(index))
		tab.name = "CouncilTab_%d" % index
		tab.toggle_mode = true
		Compact.icon(tab, tab_icons[index])
		council_tabs.append(tab)
	var close := Compact.button(council_menu, "閉じる（Esc）", _close_all)
	close.name = "CouncilClose"
	close.text = "×"
	close.add_theme_color_override("font_color", DistrictStyle.GOLD)
	council_content = VBoxContainer.new()
	council_content.name = "CouncilContent"
	council_content.add_theme_constant_override("separation", 6)
	council_menu.add_child(council_content)
	get_viewport().size_changed.connect(_resize_council)
	_resize_council()
	_select_council_tab(0)
	council_menu.hide()
	shade.hide()
	confirmation = ConfirmationDialog.new()
	confirmation.title = "確認"
	confirmation.ok_button_text = "続ける"
	confirmation.cancel_button_text = "キャンセル"
	confirmation.confirmed.connect(func():
		if action == "quit": get_tree().quit()
		else: GameSession.return_to_title())
	add_child(confirmation)

func _process(_delta: float) -> void:
	if not is_equal_approx(last_zoom,main.camera.zoom.x): _update_zoom_label()

func _show_zoom_choices() -> void:
	for index in range(ZOOM_PERCENTAGES.size()):
		zoom_choices.set_item_checked(index,is_equal_approx(main.camera.zoom.x,ZOOM_PERCENTAGES[index]/100.0))
	zoom_choices.reset_size()
	zoom_choices.position = Vector2i(zoom_label.get_global_rect().position) - Vector2i(0,zoom_choices.size.y)
	zoom_choices.popup()

func _select_zoom(percent: int) -> void:
	main._zoom_at(percent/100.0,main.get_viewport_rect().size*0.5)
	_update_zoom_label()

func _update_zoom_label() -> void:
	last_zoom = main.camera.zoom.x
	zoom_label.text = "マップ拡大率：%d%%" % int(round(last_zoom*100.0))

func _show_loyalty_crisis(officer_id: String, house_id: String, outcome: String) -> void:
	if house_id != GameSession.player_house: return
	crisis_label.text = "%s：%s" % [main.officer_registry.lookup[officer_id].display_name, outcome]

func _framed_menu(parent: Control, dimensions: Vector2, centered: bool) -> Control:
	var panel := Control.new()
	panel.custom_minimum_size = dimensions
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	if centered:
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.offset_left = -dimensions.x * 0.5
		panel.offset_right = dimensions.x * 0.5
		panel.offset_top = -dimensions.y * 0.5
		panel.offset_bottom = dimensions.y * 0.5
	DistrictStyle.frame(panel)
	return panel

func _menu_rows(panel: Control) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.offset_left = 35
	rows.offset_right = -35
	rows.offset_top = 35
	rows.offset_bottom = -35
	panel.add_child(rows)
	return rows

func _menu_button(caption: String, parent: Control, action_callback: Callable) -> Button:
	var button := DistrictStyle.button(caption, parent, action_callback)
	button.custom_minimum_size = Vector2(290, 38)
	return button

func toggle() -> void:
	if shade.visible:
		_close_all()
		return
	_open_menu(false)

func toggle_council() -> void:
	if shade.visible:
		_close_all()
		return
	if main.district_info.panel.visible: main.district_info.hide_info()
	_open_menu(true)

func _open_menu(council: bool) -> void:
	council_origin = council
	shade.color = Color(0,0,0,0) if council else Color(0,0,0,0.65)
	if council:
		_resize_council()
		_select_council_tab(council_tab)
	modal.visible = not council
	council_menu.visible = council
	shade.show()
	main.dragging = false
	main.district_click_serial += 1
	get_tree().paused = true

func _close_all() -> void:
	if is_instance_valid(slots): slots.queue_free()
	if is_instance_valid(options): options.queue_free()
	confirmation.hide()
	if is_instance_valid(retainer_panel): retainer_panel.hide()
	if is_instance_valid(technology_panel): technology_panel.hide()
	if is_instance_valid(diplomacy_panel): diplomacy_panel.hide()
	if is_instance_valid(officer_dictionary) and is_instance_valid(officer_dictionary.browser): officer_dictionary.browser.hide()
	shade.hide()
	modal.hide()
	council_menu.hide()
	main.dragging = false
	main.district_click_serial += 1
	get_tree().paused = false

func _restore_parent_menu() -> void:
	if council_origin:
		_select_council_tab(council_tab)
		council_menu.show()
	else: modal.show()

func show_slots(saving: bool) -> void:
	modal.hide()
	slots = preload("res://scripts/game/save_slots.gd").new()
	slots.main = main
	slots.saving = saving
	slots.closed.connect(_restore_parent_menu)
	shade.add_child(slots)

func show_options() -> void:
	modal.hide()
	options = preload("res://scripts/game/display_options.gd").new()
	options.closed.connect(_restore_parent_menu)
	shade.add_child(options)

func show_dictionary() -> void:
	modal.hide()
	if officer_dictionary == null:
		officer_dictionary = preload("res://scripts/game/officer_panel.gd").new()
		officer_dictionary.standalone = true
		officer_dictionary.closed.connect(_restore_parent_menu)
		add_child(officer_dictionary)
	officer_dictionary.show_browser()

func show_retainers() -> void:
	modal.hide()
	council_menu.hide()
	if not is_instance_valid(retainer_panel):
		retainer_panel = preload("res://scripts/game/retainer_panel.gd").new()
		retainer_panel.main = main
		retainer_panel.closed.connect(_restore_parent_menu)
		add_child(retainer_panel)
	retainer_panel.open()

func show_technology() -> void:
	modal.hide()
	council_menu.hide()
	if not is_instance_valid(technology_panel):
		technology_panel = preload("res://scripts/game/technology_panel.gd").new()
		technology_panel.main = main
		technology_panel.closed.connect(_restore_parent_menu)
		add_child(technology_panel)
	technology_panel.open()

func show_diplomacy() -> void:
	modal.hide()
	council_menu.hide()
	if not is_instance_valid(diplomacy_panel):
		diplomacy_panel = preload("res://scripts/game/diplomacy_panel.gd").new()
		diplomacy_panel.main = main
		diplomacy_panel.closed.connect(_restore_parent_menu)
		add_child(diplomacy_panel)
	diplomacy_panel.open()

func confirm_action(value: String) -> void:
	action = value
	confirmation.dialog_text = "未保存の進行は失われます。" + ("ゲームを終了しますか？" if value == "quit" else "スタートメニューに戻りますか？")
	confirmation.popup_centered()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_topmost()
		get_viewport().set_input_as_handled()

func _cancel_topmost() -> void:
	if confirmation.visible: confirmation.hide()
	elif is_instance_valid(officer_dictionary) and is_instance_valid(officer_dictionary.browser) and officer_dictionary.browser.visible:
		officer_dictionary.browser.hide()
		_restore_parent_menu()
	elif is_instance_valid(retainer_panel) and retainer_panel.visible:
		retainer_panel.hide()
		_restore_parent_menu()
	elif is_instance_valid(technology_panel) and technology_panel.visible:
		technology_panel.hide()
		_restore_parent_menu()
	elif is_instance_valid(diplomacy_panel) and diplomacy_panel.visible:
		diplomacy_panel.hide()
		_restore_parent_menu()
	elif is_instance_valid(options): options._close()
	elif is_instance_valid(slots):
		if slots.confirmation.visible: slots.confirmation.hide()
		else: slots.queue_free(); _restore_parent_menu()
	elif shade.visible: _close_all()
	elif main.district_info.building_confirmation.visible: main.district_info.building_confirmation.hide()
	elif main.district_info.governor_dialog.visible: main.district_info.governor_dialog.hide()
	elif main.district_info.building_dialog.visible: main.district_info.building_dialog.hide()
	elif main.district_info.panel.visible: main.district_info.hide_info()
	else: _open_menu(false)


func _resize_council() -> void:
	if council_menu == null: return
	Compact.update_frame(council_menu, "council")
	var u := Compact.unit(council_menu)
	council_menu.position = main.house_status_hud.council_popup_position() if is_instance_valid(main.house_status_hud) else Vector2(140, 106)
	for index in range(council_tabs.size()):
		var tab := council_tabs[index]
		tab.position = Vector2(12 + 57*index, 12) * u
		tab.size = Vector2(48, 30) * u
		var picture: TextureRect = tab.get_child(0)
		Compact.update_icon(picture, ["castle", "people", "governance", "diplomacy"][index])
		picture.position.x += 10*u
	var close: Button = council_menu.get_node("CouncilClose")
	close.position = Vector2(277, 12)*u
	close.size = Vector2(28, 30)*u
	council_content.position = Vector2(14, 52)*u
	council_content.size = Vector2(292, 242)*u

func _select_council_tab(index: int) -> void:
	council_tab = index
	for i in range(council_tabs.size()): council_tabs[i].set_pressed_no_signal(i == index)
	for child in council_content.get_children():
		council_content.remove_child(child)
		child.queue_free()
	var house_id: String = GameSession.player_house
	var management: Node = main.retainer_management
	if index == 0:
		var house: Dictionary = main.governance_registry.houses.get(house_id, {})
		UI.label(str(house.get("ruler", {}).get("name", "当主不明")), council_content, 13)
		for entry in [["家老", "governance"], ["軍師", "diplomacy"], ["侍大将", "military"], ["所司代", "castle"]]:
			var names: Array[String] = []
			for officer_id in management.house_members.get(house_id, []):
				if management.role_of(house_id, officer_id) == entry[0]: names.append(str(main.officer_registry.lookup[officer_id].display_name))
			_council_value(entry[1], "―" if names.is_empty() else "・".join(names), entry[0], _open_council_role.bind(entry[0]))
	elif index == 1:
		var members: Array = management.house_members.get(house_id, [])
		UI.label("配下 %d人" % members.size(), council_content, 13)
		_council_value("people", "配下管理を開く", "配下武将の配置・役職・俸禄", show_retainers)
	elif index == 2:
		_council_value("governance", "技術ツリーを開く", "研究の選択と進行状況", show_technology)
	else:
		_council_value("diplomacy", "外交を開く", "大名家との関係・交渉", show_diplomacy)

func _council_value(icon_name: String, value: String, hint: String, action_callback: Callable) -> void:
	var row := Compact.button(council_content, hint, action_callback)
	var u := Compact.unit(council_menu)
	row.custom_minimum_size = Vector2(0, 43)*u
	Compact.icon(row, icon_name).position += Vector2(7, 7)*u
	var caption := UI.label(value + "  ›", row, roundi(13*u))
	caption.position = Vector2(42, 0)*u
	caption.size = Vector2(240, 43)*u
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _open_council_role(role: String) -> void:
	show_retainers()
	retainer_panel._select_role(role)
