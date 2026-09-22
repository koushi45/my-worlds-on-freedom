extends SceneTree

func _initialize() -> void:
	var layer = preload("res://scripts/map/district_layer.gd").new()
	layer.view_zoom = 4.0
	var segments := PackedVector2Array()
	# A sub-micro-unit remainder after the first dash used to loop forever.
	layer.append_dashes(PackedVector2Array([Vector2.ZERO, Vector2(1.5000005, 0)]), segments)
	assert(segments.size() == 2)
	for zoom_value in [0.65, 0.751, 1.0, 1.3, 1.69, 2.197, 2.8561, 3.71293, 4.0]:
		layer.view_zoom = zoom_value
		segments.clear()
		layer.append_dashes(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(100, 0), Vector2(100, 100)]), segments)
		assert(not segments.is_empty() and segments.size() % 2 == 0)
		for i in range(0, segments.size(), 2):
			assert(segments[i].distance_to(segments[i+1]) <= 6.0/zoom_value + 0.0001)
			assert(segments[i].is_finite() and segments[i+1].is_finite())
	layer.free()
	print("DASH PROGRESS: PASS")
	quit()
