shader_type canvas_item;

uniform vec4 team_color : source_color = vec4(1.0, 0.8235, 0.0, 1.0);
uniform float glow_strength = 1.0;
uniform float r_min = 0.55;
uniform float g_min = 0.45;
uniform float b_max = 0.30;
uniform float r_max = 0.85;
uniform float g_max = 0.80;
uniform float b_soft = 0.10;

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

	// Recolor glow pixels
	vec3 glow = team_color.rgb * mix(lum, bright, 0.6) * glow_strength;

	vec3 out_rgb = mix(tex.rgb, glow, mask);
	COLOR = vec4(out_rgb, tex.a);
}
