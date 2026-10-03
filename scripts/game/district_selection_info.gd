extends CanvasLayer
## Values appear once; editable values are the controls that open their actions.

const UI = preload("res://scripts/game/menu_style.gd")
const IconHintPopup = preload("res://scripts/game/icon_hint_popup.gd")
const ICON_DIRECTORY := "res://assets/ui/district/"
const ICON_LABELS := {
	"house": "支配家", "governor": "郡代", "people": "人口",
	"rice": "兵糧収入", "coin": "金銭収入", "levy": "出陣可能人数",
	"security": "治安", "disaster": "災害による荒廃度",
	"autonomy": "自治率", "defense": "郡の防御レベル",
	"infrastructure": "インフラレベル",
}

var main: Node
var district_id := ""
var panel: Control
var name_label: Button
var security_label: Label # Hidden compatibility readout for older menu checks.
var copy_status: Label
var crest_rect: TextureRect
var details_rows: VBoxContainer
var facilities_rows: VBoxContainer
var building_dialog: AcceptDialog
var building_rows: VBoxContainer
var governor_dialog: ConfirmationDialog
var governor_choice: OptionButton
var governor_ids: Array[String] = []
var building_confirmation: ConfirmationDialog
var pending_building_id := ""
var pending_cancel := false
var icon_scale := 1.0
var info_icon_size := 64
var grid_icon_size := 128
var icon_cache: Dictionary = {}
var icon_hint

func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_icon_sizes()
	get_window().size_changed.connect(_on_window_resized)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	panel = Control.new()
	panel.name = "DistrictNameWindow"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -510
	panel.offset_top = -310
	panel.offset_right = 510
	panel.offset_bottom = 310
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(panel)
	var frame := NinePatchRect.new()
	frame.texture = preload("res://assets/ui/hud/frame_256.png")
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.patch_margin_left = 52
	frame.patch_margin_top = 52
	frame.patch_margin_right = 52
	frame.patch_margin_bottom = 52
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	panel.add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 24
	columns.offset_top = 35
	columns.offset_right = -24
	columns.offset_bottom = -35
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(475, 550)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 450
	left.add_theme_constant_override("separation", 9)
	left_scroll.add_child(left)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	left.add_child(header)
	crest_rect = TextureRect.new()
	crest_rect.custom_minimum_size = Vector2(64, 64)
	crest_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	crest_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	crest_rect.modulate = Color("#d7ad64")
	header.add_child(crest_rect)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	_heading("郡の記録", title_stack)
	name_label = Button.new()
	name_label.name = "DistrictNameCopyButton"
	name_label.flat = true
	name_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color("#f4e8cd"))
	name_label.tooltip_text = ""
	name_label.pressed.connect(_copy_name)
	title_stack.add_child(name_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = ""
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.pressed.connect(hide_info)
	header.add_child(close_button)
	security_label = Label.new()
	security_label.hide()
	left.add_child(security_label)
	copy_status = UI.label("", left, 12)
	copy_status.hide()
	details_rows = VBoxContainer.new()
	details_rows.add_theme_constant_override("separation", 7)
	left.add_child(details_rows)
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(475, 550)
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_scroll)
	facilities_rows = VBoxContainer.new()
	facilities_rows.custom_minimum_size.x = 450
	facilities_rows.add_theme_constant_override("separation", 10)
	right_scroll.add_child(facilities_rows)
	building_dialog = AcceptDialog.new()
	building_dialog.title = "建造物を選ぶ"
	building_dialog.min_size = Vector2i(560, 520)
	add_child(building_dialog)
	var building_scroll := ScrollContainer.new()
	building_scroll.custom_minimum_size = Vector2(540, 440)
	building_dialog.add_child(building_scroll)
	building_rows = VBoxContainer.new()
	building_rows.custom_minimum_size.x = 510
	building_rows.add_theme_constant_override("separation", 8)
	building_scroll.add_child(building_rows)
	governor_dialog = ConfirmationDialog.new()
	governor_dialog.title = "郡代を任命"
	governor_dialog.min_size = Vector2i(310, 150)
	governor_dialog.confirmed.connect(_set_governor)
	add_child(governor_dialog)
	governor_dialog.get_ok_button().text = "任命"
	governor_dialog.get_cancel_button().text = "戻る"
	governor_choice = OptionButton.new()
	governor_choice.custom_minimum_size = Vector2(270, 38)
	governor_dialog.add_child(governor_choice)
	building_confirmation = ConfirmationDialog.new()
	building_confirmation.confirmed.connect(_confirm_building_action)
	add_child(building_confirmation)
	building_confirmation.get_ok_button().text = "実行"
	building_confirmation.get_cancel_button().text = "戻る"
	icon_hint = IconHintPopup.new()
	root_control.add_child(icon_hint)
	icon_hint.bind_icon(name_label, "郡名をコピー")
	icon_hint.bind_icon(close_button, "郡の記録を閉じる")
	panel.hide()

func show_district(district_name: String, security: int = -1) -> void:
	name_label.text = district_name
	security_label.text = "治安：%d / 100" % security if security >= 0 else ""
	copy_status.hide()
	panel.show()

func set_district(value: String) -> void:
	district_id = value
	_refresh_full()
	if main != null and main.map_view != null: main.map_view.markers.invalidate()

func hide_info() -> void:
	district_id = ""
	icon_hint.clear()
	building_dialog.hide()
	governor_dialog.hide()
	building_confirmation.hide()
	panel.hide()
	if main != null and main.map_view != null: main.map_view.markers.invalidate()

func _clear_rows(target: VBoxContainer) -> void:
	icon_hint.clear()
	for child in target.get_children():
		target.remove_child(child)
		child.queue_free()

func _heading(title: String, parent: VBoxContainer) -> void:
	var label := UI.label("━━  ◆ " + title + "  ━━", parent, 19)
	label.add_theme_color_override("font_color", Color("#d7ad64"))

func _update_icon_sizes() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size) if DisplayServer.get_name() != "headless" else viewport_size
	icon_scale = maxf(0.1, window_size.x / maxf(1.0, viewport_size.x))
	info_icon_size = 256 if window_size.y >= 3600 else (192 if window_size.y >= 2700 else (128 if window_size.y >= 1800 else (96 if window_size.y >= 1200 else 64)))
	grid_icon_size = 256 if window_size.y >= 2700 else (192 if window_size.y >= 1800 else (128 if window_size.y >= 900 else (96 if window_size.y >= 600 else 64)))

func _on_window_resized() -> void:
	_update_icon_sizes()
	if panel.visible: _refresh_full.call_deferred()
	if building_dialog.visible: _refresh_buildings.call_deferred()

func _icon_texture(name: String, pixels: int) -> Texture2D:
	var key := "%s_%d" % [name, pixels]
	if not icon_cache.has(key): icon_cache[key] = load(ICON_DIRECTORY + key + ".png")
	return icon_cache[key]

func _icon(name: String, pixels: int = 0, label: String = "") -> Control:
	if pixels == 0: pixels = info_icon_size
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(pixels, pixels) / icon_scale
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var picture := TextureRect.new()
	picture.texture = _icon_texture(name, pixels)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP
	picture.size = Vector2(pixels, pixels)
	picture.scale = Vector2.ONE / icon_scale
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	icon_hint.bind_icon(holder, label if not label.is_empty() else str(ICON_LABELS.get(name, name)))
	return holder

func _icon_button(name: String, pixels: int, action: Callable, hint: String, enabled: bool = true) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(pixels, pixels) / icon_scale
	var button := TextureButton.new()
	button.texture_normal = _icon_texture(name, pixels)
	button.texture_hover = button.texture_normal
	button.texture_disabled = button.texture_normal
	button.size = Vector2(pixels, pixels)
	button.scale = Vector2.ONE / icon_scale
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.disabled = not enabled
	icon_hint.bind_action_icon(button, hint, action)
	holder.add_child(button)
	return holder

func _info_grid(title: String) -> GridContainer:
	_heading(title, details_rows)
	var grid := GridContainer.new()
	grid.name = "InfoGrid_" + title
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 7)
	details_rows.add_child(grid)
	return grid

func _info_row(group: GridContainer, icon_name: String, value: String, action: Callable = Callable(), enabled: bool = true, hint: String = "") -> void:
	var tile := PanelContainer.new()
	tile.name = "Info_" + icon_name
	tile.custom_minimum_size.x = 216
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tile_style := StyleBoxFlat.new()
	tile_style.bg_color = Color("#152238dc")
	tile_style.border_color = Color("#9c8050")
	tile_style.set_border_width_all(1)
	tile_style.set_corner_radius_all(3)
	tile_style.set_content_margin_all(4)
	tile.add_theme_stylebox_override("panel", tile_style)
	group.add_child(tile)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	tile.add_child(row)
	var icon := _icon(icon_name)
	row.add_child(icon)
	var label_text := str(ICON_LABELS.get(icon_name, icon_name))
	var description := "%s：%s" % [label_text, value]
	if not hint.is_empty() and hint != label_text: description += "\n" + hint
	if action.is_valid():
		var button := Button.new()
		button.text = value
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 15)
		button.disabled = not enabled
		icon_hint.bind_icon(button, description)
		button.pressed.connect(action)
		row.add_child(button)
	else:
		var label := UI.label(value, row, 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_hint.bind_icon(label, description)

func _refresh_full() -> void:
	if district_id.is_empty() or main == null or not main.governance_registry.districts.has(district_id): return
	_clear_rows(details_rows)
	_clear_rows(facilities_rows)
	var record: Dictionary = main.governance_registry.districts[district_id]
	var own: bool = record.house_id == GameSession.player_house
	var actions: Node = main.district_actions
	var resources: Dictionary = main.district_economy.house_resources.get(GameSession.player_house, {"money":0,"provisions":0})
	var crest_entry: Dictionary = main.kamon_layer.kamon_by_house.get(record.house_id, {})
	var crest_asset: String = str(crest_entry.get("asset", ""))
	crest_rect.texture = main.kamon_layer.kamon_textures.get(crest_asset)
	crest_rect.visible = crest_rect.texture != null
	var governance_grid := _info_grid("支配と統治")
	_info_row(governance_grid, "house", main.governance_registry.house_name(record))
	_info_row(governance_grid, "governor", main.governance_registry.governor_name(record), _open_governor_dialog if own else Callable(), true, "郡代を変更" if own else "")
	var placed: Array[String] = main.retainer_management.officers_in_district(record.house_id, district_id)
	var placement_row := HBoxContainer.new()
	placement_row.add_theme_constant_override("separation", 10)
	details_rows.add_child(placement_row)
	UI.label("出陣武将", placement_row, 15)
	if own:
		var placement_button := Button.new()
		placement_button.text = "%d人 配置中" % placed.size()
		placement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		placement_button.pressed.connect(_open_placement)
		placement_row.add_child(placement_button)
	else:
		UI.label("%d人" % placed.size(), placement_row, 15)
	var income_grid := _info_grid("郡の収入")
	_info_row(income_grid, "rice", "%d / 年（九月）" % main.district_economy.income_for(record, "agriculture"))
	_info_row(income_grid, "coin", "%d / 月" % main.district_economy.income_for(record, "commerce"))
	var people_grid := _info_grid("人口と治安")
	_info_row(people_grid, "people", "%d 人" % int(record.population))
	var available: int = actions.sortie_available(record)
	_info_row(people_grid, "levy", "%d 人" % available, _open_sortie if own else Callable(), available >= 100, "この郡から出陣できる人数。出陣すると減り、帰還・毎月の回復で増えます。")
	_info_row(people_grid, "security", "%d / 100" % main.technology_tree.security_for(record))
	_info_row(people_grid, "disaster", "%d / 100" % int(record.devastation), _repair if own else Callable(), int(record.devastation) > 0 and float(resources.money) >= actions.repair_cost(record), "荒廃を補修：金銭%d" % actions.repair_cost(record))
	_info_row(people_grid, "autonomy", "%d%%" % int(record.autonomy))
	_info_row(people_grid, "defense", "%d" % (int(record.defense) + main.district_buildings.defense_bonus(district_id)))
	_heading("建造物とインフラ", facilities_rows)
	var infra_row := HBoxContainer.new()
	infra_row.add_theme_constant_override("separation", 10)
	facilities_rows.add_child(infra_row)
	infra_row.add_child(_icon("infrastructure"))
	var infra_label := UI.label("インフラ %d / 10" % int(record.infrastructure), infra_row, 17)
	infra_label.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_hint.bind_icon(infra_label, "インフラレベル：%d / 10" % int(record.infrastructure))
	if own:
		var hint := "インフラ上昇：金銭%d・収入+5%%・防御+1" % actions.upgrade_cost(record)
		var enabled: bool = int(record.infrastructure) < 10 and float(resources.money) >= actions.upgrade_cost(record)
		infra_row.add_child(_icon_button("plus", info_icon_size, _upgrade, hint, enabled))
	var buildings: Node = main.district_buildings
	var entry: Dictionary = buildings.state[district_id]
	var office: Dictionary = main.district_office_layer.records.get(district_id, {})
	var office_text := "郡奉行所：未配置" if office.is_empty() else "郡奉行所：" + str(office.basis)
	if not office.is_empty() and main.army_campaign != null:
		office_text += "　防御 %d" % int(main.army_campaign.office_defenses.get(district_id, 0))
		var occupier: String = main.army_campaign.occupying_house(district_id)
		if not occupier.is_empty(): office_text += "　占領中"
	var office_label := UI.label(office_text, facilities_rows, 13)
	office_label.custom_minimum_size.x = 420
	office_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not office.is_empty():
		office_label.mouse_filter = Control.MOUSE_FILTER_STOP
		var detail := "%s\n標高 約%d m・傾斜 約%.1f°\n郡境に接しないタイルを選定。奉行所の実在は未確認。" % [office.basis, roundi(float(office.elevation_m)), float(office.slope_degrees)]
		if office.reference is Dictionary: detail += "\n出典：" + str(office.reference.source_title)
		icon_hint.bind_icon(office_label, detail)
	var slots_label := UI.label("建築枠　%d / %d" % [buildings.slots_used(district_id), buildings.slot_capacity(record)], facilities_rows, 15)
	slots_label.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_hint.bind_icon(slots_label, "建築枠：%d / %d" % [buildings.slots_used(district_id), buildings.slot_capacity(record)])
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	facilities_rows.add_child(grid)
	var existing: Array = buildings.existing_facilities(district_id)
	for site_id in existing: _add_historical_slot(grid, main.governance_registry.sites[site_id])
	for index in buildings.slot_capacity(record) - existing.size():
		var building_id := ""
		var is_construction := false
		if index < entry.built.size(): building_id = str(entry.built[index])
		elif index == entry.built.size() and entry.construction != null:
			building_id = str(entry.construction.building_id)
			is_construction = true
		_add_building_slot(grid, building_id, is_construction, own)
	if own:
		var resources_label := UI.label("家の金銭 %.1f　兵糧 %d" % [float(resources.money), int(resources.provisions)], facilities_rows, 13)
		resources_label.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_hint.bind_icon(resources_label, resources_label.text)

func _add_historical_slot(grid: GridContainer, site: Dictionary) -> void:
	var tile := VBoxContainer.new()
	tile.name = "Historical_" + str(site.id)
	tile.custom_minimum_size = Vector2(96, grid_icon_size / icon_scale)
	grid.add_child(tile)
	var roles: Array = site.roles
	var kind := "城・港" if "castle" in roles and "port" in roles else ("城" if "castle" in roles else "港")
	var kind_label := UI.label(kind, tile, 17)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var label := UI.label(str(site.name), tile, 13)
	label.custom_minimum_size.x = 96
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owner_label := UI.label(main.governance_registry.house_name(site), tile, 12)
	owner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var details := "%s（%s）\n支配家：%s" % [site.name, kind, main.governance_registry.house_name(site)]
	if site.get("governor") is Dictionary: details += "\n担当：" + str(site.governor.get("name", "—"))
	if "castle" in roles and main.army_campaign != null: details += "\n守備兵：%d人" % int(main.army_campaign.garrisons.get(site.id, 0))
	for control in [tile, kind_label, label, owner_label]:
		control.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_hint.bind_icon(control, details)

func _add_building_slot(grid: GridContainer, building_id: String, construction: bool, own: bool) -> void:
	var tile := VBoxContainer.new()
	tile.custom_minimum_size.x = 96
	grid.add_child(tile)
	var icon_name := "plus" if building_id.is_empty() else ("construction" if construction else building_id)
	var caption := "空き枠" if building_id.is_empty() else str(main.district_buildings.DEFINITIONS[building_id].name)
	if construction: caption = "工事中"
	if own:
		var hint := "建築物を選ぶ" if building_id.is_empty() else ("工事を取り消す" if construction else "%sを解体" % caption)
		tile.add_child(_icon_button(icon_name, grid_icon_size, _slot_pressed.bind(building_id, construction), hint))
	else:
		tile.add_child(_icon(icon_name, grid_icon_size, caption))
	var label := UI.label(caption, tile, 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	icon_hint.bind_icon(label, caption)

func _slot_pressed(building_id: String, construction: bool) -> void:
	if building_id.is_empty():
		_open_buildings()
		return
	pending_building_id = building_id
	pending_cancel = construction
	building_confirmation.dialog_text = "%sを取り消しますか？" % main.district_buildings.DEFINITIONS[building_id].name if construction else "%sを解体しますか？" % main.district_buildings.DEFINITIONS[building_id].name
	building_confirmation.popup_centered()

func _confirm_building_action() -> void:
	if pending_cancel: _cancel_building()
	else: _demolish(pending_building_id)
	pending_building_id = ""

func _open_governor_dialog() -> void:
	if district_id.is_empty(): return
	var record: Dictionary = main.governance_registry.districts[district_id]
	if record.house_id != GameSession.player_house: return
	governor_choice.clear()
	governor_ids.clear()
	var current: String = str(record.governor.get("officer_id", "")) if record.governor is Dictionary else ""
	for officer_id in main.retainer_management.house_members.get(GameSession.player_house, []):
		if main.retainer_management.role_of(GameSession.player_house, officer_id) == "直臣": continue
		governor_choice.add_item(main.officer_registry.lookup[officer_id].display_name)
		governor_ids.append(officer_id)
		if officer_id == current: governor_choice.select(governor_ids.size() - 1)
	if governor_ids.is_empty():
		governor_dialog.dialog_text = "任命できる家臣がいません。家臣画面で侍大将以上に任命してください。"
		governor_dialog.get_ok_button().disabled = true
		governor_choice.hide()
	else:
		governor_dialog.dialog_text = ""
		governor_dialog.get_ok_button().disabled = false
		governor_choice.show()
	governor_dialog.popup_centered()

func _set_governor() -> void:
	if governor_choice.selected < 0 or governor_choice.selected >= governor_ids.size(): return
	main.retainer_management.appoint_district_governor(GameSession.player_house, governor_ids[governor_choice.selected], district_id)
	_refresh_full.call_deferred()

func _open_buildings() -> void:
	if district_id.is_empty() or main.governance_registry.districts[district_id].house_id != GameSession.player_house: return
	_refresh_buildings()
	building_dialog.popup_centered()

func _refresh_buildings() -> void:
	if district_id.is_empty() or main == null: return
	_clear_rows(building_rows)
	var buildings: Node = main.district_buildings
	var record: Dictionary = main.governance_registry.districts[district_id]
	UI.label("%s　空き枠に建てる施設" % record.name, building_rows, 18)
	for building_id in buildings.DEFINITIONS:
		var definition: Dictionary = buildings.DEFINITIONS[building_id]
		var reason: String = buildings.reason_for(district_id, building_id, GameSession.player_house)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		building_rows.add_child(row)
		row.add_child(_icon(building_id, 0, str(definition.name)))
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var button := UI.button("%s　金銭%d・%dか月" % [definition.name, buildings.cost_for(district_id, building_id), definition.months], details, _build.bind(building_id))
		icon_hint.bind_icon(button, "%s：%s" % [definition.name, definition.effect if reason.is_empty() else reason])
		button.disabled = not reason.is_empty()
		var effect := str(definition.effect)
		if building_id in ["irrigation", "farm_estate", "market", "workshop", "temple"]:
			var kind := "agriculture" if building_id in ["irrigation", "farm_estate"] else "commerce"
			effect += "　%d → %d" % [main.district_economy.income_for(record, kind), main.district_economy.income_for(record, kind, building_id)]
		UI.label(effect if reason.is_empty() else effect + "　（%s）" % reason, details, 13)

func _build(building_id: String) -> void:
	var clock: Node = main.game_clock
	if main.district_buildings.start_construction(district_id, building_id, GameSession.player_house, clock.year, clock.month, clock.day) == OK:
		building_dialog.hide()
		_refresh_full.call_deferred()

func _demolish(building_id: String) -> void:
	main.district_buildings.demolish(district_id, building_id, GameSession.player_house)
	_refresh_full.call_deferred()

func _cancel_building() -> void:
	main.district_buildings.cancel_construction(district_id, GameSession.player_house)
	_refresh_full.call_deferred()

func _upgrade() -> void:
	main.district_actions.upgrade(district_id, GameSession.player_house)
	_refresh_full.call_deferred()

func _open_sortie() -> void:
	main.army_panel.show_district(district_id)
	hide_info()

func _open_placement() -> void:
	main.army_panel.show_placement(district_id)
	hide_info()

func _repair() -> void:
	main.district_actions.repair(district_id, GameSession.player_house)
	_refresh_full.call_deferred()

func refresh_if_open() -> void:
	if panel.visible and not district_id.is_empty(): _refresh_full.call_deferred()
	if building_dialog.visible and not district_id.is_empty(): _refresh_buildings.call_deferred()

func _copy_name() -> void:
	if name_label.text.is_empty(): return
	DisplayServer.clipboard_set(name_label.text)
	copy_status.text = "「%s」をコピーしました" % name_label.text
	copy_status.show()
