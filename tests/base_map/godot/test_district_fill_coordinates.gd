extends SceneTree

class MapStub extends Node:
	var elevation = preload("res://scripts/map/elevation_surface.gd").new()

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check_mesh(mesh: ArrayMesh, file: String, elevation: RefCounted, label: String) -> void:
	if mesh == null:
		failures += 1
		printerr("FAIL: missing fill " + label)
		return
	var stream := FileAccess.open(file, FileAccess.READ)
	var coordinates := stream.get_buffer(stream.get_length()).to_float32_array()
	var vertices: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if vertices.size() * 2 != coordinates.size():
		failures += 1
		printerr("FAIL: vertex count " + label)
		return
	for i in range(vertices.size()):
		var expected: Vector2 = elevation.project(Vector2(coordinates[2*i], coordinates[2*i+1]))
		if not vertices[i].is_equal_approx(expected):
			failures += 1
			printerr("FAIL: fill coordinates %s vertex %d: %s != %s" % [label, i, vertices[i], expected])
			return

func run() -> void:
	var map := MapStub.new()
	var borders = load("res://scripts/game/territory_borders.gd").new()
	borders.main = map
	borders._load_independent_fill_index()
	var legacy = preload("res://scripts/map/district_layer.gd").new()
	legacy.elevation = map.elevation
	legacy.review_mode = true
	for tilted in [false, true]:
		map.elevation.enabled = tilted
		borders.fill_meshes.clear()
		for id in borders.independent_fill_files:
			var file: String = borders.independent_fill_files[id]
			check_mesh(borders.fill_mesh_for(id), file, map.elevation, "%s tilt=%s" % [id, tilted])
		# The source/review selection path uses the same binary coordinate format.
		var id: String = borders.independent_fill_files.keys()[0]
		var file: String = borders.independent_fill_files[id]
		legacy.records[id] = {"mesh_file": file}
		legacy.select_key(id)
		check_mesh(legacy.fill_mesh(), file, map.elevation, "review tilt=%s" % tilted)
	borders.free()
	legacy.free()
	map.free()
	print("District fill coordinate tests: %d failures" % failures)
	quit(1 if failures else 0)
