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
uniform float pulse_strength = 0.0;
uniform float pulse_speed = 2.4;
uniform float pulse_phase = 0.0;
uniform float global_alpha = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Basic luminance/brightness
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float bright = max(tex.r, max(tex.g, tex.b));

	// Yellow-ish mask: R and G high, B low
	float y1 = smoothstep(r_min, r_max, tex.r);
	float y2 = smoothstep(g_min, g_max, tex.g);
	float nb = 1.0 - smoothstep(b_soft, b_max, tex.b);
	float mask = y1 * y2 * nb;

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
	COLOR = vec4(out_rgb, tex.a * global_alpha);
}
