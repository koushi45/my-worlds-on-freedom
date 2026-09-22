extends Node
## The watchdog reads mutex-owned snapshots, never scene or rendering objects.
var LOG_PATH := "user://logs/map_diagnostics_%d.jsonl" % OS.get_process_id()
const MAX_LOG_BYTES := 2 * 1024 * 1024
const STALL_MS := 2000
var main: Node
var enabled := "--map-profile" in OS.get_cmdline_user_args()
var log_file: FileAccess
var lock := Mutex.new()
var watchdog := Thread.new()
var writer := Thread.new()
var wake := Semaphore.new()
var pending: Array[Dictionary] = []
var history: Array[Dictionary] = []
var dropped := 0
var writer_stopping := false
var session_id := str(OS.get_process_id()) + "-" + str(Time.get_unix_time_from_system())
var writer_delay_ms := 0 # Fault injection, never enabled by default.
var written_sequence := 0
var sequence := 0
var stopping := false
var suspended := false
var heartbeat_ms := 0
var snapshot: Dictionary = {}
var last_operation: Dictionary = {}
var previous_tick := 0
var last_sample := 0
var last_slow := 0
var maximum_frame_ms := 0.0
var frames_over_100ms := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	writer.start(_write_loop)
	heartbeat_ms = Time.get_ticks_msec()
	record("session_start", {"engine": Engine.get_version_info().string, "os": OS.get_name(), "pid": OS.get_process_id()})
	print("MAP DIAGNOSTICS: ", ProjectSettings.globalize_path(LOG_PATH))
	var error := watchdog.start(_watch)
	if error != OK: record("watchdog_start_failed", {"error": error})

func _rotate_locked() -> void:
	if log_file != null:
		log_file.flush()
		log_file.close()
	for i in range(3, 0, -1):
		var destination := ProjectSettings.globalize_path(LOG_PATH + ".%d" % i)
		var source := ProjectSettings.globalize_path(LOG_PATH + ("" if i == 1 else ".%d" % (i-1)))
		if FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
		if FileAccess.file_exists(source): DirAccess.rename_absolute(source, destination)
	log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log_file == null: printerr("Cannot open map diagnostics: ", FileAccess.get_open_error())

func record(event: String, details: Dictionary = {}) -> void:
	lock.lock()
	_enqueue_locked(event, details)
	lock.unlock()
	wake.post()

func _enqueue_locked(event: String, details: Dictionary) -> void:
	var critical := event.contains("failed") or event.contains("stall") or event.contains("error") or event == "session_end"
	if pending.size() >= (256 if critical else 224):
		dropped += 1
		return
	sequence += 1
	var entry := {"event": event, "session": session_id, "thread": OS.get_thread_caller_id(),
		"sequence": sequence, "time_ms": Time.get_ticks_msec(), "state": snapshot,
		"last_operation": last_operation, "details": details.duplicate(true), "dropped": dropped}
	if critical: entry["history"] = history.duplicate()
	pending.append(entry)
	history.append({"event": event, "time_ms": entry.time_ms, "details": entry.details})
	if history.size() > 32: history.pop_front()

func _write_loop() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	_prune_old_sessions()
	_rotate_locked()
	while true:
		wake.wait()
		lock.lock()
		var batch := pending
		pending = []
		var finish := writer_stopping
		lock.unlock()
		# File I/O and JSON serialization never hold the producer/watchdog lock.
		for entry in batch:
			if writer_delay_ms > 0: OS.delay_msec(writer_delay_ms)
			if log_file != null:
				if log_file.get_position() >= MAX_LOG_BYTES: _rotate_locked()
				if log_file != null:
					entry["time"] = Time.get_datetime_string_from_system(true)
					log_file.store_line(JSON.stringify(entry))
					log_file.flush()
			lock.lock()
			written_sequence = entry.sequence
			lock.unlock()
		if finish:
			if log_file != null: log_file.close()
			return

func is_flushed() -> bool:
	lock.lock()
	var ready := written_sequence == sequence
	lock.unlock()
	return ready

func note_zoom(before: float, after: float, pointer: Vector2) -> void:
	lock.lock()
	last_operation = {"type": "zoom", "before": before, "after": after, "pointer": [pointer.x, pointer.y], "time_ms": Time.get_ticks_msec()}
	lock.unlock()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var ms := float(now-previous_tick) if previous_tick > 0 else 0.0
	previous_tick = now
	maximum_frame_ms = maxf(maximum_frame_ms, ms)
	if ms > 100.0: frames_over_100ms += 1
	var state: Dictionary = {}
	if is_instance_valid(main) and main.initialized:
		state = {"zoom": main.camera.zoom.x, "camera": [main.camera.position.x, main.camera.position.y], "lod": main.lod_level,
			"oblique": main.elevation.enabled, "tiles": main.loaded_tiles.size(), "pending_tiles": main.pending_tiles.size(),
			"asset_queue": main.asset_stream.queued.size(), "asset_running": main.asset_stream.running.keys(),
			"asset_failed": main.asset_stream.failed.size(), "asset_cache_bytes": main.asset_stream.resident_bytes,
			"asset_budget_bytes": main.asset_stream.budget_bytes, "asset_reserved_bytes":main.asset_stream.reserved_bytes,
			"cpu_reserved_bytes":main.cpu_jobs.reserved_bytes,"cpu_completed":main.cpu_jobs.completed,"cpu_peak_running":main.cpu_jobs.peak_running,
			"main_update_us":main.main_update_us,"coverage_missing_frames":main.coverage_missing_frames,"tile_swaps":main.tile_swaps,
			"cache_hits":main.asset_stream.hits,"cache_misses":main.asset_stream.misses,"cache_evictions":main.asset_stream.evictions, "baked_tiles": main.asset_stream.manifest.get("tiles", {}).size(),
			"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
			"buffer_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"maximum_frame_ms": maximum_frame_ms, "frames_over_100ms": frames_over_100ms}
	lock.lock()
	heartbeat_ms = now
	snapshot = state
	lock.unlock()
	if ms > 250.0 and now-last_slow >= 1000:
		last_slow = now
		record("slow_frame", {"frame_ms": ms})
	if now-last_sample >= (1000 if enabled else 10000):
		last_sample = now
		record("sample")

func _watch() -> void:
	var reported := false
	while true:
		lock.lock()
		if stopping:
			lock.unlock()
			return
		var delay := Time.get_ticks_msec()-heartbeat_ms
		if not suspended and delay >= STALL_MS and not reported:
			_enqueue_locked("main_thread_stall", {"unresponsive_ms": delay})
			reported = true
		elif (suspended or delay < STALL_MS) and reported:
			_enqueue_locked("main_thread_recovered", {})
			reported = false
		lock.unlock()
		wake.post()
		OS.delay_msec(200)

func _exit_tree() -> void:
	lock.lock()
	stopping = true
	lock.unlock()
	if watchdog.is_started(): watchdog.wait_to_finish()
	record("session_end")
	lock.lock()
	writer_stopping = true
	lock.unlock()
	wake.post()
	if writer.is_started(): writer.wait_to_finish()

func _prune_old_sessions() -> void:
	var directory:=DirAccess.open("user://logs")
	if directory==null:return
	var sessions: Array=[]
	for name in directory.get_files():
		if not name.begins_with("map_diagnostics_") or not name.ends_with(".jsonl"):continue
		var pid_text:=name.trim_prefix("map_diagnostics_").trim_suffix(".jsonl")
		if not pid_text.is_valid_int() or OS.is_process_running(int(pid_text)):continue
		sessions.append({"name":name,"time":FileAccess.get_modified_time("user://logs/"+name)})
	sessions.sort_custom(func(a,b):return int(a.time)>int(b.time))
	for i in range(3,sessions.size()):
		var name: String=sessions[i].name
		for suffix in ["",".1",".2",".3"]:
			if directory.file_exists(name+suffix):directory.remove(name+suffix)

func set_suspended(value: bool) -> void:
	lock.lock()
	suspended=value
	heartbeat_ms=Time.get_ticks_msec()
	lock.unlock()
	record("application_paused" if value else "application_resumed")
