extends Node2D
## Exact clipped land triangles; terrain texture is sampled at four texels/unit.
var elevation: RefCounted
var definition: Dictionary
var mesh: ArrayMesh
var relief: Texture2D
var coasts: Array[PackedVector2Array] = []
var view_zoom := 1.0
var baked: Resource

func _ready() -> void:
	if baked != null:
		mesh=baked.mesh
		relief=baked.textures[0]
		coasts=baked.coasts
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		return
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://"+definition["files"]["geometry"]))
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

func set_view_zoom(value: float) -> void:
	if is_equal_approx(value,view_zoom): return
	view_zoom = value
	queue_redraw()

func _draw_content() -> void:
	if mesh == null: return
	draw_mesh(mesh,null,Transform2D.IDENTITY,Color("#becc99"))
	if elevation.relief_visible: draw_mesh(mesh,relief)
	for line in coasts:
		if line.size()>1: draw_polyline(line,Color("#393d32"),1.1/view_zoom,true)

var last_slow_draw_ms := -1000
func _draw() -> void:
	var start := Time.get_ticks_usec()
	_draw_content()
	var duration := Time.get_ticks_usec()-start
	if duration>10000 and Time.get_ticks_msec()-last_slow_draw_ms>1000:
		last_slow_draw_ms=Time.get_ticks_msec()
		get_node("/root/MapDiagnostics").record("slow_draw", {"layer":get_script().resource_path,"duration_us":duration})
