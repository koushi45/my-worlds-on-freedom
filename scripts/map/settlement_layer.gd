extends Node2D
## Historical sites use original geographic anchors; labels alone may move.
signal site_selected(site_id: String)
var elevation: RefCounted
var roads: Node2D
var data: Dictionary
var view_zoom := 1.0
var view_rect := Rect2()
var enabled_roles := {"castle":true,"settlement":true,"port":true}
var show_deferred := false
var selected_id := ""
var drawn_ids: Array[String] = []
var label_rects: Array[Rect2] = []
var labeled_ids: Array[String] = []
var lookup: Dictionary = {}
var label_offsets: Dictionary = {}
var last_layout_ms := -150
var last_selected := ""
var layout_pending := true

func _ready() -> void:
	z_index = 24
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/derived/settlements/settlements_1582.json"))
	for site in data["sites"]: lookup[site["id"]] = site

func point(raw: Array) -> Vector2:
	return Vector2(float(raw[0]),float(raw[1]))

func eligible(site: Dictionary) -> bool:
	if site["point"] == null or site["adoption_status"] == "excluded": return false
	if site["adoption_status"] == "deferred" and not show_deferred: return false
	for role in site["roles"]:
		if enabled_roles.get(role,false): return true
	return false

func set_role(value: bool, role: String) -> void:
	enabled_roles[role] = value
	queue_redraw()

func update_view(rect: Rect2, zoom_value: float) -> void:
	if view_rect == rect and is_equal_approx(view_zoom,zoom_value): return
	layout_pending=true
	view_rect = rect
	view_zoom = zoom_value
	queue_redraw()

func pick(screen: Vector2) -> String:
	if not visible: return ""
	var best := ""
	var distance := 14.0
	for id in drawn_ids:
		var p: Vector2 = get_global_transform_with_canvas()*elevation.project(point(lookup[id]["display_point"]))
		var d := screen.distance_to(p)
		if d < distance: distance = d; best = id
	return best

func _draw() -> void:
	drawn_ids.clear(); label_rects.clear(); labeled_ids.clear()
	if data == null: return
	var rebuild_layout := Time.get_ticks_msec()-last_layout_ms>=120 or last_selected!=selected_id
	if rebuild_layout:
		last_layout_ms=Time.get_ticks_msec();last_selected=selected_id;label_offsets.clear();layout_pending=false
	var nodes: Array = data["sites"].duplicate()
	nodes.sort_custom(func(a: Dictionary,b: Dictionary):
		if a["id"]==selected_id: return b["id"]!=selected_id
		if b["id"]==selected_id: return false
		return int(a["importance"])<int(b["importance"]))
	var groups: Dictionary = {}
	var font := ThemeDB.fallback_font
	for site in nodes:
		if not eligible(site): continue
		var selected: bool = site["id"]==selected_id
		if view_zoom < 0.2 and int(site["importance"])>1 and not selected: continue
		if not view_rect.has_point(point(site["point"])): continue
		if view_zoom < 1.2 and groups.has(site["site_group_id"]) and not selected: continue
		groups[site["site_group_id"]]=true
		var p: Vector2 = elevation.project(point(site["display_point"]))
		var screen: Vector2 = get_global_transform_with_canvas()*p
		var viewport := get_viewport_rect().size
		if screen.x < 8 or screen.x > viewport.x-8 or screen.y < 8 or screen.y > viewport.y-8: continue
		drawn_ids.append(site["id"])
		var symbol := "settlement"
		if "castle" in site["roles"] and enabled_roles["castle"]: symbol="castle"
		elif "port" in site["roles"] and enabled_roles["port"]: symbol="port"
		var color := Color("#ffcf86") if symbol=="castle" else Color("#8fe1ef") if symbol=="port" else Color("#e4e8ba")
		if site["adoption_status"] == "deferred": color = Color("#aeb6bf")
		draw_set_transform(p,0,Vector2.ONE/view_zoom)
		draw_circle(Vector2.ZERO,9,Color("#253634"))
		if symbol=="castle":
			draw_rect(Rect2(-6,-2,12,8),color,false,2)
			for x in [-5,0,5]: draw_line(Vector2(x,-2),Vector2(x,-7),color,2)
		elif symbol=="port":
			draw_arc(Vector2.ZERO,6,0,PI,16,color,2,true)
			draw_line(Vector2(0,-5),Vector2(0,6),color,2,true)
			draw_line(Vector2(-4,-2),Vector2(4,-2),color,2,true)
			draw_arc(Vector2(0,-7),2,0,TAU,12,color,1.5,true)
		else: draw_circle(Vector2.ZERO,5,color)
		if selected: draw_arc(Vector2.ZERO,12,0,TAU,32,Color.WHITE,2,true)
		draw_set_transform(Vector2.ZERO)
		var title := str(site["display_name"])
		var size := Vector2(font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+6,22)
		var offsets := [Vector2(14,-12),Vector2(14,25),Vector2(-size.x-14,-12),Vector2(-size.x-14,25),Vector2(14,-37),Vector2(14,50)]
		var chosen := Vector2.ZERO
		var found := false
		if not rebuild_layout and label_offsets.has(site["id"]):
			chosen=label_offsets[site["id"]];found=true
			label_rects.append(Rect2(screen+chosen-Vector2(0,17),size))
		elif rebuild_layout:
			for offset in offsets:
				var rect := Rect2(screen+offset-Vector2(0,17),size)
				if rect.position.x<8 or rect.end.x>viewport.x-8 or rect.position.y<8 or rect.end.y>viewport.y-8: continue
				var crowded := false
				if roads != null and roads.visible and not selected:
					for other in roads.screen_label_rects:
						if rect.intersects(other.grow(2)): crowded=true;break
				for other in label_rects:
					if rect.intersects(other.grow(2)): crowded=true; break
				if crowded: continue
				chosen=offset;found=true;label_rects.append(rect);break
		if not found: continue
		label_offsets[site["id"]]=chosen
		labeled_ids.append(site["id"])
		draw_line(p,p+chosen/view_zoom,Color(color,0.6),1.0/view_zoom,true)
		draw_set_transform(p+chosen/view_zoom,0,Vector2.ONE/view_zoom)
		draw_string_outline(font,Vector2.ZERO,title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,5,Color("#27342d"))
		draw_string(font,Vector2.ZERO,title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
		draw_set_transform(Vector2.ZERO)

func _process(_delta: float) -> void:
	if layout_pending and Time.get_ticks_msec()-last_layout_ms>=150:queue_redraw()
