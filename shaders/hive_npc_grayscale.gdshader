shader_type canvas_item;

uniform float contrast = 1.05;
uniform float brightness = 0.90;
uniform float pulse_strength = 0.0;
uniform float pulse_speed = 2.4;
uniform float pulse_phase = 0.0;
uniform vec4 npc_tint : source_color = vec4(0.52, 0.47, 0.82, 1.0);
uniform float tint_strength = 0.88;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float pulse_wave = sin((TIME * pulse_speed) + pulse_phase) * pulse_strength;
	float body_pulse = 1.0 + (pulse_wave * 0.65);
	float gray = clamp(((luma - 0.5) * contrast + 0.5) * brightness * body_pulse, 0.0, 1.0);
	vec3 tint_mul = mix(vec3(1.0), npc_tint.rgb * 1.55, tint_strength);
	COLOR = vec4(vec3(gray) * tint_mul, tex.a);
}
