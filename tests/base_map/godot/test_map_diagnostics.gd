extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func events(path: String) -> Array:
	var result := []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var entry = JSON.parse_string(line)
		assert(entry is Dictionary, "every log line must be valid JSON")
		result.append(entry)
	return result

func run() -> void:
	var logger = root.get_node("MapDiagnostics")
	await process_frame
	logger.note_zoom(1.0, 1.3, Vector2(640, 360))
	# Deliberately stop the main thread: the watchdog must write while it is blocked.
	OS.delay_msec(2600)
	var entries := events(logger.LOG_PATH)
	var stalls := entries.filter(func(e): return e.event == "main_thread_stall")
	assert(stalls.size() == 1)
	assert(stalls[0].last_operation.after == 1.3)
	for i in range(25):
		await create_timer(0.02).timeout
	entries = events(logger.LOG_PATH)
	assert(entries.any(func(e): return e.event == "main_thread_recovered"))
	# Exercise actual writer rotation, without accessing its FileAccess from main.
	for batch in range(30):
		for i in range(20):logger.record("rotation_payload", {"payload":"x".repeat(4096)})
		while not logger.is_flushed():await create_timer(0.01).timeout
	logger.record("rotation_test")
	while not logger.is_flushed():await create_timer(0.01).timeout
	assert(FileAccess.file_exists(logger.LOG_PATH + ".1"))
	assert(events(logger.LOG_PATH).any(func(e): return e.event == "rotation_test"))
	# Disk delay must not propagate to producers.
	logger.writer_delay_ms=10
	var start:=Time.get_ticks_msec()
	for i in range(30):logger.record("producer_test", {"i":i})
	assert(Time.get_ticks_msec()-start<100)
	while not logger.is_flushed():await create_timer(0.01).timeout
	logger.writer_delay_ms=0
	print("MAP DIAGNOSTICS: PASS; blocked-thread logging, operation context, recovery, rotation")
	quit()
