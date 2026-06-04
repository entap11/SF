shader_type canvas_item;

uniform float contrast = 1.05;
uniform float brightness = 0.90;
uniform float pulse_strength = 0.0;
uniform float pulse_speed = 2.4;
uniform float pulse_phase = 0.0;
uniform vec4 npc_tint : source_color = vec4(0.52, 0.47, 0.82, 1.0);
uniform float tint_strength = 0.88;
uniform float glow_strength = 0.0;
uniform float additive_glow = 0.0;
uniform float selected_hot = 0.0;
uniform vec4 selected_hot_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float selected_metal_lift = 0.0;
uniform float selected_hot_edge = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float pulse_wave = sin((TIME * pulse_speed) + pulse_phase) * pulse_strength;
	float body_pulse = 1.0 + (pulse_wave * 0.65);
	float gray = clamp(((luma - 0.5) * contrast + 0.5) * brightness * body_pulse, 0.0, 1.0);
	vec3 tint_mul = mix(vec3(1.0), npc_tint.rgb * 1.55, tint_strength);
	float glow_mask = smoothstep(0.28, 1.0, luma) * tex.a;
	vec3 out_rgb = (vec3(gray) * tint_mul) + (npc_tint.rgb * glow_mask * glow_strength * additive_glow);
	float metal_gate = (1.0 - smoothstep(0.16, 0.62, luma)) * smoothstep(0.18, 0.95, tex.a);
	vec3 hot_base = mix(vec3(0.86, 0.90, 0.95), selected_hot_color.rgb, 0.52);
	vec3 hot_metal = mix(out_rgb, hot_base, metal_gate * selected_metal_lift);
	float hot_edge = smoothstep(0.30, 0.98, max(tex.r, max(tex.g, tex.b))) * metal_gate;
	out_rgb = mix(out_rgb, hot_metal + (selected_hot_color.rgb * hot_edge * selected_hot_edge), selected_hot);
	COLOR = vec4(out_rgb, tex.a);
}
