extends SceneTree
## Use the same rendered benchmark runner as the packaged-game check.

func _initialize() -> void:
	call_deferred("start_benchmark")

func start_benchmark() -> void:
	root.add_child(preload("res://scripts/game/cpu_speed_check.gd").new())
