extends AcceptDialog
## Research tree for the player's house.

const UI = preload("res://scripts/game/menu_style.gd")
const BRANCH_IDS := ["governance", "agriculture", "commerce"]
const BRANCH_NAMES := ["統治技術", "農業技術", "商業技術"]
var main: Node
var branch_choice: OptionButton
var points_label: Label
var technologies: ItemList
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "技術ツリー"
	ok_button_text = "閉じる"
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(800, 510)
	body.add_theme_constant_override("separation", 10)
	add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	branch_choice = OptionButton.new()
	for name in BRANCH_NAMES: branch_choice.add_item(name)
	branch_choice.item_selected.connect(func(_index: int): refresh())
	heading.add_child(branch_choice)
	points_label = UI.label("", heading, 18)
	technologies = ItemList.new()
	technologies.custom_minimum_size = Vector2(780, 390)
	technologies.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(technologies)
	UI.button("選択した技術を研究", body, _research).custom_minimum_size = Vector2(290, 40)
	status = UI.label("", body, 16)
	main.technology_tree.research_completed.connect(func(_house_id: String, _branch: String, _technology_id: String): refresh())
	main.retainer_management.updated.connect(refresh)

func open() -> void:
	refresh()
	popup_centered(Vector2i(850, 590))

func refresh() -> void:
	var house_id: String = GameSession.player_house
	if house_id.is_empty(): return
	var branch: String = BRANCH_IDS[branch_choice.selected]
	var tree: Node = main.technology_tree
	var points: float = float(main.retainer_management.technology[house_id].governance)
	points_label.text = "　統治技術力 %.1f　研究費用：通常1,000（城下町制度後950）" % points
	var selected := technologies.get_selected_items()
	var selected_index := selected[0] if not selected.is_empty() else -1
	technologies.clear()
	if tree.BRANCHES[branch].is_empty():
		technologies.add_item("研究項目は未設定です。")
		return
	for index in tree.BRANCHES[branch].size():
		var technology_id: String = tree.BRANCHES[branch][index]
		var prefix := "✓" if tree.completed(house_id, technology_id) else ("▶" if technology_id == tree.next_technology(house_id, branch) else "・")
		var cost: int = tree.cost_for(house_id, technology_id)
		technologies.add_item("%s %s　%s　%s" % [prefix, technology_id, tree.DESCRIPTIONS[technology_id], "（%d）" % cost if prefix == "▶" else ""])
		if index == selected_index: technologies.select(index)

func _research() -> void:
	var selected := technologies.get_selected_items()
	if selected.is_empty(): status.text = "技術を選択してください。"; return
	var branch: String = BRANCH_IDS[branch_choice.selected]
	if main.technology_tree.BRANCHES[branch].is_empty(): status.text = "研究項目は未設定です。"; return
	var technology_id: String = main.technology_tree.BRANCHES[branch][selected[0]]
	var result: Error = main.technology_tree.research(GameSession.player_house, branch, technology_id)
	status.text = "研究が完了しました。" if result == OK else ("技術力が足りません。" if result == ERR_UNAVAILABLE else "前の技術から研究してください。")
