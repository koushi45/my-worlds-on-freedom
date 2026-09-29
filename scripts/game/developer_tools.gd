extends CanvasLayer
const Style = preload("res://scripts/game/district_panel_style.gd")
const UI = preload("res://scripts/game/menu_style.gd")
const Grid = preload("res://scripts/map/hex_grid.gd")
const Network = preload("res://scripts/map/hex_road_network.gd")
var main: Node
var network = Network.new()
var road_layer: Node2D
var panel: Control
var road_button: Button
var edge_button: Button
var edit_help: Label
var edge_editing := false
var undo_button: Button
var redo_button: Button
var status: Label
var file_dialog: FileDialog
var enabled := false
var road_editing := false
var network_active := false
var clock_was_processing := false
var contour_layer: Sprite2D
var contour_mode := false
var contour_button: Button
var contour_legend: Label
var previous_oblique := false
var previous_basemap_visible := true

func _ready() -> void:
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS
	network.setup([],main.hex_tile_layer.visible_cells)
	if not network.load_document(JSON.parse_string(FileAccess.get_file_as_string(Network.DEFAULT_PATH))):
		push_error("Official road data could not be loaded: " + network.last_error)
	network.changed.connect(_refresh)
	road_layer = preload("res://scripts/map/editable_road_layer.gd").new()
	road_layer.name = "EditableRoads"
	road_layer.main = main
	road_layer.network = network
	main.hex_tile_layer.add_child(road_layer)
	road_layer.hide()
	panel = Control.new()
	panel.position = Vector2(20,200)
	panel.size = Vector2(350,510)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	Style.frame(panel)
	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.offset_left = 28
	rows.offset_right = -28
	rows.offset_top = 28
	rows.offset_bottom = -28
	rows.add_theme_constant_override("separation",8)
	panel.add_child(rows)
	Style.heading("開発者モード",rows,20)
	contour_button = _button("地図：通常",rows,func(): set_contour_mode(not contour_mode))
	contour_legend = UI.label("等高線50m・太線250m／真上から表示",rows,12)
	contour_legend.hide()
	road_button = _button("道編集：OFF",rows,func(): set_road_editing(not road_editing))
	edge_button = _button("編集対象：タイル",rows,func(): set_edge_editing(not edge_editing))
	edit_help = UI.label("",rows,13)
	edit_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var history := HBoxContainer.new()
	rows.add_child(history)
	undo_button = _button("元に戻す",history,network.undo)
	redo_button = _button("やり直す",history,network.redo)
	_button("道データをエクスポート",rows,_choose_export)
	_button("道データを読み込む",rows,_choose_import)
	status = UI.label("",rows,13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var save_hint := UI.label("編集内容はエクスポートして保存してください。",rows,12)
	save_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("開発者モードを終了",rows,close)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	file_dialog.use_native_dialog = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	file_dialog.filters = PackedStringArray(["*.json ; 道データ JSON"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)
	panel.hide()
	_activate_network()
	_refresh()

func _button(caption: String, parent: Control, action: Callable) -> Button:
	var button := Style.button(caption,parent,action)
	button.custom_minimum_size = Vector2(0,32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",16)
	return button

func open() -> void:
	enabled = true
	panel.show()
	_refresh()

func close() -> void:
	set_road_editing(false)
	set_contour_mode(false)
	enabled = false
	panel.hide()
	_refresh()

func set_contour_mode(value: bool) -> void:
	if value and not enabled: return
	if value == contour_mode: return
	contour_mode = value
	main.dragging = false
	main.district_click_serial += 1
	if value:
		previous_oblique = main.elevation.enabled
		previous_basemap_visible = main.tile_root.visible
		main.set_oblique(false)
		if contour_layer == null:
			contour_layer = load("res://scripts/map/contour_map_layer.gd").new()
			main.add_child(contour_layer)
		main.tile_root.hide()
		contour_layer.show()
	else:
		contour_layer.hide()
		main.tile_root.visible = previous_basemap_visible
		main.set_oblique(previous_oblique)
	contour_button.text = "地図：等高線（50m）" if value else "地図：通常"
	contour_legend.visible = value

func _activate_network() -> void:
	network_active = true
	main.connection_layer.select_route("")
	main.connection_layer.hide()
	main.shared_road_layer.hide()
	road_layer.show()
	road_layer.update_view(main.get_visible_world_rect().grow(2.0), main.camera.zoom.x)

func set_road_editing(value: bool) -> void:
	if value == road_editing: return
	road_editing = value
	main.dragging = false
	main.district_click_serial += 1
	if value:
		_activate_network()
		main.district_info.hide_info()
		clock_was_processing = main.game_clock.is_processing()
		main.game_clock.set_process(false)
		if main.camera.zoom.x < Grid.MIN_DRAW_ZOOM: main.set_map_zoom(Grid.MIN_DRAW_ZOOM)
	else:
		main.game_clock._last_tick_usec = Time.get_ticks_usec()
		main.game_clock.set_process(clock_was_processing)
	road_layer.editing = value
	road_layer.queue_redraw()
	_refresh()

func click_world(world: Vector2) -> bool:
	if not enabled or not road_editing: return false
	if main.camera.zoom.x < Grid.MIN_DRAW_ZOOM:
		status.text = "道を編集するには200%以上に拡大してください。"
		return true
	if edge_editing:
		var edge := _pick_edge(world)
		if edge.size() == 2: network.toggle_edge(edge[0],edge[1])
		else: status.text = "道の線の中央付近をクリックしてください。"
		return true
	if not network.toggle(Grid.cell_at(world)):
		status.text = "六角形が表示される範囲をクリックしてください。"
	return true

func set_edge_editing(value: bool) -> void:
	edge_editing = value
	road_layer.edge_editing = value
	road_layer.queue_redraw()
	_refresh()

func _pick_edge(world: Vector2) -> Array[Vector2i]:
	var cell := Grid.cell_at(world)
	var candidates := [cell]
	for delta in Network.NEIGHBORS: candidates.append(cell+delta)
	var best: Array[Vector2i] = []
	var distance: float = 8.0 / main.camera.zoom.x
	var point: Vector2 = main.elevation.project(world)
	for a in candidates:
		if not network.cells.has(a): continue
		for delta in Network.NEIGHBORS:
			var b: Vector2i = a+delta
			if not network.cells.has(b): continue
			var start: Vector2 = main.elevation.project(Grid.center(a))
			var end: Vector2 = main.elevation.project(Grid.center(b))
			# Avoid ambiguous junctions; target the middle of the segment.
			var nearest := Geometry2D.get_closest_point_to_segment(point,start.lerp(end,0.2),start.lerp(end,0.8))
			var gap := point.distance_to(nearest)
			if gap < distance:
				distance = gap
				best.assign([a,b])
	return best

func _refresh() -> void:
	if status == null: return
	var disconnected := {}
	if enabled:
		for cell in main.district_office_layer.cell_districts:
			if not network.has_connection(cell):
				disconnected[main.district_office_layer.cell_districts[cell]] = true
	main.territory_borders.disconnected_offices = disconnected
	main.territory_borders.queue_redraw()
	road_button.text = "道編集：ON（時間停止中）" if road_editing else "道編集：OFF"
	edge_button.text = "編集対象：接続線" if edge_editing else "編集対象：タイル"
	edge_button.disabled = not road_editing
	edit_help.text = ("線の中央をクリック：接続を削除\n赤い破線をクリック：接続を復元" if edge_editing else "六角形をクリック：道を追加／削除\n隣接する道は自動で接続します。") + "\nドラッグ：地図移動　ホイール：拡大縮小"
	undo_button.disabled = network.undo_cells.is_empty()
	redo_button.disabled = network.redo_cells.is_empty()
	status.text = "道：%d枚　薄赤：未接続の郡 %d" % [network.cells.size(),disconnected.size()]

func _choose_export() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "道データをエクスポート"
	file_dialog.current_file = "hex_roads.json"
	file_dialog.popup_centered_ratio(0.7)

func _choose_import() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "道データを読み込む（編集中の道を置き換え）"
	file_dialog.current_file = ""
	file_dialog.popup_centered_ratio(0.7)

func _file_selected(path: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var error: Error = network.export_file(path)
		status.text = "道データを書き出しました。" if error == OK else "書き出しに失敗しました：" + error_string(error)
		status.tooltip_text = path
	else:
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null:
			status.text = "ファイルを読み込めません。"
			return
		if file.get_length() > 16 * 1024 * 1024:
			status.text = "道データのファイルが大きすぎます。"
			return
		var value: Variant = JSON.parse_string(file.get_as_text())
		if not network.load_document(value):
			status.text = network.last_error
			return
		_activate_network()
		status.text = "道データを読み込みました（%d枚）。" % network.cells.size()
		status.tooltip_text = path
