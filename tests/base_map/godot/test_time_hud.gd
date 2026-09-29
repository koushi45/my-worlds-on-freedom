extends SceneTree

const Clock = preload("res://scripts/game/game_clock.gd")
const TimeHud = preload("res://scripts/game/time_hud.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock := Clock.new()
	root.add_child(clock)
	var hud := TimeHud.new()
	hud.clock = clock
	root.add_child(hud)
	await process_frame
	var panel_rect: Rect2 = hud.panel.get_global_rect()
	_check(panel_rect.position.x >= 0 and panel_rect.end.x <= root.get_visible_rect().size.x, "time panel fits viewport")
	_check(hud.date_label.get_global_rect().end.x <= panel_rect.end.x - 16, "date fits panel")
	_check(hud.faster_button.get_global_rect().end.x <= panel_rect.end.x - 16, "controls fit panel")
	_check(hud.date_icon.texture.get_width() == hud.icon_variant_size, "calendar uses native-size PNG")
	_check(hud.playback_icon.texture.resource_path.contains("pause_"), "running state shows pause icon")
	hud.playback_button.pressed.emit()
	_check(clock.paused and hud.playback_icon.texture.resource_path.contains("play_"), "click pauses and shows play icon")
	hud.playback_button.pressed.emit()
	hud.faster_button.pressed.emit()
	_check(not clock.paused and clock.speed == 2, "buttons resume and accelerate")
	hud.queue_free()
	clock.queue_free()
	await process_frame
	print("Time HUD tests: %d failures" % failures)
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
