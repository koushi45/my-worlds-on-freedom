shader_type canvas_item;
render_mode unshaded;

uniform float view_zoom = 1.0;
uniform float band_width = 9.0;
uniform vec4 band_color : source_color = vec4(1.0);

varying float inward_ratio;

void vertex() {
    inward_ratio = UV.x * view_zoom / band_width;
}

void fragment() {
    float fade = 1.0 - smoothstep(0.08, 1.0, inward_ratio);
    COLOR = vec4(band_color.rgb, band_color.a * fade);
}
