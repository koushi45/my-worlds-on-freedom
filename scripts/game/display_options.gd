extends Control
signal closed
const UI = preload("res://scripts/game/menu_style.gd")
var resolution_selector: OptionButton
var bgm_slider: HSlider
var bgm_value_label: Label
var sfx_slider: HSlider
var sfx_value_label: Label
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := UI.centered(self,Vector2(560,720))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",12)
	panel.add_child(rows)
	UI.label("オプション",rows,28)
	UI.label("ウィンドウサイズ",rows,16)
	resolution_selector = OptionButton.new()
	resolution_selector.custom_minimum_size = Vector2(360,44)
	resolution_selector.add_theme_font_size_override("font_size",18)
	for label in DisplaySettings.LABELS: resolution_selector.add_item(label)
	resolution_selector.select(DisplaySettings.current_index)
	rows.add_child(resolution_selector)
	bgm_value_label = UI.label("BGM音量：%d%%" % int(round(DisplaySettings.bgm_volume*100.0)),rows,16)
	bgm_slider = HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 100.0
	bgm_slider.step = 1.0
	bgm_slider.value = DisplaySettings.bgm_volume*100.0
	bgm_slider.custom_minimum_size = Vector2(360,34)
	bgm_slider.value_changed.connect(func(value: float): bgm_value_label.text = "BGM音量：%d%%" % int(round(value)))
	rows.add_child(bgm_slider)
	sfx_value_label = UI.label("効果音音量：%d%%" % int(round(DisplaySettings.sfx_volume*100.0)),rows,16)
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 1.0
	sfx_slider.value = DisplaySettings.sfx_volume*100.0
	sfx_slider.custom_minimum_size = Vector2(360,34)
	sfx_slider.value_changed.connect(func(value: float): sfx_value_label.text = "効果音音量：%d%%" % int(round(value)))
	rows.add_child(sfx_slider)
	status = UI.label("選択後に適用してください。",rows,14)
	UI.button("適用",rows,_apply)
	UI.button("戻る",rows,_close)
	UI.label("BGM（交互再生）\nEight Mountains — Savfk\nRise Again (Alternative Version) — Alexander Nakarada\n両曲 CC BY 4.0 / 公式配布音源をOGGへ変換",rows,13)
	var first_source := LinkButton.new()
	first_source.text = "Eight Mountains 配布元・ライセンス"
	first_source.uri = "https://savfkmusic.com/eight-mountains/index.html"
	first_source.add_theme_font_size_override("font_size",13)
	rows.add_child(first_source)
	var second_source := LinkButton.new()
	second_source.text = "Rise Again 配布元・ライセンス"
	second_source.uri = "https://creatorchords.com/music/rise-again-alternative-version/"
	second_source.add_theme_font_size_override("font_size",13)
	rows.add_child(second_source)

func _apply() -> void:
	DisplaySettings.apply_resolution(resolution_selector.selected)
	DisplaySettings.set_bgm_volume(bgm_slider.value/100.0)
	DisplaySettings.set_sfx_volume(sfx_slider.value/100.0)
	status.text = "%s・BGM %d%%・効果音 %d%% に変更しました。" % [DisplaySettings.LABELS[DisplaySettings.current_index],int(round(bgm_slider.value)),int(round(sfx_slider.value))]

func _close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
