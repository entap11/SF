shader_type canvas_item;
render_mode unshaded;

uniform vec4 base_dark : source_color = vec4(0.14, 0.15, 0.17, 1.0);
uniform vec4 metal_highlight : source_color = vec4(0.42, 0.44, 0.46, 1.0);
uniform vec4 amber_inlay : source_color = vec4(0.95, 0.66, 0.22, 1.0);
uniform float inlay_strength : hint_range(0.0, 2.0) = 0.55;
uniform float hex_scale : hint_range(8.0, 80.0) = 28.0;
uniform float hex_strength : hint_range(0.0, 1.0) = 0.18;
uniform float sweep_pos : hint_range(-0.5, 1.5) = -0.3;
uniform float sweep_width : hint_range(0.02, 0.6) = 0.16;
uniform float sweep_strength : hint_range(0.0, 1.5) = 0.0;
uniform float noise_strength : hint_range(0.0, 0.35) = 0.09;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

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

	vec2 texel = TEXTURE_PIXEL_SIZE;
	float n1 = texture(TEXTURE, UV + vec2(texel.x, 0.0)).a;
	float n2 = texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a;
	float n3 = texture(TEXTURE, UV + vec2(0.0, texel.y)).a;
	float n4 = texture(TEXTURE, UV + vec2(0.0, -texel.y)).a;
	float neighbor = (n1 + n2 + n3 + n4) * 0.25;
	float edge = clamp(alpha - neighbor, 0.0, 1.0);

	float grad = smoothstep(0.0, 1.0, UV.y);
	vec3 metal = mix(base_dark.rgb, metal_highlight.rgb, grad * 0.55);
	float grain = (hash12(UV * 420.0) - 0.5) * 2.0;
	metal += grain * noise_strength;

	float hex = hex_line(UV, hex_scale, 0.045);
	float matte = 1.0 - (hex * hex_strength);
	metal *= matte;

	vec3 inlay = amber_inlay.rgb * edge * inlay_strength;
	float sweep_dist = abs(UV.x - sweep_pos);
	float sweep = exp(-pow(sweep_dist / max(sweep_width, 0.001), 2.0));
	vec3 sweep_color = (metal_highlight.rgb * 0.85 + amber_inlay.rgb * 0.45) * sweep * sweep_strength;

	vec3 final_rgb = (metal + inlay + sweep_color) * COLOR.rgb;
	COLOR = vec4(final_rgb, alpha);
}
