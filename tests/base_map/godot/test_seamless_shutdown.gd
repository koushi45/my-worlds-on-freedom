extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var main=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await preload("res://tests/base_map/godot/wait_map.gd").settled(main)
	main.cpu_jobs.delay_ms=250
	main.district_layer.compiled_parents.erase("izumi")
	main.district_layer.load_parent("izumi")
	root.remove_child(main)
	main.free()
	await process_frame
	print("SEAMLESS SHUTDOWN: PASS")
	quit()
