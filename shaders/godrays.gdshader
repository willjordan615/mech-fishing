shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, world_vertex_coords;

uniform vec4 ray_color : source_color = vec4(0.3, 0.5, 0.8, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.15;
uniform float flicker_speed : hint_range(0.0, 5.0) = 0.8;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec3 player_pos = vec3(0.0);
uniform float fade_start : hint_range(0.0, 300.0) = 60.0;
uniform float fade_end : hint_range(0.0, 300.0) = 140.0;

void fragment() {
    float depth_fade = 1.0 - UV.y;
    depth_fade = pow(depth_fade, 2.0);

    float flicker = 1.0 - flicker_intensity *
        (0.5 + 0.5 * sin(TIME * flicker_speed + UV.x * 10.0));

    vec2 flat_dist = vec2(VERTEX.x - player_pos.x, VERTEX.z - player_pos.z);
    float dist = length(flat_dist);
    float dist_fade = 1.0 - smoothstep(fade_start, fade_end, dist);

    float alpha = opacity * depth_fade * flicker * dist_fade;

    ALBEDO = ray_color.rgb;
    ALPHA = alpha;
}