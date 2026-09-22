extends Control
const UI = preload("res://scripts/game/menu_style.gd")
var menu: VBoxContainer
var picker: PanelContainer
var house_list: ItemList
var search: LineEdit
var description: Label
var start_button: Button
var house_ids: Array = []
var chosen := ""
var busy := false
var options: Control
var officer_dictionary: Node

func _ready() -> void:
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/title_landscape.svg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.025,0.08,0.1,0.35)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	menu = VBoxContainer.new()
	menu.position = Vector2(90,145)
	menu.add_theme_constant_override("separation",14)
	add_child(menu)
	UI.label("MY WORLDS ON FREEDOM",menu,18)
	UI.label("戦国の世",menu,58)
	UI.label("天文十五年 ― 1546",menu,20)
	UI.label("",menu,10)
	UI.button("スタート",menu,show_houses).grab_focus()
	UI.button("ロード",menu,show_load)
	UI.button("辞典",menu,show_dictionary)
	UI.button("オプション",menu,show_options)
	if "--developer-ui" in OS.get_cmdline_user_args(): GameSession.new_game.call_deferred("oda_nobuhide")

func show_dictionary() -> void:
	menu.hide()
	if officer_dictionary == null:
		officer_dictionary = preload("res://scripts/game/officer_panel.gd").new()
		officer_dictionary.standalone = true
		officer_dictionary.closed.connect(menu.show)
		add_child(officer_dictionary)
	officer_dictionary.show_browser()

func show_load() -> void:
	var slots := preload("res://scripts/game/save_slots.gd").new()
	add_child(slots)

func show_options() -> void:
	menu.hide()
	options = preload("res://scripts/game/display_options.gd").new()
	options.closed.connect(menu.show)
	add_child(options)

func show_houses() -> void:
	menu.hide()
	picker = UI.centered(self,Vector2(780,620))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",12)
	picker.add_child(rows)
	UI.label("大名家を選ぶ",rows,28)
	UI.label("1546年1月1日開始　／　領有郡のある大名家",rows,16)
	search = LineEdit.new()
	search.placeholder_text = "大名家・当主名で検索"
	search.text_changed.connect(func(_s): refresh_houses())
	rows.add_child(search)
	house_list = ItemList.new()
	house_list.custom_minimum_size.y = 270
	house_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	house_list.item_selected.connect(select_house)
	rows.add_child(house_list)
	description = UI.label("",rows,16)
	description.custom_minimum_size.y = 50
	start_button = UI.button("この大名家で開始",rows,begin)
	UI.button("戻る",rows,func(): picker.queue_free(); menu.show())
	refresh_houses()
	var index := house_ids.find("oda_nobuhide")
	if index >= 0: house_list.select(index); house_list.ensure_current_is_visible(); select_house(index)
	search.grab_focus()

func refresh_houses() -> void:
	house_ids.clear()
	house_list.clear()
	chosen = ""
	start_button.disabled = true
	for id in GameSession.catalog.houses:
		var h: Dictionary = GameSession.catalog.houses[id]
		if h.playable and (search.text.is_empty() or search.text in h.name or search.text in h.ruler): house_ids.append(id)
	house_ids.sort_custom(func(a,b): return GameSession.catalog.houses[a].name < GameSession.catalog.houses[b].name)
	for id in house_ids:
		var h: Dictionary = GameSession.catalog.houses[id]
		house_list.add_item("%s　｜　%s　｜　領有 %d郡" % [h.name,h.ruler,h.district_count])
	description.text = "%d家から選択してください。領有・任命は開始時のゲーム設定です。" % house_ids.size()

func select_house(index: int) -> void:
	chosen = house_ids[index]
	var h: Dictionary = GameSession.catalog.houses[chosen]
	description.text = "%s　当主：%s\n領有 %d郡" % [h.name,h.ruler,h.district_count]
	start_button.disabled = false

func begin() -> void:
	if chosen.is_empty() or busy: return
	busy = true
	start_button.disabled = true
	description.text = "地図を読み込んでいます…"
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var err: Error = GameSession.new_game(chosen)
	if err != OK: description.text = "ゲームを開始できません："+error_string(err); busy = false; start_button.disabled = false
