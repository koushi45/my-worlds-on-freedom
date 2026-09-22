extends Control
signal closed
const UI = preload("res://scripts/game/menu_style.gd")
var main: Node
var saving := false
var rows: VBoxContainer
var status: Label
var confirmation: ConfirmationDialog
var selected_slot := 0
var loading := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var p := UI.centered(self,Vector2(720,570))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	p.add_child(rows)
	UI.label("セーブ" if saving else "ロード",rows,28)
	UI.label("保存先：この端末の5つのスロット",rows,14)
	for slot in range(1,6):
		var d: Dictionary = GameSession.read_save(slot)
		var caption := "スロット %d　未使用" % slot
		if not d.is_empty(): caption = "スロット %d　%s\n%d年%d月%d日　%s" % [slot,GameSession.catalog.houses[d.player_house].name,d.clock.year,d.clock.month,d.clock.day,d.get("saved_at","")]
		elif FileAccess.file_exists(GameSession.path_for(slot)): caption = "スロット %d　読込不可（破損・非対応）" % slot
		var b := UI.button(caption,rows,choose.bind(slot))
		b.add_theme_font_size_override("font_size",16)
		b.custom_minimum_size.y = 58
		b.disabled = not saving and d.is_empty()
	status = UI.label("",rows,14)
	UI.button("戻る",rows,func(): closed.emit(); queue_free())
	confirmation = ConfirmationDialog.new()
	confirmation.title = "確認"
	confirmation.ok_button_text = "実行"
	confirmation.cancel_button_text = "キャンセル"
	confirmation.confirmed.connect(execute)
	add_child(confirmation)

func choose(slot: int) -> void:
	if loading: return
	selected_slot = slot
	if (saving and FileAccess.file_exists(GameSession.path_for(slot))) or (not saving and main != null):
		confirmation.dialog_text = "スロット %d を上書きしますか？" % slot if saving else "未保存の進行を破棄し、選択したセーブをロードしますか？"
		confirmation.popup_centered()
	else: execute()

func execute() -> void:
	if saving:
		var err: Error = GameSession.save_game(main,selected_slot)
		if err == OK:
			status.text = "スロット %d に保存しました。" % selected_slot
			var d: Dictionary = GameSession.read_save(selected_slot)
			if d.is_empty(): status.text = "保存後の検証に失敗しました："+GameSession.last_error; return
			var b := rows.get_child(selected_slot+1) as Button
			b.text = "スロット %d　%s\n%d年%d月%d日　%s" % [selected_slot,GameSession.catalog.houses[d.player_house].name,d.clock.year,d.clock.month,d.clock.day,d.saved_at]
		else: status.text = GameSession.last_error
	else:
		if loading: return
		loading = true
		status.text = "ゲームを読み込んでいます…"
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		if GameSession.load_game(selected_slot) != OK:
			status.text = GameSession.last_error
			loading = false
