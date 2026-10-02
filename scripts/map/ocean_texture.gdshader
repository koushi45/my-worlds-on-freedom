shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ocean_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D coast_style_field : filter_linear_mipmap, repeat_disable;
uniform float repeat_world_size = 512.0;
uniform vec2 source_origin = vec2(0.0);
uniform vec2 source_span = vec2(8192.0);
uniform bool water_only = false;
global uniform float terrain_haze_strength;

varying vec2 source_position;

vec3 tiled_water(vec2 position) {
	vec2 uv = position / repeat_world_size + vec2(TIME * 0.002, TIME * 0.0007);
	vec2 phase = fract(uv);
	vec2 blend = smoothstep(vec2(0.0), vec2(0.5), phase)
		* (vec2(1.0) - smoothstep(vec2(0.5), vec2(1.0), phase));
	vec3 a = texture(ocean_texture, uv).rgb;
	vec3 b = texture(ocean_texture, uv + vec2(0.5, 0.0)).rgb;
	vec3 c = texture(ocean_texture, uv + vec2(0.0, 0.5)).rgb;
	vec3 d = texture(ocean_texture, uv + vec2(0.5, 0.5)).rgb;
	return mix(mix(d, c, blend.x), mix(b, a, blend.x), blend.y);
}

void vertex() {
	source_position = source_origin + UV * source_span;
}

void fragment() {
	vec4 map_color = texture(TEXTURE, UV);
	vec4 coast = texture(coast_style_field, clamp(source_position / 8192.0, vec2(0.0), vec2(1.0)));
	float water_mask = 1.0 - smoothstep(0.35, 0.65, coast.b);
	float distance_to_shore = coast.r * 128.0;
	float cliff = coast.g;
	vec3 patterned_sea = tiled_water(source_position);
	float shallow = 1.0 - smoothstep(2.0, mix(48.0, 30.0, cliff), distance_to_shore);
	// Keep the existing wave variation but shift it towards a quiet blue-grey.
	float wave_luma = dot(patterned_sea, vec3(0.2126, 0.7152, 0.0722));
	patterned_sea = vec3(0.16, 0.23, 0.29) + vec3(wave_luma - 0.25) * 0.32;
	vec3 nearshore = mix(vec3(0.28, 0.42, 0.43), vec3(0.21, 0.32, 0.36), cliff);
	vec3 sea_color = mix(patterned_sea, nearshore, shallow * 0.48);
	float glint = max(patterned_sea.r, max(patterned_sea.g, patterned_sea.b));
	sea_color += vec3(0.5, 0.8, 0.85) * smoothstep(0.35, 0.6, glint) * shallow * 0.03;
	float foam = (1.0 - smoothstep(0.0, 4.0, distance_to_shore)) * (1.0 - cliff);
	sea_color = mix(sea_color, vec3(0.78, 0.84, 0.73), foam * 0.13);
	float far_side = 1.0 - smoothstep(0.15, 0.75, SCREEN_UV.y);
	float haze = far_side * far_side * terrain_haze_strength;
	sea_color = mix(sea_color, vec3(0.38, 0.47, 0.52), haze);
	if (water_only) {
		COLOR = vec4(sea_color, 1.0);
	} else {
		float land_distance = max(0.0, coast.a * 255.0 - 128.0) * (32.0 / 127.0);
		float land_shadow = smoothstep(0.6, 0.8, coast.b) * cliff * (1.0 - smoothstep(0.0, 12.0, land_distance));
		vec3 land_color = map_color.rgb * (1.0 - 0.16 * land_shadow);
		land_color = mix(land_color, vec3(0.38, 0.47, 0.52), haze);
		COLOR = vec4(mix(land_color, sea_color, water_mask), map_color.a);
	}
}
