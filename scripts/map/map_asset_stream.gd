extends Node
## Priority streaming with shared-component accounting and admission reservations.
signal arrived
var manifest: Dictionary = {}
var elevation_fingerprint := ""
var cache: Dictionary = {}
var costs: Dictionary = {}
var queued: Array[String] = []
var running: Dictionary = {}
var failed: Dictionary = {}
var denied: Dictionary = {}
var priorities: Dictionary = {}
var pins: Dictionary = {}
var components: Dictionary = {}
var component_refs: Dictionary = {}
var touched: Dictionary = {}
var resident_bytes := 0
var reserved_bytes := 0
var budget_bytes := 176*1024*1024
var hits := 0
var misses := 0
var evictions := 0
var generation := 0
var latency_ms := 100.0
var injected_delay_ms := 0
var injected_fail: Dictionary = {}
var plan: Array = []

func _ready() -> void:
	var path := "res://data/derived/map_runtime/manifest.json"
	if FileAccess.file_exists(path): manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest.is_empty() and manifest.get("heightfield_sha256","") != elevation_fingerprint:
		MapDiagnostics.record("asset_manifest_failed", {"reason":"elevation_fingerprint"})
		manifest.clear()
	if OS.has_feature("android"): budget_bytes=112*1024*1024 # 16 MiB reserved separately for CPU jobs.

func footprint(path: String) -> Dictionary:
	return manifest.get("footprints",{}).get(path,{path:8*1024*1024})

func request_cost(path: String) -> int:
	var size := int(manifest.get("file_bytes",{}).get(path,0))
	for key in footprint(path):
		if not component_refs.has(key): size += int(footprint(path)[key])*2
	return maxi(1,size)

func adopt(path: String, resource: Resource) -> void:
	if cache.has(path): return
	cache[path]=resource
	costs[path]=footprint(path)
	for key in costs[path]:
		if not component_refs.has(key):
			component_refs[key]=0
			components[key]=int(costs[path][key])
			resident_bytes+=int(components[key])
		component_refs[key]+=1
	touched[path]=Time.get_ticks_msec()

func release(path: String) -> void:
	if not cache.has(path): return
	for key in costs[path]:
		component_refs[key]-=1
		if component_refs[key]==0:
			resident_bytes-=int(components[key])
			components.erase(key);component_refs.erase(key)
	cache.erase(path);costs.erase(path);touched.erase(path)
	evictions+=1

func set_pins(paths: Array) -> void:
	pins.clear()
	for path in paths:
		if not str(path).is_empty(): pins[path]=true

func fetch(path: String, priority: int = 0) -> Resource:
	if cache.has(path):
		hits+=1;touched[path]=Time.get_ticks_msec()
		return cache[path]
	if path.is_empty() or failed.has(path) or denied.has(path): return null
	priorities[path]=mini(priority,int(priorities.get(path,priority)))
	if not running.has(path) and not path in queued:
		misses+=1;queued.append(path)
	return null

func has_pending() -> bool:
	return not queued.is_empty() or not running.is_empty()

func trim(extra: int = 0) -> bool:
	var candidates := cache.keys()
	candidates.sort_custom(func(a,b):
		var now:=Time.get_ticks_msec()
		var a_hot:=now-int(touched[a])<2500
		var b_hot:=now-int(touched[b])<2500
		if a_hot!=b_hot:return not a_hot
		return int(touched[a])<int(touched[b]))
	for path in candidates:
		if resident_bytes+reserved_bytes+extra<=budget_bytes: return true
		if pins.has(path): continue
		release(path)
	return resident_bytes+reserved_bytes+extra<=budget_bytes

func _advance_stream() -> void:
	var changed:=false
	for path in running.keys():
		var job: Dictionary=running[path]
		var status:=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS or Time.get_ticks_msec()<int(job.ready_after):continue
		running.erase(path);reserved_bytes-=int(job.reserved)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var resource:=ResourceLoader.load_threaded_get(path)
			adopt(path,resource)
			latency_ms=lerpf(latency_ms,float(Time.get_ticks_msec()-int(job.start)),0.2)
			MapDiagnostics.record("asset_ready", {"path":path,"generation":job.generation,"elapsed_ms":Time.get_ticks_msec()-int(job.start)})
		else:
			failed[path]=true
			MapDiagnostics.record("asset_load_failed", {"path":path,"status":status,"generation":job.generation})
		changed=true
	if changed: arrived.emit()
	queued.sort_custom(func(a,b):return int(priorities.get(a,3))<int(priorities.get(b,3)))
	while running.size()<2 and not queued.is_empty():
		var path: String=queued.pop_front()
		if cache.has(path):continue
		var reservation:=request_cost(path)
		# Speculative loads do not evict data used in the last 2.5 seconds.
		if int(priorities.get(path,0))>0 and resident_bytes+reserved_bytes+reservation>budget_bytes:
			denied[path]=true;continue
		if not trim(reservation):
			denied[path]=true
			MapDiagnostics.record("asset_budget_deferred", {"path":path,"bytes":reservation,"generation":generation})
			continue
		if injected_fail.has(path):
			failed[path]=true;arrived.emit()
			MapDiagnostics.record("asset_load_failed", {"path":path,"reason":"injected"})
			continue
		var error:=ResourceLoader.load_threaded_request(path,"",false)
		if error==OK:
			var now:=Time.get_ticks_msec()
			running[path]={"reserved":reservation,"start":now,"ready_after":now+injected_delay_ms,"generation":generation}
			reserved_bytes+=reservation
		else:
			failed[path]=true;arrived.emit()
			MapDiagnostics.record("asset_request_failed", {"path":path,"error":error})

func keep_requests(paths: Array) -> void:
	if plan != paths:
		plan=paths.duplicate();generation+=1;denied.clear()
	queued=queued.filter(func(p: String):return p in paths)
	for path in priorities.keys():
		if not path in paths: priorities.erase(path)
	# Expire unused assets only under pressure; hot visits otherwise stay reusable.
	if resident_bytes+reserved_bytes>budget_bytes:trim()

func _exit_tree() -> void:
	queued.clear()
	for path in running: ResourceLoader.load_threaded_get(path)
	running.clear();cache.clear();costs.clear();resident_bytes=0;reserved_bytes=0

func _process(_delta: float) -> void:
	var start:=Time.get_ticks_usec()
	_advance_stream()
	var duration:=Time.get_ticks_usec()-start
	if duration>10000:MapDiagnostics.record("slow_stream", {"duration_us":duration})
