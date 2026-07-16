shader_type canvas_item;

uniform vec4 team_color : source_color = vec4(1.0, 0.8235, 0.0, 1.0);
uniform float glow_strength = 1.0;
uniform float r_min = 0.55;
uniform float g_min = 0.45;
uniform float b_max = 0.30;
uniform float r_max = 0.85;
uniform float g_max = 0.80;
uniform float b_soft = 0.10;
uniform float detail_preserve = 0.86;
uniform float colorize_strength = 0.78;
uniform float additive_glow = 0.22;
uniform float white_sat_max = 0.32;
uniform float white_val_min = 0.56;
uniform float white_strength = 0.95;
uniform float pulse_strength = 0.0;
uniform float pulse_speed = 2.4;
uniform float pulse_phase = 0.0;
uniform float global_alpha = 1.0;
uniform float selected_hot = 0.0;
uniform vec4 selected_hot_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float selected_metal_lift = 0.0;
uniform float selected_hot_edge = 0.0;
uniform vec4 body_glow_color : source_color = vec4(1.0, 0.72, 0.08, 1.0);
uniform vec2 body_glow_center = vec2(0.5, 0.50);
uniform vec2 body_glow_radius = vec2(0.17, 0.25);
uniform float body_glow_strength = 0.0;
uniform float body_glow_luma_floor = 0.08;
uniform float body_pulse_strength = 0.0;
uniform float body_pulse_speed = 4.8;
uniform float body_pulse_phase = 0.0;
uniform vec4 key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float key_threshold = 0.10;
uniform float key_softness = 0.05;
uniform float key_enabled = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1e-10;
	return vec3(abs(q.z + (q.w - q.y) / ((6.0 * d) + e)), d / (q.x + e), q.x);
}

float body_mask_at(vec2 uv) {
	vec2 safe_radius = max(body_glow_radius, vec2(0.0001));
	vec2 body_delta = (uv - body_glow_center) / safe_radius;
	return 1.0 - smoothstep(0.72, 1.0, length(body_delta));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float source_alpha = tex.a;
	if (key_enabled > 0.5) {
		float key_distance = distance(tex.rgb, key_color.rgb);
		source_alpha *= smoothstep(
			key_threshold - key_softness,
			key_threshold + key_softness,
			key_distance
		);
	}
	vec3 hsv = rgb2hsv(tex.rgb);

	// Basic luminance/brightness
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float bright = max(tex.r, max(tex.g, tex.b));

	// Yellow-ish mask: R and G high, B low
	float y1 = smoothstep(r_min, r_max, tex.r);
	float y2 = smoothstep(g_min, g_max, tex.g);
	float nb = 1.0 - smoothstep(b_soft, b_max, tex.b);
	float yellow_mask = y1 * y2 * nb;
	float white_sat_gate = 1.0 - smoothstep(white_sat_max - 0.08, white_sat_max + 0.08, hsv.y);
	float white_val_gate = smoothstep(white_val_min - 0.08, white_val_min + 0.08, hsv.z);
	float white_mask = white_sat_gate * white_val_gate * white_strength;
	float mask = clamp(max(yellow_mask, white_mask), 0.0, 1.0);

	// Neutralize the source yellow first, then tint it so red does not collapse to orange.
	float energy = mix(lum, bright, 0.72);
	float pulse_wave = sin((TIME * pulse_speed) + pulse_phase) * pulse_strength;
	float body_pulse = 1.0 + (pulse_wave * 0.55);
	float glow_pulse = 1.0 + max(pulse_wave, 0.0) * 1.45;
	vec3 neutral_glow = mix(tex.rgb, vec3(energy), 0.88);
	vec3 preserved = mix(neutral_glow, neutral_glow * team_color.rgb, colorize_strength);
	vec3 emissive = team_color.rgb * energy * glow_strength;
	vec3 lit = mix(tex.rgb, preserved, mask * detail_preserve);
	vec3 out_rgb = (lit * body_pulse) + (emissive * mask * additive_glow * glow_pulse);
	float dark_mask = 1.0 - smoothstep(0.16, 0.62, lum);
	float metal_gate = dark_mask * smoothstep(0.18, 0.95, source_alpha);
	vec3 hot_base = mix(vec3(0.86, 0.90, 0.95), selected_hot_color.rgb, 0.52);
	vec3 hot_metal = mix(out_rgb, hot_base, metal_gate * selected_metal_lift);
	float hot_edge = smoothstep(0.30, 0.98, bright) * metal_gate;
	out_rgb = mix(out_rgb, hot_metal + (selected_hot_color.rgb * hot_edge * selected_hot_edge), selected_hot);
	float body_pulse_wave = (sin((TIME * body_pulse_speed) + body_pulse_phase) * 0.5) + 0.5;
	float body_burst = 1.0 + (pow(body_pulse_wave, 3.0) * body_pulse_strength);
	float body_emission = source_alpha * body_mask_at(UV) * smoothstep(body_glow_luma_floor, 1.0, lum);
	out_rgb += body_glow_color.rgb * body_emission * body_glow_strength * body_burst;
	COLOR = vec4(out_rgb, source_alpha * global_alpha);
}
