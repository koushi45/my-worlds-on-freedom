extends Node2D

const MapTileCatalogScript = preload("res://scripts/map/map_tile_catalog.gd")
const PoliticalLayerScript = preload("res://scripts/map/political_boundary_layer.gd")

const WORLD_SIZE := Vector2(8192.0, 8192.0)
const MIN_ZOOM := 0.5
const MAX_ZOOM := 4.0
const DETAIL_ZOOM := 1.0
const ZOOM_MULTIPLIERS := [1.0, 2.0, 4.0, 8.0, 12.0]
const LOD_NAMES := ["全国", "地方", "地域", "狭域", "詳細"]
const PAN_SPEED := 720.0
# Developer tools remain available explicitly, never in the game view.
var developer_ui := "--developer-ui" in OS.get_cmdline_user_args()

@onready var tile_root: Node2D = $MapTiles
@onready var camera: Camera2D = $MapCamera
@onready var lod_label: Label = $Interface/InfoPanel/Margin/VBox/LodLabel
@onready var tile_label: Label = $Interface/InfoPanel/Margin/VBox/TileLabel

var elevation = preload("res://scripts/map/elevation_surface.gd").new()
var catalog = MapTileCatalogScript.new()
var loaded_tiles: Dictionary = {}
var lod_level := 0
var base_zoom := 0.1
var dragging := false
var initialized := false
var political_layer: Node2D
var river_layer: Node2D
var lake_layer: Node2D
var settlement_layer: Node2D
var settlement_panel: Node
var connection_layer: Node2D
var shared_road_layer: Node2D
var connection_panel: Node
var district_layer: Node2D
var kamon_layer: Node2D
var district_panel: Node
var district_selection_mode := false
var selection_label: Label
var tilt_toggle: CheckButton
var current_road_region := "all"
var road_focus_active := false
var press_position := Vector2.ZERO
var drag_moved := false
var last_view_state: Array = []
var visible_refresh_count := 0
var asset_stream: Node
var pending_tiles: Dictionary = {}
var overview: MeshInstance2D
var overviews: Dictionary = {}
var cpu_jobs: Node
var required_tiles: Dictionary = {}
var required_bounds: Dictionary = {}
var prefetch_tiles: Array = []
var prefetch_priorities: Dictionary = {}
var detail_active := false
var low_memory_mode := false
var prefetch_limit := 24
var previous_camera := Vector2.ZERO
var previous_view_time := 0
var view_velocity := Vector2.ZERO
var main_update_us := 0
var coverage_missing_frames := 0
var map_memory_budget_mib := 128 if OS.has_feature("android") else 192
var tile_swaps := 0
var district_click_serial := 0
var officer_panel: Node
var scenario: Dictionary = {}
var officer_registry: RefCounted
var game_clock: Node
var time_hud: CanvasLayer
var governance_registry: RefCounted
var game_menu: CanvasLayer
var territory_borders: Node2D
var bgm_player: AudioStreamPlayer
var bgm_tracks: Array[AudioStream] = []
var bgm_track_index := 0
var district_info: CanvasLayer


func _ready() -> void:
	_setup_bgm()
	if OS.has_feature("android"):Engine.max_fps=30
	for argument in OS.get_cmdline_user_args():
		if argument in ["--map-fps=30","--map-fps=60"]:Engine.max_fps=int(argument.get_slice("=",1))
	asset_stream=preload("res://scripts/map/map_asset_stream.gd").new()
	asset_stream.elevation_fingerprint=elevation.fingerprint()
	add_child(asset_stream)
	cpu_jobs = preload("res://scripts/map/map_cpu_jobs.gd").new()
	add_child(cpu_jobs)
	_setup_overviews()
	if overviews.size()!=2:
		MapDiagnostics.record("startup_map_failed", {"reason":"resident_backdrop_missing"})
		return
	RenderingServer.set_default_clear_color(Color("#1d3948"))
	var load_error: Error = catalog.load_manifest()
	if load_error != OK:
		lod_label.text = "地図マニフェストを読み込めません"
		printerr("Map manifest load failed: ", error_string(load_error))
		return

	political_layer = PoliticalLayerScript.new()
	political_layer.elevation = elevation
	political_layer.cpu_jobs = cpu_jobs
	political_layer.name = "PoliticalBoundaries"
	add_child(political_layer)
	district_layer = preload("res://scripts/map/district_layer.gd").new()
	# The game uses the same provisional district set as the current Windows release.
	if not developer_ui: district_layer.unconfirmed_mode = true; district_layer.review_mode = true
	if district_layer.unconfirmed_mode:
		district_layer.independent_geometry = preload("res://scripts/map/independent_district_geometry.gd").new()
	district_layer.elevation = elevation
	district_layer.asset_stream = asset_stream
	district_layer.cpu_jobs = cpu_jobs
	district_layer.name = "Districts"
	add_child(district_layer)
	var water: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/hydrography/water_registry.json"))
	river_layer = preload("res://scripts/map/water_layer.gd").new()
	river_layer.name = "Rivers"
	river_layer.kind = "rivers"
	river_layer.records = water["rivers"]
	for area in water["lakes"]:
		if int(area["source_type"])==1: river_layer.records.append(area)
	river_layer.elevation = elevation
	river_layer.cpu_jobs = cpu_jobs
	add_child(river_layer)
	lake_layer = preload("res://scripts/map/water_layer.gd").new()
	lake_layer.name = "Lakes"
	lake_layer.kind = "lakes"
	for area in water["lakes"]:
		if int(area["source_type"])!=1: lake_layer.records.append(area)
	lake_layer.elevation = elevation
	lake_layer.cpu_jobs = cpu_jobs
	add_child(lake_layer)
	settlement_layer = preload("res://scripts/map/settlement_layer.gd").new()
	settlement_layer.elevation = elevation
	add_child(settlement_layer)
	district_layer.settlements = settlement_layer
	connection_layer = preload("res://scripts/map/road_connection_layer.gd").new()
	connection_layer.elevation = elevation
	connection_layer.settlements = settlement_layer
	add_child(connection_layer)
	shared_road_layer = preload("res://scripts/map/shared_road_layer.gd").new()
	shared_road_layer.elevation = elevation
	shared_road_layer.cpu_jobs = cpu_jobs
	shared_road_layer.game_connections = connection_layer
	add_child(shared_road_layer)
	connection_layer.shared_renderer = shared_road_layer
	settlement_layer.roads = connection_layer
	if developer_ui:
		_build_developer_interface()
		$Interface.show()
	else:
		# Keep the underlying records without creating browser panels or dialogs.
		officer_registry = preload("res://scripts/game/officer_registry.gd").new()
		if officer_registry.load_data() != OK: push_error(officer_registry.last_error)
		lod_label = null
		tile_label = null
		$Interface.queue_free()
	scenario = officer_registry.scenario
	governance_registry = preload("res://scripts/game/governance_registry.gd").new()
	if governance_registry.load_data() != OK:
		push_error(governance_registry.last_error)
		return

	kamon_layer = preload("res://scripts/map/kamon_layer.gd").new()
	kamon_layer.name = "Kamon"
	kamon_layer.district_layer = district_layer
	kamon_layer.elevation = elevation
	kamon_layer.governance_registry = governance_registry
	add_child(kamon_layer)
	if district_layer.independent_geometry != null:
		for id in governance_registry.districts:
			governance_registry.districts[id].point = district_layer.records[id].label
			governance_registry.districts[id].geometry_note = "郡境は国境から独立しています。陸続きの飛び地は近隣郡へ統合し、離島は別郡として、各郡を一つの外周に整理しています。境界付近のクリックは最寄りの一郡に確定します。"
	camera.position = WORLD_SIZE * 0.5
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_recalculate_base_zoom()
	_apply_lod(false)
	if DisplayServer.get_name() != "headless":
		var warmup=preload("res://scripts/map/map_label_warmup.gd").new()
		for site in settlement_layer.data.sites:warmup.labels.append({"text":site.display_name,"size":16,"outline":5})
		add_child(warmup)
		await warmup.finished
	# Both projection backdrops exist before input is accepted.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	initialized = true
	game_clock = preload("res://scripts/game/game_clock.gd").new()
	game_clock.name = "GameClock"
	add_child(game_clock)
	game_clock.set_process(false)
	time_hud = preload("res://scripts/game/time_hud.gd").new()
	time_hud.name = "TimeHUD"
	time_hud.clock = game_clock
	add_child(time_hud)
	district_info = preload("res://scripts/game/district_selection_info.gd").new()
	district_info.name = "DistrictSelectionInfo"
	add_child(district_info)
	var restoring: bool = not GameSession.pending.is_empty()
	GameSession.apply_to(self)
	if not restoring and not GameSession.player_house.is_empty():
		for r in governance_registry.districts.values():
			if r.house_id == GameSession.player_house:
				set_map_zoom(MIN_ZOOM)
				camera.position = elevation.project(Vector2(r.point[0],r.point[1]))
				_clamp_camera()
				break
	territory_borders = preload("res://scripts/game/territory_borders.gd").new()
	territory_borders.main = self
	add_child(territory_borders)
	kamon_layer.territory_borders = territory_borders
	kamon_layer.update_view(get_visible_world_rect().grow(2.0),camera.zoom.x)
	kamon_layer.queue_redraw()
	game_menu = preload("res://scripts/game/game_menu.gd").new()
	game_menu.main = self
	add_child(game_menu)
	# Geometry preparation is loading time, not elapsed simulation time.
	game_clock._last_tick_usec = Time.get_ticks_usec()
	game_clock.set_process(true)
	_refresh_visible_tiles()
	set_process(true)
	MapDiagnostics.main = self
	MapDiagnostics.record("map_ready")

func _setup_bgm() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "MainMapBGM"
	var eight_mountains := preload("res://assets/audio/eight_mountains.ogg").duplicate() as AudioStreamOggVorbis
	eight_mountains.loop = false
	var rise_again := preload("res://assets/audio/rise_again_alternative.ogg").duplicate() as AudioStreamOggVorbis
	rise_again.loop = false
	bgm_tracks = [eight_mountains,rise_again]
	bgm_track_index = 0
	bgm_player.stream = bgm_tracks[bgm_track_index]
	add_child(bgm_player)
	bgm_player.finished.connect(_play_next_bgm)
	DisplaySettings.bgm_volume_changed.connect(_set_bgm_volume)
	_set_bgm_volume(DisplaySettings.bgm_volume)
	bgm_player.play()

func _play_next_bgm() -> void:
	if bgm_tracks.is_empty(): return
	bgm_track_index = (bgm_track_index+1)%bgm_tracks.size()
	bgm_player.stream = bgm_tracks[bgm_track_index]
	bgm_player.play()

func _set_bgm_volume(value: float) -> void:
	if bgm_player != null: bgm_player.volume_linear = value


func _build_developer_interface() -> void:
	connection_panel = preload("res://scripts/map/road_connection_panel.gd").new()
	connection_panel.main = self
	connection_panel.layer = connection_layer
	add_child(connection_panel)
	settlement_panel = preload("res://scripts/map/settlement_panel.gd").new()
	settlement_panel.main = self
	settlement_panel.layer = settlement_layer
	add_child(settlement_panel)
	selection_label = Label.new()
	selection_label.text = "領域をクリックで選択"
	$Interface/InfoPanel/Margin/VBox.add_child(selection_label)
	district_panel = preload("res://scripts/map/district_panel.gd").new()
	district_panel.main = self
	district_panel.layer = district_layer
	add_child(district_panel)
	var relief_toggle := CheckButton.new()
	relief_toggle.text = "標高レイヤー"
	relief_toggle.button_pressed = true
	relief_toggle.toggled.connect(set_relief_visible)
	$Interface/InfoPanel/Margin/VBox.add_child(relief_toggle)
	tilt_toggle = CheckButton.new()
	tilt_toggle.text = "立体表示（傾斜・起伏）"
	tilt_toggle.button_pressed = true
	tilt_toggle.toggled.connect(set_oblique)
	$Interface/InfoPanel/Margin/VBox.add_child(tilt_toggle)
	var water_controls := HBoxContainer.new()
	for layer in [river_layer,lake_layer]:
		var toggle := CheckButton.new()
		toggle.text = "主要河川" if layer==river_layer else "湖"
		toggle.button_pressed = true
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.toggled.connect(layer.set_visible)
		water_controls.add_child(toggle)
	$Interface/InfoPanel/Margin/VBox.add_child(water_controls)
	var biwa_button := Button.new()
	biwa_button.text = "琵琶湖へ移動"
	biwa_button.pressed.connect(focus_biwa)
	$Interface/InfoPanel/Margin/VBox.add_child(biwa_button)
	var legend := Label.new()
	legend.text = "標高  低地 → 丘陵 → 山岳\n0 m    300 m    1,200 m    3,000 m+\n起伏は視認性のため強調しています"
	legend.add_theme_font_size_override("font_size",12)
	$Interface/InfoPanel/Margin/VBox.add_child(legend)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0,0.3333,0.6667,1.0])
	ramp.colors = PackedColorArray([Color("#becc99"),Color("#88a96f"),Color("#8d9971"),Color("#eee9db")])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	var ramp_view := TextureRect.new()
	ramp_view.texture = ramp_texture
	ramp_view.custom_minimum_size = Vector2(0,10)
	ramp_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	$Interface/InfoPanel/Margin/VBox.add_child(ramp_view)
	var kyushu_button := Button.new()
	kyushu_button.text = "九州へ移動"
	kyushu_button.pressed.connect(focus_kyushu)
	$Interface/InfoPanel/Margin/VBox.add_child(kyushu_button)
	for region in [["shikoku", "四国へ移動"], ["chugoku", "中国地方へ移動"], ["honshu", "近畿以東へ移動"]]:
		var button := Button.new()
		button.text = region[1]
		button.pressed.connect(focus_region.bind(region[0]))
		$Interface/InfoPanel/Margin/VBox.add_child(button)
	var credits := Label.new()
	credits.text = "旧国境界: Artanisen / まいまいようお（加工）CC BY-SA 4.0"
	credits.add_theme_font_size_override("font_size",11)
	$Interface/InfoPanel/Margin/VBox.add_child(credits)
	var attribution_button := Button.new()
	attribution_button.text = "出典・ライセンス"
	attribution_button.pressed.connect(show_attribution)
	$Interface/InfoPanel/Margin/VBox.add_child(attribution_button)
	officer_panel = preload("res://scripts/game/officer_panel.gd").new()
	officer_panel.main = self
	add_child(officer_panel)
	officer_registry = officer_panel.registry


func _process(delta: float) -> void:
	if not initialized:
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		camera.position += direction * PAN_SPEED * delta / camera.zoom.x
		_clamp_camera()
	var update_start := Time.get_ticks_usec()
	_refresh_visible_tiles()
	_pump_tiles()
	main_update_us = Time.get_ticks_usec()-update_start
	if overview == null or not overview.visible:
		coverage_missing_frames += 1
		if coverage_missing_frames == 1: MapDiagnostics.record("map_coverage_error")


func _unhandled_input(event: InputEvent) -> void:
	if not initialized:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(camera.zoom.x*1.3, event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(camera.zoom.x/1.3, event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				press_position = event.position
				drag_moved = false
			elif dragging and event.button_index == MOUSE_BUTTON_LEFT and not drag_moved:
				if district_selection_mode:
					_select_district_async(event.position)
					dragging = false
					get_viewport().set_input_as_handled()
					return
				var site_id: String = settlement_layer.pick(event.position)
				if not site_id.is_empty():
					district_click_serial += 1
					InteractionAudio.play_click()
					district_info.hide_info()
					settlement_layer.selected_id = site_id
					settlement_layer.queue_redraw()
					if developer_ui: settlement_panel.show_site(site_id)
				elif territory_borders != null and territory_borders.country_mode: select_country(_screen_to_world(event.position))
				else: _select_district_async(event.position)
			dragging = event.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		drag_moved = drag_moved or event.position.distance_to(press_position) > 4.0
		if drag_moved:
			camera.position -= event.relative / camera.zoom.x
		_clamp_camera()
		get_viewport().set_input_as_handled()


func _set_lod(new_level: int, mouse_position: Vector2) -> void:
	new_level = clampi(new_level, 0, ZOOM_MULTIPLIERS.size() - 1)
	if new_level == lod_level:
		return
	road_focus_active = false
	var world_before := _screen_to_display(mouse_position)
	lod_level = new_level
	_apply_lod(true)
	var world_after := _screen_to_display(mouse_position)
	camera.position += world_before - world_after
	_clamp_camera()
	_refresh_visible_tiles()


func _apply_lod(clear_tiles: bool) -> void:
	var zoom_value: float = MAX_ZOOM if lod_level == 4 else clampf(base_zoom * float(ZOOM_MULTIPLIERS[lod_level]),MIN_ZOOM,MAX_ZOOM)
	camera.zoom = Vector2.ONE * zoom_value
	if zoom_value>=1.08:detail_active=true
	elif zoom_value<0.92:detail_active=false
	if clear_tiles:
		_clear_loaded_tiles()
	_update_status()

func set_map_zoom(value: float) -> void:
	# Fitted national views reserve panel space and may be below the normal fit.
	camera.zoom = Vector2.ONE*clampf(value,MIN_ZOOM,MAX_ZOOM)
	var thresholds := [0.0,0.18,0.4,0.75,1.5]
	while lod_level < 4 and camera.zoom.x >= float(thresholds[lod_level+1])*1.08: lod_level += 1
	while lod_level > 0 and camera.zoom.x < float(thresholds[lod_level])*0.92: lod_level -= 1
	if camera.zoom.x >= 1.08: detail_active = true
	elif camera.zoom.x < 0.92: detail_active = false

func _zoom_at(value: float, mouse_position: Vector2) -> void:
	value = clampf(value,MIN_ZOOM,MAX_ZOOM)
	if is_equal_approx(value,camera.zoom.x): return
	MapDiagnostics.note_zoom(camera.zoom.x, value, mouse_position)
	road_focus_active = false
	var before := _screen_to_display(mouse_position)
	set_map_zoom(value)
	camera.position += before-_screen_to_display(mouse_position)
	_clamp_camera()
	# Apply visibility once in _process, even when many wheel events arrive.


func _refresh_visible_tiles() -> void:
	var state: Array = [camera.position,camera.zoom,get_viewport_rect().size,lod_level,elevation.enabled,catalog.detail_tiles.size()]
	if state == last_view_state: return
	last_view_state = state
	visible_refresh_count += 1
	camera.force_update_scroll()
	var view_rect := get_visible_world_rect().grow(2.0)
	if political_layer != null:
		political_layer.update_view(view_rect, camera.zoom.x)
	if district_layer != null: district_layer.update_view(view_rect,camera.zoom.x)
	if kamon_layer != null: kamon_layer.update_view(view_rect,camera.zoom.x)
	if river_layer != null:
		river_layer.update_view(view_rect,camera.zoom.x)
		lake_layer.update_view(view_rect,camera.zoom.x)
	if settlement_layer != null: settlement_layer.update_view(view_rect,camera.zoom.x)
	if connection_layer != null: connection_layer.update_view(view_rect,camera.zoom.x)
	if shared_road_layer != null: shared_road_layer.update_view(view_rect,camera.zoom.x)
	var visible_tiles: Array = _desired_tiles(view_rect)
	var required: Dictionary = {}
	required_bounds.clear()
	for tile in visible_tiles:
		var tile_id := str(tile["tile_id"])
		required[tile_id] = true
		var b: Array=tile["global_viewport"]
		required_bounds[tile_id]=Rect2(Vector2(b[0],b[1]),Vector2(b[2]-b[0],b[3]-b[1]))
		if not loaded_tiles.has(tile_id):
			pending_tiles[tile_id]=tile
		if loaded_tiles.has(tile_id) and loaded_tiles[tile_id].has_method("set_view_zoom"): loaded_tiles[tile_id].set_view_zoom(camera.zoom.x)
	for id in pending_tiles.keys():
		if not required.has(id):pending_tiles.erase(id)

	required_tiles = required
	_plan_prefetch(view_rect)
	_retire_tiles()
	_update_status()


func _create_tile(tile: Dictionary) -> void:
	var baked_path := _tile_path(tile)
	if baked_path.is_empty() or asset_stream.failed.has(baked_path) or asset_stream.denied.has(baked_path):
		pending_tiles.erase(str(tile["tile_id"]))
		return
	var baked: Resource = asset_stream.fetch(baked_path)
	if baked == null: return
	if tile.has("density"):
		var detail = preload("res://scripts/map/detail_map_tile.gd").new()
		detail.name = str(tile["tile_id"])
		detail.definition = tile
		detail.elevation = elevation
		detail.view_zoom = camera.zoom.x
		detail.baked = baked
		_mark_tile(detail,tile,baked_path)
		tile_root.add_child(detail)
		loaded_tiles[str(tile["tile_id"])] = detail
		return
	var texture_path := "res://" + str(tile["files"]["composite"])
	var texture: Texture2D = baked.textures[0]
	if texture == null:
		printerr("Map tile load failed: ", texture_path)
		return

	var mesh: ArrayMesh = baked.mesh
	var sprite := MeshInstance2D.new()
	sprite.name = str(tile["tile_id"])
	sprite.mesh = mesh
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var relief := MeshInstance2D.new()
	relief.name = "Elevation"
	relief.mesh = mesh
	relief.texture = baked.textures[1]
	relief.visible = elevation.relief_visible
	relief.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.add_child(relief)
	var coast := MeshInstance2D.new()
	coast.name = "Coastline"
	coast.mesh = mesh
	coast.texture = baked.textures[2]
	coast.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.add_child(coast)
	_mark_tile(sprite,tile,baked_path)
	tile_root.add_child(sprite)
	loaded_tiles[str(tile["tile_id"])] = sprite


func _clear_loaded_tiles(projection_changed: bool = false) -> void:
	last_view_state = []
	pending_tiles.clear()
	if projection_changed:
		# The replacement projection's resident backdrop is already prepared.
		for node in loaded_tiles.values(): node.queue_free()
		loaded_tiles.clear()


func _recalculate_base_zoom() -> void:
	var viewport_size := Vector2(get_viewport_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	base_zoom = minf(viewport_size.x / WORLD_SIZE.x, viewport_size.y / WORLD_SIZE.y) * 0.94
	_apply_lod(false)
	_clamp_camera()


func _on_viewport_size_changed() -> void:
	var previous_zoom := camera.zoom.x
	var fitted := is_equal_approx(previous_zoom,base_zoom)
	_recalculate_base_zoom()
	if not fitted: set_map_zoom(previous_zoom)
	if road_focus_active:
		if current_road_region == "connection": connection_panel.focus_current()
		else: focus_road_region(current_road_region)
	_refresh_visible_tiles()


func _clamp_camera() -> void:
	# A fitted road view reserves the left panel and may need sea outside the canvas.
	if road_focus_active: return
	var half_view := Vector2(get_viewport_rect().size) * 0.5 / camera.zoom.x
	var min_position := half_view
	var max_position := WORLD_SIZE - half_view
	camera.position.x = WORLD_SIZE.x * 0.5 if min_position.x > max_position.x else clampf(camera.position.x, min_position.x, max_position.x)
	camera.position.y = WORLD_SIZE.y * 0.5 if min_position.y > max_position.y else clampf(camera.position.y, min_position.y, max_position.y)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return elevation.unproject(_screen_to_display(screen_position))


func _screen_to_display(screen_position: Vector2) -> Vector2:
	var viewport_center := Vector2(get_viewport_rect().size) * 0.5
	return camera.position + (screen_position - viewport_center) / camera.zoom.x


func get_visible_world_rect() -> Rect2:
	var world_view_size := Vector2(get_viewport_rect().size) / camera.zoom.x
	var rect := Rect2(camera.position - world_view_size * 0.5, world_view_size)
	var source := Rect2(elevation.unproject(rect.position),Vector2.ZERO)
	for p in [rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
		source = source.expand(elevation.unproject(p))
	# Include elevated terrain that projects into view from beyond an edge.
	return source.grow(120.0 if elevation.enabled else 0.0)


func set_relief_visible(value: bool) -> void:
	elevation.relief_visible = value
	for tile in loaded_tiles.values():
		if tile.has_method("set_view_zoom"): tile.queue_redraw()
		else: tile.get_node("Elevation").visible = value


func set_oblique(value: bool) -> void:
	if tilt_toggle != null: tilt_toggle.set_pressed_no_signal(value)
	var center: Vector2 = elevation.unproject(camera.position)
	elevation.enabled = value
	_show_overview()
	camera.position = elevation.project(center)
	political_layer.invalidate_surface()
	district_layer.invalidate_surface()
	kamon_layer.invalidate_surface()
	river_layer.invalidate_surface()
	lake_layer.invalidate_surface()
	connection_layer.invalidate_surface()
	shared_road_layer.invalidate_surface()
	settlement_layer.queue_redraw()
	_clear_loaded_tiles(true)
	if road_focus_active:
		if current_road_region == "connection":
			connection_panel.focus_current()
			return
		focus_road_region(current_road_region)
		return
	_clamp_camera()
	_refresh_visible_tiles()


func get_loaded_tile_count() -> int:
	return loaded_tiles.size()


func get_lod_level() -> int:
	return lod_level


func select_country(world_point: Vector2) -> void:
	district_info.hide_info()
	district_layer.select_key("")
	var country_name: String = political_layer.select_at(world_point)
	if not country_name.is_empty(): InteractionAudio.play_click()
	if selection_label != null: selection_label.text = "選択: " + country_name if not country_name.is_empty() else "未選択（未収録地域・離島は選択対象外）"


func focus_kyushu() -> void:
	focus_region("kyushu")


func focus_road_region(region_id: String) -> void:
	road_focus_active = true
	current_road_region = region_id
	var bounds := Rect2()
	var first := true
	if region_id.begins_with("site:"):
		var site: Dictionary = settlement_layer.lookup[region_id.trim_prefix("site:")]
		bounds = Rect2(elevation.project(settlement_layer.point(site["point"])),Vector2.ZERO).grow(65)
		first = false
	else:
		for site in settlement_layer.data["sites"]:
			if site["point"] == null or site["adoption_status"] != "accepted": continue
			if region_id != "all" and site["region_id"] != region_id.trim_prefix("sites:"): continue
			var p: Vector2 = elevation.project(settlement_layer.point(site["point"]))
			if first: bounds = Rect2(p,Vector2.ZERO); first = false
			else: bounds = bounds.expand(p)
		bounds = bounds.grow(12)
	if first: return
	var available := get_viewport_rect().size - (Vector2(470,150) if developer_ui else Vector2(32,32))
	var zoom_value := minf(MAX_ZOOM,minf(available.x/maxf(bounds.size.x,1),available.y/maxf(bounds.size.y,1)))
	lod_level = 0
	for level in range(5):
		if base_zoom*float(ZOOM_MULTIPLIERS[level]) <= zoom_value: lod_level = level
	_apply_lod(true)
	set_map_zoom(zoom_value)
	camera.position = bounds.get_center() - (Vector2(185.0/zoom_value,0) if developer_ui else Vector2.ZERO)
	_clamp_camera()
	_refresh_visible_tiles()


func focus_biwa() -> void:
	road_focus_active = false
	for lake in lake_layer.records:
		if lake["name"]!="BIWA KO": continue
		lod_level = 4
		_apply_lod(true)
		var point: Array = lake["label_point"]
		camera.position = elevation.project(Vector2(float(point[0]),float(point[1])))
		_clamp_camera()
		_refresh_visible_tiles()
		return


func focus_region(region_id: String) -> void:
	road_focus_active = false
	lod_level = 1 if region_id=="honshu" else 2
	_apply_lod(true)
	var bounds: Array = political_layer.data["regional_bounds"][region_id]
	camera.position = elevation.project(Vector2((float(bounds[0])+float(bounds[2]))*0.5, (float(bounds[1])+float(bounds[3]))*0.5))
	_clamp_camera()
	_refresh_visible_tiles()


func show_attribution() -> void:
	if not developer_ui: return
	var dialog := AcceptDialog.new()
	dialog.title = "地図データの出典"
	dialog.dialog_text = "基盤: Natural Earth 1:10m Land 5.1.1（Public Domain）\n旧国境界画像: Ancient Provinces of Japan Ryoseikoku Map\n作者: Artanisen / 更新者: まいまいようお\n出典: https://commons.wikimedia.org/wiki/File:Ancient_Provinces_of_Japan_Ryoseikoku_Map.png\n九州部分を画像加工・位置補正・トレース・陸地クリップした派生データ v1.0.0\n境界データ: CC BY-SA 4.0\nhttps://creativecommons.org/licenses/by-sa/4.0/\n付属の LICENSE-CC-BY-SA-4.0.txt と ATTRIBUTION.md もご覧ください。"
	$Interface.add_child(dialog)
	dialog.dialog_text = dialog.dialog_text.replace("九州部分を", "九州・四国・中国地方の本土部分を")
	dialog.dialog_text += "\n\n標高: Mapzen / AWS Terrain Tiles (Terrarium)\nSRTM / GMTED2010: U.S. Geological Survey\nETOPO1: NOAA（Public Domain）\nhttps://registry.opendata.aws/terrain-tiles/\n日本用投影・基盤陸地クリップ・陰影生成・表示用起伏強調を実施。"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.dialog_text += "\n\n川・湖: 国土地理院『地球地図日本 第2版 水系』（2011年）\nhttps://www.gsi.go.jp/kankyochiri/gm_jpn.html\n投影変換・基盤陸地クリップ・湖面分割・着色を行った加工データ。\n現代の水系を使用（戦国期の河道復元ではありません）。\n利用条件: 国土地理院コンテンツ利用規約 / PDL1.0"
	dialog.canceled.connect(dialog.queue_free)
	if district_layer.initialized:
		dialog.dialog_text += "\n\n郡の比較候補：旧国・旧郡境界データセット（CODH）\n幕末明治地勢地図境界データ（人間文化研究機構）を加工\ndoi:10.20676/00000454 / CC BY-NC 4.0\n現行国へのクリップ・未確定領域の保持・地表分割を実施。\n1582年の確定郡境ではありません。"
	dialog.popup_centered()


func _update_status() -> void:
	if lod_label == null or tile_label == null:
		return
	var percent := int(round(camera.zoom.x * 100.0))
	lod_label.text = "%s表示  %d / 5  （%d%%）" % [LOD_NAMES[lod_level], lod_level + 1, percent]
	tile_label.text = "描画タイル: %d　正本座標: 8192 × 8192" % loaded_tiles.size()

func _tile_path(tile: Dictionary) -> String:
	return asset_stream.manifest.get("tiles",{}).get(str(tile["tile_id"])+("_tilt" if elevation.enabled else "_flat"),"")

func _setup_overviews() -> void:
	for mode in ["flat","tilt"]:
		var path: String = asset_stream.manifest.get("overviews",{}).get(mode,"")
		if path.is_empty():
			MapDiagnostics.record("overview_failed", {"mode":mode})
			continue
		# Startup only. Never called from camera or streaming updates.
		var chunk: Resource = load(path)
		if chunk == null: continue
		asset_stream.adopt(path,chunk)
		var node := MeshInstance2D.new()
		node.mesh=chunk.mesh;node.texture=chunk.textures[0];node.z_index=-10
		node.set_meta("path",path)
		tile_root.add_child(node)
		overviews[mode]=node
	_show_overview()

func _show_overview() -> void:
	var mode := "tilt" if elevation.enabled else "flat"
	for key in overviews: overviews[key].visible = key == mode
	overview=overviews.get(mode)

func _desired_tiles(rect: Rect2) -> Array:
	if low_memory_mode:return catalog.get_visible_tiles(mini(lod_level,2),rect) if lod_level>0 else []
	if detail_active and not catalog.detail_tiles.is_empty(): return catalog.get_detail_tiles(rect)
	if lod_level == 0: return [] # Dedicated resident national backdrop.
	return catalog.get_visible_tiles(lod_level,rect)

func _mark_tile(node: Node2D, tile: Dictionary, path: String) -> void:
	var b: Array=tile["global_viewport"]
	node.set_meta("bounds",Rect2(Vector2(b[0],b[1]),Vector2(b[2]-b[0],b[3]-b[1])))
	node.set_meta("path",path)
	node.set_meta("frame",Engine.get_process_frames())
	node.z_index=6 if tile.has("density") else int(tile["lod"])+1
	tile_swaps += 1

func _retire_tiles() -> void:
	var view := get_visible_world_rect()
	for id in loaded_tiles.keys():
		if required_tiles.has(id): continue
		var node: Node2D=loaded_tiles[id]
		var bounds: Rect2=node.get_meta("bounds")
		var retain := false
		if bounds.intersects(view):
			for key in required_tiles:
				if not bounds.intersects(required_bounds[key]):continue
				if not loaded_tiles.has(key):
					if pending_tiles.has(key): retain=true;break
				elif int(loaded_tiles[key].get_meta("frame"))>=Engine.get_process_frames()-1:
					retain=true;break
		if not retain:
			node.queue_free();loaded_tiles.erase(id)

func _plan_prefetch(rect: Rect2) -> void:
	var now:=Time.get_ticks_msec()
	if previous_view_time>0 and now>previous_view_time:
		view_velocity=(camera.position-previous_camera)/float(now-previous_view_time)*1000.0
	previous_view_time=now;previous_camera=camera.position
	prefetch_tiles.clear()
	prefetch_priorities.clear()
	var lead: Vector2=(view_velocity*clampf(asset_stream.latency_ms/1000.0,0.3,0.5)).limit_length(512.0)
	# Projected motion approximates source motion conservatively; the ring covers turns.
	var ahead := Rect2(rect.position+lead,rect.size)
	var neighbors := _desired_tiles(rect.grow(256.0).merge(ahead))
	neighbors.sort_custom(func(a,b):
		var av: Array=a["global_viewport"];var bv: Array=b["global_viewport"]
		return Vector2(av[0],av[1]).distance_squared_to(ahead.get_center()) < Vector2(bv[0],bv[1]).distance_squared_to(ahead.get_center()))
	var next_tiles: Array=[]
	if not detail_active and camera.zoom.x>0.8: next_tiles=catalog.get_detail_tiles(rect)
	elif detail_active and camera.zoom.x<1.25: next_tiles=catalog.get_visible_tiles(3,rect)
	elif lod_level<3: next_tiles=catalog.get_visible_tiles(lod_level+1,rect)
	var seen := required_tiles.duplicate()
	for tile in next_tiles+neighbors:
		if seen.has(tile["tile_id"]):continue
		seen[tile["tile_id"]]=true
		prefetch_tiles.append(tile)
		prefetch_priorities[_tile_path(tile)]=1 if tile in next_tiles else 2
		if prefetch_tiles.size()>=prefetch_limit:break

func _pump_tiles() -> void:
	if asset_stream == null:return
	var vectors: int=political_layer.vector_bytes+river_layer.vector_bytes+lake_layer.vector_bytes+shared_road_layer.vector_bytes
	for node in shared_road_layer.stroke_meshes.values():vectors+=int(node.buffer_bytes)
	vectors+=int(political_layer.coast_mesh.buffer_bytes)+int(political_layer.border_mesh.buffer_bytes)
	asset_stream.budget_bytes=map_memory_budget_mib*1024*1024-cpu_jobs.budget_bytes-vectors
	var keep: Array=[]
	var pins: Array=[]
	for node in overviews.values():pins.append(node.get_meta("path"))
	for node in loaded_tiles.values():pins.append(node.get_meta("path"))
	for tile in pending_tiles.values():keep.append(_tile_path(tile))
	if district_layer!=null:
		keep.append_array(district_layer.pending_resource_paths())
		pins.append_array(district_layer.resident_resource_paths())
	for tile in prefetch_tiles:keep.append(_tile_path(tile))
	keep.append_array(pins)
	asset_stream.set_pins(pins)
	asset_stream.keep_requests(keep)
	var start:=Time.get_ticks_usec()
	for id in pending_tiles.keys():
		_create_tile(pending_tiles[id])
		if loaded_tiles.has(id): pending_tiles.erase(id)
		if Time.get_ticks_usec()-start>1500:break
	for tile in prefetch_tiles:asset_stream.fetch(_tile_path(tile),int(prefetch_priorities.get(_tile_path(tile),3)))
	_retire_tiles()

func has_pending_map_work() -> bool:
	return not initialized or not pending_tiles.is_empty() or asset_stream.has_pending() or not district_layer.waiting_parents.is_empty() or not cpu_jobs.jobs.is_empty() or district_layer.has_pending_batches() or not river_layer.upload_queue.is_empty() or not lake_layer.upload_queue.is_empty() or political_layer.projection_cache.size()<2 or shared_road_layer.projection_cache.size()<2 or river_layer.projection_cache.size()<2 or lake_layer.projection_cache.size()<2

func _select_district_async(screen_point: Vector2) -> void:
	district_click_serial+=1
	var serial:=district_click_serial
	var ground:=_screen_to_world(screen_point)
	var camera_before:=camera.position
	var zoom_before:=camera.zoom
	var radius:float=12.0/camera.zoom.x+(4000.0*elevation.height_scale if elevation.enabled else 0.0)
	var required:Dictionary={}
	for key in district_layer.query(Rect2(ground,Vector2.ZERO).grow(radius+.01)):
		required[district_layer.records[key]["parent"]]=true
	for id in required:district_layer.load_parent(id)
	var deadline:=Time.get_ticks_msec()+10000
	while not required.keys().all(func(id):return district_layer.loaded.has(id)):
		if selection_label != null: selection_label.text="郡データを読み込み中…"
		await get_tree().process_frame
		if serial!=district_click_serial or camera.position!=camera_before or camera.zoom!=zoom_before or (developer_ui and not district_selection_mode):return
		if Time.get_ticks_msec()>deadline:
			if selection_label != null: selection_label.text="郡データを読み込めませんでした"
			return
	var candidates: Array=await district_layer.pick_async(ground)
	if serial!=district_click_serial or camera.position!=camera_before or camera.zoom!=zoom_before or (developer_ui and not district_selection_mode):return
	if not candidates.is_empty(): InteractionAudio.play_click()
	show_district_info(candidates[0] if not candidates.is_empty() else "")
	if developer_ui: district_panel.show_candidates(candidates)
	else:
		political_layer.selected_id = ""
		political_layer.queue_redraw()
		district_layer.select_key(candidates[0] if not candidates.is_empty() else "")

func show_district_info(key: String) -> void:
	if district_info == null: return
	if key.is_empty() or not district_layer.records.has(key):
		district_info.hide_info()
		return
	var district_record: Dictionary = governance_registry.districts.get(key,{})
	var ruler_name: String = governance_registry.ruler_name(district_record) if not district_record.is_empty() else "支配者未詳"
	district_info.show_district(str(district_layer.records[key].name),ruler_name)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		MapDiagnostics.set_suspended(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		MapDiagnostics.set_suspended(false)
		last_view_state=[]
	elif what == NOTIFICATION_OS_MEMORY_WARNING and initialized:
		low_memory_mode=true;prefetch_limit=4
		map_memory_budget_mib=maxi(64,int(map_memory_budget_mib*0.75))
		_clear_loaded_tiles(true)
		MapDiagnostics.record("memory_pressure", {"budget_mib":map_memory_budget_mib})
