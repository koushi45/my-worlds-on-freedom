extends RefCounted
## Council text and native PNG artwork follow the header's density scale.
const Base = preload("res://scripts/game/district_panel_style.gd")
const Compact = preload("res://scripts/game/compact_hud_style.gd")
const UI = preload("res://scripts/game/menu_style.gd")
const GOLD := Base.GOLD

static func _font(control: Control, size: int) -> void:
	control.set_meta("council_font_size", size)
	var unit := Compact.unit(control) if control.is_inside_tree() else 1.0
	control.add_theme_font_size_override("font_size", roundi(size * unit))

static func label(text: String, parent: Node, size: int = 12) -> Label:
	var result := UI.label(text, parent, size)
	_font(result, size)
	return result

static func heading(text: String, parent: Control, size: int = 14) -> Label:
	var result := label("━━  ◆ %s  ━━" % text, parent, size)
	result.add_theme_color_override("font_color", GOLD)
	return result

static func button(text: String, parent: Control, action: Callable) -> Button:
	var result := Base.button(text, parent, action)
	_font(result, 12)
	result.clip_text = true
	return result

static func field(control: Control) -> void:
	Base.field(control)
	_font(control, 12)
	if control is SpinBox: _font(control.get_line_edit(), 12)

static func frame(parent: Control) -> NinePatchRect:
	return Base.frame(parent)

static func icon(parent: Control, stem: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(holder)
	var name := ("district_" if stem.begins_with("res://assets/ui/district/") else "") + stem.get_file()
	holder.set_meta("council_icon", name)
	holder.custom_minimum_size = Vector2.ONE * 28 * Compact.unit(holder)
	Compact.icon(holder, name)
	return holder

static func resize(root: Control) -> void:
	if root.has_meta("council_font_size"): _font(root, root.get_meta("council_font_size"))
	if root.has_meta("council_icon"):
		root.custom_minimum_size = Vector2.ONE * 28 * Compact.unit(root)
		Compact.update_icon(root.get_child(0), root.get_meta("council_icon"))
	for child in root.get_children():
		if child is Control: resize(child)

static func follow_window(root: Control) -> void:
	var viewport := root.get_viewport()
	var update := func(): resize(root)
	viewport.size_changed.connect(update)
	root.tree_exiting.connect(func(): viewport.size_changed.disconnect(update), CONNECT_ONE_SHOT)
	resize(root)
