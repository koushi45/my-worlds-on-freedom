extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	var geometry=load("res://scripts/map/map_line_geometry.gd")
	var arrays: Array=geometry.arrays_for([PackedVector2Array([Vector2(50,80),Vector2(550,80)])])
	var node:=MeshInstance2D.new()
	node.mesh=ArrayMesh.new();node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var style:=ShaderMaterial.new();style.shader=load("res://scripts/map/line_mesh.gdshader")
	style.set_shader_parameter("dashed",true);style.set_shader_parameter("half_width",2.0)
	style.set_shader_parameter("view_zoom",1.0);style.set_shader_parameter("line_color",Color.WHITE)
	node.material=style;root.add_child(node)
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var valid:=true
	for x in [52,62,252,452]:valid=valid and image.get_pixel(x,80).r>0.8
	for x in [58,68,258,458]:valid=valid and image.get_pixel(x,80).r<0.2
	image.save_png("res://builds/seamless/dash_shader.png")
	print("DASH SHADER GPU: ","PASS" if valid else "FAIL")
	quit(0 if valid else 1)
