extends CanvasLayer
## The player's house at a glance. Values come directly from the live simulation.

const Portraits = preload("res://scripts/game/officer_portraits.gd")
const IconHintPopup = preload("res://scripts/game/icon_hint_popup.gd")
const ICONS := {
	"money": "koban",
	"governance": "governance",
	"military": "military",
	"diplomacy": "diplomacy",
	"security": "security",
	"population": "people",
	"troops": "spears",
	"provisions": "rice",
	"districts": "castle",
	"prestige": "fan",
}
const METRIC_ROWS := [
	["money", "governance", "military", "diplomacy", "security"],
	["population", "troops", "provisions", "districts", "prestige"],
]
const HINTS := {
	"money": "所持金銭",
	"governance": "統治技術力",
	"military": "軍事技術力",
	"diplomacy": "外交技術力",
	"security": "領有郡の平均治安（技術・施設効果を含む）",
	"population": "領有郡の総人口",
	"troops": "領有郡の出陣可能人数合計",
	"provisions": "所持兵糧",
	"districts": "領有郡数",
	"prestige": "大名家の威信",
}
const PAPER := Color("#fff0d3")

var main: Node
var panel: Control
var portrait: TextureRect
var crest: TextureRect
var house_label: Label
var ruler_label: Label
var values: Dictionary = {}
var metric_icons: Dictionary = {}
var icon_variant_size := 0
var last_window_size := Vector2i.ZERO
var refresh_elapsed := 0.0
var council_button: Button
var council_icon: TextureRect
var icon_hint
var refresh_dirty := false
var refresh_count := 0
var last_ruler_id := "__uninitialized__"


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	icon_hint = IconHintPopup.new()
	overlay.add_child(icon_hint)
	panel = Control.new()
	panel.name = "HouseStatusPanel"
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_force_pass_scroll_events = false
	overlay.add_child(panel)
	var frame := NinePatchRect.new()
	frame.name = "LacquerFrame"
	frame.texture = _frame_texture()
	frame.set_patch_margin(SIDE_LEFT, 52)
	frame.set_patch_margin(SIDE_TOP, 52)
	frame.set_patch_margin(SIDE_RIGHT, 52)
	frame.set_patch_margin(SIDE_BOTTOM, 52)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 42
	content.offset_right = -42
	content.offset_top = 23
	content.offset_bottom = -23
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 174
	identity.add_theme_constant_override("separation", 0)
	content.add_child(identity)
	var pictures := HBoxContainer.new()
	pictures.add_theme_constant_override("separation", 5)
	identity.add_child(pictures)
	portrait = _picture(pictures, Vector2(61, 65))
	portrait.texture = preload("res://assets/ui/hud/samurai.png")
	crest = _picture(pictures, Vector2(58, 58))
	house_label = _label(identity, 12, Color("#d7bc81"))
	ruler_label = _label(identity, 20, PAPER)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 3)
	content.add_child(rows)
	for keys in METRIC_ROWS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 3)
		rows.add_child(row)
		for key in keys: _add_metric(row, key)
	council_button = Button.new()
	council_button.name = "CouncilButton"
	council_button.text = "      評定"
	council_button.tooltip_text = ""
	council_button.custom_minimum_size = Vector2(154, 48)
	council_button.focus_mode = Control.FOCUS_NONE
	council_button.add_theme_font_size_override("font_size", 20)
	council_button.add_theme_color_override("font_color", PAPER)
	var council_style := StyleBoxFlat.new()
	council_style.bg_color = Color("#172b30")
	council_style.border_color = Color("#c5a15f")
	council_style.set_border_width_all(2)
	council_style.set_corner_radius_all(6)
	council_button.add_theme_stylebox_override("normal", council_style)
	var hover_style := council_style.duplicate()
	hover_style.bg_color = Color("#29424a")
	council_button.add_theme_stylebox_override("hover", hover_style)
	council_button.add_theme_stylebox_override("pressed", hover_style)
	council_button.pressed.connect(func(): main.game_menu.toggle_council())
	icon_hint.bind_icon(council_button, "評定を開く（役職ツリー・配下管理／技術ツリー／外交）")
	panel.add_child(council_button)
	council_icon = TextureRect.new()
	council_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	council_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	council_icon.stretch_mode = TextureRect.STRETCH_KEEP
	council_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	council_button.add_child(council_icon)
	get_viewport().size_changed.connect(_resize)
	if get_window() != get_viewport(): get_window().size_changed.connect(_resize)
	_resize()
	_refresh()
	main.retainer_management.updated.connect(invalidate)
	main.army_campaign.changed.connect(invalidate)
	main.diplomacy.changed.connect(invalidate)
	main.district_economy.development_updated.connect(invalidate)
	main.district_economy.income_collected.connect(func(_kind, _amount): invalidate())
	main.district_actions.changed.connect(func(_id): invalidate())
	main.district_buildings.changed.connect(func(_id): invalidate())
	main.technology_tree.research_completed.connect(func(_house, _branch, _id): invalidate())
	main.house_prestige.prestige_changed.connect(func(_house, _value, _reason): invalidate())
	main.game_clock.day_advanced.connect(func(_year, _month, _day): invalidate())


func _frame_texture() -> Texture2D:
	return preload("res://assets/ui/hud/frame_256.png")


func _picture(parent: Control, dimensions: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.custom_minimum_size = dimensions
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(picture)
	return picture


func _label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _add_metric(row: HBoxContainer, key: String) -> void:
	var item := HBoxContainer.new()
	item.custom_minimum_size.x = 114
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 2)
	row.add_child(item)
	var icon_holder := Control.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	item.add_child(icon_holder)
	icon_hint.bind_icon(icon_holder, HINTS[key])
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)
	metric_icons[key] = icon
	var value := _label(item, 17, PAPER)
	value.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_hint.bind_icon(value, HINTS[key])
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values[key] = value


func _resize() -> void:
	# Leave 16 logical pixels before the time controls at the 1280 px design width.
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else viewport_size
	last_window_size = Vector2i(window_size)
	var pixel_scale := maxf(0.1, window_size.x / maxf(1.0, viewport_size.x))
	var side := 256 if window_size.y >= 3600 else (192 if window_size.y >= 2700 else (128 if window_size.y >= 1800 else (96 if window_size.y >= 1200 else 64)))
	var logical_side := float(side) / pixel_scale
	if icon_variant_size != side:
		icon_variant_size = side
		for key in metric_icons:
			metric_icons[key].texture = load("res://assets/ui/hud/%s_%d.png" % [ICONS[key], side])
		council_icon.texture = load("res://assets/ui/hud/governance_%d.png" % side)
	for icon in metric_icons.values():
		icon.get_parent().custom_minimum_size = Vector2(logical_side, logical_side)
		icon.size = Vector2(side, side)
		icon.scale = Vector2.ONE / pixel_scale
	# Both the two native-size icon rows and the portrait/name group need
	# breathing room inside the ornamental top and bottom edges.
	panel.size = Vector2(minf(912.0, maxf(0.0, viewport_size.x - 368.0)), maxf(105.0, logical_side * 2.0 + 3.0) + 46.0)
	council_button.position = Vector2(42, panel.size.y - 10)
	council_icon.size = Vector2(side, side)
	council_icon.scale = Vector2.ONE / pixel_scale
	council_icon.position = Vector2(8, (48.0 - logical_side) * 0.5)


func _process(delta: float) -> void:
	# With canvas_items stretch, the logical viewport can stay 1280x720 while
	# the OS window changes size, so the viewport signal alone is insufficient.
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_size() != last_window_size:
		_resize()
	if refresh_dirty:
		refresh_dirty = false
		_refresh()

func invalidate() -> void:
	refresh_dirty = true


func _refresh() -> void:
	if main == null or GameSession.player_house.is_empty(): return
	refresh_count += 1
	var house_id: String = GameSession.player_house
	var house: Dictionary = main.governance_registry.houses.get(house_id, {})
	var ruler: Dictionary = house.get("ruler", {})
	var ruler_id: String = str(ruler.get("officer_id", ""))
	house_label.text = str(house.get("display_name", house_id))
	ruler_label.text = str(ruler.get("name", "当主不明"))
	if last_ruler_id != ruler_id:
		last_ruler_id = ruler_id
		var face: Texture2D = Portraits.texture_for(ruler_id)
		portrait.texture = face if face != null else preload("res://assets/ui/hud/samurai.png")
		portrait.tooltip_text = ruler_label.text if face != null else ruler_label.text + "（肖像未収録）"
	var crest_entry: Dictionary = main.kamon_layer.kamon_by_house.get(house_id, {})
	var crest_asset: String = str(crest_entry.get("asset", ""))
	crest.texture = main.kamon_layer.kamon_textures.get(crest_asset)
	crest.tooltip_text = "家紋：%s" % str(crest_entry.get("crest_name", house_label.text))
	var population := 0
	var troops := 0
	var districts := 0
	var security_sum := 0
	for record in main.governance_registry.districts.values():
		if record.house_id != house_id: continue
		districts += 1
		population += int(record.get("population", 0))
		troops += main.district_actions.sortie_available(record)
		security_sum += main.technology_tree.security_for(record)
	var resources: Dictionary = main.district_economy.house_resources.get(house_id, {})
	var technology: Dictionary = main.retainer_management.technology.get(house_id, {})
	values.money.text = "%.1f" % float(resources.get("money", 0))
	values.governance.text = "%.1f" % float(technology.get("governance", 0))
	values.military.text = "%.1f" % float(technology.get("military", 0))
	values.diplomacy.text = "%.1f" % float(technology.get("diplomacy", 0))
	values.security.text = "%d" % roundi(float(security_sum) / districts) if districts > 0 else "―"
	values.population.text = _grouped(population)
	values.troops.text = _grouped(troops)
	values.provisions.text = _grouped(int(resources.get("provisions", 0)))
	values.districts.text = "%d" % districts
	values.prestige.text = "%d" % main.house_prestige.value_for(house_id)


func _grouped(number: int) -> String:
	var digits := str(number)
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0: result += ","
		result += digits[i]
	return result
