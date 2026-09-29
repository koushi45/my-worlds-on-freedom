shader_type canvas_item;
render_mode unshaded;

uniform sampler2D height_field : filter_nearest, repeat_disable;
uniform float interval_m = 50.0;
uniform float index_interval_m = 250.0;

float meters(vec2 uv) {
	vec2 encoded = texture(height_field, uv).rg;
	return round(encoded.r * 255.0) * 256.0 + round(encoded.g * 255.0);
}

float contour(float height, float interval, float width) {
	float level = height / interval;
	float distance_to_line = abs(fract(level + 0.5) - 0.5);
	float aa = max(fwidth(level), 0.00001);
	return 1.0 - smoothstep(aa * width, aa * (width + 0.8), distance_to_line);
}

void fragment() {
	vec2 size = vec2(textureSize(height_field, 0));
	vec2 position = UV * size - 0.5;
	vec2 base = floor(position);
	vec2 blend = fract(position);
	vec2 uv = (base + 0.5) / size;
	vec2 step_uv = 1.0 / size;
	// Decode before interpolation so carrying from the low byte is exact.
	float h = mix(mix(meters(uv), meters(uv + vec2(step_uv.x,0.0)), blend.x),
		mix(meters(uv + vec2(0.0,step_uv.y)), meters(uv + step_uv), blend.x), blend.y);
	float minor = contour(h, interval_m, 0.35);
	float major = contour(h, index_interval_m, 0.8);
	// Flat zero-height land is not itself a contour; no bathymetry is present.
	float gradient = length(vec2(dFdx(h), dFdy(h)));
	float valid = step(25.0,h) * step(0.0001,gradient);
	vec3 paper = vec3(0.95,0.94,0.87);
	vec3 lines = mix(paper,vec3(0.62,0.47,0.30),minor * valid);
	lines = mix(lines,vec3(0.35,0.26,0.17),major * valid);
	float land = step(0.5,texture(height_field,UV).b);
	COLOR = vec4(mix(vec3(0.75,0.86,0.90),lines,land),1.0);
}
