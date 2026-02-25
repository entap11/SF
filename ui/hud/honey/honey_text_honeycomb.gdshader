shader_type canvas_item;
render_mode unshaded;

uniform vec4 honey_top : source_color = vec4(1.0, 0.94, 0.62, 1.0);
uniform vec4 honey_mid : source_color = vec4(0.98, 0.76, 0.26, 1.0);
uniform vec4 honey_bot : source_color = vec4(0.78, 0.45, 0.08, 1.0);

uniform float hex_scale : hint_range(8.0, 80.0) = 34.0;
uniform float hex_line_strength : hint_range(0.0, 1.5) = 0.35;
uniform float hex_line_width : hint_range(0.005, 0.2) = 0.05;
uniform float glisten_strength : hint_range(0.0, 1.0) = 0.12;
uniform float glisten_speed : hint_range(0.0, 2.0) = 0.20;

float hex_sdf(vec2 p) {
	p = abs(p);
	return max(dot(p, vec2(0.8660254, 0.5)), p.x);
}

float hex_line(vec2 uv, float scale, float width) {
	vec2 grid_uv = uv * scale;
	grid_uv.x *= 1.1547005;
	grid_uv.y += floor(grid_uv.x) * 0.5;
	vec2 cell_uv = fract(grid_uv) - 0.5;
	float dist = hex_sdf(cell_uv);
	return 1.0 - smoothstep(0.5 - width, 0.5, dist);
}

void fragment() {
	vec4 atlas = texture(TEXTURE, UV);
	float alpha = atlas.a * COLOR.a;
	if (alpha <= 0.001) {
		discard;
	}

	vec3 base = mix(honey_top.rgb, honey_mid.rgb, smoothstep(0.0, 0.5, UV.y));
	base = mix(base, honey_bot.rgb, smoothstep(0.5, 1.0, UV.y));

	float sweep = sin((UV.x * 3.2 + UV.y * 2.7) - (TIME * (6.2831853 * glisten_speed)));
	float glisten = smoothstep(0.65, 1.0, sweep) * glisten_strength;

	float lines = hex_line(UV, hex_scale, hex_line_width) * hex_line_strength;
	vec3 final_rgb = base + vec3(glisten) + vec3(lines);

	COLOR = vec4(final_rgb * COLOR.rgb, alpha);
}
