extends CanvasLayer
const Compact = preload("res://scripts/game/compact_hud_style.gd")
var clock: Node
var panel: Control
var date_label: Label
var rate_label: Label
var playback_button: Button
var playback_icon: TextureRect
var speed_buttons: Array[Button] = []
var icon_variant_size := 0
var last_window_size := Vector2i.ZERO

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	panel = Control.new()
	panel.name = "TimePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_force_pass_scroll_events = false
	overlay.add_child(panel)
	Compact.frame(panel, "time")
	date_label = Label.new()
	date_label.add_theme_color_override("font_color", Color("#fff0d3"))
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(date_label)
	playback_button = Compact.button(panel, "停止／再生（スペース）", clock.toggle_paused)
	playback_icon = Compact.icon(playback_button, "pause")
	rate_label = Label.new()
	rate_label.add_theme_color_override("font_color", Color("#d7bc81"))
	rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(rate_label)
	for speed in clock.SPEEDS:
		var button := Compact.button(panel, "%d倍速（%d）" % [speed, speed_buttons.size()+1], clock.set_speed.bind(speed))
		button.toggle_mode = true
		var lit := StyleBoxFlat.new()
		lit.bg_color = Color("#e5c17b")
		lit.set_content_margin_all(0)
		button.add_theme_stylebox_override("pressed", lit)
		button.pressed.connect(func(): _on_speed_changed(clock.speed))
		speed_buttons.append(button)
	clock.day_advanced.connect(_on_day_advanced)
	clock.state_restored.connect(_on_day_advanced)
	clock.speed_changed.connect(_on_speed_changed)
	clock.pause_changed.connect(_on_pause_changed)
	get_viewport().size_changed.connect(_resize)
	if get_window() != get_viewport(): get_window().size_changed.connect(_resize)
	_resize()
	_on_day_advanced(clock.year, clock.month, clock.day)
	_on_speed_changed(clock.speed)

func _resize() -> void:
	last_window_size = DisplayServer.window_get_size()
	icon_variant_size = Compact.pixels(panel)
	var u := Compact.unit(panel)
	Compact.update_frame(panel, "time")
	panel.position = Vector2(get_viewport().get_visible_rect().size.x - panel.size.x - 12, 12)
	date_label.position = Vector2(13, 7) * u
	date_label.size = Vector2(100, 34) * u
	date_label.add_theme_font_size_override("font_size", roundi(14*u))
	playback_button.position = Vector2(118, 9) * u
	playback_button.size = Vector2(30, 30) * u
	Compact.update_icon(playback_icon, "play" if clock.paused else "pause")
	rate_label.position = Vector2(155, 5) * u
	rate_label.size = Vector2(65, 18) * u
	rate_label.add_theme_font_size_override("font_size", roundi(11*u))
	for index in range(speed_buttons.size()):
		speed_buttons[index].position = Vector2(157 + index*16, 29) * u
		speed_buttons[index].size = Vector2(11, 11) * u

func _process(_delta: float) -> void:
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_size() != last_window_size: _resize()

func _on_day_advanced(year: int, month: int, day: int) -> void:
	date_label.text = "%d.%d.%d" % [year, month, day]
	date_label.tooltip_text = clock.date_text()

func _on_speed_changed(speed: int) -> void:
	for index in range(speed_buttons.size()): speed_buttons[index].set_pressed_no_signal(clock.SPEEDS[index] <= speed)
	_update_playback()

func _on_pause_changed(_paused: bool) -> void:
	_update_playback()

func _update_playback() -> void:
	if playback_icon == null: return
	Compact.update_icon(playback_icon, "play" if clock.paused else "pause")
	playback_button.tooltip_text = "再生（スペース）" if clock.paused else "停止（スペース）"
	rate_label.text = "%d×" % clock.speed
	rate_label.tooltip_text = "停止中" if clock.paused else "1秒＝%d日" % clock.speed

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
