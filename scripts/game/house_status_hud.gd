extends CanvasLayer
## The player's house at a glance. Values come directly from the live simulation.

const Compact = preload("res://scripts/game/compact_hud_style.gd")
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
const HOUSEHOLD := ["money", "provisions", "population", "troops", "prestige", "security", "districts"]
const TECHNOLOGY := ["governance", "diplomacy", "military"]
const HINTS := {"money":"所持金銭", "provisions":"所持兵糧", "population":"領有郡の総人口", "troops":"出陣可能な総兵力", "prestige":"大名家の威信", "security":"領有郡の平均治安", "districts":"領有郡数", "governance":"統治技術力", "diplomacy":"外交技術力", "military":"軍事技術力"}
const PAPER := Color("#fff0d3")
var main: Node
var panel: Control
var household_panel: Control
var technology_panel: Control
var crest: TextureRect
var house_label: Label
var ruler_label: Label
var values: Dictionary = {}
var metric_icons: Dictionary = {}
var metric_cells: Dictionary = {}
var icon_variant_size := 0
var last_window_size := Vector2i.ZERO
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
	panel = _panel(overlay, "HouseIdentity", "identity")
	crest = TextureRect.new()
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(crest)
	house_label = _label(panel, 12)
	ruler_label = _label(panel, 11)
	ruler_label.hide()
	household_panel = _panel(overlay, "HouseholdMetrics", "house")
	technology_panel = _panel(overlay, "TechnologyMetrics", "technology")
	for key in HOUSEHOLD: _metric(household_panel, key)
	for key in TECHNOLOGY: _metric(technology_panel, key)
	council_button = Compact.button(overlay, "評定", func(): main.game_menu.toggle_council())
	council_button.name = "CouncilButton"
	council_icon = Compact.icon(council_button, "fan")
	icon_hint.bind_icon(council_button, "評定（家臣管理・外交・技術）")
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

func _panel(parent: Control, title: String, kind: String) -> Control:
	var result := Control.new()
	result.name = title
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.mouse_force_pass_scroll_events = false
	parent.add_child(result)
	Compact.frame(result, kind)
	return result

func _label(parent: Control, font_size: int) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", PAPER)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(result)
	return result

func _metric(parent: Control, key: String) -> void:
	var cell := Control.new()
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(cell)
	icon_hint.bind_icon(cell, HINTS[key])
	metric_cells[key] = cell
	metric_icons[key] = Compact.icon(cell, ICONS[key])
	values[key] = _label(cell, 12)

func _resize() -> void:
	last_window_size = DisplayServer.window_get_size()
	var u := Compact.unit(panel)
	icon_variant_size = Compact.pixels(panel)
	Compact.update_frame(panel, "identity")
	Compact.update_frame(household_panel, "house")
	Compact.update_frame(technology_panel, "technology")
	panel.position = Vector2(12, 12)
	household_panel.position = panel.position + Vector2(128, 0) * u
	technology_panel.position = household_panel.position + Vector2(0, 46) * u
	crest.position = Vector2(8, 10) * u
	crest.size = Vector2(44, 44) * u
	house_label.position = Vector2(53, 10) * u
	house_label.size = Vector2(61, 65) * u
	house_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	house_label.add_theme_font_size_override("font_size", roundi(12*u))
	_layout_metrics(HOUSEHOLD, [93, 83, 112, 99, 60, 60, 55], u)
	_layout_metrics(TECHNOLOGY, [76, 76, 76], u)
	council_button.position = technology_panel.position + Vector2(246, 5) * u
	council_button.size = Vector2(30, 30) * u
	Compact.update_icon(council_icon, "fan")

func _layout_metrics(keys: Array, widths: Array, u: float) -> void:
	var x := 7.0
	for index in range(keys.size()):
		var key: String = keys[index]
		var cell: Control = metric_cells[key]
		cell.position = Vector2(x, 6) * u
		cell.size = Vector2(widths[index], 28) * u
		Compact.update_icon(metric_icons[key], ICONS[key])
		values[key].position = Vector2(28, 0) * u
		values[key].size = Vector2(widths[index]-28, 28) * u
		values[key].add_theme_font_size_override("font_size", roundi(12*u))
		x += widths[index]

func _process(_delta: float) -> void:
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_size() != last_window_size: _resize()
	if refresh_dirty:
		refresh_dirty = false
		_refresh()

func invalidate() -> void:
	refresh_dirty = true

func council_popup_position() -> Vector2:
	return technology_panel.position + Vector2(0, technology_panel.size.y + 8)

func _refresh() -> void:
	if main == null or GameSession.player_house.is_empty(): return
	refresh_count += 1
	var house_id: String = GameSession.player_house
	var house: Dictionary = main.governance_registry.houses.get(house_id, {})
	var ruler: Dictionary = house.get("ruler", {})
	var ruler_id: String = str(ruler.get("officer_id", ""))
	var full_house_name := str(house.get("display_name", house_id))
	house_label.text = full_house_name.get_slice("（", 0)
	ruler_label.text = str(ruler.get("name", "当主不明"))
	last_ruler_id = ruler_id
	panel.tooltip_text = full_house_name + "\n当主：" + ruler_label.text
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
