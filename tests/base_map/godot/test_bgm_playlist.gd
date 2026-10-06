extends SceneTree
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var display = root.get_node("DisplaySettings")
	display.set_bgm_volume(0.4, false)
	# Exercise the map's audio setup without loading its geographic layers.
	var main = Node2D.new()
	root.add_child(main)
	main.set_script(load("res://scripts/main/main_map.gd"))
	main.set_process(false)
	main.set_physics_process(false)
	main._setup_bgm()
	check(main.bgm_tracks.size() == 3, "normal BGM has three tracks")
	check(main.bgm_player.stream.resource_path.ends_with("scottish_symphony_i_andante_con_moto.ogg"), "existing track plays first")
	for track in main.bgm_tracks:
		check(not track.loop, "tracks finish to allow playlist advance")
		check(track.get_length() > 100, "recording decodes")
	var moonlight: AudioStreamOggVorbis = main.bgm_tracks[1]
	check(moonlight.get_length() > 330 and moonlight.get_length() < 340, "Moonlight first movement is about 5:36")
	main.bgm_player.stop()
	main.bgm_player.finished.emit()
	check(main.bgm_player.stream == moonlight and main.bgm_player.playing, "finished signal starts Moonlight")
	display.set_bgm_volume(0.2, false)
	check(is_equal_approx(main.bgm_player.volume_linear, 0.2), "volume applies to Moonlight")
	main.bgm_player.stop()
	main.bgm_player.finished.emit()
	var bridal: AudioStreamOggVorbis = main.bgm_tracks[2]
	check(bridal.resource_path.ends_with("wagner_bridal_chorus.ogg"), "Bridal Chorus is included")
	check(bridal.get_length() > 138 and bridal.get_length() < 141, "Bridal Chorus is about 2:19")
	check(main.bgm_player.stream == bridal and main.bgm_player.playing, "Moonlight advances to Bridal Chorus")
	check(is_equal_approx(main.bgm_player.volume_linear, 0.2), "volume applies to Bridal Chorus")
	main.bgm_player.stop()
	main.bgm_player.finished.emit()
	check(main.bgm_track_index == 0 and main.bgm_player.playing, "playlist wraps to existing track")
	check(is_equal_approx(main.bgm_player.volume_linear, 0.2), "volume persists across tracks")
	main.bgm_player.stop()
	root.remove_child(main)
	main.free()
	print("BGM playlist failures: ", failures)
	quit(1 if failures else 0)
