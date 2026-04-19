shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform float scroll_speed_a : hint_range(0.0, 1.0) = 0.08;
uniform float scroll_speed_b : hint_range(0.0, 1.0) = 0.05;
uniform float caustic_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float alpha : hint_range(0.0, 1.0) = 0.55;
uniform vec4 water_color : source_color = vec4(0.05, 0.18, 0.35, 1.0);

// Simple hash for noise
float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// Voronoi — returns distance to nearest point
float voronoi(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float min_dist = 1.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = vec2(hash(i + neighbor), hash(i + neighbor + vec2(1.0, 0.0)));
            vec2 diff = neighbor + point - f;
            min_dist = min(min_dist, length(diff));
        }
    }
    return min_dist;
}

void fragment() {
    vec2 uv = UV * 100.0;
    
    // Two noise layers scrolling in different directions
    vec2 scroll_a = vec2(TIME * scroll_speed_a, TIME * scroll_speed_a * 0.7);
    vec2 scroll_b = vec2(-TIME * scroll_speed_b * 0.8, TIME * scroll_speed_b);
    
    float layer_a = voronoi(uv + scroll_a);
    float layer_b = voronoi(uv * 1.3 + scroll_b);
    
    // Caustic pattern: bright where both layers are bright
    float caustic = pow(1.0 - (layer_a * 0.5 + layer_b * 0.5), 3.0) * caustic_intensity;
    
    // Fresnel — brighter at glancing angles
    float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
    
    vec3 color = water_color.rgb + vec3(caustic) + vec3(fresnel * 0.3);
    
    ALBEDO = color;
    ALPHA = alpha + fresnel * 0.2;
    EMISSION = vec3(0.0, caustic * 0.6, caustic * 0.9);
}