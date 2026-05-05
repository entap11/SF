shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 core_color : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform float scroll_speed = 0.18;
uniform float pulse_strength = 0.18;
uniform float glow_strength = 0.65;
uniform float tint_strength = 0.85;
uniform float activity_pulse = 0.0;
uniform float power_flash = 0.0;
uniform float surge = 0.0;
uniform float flicker = 0.0;
uniform float alpha_scale = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 centered = (uv - vec2(0.5, 0.5)) * vec2(1.28, 1.0);
	float radial = dot(centered, centered);
	float mask = 1.0 - smoothstep(0.34, 0.52, radial);

	float y_scroll = uv.y + (TIME * scroll_speed) - (surge * 0.12);
	float slow_wave = sin((y_scroll * 18.0) + sin((uv.x * 7.0) + (TIME * 0.8)));
	float fine_wave = sin((y_scroll * 39.0) + (uv.x * 11.0) - (TIME * 1.6));
	float flow = 0.5 + (0.34 * slow_wave) + (0.16 * fine_wave);
	flow = clamp(flow, 0.0, 1.0);

	float breath = 1.0 + (sin(TIME * 2.0) * pulse_strength);
	float activity = 1.0 + activity_pulse + power_flash;
	float stress = 1.0 - (flicker * (0.45 + (0.35 * sin(TIME * 55.0))));
	float core_hot = smoothstep(0.48, 0.0, radial);

	vec3 pale = vec3(0.82, 0.95, 1.0);
	vec3 tint = mix(pale, core_color.rgb, tint_strength);
	vec3 color = tint * (0.50 + (flow * 0.46) + (core_hot * glow_strength));
	float alpha = mask * alpha_scale * breath * activity * stress * (0.34 + (flow * 0.40) + (core_hot * 0.32));
	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
