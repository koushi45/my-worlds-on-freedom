extends RefCounted
## Demand-only texture loading; two requests, bounded decoded/transfer reservations.
var resident: Dictionary = {}
var waiting: Dictionary = {}
var wanted: Dictionary = {}
var failed: Dictionary = {}
var limit := 2
var budget_bytes := 160*1024*1024
var resident_bytes := 0
var reserved_bytes := 0
var peak_reserved_bytes := 0

func keep(paths: Dictionary) -> void:
    wanted = paths
    for path in resident.keys():
        if not wanted.has(path): resident.erase(path)
    _account()

func _account() -> void:
    resident_bytes = 0
    for path in resident: resident_bytes += int(wanted.get(path,0))

func adopt(path: String, texture: Texture2D) -> void:
    if texture!=null: resident[path] = texture
    _account()

func poll() -> void:
    for path in waiting.keys():
        var status := ResourceLoader.load_threaded_get_status(path)
        if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
        reserved_bytes -= int(waiting[path])
        waiting.erase(path)
        if status==ResourceLoader.THREAD_LOAD_LOADED:
            var texture := ResourceLoader.load_threaded_get(path) as Texture2D
            if wanted.has(path): resident[path] = texture
        else:
            failed[path] = true
            _record("texture_load_failed", {"path":path,"status":status})
    _account()
    for path in wanted:
        if resident.has(path) or waiting.has(path) or failed.has(path): continue
        if ResourceLoader.has_cached(path):
            resident[path] = load(path)
            _account()
            continue
        if waiting.size()>=limit: break
        var cost := maxi(1,int(wanted[path])*2)
        if resident_bytes+reserved_bytes+cost>budget_bytes: continue
        var error := ResourceLoader.load_threaded_request(path,"Texture2D",false)
        if error!=OK:
            failed[path] = true
            _record("texture_request_failed", {"path":path,"error":error})
            continue
        waiting[path] = cost
        reserved_bytes += cost
        peak_reserved_bytes = maxi(peak_reserved_bytes,reserved_bytes)

func texture(path: String) -> Texture2D:
    return resident.get(path)

func pending() -> bool:
    if not waiting.is_empty(): return true
    for path in wanted:
        if not resident.has(path) and not failed.has(path): return true
    return false

func shutdown() -> void:
    # Scene teardown only. Finish submitted loads so abandoned results release.
    for path in waiting: ResourceLoader.load_threaded_get(path)
    waiting.clear()
    resident.clear()
    reserved_bytes = 0
    resident_bytes = 0

func _record(event: String, data: Dictionary) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    if tree==null: return
    var diagnostics := tree.root.get_node_or_null("MapDiagnostics")
    if diagnostics!=null: diagnostics.record(event,data)
