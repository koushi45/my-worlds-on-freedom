extends SceneTree
const Wait = preload("res://tests/base_map/godot/wait_map.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.max_fps = 60
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await Wait.settled(main)
	var maximum_ms := 0
	for tilt in [false, true]:
		main.set_oblique(tilt)
		main.camera.position = main.elevation.project(Vector2(3460, 5880))
		main.set_map_zoom(0.65)
		await Wait.settled(main)
		for cycle in range(3):
			for direction in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				for step in range(12):
					var start := Time.get_ticks_msec()
					var refreshes: int = main.visible_refresh_count
					for burst in range(3):
						var event := InputEventMouseButton.new()
						event.button_index = direction
						event.pressed = true
						event.position = Vector2(700, 380)
						main._unhandled_input(event)
					assert(main.visible_refresh_count == refreshes, "wheel bursts must defer visibility work")
					await process_frame
					await process_frame
					maximum_ms = maxi(maximum_ms, Time.get_ticks_msec()-start)
					assert(main.camera.zoom.x <= 4.0)
		await Wait.settled(main)
	assert(main.asset_stream.failed.is_empty())
	print("WHEEL STRESS: PASS; 432 wheel events, both projections; max two-frame interval ms=", maximum_ms)
	quit()
