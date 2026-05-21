shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_disabled;

uniform sampler2D unit_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.34;
uniform float shade_strength : hint_range(0.0, 0.8) = 0.22;

void fragment() {
	vec4 tex = texture(unit_tex, UV);
	if (tex.a <= 0.01) {
		discard;
	}

	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2) * rim_strength;
	float side_shade = (UV.x - 0.5) * shade_strength;
	ALBEDO = clamp(tex.rgb + rim - side_shade, vec3(0.0), vec3(1.0));
	ALPHA = tex.a;
	ROUGHNESS = 0.72;
}
