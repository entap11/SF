shader_type canvas_item;
render_mode unshaded;

uniform vec4 steel_dark : source_color = vec4(0.055, 0.058, 0.064, 1.0);
uniform vec4 steel_mid : source_color = vec4(0.10, 0.105, 0.115, 1.0);
uniform vec4 steel_high : source_color = vec4(0.20, 0.205, 0.22, 1.0);
uniform float brushed_strength : hint_range(0.0, 0.25) = 0.07;
uniform float bevel_strength : hint_range(0.0, 0.6) = 0.24;
uniform float edge_hardness : hint_range(0.0, 1.0) = 0.72;
uniform float inner_shadow_strength : hint_range(0.0, 0.8) = 0.28;

uniform vec4 backlight_color : source_color = vec4(1.0, 0.831, 0.0, 1.0); // #FFD400
uniform float halo_core_strength : hint_range(0.0, 2.0) = 1.15;
uniform float halo_outer_strength : hint_range(0.0, 1.5) = 0.58;
uniform float halo_core_radius_px : hint_range(1.0, 8.0) = 2.8;
uniform float halo_outer_radius_px : hint_range(3.0, 16.0) = 8.2;
uniform float wall_spill_strength : hint_range(0.0, 1.0) = 0.22;
uniform float wall_spill_shift_px : hint_range(-10.0, 20.0) = 6.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float sample_alpha(vec2 uv) {
	return texture(TEXTURE, uv).a * COLOR.a;
}

float dilate_alpha(vec2 uv, vec2 texel_step) {
	float a0 = sample_alpha(uv + vec2(texel_step.x, 0.0));
	float a1 = sample_alpha(uv + vec2(-texel_step.x, 0.0));
	float a2 = sample_alpha(uv + vec2(0.0, texel_step.y));
	float a3 = sample_alpha(uv + vec2(0.0, -texel_step.y));
	float a4 = sample_alpha(uv + vec2(texel_step.x, texel_step.y));
	float a5 = sample_alpha(uv + vec2(-texel_step.x, texel_step.y));
	float a6 = sample_alpha(uv + vec2(texel_step.x, -texel_step.y));
	float a7 = sample_alpha(uv + vec2(-texel_step.x, -texel_step.y));
	return max(max(max(a0, a1), max(a2, a3)), max(max(a4, a5), max(a6, a7)));
}

void fragment() {
	float alpha = sample_alpha(UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;

	float inner = min(
		min(sample_alpha(UV + vec2(texel.x, 0.0)), sample_alpha(UV + vec2(-texel.x, 0.0))),
		min(sample_alpha(UV + vec2(0.0, texel.y)), sample_alpha(UV + vec2(0.0, -texel.y)))
	);
	float inner_edge = clamp(alpha - inner, 0.0, 1.0);
	float inner_shadow = inner_edge * inner_shadow_strength;

	float grad_l = sample_alpha(UV + vec2(-texel.x, 0.0));
	float grad_r = sample_alpha(UV + vec2(texel.x, 0.0));
	float grad_u = sample_alpha(UV + vec2(0.0, -texel.y));
	float grad_d = sample_alpha(UV + vec2(0.0, texel.y));
	vec2 normal2d = vec2(grad_r - grad_l, grad_d - grad_u);
	vec2 light_dir = normalize(vec2(-0.62, -0.78));
	float bevel = clamp(dot(-normal2d, light_dir), -1.0, 1.0) * bevel_strength;

	float vertical_t = clamp(UV.y, 0.0, 1.0);
	vec3 steel = mix(steel_mid.rgb, steel_dark.rgb, vertical_t);
	float brush_phase = UV.y * 540.0 + hash12(vec2(floor(UV.x * 36.0), floor(UV.y * 48.0))) * 2.2;
	float brush = (sin(brush_phase) * 0.5 + 0.5) - 0.5;
	steel += brush * brushed_strength;
	float edge_spec = pow(clamp(inner_edge, 0.0, 1.0), mix(3.8, 1.4, edge_hardness));
	steel += steel_high.rgb * edge_spec * 0.55;
	steel *= 1.0 + bevel;
	steel *= 1.0 - inner_shadow;
	steel = clamp(steel, vec3(0.0), vec3(1.0));

	vec2 core_step = texel * halo_core_radius_px;
	vec2 outer_step = texel * halo_outer_radius_px;
	float core_dilate = dilate_alpha(UV, core_step);
	float outer_dilate = dilate_alpha(UV, outer_step);
	float halo_core = clamp(core_dilate - alpha, 0.0, 1.0) * halo_core_strength;
	float halo_outer = clamp(outer_dilate - core_dilate, 0.0, 1.0) * halo_outer_strength;

	vec2 spill_shift_uv = vec2(0.0, wall_spill_shift_px * texel.y);
	float spill_dilate = dilate_alpha(UV - spill_shift_uv, outer_step);
	float spill = clamp(spill_dilate - outer_dilate, 0.0, 1.0) * wall_spill_strength;

	vec3 backlight = backlight_color.rgb * (halo_core + halo_outer + spill);
	vec3 final_rgb = steel * alpha * COLOR.rgb + backlight;
	float final_alpha = clamp(alpha + halo_core + halo_outer + spill, 0.0, 1.0);
	if (final_alpha <= 0.001) {
		discard;
	}
	COLOR = vec4(final_rgb, final_alpha);
}
