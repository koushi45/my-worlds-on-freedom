extends RefCounted

static func panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#112932f5")
	s.border_color = Color("#baa375")
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s

static func button(text: String, parent: Node, action: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(250,44)
	b.add_theme_font_size_override("font_size",18)
	parent.add_child(b)
	if action.is_valid(): b.pressed.connect(action)
	return b

static func label(text: String, parent: Node, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("#f4e8cd"))
	parent.add_child(l)
	return l

static func centered(parent: Control, dimensions: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -dimensions.x/2
	p.offset_right = dimensions.x/2
	p.offset_top = -dimensions.y/2
	p.offset_bottom = dimensions.y/2
	p.add_theme_stylebox_override("panel",panel())
	return p
