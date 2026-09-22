extends CanvasLayer
## Minimal district-name window shown only while a district is selected.

const UI = preload("res://scripts/game/menu_style.gd")

var panel: PanelContainer
var name_label: Button
var ruler_label: Label
var copy_status: Label

func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	panel = PanelContainer.new()
	panel.name = "DistrictNameWindow"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.5
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.5
	panel.offset_left = 24.0
	panel.offset_top = -64.0
	panel.offset_right = 354.0
	panel.offset_bottom = 64.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",UI.panel())
	root_control.add_child(panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)
	var title_label := UI.label("選択中の郡",rows,15)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label = Button.new()
	name_label.name = "DistrictNameCopyButton"
	name_label.flat = true
	name_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2(280,40)
	name_label.add_theme_font_size_override("font_size",24)
	name_label.add_theme_color_override("font_color",Color("#f4e8cd"))
	name_label.tooltip_text = "クリックして郡名をコピー"
	name_label.pressed.connect(_copy_name)
	rows.add_child(name_label)
	ruler_label = UI.label("",rows,16)
	ruler_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy_status = UI.label("郡名をクリックでコピー",rows,12)
	copy_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.hide()

func show_district(district_name: String, ruler_name: String) -> void:
	name_label.text = district_name
	ruler_label.text = "支配者：%s" % ruler_name
	copy_status.text = "郡名をクリックでコピー"
	panel.show()

func hide_info() -> void:
	panel.hide()

func _copy_name() -> void:
	if name_label.text.is_empty(): return
	DisplayServer.clipboard_set(name_label.text)
	copy_status.text = "「%s」をコピーしました" % name_label.text
