extends Control
signal closed
const UI = preload("res://scripts/game/menu_style.gd")
var resolution_selector: OptionButton
var bgm_slider: HSlider
var bgm_value_label: Label
var sfx_slider: HSlider
var sfx_value_label: Label
var status: Label
var terrain_selectors: Array[OptionButton] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := UI.centered(self,Vector2(640,680))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",12)
	panel.add_child(layout)
	UI.label("オプション",layout,28)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",12)
	scroll.add_child(rows)
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
	var terrain_values := [DisplaySettings.terrain_cache_level,DisplaySettings.terrain_parallel_level,DisplaySettings.terrain_prefetch_level]
	var terrain_names := ["地形キャッシュ先読み・保持範囲","地形生成並列処理","地形先読み処理"]
	var terrain_hints := ["保持範囲を広げるほど、移動・回転時の切り替わりを抑えます。","並列数を増やすほど、未準備の地形を早く生成します。","移動先・回転先の地形と地図を先に読み込みます。"]
	for i in 3:
		var row := HBoxContainer.new()
		rows.add_child(row)
		UI.label(terrain_names[i],row,16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var selector := OptionButton.new()
		selector.custom_minimum_size = Vector2(160,44)
		selector.add_theme_font_size_override("font_size",18)
		for label in DisplaySettings.LOAD_LABELS: selector.add_item(label)
		selector.select(terrain_values[i])
		row.add_child(selector)
		terrain_selectors.append(selector)
		var hint := UI.label(terrain_hints[i],rows,14)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label("中・高負荷はCPU・RAM・VRAMの使用量が増えます。",rows,14)
	status = UI.label("選択後に適用してください。",layout,14)
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	UI.button("適用",actions,_apply).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button("戻る",actions,_close).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label("BGM（3曲を順番に繰り返し再生）\nSymphony no. 3 'Scottish', Op. 56 - I. Andante con moto\nFelix Mendelssohn / Musopen Symphony\nPublic Domain Mark 1.0 / 配布音源をOGGへ変換",rows,13)
	var music_source := LinkButton.new()
	music_source.text = "Musopen 配布元・権利表示"
	music_source.uri = "https://musopen.org/music/282-symphony-no-3-scottish-op-56/"
	music_source.add_theme_font_size_override("font_size",13)
	rows.add_child(music_source)
	UI.label("月光ソナタ 第1楽章（Op. 27 No. 2 / Adagio sostenuto）\nLudwig van Beethoven / Paul Pitman\n録音提供：Musopen / Public Domain",rows,13)
	var moonlight_source := LinkButton.new()
	moonlight_source.text = "Musopen https://musopen.org/"
	moonlight_source.uri = "https://musopen.org/"
	moonlight_source.add_theme_font_size_override("font_size",13)
	rows.add_child(moonlight_source)
	var moonlight_license := LinkButton.new()
	moonlight_license.text = "月光ソナタ 配布元・録音の利用許諾"
	moonlight_license.uri = "https://commons.wikimedia.org/wiki/File:Ludwig_van_Beethoven_-_sonata_no._14_in_c_sharp_minor_%27moonlight%27,_op._27_no._2_-_i._adagio_sostenuto.ogg"
	moonlight_license.add_theme_font_size_override("font_size",13)
	rows.add_child(moonlight_license)
	UI.label("婚礼の合唱（ローエングリンより / パイプオルガン版）\n作曲：Richard Wagner\nWagner Bridal Chorus — Kevin MacLeod (incompetech.com)\nCC BY 4.0 / MP3からOGGへ変換",rows,13)
	var bridal_source := LinkButton.new()
	bridal_source.text = "Incompetech 配布元・クレジット"
	bridal_source.uri = "https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100021"
	bridal_source.add_theme_font_size_override("font_size",13)
	rows.add_child(bridal_source)
	var bridal_license := LinkButton.new()
	bridal_license.text = "Creative Commons Attribution 4.0"
	bridal_license.uri = "https://creativecommons.org/licenses/by/4.0/"
	bridal_license.add_theme_font_size_override("font_size",13)
	rows.add_child(bridal_license)

func _apply() -> void:
	DisplaySettings.apply_resolution(resolution_selector.selected)
	DisplaySettings.set_bgm_volume(bgm_slider.value/100.0)
	DisplaySettings.set_sfx_volume(sfx_slider.value/100.0)
	DisplaySettings.set_terrain_options(terrain_selectors[0].selected,terrain_selectors[1].selected,terrain_selectors[2].selected)
	status.text = "表示・音量・地形設定を適用しました。"

func _close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
