shader_type canvas_item;

uniform float contrast = 1.05;
uniform float brightness = 0.90;
uniform float pulse_strength = 0.0;
uniform float pulse_speed = 2.4;
uniform float pulse_phase = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float pulse_wave = sin((TIME * pulse_speed) + pulse_phase) * pulse_strength;
	float body_pulse = 1.0 + (pulse_wave * 0.65);
	float gray = clamp(((luma - 0.5) * contrast + 0.5) * brightness * body_pulse, 0.0, 1.0);
	COLOR = vec4(vec3(gray), tex.a);
}
