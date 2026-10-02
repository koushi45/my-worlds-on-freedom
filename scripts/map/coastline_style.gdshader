shader_type canvas_item;
render_mode unshaded;

uniform sampler2D coast_style_field : filter_linear_mipmap, repeat_disable;
uniform vec2 source_origin = vec2(0.0);
uniform vec2 source_span = vec2(8192.0);

varying vec2 source_position;

void vertex() {
	source_position = source_origin + UV * source_span;
}

void fragment() {
	float ink = texture(TEXTURE, UV).a;
	float cliff = texture(coast_style_field, clamp(source_position / 8192.0, vec2(0.0), vec2(1.0))).g;
	vec3 sand_foam = vec3(0.90, 0.84, 0.68);
	vec3 cliff_contact = vec3(0.15, 0.24, 0.26);
	COLOR = vec4(mix(sand_foam, cliff_contact, cliff), ink);
}
