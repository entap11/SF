shader_type canvas_item;

uniform vec3 key_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float threshold = 0.08;
uniform float softness = 0.04;
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.5;
uniform float fill_velocity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wave_tint : source_color = vec4(0.60, 0.86, 1.0, 0.25);
uniform float wave_speed = 0.75;
uniform float wave_scale = 18.0;

void fragment() {
	vec2 uv = UV;
	vec4 tex = texture(TEXTURE, uv);
	float key_dist = distance(tex.rgb, key_color);
	float alpha_mask = smoothstep(threshold, threshold + softness, key_dist);

	float slosh = mix(1.0, 2.2, fill_velocity);
	float wave_phase = uv.y * wave_scale + TIME * wave_speed * slosh;
	float wave = 0.5 + 0.5 * sin(wave_phase);
	float edge = smoothstep(fill_ratio - 0.14, fill_ratio + 0.04, uv.x);
	float trailing = smoothstep(fill_ratio - 0.32, fill_ratio - 0.03, uv.x) * (1.0 - edge);
	float shimmer = ((1.0 - edge) * wave) + trailing * 0.35 * slosh;

	vec3 color = tex.rgb + wave_tint.rgb * wave_tint.a * shimmer;
	COLOR = vec4(color, tex.a * alpha_mask);
}
