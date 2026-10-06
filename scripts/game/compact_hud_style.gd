extends RefCounted
## Native PNGs contain small artwork with transparent padding.
const DIRECTORY := "res://assets/ui/hud/compact/"

static func pixels(control: Control) -> int:
	var height := DisplayServer.window_get_size().y if DisplayServer.get_name() != "headless" else int(control.get_viewport_rect().size.y)
	return 256 if height >= 2880 else (192 if height >= 2160 else (128 if height >= 1440 else (96 if height >= 1000 else 64)))

static func pixel_scale(control: Control) -> float:
	if DisplayServer.get_name() == "headless": return 1.0
	var physical := float(DisplayServer.window_get_size().x)
	var logical := control.get_viewport_rect().size.x
	if physical <= 0.0 or logical <= 0.0: return 1.0
	return physical / maxf(1.0, logical)

static func unit(control: Control) -> float:
	return float(pixels(control)) / 64.0 / pixel_scale(control)

static func frame(panel: Control, kind: String) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = "NativeFrame"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP
	panel.add_child(picture)
	update_frame(panel, kind)
	return picture

static func update_frame(panel: Control, kind: String) -> void:
	var picture: TextureRect = panel.get_node("NativeFrame")
	picture.texture = load(DIRECTORY + "%s_%d.png" % [kind, pixels(panel)])
	picture.size = picture.texture.get_size()
	picture.scale = Vector2.ONE / pixel_scale(panel)
	panel.size = picture.size * picture.scale

static func council_position(panel: Control, hud: Node) -> Vector2:
	return Vector2(hud.panel.position.x, hud.council_popup_position().y + 30 * unit(panel))

static func icon(parent: Control, name: String) -> TextureRect:
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP
	parent.add_child(picture)
	update_icon(picture, name)
	return picture

static func update_icon(picture: TextureRect, name: String) -> void:
	var side := pixels(picture)
	var cell := 28.0 * unit(picture)
	picture.texture = load(DIRECTORY + "%s_%d.png" % [name, side])
	picture.size = Vector2.ONE * side
	picture.scale = Vector2.ONE / pixel_scale(picture)
	picture.position = Vector2.ONE * (cell - float(side) / pixel_scale(picture)) * 0.5

static func button(parent: Control, hint: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = ""
	item.tooltip_text = hint
	item.focus_mode = Control.FOCUS_NONE
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#101821")
	normal.border_color = Color("#97733c")
	normal.set_border_width_all(1)
	normal.set_content_margin_all(0)
	item.add_theme_stylebox_override("normal", normal)
	var selected := normal.duplicate()
	selected.bg_color = Color("#3a3420")
	selected.border_color = Color("#e5c17b")
	item.add_theme_stylebox_override("hover", selected)
	item.add_theme_stylebox_override("pressed", selected)
	item.pressed.connect(action)
	parent.add_child(item)
	return item
