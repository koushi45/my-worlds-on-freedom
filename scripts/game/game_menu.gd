extends CanvasLayer
const UI = preload("res://scripts/game/menu_style.gd")
var main: Node
var shade: ColorRect
var modal: PanelContainer
var slots: Control
var confirmation: ConfirmationDialog
var territory_fill_toggle: CheckButton
var zoom_label: Label
var last_zoom := -1.0
var action := ""
var options: Control
var officer_dictionary: Node
var retainer_panel: AcceptDialog
var technology_panel: AcceptDialog
var prestige_label: Label
var crisis_label: Label

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var open := UI.button("メニュー  Esc",overlay,toggle)
	open.custom_minimum_size = Vector2(170,36)
	open.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	open.offset_left = -190
	open.offset_right = -16
	open.offset_top = 154
	open.offset_bottom = 190
	open.focus_mode = Control.FOCUS_NONE
	prestige_label = UI.label("", overlay, 18)
	prestige_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prestige_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	prestige_label.offset_left = -190
	prestige_label.offset_right = -16
	prestige_label.offset_top = 198
	prestige_label.offset_bottom = 226
	prestige_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.house_prestige.prestige_changed.connect(func(_house_id: String, _value: int, _reason: String): _update_prestige())
	_update_prestige()
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
	zoom_label = UI.label("",overlay,15)
	zoom_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	zoom_label.offset_left = 20
	zoom_label.offset_top = -44
	zoom_label.offset_bottom = -12
	zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	modal = UI.centered(shade,Vector2(420,590))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	modal.add_child(rows)
	UI.label("ゲームメニュー",rows,28)
	UI.button("セーブ",rows,show_slots.bind(true))
	UI.button("ロード",rows,show_slots.bind(false))
	UI.button("辞典",rows,show_dictionary)
	UI.button("役職ツリー・配下管理",rows,show_retainers)
	UI.button("技術ツリー",rows,show_technology)
	UI.button("オプション",rows,show_options)
	UI.button("スタートメニューに戻る",rows,confirm_action.bind("title"))
	UI.button("ゲーム終了",rows,confirm_action.bind("quit"))
	UI.button("ゲームに戻る",rows,toggle)
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

func _update_zoom_label() -> void:
	last_zoom = main.camera.zoom.x
	zoom_label.text = "マップ拡大率：%d%%" % int(round(last_zoom*100.0))

func _update_prestige() -> void:
	prestige_label.text = "威信 %d / 100" % main.house_prestige.value_for(GameSession.player_house)

func _show_loyalty_crisis(officer_id: String, house_id: String, outcome: String) -> void:
	if house_id != GameSession.player_house: return
	crisis_label.text = "%s：%s" % [main.officer_registry.lookup[officer_id].display_name, outcome]

func toggle() -> void:
	if is_instance_valid(slots): slots.queue_free()
	if is_instance_valid(options): options.queue_free()
	confirmation.hide()
	shade.visible = not shade.visible
	modal.show()
	main.dragging = false
	main.district_click_serial += 1
	get_tree().paused = shade.visible

func show_slots(saving: bool) -> void:
	modal.hide()
	slots = preload("res://scripts/game/save_slots.gd").new()
	slots.main = main
	slots.saving = saving
	slots.closed.connect(modal.show)
	shade.add_child(slots)

func show_options() -> void:
	modal.hide()
	options = preload("res://scripts/game/display_options.gd").new()
	options.closed.connect(modal.show)
	shade.add_child(options)

func show_dictionary() -> void:
	modal.hide()
	if officer_dictionary == null:
		officer_dictionary = preload("res://scripts/game/officer_panel.gd").new()
		officer_dictionary.standalone = true
		officer_dictionary.closed.connect(modal.show)
		add_child(officer_dictionary)
	officer_dictionary.show_browser()

func show_retainers() -> void:
	modal.hide()
	if not is_instance_valid(retainer_panel):
		retainer_panel = preload("res://scripts/game/retainer_panel.gd").new()
		retainer_panel.main = main
		retainer_panel.confirmed.connect(modal.show)
		retainer_panel.canceled.connect(modal.show)
		retainer_panel.close_requested.connect(modal.show)
		add_child(retainer_panel)
	retainer_panel.open()

func show_technology() -> void:
	modal.hide()
	if not is_instance_valid(technology_panel):
		technology_panel = preload("res://scripts/game/technology_panel.gd").new()
		technology_panel.main = main
		technology_panel.confirmed.connect(modal.show)
		technology_panel.canceled.connect(modal.show)
		technology_panel.close_requested.connect(modal.show)
		add_child(technology_panel)
	technology_panel.open()

func confirm_action(value: String) -> void:
	action = value
	confirmation.dialog_text = "未保存の進行は失われます。" + ("ゲームを終了しますか？" if value == "quit" else "スタートメニューに戻りますか？")
	confirmation.popup_centered()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if confirmation.visible: confirmation.hide()
		elif is_instance_valid(officer_dictionary) and is_instance_valid(officer_dictionary.browser) and officer_dictionary.browser.visible:
			officer_dictionary.browser.hide()
			modal.show()
		elif is_instance_valid(retainer_panel) and retainer_panel.visible:
			retainer_panel.hide()
			modal.show()
		elif is_instance_valid(technology_panel) and technology_panel.visible:
			technology_panel.hide()
			modal.show()
		elif is_instance_valid(options): options._close()
		elif is_instance_valid(slots):
			if slots.confirmation.visible: slots.confirmation.hide()
			else: slots.queue_free(); modal.show()
		else: toggle()
		get_viewport().set_input_as_handled()
