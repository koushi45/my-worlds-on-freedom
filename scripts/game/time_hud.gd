extends CanvasLayer

const ICON_DIRECTORY := "res://assets/ui/time/"
const PAPER := Color("#f7efd8")

var clock: Node
var date_label: Label
var rate_label: Label
var panel: Control
var playback_button: Button
var slower_button: Button
var faster_button: Button
var date_icon: TextureRect
var date_icon_holder: Control
var playback_icon: TextureRect
var slower_icon: TextureRect
var faster_icon: TextureRect
var icon_variant_size := 0
var last_window_size := Vector2i.ZERO


func _ready() -> void:
	layer = 10
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	panel = Control.new()
	panel.name = "TimePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_force_pass_scroll_events = false
	overlay.add_child(panel)
	var frame := NinePatchRect.new()
	frame.texture = preload("res://assets/ui/hud/frame_256.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: frame.set_patch_margin(side, 52)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.offset_left = 22
	rows.offset_right = -22
	rows.offset_top = 17
	rows.offset_bottom = -15
	panel.add_child(rows)
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 6)
	rows.add_child(date_row)
	date_icon_holder = Control.new()
	date_row.add_child(date_icon_holder)
	date_icon = _make_icon(date_icon_holder)
	date_label = Label.new()
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date_label.add_theme_font_size_override("font_size", 23)
	date_label.add_theme_color_override("font_color", PAPER)
	date_row.add_child(date_label)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	rows.add_child(controls)
	slower_button = _make_button("速度を1段階下げる", controls)
	slower_icon = _make_icon(slower_button)
	slower_button.pressed.connect(clock.change_speed.bind(-1))
	playback_button = _make_button("停止 / 再生（スペース）", controls)
	playback_icon = _make_icon(playback_button)
	playback_button.pressed.connect(clock.toggle_paused)
	faster_button = _make_button("速度を1段階上げる", controls)
	faster_icon = _make_icon(faster_button)
	faster_button.pressed.connect(clock.change_speed.bind(1))
	rate_label = Label.new()
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rate_label.add_theme_font_size_override("font_size", 13)
	rate_label.add_theme_color_override("font_color", Color("#d7bc81"))
	rate_label.tooltip_text = "スペース: 停止 / 再生　1: 1倍　2: 2倍　3: 4倍　4: 8倍"
	rows.add_child(rate_label)
	clock.day_advanced.connect(_on_day_advanced)
	clock.state_restored.connect(_on_day_advanced)
	clock.speed_changed.connect(_on_speed_changed)
	clock.pause_changed.connect(_on_pause_changed)
	get_viewport().size_changed.connect(_resize)
	if get_window() != get_viewport(): get_window().size_changed.connect(_resize)
	_resize()
	_on_day_advanced(clock.year, clock.month, clock.day)
	_on_speed_changed(clock.speed)


func _make_button(hint: String, parent: Control) -> Button:
	var button := Button.new()
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#d7bc8133")
	hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	parent.add_child(button)
	return button


func _make_icon(parent: Control) -> TextureRect:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else viewport_size
	last_window_size = Vector2i(window_size)
	var pixel_scale := maxf(0.1, window_size.x / maxf(1.0, viewport_size.x))
	var side := 256 if window_size.y >= 3600 else (192 if window_size.y >= 2700 else (128 if window_size.y >= 1800 else (96 if window_size.y >= 1200 else 64)))
	var logical_side := float(side) / pixel_scale
	if icon_variant_size != side:
		icon_variant_size = side
		date_icon.texture = load(ICON_DIRECTORY + "calendar_%d.png" % side)
		slower_icon.texture = load(ICON_DIRECTORY + "slower_%d.png" % side)
		faster_icon.texture = load(ICON_DIRECTORY + "faster_%d.png" % side)
		_update_playback()
	date_icon_holder.custom_minimum_size = Vector2(logical_side, logical_side)
	date_icon.size = Vector2(side, side)
	date_icon.scale = Vector2.ONE / pixel_scale
	for button in [slower_button, playback_button, faster_button]:
		button.custom_minimum_size = Vector2(logical_side + 6, logical_side + 4)
	for icon in [slower_icon, playback_icon, faster_icon]:
		icon.size = Vector2(side, side)
		icon.scale = Vector2.ONE / pixel_scale
		icon.position = Vector2(3, 2)
	panel.offset_left = -minf(320.0, viewport_size.x - 32.0) - 16.0
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = 16 + 17 + logical_side * 2.0 + 4.0 + 10.0 + 20.0 + 15.0


func _process(_delta: float) -> void:
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_size() != last_window_size:
		_resize()


func _on_day_advanced(_year: int, _month: int, _day: int) -> void:
	date_label.text = clock.date_text()


func _on_speed_changed(value: int) -> void:
	slower_button.disabled = value == clock.SPEEDS.front()
	faster_button.disabled = value == clock.SPEEDS.back()
	_update_playback()


func _on_pause_changed(_paused: bool) -> void:
	_update_playback()


func _update_playback() -> void:
	if playback_icon == null or icon_variant_size == 0:
		return
	playback_icon.texture = load(ICON_DIRECTORY + ("play_%d.png" if clock.paused else "pause_%d.png") % icon_variant_size)
	playback_button.tooltip_text = "再生（スペース）" if clock.paused else "停止（スペース）"
	rate_label.text = ("停止中｜再開時 %d倍" if clock.paused else "%d倍速｜1秒 = %d日") % ([clock.speed] if clock.paused else [clock.speed, clock.speed])


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
