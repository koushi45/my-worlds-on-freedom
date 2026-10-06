extends CanvasLayer
const UI = preload("res://scripts/game/menu_style.gd")
const DistrictStyle = preload("res://scripts/game/district_panel_style.gd")
var main: Node
var shade: ColorRect
var modal: Control
var council_menu: Control
var district_management_panel: Control
var council_origin := false
var slots: Control
var confirmation: ConfirmationDialog
var action := ""
var options: Control
var officer_dictionary: Node
var retainer_panel: Control
var technology_panel: Control
var diplomacy_panel: Control
var finance_panel: Control
const Compact = preload("res://scripts/game/compact_hud_style.gd")
const COUNCIL_TAB_ICONS := ["menu_retainers", "menu_diplomacy", "menu_technology", "menu_finance"]
var council_tabs: Array[Button] = []
var council_content: Control
var council_tab := 0
var crisis_label: Label
var assistance_button: Button

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
	assistance_button = DistrictStyle.button("", overlay, _open_assistance)
	assistance_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	assistance_button.offset_left = -370
	assistance_button.offset_right = -16
	assistance_button.offset_top = 260
	assistance_button.offset_bottom = 296
	main.diplomacy.changed.connect(_refresh_assistance)
	_refresh_assistance()
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
	Compact.frame(council_menu, "council_management")
	var tab_names := ["家臣管理", "外交", "技術", "収支"]
	for index in range(tab_names.size()):
		var tab := Compact.button(council_menu, tab_names[index], _select_council_tab.bind(index))
		tab.name = "CouncilTab_%d" % index
		tab.toggle_mode = true
		Compact.icon(tab, COUNCIL_TAB_ICONS[index])
		var caption := UI.label(tab_names[index], tab, 12)
		caption.name = "Caption"
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		council_tabs.append(tab)
	council_content = Control.new()
	council_content.name = "CouncilContent"
	council_menu.add_child(council_content)
	# Add the close button above the content so overlapping panels cannot intercept clicks.
	var close := Compact.button(council_menu, "閉じる（Esc）", _close_all)
	close.name = "CouncilClose"
	close.text = "×"
	close.add_theme_color_override("font_color", DistrictStyle.GOLD)
	get_viewport().size_changed.connect(_resize_council)
	_resize_council()
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

func _show_loyalty_crisis(officer_id: String, house_id: String, outcome: String) -> void:
	if house_id != GameSession.player_house: return
	crisis_label.text = "%s：%s" % [main.officer_registry.lookup[officer_id].display_name, outcome]

func _refresh_assistance() -> void:
	var count := 0
	for war in main.diplomacy.wars.values():
		if war.requests.get(GameSession.player_house) == "pending": count += 1
	assistance_button.visible = count > 0
	assistance_button.text = "同盟国から参戦要請：%d件（外交を開く）" % count

func _open_assistance() -> void:
	if not shade.visible: _open_menu(false)
	show_diplomacy()
	for war in main.diplomacy.wars.values():
		if war.requests.get(GameSession.player_house) == "pending":
			diplomacy_panel.selected = war.defender
			diplomacy_panel._fill_houses()
			break

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

func toggle_district_management() -> void:
	if is_instance_valid(district_management_panel) and district_management_panel.visible:
		_close_all()
		return
	if shade.visible: _close_all()
	if main.district_info.panel.visible: main.district_info.hide_info()
	if not is_instance_valid(district_management_panel):
		district_management_panel = preload("res://scripts/game/district_management_panel.gd").new()
		district_management_panel.main = main
		district_management_panel.closed.connect(_close_all)
		shade.add_child(district_management_panel)
	shade.color = Color(0, 0, 0, 0)
	shade.show()
	modal.hide()
	council_menu.hide()
	main.dragging = false
	main.district_click_serial += 1
	get_tree().paused = true
	district_management_panel.open()

func _open_menu(council: bool) -> void:
	if is_instance_valid(district_management_panel): district_management_panel.hide()
	council_origin = council
	shade.color = Color(0,0,0,0) if council else Color(0,0,0,0.65)
	modal.visible = not council
	council_menu.visible = council
	shade.show()
	main.dragging = false
	main.district_click_serial += 1
	get_tree().paused = true
	if council:
		_resize_council()
		_select_council_tab(council_tab)

func _close_all() -> void:
	if is_instance_valid(slots): slots.queue_free()
	if is_instance_valid(options): options.queue_free()
	confirmation.hide()
	if is_instance_valid(retainer_panel):
		retainer_panel.wage_dialog.hide()
		retainer_panel.hide()
	if is_instance_valid(technology_panel): technology_panel.hide()
	if is_instance_valid(diplomacy_panel): diplomacy_panel.hide()
	if is_instance_valid(finance_panel): finance_panel.hide()
	if is_instance_valid(officer_dictionary) and is_instance_valid(officer_dictionary.browser): officer_dictionary.browser.hide()
	if is_instance_valid(district_management_panel):
		district_management_panel.choices.hide()
		district_management_panel.hide()
	shade.hide()
	modal.hide()
	council_menu.hide()
	main.dragging = false
	main.district_click_serial += 1
	get_tree().paused = false

func _restore_parent_menu() -> void:
	if council_origin:
		_open_menu(true)
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
	council_tab = 0
	_open_menu(true)

func show_diplomacy(house_id := "") -> void:
	council_tab = 1
	_open_menu(true)
	if not house_id.is_empty():
		diplomacy_panel.selected = house_id
		diplomacy_panel.search.clear()
		diplomacy_panel._fill_houses()
		diplomacy_panel.house_list.ensure_current_is_visible()

func show_technology() -> void:
	council_tab = 2
	_open_menu(true)

func confirm_action(value: String) -> void:
	action = value
	confirmation.dialog_text = "未保存の進行は失われます。" + ("ゲームを終了しますか？" if value == "quit" else "スタートメニューに戻りますか？")
	confirmation.popup_centered()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_topmost()
		get_viewport().set_input_as_handled()

func _cancel_topmost() -> void:
	if is_instance_valid(district_management_panel) and district_management_panel.visible:
		if district_management_panel.choices.visible: district_management_panel.choices.hide()
		elif district_management_panel.facility_picker.visible: district_management_panel.close_facility_picker()
		else: _close_all()
	elif confirmation.visible: confirmation.hide()
	elif is_instance_valid(officer_dictionary) and is_instance_valid(officer_dictionary.browser) and officer_dictionary.browser.visible:
		officer_dictionary.browser.hide()
		_restore_parent_menu()
	elif is_instance_valid(retainer_panel) and retainer_panel.visible:
		if retainer_panel.wage_dialog.visible: retainer_panel.wage_dialog.hide()
		else: _close_all()
	elif is_instance_valid(technology_panel) and technology_panel.visible:
		_close_all()
	elif is_instance_valid(diplomacy_panel) and diplomacy_panel.visible:
		_close_all()
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
	Compact.update_frame(council_menu, "council_management")
	var u := Compact.unit(council_menu)
	var hud: Node = main.house_status_hud
	council_menu.position = Compact.council_position(council_menu, hud)
	for index in range(council_tabs.size()):
		var tab := council_tabs[index]
		tab.position = Vector2(40*index, -30)*u
		tab.size = Vector2(36, 30)*u
		var picture: TextureRect = tab.get_child(0)
		Compact.update_icon(picture, COUNCIL_TAB_ICONS[index])
		picture.position += Vector2(5, 1)*u
		var caption: Label = tab.get_node("Caption")
		caption.hide()
		caption.position = Vector2(38, 0)*u
		caption.size = Vector2(90, 30)*u
		caption.add_theme_font_size_override("font_size", roundi(12*u))
	var close: Button = council_menu.get_node("CouncilClose")
	close.position = Vector2(council_menu.size.x-42*u, 12*u)
	close.size = Vector2(28, 30)*u
	close.add_theme_font_size_override("font_size", roundi(12*u))
	council_content.position = Vector2(14, 16)*u
	council_content.size = council_menu.size-Vector2(28, 30)*u

func _select_council_tab(index: int) -> void:
	if index < 0 or index >= council_tabs.size(): return
	council_tab = index
	if is_instance_valid(retainer_panel): retainer_panel.wage_dialog.hide()
	for i in range(council_tabs.size()): council_tabs[i].set_pressed_no_signal(i == index)
	for panel in [retainer_panel, diplomacy_panel, technology_panel, finance_panel]:
		if is_instance_valid(panel): panel.hide()
	var panel: Control
	match index:
		0:
			if not is_instance_valid(retainer_panel):
				retainer_panel = preload("res://scripts/game/retainer_panel.gd").new()
			panel = retainer_panel
		1:
			if not is_instance_valid(diplomacy_panel):
				diplomacy_panel = preload("res://scripts/game/diplomacy_panel.gd").new()
			panel = diplomacy_panel
		2:
			if not is_instance_valid(technology_panel):
				technology_panel = preload("res://scripts/game/technology_panel.gd").new()
			panel = technology_panel
		3:
			if not is_instance_valid(finance_panel):
				finance_panel = preload("res://scripts/game/finance_panel.gd").new()
			panel = finance_panel
	if panel.get_parent() == null:
		panel.main = main
		panel.closed.connect(_close_all)
		council_content.add_child(panel)
	panel.open()

func _open_council_role(role: String) -> void:
	show_retainers()
	retainer_panel._select_role(role)
