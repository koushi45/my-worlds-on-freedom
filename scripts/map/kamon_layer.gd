extends Node2D
## Family crests are a dedicated overlay anchored at each district's representative point.
const KAMON_INDEX := "res://assets/kamon/index.json"
const KAMON_SCREEN_SIZE := 28.0
const KAMON_MIN_SCREEN_SIZE := 24.0
const KAMON_MAX_SCALE := 1.6
const KAMON_REFERENCE_AREA := 9850.0

var district_layer: Node2D
var elevation: RefCounted
var governance_registry: RefCounted
var territory_borders: Node2D
var kamon_by_house: Dictionary = {}
var kamon_textures: Dictionary = {}
var visible_keys: Array = []
var view_rect := Rect2()
var view_zoom := 1.0
var label_count := 0
var drawn_keys: Array = []

func _ready() -> void:
	# Crests remain readable above settlement names (settlements use 24).
	z_index = 25
	_load_assets()
	district_layer.visibility_changed.connect(_sync_district_visibility)
	_sync_district_visibility()

func _load_assets() -> void:
	kamon_by_house.clear()
	kamon_textures.clear()
	if not FileAccess.file_exists(KAMON_INDEX):
		push_warning("Kamon index is missing")
		return
	var index = JSON.parse_string(FileAccess.get_file_as_string(KAMON_INDEX))
	if not index is Dictionary: return
	kamon_by_house = index.get("houses", {})
	for entry in kamon_by_house.values():
		var asset: String = entry.get("asset", "")
		if asset.is_empty() or kamon_textures.has(asset): continue
		# Exported PCKs contain the imported SVG texture, not the source SVG text.
		# ResourceLoader therefore works both in the editor and in Windows exports.
		var imported := ResourceLoader.load(asset, "Texture2D") as Texture2D
		if imported == null: continue
		var image := imported.get_image()
		if image == null or image.is_empty(): continue
		image.convert(Image.FORMAT_RGBA8)
		# Crests are monochrome white; retain only the imported antialiased alpha.
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var alpha := image.get_pixel(x,y).a
				if alpha > 0.0: image.set_pixel(x,y,Color(1.0,1.0,1.0,alpha))
		kamon_textures[asset] = ImageTexture.create_from_image(image)
	if kamon_textures.is_empty(): push_error("No kamon textures could be loaded")
	else: print("KAMON TEXTURES: %d" % kamon_textures.size())
	queue_redraw()

func _sync_district_visibility() -> void:
	visible = true
	visible_keys = district_layer.query(view_rect)
	queue_redraw()

func update_view(rect: Rect2, zoom_value: float) -> void:
	if rect == view_rect and is_equal_approx(view_zoom,zoom_value): return
	view_rect = rect
	view_zoom = zoom_value
	visible_keys = district_layer.query(rect)
	queue_redraw()

func invalidate_surface() -> void:
	queue_redraw()

func kamon_screen_size(key: String) -> float:
	var map_area := KAMON_REFERENCE_AREA
	if district_layer.independent_geometry != null and district_layer.independent_geometry.regions.has(key):
		map_area = float(district_layer.independent_geometry.regions[key].get("map_area", KAMON_REFERENCE_AREA))
	var area_scale := minf(pow(maxf(map_area,0.001)/KAMON_REFERENCE_AREA,0.25),KAMON_MAX_SCALE)
	return maxf(KAMON_MIN_SCREEN_SIZE,KAMON_SCREEN_SIZE * area_scale)

func kamon_background_color(house_id: String) -> Color:
	var color: Color = territory_borders.theme_color(house_id) if territory_borders != null else Color("#8b7c67")
	color.a = 0.92
	return color

func _draw() -> void:
	label_count = 0
	drawn_keys.clear()
	if district_layer == null or not district_layer.initialized: return
	if view_zoom <= 2.0 and territory_borders != null:
		for country_id in territory_borders.country_records:
			var country: Dictionary = territory_borders.country_records[country_id]
			var anchor: Vector2 = country.anchor
			if not view_rect.has_point(anchor): continue
			var representative: String = country.representative_district
			if not governance_registry.districts.has(representative): continue
			_draw_kamon("country:"+str(country_id),anchor,governance_registry.districts[representative].house_id,34.0)
		return
	for key in visible_keys:
		var record: Dictionary = district_layer.records[key]
		var anchor := Vector2(record["label"][0],record["label"][1])
		if not view_rect.has_point(anchor): continue
		if governance_registry == null or not governance_registry.districts.has(key): continue
		_draw_kamon(key,anchor,governance_registry.districts[key].get("house_id", ""),kamon_screen_size(key))

func _draw_kamon(key: String, anchor: Vector2, house_id: String, screen_size: float) -> void:
	var point: Vector2 = elevation.project(anchor)
	var screen: Vector2 = get_global_transform_with_canvas()*point
	if screen.x<8 or screen.y<8 or screen.x>get_viewport_rect().size.x-8 or screen.y>get_viewport_rect().size.y-8: return
	var entry: Dictionary = kamon_by_house.get(house_id, {})
	var asset: String = entry.get("asset", "")
	if not kamon_textures.has(asset): return
	draw_set_transform(point,0,Vector2.ONE/view_zoom)
	draw_circle(Vector2.ZERO,screen_size*0.55,kamon_background_color(house_id))
	draw_circle(Vector2.ZERO,screen_size*0.55,Color(1,1,1,0.82),false,1.0,true)
	var icon_rect := Rect2(Vector2.ONE * -screen_size*0.45,Vector2.ONE*screen_size*0.9)
	draw_texture_rect(kamon_textures[asset],icon_rect,false,Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	label_count += 1
	drawn_keys.append(key)
