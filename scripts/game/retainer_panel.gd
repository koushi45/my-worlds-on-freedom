extends Control
## Role preview on the left; native portraits, ability icons, and wages on the right.

const UI = preload("res://scripts/game/council_panel_style.gd")
const DistrictStyle = preload("res://scripts/game/council_panel_style.gd")
const Portraits = preload("res://scripts/game/officer_portraits.gd")
const Compact = preload("res://scripts/game/compact_hud_style.gd")
const Rules = preload("res://scripts/game/retainer_management.gd")
const ROLE_NAMES := ["直臣", "侍大将", "軍師", "家老", "所司代"]
const ROLE_ICONS := {
	"直臣": "res://assets/ui/hud/role_retainer",
	"侍大将": "res://assets/ui/hud/role_commander",
	"軍師": "res://assets/ui/hud/role_strategist",
	"家老": "res://assets/ui/hud/role_elder",
	"所司代": "res://assets/ui/hud/role_deputy",
}
const ABILITIES := {
	"command": ["統率", "res://assets/ui/hud/ability_command"],
	"tactics": ["武勇", "res://assets/ui/hud/ability_tactics"],
	"strategy": ["知略", "res://assets/ui/hud/ability_strategy"],
	"politics": ["政治", "res://assets/ui/hud/ability_politics"],
	"trust": ["人望", "res://assets/ui/hud/ability_trust"],
}
signal closed

var main: Node
var selected_role := "直臣"
var selected_officer_id := ""
var role_buttons: Dictionary = {}
var officer_buttons: Dictionary = {}
var overview_values: Dictionary = {}
var ruler_values: Dictionary = {}
var ruler_name: Label
var ruler_abilities: HBoxContainer
var roster_rows: VBoxContainer
var wage_input: SpinBox
var appoint_button: Button
var wage_dialog: ConfirmationDialog
var columns: HBoxContainer
var left: VBoxContainer
var role_row: HBoxContainer
var roster_scroll: ScrollContainer
var role_title: Label
var role_summary: Label
var effect_value: Label
var loyalty_effect: Label
var preview_officer: Label
var stipend_delta: Label
var stipend_after: Label
var base_wage_hint: Label
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
	ruler_abilities = HBoxContainer.new()
	ruler_abilities.name = "RulerAbilities"
	ruler_abilities.add_theme_constant_override("separation", 8)
	body.add_child(ruler_abilities)
	ruler_name = UI.label("", ruler_abilities, 12)
	ruler_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ruler_name.clip_text = true
	ruler_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in ABILITIES:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = "大名の%s" % ABILITIES[key][0]
		ruler_abilities.add_child(cell)
		DistrictStyle.icon(cell, ABILITIES[key][1])
		var value := UI.label("", cell, 12)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ruler_values[key] = value
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation", 8)
	body.add_child(overview)
	for entry in [
		["prestige", "威信", "res://assets/ui/hud/hud_prestige"],
		["money", "金銭", "res://assets/ui/hud/hud_money"],
		["governance", "統治技術力", "res://assets/ui/hud/hud_governance"],
		["military", "軍事技術力", "res://assets/ui/hud/hud_military"],
		["diplomacy", "外交技術力", "res://assets/ui/hud/hud_diplomacy"],
	]:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		overview.add_child(cell)
		DistrictStyle.icon(cell, entry[2])
		var value := UI.label("", cell, 12)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.tooltip_text = entry[1]
		overview_values[entry[0]] = value
	columns = HBoxContainer.new()
	columns.name = "AppointmentColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	left = VBoxContainer.new()
	left.name = "RolePreview"
	columns.add_child(left)
	DistrictStyle.heading("役職を選ぶ", left, 14)
	role_row = HBoxContainer.new()
	left.add_child(role_row)
	var role_group := ButtonGroup.new()
	for role in ROLE_NAMES:
		var card := DistrictStyle.button("", role_row, _select_role.bind(role))
		card.name = "Role_%s" % role
		card.tooltip_text = role
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true
		card.button_group = role_group
		role_buttons[role] = card
		var contents := HBoxContainer.new()
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(contents)
		contents.alignment = BoxContainer.ALIGNMENT_CENTER
		DistrictStyle.icon(contents, ROLE_ICONS[role])
	role_title = UI.label("", left, 18)
	role_title.add_theme_color_override("font_color", DistrictStyle.GOLD)
	role_summary = UI.label("", left, 12)
	role_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	DistrictStyle.heading("任命時の効果", left, 14)
	effect_value = _preview_metric(left, "res://assets/ui/hud/effect_none")
	effect_value.name = "GrowthPreview"
	loyalty_effect = _preview_metric(left, "res://assets/ui/hud/metric_loyalty_bonus")
	preview_officer = UI.label("右の武将を選択してください。", left, 12)
	preview_officer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	DistrictStyle.heading("俸禄 / 月", left, 14)
	stipend_delta = _preview_metric(left, "res://assets/ui/hud/metric_stipend_delta")
	stipend_delta.name = "StipendDelta"
	stipend_after = UI.label("", left, 14)
	stipend_after.name = "StipendAfter"
	base_wage_hint = UI.label("", left, 12)
	base_wage_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(space)
	appoint_button = DistrictStyle.button("選択した役職に任命", left, _appoint)
	appoint_button.custom_minimum_size = Vector2(0, 34)
	var right := VBoxContainer.new()
	right.name = "OfficerRoster"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	DistrictStyle.heading("配下武将", right, 14)
	roster_scroll = ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	DistrictStyle.field(roster_scroll)
	right.add_child(roster_scroll)
	roster_rows = VBoxContainer.new()
	roster_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_rows.add_theme_constant_override("separation", 6)
	roster_scroll.add_child(roster_rows)
	wage_dialog = ConfirmationDialog.new()
	wage_dialog.title = "基礎俸禄を変更"
	wage_dialog.ok_button_text = "設定"
	wage_dialog.cancel_button_text = "戻る"
	wage_dialog.confirmed.connect(_set_wage)
	add_child(wage_dialog)
	wage_input = SpinBox.new()
	wage_input.min_value = 0.1
	wage_input.max_value = 10.0
	wage_input.step = 0.1
	wage_input.value = 0.1
	wage_input.custom_minimum_size.x = 90
	wage_dialog.add_child(wage_input)
	UI.field(wage_input)
	status = UI.label("左の役職と右の武将を選択してください。", body, 12)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.retainer_management.updated.connect(refresh)
	main.house_prestige.prestige_changed.connect(func(_house_id: String, _value: float, _reason: String): refresh())
	resized.connect(_resize_layout)
	get_viewport().size_changed.connect(_resize_layout)
	UI.follow_window(self)
	_resize_layout()
	hide()

func open() -> void:
	refresh()
	show()

func close_panel() -> void:
	wage_dialog.hide()
	hide()
	closed.emit()

func _preview_metric(parent: Control, stem: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	DistrictStyle.icon(row, stem)
	var value := UI.label("", row, 12)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return value

func _resize_layout() -> void:
	if columns == null: return
	var u := Compact.unit(self)
	columns.add_theme_constant_override("separation", roundi(16*u))
	left.custom_minimum_size.x = size.x * 0.36
	left.add_theme_constant_override("separation", roundi(7*u))
	role_row.add_theme_constant_override("separation", roundi(4*u))
	for button in role_buttons.values(): button.custom_minimum_size = Vector2(36, 36)*u
	appoint_button.custom_minimum_size = Vector2(0, 34)*u
	for row in officer_buttons.values():
		row.custom_minimum_size.y = 110*u
		var content: VBoxContainer = row.get_node("Contents")
		content.offset_left = 8*u
		content.offset_right = -8*u
		content.offset_top = 4*u
		content.offset_bottom = -4*u
		content.get_node("Identity/Portrait").custom_minimum_size = Vector2(42, 48)*u

func refresh() -> void:
	var house_id: String = GameSession.player_house
	if house_id.is_empty(): return
	var management: Node = main.retainer_management
	var progress: Dictionary = management.technology[house_id]
	var ruler_id: String = management.ruler_id(house_id)
	ruler_abilities.visible = main.officer_registry.lookup.has(ruler_id)
	if ruler_abilities.visible:
		var officer: Dictionary = main.officer_registry.lookup[ruler_id]
		ruler_name.text = "大名：%s" % officer.display_name
		ruler_name.tooltip_text = ruler_name.text
		for key in ABILITIES: ruler_values[key].text = _score_text(officer, key)
	var growth: Dictionary = management.monthly_growth(house_id)
	overview_values.prestige.text = "%.1f / 100" % main.house_prestige.value_for(house_id)
	overview_values.prestige.mouse_filter = Control.MOUSE_FILTER_STOP
	overview_values.prestige.tooltip_text = main.house_prestige.description_for(house_id)
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
		var summary: String = "%d 人" % counts[role] if counts.has(role) else incumbents[role]
		role_buttons[role].tooltip_text = "%s：%s" % [role, summary]
		role_buttons[role].set_pressed_no_signal(role == selected_role)
	role_summary.text = "%d 人" % counts[selected_role] if counts.has(selected_role) else incumbents.get(selected_role, "")
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
	_resize_layout()

func _add_officer_row(house_id: String, officer_id: String, group: ButtonGroup) -> void:
	var officer: Dictionary = main.officer_registry.lookup[officer_id]
	var management: Node = main.retainer_management
	var row := DistrictStyle.button("", roster_rows, _select_officer.bind(officer_id))
	row.name = "Officer_%s" % officer_id
	row.custom_minimum_size = Vector2(0, 110)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.toggle_mode = true
	row.button_group = group
	officer_buttons[officer_id] = row
	var content := VBoxContainer.new()
	content.name = "Contents"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_right = -8
	content.add_theme_constant_override("separation", 7)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	var top := HBoxContainer.new()
	top.name = "Identity"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(top)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(42, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = Portraits.texture_for(officer_id)
	if portrait.texture == null: portrait.texture = preload("res://assets/ui/hud/samurai.png")
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(identity)
	var name_label := UI.label(str(officer.display_name), identity, 12)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.label(management.role_of(house_id, officer_id), identity, 12).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom)
	var loyalty := VBoxContainer.new()
	loyalty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loyalty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loyalty.tooltip_text = "忠誠 / 必要忠誠"
	bottom.add_child(loyalty)
	DistrictStyle.icon(loyalty, "res://assets/ui/hud/metric_loyalty")
	var loyalty_value := UI.label("%d / %d" % [management.loyalty_for(house_id, officer_id), management.required_loyalty_for(officer_id)], loyalty, 12)
	loyalty_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loyalty_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loyalty_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scores: Dictionary = officer.get("assessment", {}).get("scores", {})
	for key in ["command", "tactics", "strategy", "politics", "trust"]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.tooltip_text = ABILITIES[key][0]
		bottom.add_child(cell)
		DistrictStyle.icon(cell, ABILITIES[key][1])
		var score: Variant = scores.get(key)
		var score_text := "―" if score == null else str(score)
		if score_text.ends_with(".0"): score_text = score_text.trim_suffix(".0")
		var value := UI.label(score_text, cell, 12)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stipend_button := DistrictStyle.button("", top, _open_wage.bind(officer_id))
	stipend_button.name = "StipendButton"
	stipend_button.custom_minimum_size = Vector2(92, 34)
	stipend_button.tooltip_text = "現在の月額俸禄（押すと基礎俸禄を変更）"
	var stipend_cell := HBoxContainer.new()
	stipend_cell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stipend_cell.alignment = BoxContainer.ALIGNMENT_CENTER
	stipend_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stipend_button.add_child(stipend_cell)
	DistrictStyle.icon(stipend_cell, "res://assets/ui/hud/metric_stipend")
	var stipend := UI.label("%.1f / 月" % management.stipend_for(house_id, officer_id), stipend_cell, 12)
	stipend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stipend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = "%s：%s／忠誠 %d、必要 %d／俸禄 %.1f / 月" % [officer.display_name, management.role_of(house_id, officer_id), management.loyalty_for(house_id, officer_id), management.required_loyalty_for(officer_id), management.stipend_for(house_id, officer_id)]

func _select_role(role: String) -> void:
	selected_role = role
	refresh()
	status.text = "%s：任命する武将を右から選んでください。" % role

func _score_text(officer: Dictionary, key: String) -> String:
	var score: Variant = officer.get("assessment", {}).get("scores", {}).get(key)
	return "―" if score == null else str(score).trim_suffix(".0")

func _select_officer(officer_id: String) -> void:
	selected_officer_id = officer_id
	for id in officer_buttons: officer_buttons[id].set_pressed_no_signal(id == officer_id)
	_update_actions()
	status.text = "%sを選択しました。" % main.officer_registry.lookup[officer_id].display_name

func _update_actions() -> void:
	appoint_button.disabled = selected_role.is_empty() or selected_officer_id.is_empty()
	_update_preview()

func _role_multiplier(role: String) -> float:
	return Rules.SENIOR_MULTIPLIER if role in Rules.SENIOR_ROLES else (Rules.SAMURAI_MULTIPLIER if role == "侍大将" else 1.0)

func _role_loyalty(role: String) -> int:
	return 10 if role in Rules.SENIOR_ROLES else (5 if role == "侍大将" else 0)

func _update_preview() -> void:
	role_title.text = selected_role
	appoint_button.text = "%sに任命" % selected_role
	var management: Node = main.retainer_management
	var field: String = {"軍師":"military", "家老":"governance", "所司代":"diplomacy"}.get(selected_role, "")
	var effect_icon: Control = effect_value.get_parent().get_child(0)
	var icon_stem: String = {"軍師":"effect_military", "家老":"effect_governance", "所司代":"effect_diplomacy"}.get(selected_role, "effect_none")
	effect_icon.set_meta("council_icon", icon_stem)
	Compact.update_icon(effect_icon.get_child(0), icon_stem)
	var selected := not selected_officer_id.is_empty()
	if field.is_empty():
		effect_value.text = "技術の月次成長への追加効果なし"
	elif not selected:
		effect_value.text = "%s：大名と武将の能力合計 × 0.75 / 月" % {"military":"軍事", "governance":"統治", "diplomacy":"外交"}[field]
	else:
		var house_id: String = GameSession.player_house
		var ruler: String = management.ruler_id(house_id)
		var ability: String = "politics" if field == "governance" else "strategy"
		var ruler_score: float = management._military(ruler) if field == "military" else management._score(ruler, ability)
		var officer_score: float = management._military(selected_officer_id) if field == "military" else management._score(selected_officer_id, ability)
		var after := (ruler_score + officer_score)*0.75
		var before: float = management.monthly_growth(house_id)[field]
		effect_value.text = "%s %.1f → %.1f / 月 (%+.1f)" % [{"military":"軍事", "governance":"統治", "diplomacy":"外交"}[field], before, after, after-before]
	loyalty_effect.text = "役職による忠誠 +%d" % _role_loyalty(selected_role)
	if not selected:
		preview_officer.text = "右の武将を選択してください。"
		stipend_delta.text = "基礎俸禄 × %.0f" % _role_multiplier(selected_role)
		stipend_after.text = "任命後 ― / 月"
		base_wage_hint.text = "武将を選択すると俸禄の増減を表示"
		return
	var house_id: String = GameSession.player_house
	var base: float = float(management.loyalty_state[selected_officer_id].base_wage_tenths)*Rules.BASE_STIPEND
	var current: float = management.stipend_for(house_id, selected_officer_id)
	var after: float = base*_role_multiplier(selected_role)
	preview_officer.text = "%s → %s" % [main.officer_registry.lookup[selected_officer_id].display_name, selected_role]
	stipend_delta.text = "増減 %+.1f / 月" % (after-current)
	stipend_after.text = "任命後 %.1f / 月" % after
	base_wage_hint.text = "基礎 %.1f × %.0f（一覧の金額から変更）" % [base, _role_multiplier(selected_role)]
	var occupied := false
	if selected_role in Rules.SENIOR_ROLES:
		for id in management.house_members[house_id]:
			if id != selected_officer_id and management.role_of(house_id, id) == selected_role: occupied = true
	appoint_button.disabled = occupied or management.role_of(house_id, selected_officer_id) == selected_role
	appoint_button.tooltip_text = "既に任命済みです。先に直臣へ戻してください。" if occupied else ""

func _open_wage(officer_id: String) -> void:
	_select_officer(officer_id)
	wage_input.value = float(main.retainer_management.loyalty_state[officer_id].base_wage_tenths)*Rules.BASE_STIPEND
	wage_dialog.title = "%s：基礎俸禄 / 月" % main.officer_registry.lookup[officer_id].display_name
	wage_dialog.popup_centered(Vector2i(320, 130))

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
