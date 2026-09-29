extends RefCounted
## Neighbouring road tiles connect unless their edge is explicitly excluded.
signal changed
const Grid = preload("res://scripts/map/hex_grid.gd")
const DEFAULT_PATH := "res://data/derived/scenarios/hex_roads_1546.json"
const NEIGHBORS = [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]
var cells: Dictionary = {}
var allowed: Dictionary = {}
var excluded_edges: Dictionary = {}
var undo_cells: Array = []
var redo_cells: Array = []
var last_error := ""

func setup(strokes: Array, coverage: Dictionary) -> void:
	allowed = coverage
	cells.clear()
	excluded_edges.clear()
	for stroke in strokes:
		for p in stroke.points:
			var cell := Grid.cell_at(Vector2(float(p[0]),float(p[1])))
			if allowed.has(cell): cells[cell] = true
	undo_cells.clear()
	redo_cells.clear()

func toggle(cell: Vector2i) -> bool:
	if not allowed.has(cell): return false
	_record(cell)
	return true

func edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.y > b.y or (a.y == b.y and a.x > b.x): return Vector4i(b.x,b.y,a.x,a.y)
	return Vector4i(a.x,a.y,b.x,b.y)

func toggle_edge(a: Vector2i, b: Vector2i) -> bool:
	if not cells.has(a) or not cells.has(b) or Grid.distance(a,b) != 1: return false
	_record(edge_key(a,b))
	return true

func _record(action: Variant) -> void:
	_flip(action)
	undo_cells.append(action)
	if undo_cells.size() > 2000: undo_cells.pop_front()
	redo_cells.clear()
	changed.emit()

func _flip(action: Variant) -> void:
	var target: Dictionary = excluded_edges if action is Vector4i else cells
	if target.has(action): target.erase(action)
	else: target[action] = true

func undo() -> void:
	if undo_cells.is_empty(): return
	var cell: Variant = undo_cells.pop_back()
	_flip(cell)
	redo_cells.append(cell)
	changed.emit()

func redo() -> void:
	if redo_cells.is_empty(): return
	var cell: Variant = redo_cells.pop_back()
	_flip(cell)
	undo_cells.append(cell)
	changed.emit()

func connected(a: Vector2i, b: Vector2i) -> bool:
	return cells.has(a) and cells.has(b) and Grid.distance(a,b) == 1 and not excluded_edges.has(edge_key(a,b))

func has_connection(cell: Vector2i) -> bool:
	for delta in NEIGHBORS:
		if connected(cell,cell+delta): return true
	return false

func document() -> Dictionary:
	var ordered := cells.keys()
	ordered.sort_custom(func(a: Vector2i,b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var rows := []
	for cell in ordered: rows.append([cell.x,cell.y])
	var edges := []
	var keys := excluded_edges.keys()
	keys.sort()
	for edge in keys: edges.append([[edge.x,edge.y],[edge.z,edge.w]])
	return {"schema_version":1,"kind":"hex_road_network","hex_radius":Grid.RADIUS,
		"coordinates":"pointy_top_axial_q_r","connection_rule":"all_six_occupied_neighbors",
		"cells":rows,"excluded_edges":edges}

func load_document(value: Variant) -> bool:
	last_error = "道データの形式または六角形サイズが一致しません。"
	if not value is Dictionary: return false
	if value.get("schema_version") != 1 or value.get("kind") != "hex_road_network": return false
	if value.get("hex_radius") != Grid.RADIUS or value.get("coordinates") != "pointy_top_axial_q_r" or value.get("connection_rule") != "all_six_occupied_neighbors": return false
	var rows: Variant = value.get("cells")
	if not rows is Array or rows.size() > allowed.size(): return false
	var loaded := {}
	for row in rows:
		if not row is Array or row.size() != 2: return false
		for number in row:
			if not (number is int or number is float): return false
			if not is_finite(float(number)) or absf(float(number)) > 2000 or float(number) != floor(float(number)): return false
		var cell := Vector2i(int(row[0]),int(row[1]))
		if not allowed.has(cell) or loaded.has(cell): return false
		loaded[cell] = true
	var edge_rows: Variant = value.get("excluded_edges",[])
	if not edge_rows is Array or edge_rows.size() > allowed.size()*3: return false
	var loaded_edges := {}
	for edge in edge_rows:
		if not edge is Array or edge.size() != 2: return false
		var endpoints: Array[Vector2i] = []
		for row in edge:
			if not row is Array or row.size() != 2: return false
			for number in row:
				if not (number is int or number is float): return false
				if not is_finite(float(number)) or absf(float(number)) > 2000 or float(number) != floor(float(number)): return false
			var endpoint := Vector2i(int(row[0]),int(row[1]))
			if not allowed.has(endpoint): return false
			endpoints.append(endpoint)
		if Grid.distance(endpoints[0],endpoints[1]) != 1: return false
		var key := edge_key(endpoints[0],endpoints[1])
		if loaded_edges.has(key): return false
		loaded_edges[key] = true
	cells = loaded
	excluded_edges = loaded_edges
	undo_cells.clear()
	redo_cells.clear()
	last_error = ""
	changed.emit()
	return true

func export_file(path: String) -> Error:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document(), "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	return error
