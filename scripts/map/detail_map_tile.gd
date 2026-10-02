extends Node2D
## Exact clipped land triangles; streaming selects the regular or close texture.
var elevation: RefCounted
var definition: Dictionary
var mesh: ArrayMesh
var relief: Texture2D
var coasts: Array[PackedVector2Array] = []
var styled_coasts: Array[Dictionary] = []
var coast_style_image: Image
var water_material: Material
var view_zoom := 1.0
var baked: Resource

func _ready() -> void:
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + definition["files"]["geometry"]))
	if baked != null:
		mesh=baked.mesh
		relief=baked.textures[0]
		coasts=baked.coasts
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_build_styled_coasts(geometry)
		_build_water_mesh(geometry)
		return
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var b: Array = definition["global_viewport"]
	var origin := Vector2(b[0],b[1])
	var density: float = definition["density"]
	var gutter: float = definition["gutter"]
	var side: float = definition["output_size"][0]
	for raw in geometry["vertices"]:
		var p := Vector2(raw[0],raw[1])
		vertices.append(elevation.project(p))
		uv.append(((p-origin)*density+Vector2.ONE*gutter)/side)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(geometry["indices"])
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	relief = load("res://"+definition["files"]["relief"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for raw in geometry["coasts"]:
		var line := PackedVector2Array()
		for p in raw: line.append(Vector2(p[0],p[1]))
		coasts.append(elevation.project_line(line))
	_build_styled_coasts(geometry)
	_build_water_mesh(geometry)

func _build_water_mesh(geometry: Dictionary) -> void:
	if water_material == null or not geometry.has("water_vertices") or geometry["water_indices"].is_empty(): return
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for raw in geometry["water_vertices"]:
		var point := Vector2(raw[0], raw[1])
		vertices.append(elevation.project(point))
		uv.append(point / 8192.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(geometry["water_indices"])
	var water_mesh := ArrayMesh.new()
	water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var water := MeshInstance2D.new()
	water.name = "CoastalWater"
	water.mesh = water_mesh
	water.material = water_material
	water.show_behind_parent = true
	water.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(water)

func _cliff_at(point: Vector2) -> bool:
	if coast_style_image == null: return false
	var pixel := Vector2i((point / 4.0).floor())
	pixel.x = clampi(pixel.x, 0, coast_style_image.get_width() - 1)
	pixel.y = clampi(pixel.y, 0, coast_style_image.get_height() - 1)
	return coast_style_image.get_pixelv(pixel).g >= 0.5

func _build_styled_coasts(geometry: Dictionary = {}) -> void:
	if geometry.is_empty():
		geometry = JSON.parse_string(FileAccess.get_file_as_string("res://" + definition["files"]["geometry"]))
	for raw in geometry["coasts"]:
		var kind := -1
		var run := PackedVector2Array()
		for i in range(raw.size() - 1):
			var a := Vector2(raw[i][0], raw[i][1])
			var b := Vector2(raw[i + 1][0], raw[i + 1][1])
			var next_kind := 1 if _cliff_at((a + b) * 0.5) else 0
			if next_kind != kind:
				if run.size() > 1: styled_coasts.append({"line": elevation.project_line(run), "cliff": kind == 1})
				run = PackedVector2Array([a])
				kind = next_kind
			run.append(b)
		if run.size() > 1: styled_coasts.append({"line": elevation.project_line(run), "cliff": kind == 1})

func set_view_zoom(value: float) -> void:
	if is_equal_approx(value,view_zoom): return
	view_zoom = value
	queue_redraw()

func _draw_content() -> void:
	if mesh == null: return
	draw_mesh(mesh,null,Transform2D.IDENTITY,Color("#becc99"))
	if elevation.relief_visible: draw_mesh(mesh,relief)
	for coast in styled_coasts:
		var line: PackedVector2Array = coast["line"]
		if coast["cliff"]:
			draw_polyline(line, Color("#20363cb8"), 4.0 / view_zoom, true)
			draw_polyline(line, Color("#5b8585b8"), 1.3 / view_zoom, true)
		else:
			draw_polyline(line, Color("#947d62bb"), 3.0 / view_zoom, true)
			draw_polyline(line, Color("#d9c9a6bf"), 1.6 / view_zoom, true)

var last_slow_draw_ms := -1000
func _draw() -> void:
	var start := Time.get_ticks_usec()
	_draw_content()
	var duration := Time.get_ticks_usec()-start
	if duration>10000 and Time.get_ticks_msec()-last_slow_draw_ms>1000:
		last_slow_draw_ms=Time.get_ticks_msec()
		get_node("/root/MapDiagnostics").record("slow_draw", {"layer":get_script().resource_path,"duration_us":duration})
