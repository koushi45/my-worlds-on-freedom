extends RefCounted

const UI = preload("res://scripts/game/menu_style.gd")
const FRAME = preload("res://assets/ui/hud/frame_256.png")
const GOLD := Color("#d7ad64")
const PAPER := Color("#f4e8cd")

static func frame(parent: Control) -> NinePatchRect:
	var border := NinePatchRect.new()
	border.texture = FRAME
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		border.set_patch_margin(side, 52)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(border)
	return border

static func heading(title: String, parent: Control, size: int = 19) -> Label:
	var label := UI.label("━━  ◆ %s  ━━" % title, parent, size)
	label.add_theme_color_override("font_color", GOLD)
	return label

static func button(caption: String, parent: Control, action: Callable) -> Button:
	var item := UI.button(caption, parent, action)
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_color_override("font_color", PAPER)
	item.add_theme_color_override("font_hover_color", GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#171b25b8")
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	item.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#26313bdc")
	hover.border_color = GOLD
	hover.set_border_width_all(1)
	item.add_theme_stylebox_override("hover", hover)
	item.add_theme_stylebox_override("pressed", hover)
	return item

static func field(control: Control) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#171b25b8")
	background.set_corner_radius_all(2)
	control.add_theme_stylebox_override("normal", background)
	control.add_theme_stylebox_override("panel", background)
	control.add_theme_color_override("font_color", PAPER)

static func icon(parent: Control, stem: String) -> Control:
	var viewport_size := parent.get_viewport().get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else viewport_size
	var pixel_scale := maxf(0.1, window_size.x / maxf(1.0, viewport_size.x))
	var pixels := 256 if window_size.y >= 3600 else (192 if window_size.y >= 2700 else (128 if window_size.y >= 1800 else (96 if window_size.y >= 1200 else 64)))
	var logical_size := float(pixels) / pixel_scale
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(logical_size, logical_size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var picture := TextureRect.new()
	picture.texture = load("%s_%d.png" % [stem, pixels])
	picture.size = Vector2(pixels, pixels)
	picture.scale = Vector2.ONE / pixel_scale
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(picture)
	return holder
