shader_type canvas_item;
render_mode unshaded;

uniform sampler2D mask_a : source_color, filter_linear, repeat_disable;
uniform sampler2D mask_b : source_color, filter_linear, repeat_disable;
uniform float mask_mode_a = 0.0;
uniform float mask_mode_b = 0.0;
uniform float mask_cutoff_a : hint_range(0.0, 1.0) = 0.0;
uniform float mask_cutoff_b : hint_range(0.0, 1.0) = 0.0;
uniform float mask_softness_a : hint_range(0.001, 1.0) = 0.1;
uniform float mask_softness_b : hint_range(0.001, 1.0) = 0.1;
uniform float keyframe_blend : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.082, 0.075, 0.106, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.52;
uniform float edge_softness_px : hint_range(0.0, 4.0) = 1.0;

float resolve_mask(vec4 sample_color, float mode, float cutoff, float softness) {
	if (mode < 0.5) {
		return sample_color.a;
	}
	float inverse_luminance = 1.0 - dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
	return smoothstep(cutoff, cutoff + max(softness, 0.001), inverse_luminance);
}

float sample_mask_a(vec2 uv) {
	return resolve_mask(texture(mask_a, uv), mask_mode_a, mask_cutoff_a, mask_softness_a);
}

float sample_mask_b(vec2 uv) {
	return resolve_mask(texture(mask_b, uv), mask_mode_b, mask_cutoff_b, mask_softness_b);
}

float softened_mask_a(vec2 uv) {
	vec2 pixel_step = edge_softness_px / vec2(textureSize(mask_a, 0));
	return (
		sample_mask_a(uv) * 0.40
		+ sample_mask_a(uv + vec2(pixel_step.x, 0.0)) * 0.15
		+ sample_mask_a(uv - vec2(pixel_step.x, 0.0)) * 0.15
		+ sample_mask_a(uv + vec2(0.0, pixel_step.y)) * 0.15
		+ sample_mask_a(uv - vec2(0.0, pixel_step.y)) * 0.15
	);
}

float softened_mask_b(vec2 uv) {
	vec2 pixel_step = edge_softness_px / vec2(textureSize(mask_b, 0));
	return (
		sample_mask_b(uv) * 0.40
		+ sample_mask_b(uv + vec2(pixel_step.x, 0.0)) * 0.15
		+ sample_mask_b(uv - vec2(pixel_step.x, 0.0)) * 0.15
		+ sample_mask_b(uv + vec2(0.0, pixel_step.y)) * 0.15
		+ sample_mask_b(uv - vec2(0.0, pixel_step.y)) * 0.15
	);
}

void fragment() {
	float alpha_a = softened_mask_a(UV);
	float alpha_b = softened_mask_b(UV);
	float mask_alpha = mix(alpha_a, alpha_b, keyframe_blend);
	COLOR = vec4(
		shadow_color.rgb,
		mask_alpha * shadow_opacity * shadow_color.a
	);
}
