extends CanvasLayer

var clock: Node
var date_label: Label
var rate_label: Label
var panel: PanelContainer
var playback_button: Button
var slower_button: Button
var faster_button: Button


func _ready() -> void:
	layer = 10
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	panel = PanelContainer.new()
	panel.name = "TimePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -308
	panel.offset_right = -16
	panel.offset_top = 16
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_force_pass_scroll_events = false
	overlay.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172e38ef")
	style.border_color = Color("#b5a879")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	date_label = Label.new()
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_label.add_theme_font_size_override("font_size", 24)
	date_label.add_theme_color_override("font_color", Color("#f7efd8"))
	rows.add_child(date_label)
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 6)
	rows.add_child(speeds)
	slower_button = _make_button("− 減速", "速度を1段階下げる", speeds)
	slower_button.pressed.connect(clock.change_speed.bind(-1))
	playback_button = _make_button("停止", "停止 / 再生（スペース）", speeds)
	playback_button.pressed.connect(clock.toggle_paused)
	faster_button = _make_button("＋ 加速", "速度を1段階上げる", speeds)
	faster_button.pressed.connect(clock.change_speed.bind(1))
	rate_label = Label.new()
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rate_label.add_theme_font_size_override("font_size", 12)
	rate_label.add_theme_color_override("font_color", Color("#c8d2d3"))
	rows.add_child(rate_label)
	clock.day_advanced.connect(_on_day_advanced)
	clock.state_restored.connect(_on_day_advanced)
	clock.speed_changed.connect(_on_speed_changed)
	clock.pause_changed.connect(_on_pause_changed)
	_on_day_advanced(clock.year, clock.month, clock.day)
	_on_speed_changed(clock.speed)


func _on_day_advanced(_year: int, _month: int, _day: int) -> void:
	date_label.text = clock.date_text()


func _on_speed_changed(value: int) -> void:
	slower_button.disabled = value == clock.SPEEDS.front()
	faster_button.disabled = value == clock.SPEEDS.back()
	_update_playback()


func _on_pause_changed(_paused: bool) -> void:
	_update_playback()


func _update_playback() -> void:
	playback_button.text = "再生" if clock.paused else "停止"
	rate_label.text = ("停止中｜再開時 %d倍" if clock.paused else "%d倍速｜1秒 = %d日") % ([clock.speed] if clock.paused else [clock.speed, clock.speed])
	rate_label.tooltip_text = "スペース: 停止 / 再生　1: 1倍　2: 2倍　3: 4倍　4: 8倍"


func _make_button(text: String, hint: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(80, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Space always controls playback, including after a mouse click on speed buttons.
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	match event.keycode:
		KEY_SPACE:
			clock.toggle_paused()
		KEY_1, KEY_2, KEY_3, KEY_4:
			clock.set_speed(clock.SPEEDS[event.keycode - KEY_1])
		_:
			return
	get_viewport().set_input_as_handled()
