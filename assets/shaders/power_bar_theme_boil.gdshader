shader_type canvas_item;

uniform vec3 key_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float threshold = 0.08;
uniform float softness = 0.04;
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.5;
uniform vec4 boil_tint : source_color = vec4(1.0, 0.92, 0.60, 0.34);
uniform float boil_speed = 1.35;
uniform float boil_scale = 28.0;
uniform float bubble_strength = 0.22;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec4 tex = texture(TEXTURE, uv);
	float key_dist = distance(tex.rgb, key_color);
	float alpha_mask = smoothstep(threshold, threshold + softness, key_dist);

	vec2 bubble_uv = vec2(uv.x * boil_scale, uv.y * boil_scale * 0.6 + TIME * boil_speed);
	vec2 cell = floor(bubble_uv);
	vec2 local = fract(bubble_uv) - vec2(0.5);
	float rnd = hash21(cell);
	float radius = mix(0.07, 0.28, rnd);
	float bubble = smoothstep(radius, radius - 0.03, length(local));

	float wave = 0.5 + 0.5 * sin((uv.y + uv.x * 0.6) * boil_scale + TIME * boil_speed * 1.1);
	float edge = smoothstep(fill_ratio - 0.20, fill_ratio + 0.08, uv.x);
	float energy = (1.0 - edge) * (wave * 0.6 + bubble * bubble_strength);

	vec3 color = tex.rgb + boil_tint.rgb * boil_tint.a * energy;
	COLOR = vec4(color, tex.a * alpha_mask);
}
