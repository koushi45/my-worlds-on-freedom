extends "res://scripts/map/road_geometry.gd"
## The only road stroke renderer. Labels and selection controls stay in their layers.
var game_connections: Node2D
var drawn_strokes := 0
var active_strokes := 0
var stroke_meshes: Dictionary = {}
const LineBatch=preload("res://scripts/map/line_mesh_batch.gd")

func _ready() -> void:
	z_index = 19
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/road_connections/shared_display.json"))
	for stroke in data["strokes"]:
		var b: Array = stroke["bounds"]
		stroke["draw_bounds"] = Rect2(point([b[0],b[1]]),point([b[2]-b[0],b[3]-b[1]])).grow(2)
	game_connections.visibility_changed.connect(queue_redraw)

func _draw_content() -> void:
	drawn_strokes = 0
	active_strokes = 0
	for batch in stroke_meshes.values():batch.visible=false
	if data == null or not game_connections.visible: return
	var batches: Dictionary = {}
	for stroke in data["strokes"]:
		if not view_rect.intersects(stroke["draw_bounds"]): continue
		var active: bool = game_connections.selected_id in stroke["connection_ids"]
		if view_zoom < 0.18 and stroke["role"] == "site_access" and not active: continue
		var width := (2.5 if stroke["role"] == "trunk" else 1.5) if view_zoom >= 0.18 else 1.0
		var color := Color("#ffe196")
		if stroke["role"] == "crossing": color = Color("#efb579")
		if active:
			width += 1.0
			color = Color("#fff7b2")
			active_strokes += 1
		var line := surface_for(stroke)
		if line.size() < 2: continue
		var key := str(width)+color.to_html()
		if not batches.has(key): batches[key] = {"width":width,"color":color,"points":PackedVector2Array()}
		var segments: PackedVector2Array = batches[key]["points"]
		for i in range(line.size()-1):
			segments.append(line[i])
			segments.append(line[i+1])
		drawn_strokes += 1
	for key in batches:
		var batch:Dictionary=batches[key]
		for outline in [true,false]:
			var id:String=key+str(outline)
			if not stroke_meshes.has(id):
				var node=LineBatch.new();node.z_index=0 if outline else 1
				add_child(node);stroke_meshes[id]=node
			stroke_meshes[id].configure(batch["points"],batch["width"]+(1.5 if outline else 0.0),Color("#39362e") if outline else batch["color"],view_zoom)
	for node in stroke_meshes.values():
		if not node.visible:
			node.mesh=null;node.last_segments.clear();node.buffer_bytes=0

var last_slow_draw_ms := -1000
func _draw() -> void:
	var start := Time.get_ticks_usec()
	_draw_content()
	var duration := Time.get_ticks_usec()-start
	if duration>10000 and Time.get_ticks_msec()-last_slow_draw_ms>1000:
		last_slow_draw_ms=Time.get_ticks_msec()
		get_node("/root/MapDiagnostics").record("slow_draw", {"layer":get_script().resource_path,"duration_us":duration})
