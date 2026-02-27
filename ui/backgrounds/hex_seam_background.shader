shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 base_color : source_color = vec4(0.060, 0.055, 0.050, 0.58);
uniform vec4 glow_color : source_color = vec4(1.0, 0.831, 0.0, 1.0);
uniform float seam_width : hint_range(0.001, 0.2) = 0.034;
uniform float seam_intensity : hint_range(0.0, 4.0) = 1.0;
uniform float noise_scale : hint_range(0.1, 20.0) = 3.5;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.24;
uniform float center_bias : hint_range(0.0, 2.5) = 0.5;
uniform bool pulse_enabled = false;
uniform float pulse_period : hint_range(1.0, 12.0) = 5.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.04;
uniform float flicker_amount : hint_range(0.0, 0.4) = 0.01;
uniform float hex_scale : hint_range(2.0, 60.0) = 17.0;
uniform float seed = 11.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p * freq) * amp;
		freq *= 2.0;
		amp *= 0.5;
	}
	return v;
}

float sd_hexagon(vec2 p, float radius) {
	vec2 q = abs(p);
	return max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x) - radius;
}

vec2 nearest_hex_center(vec2 p) {
	float dx = 1.7320508;
	float dy = 1.5;
	float base_row = floor(p.y / dy);
	float best_d = 1e9;
	vec2 best_center = vec2(0.0);

	for (int i = -1; i <= 1; i++) {
		float row = base_row + float(i);
		float row_offset = mod(row, 2.0) * (dx * 0.5);
		float col = round((p.x - row_offset) / dx);
		vec2 center = vec2(col * dx + row_offset, row * dy);
		float d = distance(p, center);
		if (d < best_d) {
			best_d = d;
			best_center = center;
		}
	}
	return best_center;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - vec2(0.5)) * hex_scale;
	vec2 cell_center = nearest_hex_center(p);
	vec2 local = p - cell_center;

	float seam_dist = abs(sd_hexagon(local, 1.0));
	float seam_core = 1.0 - smoothstep(0.0, seam_width, seam_dist);
	float seam_soft = 1.0 - smoothstep(seam_width * 0.7, seam_width * 5.0, seam_dist);

	float cell_noise = hash12(cell_center + vec2(seed, seed * 0.73));
	float leather_grain = fbm(p * 0.65 + vec2(seed * 1.33, -seed * 0.71));
	float leather_stretch = value_noise(vec2(p.x * 0.18, p.y * 1.4) + vec2(-seed * 2.1, seed * 1.2));
	float plate_variation = 0.92 + (cell_noise - 0.5) * 0.06 + (leather_grain - 0.5) * 0.08 + (leather_stretch - 0.5) * 0.05;
	vec3 base_rgb = base_color.rgb * plate_variation;

	float seam_noise = value_noise((p + vec2(seed * 2.13, seed * 3.77)) * noise_scale);
	float seam_hotspots = smoothstep(0.62, 0.93, seam_noise);
	float seam_variation = mix(1.0 - noise_amount * 0.75, 1.0 + noise_amount * 1.35, seam_hotspots);

	float radial = length((uv - vec2(0.5)) * vec2(1.0, 1.2));
	float center_mask = pow(clamp(1.0 - radial * 1.42, 0.0, 1.0), 1.25);
	float center_gain = 1.0 + center_mask * center_bias * 0.85;
	float edge_dim = smoothstep(0.15, 0.95, radial);
	base_rgb *= 1.0 - edge_dim * 0.16;

	float anim_gain = 1.0;
	if (pulse_enabled) {
		float safe_period = max(0.001, pulse_period);
		float pulse = 1.0 + sin(TIME * (6.2831853 / safe_period)) * pulse_amount;
		float flicker_src = hash12(vec2(floor(TIME * 12.0), seed + 91.7));
		float flicker = 1.0 + (flicker_src - 0.5) * 2.0 * flicker_amount;
		anim_gain = pulse * flicker;
	}

	float glow_core = seam_core * seam_intensity * 0.85;
	float glow_aura = seam_soft * seam_intensity * 0.22;
	float glow_strength = max(0.0, (glow_core + glow_aura) * seam_variation * center_gain * anim_gain);
	vec3 glow_rgb = glow_color.rgb * glow_strength * 0.82;

	float glow_alpha = clamp(glow_strength * 0.12, 0.0, 0.25);
	float out_alpha = max(base_color.a, glow_alpha);
	vec4 out_color = vec4(base_rgb + glow_rgb, out_alpha);
	COLOR = out_color * COLOR;
}
