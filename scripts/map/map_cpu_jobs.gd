extends Node
## Bounded, independently owned CPU tasks. No scene or GPU access in workers.
var jobs: Dictionary = {}
var limit := 2 if OS.has_feature("android") else 4
var budget_bytes := 16 * 1024 * 1024
var reserved_bytes := 0
var completed := 0
var peak_running := 0
var threads: Dictionary = {}
var delay_ms := 0

class Work extends RefCounted:
	var action: Callable
	var result: Variant
	var started := 0
	var ended := 0
	var thread_id := 0
	var delay := 0
	func run() -> void:
		thread_id = OS.get_thread_caller_id()
		started = Time.get_ticks_usec()
		if delay > 0: OS.delay_msec(delay)
		result = action.call()
		ended = Time.get_ticks_usec()

func submit(key: String, action: Callable, bytes: int, generation: int = 0) -> bool:
	if jobs.has(key): return true
	if jobs.size() >= limit or reserved_bytes + bytes > budget_bytes: return false
	var work := Work.new()
	work.action = action
	work.delay = delay_ms
	var task := WorkerThreadPool.add_task(work.run, false, key)
	jobs[key] = {"work": work, "task": task, "bytes": bytes, "generation": generation, "time_ms": Time.get_ticks_msec(), "reported": false}
	reserved_bytes += bytes
	peak_running = maxi(peak_running, jobs.size())
	MapDiagnostics.record("cpu_submitted", {"job": key, "generation": generation, "reserved_bytes": bytes})
	return true

func is_complete(key: String) -> bool:
	return jobs.has(key) and WorkerThreadPool.is_task_completed(jobs[key].task)

func take(key: String) -> Variant:
	if not is_complete(key): return null
	return drain(key)

func drain(key: String) -> Variant:
	# Shutdown-only callers may wait; interactive callers use take after polling.
	if not jobs.has(key):return null
	var job: Dictionary = jobs[key]
	WorkerThreadPool.wait_for_task_completion(job.task) # Already complete; also releases pool resources.
	var work: Work = job.work
	threads[work.thread_id] = true
	MapDiagnostics.record("cpu_completed", {"job": key, "generation": job.generation, "worker": work.thread_id, "cpu_us": work.ended-work.started})
	reserved_bytes -= int(job.bytes)
	jobs.erase(key)
	completed += 1
	return work.result

func _process(_delta: float) -> void:
	for key in jobs:
		var job: Dictionary = jobs[key]
		if not job.reported and Time.get_ticks_msec()-int(job.time_ms)>2000 and not is_complete(key):
			job.reported = true
			MapDiagnostics.record("cpu_job_stall", {"job": key, "generation": job.generation, "elapsed_ms": Time.get_ticks_msec()-int(job.time_ms)})

func _exit_tree() -> void:
	for job in jobs.values(): WorkerThreadPool.wait_for_task_completion(job.task)
	jobs.clear()
	reserved_bytes = 0
