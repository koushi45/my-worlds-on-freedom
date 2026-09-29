extends Sprite2D
## North-up contour basemap from unexaggerated measured elevations.
const FIELD = preload("res://assets/map/elevation/contour_height_field.png")
const CONTOUR_SHADER = preload("res://scripts/map/contour_map.gdshader")

func _ready() -> void:
	name = "DeveloperContours"
	z_index = 7
	centered = false
	texture = FIELD
	scale = Vector2(8192.0/FIELD.get_width(),8192.0/FIELD.get_height())
	var style := ShaderMaterial.new()
	style.shader = CONTOUR_SHADER
	style.set_shader_parameter("height_field",FIELD)
	style.set_shader_parameter("interval_m",50.0)
	style.set_shader_parameter("index_interval_m",250.0)
	material = style
