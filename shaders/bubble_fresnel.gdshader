shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

// Fresnel power — higher = thinner, sharper rim
uniform float fresnel_power: hint_range(1.0, 8.0) = 3.5;

// Rim color — cool blue-white like underwater bubble edge
uniform vec4 rim_color: source_color = vec4(0.78, 0.92, 1.0, 1.0);

// Overall opacity scale — tune per emitter variant
uniform float alpha_scale: hint_range(0.0, 1.0) = 0.85;

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow(1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0), amount);
}

void fragment() {
	float f = fresnel(fresnel_power, NORMAL, VIEW);

	// Rim is bright, center is transparent — matches real bubble refraction
	ALBEDO = rim_color.rgb * f;
	ALPHA  = f * alpha_scale;
}
