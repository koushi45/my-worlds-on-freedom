extends Control
## Council diplomacy: select another house, inspect its opinion, then take an action.

const UI = preload("res://scripts/game/council_panel_style.gd")
const Style = preload("res://scripts/game/council_panel_style.gd")

signal closed

var main: Node
var selected := ""
var house_ids: Array[String] = []
var search: LineEdit
var house_list: ItemList
var details: VBoxContainer
var status: Label
var claim_dialog: ConfirmationDialog
var claim_choice: OptionButton
var claim_ids: Array[String] = []
var claim_target := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Control.new()
	panel.name = "DiplomacyWindow"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	Style.heading("外交", header, 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 200
	columns.add_child(left)
	search = LineEdit.new()
	search.placeholder_text = "家名で探す"
	search.text_changed.connect(func(_value: String): _fill_houses())
	Style.field(search)
	left.add_child(search)
	house_list = ItemList.new()
	house_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	house_list.item_selected.connect(_select_index)
	Style.field(house_list)
	left.add_child(house_list)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 9)
	right.add_child(details)
	status = UI.label("外交行動を選んでください", body, 12)
	status.custom_minimum_size.y = 26
	main.diplomacy.changed.connect(_refresh)
	claim_dialog = ConfirmationDialog.new()
	claim_dialog.title = "請求権を捏造する郡（諜報値20）"
	claim_dialog.ok_button_text = "捏造する"
	claim_dialog.cancel_button_text = "戻る"
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color("#0c1422")
	dialog_style.border_color = Style.GOLD
	dialog_style.set_border_width_all(2)
	dialog_style.set_content_margin_all(14)
	claim_dialog.add_theme_stylebox_override("panel", dialog_style)
	var dialog_border := dialog_style.duplicate() as StyleBoxFlat
	dialog_border.set_expand_margin_all(8)
	dialog_border.set_expand_margin(SIDE_TOP, 32)
	claim_dialog.add_theme_stylebox_override("embedded_border", dialog_border)
	claim_dialog.add_theme_color_override("title_color", Style.GOLD)
	add_child(claim_dialog)
	for dialog_button in [claim_dialog.get_ok_button(), claim_dialog.get_cancel_button()]:
		Style.Base.field(dialog_button)
		dialog_button.add_theme_font_size_override("font_size", 18)
		dialog_button.custom_minimum_size = Vector2(100, 36)
		dialog_button.add_theme_color_override("font_hover_color", Style.GOLD)
	claim_choice = OptionButton.new()
	Style.field(claim_choice)
	claim_dialog.add_child(claim_choice)
	claim_dialog.confirmed.connect(_confirm_claim)
	UI.follow_window(self)

func open() -> void:
	show()
	_fill_houses()
	_refresh()

func close_panel() -> void:
	hide()
	closed.emit()

func _fill_houses() -> void:
	house_ids.clear()
	house_list.clear()
	var owned := {}
	var player_points: Array[Vector2] = []
	for district in main.governance_registry.districts.values(): owned[district.house_id] = true
	for district in main.governance_registry.districts.values():
		if district.house_id == GameSession.player_house:
			player_points.append(Vector2(district.point[0], district.point[1]))
	var distances := {}
	for district in main.governance_registry.districts.values():
		if district.house_id == GameSession.player_house: continue
		var point := Vector2(district.point[0], district.point[1])
		var nearest: float = distances.get(district.house_id, INF)
		for player_point in player_points:
			nearest = minf(nearest, point.distance_squared_to(player_point))
		distances[district.house_id] = nearest
	for house_id in main.governance_registry.houses:
		if house_id == GameSession.player_house or not owned.has(house_id): continue
		var name: String = str(main.governance_registry.houses[house_id].display_name)
		if not search.text.is_empty() and not name.contains(search.text): continue
		house_ids.append(house_id)
	house_ids.sort_custom(func(a: String, b: String):
		var a_distance: float = distances.get(a, INF)
		var b_distance: float = distances.get(b, INF)
		if a_distance != b_distance: return a_distance < b_distance
		var a_name: String = str(main.governance_registry.houses[a].display_name)
		var b_name: String = str(main.governance_registry.houses[b].display_name)
		return a_name < b_name if a_name != b_name else a < b)
	for house_id in house_ids:
		var name: String = str(main.governance_registry.houses[house_id].display_name)
		var relation: String = _relation_name(GameSession.relation(GameSession.player_house, house_id))
		house_list.add_item("%s　%s" % [name, relation])
		if house_id == selected: house_list.select(house_list.item_count - 1)
	if selected.is_empty() and not house_ids.is_empty():
		selected = house_ids[0]
		house_list.select(0)
	_refresh()

func _select_index(index: int) -> void:
	if index < 0 or index >= house_ids.size(): return
	selected = house_ids[index]
	_refresh()

func _relation_name(value: String) -> String:
	match value:
		"ally": return "同盟"
		"enemy": return "敵対"
		_: return "中立"

func _refresh() -> void:
	if not is_instance_valid(details): return
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	if selected.is_empty() or not main.governance_registry.houses.has(selected): return
	var actor: String = GameSession.player_house
	var name: String = str(main.governance_registry.houses[selected].display_name)
	Style.heading(name, details, 14)
	var pending: String = main.diplomacy.pending_request(actor, selected)
	if not pending.is_empty():
		var aggressor: String = main.diplomacy.wars[pending].attacker
		UI.label("防衛参戦要請：%sに対抗する援軍を求めています" % str(main.governance_registry.houses[aggressor].display_name), details, 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_add_action("join_war", "同盟国の防衛戦争に参戦する")
		_add_action("decline_war", "参戦を辞退する")
	UI.label("関係：%s" % _relation_name(GameSession.relation(actor, selected)), details, 12)
	UI.label("相手からの友好度：%+d / 100" % main.diplomacy.opinion(selected, actor), details, 12)
	UI.label("こちらからの友好度：%+d / 100" % main.diplomacy.opinion(actor, selected), details, 12)
	var remaining: int = main.diplomacy.truce_remaining(actor, selected)
	if remaining > 0: UI.label("停戦：残り%d日" % remaining, details, 12)
	Style.heading("外交行動", details, 14)
	UI.label("外交官：派遣中%d / %d人（関係改善・諜報で共通）" % [main.diplomacy.diplomats_used(actor), main.diplomacy.DIPLOMAT_LIMIT], details, 12)
	for assignment in [[main.diplomacy.envoys, "関係改善"], [main.diplomacy.spies, "諜報"]]:
		for destination in assignment[0].get(actor, []):
			UI.label("%s：%s" % [assignment[1], main.governance_registry.houses[destination].display_name], details, 12)
	_add_action("recall" if main.diplomacy.has_envoy(actor, selected) else "envoy", "関係改善の使節を呼び戻す" if main.diplomacy.has_envoy(actor, selected) else "関係改善の使節を派遣（外交官1人・毎月+5）")
	_add_action("gift", "贈物を送る（金銭100・友好度+20）")
	_add_action("ally", "同盟を提案（友好度40以上）")
	_add_action("break_ally", "同盟を破棄（威信-10）")
	_add_action("insult", "侮辱を送る（友好度-25）")
	_add_action("war", "請求権を根拠に宣戦（威信減少なし）" if main.diplomacy.has_claim_against(actor, selected) else "理由なく宣戦（威信-%d）" % main.house_prestige.UNJUSTIFIED_WAR_LOSS)
	_add_action("peace", "停戦を提案（友好度-20以上）")
	if GameSession.relation(actor, selected) == "enemy": _add_action("call_allies", "同盟国に防衛参戦を要請する")
	Style.heading("諜報", details, 14)
	UI.label("この家への諜報値：%d / 100　相手の自家への諜報値：%d" % [main.diplomacy.spy_value(actor, selected), main.diplomacy.spy_value(selected, actor)], details, 12)
	_add_action("recall_spy" if main.diplomacy.has_spy(actor, selected) else "build_spy_network", "間者を帰還（月初-2）" if main.diplomacy.has_spy(actor, selected) else "間者を派遣（外交官1人・月初+%d）" % main.diplomacy.SPY_MONTHLY_GAIN)
	for id in main.diplomacy.claims.get(actor, {}):
		if main.governance_registry.districts.has(id) and main.governance_registry.districts[id].house_id == selected and main.diplomacy.claim_remaining(actor, id) > 0:
			UI.label("請求権：%s（残り%d日）" % [main.governance_registry.districts[id].get("name", id), main.diplomacy.claim_remaining(actor, id)], details, 12)
	_add_action("fabricate_claim", "請求権を捏造（諜報20・1825日・郡を選択）")
	for entry in [["sow_discontent", "不満扇動（諜報60・月初に治安-3・360日）"], ["sabotage_reputation", "評判毀損（諜報50・第三者からの友好度-20・360日）"], ["sabotage_recruitment", "徴兵妨害（諜報50・兵力回復-20%・360日）"], ["slander_merchants", "商人中傷（諜報70・商業収入-25%・360日）"]]:
		_add_action(entry[0], entry[1])
		var effect_days: int = main.diplomacy.effect_remaining(entry[0], selected)
		if effect_days > 0: UI.label("効果中：残り%d日" % effect_days, details, 12)
	_add_action("counterespionage", "防諜（諜報30・相手の自家への諜報値-30）")

func _add_action(action: String, caption: String) -> void:
	var button := Style.button(caption, details, _act.bind(action))
	button.custom_minimum_size = Vector2(0, 34)
	var issue: String = main.diplomacy.reason(action, GameSession.player_house, selected)
	button.disabled = not issue.is_empty()
	button.tooltip_text = issue if not issue.is_empty() else caption

func _act(action: String) -> void:
	if action == "fabricate_claim":
		claim_target = selected
		claim_ids = main.diplomacy.claim_candidates(GameSession.player_house, selected)
		claim_choice.clear()
		for id in claim_ids: claim_choice.add_item(str(main.governance_registry.districts[id].get("name", id)))
		if not claim_ids.is_empty(): claim_dialog.popup_centered(Vector2i(480, 140))
		return
	main.diplomacy.act(action, GameSession.player_house, selected)
	status.text = main.diplomacy.last_message
	_fill_houses()

func _confirm_claim() -> void:
	if claim_choice.selected < 0 or claim_choice.selected >= claim_ids.size(): return
	main.diplomacy.act("fabricate_claim", GameSession.player_house, claim_target, claim_ids[claim_choice.selected])
	status.text = main.diplomacy.last_message
	_fill_houses()
