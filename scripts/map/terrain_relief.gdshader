shader_type canvas_item;
render_mode unshaded;

global uniform float terrain_haze_strength;
uniform vec2 source_origin = vec2(0.0);
uniform vec2 source_span = vec2(8192.0);
uniform float gutter_uv = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 terrain = texture(TEXTURE, UV);
	vec2 source_uv = (UV - vec2(gutter_uv)) / (1.0 - 2.0 * gutter_uv);
	vec2 world_uv = (source_origin + source_uv * source_span) / 8192.0;
	// Unlit colour; the 3D terrain supplies normals, sun and cast shadows.
	float far_side = 1.0 - smoothstep(0.15, 0.75, SCREEN_UV.y);
	vec3 colour = mix(terrain.rgb, vec3(0.38, 0.47, 0.52), far_side * far_side * terrain_haze_strength);
	COLOR = vec4(colour, terrain.a) * tint;
}
