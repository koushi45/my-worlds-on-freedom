extends Control
## Current recurring income and contracted wages, using the simulation's own calculations.
const UI = preload("res://scripts/game/council_panel_style.gd")
signal closed
var main: Node
var rows: VBoxContainer
var report: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var body := VBoxContainer.new()
	add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.heading("月次収入・月次支出", body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	UI.follow_window(self)
	hide()

func open() -> void:
	refresh()
	show()

func refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var house: String = get_node("/root/GameSession").player_house
	report = summarize(main.district_economy, main.retainer_management, house)
	_note("自家の領有全郡：%d郡／現在の状態での見込額" % report.districts.size())
	UI.heading("金銭の月次収入（毎月1日）", rows)
	_metric("郡の商工業・税収", "%d / 月" % report.money_income)
	_metric("月次収入 合計", "%d / 月" % report.money_income)
	UI.heading("金銭の月次支出（毎月1日）", rows)
	_metric("俸禄支出", "%.1f / 月" % report.money_expense)
	for role in report.wages:
		_metric("　%s" % role, "%.1f / 月" % report.wages[role])
	_metric("月次支出 合計", "%.1f / 月" % report.money_expense)
	_metric("月次差引", "%+.1f / 月" % (report.money_income - report.money_expense))
	UI.heading("兵糧の年間収入（9月1日）", rows)
	_metric("郡の農業・年貢", "%d / 年" % report.provisions_income)
	_metric("年間収入 合計", "%d / 年" % report.provisions_income)
	_note("俸禄は契約額を表示。建築・修復・贈物・命令などの随時支出、略奪・返金などの臨時収入は見込額に含みません。")
	UI.heading("郡別の収入内訳", rows)
	_note("郡名　／　金銭（月）　／　兵糧（年）")
	for district in report.districts:
		_metric(district.name, "%d / 月　　%d / 年" % [district.money, district.provisions])
	if report.districts.is_empty(): _note("領有している郡はありません。")
	UI.resize(self)

func _metric(caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	UI.label(caption, row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(value, row).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _note(text: String) -> void:
	var label := UI.label(text, rows, 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func summarize(economy: Node, retainers: Node, house: String) -> Dictionary:
	var result := {"money_income": 0, "provisions_income": 0, "money_expense": retainers.monthly_stipend(house), "districts": [], "wages": {}}
	for record in economy.registry.districts.values():
		if record.house_id != house: continue
		var money: int = economy.income_for(record, "commerce")
		var provisions: int = economy.income_for(record, "agriculture")
		result.money_income += money
		result.provisions_income += provisions
		result.districts.append({"name": record.get("name", record.id), "money": money, "provisions": provisions})
	result.districts.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	for officer in retainers.house_members.get(house, []):
		var role: String = retainers.role_of(house, officer)
		result.wages[role] = float(result.wages.get(role, 0.0)) + retainers.stipend_for(house, officer)
	return result
