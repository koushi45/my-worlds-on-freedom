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
	for district in main.governance_registry.districts.values(): owned[district.house_id] = true
	for house_id in main.governance_registry.houses:
		if house_id == GameSession.player_house or not owned.has(house_id): continue
		var name: String = str(main.governance_registry.houses[house_id].display_name)
		if not search.text.is_empty() and not name.contains(search.text): continue
		house_ids.append(house_id)
	house_ids.sort_custom(func(a: String, b: String): return str(main.governance_registry.houses[a].display_name) < str(main.governance_registry.houses[b].display_name))
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
	var envoy: String = main.diplomacy.envoy_target(actor)
	Style.heading("外交行動", details, 14)
	var envoy_caption := "関係改善の使節を派遣（毎月+5）"
	if not envoy.is_empty() and envoy != selected:
		envoy_caption = "使節を%sから呼び戻して派遣" % str(main.governance_registry.houses[envoy].display_name)
	_add_action("envoy", envoy_caption)
	_add_action("recall", "使節を呼び戻す（派遣先：%s）" % name)
	_add_action("gift", "贈物を送る（金銭100・友好度+20）")
	_add_action("ally", "同盟を提案（友好度40以上）")
	_add_action("break_ally", "同盟を破棄（威信-10）")
	_add_action("insult", "侮辱を送る（友好度-25）")
	_add_action("war", "宣戦する（威信-10）")
	_add_action("peace", "停戦を提案（友好度-20以上）")
	if GameSession.relation(actor, selected) == "enemy": _add_action("call_allies", "同盟国に防衛参戦を要請する")

func _add_action(action: String, caption: String) -> void:
	var button := Style.button(caption, details, _act.bind(action))
	button.custom_minimum_size = Vector2(0, 34)
	var issue: String = main.diplomacy.reason(action, GameSession.player_house, selected)
	button.disabled = not issue.is_empty()
	button.tooltip_text = issue if not issue.is_empty() else caption

func _act(action: String) -> void:
	main.diplomacy.act(action, GameSession.player_house, selected)
	status.text = main.diplomacy.last_message
	_fill_houses()
