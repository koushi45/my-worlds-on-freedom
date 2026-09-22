extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var display = root.get_node("DisplaySettings")
	display.settings_path = "user://qa_display_settings_%d.cfg" % OS.get_process_id()
	display.apply_resolution(1,false)
	display.set_bgm_volume(0.4,false)
	display.set_sfx_volume(1.0,false)
	change_scene_to_file("res://scenes/start/start.tscn")
	await process_frame
	await process_frame
	check(display.RESOLUTIONS == [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)],"resolution catalogue covers 1280 through 4K")
	check(display.current_index == 1,"1920 by 1080 is the standard resolution")
	if DisplayServer.get_name() != "headless": check(DisplayServer.window_get_size() == Vector2i(1920,1080),"standard window is 1920 by 1080")
	current_scene.show_options()
	await process_frame
	var options = current_scene.options
	check(is_instance_valid(options) and options.resolution_selector.item_count == 4,"title options expose four window sizes")
	check(options.resolution_selector.selected == 1,"standard size is initially selected")
	check(is_equal_approx(options.bgm_slider.value,40.0),"BGM defaults to 40 percent")
	check(is_equal_approx(options.sfx_slider.value,100.0),"sound effects default to 100 percent")
	options.resolution_selector.select(0)
	options._apply()
	await process_frame
	check(display.current_index == 0,"1280 by 720 can be selected")
	if DisplayServer.get_name() != "headless": check(DisplayServer.window_get_size() == Vector2i(1280,720),"1280 option resizes the window")
	options.resolution_selector.select(3)
	options._apply()
	await process_frame
	check(display.current_index == 3,"4K can be selected")
	options.bgm_slider.value = 25.0
	options.sfx_slider.value = 25.0
	options._apply()
	check(is_equal_approx(display.bgm_volume,0.25),"BGM volume can be changed")
	check(is_equal_approx(display.sfx_volume,0.25),"sound effect volume can be changed")
	check(is_equal_approx(root.get_node("InteractionAudio").player.volume_linear,0.25),"sound effect volume updates the active player")
	options.resolution_selector.select(1)
	options.bgm_slider.value = 40.0
	options.sfx_slider.value = 100.0
	options._apply()
	await process_frame
	var saved := ConfigFile.new()
	check(saved.load(display.settings_path) == OK and int(saved.get_value("display","resolution_index",-1)) == 1,"window size persists")
	check(is_equal_approx(float(saved.get_value("audio","bgm_volume",-1.0)),0.4),"BGM volume persists")
	check(is_equal_approx(float(saved.get_value("audio","sfx_volume",-1.0)),1.0),"sound effect volume persists")
	var test_button := Button.new()
	root.add_child(test_button)
	var old_play_count: int = root.get_node("InteractionAudio").play_count
	test_button.pressed.emit()
	check(root.get_node("InteractionAudio").play_count == old_play_count+1,"clickable UI plays the shared operation sound")
	check(root.get_node("InteractionAudio").player.playing,"the CC0 Breviceps sound plays as the operation sound")
	check(root.get_node("InteractionAudio").player.stream.resource_path.ends_with("ui_click_breviceps.ogg"),"the Breviceps sound replaces the previous click sound")
	test_button.queue_free()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/qa/display_options_1920x1080.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(display.settings_path))
	print("Display option tests: %d failures" % failures)
	quit(1 if failures else 0)
