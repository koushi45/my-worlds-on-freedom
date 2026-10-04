extends Control
## Select a role first, then choose an officer with a portrait and ability scores.

const UI = preload("res://scripts/game/council_panel_style.gd")
const DistrictStyle = preload("res://scripts/game/council_panel_style.gd")
const Portraits = preload("res://scripts/game/officer_portraits.gd")
const ROLE_NAMES := ["直臣", "侍大将", "軍師", "家老", "所司代"]
const ROLE_ICONS := {
	"直臣": "res://assets/ui/district/house",
	"侍大将": "res://assets/ui/hud/military",
	"軍師": "res://assets/ui/hud/diplomacy",
	"家老": "res://assets/ui/hud/governance",
	"所司代": "res://assets/ui/hud/castle",
}
const ABILITIES := {
	"command": ["統率", "res://assets/ui/hud/military"],
	"tactics": ["武勇", "res://assets/ui/hud/spears"],
	"strategy": ["知略", "res://assets/ui/hud/diplomacy"],
	"politics": ["政治", "res://assets/ui/hud/governance"],
	"trust": ["人望", "res://assets/ui/hud/fan"],
}
signal closed

var main: Node
var selected_role := ""
var selected_officer_id := ""
var role_buttons: Dictionary = {}
var role_values: Dictionary = {}
var officer_buttons: Dictionary = {}
var overview_values: Dictionary = {}
var roster_rows: VBoxContainer
var wage_input: SpinBox
var appoint_button: Button
var wage_button: Button
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Control.new()
	panel.name = "RetainerWindow"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	DistrictStyle.heading("役職・家臣管理", header, 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation", 8)
	body.add_child(overview)
	for entry in [
		["prestige", "威信", "res://assets/ui/hud/fan"],
		["money", "金銭", "res://assets/ui/hud/koban"],
		["governance", "統治", "res://assets/ui/hud/governance"],
		["military", "軍事", "res://assets/ui/hud/military"],
		["diplomacy", "外交", "res://assets/ui/hud/diplomacy"],
	]:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		overview.add_child(cell)
		DistrictStyle.icon(cell, entry[2])
		var value := UI.label("", cell, 12)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.tooltip_text = entry[1]
		overview_values[entry[0]] = value
	DistrictStyle.heading("役職を選ぶ", body, 14)
	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 8)
	body.add_child(role_row)
	var role_group := ButtonGroup.new()
	for role in ROLE_NAMES:
		var card := DistrictStyle.button("", role_row, _select_role.bind(role))
		card.name = "Role_%s" % role
		card.custom_minimum_size = Vector2(0, 52)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true
		card.button_group = role_group
		role_buttons[role] = card
		var contents := HBoxContainer.new()
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 8
		contents.offset_right = -8
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(contents)
		DistrictStyle.icon(contents, ROLE_ICONS[role])
		var labels := VBoxContainer.new()
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contents.add_child(labels)
		var name_label := UI.label(role, labels, 12)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var value_label := UI.label("", labels, 12)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.clip_text = true
		role_values[role] = value_label
	DistrictStyle.heading("配下武将を選ぶ", body, 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 195
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	DistrictStyle.field(scroll)
	body.add_child(scroll)
	roster_rows = VBoxContainer.new()
	roster_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(roster_rows)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	appoint_button = DistrictStyle.button("選択した役職に任命", actions, _appoint)
	appoint_button.custom_minimum_size = Vector2(180, 34)
	var wage_label := UI.label("基礎俸禄", actions, 12)
	wage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wage_input = SpinBox.new()
	wage_input.min_value = 0.1
	wage_input.max_value = 10.0
	wage_input.step = 0.1
	wage_input.value = 0.1
	wage_input.custom_minimum_size.x = 90
	actions.add_child(wage_input)
	UI.field(wage_input)
	wage_button = DistrictStyle.button("俸禄を設定", actions, _set_wage)
	wage_button.custom_minimum_size = Vector2(110, 34)
	status = UI.label("上の役職と下の武将を選択してください。", body, 12)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.retainer_management.updated.connect(refresh)
	main.house_prestige.prestige_changed.connect(func(_house_id: String, _value: int, _reason: String): refresh())
	get_window().size_changed.connect(refresh)
	UI.follow_window(self)
	hide()

func open() -> void:
	refresh()
	show()

func close_panel() -> void:
	hide()
	closed.emit()

func refresh() -> void:
	var house_id: String = GameSession.player_house
	if house_id.is_empty(): return
	var management: Node = main.retainer_management
	var progress: Dictionary = management.technology[house_id]
	var growth: Dictionary = management.monthly_growth(house_id)
	overview_values.prestige.text = "%d / 100" % main.house_prestige.value_for(house_id)
	overview_values.money.text = "%.1f" % float(main.district_economy.house_resources[house_id].money)
	for key in ["governance", "military", "diplomacy"]:
		overview_values[key].text = "%.1f" % float(progress[key])
		overview_values[key].tooltip_text = "%s：+%.1f / 月" % [key, float(growth[key])]
	var counts := {"直臣": 0, "侍大将": 0}
	var incumbents := {"軍師": "未任命", "家老": "未任命", "所司代": "未任命"}
	for officer_id in management.house_members[house_id]:
		var role: String = management.role_of(house_id, officer_id)
		if counts.has(role): counts[role] += 1
		elif incumbents.has(role): incumbents[role] = str(main.officer_registry.lookup[officer_id].display_name)
	for role in ROLE_NAMES:
		role_values[role].text = "%d 人" % counts[role] if counts.has(role) else incumbents[role]
		role_buttons[role].set_pressed_no_signal(role == selected_role)
	for child in roster_rows.get_children():
		roster_rows.remove_child(child)
		child.queue_free()
	officer_buttons.clear()
	var officer_group := ButtonGroup.new()
	for officer_id in management.house_members[house_id]:
		_add_officer_row(house_id, officer_id, officer_group)
	if not selected_officer_id.is_empty() and not officer_buttons.has(selected_officer_id): selected_officer_id = ""
	if officer_buttons.has(selected_officer_id): officer_buttons[selected_officer_id].set_pressed_no_signal(true)
	_update_actions()

func _add_officer_row(house_id: String, officer_id: String, group: ButtonGroup) -> void:
	var officer: Dictionary = main.officer_registry.lookup[officer_id]
	var management: Node = main.retainer_management
	var row := DistrictStyle.button("", roster_rows, _select_officer.bind(officer_id))
	row.name = "Officer_%s" % officer_id
	row.custom_minimum_size = Vector2(0, 72)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.toggle_mode = true
	row.button_group = group
	officer_buttons[officer_id] = row
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_right = -8
	content.add_theme_constant_override("separation", 7)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(52, 60)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = Portraits.texture_for(officer_id)
	if portrait.texture == null: portrait.texture = preload("res://assets/ui/hud/samurai.png")
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 136
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(identity)
	var name_label := UI.label(str(officer.display_name), identity, 12)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.label(management.role_of(house_id, officer_id), identity, 12).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loyalty := HBoxContainer.new()
	loyalty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loyalty.tooltip_text = "忠誠 / 必要忠誠"
	identity.add_child(loyalty)
	DistrictStyle.icon(loyalty, "res://assets/ui/hud/fan")
	var loyalty_value := UI.label("%d / %d" % [management.loyalty_for(house_id, officer_id), management.required_loyalty_for(officer_id)], loyalty, 12)
	loyalty_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loyalty_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scores: Dictionary = officer.get("assessment", {}).get("scores", {})
	for key in ["command", "tactics", "strategy", "politics", "trust"]:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 46
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.tooltip_text = ABILITIES[key][0]
		content.add_child(cell)
		DistrictStyle.icon(cell, ABILITIES[key][1])
		var score: Variant = scores.get(key)
		var score_text := "―" if score == null else str(score)
		if score_text.ends_with(".0"): score_text = score_text.trim_suffix(".0")
		var value := UI.label(score_text, cell, 12)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stipend_cell := HBoxContainer.new()
	stipend_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stipend_cell.tooltip_text = "月額俸禄"
	content.add_child(stipend_cell)
	DistrictStyle.icon(stipend_cell, "res://assets/ui/hud/koban")
	var stipend := UI.label("%.1f / 月" % management.stipend_for(house_id, officer_id), stipend_cell, 12)
	stipend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stipend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = "%s：%s／忠誠 %d、必要 %d／俸禄 %.1f / 月" % [officer.display_name, management.role_of(house_id, officer_id), management.loyalty_for(house_id, officer_id), management.required_loyalty_for(officer_id), management.stipend_for(house_id, officer_id)]

func _select_role(role: String) -> void:
	selected_role = role
	_update_actions()
	status.text = "%s：任命する武将を下から選んでください。" % role

func _select_officer(officer_id: String) -> void:
	selected_officer_id = officer_id
	wage_input.value = float(main.retainer_management.loyalty_state[officer_id].base_wage_tenths) * 0.1
	_update_actions()
	status.text = "%sを選択しました。" % main.officer_registry.lookup[officer_id].display_name

func _update_actions() -> void:
	appoint_button.disabled = selected_role.is_empty() or selected_officer_id.is_empty()
	wage_button.disabled = selected_officer_id.is_empty()

func _appoint() -> void:
	if selected_role.is_empty() or selected_officer_id.is_empty(): return
	var result: Error = main.retainer_management.assign_role(GameSession.player_house, selected_officer_id, selected_role)
	if result == ERR_ALREADY_EXISTS: status.text = "この役職には既に任命されています。先に解任してください。"
	elif result != OK: status.text = "任命できません。"
	else: status.text = "%sを%sに任命しました。" % [main.officer_registry.lookup[selected_officer_id].display_name, selected_role]

func _set_wage() -> void:
	if selected_officer_id.is_empty(): return
	var result: Error = main.retainer_management.set_base_stipend(GameSession.player_house, selected_officer_id, wage_input.value)
	status.text = "俸禄を設定しました。" if result == OK else "俸禄を設定できません。"
