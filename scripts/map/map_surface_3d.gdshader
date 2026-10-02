shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D surface_map : source_color, filter_linear;
uniform sampler2D far_albedo : source_color, filter_linear_mipmap;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float material_world_span = 24.0;
uniform float material_strength = 0.0;
uniform vec2 source_origin;
uniform vec2 source_span;
uniform float source_heading = 0.0;
uniform vec4 fine_rect;
uniform bool fine_active = false;
uniform bool is_fine = false;
uniform vec4 fuji_rect;
uniform bool fuji_active = false;
uniform bool is_fuji = false;
uniform float haze_strength = 0.0;
uniform vec3 focus_point;
uniform float height_factor = 1.0;
varying vec3 map_position;
varying vec3 slope_normal;

void vertex() {
    VERTEX.y *= height_factor;
    if (height_factor < 0.5) NORMAL = vec3(0.0, 1.0, 0.0);
    TANGENT = normalize(vec3(1.0,0.0,0.0)-NORMAL*NORMAL.x);
    BINORMAL = normalize(cross(TANGENT,NORMAL));
    slope_normal = NORMAL;
    map_position = VERTEX;
}

void fragment() {
    vec2 world = map_position.xz + vec2(4096.0);
    if (fuji_active && !is_fuji && all(greaterThan(world,fuji_rect.xy)) && all(lessThan(world,fuji_rect.zw))) discard;
    vec2 offset = world - (source_origin + source_span * 0.5);
    float c = cos(source_heading);
    float s = sin(source_heading);
    vec2 source_uv = vec2(c*offset.x-s*offset.y,s*offset.x+c*offset.y) / source_span + vec2(0.5);
    if (fine_active && !is_fine && all(greaterThan(world,fine_rect.xy)) && all(lessThan(world,fine_rect.zw))) discard;
    vec4 far_colour = texture(far_albedo,world/8192.0);
    vec3 colour = mix(vec3(0.114,0.224,0.282),far_colour.rgb,far_colour.a);
    if (all(greaterThanEqual(source_uv,vec2(0.0))) && all(lessThanEqual(source_uv,vec2(1.0)))) {
        vec2 edge = min(source_uv,vec2(1.0)-source_uv)*source_span;
        float blend = smoothstep(0.0,12.0,min(edge.x,edge.y));
        colour = mix(colour,texture(surface_map,source_uv).rgb,blend);
    }
    float distance_to_focus = length(map_position.xz-focus_point.xz);
    float snow = smoothstep(0.52,0.74,min(far_colour.r,min(far_colour.g,far_colour.b)));
    float forest = (1.0-smoothstep(0.12,0.29,far_colour.g))*(1.0-snow);
    float stone = smoothstep(0.20,0.65,1.0-slope_normal.y)*(1.0-snow)*(1.0-forest*0.55);
    vec4 weights = vec4((1.0-forest)*(1.0-stone)*(1.0-snow),forest*(1.0-stone),stone,snow);
    weights /= max(dot(weights,vec4(1.0)),0.001);
    // Colourful geographic ink and water keep their original appearance.
    float green = smoothstep(0.82,1.03,colour.g/max(colour.r,0.001))*smoothstep(1.05,1.40,colour.g/max(colour.b,0.001));
    float neutral = (1.0-smoothstep(0.06,0.18,abs(colour.r-colour.g)+abs(colour.g-colour.b)))*max(stone,snow);
    float mask = clamp(max(green,neutral),0.0,1.0)*far_colour.a;
    float strength = material_strength*mask*(1.0-smoothstep(450.0,1600.0,distance_to_focus));
    vec2 detail_uv = world/material_world_span;
    vec3 grass = texture(grass_albedo,detail_uv).rgb;
    vec3 forest_colour = texture(forest_albedo,detail_uv+vec2(0.37,0.19)).rgb;
    vec3 rock = texture(rock_albedo,detail_uv+vec2(0.13,0.61)).rgb;
    vec3 snow_colour = texture(snow_albedo,detail_uv).rgb;
    // Normalize each material to preserve the established large vegetation colours.
    // Coarsest mip measures the material mean in the renderer's actual colour space.
    vec3 ratio = weights.x*grass/max(textureLod(grass_albedo,vec2(0.5),14.0).rgb,vec3(0.01))
               +weights.y*forest_colour/max(textureLod(forest_albedo,vec2(0.5),14.0).rgb,vec3(0.01))
               +weights.z*rock/max(textureLod(rock_albedo,vec2(0.5),14.0).rgb,vec3(0.01))
               +weights.w*snow_colour/max(textureLod(snow_albedo,vec2(0.5),14.0).rgb,vec3(0.01));
    colour *= mix(vec3(1.0),clamp(ratio,vec3(0.42),vec3(1.65)),strength);
    vec3 normal_colour = weights.x*texture(grass_normal,detail_uv).rgb
                      +weights.y*texture(forest_normal,detail_uv+vec2(0.37,0.19)).rgb
                      +weights.z*texture(rock_normal,detail_uv+vec2(0.13,0.61)).rgb
                      +weights.w*texture(snow_normal,detail_uv).rgb;
    NORMAL_MAP = normal_colour;
    NORMAL_MAP_DEPTH = strength*0.70*height_factor;
    float haze = (1.0-exp(-max(0.0,distance_to_focus-140.0)/1800.0))*haze_strength;
    ALBEDO = colour*(1.0-haze);
    EMISSION = vec3(0.48,0.64,0.70)*haze;
    ROUGHNESS = 1.0;
}
