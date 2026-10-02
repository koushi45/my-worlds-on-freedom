extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var probe := preload("res://scripts/map/map_performance_probe.gd").new()
    root.add_child(probe)
