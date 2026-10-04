extends SceneTree

const Portraits = preload("res://scripts/game/officer_portraits.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/portraits_history_modern_20261003_102.json"))
	assert(rows.size() == 102)
	var output := "res://builds/qa/portraits_history102_backgrounds"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for start in range(0, 102, 4):
		var canvas := Control.new()
		root.add_child(canvas)
		for slot in range(4):
			if start + slot >= rows.size():
				continue
			var row: Dictionary = rows[start + slot]
			var texture = Portraits.texture_for(row["id"])
			assert(texture != null)
			for background in range(2):
				var card := ColorRect.new()
				card.position = Vector2(slot*320, background*360)
				card.size = Vector2(320,360)
				card.color = Color("1d1d21") if background == 0 else Color("f2f0eb")
				canvas.add_child(card)
				var portrait := TextureRect.new()
				portrait.position = Vector2(32,20)
				portrait.size = Vector2(256,256)
				portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				portrait.texture = texture
				card.add_child(portrait)
				var label := Label.new()
				label.position = Vector2(32,292)
				label.text = str(start+slot+1)+". "+str(row["name"])
				label.add_theme_color_override("font_color", Color.WHITE if background == 0 else Color.BLACK)
				card.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(output+"/sheet_%02d.png" % (start/4))
		assert(error == OK)
		canvas.queue_free()
		await process_frame
	print("BACKGROUND_CONTACT_SHEETS_26_OK")
	quit()
