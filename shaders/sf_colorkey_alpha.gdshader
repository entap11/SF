shader_type canvas_item;

uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float threshold = 0.28;
uniform float softness = 0.10;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_px = 1.6;
uniform float outline_strength = 1.0;
uniform float inner_outline_strength = 0.85;
uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.0, 1.0);
uniform float glow_strength = 0.0;
uniform float glow_luma_floor = 0.10;
uniform float glow_pulse_strength = 0.0;
uniform float glow_pulse_speed = 4.0;
uniform float glow_pulse_phase = 0.0;
uniform vec4 body_glow_color : source_color = vec4(1.0, 0.72, 0.08, 1.0);
uniform vec2 body_glow_center = vec2(0.5, 0.50);
uniform vec2 body_glow_radius = vec2(0.17, 0.25);
uniform float body_glow_strength = 0.0;
uniform float body_glow_luma_floor = 0.08;
uniform float body_halo_radius_uv = 0.024;
uniform float body_halo_alpha = 0.0;
uniform float body_halo_brightness = 1.0;
uniform float body_pulse_strength = 0.0;
uniform float body_pulse_speed = 4.8;
uniform float body_pulse_phase = 0.0;

float keyed_alpha_at(vec2 uv) {
	vec4 sample_color = texture(TEXTURE, uv);
	float key_distance = distance(sample_color.rgb, key_color.rgb);
	float key_alpha = smoothstep(threshold - softness, threshold + softness, key_distance);
	return sample_color.a * key_alpha;
}

float body_mask_at(vec2 uv) {
	vec2 safe_radius = max(body_glow_radius, vec2(0.0001));
	vec2 body_delta = (uv - body_glow_center) / safe_radius;
	return 1.0 - smoothstep(0.72, 1.0, length(body_delta));
}

float body_source_at(vec2 uv) {
	return keyed_alpha_at(uv) * body_mask_at(uv);
}

float body_ring_at(vec2 uv, float radius_uv) {
	float diagonal = radius_uv * 0.70710678;
	float ring = body_source_at(uv + vec2(radius_uv, 0.0));
	ring = max(ring, body_source_at(uv + vec2(-radius_uv, 0.0)));
	ring = max(ring, body_source_at(uv + vec2(0.0, radius_uv)));
	ring = max(ring, body_source_at(uv + vec2(0.0, -radius_uv)));
	ring = max(ring, body_source_at(uv + vec2(diagonal, diagonal)));
	ring = max(ring, body_source_at(uv + vec2(-diagonal, diagonal)));
	ring = max(ring, body_source_at(uv + vec2(diagonal, -diagonal)));
	ring = max(ring, body_source_at(uv + vec2(-diagonal, -diagonal)));
	return ring;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(c.rgb, key_color.rgb);
	float a = smoothstep(threshold - softness, threshold + softness, d);
	float base_alpha = c.a * a;
	vec2 texel = TEXTURE_PIXEL_SIZE * outline_px;
	float n1 = texture(TEXTURE, UV + vec2(texel.x, 0.0)).a;
	float n2 = texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a;
	float n3 = texture(TEXTURE, UV + vec2(0.0, texel.y)).a;
	float n4 = texture(TEXTURE, UV + vec2(0.0, -texel.y)).a;
	float n5 = texture(TEXTURE, UV + texel * vec2(0.71, 0.71)).a;
	float n6 = texture(TEXTURE, UV + texel * vec2(-0.71, 0.71)).a;
	float n7 = texture(TEXTURE, UV + texel * vec2(0.71, -0.71)).a;
	float n8 = texture(TEXTURE, UV + texel * vec2(-0.71, -0.71)).a;
	float neighbor_alpha = max(max(max(n1, n2), max(n3, n4)), max(max(n5, n6), max(n7, n8)));
	float inner_neighbor_alpha = min(min(min(n1, n2), min(n3, n4)), min(min(n5, n6), min(n7, n8)));
	float outline_mask = clamp((neighbor_alpha - base_alpha) * outline_strength, 0.0, 1.0);
	float inner_outline_mask = clamp((base_alpha - inner_neighbor_alpha) * inner_outline_strength, 0.0, 1.0);
	vec3 shaded_rgb = mix(c.rgb, outline_color.rgb, inner_outline_mask);
	vec3 out_rgb = mix(outline_color.rgb, shaded_rgb, base_alpha);
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float glow_mask = base_alpha * smoothstep(glow_luma_floor, 1.0, luma);
	float glow_pulse = 1.0 + ((sin((TIME * glow_pulse_speed) + glow_pulse_phase) * 0.5) + 0.5) * glow_pulse_strength;
	out_rgb += glow_color.rgb * glow_mask * glow_strength * glow_pulse;
	float body_pulse_wave = (sin((TIME * body_pulse_speed) + body_pulse_phase) * 0.5) + 0.5;
	float body_burst = 1.0 + (pow(body_pulse_wave, 3.0) * body_pulse_strength);
	float body_mask = body_mask_at(UV);
	float body_emission = base_alpha * body_mask * smoothstep(body_glow_luma_floor, 1.0, luma);
	out_rgb += body_glow_color.rgb * body_emission * body_glow_strength * glow_pulse * body_burst;
	float near_body = body_ring_at(UV, body_halo_radius_uv * 0.52);
	float far_body = body_ring_at(UV, body_halo_radius_uv);
	float body_halo = max(near_body * 0.78, far_body * 0.42) * (1.0 - base_alpha);
	float halo_alpha = clamp(body_halo * body_halo_alpha, 0.0, 1.0);
	out_rgb = mix(out_rgb, body_glow_color.rgb * body_halo_brightness * glow_pulse * body_burst, halo_alpha);
	float out_alpha = max(max(base_alpha, outline_mask * outline_color.a), halo_alpha);
	COLOR = vec4(out_rgb, out_alpha);
}
