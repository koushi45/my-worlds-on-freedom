extends MeshInstance2D
## One indexed GPU mesh per line style, with screen-space width and edge coverage.
const LINE_SHADER = preload("res://scripts/map/line_mesh.gdshader")
var style: ShaderMaterial
var buffer_bytes := 0
var last_segments := PackedVector2Array()

func _init() -> void:
	style=ShaderMaterial.new();style.shader=LINE_SHADER;material=style

func configure(segments: PackedVector2Array, width: float, color: Color, zoom_value: float) -> void:
	style.set_shader_parameter("view_zoom",zoom_value)
	style.set_shader_parameter("half_width",width*.5)
	style.set_shader_parameter("line_color",color)
	visible=true
	if segments==last_segments and mesh!=null:return
	last_segments=segments
	var count:=segments.size()/2
	var vertices:=PackedVector2Array();vertices.resize(count*4)
	var offsets:=PackedVector2Array();offsets.resize(count*4)
	var indices:=PackedInt32Array();indices.resize(count*6)
	for i in range(count):
		var a:=segments[i*2];var b:=segments[i*2+1]
		var direction:Vector2=(b-a).normalized();var normal:=Vector2(-direction.y,direction.x)
		var v:=i*4;var t:=i*6
		vertices[v]=a;vertices[v+1]=a;vertices[v+2]=b;vertices[v+3]=b
		offsets[v]=-normal;offsets[v+1]=normal;offsets[v+2]=-normal;offsets[v+3]=normal
		indices[t]=v;indices[t+1]=v+1;indices[t+2]=v+2;indices[t+3]=v+1;indices[t+4]=v+3;indices[t+5]=v+2
	if count==0:mesh=null;return
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=offsets;arrays[Mesh.ARRAY_INDEX]=indices
	var next:=ArrayMesh.new();next.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	mesh=next;buffer_bytes=vertices.size()*16+indices.size()*4
	visible=true
