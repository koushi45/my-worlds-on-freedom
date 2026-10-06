extends Control
## Icon tabs and research cards using the same native-size Japanese PNG set as the district UI.

const UI = preload("res://scripts/game/council_panel_style.gd")
const DistrictStyle = preload("res://scripts/game/council_panel_style.gd")
const BRANCH_IDS := ["governance", "agriculture", "commerce"]
const BRANCH_NAMES := {"governance": "統治技術", "agriculture": "農業技術", "commerce": "商業技術"}
const BRANCH_ICONS := {
	"governance": "res://assets/ui/hud/branch_governance",
	"agriculture": "res://assets/ui/hud/branch_agriculture",
	"commerce": "res://assets/ui/hud/branch_commerce",
}
const TECHNOLOGY_ICONS := {
	"分国法": "res://assets/ui/hud/tech_law",
	"官僚機構制定": "res://assets/ui/hud/tech_bureaucracy",
	"人口台帳": "res://assets/ui/hud/tech_census",
	"城下町制度": "res://assets/ui/hud/tech_castle_town",
	"楽市": "res://assets/ui/hud/tech_free_market",
	"兵農分離": "res://assets/ui/hud/tech_professional_army",
	"武家諸法度": "res://assets/ui/hud/tech_warrior_law",
	"二毛作": "res://assets/ui/hud/tech_double_crop",
	"鉄製農具配布": "res://assets/ui/hud/tech_iron_tools",
	"近世式用水路": "res://assets/ui/hud/tech_modern_canals",
	"共同管理法制定": "res://assets/ui/hud/tech_common_management",
	"大名介入": "res://assets/ui/hud/tech_daimyo_intervention",
	"灌漑整備": "res://assets/ui/hud/tech_irrigation_improvement",
	"検地": "res://assets/ui/hud/tech_land_survey",
	"石高制制定": "res://assets/ui/hud/tech_kokudaka",
	"新田開発": "res://assets/ui/hud/tech_new_paddies",
	"市場整備": "res://assets/ui/hud/tech_market_improvement",
	"商人保護": "res://assets/ui/hud/tech_merchant_protection",
	"度量衡整備": "res://assets/ui/hud/tech_weights_measures",
	"職人誘致": "res://assets/ui/hud/tech_artisan_invitation",
	"問屋整備": "res://assets/ui/hud/tech_wholesalers",
	"貨幣流通促進": "res://assets/ui/hud/tech_currency_circulation",
	"商工業振興": "res://assets/ui/hud/tech_industry_promotion",
	"商業奉行設置": "res://assets/ui/hud/tech_commerce_magistrate",
}
signal closed

var main: Node
var selected_branch := "governance"
var branch_buttons: Dictionary = {}
var technology_buttons: Dictionary = {}
var points_label: Label
var branch_state: Label
var technology_rows: VBoxContainer
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Control.new()
	panel.name = "TechnologyWindow"
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var title_row := HBoxContainer.new()
	body.add_child(title_row)
	DistrictStyle.heading("技術ツリー", title_row, 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var points := HBoxContainer.new()
	points.add_theme_constant_override("separation", 8)
	body.add_child(points)
	DistrictStyle.icon(points, "res://assets/ui/hud/research_points")
	points_label = UI.label("", points, 12)
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	branch_state = UI.label("", points, 12)
	branch_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	branch_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DistrictStyle.heading("技術系統を選ぶ", body, 14)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	body.add_child(tabs)
	var tab_group := ButtonGroup.new()
	for branch in BRANCH_IDS:
		var tab := DistrictStyle.button("", tabs, _select_branch.bind(branch))
		tab.name = "Branch_%s" % branch
		tab.custom_minimum_size = Vector2(0, 46)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.button_group = tab_group
		branch_buttons[branch] = tab
		var contents := HBoxContainer.new()
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 16
		contents.offset_right = -16
		contents.add_theme_constant_override("separation", 10)
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(contents)
		DistrictStyle.icon(contents, BRANCH_ICONS[branch])
		var title := UI.label(BRANCH_NAMES[branch], contents, 12)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DistrictStyle.heading("研究項目", body, 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 275
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	DistrictStyle.field(scroll)
	body.add_child(scroll)
	technology_rows = VBoxContainer.new()
	technology_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	technology_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(technology_rows)
	status = UI.label("研究できる項目を押してください。", body, 12)
	main.technology_tree.research_completed.connect(func(_house_id: String, _branch: String, _technology_id: String): refresh())
	main.retainer_management.updated.connect(refresh)
	get_window().size_changed.connect(refresh)
	UI.follow_window(self)
	hide()

func open() -> void:
	refresh()
	show()

func close_panel() -> void:
	hide()
	closed.emit()

func _select_branch(branch: String) -> void:
	selected_branch = branch
	status.text = "%sを表示しています。" % BRANCH_NAMES[branch]
	refresh()

func refresh() -> void:
	var house_id: String = GameSession.player_house
	if house_id.is_empty(): return
	var tree: Node = main.technology_tree
	var points: float = float(main.retainer_management.technology[house_id].governance)
	points_label.text = "統治技術力  %.1f" % points
	for branch in BRANCH_IDS: branch_buttons[branch].set_pressed_no_signal(branch == selected_branch)
	var next_id: String = tree.next_technology(house_id, selected_branch)
	if next_id.is_empty(): branch_state.text = "研究項目なし" if tree.BRANCHES[selected_branch].is_empty() else "この系統は研究完了"
	else:
		var next_cost: int = tree.cost_for(house_id, next_id)
		branch_state.text = "次：%s" % next_id if points >= next_cost else "次：%s（技術力不足）" % next_id
	for child in technology_rows.get_children():
		technology_rows.remove_child(child)
		child.queue_free()
	technology_buttons.clear()
	if tree.BRANCHES[selected_branch].is_empty():
		var empty := HBoxContainer.new()
		technology_rows.add_child(empty)
		DistrictStyle.icon(empty, BRANCH_ICONS[selected_branch])
		UI.label("商業技術の研究項目は未設定です。", empty, 12).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return
	for technology_id in tree.BRANCHES[selected_branch]:
		var cost: int = tree.cost_for(house_id, technology_id)
		var completed: bool = tree.completed(house_id, technology_id)
		var next: bool = technology_id == next_id
		_add_technology_row(technology_id, cost, completed, next, points >= cost)

func _add_technology_row(technology_id: String, cost: int, completed: bool, next: bool, affordable: bool) -> void:
	var available: bool = next and affordable and not completed
	var card := DistrictStyle.button("", technology_rows, _research.bind(technology_id))
	card.name = "Technology_%s" % technology_id
	card.custom_minimum_size = Vector2(0, 64)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.disabled = not available
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color("#121823b3")
	disabled_style.border_color = Color("#60563e88")
	disabled_style.set_border_width_all(1)
	card.add_theme_stylebox_override("disabled", disabled_style)
	if available:
		var ready_style := StyleBoxFlat.new()
		ready_style.bg_color = Color("#294048db")
		ready_style.border_color = Color("#ddb86d")
		ready_style.set_border_width_all(2)
		card.add_theme_stylebox_override("normal", ready_style)
	technology_buttons[technology_id] = card
	var accent := ColorRect.new()
	accent.color = Color("#d7ad64") if available else (Color("#7aae78") if completed else Color("#746c58"))
	accent.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	accent.offset_right = 4
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent)
	var contents := HBoxContainer.new()
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.offset_left = 14
	contents.offset_right = -14
	contents.add_theme_constant_override("separation", 12)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(contents)
	DistrictStyle.icon(contents, TECHNOLOGY_ICONS[technology_id])
	var text_stack := VBoxContainer.new()
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(text_stack)
	var name_label := UI.label(technology_id, text_stack, 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail := UI.label(main.technology_tree.DESCRIPTIONS[technology_id], text_stack, 12)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var state := VBoxContainer.new()
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	state.custom_minimum_size.x = 118
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(state)
	var state_label := UI.label("研究済" if completed else ("研究する" if available else ("技術力不足" if next else "前提技術待ち")), state, 12)
	state_label.add_theme_color_override("font_color", Color("#a5d7a1") if completed else (DistrictStyle.GOLD if available else Color("#a2a4a8")))
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.add_child(cost_row)
	DistrictStyle.icon(cost_row, "res://assets/ui/hud/research_cost")
	var cost_label := UI.label("%d" % cost, cost_row, 12)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not available: contents.modulate = Color(1, 1, 1, 0.72)
	card.tooltip_text = "%s：%s／%s" % [technology_id, main.technology_tree.DESCRIPTIONS[technology_id], state_label.text]

func _research(technology_id: String) -> void:
	if not technology_buttons.has(technology_id) or technology_buttons[technology_id].disabled: return
	var result: Error = main.technology_tree.research(GameSession.player_house, selected_branch, technology_id)
	status.text = "%sの研究が完了しました。" % technology_id if result == OK else "研究できませんでした。"
