extends Node2D
## Screen-space widths, cached projection, viewport culling. No per-frame JSON loads.
const HOUSE_THEME_PATH := "res://data/derived/governance/house_theme_colors_1546.json"
const FALLBACK_THEME_COLOR := Color("#8b7c67")
const DISTRICT_BORDER_WIDTH := 1.4
const INNER_BAND_WIDTH := 9.0
const BORDER_COLOR := Color("#f7f5eb")
const COUNTRY_MAX_ZOOM := 2.0
const TERRITORY_FILL_ALPHA := 0.24
const SELECTION_PULSE_ALPHA := 0.42
const SELECTION_PULSE_SECONDS := 2.4
const INDEPENDENT_FILL_INDEX := "res://data/derived/scenarios/independent_district_fill_meshes.json"
var main: Node
var outlines: Dictionary = {}
var projected: Dictionary = {}
var bounds: Dictionary = {}
var projection_enabled := false
var last_transform := Transform2D()
var draw_counts: Dictionary = {}
var neutral_nodes: Array[MeshInstance2D] = []
var neutral_style: ShaderMaterial
var band_nodes: Array[MeshInstance2D] = []
var district_band_nodes: Array[MeshInstance2D] = []
var country_band_nodes: Array[MeshInstance2D] = []
var band_styles: Dictionary = {}
var theme_colors: Dictionary = {}
var country_projected: Dictionary = {}
var country_bounds: Dictionary = {}
var country_records: Dictionary = {}
var country_mode := true
var loaded_fade_regions := 0
var last_selected := ""
var selection_pulse_phase := 0.0
var selection_pulse_alpha := 0.0
var fill_enabled := false
var fill_meshes: Dictionary = {}
var independent_fill_files: Dictionary = {}
var coastline_only_ids: Dictionary = {}

func _ready() -> void:
	z_index = 22
	neutral_style = ShaderMaterial.new()
	neutral_style.shader = preload("res://scripts/map/line_mesh.gdshader")
	neutral_style.set_shader_parameter("dashed",true)
	neutral_style.set_shader_parameter("half_width",DISTRICT_BORDER_WIDTH * 0.5)
	neutral_style.set_shader_parameter("line_color",Color("#746347"))
	_load_house_theme_colors()
	if main.district_layer.independent_geometry != null:
		_load_independent_fill_index()
		for id in main.district_layer.independent_geometry.extra_districts:
			if main.district_layer.independent_geometry.extra_districts[id].get("coastline_only",false): coastline_only_ids[id] = true
		for id in main.district_layer.independent_geometry.regions:
			var polygons: Array = []
			for polygon in main.district_layer.independent_geometry.regions[id].polygons:
				polygons.append(polygon)
			outlines[id] = polygons
	else:
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/scenarios/district_outlines_1546.json"))
		for id in raw:
			outlines[id] = []
			for ring in raw[id]:
				var points := PackedVector2Array()
				for p in ring: points.append(Vector2(p[0],p[1]))
				outlines[id].append([points])
	rebuild()

func _load_house_theme_colors() -> void:
	if not FileAccess.file_exists(HOUSE_THEME_PATH):
		push_error("House theme colour registry is missing")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(HOUSE_THEME_PATH))
	if not data is Dictionary or not data.get("themes") is Dictionary:
		push_error("House theme colour registry is invalid")
		return
	for house_id in data.themes:
		theme_colors[house_id] = Color(data.themes[house_id].color)

func theme_color(house_id: String) -> Color:
	return theme_colors.get(house_id,FALLBACK_THEME_COLOR)

func _band_style_for(house_id: String) -> ShaderMaterial:
	if band_styles.has(house_id): return band_styles[house_id]
	var style := ShaderMaterial.new()
	style.shader = preload("res://scripts/game/territory_inner_band.gdshader")
	style.set_shader_parameter("band_width",INNER_BAND_WIDTH)
	var color := theme_color(house_id)
	color.a = 0.72
	style.set_shader_parameter("band_color",color)
	band_styles[house_id] = style
	return style

func _load_independent_fill_index() -> void:
	if not FileAccess.file_exists(INDEPENDENT_FILL_INDEX):
		push_error("Independent district fill index is missing")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(INDEPENDENT_FILL_INDEX))
	if not data is Dictionary: return
	var source: String = data.get("source", "")
	if source.is_empty() or FileAccess.get_sha256(source) != data.get("source_sha256", ""):
		push_error("Independent district fill meshes do not match the current polygons")
		return
	for id in data.get("meshes", {}):
		independent_fill_files[id] = data.meshes[id].get("file", "")

func set_fill_enabled(value: bool) -> void:
	fill_enabled = value
	queue_redraw()

func fill_mesh_for(id: String) -> ArrayMesh:
	if fill_meshes.has(id): return fill_meshes[id]
	var file: String = independent_fill_files.get(id, "")
	if file.is_empty() or not FileAccess.file_exists(file): return null
	var stream := FileAccess.open(file,FileAccess.READ)
	if stream == null: return null
	var vertices := PackedVector2Array()
	while stream.get_position() < stream.get_length():
		vertices.append(main.elevation.project(Vector2(stream.get_float(),stream.get_float())))
	if vertices.is_empty(): return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	fill_meshes[id] = mesh
	return mesh

func rebuild() -> void:
	for node in neutral_nodes: node.queue_free()
	for node in band_nodes: node.queue_free()
	neutral_nodes.clear()
	band_nodes.clear()
	district_band_nodes.clear()
	country_band_nodes.clear()
	projected.clear()
	bounds.clear()
	country_projected.clear()
	country_bounds.clear()
	country_records.clear()
	loaded_fade_regions = 0
	fill_meshes.clear()
	projection_enabled = main.elevation.enabled
	for id in outlines:
		if not main.governance_registry.districts.has(id): continue
		var house_id: String = main.governance_registry.districts[id].house_id
		var state: String = GameSession.relation(GameSession.player_house,house_id)
		var rings: Array[PackedVector2Array] = []
		var polygons: Array = []
		var box := Rect2()
		var first := true
		for raw_polygon in outlines[id]:
			var polygon_rings: Array[PackedVector2Array] = []
			for raw in raw_polygon:
				var points := PackedVector2Array()
				for p in raw:
					var v: Vector2 = main.elevation.project(p)
					points.append(v)
					if first: box = Rect2(v,Vector2.ZERO); first = false
					else: box = box.expand(v)
				polygon_rings.append(points)
				rings.append(points)
			polygons.append(polygon_rings)
		projected[id] = {"rings":rings,"polygons":polygons,"state":state,"house_id":house_id}
		bounds[id] = box
		if main.district_layer.independent_geometry != null and not coastline_only_ids.has(id):
			var arrays: Array = preload("res://scripts/map/map_line_geometry.gd").arrays_for(rings)
			if arrays[Mesh.ARRAY_VERTEX].is_empty(): continue
			var node := MeshInstance2D.new()
			node.mesh = ArrayMesh.new()
			node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
			node.material = neutral_style
			node.z_index = -1 # Above countries, below coloured ownership outlines.
			add_child(node)
			neutral_nodes.append(node)
	_create_band_nodes(false,district_band_nodes)
	_build_country_geometry()
	queue_redraw()

func _create_band_nodes(countries: bool, target: Array[MeshInstance2D]) -> void:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/scenarios/territory_fades/index.json"))
	var records: Dictionary = country_projected if countries else projected
	var records_by_house := {}
	for id in records:
		if not countries and coastline_only_ids.has(id): continue
		var house_id: String = records[id].house_id
		if not records_by_house.has(house_id): records_by_house[house_id] = []
		records_by_house[house_id].append(id)
	for house_id in records_by_house:
		var vertices := PackedVector2Array()
		var distances := PackedVector2Array()
		for id in records_by_house[house_id]:
			var key: String = ("country:" if countries else "district:") + str(id)
			if not index.has(key):
				push_error("Territory fade mesh is missing: " + key)
				continue
			var stream := FileAccess.open(index[key],FileAccess.READ)
			if stream == null:
				push_error("Cannot open territory fade mesh: " + key)
				continue
			var data := stream.get_buffer(stream.get_length()).to_float32_array()
			var projected_points := {}
			for i in range(0,data.size(),3):
				var point := Vector2(data[i],data[i+1])
				var distance := data[i+2]
				if not projected_points.has(point): projected_points[point] = main.elevation.project(point)
				vertices.append(projected_points[point])
				distances.append(Vector2(distance,0))
			loaded_fade_regions += 1
		var band_arrays: Array = []
		band_arrays.resize(Mesh.ARRAY_MAX)
		band_arrays[Mesh.ARRAY_VERTEX] = vertices
		band_arrays[Mesh.ARRAY_TEX_UV] = distances
		if band_arrays[Mesh.ARRAY_VERTEX].is_empty(): continue
		var band_node := MeshInstance2D.new()
		band_node.mesh = ArrayMesh.new()
		band_node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,band_arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		band_node.material = _band_style_for(house_id)
		band_node.show_behind_parent = true
		add_child(band_node)
		band_nodes.append(band_node)
		target.append(band_node)

func _country_center(polygons: Array) -> Vector2:
	var weighted := Vector2.ZERO
	var total_area := 0.0
	for ring in polygons:
		var twice_area := 0.0
		var numerator := Vector2.ZERO
		for i in range(ring.size()-1):
			var cross: float = ring[i].cross(ring[i+1])
			twice_area += cross
			numerator += (ring[i]+ring[i+1])*cross
		if absf(twice_area) > 0.000001:
			var area := absf(twice_area)*0.5
			weighted += numerator/(3.0*twice_area)*area
			total_area += area
	return weighted/total_area if total_area > 0.0 else Vector2.ZERO

func _build_country_geometry() -> void:
	for country_id in main.political_layer.click_polygons:
		var raw_polygons: Array = main.political_layer.click_polygons[country_id]
		var center := _country_center(raw_polygons)
		var representative := ""
		var best_distance := INF
		for district_id in main.district_layer.records:
			var region: Dictionary = main.district_layer.records[district_id]
			if region.parent != country_id: continue
			var label := Vector2(main.district_layer.records[district_id].label[0],main.district_layer.records[district_id].label[1])
			var distance := label.distance_squared_to(center)
			if distance < best_distance:
				best_distance = distance
				representative = district_id
		if representative.is_empty() or not main.governance_registry.districts.has(representative): continue
		var anchor := center
		if not raw_polygons.any(func(ring): return Geometry2D.is_point_in_polygon(anchor,ring)):
			anchor = Vector2(main.district_layer.records[representative].label[0],main.district_layer.records[representative].label[1])
		var house_id: String = main.governance_registry.districts[representative].house_id
		var state: String = GameSession.relation(GameSession.player_house,house_id)
		country_records[country_id] = {"representative_district":representative,"house_id":house_id,"anchor":anchor,"state":state}
		var polygons: Array = []
		var rings: Array[PackedVector2Array] = []
		var box := Rect2()
		var first := true
		for raw_ring in raw_polygons:
			var ring := PackedVector2Array()
			for raw_point in raw_ring:
				var point: Vector2 = main.elevation.project(raw_point)
				ring.append(point)
				if first: box = Rect2(point,Vector2.ZERO); first = false
				else: box = box.expand(point)
			polygons.append([ring])
			rings.append(ring)
		country_projected[country_id] = {"rings":rings,"polygons":polygons,"state":state,"house_id":house_id}
		country_bounds[country_id] = box
	_create_band_nodes(true,country_band_nodes)


func _process(delta: float) -> void:
	if projection_enabled != main.elevation.enabled: rebuild()
	var transform := get_global_transform_with_canvas()
	neutral_style.set_shader_parameter("view_zoom",transform.x.length())
	for style in band_styles.values(): style.set_shader_parameter("view_zoom",transform.x.length())
	country_mode = transform.x.length() <= COUNTRY_MAX_ZOOM
	for node in neutral_nodes: node.visible = not country_mode and transform.x.length() >= 0.65
	for node in district_band_nodes: node.visible = not country_mode
	for node in country_band_nodes: node.visible = country_mode
	var selected: String = ("country:"+main.political_layer.selected_id) if country_mode and not main.political_layer.selected_id.is_empty() else (("district:"+main.district_layer.selected_key) if not country_mode and not main.district_layer.selected_key.is_empty() else "")
	if last_selected != selected:
		last_selected = selected
		selection_pulse_phase = 0.0
		queue_redraw()
	if not selected.is_empty():
		selection_pulse_phase = fmod(selection_pulse_phase+delta/SELECTION_PULSE_SECONDS,1.0)
		selection_pulse_alpha = SELECTION_PULSE_ALPHA*(0.5-0.5*cos(TAU*selection_pulse_phase))
		queue_redraw()
	else: selection_pulse_alpha = 0.0
	if transform != last_transform: last_transform = transform; queue_redraw()

func _draw() -> void:
	var transform := get_global_transform_with_canvas()
	var visible_rect: Rect2 = transform.affine_inverse() * get_viewport_rect()
	var scale_value := maxf(transform.x.length(),0.001)
	draw_counts = {"self":0,"ally":0,"enemy":0,"neutral":0}
	# Coloured ownership bands are clipped geometrically to the territory side.
	# The visible boundary itself is always white.
	var active_projected: Dictionary = country_projected if country_mode else projected
	var active_bounds: Dictionary = country_bounds if country_mode else bounds
	for state in ["neutral","enemy","ally","self"]:
		for id in active_projected:
			var r: Dictionary = active_projected[id]
			if r.state != state or not active_bounds[id].grow(10/scale_value).intersects(visible_rect): continue
			draw_counts[state] += 1
			if fill_enabled:
				var fill_color: Color = theme_color(r.house_id)
				fill_color.a = TERRITORY_FILL_ALPHA
				if country_mode:
					for polygon in r.polygons:
						if not polygon.is_empty(): draw_colored_polygon(polygon[0],fill_color)
				else:
					var mesh := fill_mesh_for(str(id))
					if mesh != null: draw_mesh(mesh,null,Transform2D.IDENTITY,fill_color)
	_draw_selection_pulse(active_projected)
	for state in ["neutral","enemy","ally","self"]:
		for id in active_projected:
			var r: Dictionary = active_projected[id]
			if r.state != state or not active_bounds[id].grow(10/scale_value).intersects(visible_rect): continue
			if country_mode or not coastline_only_ids.has(id):
				for ring in r.rings:
					if ring.size()<2: continue
					draw_polyline(ring,BORDER_COLOR,DISTRICT_BORDER_WIDTH/scale_value,true)

func _draw_selection_pulse(active_projected: Dictionary) -> void:
	var selected: String = main.political_layer.selected_id if country_mode else main.district_layer.selected_key
	if selected.is_empty() or not active_projected.has(selected) or selection_pulse_alpha <= 0.0: return
	var record: Dictionary = active_projected[selected]
	var color := theme_color(record.house_id)
	color.a = selection_pulse_alpha
	if country_mode:
		for polygon in record.polygons:
			if not polygon.is_empty(): draw_colored_polygon(polygon[0],color)
	else:
		var mesh := fill_mesh_for(selected)
		if mesh != null: draw_mesh(mesh,null,Transform2D.IDENTITY,color)
