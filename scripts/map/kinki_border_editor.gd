extends Node2D
## Only cyan draft lines are mutable. Canonical coast and approved regions are read-only.
@export var region_scope := "kinki"
var region_label := "近畿"
const LOCKED := "res://data/derived/political/approved_western/political_registry.json"
const AUTOSAVE := "user://kinki_border_edits_v1.json"
var autosave_path := AUTOSAVE
var draft: Dictionary
var locked: Dictionary
var lines: Array = []
var undo_stack: Array = []
var redo_stack: Array = []
var bounds := Rect2()
var zoom_value := 1.0
var offset := Vector2.ZERO
var mode := 0
var pending := false
var first := Vector2.ZERO
var dragging := false
var press := Vector2.ZERO
var moved := false
var box_selecting := false
var box_start := Vector2.ZERO
var box_end := Vector2.ZERO
var message: Label
var show_reference := false
var texture: Texture2D
var raster_rect := Rect2()
var sequence := 0
var initialized := false
var coast_cache: Array = []
var fixed_lines: Array = []
var locked_polygons: Array = []
var selected_preview := ""
var shared_lines: Array = []
var target_polygons: Array = []

func region36_draft() -> Dictionary:
	var target: Dictionary = {}
	for region in locked.regions:
		if region.region_id=="honshu-area-36": target=region
	var box := Rect2()
	for raw in target.polygons:
		var polygon := points(raw)
		target_polygons.append(polygon)
		box=Rect2(polygon[0],Vector2.ZERO)
		for p in polygon: box=box.expand(p)
	var digest := FileAccess.get_sha256(LOCKED)
	if autosave_path==AUTOSAVE: autosave_path="user://region36_border_edits_%s.json" % digest.left(12)
	return {"display_name":"領域36（摂津・和泉）", "bounds":[box.position.x-15,box.position.y-15,box.end.x+15,box.end.y+15], "boundaries":[],"coastlines":{},"coordinate_system":locked.get("coordinate_system","game_8192"),"source_draft_sha256":digest,"reference_hashes":{"approved_registry":digest},"target_region_id":"honshu-area-36"}

func points(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in raw: result.append(Vector2(float(p[0]),float(p[1])))
	return result

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#203e4b"))
	locked = JSON.parse_string(FileAccess.get_file_as_string(LOCKED))
	if region_scope=="region36" and not locked.regions.any(func(r): return r.region_id=="honshu-area-36"):
		get_tree().call_deferred("change_scene_to_file","res://scenes/main/main.tscn")
		return
	if locked.get("regional_bounds",{}).has(region_scope) or (region_scope=="kinki" and locked.get("regional_bounds",{}).has("honshu")):
		get_tree().call_deferred("change_scene_to_file","res://scenes/main/main.tscn")
		return
	region_label = "中国地方" if region_scope == "chugoku" else "近畿"
	if region_scope == "chugoku" and autosave_path == AUTOSAVE:
		autosave_path = "user://chugoku_border_edits_v1.json"
	if region_scope=="region36": draft=region36_draft()
	else: draft = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/editor/%s/editor_draft.json" % region_scope))
	region_label = draft.get("display_name",region_label)
	if region_scope == "honshu" and autosave_path == AUTOSAVE:
		autosave_path = "user://honshu_border_edits_%s.json" % str(draft.source_draft_sha256).left(12)
	if region_scope == "kinki" and autosave_path == AUTOSAVE and draft.has("handdrawn_source"):
		autosave_path = "user://kinki_border_edits_%s.json" % str(draft.source_draft_sha256).left(12)
	if region_scope == "chugoku" and autosave_path == "user://chugoku_border_edits_v1.json" and draft.has("regions"):
		autosave_path = "user://chugoku_border_edits_%s.json" % str(draft.source_draft_sha256).left(12)
	locked = JSON.parse_string(FileAccess.get_file_as_string(LOCKED))
	var b: Array = draft.bounds
	bounds = Rect2(float(b[0]),float(b[1]),float(b[2])-float(b[0]),float(b[3])-float(b[1]))
	lines = draft.boundaries.duplicate(true)
	for line in lines:
		for p in line.points: bounds=bounds.expand(Vector2(float(p[0]),float(p[1])))
	bounds=bounds.grow(1.0)
	for ring in draft.coastlines.values(): coast_cache.append(points(ring))
	for ring in locked.coastlines.values(): coast_cache.append(points(ring))
	for line in locked.boundaries: fixed_lines.append(points(line.points))
	for reference in draft.get("shared_boundary_references",[]):
		for line in locked.boundaries:
			if line.boundary_id==reference.boundary_id: shared_lines.append(points(line.points))
	for region in locked.regions:
		if region_scope=="region36" and region.region_id=="honshu-area-36": continue
		for polygon in region.polygons: locked_polygons.append(points(polygon))
	if region_scope=="region36":
		shared_lines.append_array(target_polygons)
	else:
		texture = load("res://data/derived/editor/%s/reference.png" % region_scope)
		var geo: Dictionary = draft.raster_georeference
		var scale_factor := float(geo.pixels_per_game_unit)
		var raster_bounds: Array = geo.get("bounds_8192",b)
		raster_rect = Rect2(Vector2(float(raster_bounds[0]),float(raster_bounds[1]))-Vector2.ONE*0.5/scale_factor,texture.get_size()/scale_factor)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(8,8)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "%s・国境線編集（未確定草稿）\n海岸／九州・四国・中国は編集不可" % region_label
	if region_scope=="region36": title.text="領域36：摂津・和泉の境界線編集\n薄い桃色の領域内に水色の線を追加"
	column.add_child(title)
	var modes := OptionButton.new()
	modes.add_item("追加：2点クリックで直線")
	modes.add_item("範囲削除：左ドラッグで四角形")
	if not draft.get("regions",[]).is_empty(): modes.add_item("枠の確認：国をクリック（未確定）")
	modes.item_selected.connect(func(index: int): mode=index; pending=false; selected_preview=""; queue_redraw())
	column.add_child(modes)
	for item in [["元に戻す (Ctrl+Z)",undo],["やり直し (Ctrl+Y)",redo],["JSONを書き出す",export_dialog],["JSONを読み込む",import_dialog],["全体表示 (F)",fit_map],["本番マップに戻る",leave_editor]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		column.add_child(button)
	var toggle := CheckButton.new()
	toggle.text = "変形した参考画像を表示"
	toggle.button_pressed = show_reference
	toggle.toggled.connect(func(value: bool): show_reference=value; queue_redraw())
	column.add_child(toggle)
	toggle.visible = texture != null
	var help := Label.new()
	help.text = "ホイール：拡縮／中ドラッグ：移動\n追加：2点クリック／左ドラッグで移動\n削除：左ドラッグ範囲の内側だけ削除\nEsc・右クリック：取消／Ctrl+Z：戻す\n変更は自動保存。書出JSONをお渡しください。"
	column.add_child(help)
	message = Label.new()
	message.custom_minimum_size = Vector2(285,0)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	initialized = true
	if FileAccess.file_exists(autosave_path): load_edits(autosave_path,false)
	get_viewport().size_changed.connect(fit_map)
	fit_map()
	status("追加モード：始点と終点をクリックしてください。")

func fit_map() -> void:
	var size := get_viewport_rect().size
	zoom_value = minf((size.x-340)/bounds.size.x,(size.y-30)/bounds.size.y)
	offset = Vector2(330+(size.x-330)*0.5,size.y*0.5)-bounds.get_center()*zoom_value
	queue_redraw()

func status(text: String) -> void:
	message.text = "%s\n編集線：%d本" % [text,lines.size()]

func snapshot() -> void:
	undo_stack.append(lines.duplicate(true))
	if undo_stack.size()>100: undo_stack.pop_front()
	redo_stack.clear()

func changed() -> void:
	pending = false
	selected_preview = ""
	var error := save_edits(autosave_path)
	status("自動保存済み" if error==OK else "自動保存失敗：JSONを書き出してください。")
	queue_redraw()

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(lines.duplicate(true))
	lines = undo_stack.pop_back()
	changed()

func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(lines.duplicate(true))
	lines = redo_stack.pop_back()
	changed()

func allowed(a: Vector2,b: Vector2) -> bool:
	if not bounds.has_point(a) or not bounds.has_point(b): return false
	if region_scope=="region36":
		var covered := 0.0
		for polygon in target_polygons:
			for part in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a,b]),polygon):
				for i in range(part.size()-1): covered+=part[i].distance_to(part[i+1])
		if covered<a.distance_to(b)-0.003: return false
	for line in shared_lines:
		for i in range(line.size()-1):
			if a.distance_to(Geometry2D.get_closest_point_to_segment(a,line[i],line[i+1]))<0.003 and b.distance_to(Geometry2D.get_closest_point_to_segment(b,line[i],line[i+1]))<0.003:
				return false
	for polygon in locked_polygons:
		for part in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a,b]),polygon):
			for i in range(part.size()-1):
				if part[i].distance_to(part[i+1])>0.01: return false
	return true

func snap_point(p: Vector2) -> Vector2:
	var best := p
	var distance := 8.0/zoom_value
	# Snap to editable endpoints or the immutable coast, without editing either.
	for line in lines:
		for raw in [line.points[0],line.points[-1]]:
			var q := Vector2(raw[0],raw[1])
			if q.distance_to(p)<distance: distance=q.distance_to(p); best=q
	for ring in coast_cache + shared_lines:
		for i in range(ring.size()-1):
			var q := Geometry2D.get_closest_point_to_segment(p,ring[i],ring[i+1])
			if q.distance_to(p)<distance: distance=q.distance_to(p); best=q
	return best

func add_line(a: Vector2,b: Vector2) -> bool:
	if a.distance_to(b)<0.01 or not allowed(a,b): return false
	snapshot()
	sequence += 1
	lines.append({"boundary_id":"manual:%s:%d" % [str(Time.get_unix_time_from_system()),sequence],"points":[[a.x,a.y],[b.x,b.y]],"trace_method":"user_two_click","certainty":"user_edited","review_status":"pending_polygonization"})
	changed()
	return true

func delete_rectangle(rect: Rect2) -> bool:
	var area := rect.abs()
	if area.size.x<0.01 or area.size.y<0.01: return false
	var clip := PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
	var remaining: Array = []
	var count := 0
	for line in lines:
		var poly := points(line.points)
		var inside := Geometry2D.intersect_polyline_with_polygon(poly,clip)
		var removed_length := 0.0
		for part in inside:
			for i in range(part.size()-1): removed_length+=part[i].distance_to(part[i+1])
		if removed_length<0.001:
			remaining.append(line.duplicate(true))
			continue
		count+=1
		for part in Geometry2D.clip_polyline_with_polygon(poly,clip):
			if part.size()<2: continue
			var item: Dictionary = line.duplicate(true)
			sequence+=1
			item["boundary_id"] = "%s:cut:%d:%s" % [line.boundary_id,sequence,str(Time.get_ticks_usec())]
			item["source_boundary_id"] = line.get("source_boundary_id",line.boundary_id)
			item["points"] = []
			for p in part: item.points.append([p.x,p.y])
			item["review_status"] = "pending_polygonization"
			remaining.append(item)
	if count==0: status("範囲内に削除できる水色線がありません。"); return false
	snapshot()
	lines=remaining
	changed()
	status("%d本の線から、範囲内の部分だけ削除しました。" % count)
	return true

func export_data() -> Dictionary:
	return {"schema":"my-worlds-%s-border-edits" % region_scope,"schema_version":1,"scope":region_scope,"status":"user_edited_pending_polygonization","coordinate_system":draft.coordinate_system,"reference_hashes":draft.reference_hashes,"source_draft_sha256":draft.source_draft_sha256,"exported_at_utc":Time.get_datetime_string_from_system(true),"boundaries":lines.duplicate(true),"shared_boundary_references":draft.get("shared_boundary_references",[]).duplicate(true),"immutable_layers":["coastline","kyushu","shikoku","chugoku"],"note":"Full replacement of this draft region only. Coastlines are referenced, never changed. Intersections must be noded and areas validated offline."}

func save_edits(path: String) -> Error:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(export_data(),"\t",true,true))
	file.flush()
	return file.get_error()

func load_edits(path: String,record_undo: bool=true) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema","")!="my-worlds-%s-border-edits" % region_scope or parsed.get("scope","")!=region_scope or parsed.get("source_draft_sha256","")!=draft.source_draft_sha256 :
		status("読み込み不可：基盤または草稿の版が異なります。")
		return false
	var references_match: bool = parsed.get("reference_hashes",{})==draft.reference_hashes
	if not references_match and not parsed.get("reference_hashes",{}) in draft.get("legacy_reference_hashes",[]):
		status("読み込み不可：基盤の版が異なります。")
		return false
	var incoming = parsed.get("boundaries",null)
	if not incoming is Array or incoming.size()>10000: return false
	var ids := {}
	var normalized: Array = []
	for line in incoming:
		if not line is Dictionary or not line.get("boundary_id",null) is String or ids.has(line.boundary_id): return false
		ids[line.boundary_id]=true
		var coords = line.get("points",null)
		if not coords is Array or coords.size()<2 or coords.size()>100000: return false
		for p in coords:
			if not p is Array or p.size()!=2: return false
			for v in p:
				if not (v is float or v is int) or not is_finite(float(v)): return false
			if not bounds.grow(0.01).has_point(Vector2(p[0],p[1])): return false
		var obsolete := false
		var migration: Dictionary = draft.get("shared_boundary_migration",{})
		for removed_id in migration.get("removed_ids",[]):
			if line.boundary_id==removed_id or line.boundary_id.begins_with(str(removed_id)+":cut:") or line.get("source_boundary_id","")==removed_id:
				obsolete=true
		if obsolete: continue
		for mapping in migration.get("endpoint_remaps",[]):
			for end in [0,coords.size()-1]:
				if Vector2(coords[end][0],coords[end][1]).distance_to(Vector2(mapping["from"][0],mapping["from"][1]))<0.003:
					coords[end]=mapping["to"].duplicate()
		normalized.append(line)
		# Original candidate fragments may touch locked seams; only exact seed lines are exempt.
		var original := false
		for seed in draft.boundaries:
			if line.boundary_id==seed.boundary_id and coords==seed.points: original=true; break
			if line.get("source_boundary_id","")==seed.boundary_id and is_seed_subset(points(coords),points(seed.points)):
				original=true; break
		if not original:
			var poly := points(coords)
			for i in range(poly.size()-1):
				if not allowed(poly[i],poly[i+1]): return false
	if record_undo: snapshot()
	lines=normalized.duplicate(true)
	selected_preview=""
	pending=false
	queue_redraw()
	status("JSONを読み込みました。")
	return true

func make_dialog(save: bool) -> void:
	var dialog := FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog=true
	dialog.filters=PackedStringArray(["*.json ; %s国境線 JSON" % region_label])
	dialog.current_dir=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if save: dialog.current_file="%s_border_edits.json" % region_scope
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if save: status("書き出しました："+path if save_edits(path)==OK else "書き出しに失敗しました。")
		elif load_edits(path): changed()
		else: status("読み込みに失敗しました。データ形式・範囲・基盤の版を確認してください。")
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.75)

func export_dialog() -> void: make_dialog(true)
func import_dialog() -> void: make_dialog(false)
func leave_editor() -> void: get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func is_seed_subset(poly: PackedVector2Array,seed: PackedVector2Array) -> bool:
	for i in range(poly.size()-1):
		var steps := maxi(2,ceili(poly[i].distance_to(poly[i+1])/0.5))
		for step in range(steps+1):
			var p := poly[i].lerp(poly[i+1],float(step)/steps)
			var distance := INF
			for j in range(seed.size()-1): distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,seed[j],seed[j+1])))
			if distance>0.003: return false
	return true

func select_preview(p: Vector2) -> String:
	selected_preview = ""
	if JSON.stringify(lines) != JSON.stringify(draft.boundaries):
		status("線が変更されています。枠の再作成には編集JSONを書き出してください。")
		queue_redraw()
		return ""
	for region in draft.get("regions",[]):
		for polygon in region.polygons:
			if Geometry2D.is_point_in_polygon(p,points(polygon)):
				selected_preview = region.region_id
				status("%sの枠を確認中（未確定）" % region.name_ja)
				queue_redraw()
				return selected_preview
	status("枠の確認：国の内側をクリックしてください。")
	queue_redraw()
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: pending=false; box_selecting=false; queue_redraw()
		elif event.ctrl_pressed and event.keycode==KEY_Z: undo()
		elif event.ctrl_pressed and event.keycode==KEY_Y: redo()
		elif event.keycode==KEY_F: fit_map()
	if event is InputEventMouseButton:
		if event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: pending=false; box_selecting=false; queue_redraw()
		if mode==1 and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				box_selecting=true
				box_start=(event.position-offset)/zoom_value
				box_end=box_start
			elif box_selecting:
				box_end=(event.position-offset)/zoom_value
				box_selecting=false
				delete_rectangle(Rect2(box_start,box_end-box_start))
			queue_redraw()
			return
		if box_selecting: return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var world: Vector2 = (event.position-offset)/zoom_value
			zoom_value=clampf(zoom_value*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8),0.08,8.0)
			offset=event.position-world*zoom_value
			queue_redraw()
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
			if event.pressed: dragging=true; moved=false; press=event.position
			else:
				dragging=false
				if event.button_index==MOUSE_BUTTON_LEFT and not moved:
					var p: Vector2 = (event.position-offset)/zoom_value
					if mode==0:
						p=snap_point(p)
						if not bounds.has_point(p): status("%s編集範囲の外です。" % region_label)
						elif not pending: first=p; pending=true; status("終点をクリックしてください。右クリックで取消。")
						elif not add_line(first,p): status("追加不可：同一点、範囲外、または確定済み地域に重なっています。")
					elif mode==2: select_preview(p)
					queue_redraw()
	if event is InputEventMouseMotion and box_selecting:
		box_end=(event.position-offset)/zoom_value
		queue_redraw()
		return
	if event is InputEventMouseMotion and dragging:
		moved=moved or event.position.distance_to(press)>4
		if moved: offset+=event.relative; queue_redraw()

func _draw() -> void:
	if not initialized: return
	draw_set_transform(offset,0,Vector2.ONE*zoom_value)
	for ring in coast_cache: draw_colored_polygon(ring,Color("#faf9f5"))
	for polygon in target_polygons: draw_colored_polygon(polygon,Color("#f4d5d5"))
	if show_reference and texture!=null: draw_texture_rect(texture,raster_rect,false)
	for ring in coast_cache: draw_polyline(ring,Color("#42382e"),1.4/zoom_value,true)
	for line in fixed_lines: draw_polyline(line,Color("#42382e"),1.6/zoom_value,true)
	for line in lines: draw_polyline(points(line.points),Color("#00b9cf"),2.0/zoom_value,true)
	if not selected_preview.is_empty():
		for region in draft.get("regions",[]):
			if region.region_id == selected_preview:
				for polygon in region.polygons: draw_polyline(points(polygon),Color("#f2b633"),3.0/zoom_value,true)
	if pending: draw_circle(first,5.0/zoom_value,Color("#ffae35"))
	if box_selecting:
		var rect := Rect2(box_start,box_end-box_start).abs()
		draw_rect(rect,Color(1,0.25,0.15,0.15),true)
		draw_rect(rect,Color("#e85835"),false,1.5/zoom_value)
