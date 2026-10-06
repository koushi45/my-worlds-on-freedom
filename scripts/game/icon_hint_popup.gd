extends PanelContainer
## Immediate icon labels for mouse hover and Android taps.

var active_target: Control
var caption: Label
var touch_mode := OS.has_feature("android")

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#111a2bf5")
	frame.border_color = Color("#d7ad64")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(5)
	frame.set_content_margin_all(9)
	add_theme_stylebox_override("panel", frame)
	caption = Label.new()
	caption.add_theme_color_override("font_color", Color("#fff0d3"))
	caption.add_theme_font_size_override("font_size", 16)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)

func show_for(target: Control, label: String) -> void:
	if label.is_empty(): return
	active_target = target
	caption.text = label
	size = get_combined_minimum_size()
	var view_size := get_viewport_rect().size
	var target_rect := target.get_global_rect()
	var x := clampf(target_rect.position.x, 4.0, maxf(4.0, view_size.x - size.x - 4.0))
	var y := target_rect.end.y + 4.0
	if y + size.y > view_size.y - 4.0:
		y = target_rect.position.y - size.y - 4.0
	position = Vector2(x, maxf(4.0, y))
	show()

func hide_for(target: Control) -> void:
	if active_target == target: clear()

func clear() -> void:
	active_target = null
	hide()

func bind_icon(target: Control, label: String) -> void:
	bind_dynamic_icon(target, func() -> String: return label)

func bind_dynamic_icon(target: Control, label: Callable) -> void:
	target.mouse_entered.connect(func():
		if not touch_mode: show_for(target, str(label.call()))
	)
	target.mouse_exited.connect(func():
		if not touch_mode: hide_for(target)
	)
	target.gui_input.connect(func(event: InputEvent):
		if not touch_mode: return
		if event is InputEventScreenTouch and event.pressed:
			show_for(target, str(label.call()))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			show_for(target, str(label.call()))
	)

func bind_action_icon(target: BaseButton, label: String, action: Callable) -> void:
	target.mouse_entered.connect(func():
		if not touch_mode: show_for(target, label)
	)
	target.mouse_exited.connect(func():
		if not touch_mode: hide_for(target)
	)
	target.gui_input.connect(func(event: InputEvent):
		if not touch_mode or not target.disabled: return
		if event is InputEventScreenTouch and event.pressed:
			show_for(target, label)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			show_for(target, label)
	)
	target.pressed.connect(func():
		if touch_mode and active_target != target:
			show_for(target, label)
			return
		clear()
		action.call()
	)
