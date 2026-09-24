extends AcceptDialog
## Player-house role tree and appointment editor.

const UI = preload("res://scripts/game/menu_style.gd")
const ROLE_NAMES := ["直臣", "侍大将", "軍師", "家老", "所司代"]
var main: Node
var tree: RichTextLabel
var roster: ItemList
var role_choice: OptionButton
var wage_input: SpinBox
var district_choice: OptionButton
var province_choice: OptionButton
var summary: Label
var status: Label
var member_ids: Array = []
var district_ids: Array = []
var province_names: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "役職ツリー・配下管理"
	ok_button_text = "閉じる"
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(850, 550)
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	summary = UI.label("", body, 17)
	tree = RichTextLabel.new()
	tree.custom_minimum_size = Vector2(810, 125)
	tree.fit_content = false
	tree.scroll_active = true
	body.add_child(tree)
	UI.label("配下一覧（武将を選択して役職を変更）", body, 18)
	roster = ItemList.new()
	roster.custom_minimum_size = Vector2(810, 180)
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster.item_selected.connect(_select_member)
	body.add_child(roster)
	var row := HBoxContainer.new()
	body.add_child(row)
	role_choice = OptionButton.new()
	for role in ROLE_NAMES: role_choice.add_item(role)
	row.add_child(role_choice)
	UI.button("任命する", row, _appoint).custom_minimum_size = Vector2(160, 40)
	UI.label("基礎俸禄", row, 16)
	wage_input = SpinBox.new()
	wage_input.min_value = 0.1
	wage_input.max_value = 10.0
	wage_input.step = 0.1
	wage_input.value = 0.1
	row.add_child(wage_input)
	UI.button("俸禄を設定", row, _set_wage).custom_minimum_size = Vector2(160, 40)
	var governor_row := HBoxContainer.new()
	body.add_child(governor_row)
	district_choice = OptionButton.new()
	district_choice.custom_minimum_size.x = 210
	governor_row.add_child(district_choice)
	UI.button("郡代に任命", governor_row, _appoint_district).custom_minimum_size = Vector2(155, 40)
	province_choice = OptionButton.new()
	province_choice.custom_minimum_size.x = 210
	governor_row.add_child(province_choice)
	UI.button("国代に任命", governor_row, _appoint_province).custom_minimum_size = Vector2(155, 40)
	status = UI.label("", body, 15)
	main.retainer_management.updated.connect(refresh)
	main.house_prestige.prestige_changed.connect(func(_house_id: String, _value: int, _reason: String): refresh())

func open() -> void:
	refresh()
	popup_centered(Vector2i(900, 640))

func refresh() -> void:
	var house_id: String = GameSession.player_house
	if house_id.is_empty(): return
	var management: Node = main.retainer_management
	var house: Dictionary = main.governance_registry.houses[house_id]
	var ruler_name := str(house.ruler.get("name", "当主未詳")) if house.ruler is Dictionary else "当主未詳"
	var growth: Dictionary = management.monthly_growth(house_id)
	var progress: Dictionary = management.technology[house_id]
	summary.text = "%s　威信 %d/100　俸禄 %.1f/月　金銭 %.1f\n技術：統治 %.1f (+%.1f/月)　外交 %.1f (+%.1f/月)　軍事 %.1f (+%.1f/月)" % [house.get("name", house_id), main.house_prestige.value_for(house_id), management.monthly_stipend(house_id), float(main.district_economy.house_resources[house_id].money), progress.governance, growth.governance, progress.diplomacy, growth.diplomacy, progress.military, growth.military]
	var slots := {"軍師": "未任命", "家老": "未任命", "所司代": "未任命"}
	var samurai := 0
	var direct := 0
	for officer_id in management.house_members[house_id]:
		var role: String = management.role_of(house_id, officer_id)
		if role in slots: slots[role] = str(main.officer_registry.lookup[officer_id].display_name)
		elif role == "侍大将": samurai += 1
		else: direct += 1
	tree.text = "大名　%s（俸禄なし）\n├ 軍師　%s（俸禄2.0/月・軍事技術）\n├ 家老　%s（俸禄2.0/月・統治技術）\n├ 所司代　%s（俸禄2.0/月・外交技術）\n├ 侍大将　%d人（俸禄0.1/月）\n└ 直臣　%d人（俸禄0.1/月）" % [ruler_name, slots["軍師"], slots["家老"], slots["所司代"], samurai, direct]
	var selected_id := ""
	var selected := roster.get_selected_items()
	if not selected.is_empty() and selected[0] < member_ids.size(): selected_id = member_ids[selected[0]]
	roster.clear()
	member_ids.clear()
	district_choice.clear()
	district_ids.clear()
	province_choice.clear()
	province_names.clear()
	for district_id in main.governance_registry.districts:
		var district: Dictionary = main.governance_registry.districts[district_id]
		if district.house_id != house_id: continue
		district_ids.append(district_id)
		district_choice.add_item("%s・%s" % [district.province, district.name])
		if district.province not in province_names:
			province_names.append(district.province)
			province_choice.add_item(district.province)
	for officer_id in management.house_members[house_id]:
		var officer: Dictionary = main.officer_registry.lookup[officer_id]
		var role: String = management.role_of(house_id, officer_id)
		member_ids.append(officer_id)
		var state: Dictionary = management.loyalty_state[officer_id]
		roster.add_item("%s　%s　忠誠 %d / 必要 %d　基礎 %.1f・支払 %.1f（要求基礎 %.1f）/月" % [officer.display_name, role, management.loyalty_for(house_id, officer_id), management.required_loyalty_for(officer_id), float(state.base_wage_tenths) * 0.1, management.stipend_for(house_id, officer_id), float(state.required_wage_tenths) * 0.1])
		if officer_id == selected_id: roster.select(member_ids.size() - 1)
	if not roster.get_selected_items().is_empty(): _select_member(roster.get_selected_items()[0])

func _select_member(index: int) -> void:
	if index < 0 or index >= member_ids.size(): return
	var role: String = main.retainer_management.role_of(GameSession.player_house, member_ids[index])
	role_choice.select(ROLE_NAMES.find(role))
	wage_input.value = float(main.retainer_management.loyalty_state[member_ids[index]].base_wage_tenths) * 0.1
	status.text = ""

func _appoint() -> void:
	var selected := roster.get_selected_items()
	if selected.is_empty(): status.text = "武将を選択してください。"; return
	var result: Error = main.retainer_management.assign_role(GameSession.player_house, member_ids[selected[0]], ROLE_NAMES[role_choice.selected])
	if result == ERR_ALREADY_EXISTS: status.text = "この役職には既に任命されています。先に解任してください。"
	elif result != OK: status.text = "任命できません。"
	else: status.text = "任命しました。"

func _set_wage() -> void:
	var selected := roster.get_selected_items()
	if selected.is_empty(): status.text = "武将を選択してください。"; return
	var result: Error = main.retainer_management.set_base_stipend(GameSession.player_house, member_ids[selected[0]], wage_input.value)
	status.text = "俸禄を設定しました。" if result == OK else "俸禄を設定できません。"

func _appoint_district() -> void:
	var selected := roster.get_selected_items()
	if selected.is_empty() or district_ids.is_empty(): status.text = "武将と郡を選択してください。"; return
	var result: Error = main.retainer_management.appoint_district_governor(GameSession.player_house, member_ids[selected[0]], district_ids[district_choice.selected])
	status.text = "郡代に任命しました。" if result == OK else "侍大将以上の武将を選択してください。"

func _appoint_province() -> void:
	var selected := roster.get_selected_items()
	if selected.is_empty() or province_names.is_empty(): status.text = "武将と国を選択してください。"; return
	var result: Error = main.retainer_management.appoint_province_governor(GameSession.player_house, member_ids[selected[0]], province_names[province_choice.selected])
	status.text = "国代に任命しました。" if result == OK else "侍大将以上の武将を選択してください。"
