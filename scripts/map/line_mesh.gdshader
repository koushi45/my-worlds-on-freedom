shader_type canvas_item;
render_mode unshaded;
uniform float view_zoom = 1.0;
uniform float half_width = 1.0;
uniform vec4 line_color : source_color = vec4(1.0);
uniform bool dashed = false;
varying float line_distance;
varying float edge_distance;
void vertex() {
    line_distance = dot(COLOR.rgb, vec3(65536.0, 256.0, 1.0)) * (255.0 / 64.0);
    float side = (VERTEX_ID % 2 == 0) ? -1.0 : 1.0;
    edge_distance = side * (half_width + 0.75);
    VERTEX += UV * (half_width + 0.75) / view_zoom;
}
void fragment() {
    float dash_alpha = dashed ? 1.0 - smoothstep(5.5, 6.5, mod(line_distance * view_zoom, 10.0)) : 1.0;
    COLOR = vec4(line_color.rgb, line_color.a * dash_alpha * clamp(half_width + 0.5 - abs(edge_distance), 0.0, 1.0));
}
