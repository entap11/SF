shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.90, 0.74, 0.09, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.831, 0.0, 1.0);
uniform vec4 stroke_color : source_color = vec4(0.44, 0.28, 0.05, 1.0);
uniform float stroke_width : hint_range(0.5, 2.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.80, 0.22, 1.0);
uniform float glow_strength : hint_range(0.0, 0.8) = 0.22;
uniform float glow_radius : hint_range(1.0, 4.0) = 2.3;
uniform float bevel_strength : hint_range(0.0, 1.0) = 0.20;
uniform float inner_shadow_strength : hint_range(0.0, 1.0) = 0.16;
uniform float sweep_pos : hint_range(-0.5, 1.5) = -0.3;
uniform float sweep_width : hint_range(0.02, 0.5) = 0.18;
uniform float sweep_strength : hint_range(0.0, 1.5) = 0.0;

float sample_alpha(vec2 uv) {
	return texture(TEXTURE, uv).a * COLOR.a;
}

void fragment() {
	float alpha = sample_alpha(UV);
	if (alpha <= 0.001) {
		discard;
	}

	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 stroke_step = texel * stroke_width;
	float a_r = sample_alpha(UV + vec2(stroke_step.x, 0.0));
	float a_l = sample_alpha(UV + vec2(-stroke_step.x, 0.0));
	float a_d = sample_alpha(UV + vec2(0.0, stroke_step.y));
	float a_u = sample_alpha(UV + vec2(0.0, -stroke_step.y));
	float a_ur = sample_alpha(UV + vec2(stroke_step.x, -stroke_step.y));
	float a_ul = sample_alpha(UV + vec2(-stroke_step.x, -stroke_step.y));
	float a_dr = sample_alpha(UV + vec2(stroke_step.x, stroke_step.y));
	float a_dl = sample_alpha(UV + vec2(-stroke_step.x, stroke_step.y));

	float dilated = max(max(max(a_r, a_l), max(a_d, a_u)), max(max(a_ur, a_ul), max(a_dr, a_dl)));
	float outline = clamp(dilated - alpha, 0.0, 1.0);

	vec2 glow_step = texel * glow_radius;
	float g_r = sample_alpha(UV + vec2(glow_step.x, 0.0));
	float g_l = sample_alpha(UV + vec2(-glow_step.x, 0.0));
	float g_d = sample_alpha(UV + vec2(0.0, glow_step.y));
	float g_u = sample_alpha(UV + vec2(0.0, -glow_step.y));
	float g_ur = sample_alpha(UV + vec2(glow_step.x, -glow_step.y));
	float g_ul = sample_alpha(UV + vec2(-glow_step.x, -glow_step.y));
	float g_dr = sample_alpha(UV + vec2(glow_step.x, glow_step.y));
	float g_dl = sample_alpha(UV + vec2(-glow_step.x, glow_step.y));
	float glow_mask = max(max(max(g_r, g_l), max(g_d, g_u)), max(max(g_ur, g_ul), max(g_dr, g_dl)));
	float glow = clamp(glow_mask - alpha, 0.0, 1.0) * glow_strength;

	float eroded = min(min(min(a_r, a_l), min(a_d, a_u)), min(min(a_ur, a_ul), min(a_dr, a_dl)));
	float inner_edge = clamp(alpha - eroded, 0.0, 1.0);
	float inner_shadow = inner_edge * inner_shadow_strength;

	float bevel_sample_l = sample_alpha(UV + vec2(-texel.x, 0.0));
	float bevel_sample_r = sample_alpha(UV + vec2(texel.x, 0.0));
	float bevel_sample_u = sample_alpha(UV + vec2(0.0, -texel.y));
	float bevel_sample_d = sample_alpha(UV + vec2(0.0, texel.y));
	vec2 gradient = vec2(bevel_sample_r - bevel_sample_l, bevel_sample_d - bevel_sample_u);
	vec2 light_dir = normalize(vec2(-0.55, -0.85));
	float bevel = clamp(dot(-gradient, light_dir), -1.0, 1.0) * bevel_strength;

	float grad_t = clamp(UV.y, 0.0, 1.0);
	vec3 fill = mix(top_color.rgb, bottom_color.rgb, grad_t);
	fill *= COLOR.rgb;
	fill *= 1.0 + bevel;
	fill *= 1.0 - inner_shadow;

	float sweep_dist = abs(UV.x - sweep_pos);
	float sweep = exp(-pow(sweep_dist / max(sweep_width, 0.001), 2.0));
	vec3 sweep_color = glow_color.rgb * (sweep * sweep_strength * 0.5);

	vec3 final_rgb = fill * alpha;
	final_rgb += stroke_color.rgb * outline;
	final_rgb += glow_color.rgb * glow;
	final_rgb += sweep_color * alpha;
	float final_alpha = clamp(alpha + outline + glow, 0.0, 1.0);
	COLOR = vec4(final_rgb, final_alpha);
}
