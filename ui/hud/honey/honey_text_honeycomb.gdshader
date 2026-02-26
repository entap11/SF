shader_type canvas_item;
render_mode unshaded;

uniform vec4 honey_top : source_color = vec4(1.00, 0.90, 0.52, 1.0);
uniform vec4 honey_mid : source_color = vec4(0.91, 0.55, 0.14, 1.0);
uniform vec4 honey_bot : source_color = vec4(0.50, 0.20, 0.02, 1.0);
uniform vec4 honey_edge_dark : source_color = vec4(0.19, 0.07, 0.01, 1.0);
uniform vec4 honey_gloss : source_color = vec4(1.0, 0.95, 0.78, 1.0);

uniform float inflate_px : hint_range(0.5, 3.0) = 1.75;
uniform float outer_ring_strength : hint_range(0.0, 2.0) = 1.15;
uniform float edge_dark_strength : hint_range(0.0, 2.0) = 1.00;
uniform float volume_strength : hint_range(0.0, 2.0) = 0.72;
uniform float top_gloss_strength : hint_range(0.0, 2.0) = 0.60;
uniform float sheen_strength : hint_range(0.0, 2.0) = 0.18;
uniform float sheen_speed : hint_range(0.0, 3.0) = 0.28;
uniform float bubble_speck_strength : hint_range(0.0, 1.0) = 0.06;
uniform float drip_strength : hint_range(0.0, 2.0) = 0.24;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float sample_dilate(vec2 uv, vec2 texel) {
	float s = texture(TEXTURE, uv).a;
	s = max(s, texture(TEXTURE, uv + texel * vec2(1.00, 0.00)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(-1.00, 0.00)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(0.00, 1.00)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(0.00, -1.00)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(0.71, 0.71)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(-0.71, 0.71)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(0.71, -0.71)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(-0.71, -0.71)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(1.00, 0.45)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(-1.00, 0.45)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(1.00, -0.45)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(-1.00, -0.45)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(0.45, 1.00)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(-0.45, 1.00)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(0.45, -1.00)).a);
	s = max(s, texture(TEXTURE, uv + texel * vec2(-0.45, -1.00)).a);
	return s;
}

void fragment() {
	vec4 atlas = texture(TEXTURE, UV);
	float src_alpha = atlas.a * COLOR.a;
	if (src_alpha <= 0.001) {
		discard;
	}

	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 uv_warp = UV;
	float wobble = sin((UV.y * 18.0) + sin(UV.y * 37.0)) * 0.0022;
	uv_warp.x += wobble;
	float body = sample_dilate(uv_warp, texel * inflate_px);
	float outer = sample_dilate(uv_warp, texel * (inflate_px * 1.9));
	float alpha = smoothstep(0.16, 0.95, body) * COLOR.a;
	if (alpha <= 0.001) {
		discard;
	}

	float n1 = texture(TEXTURE, uv_warp + vec2(texel.x * inflate_px, 0.0)).a;
	float n2 = texture(TEXTURE, uv_warp + vec2(-texel.x * inflate_px, 0.0)).a;
	float n3 = texture(TEXTURE, uv_warp + vec2(0.0, texel.y * inflate_px)).a;
	float n4 = texture(TEXTURE, uv_warp + vec2(0.0, -texel.y * inflate_px)).a;
	float neighbor = (n1 + n2 + n3 + n4) * 0.25;
	float edge = clamp(body - neighbor, 0.0, 1.0);
	float interior = smoothstep(0.04, 0.95, neighbor);
	float ring = clamp(outer - body, 0.0, 1.0);

	float top_to_bottom = 1.0 - UV.y;
	vec3 honey = mix(honey_bot.rgb, honey_mid.rgb, smoothstep(0.0, 0.62, top_to_bottom));
	honey = mix(honey, honey_top.rgb, smoothstep(0.56, 1.0, top_to_bottom));

	float center_bulge = 1.0 - abs((UV.x * 2.0) - 1.0);
	center_bulge = smoothstep(0.0, 1.0, center_bulge);
	honey += vec3(0.11, 0.06, 0.01) * center_bulge * volume_strength;

	float top_gloss = smoothstep(0.68, 1.0, top_to_bottom) * (1.0 - edge) * interior;
	float gloss_lobe = exp(-pow((UV.x - 0.28) / 0.26, 2.0)) * 0.62;
	gloss_lobe += exp(-pow((UV.x - 0.76) / 0.20, 2.0)) * 0.44;
	float gloss = top_gloss * gloss_lobe * top_gloss_strength;

	float sheen_line = (UV.x * 1.22) - (UV.y * 0.74);
	float sheen_wave = sin((sheen_line * 8.0) - (TIME * (6.2831853 * sheen_speed)));
	float sheen = smoothstep(0.84, 1.0, sheen_wave) * (1.0 - edge) * interior * sheen_strength;

	float bubble_grid = hash12(floor(UV * vec2(10.0, 7.0)) + vec2(3.0, 19.0));
	float bubble_speck = smoothstep(0.85, 1.0, bubble_grid) * interior * (1.0 - edge) * bubble_speck_strength;

	float column_id = floor(uv_warp.x * 8.0);
	float drip_rand = hash12(vec2(column_id, 9.0));
	float drip_width = mix(0.12, 0.34, hash12(vec2(column_id, 21.0)));
	float drip_len = mix(0.04, 0.24, drip_rand);
	float drip_x = abs(fract(uv_warp.x * 8.0) - 0.5);
	float drip_body = smoothstep(drip_width, drip_width * 0.52, drip_x);
	float drip_vertical = smoothstep(1.0 - drip_len, 1.0, UV.y);
	float bottom_anchor = texture(TEXTURE, uv_warp - vec2(0.0, texel.y * 2.0)).a;
	float drips = drip_body * drip_vertical * smoothstep(0.10, 0.85, bottom_anchor) * drip_strength;

	vec3 final_rgb = honey;
	final_rgb -= honey_edge_dark.rgb * edge * edge_dark_strength;
	final_rgb += honey_gloss.rgb * gloss;
	final_rgb += honey_gloss.rgb * sheen * 0.72;
	final_rgb += honey_gloss.rgb * bubble_speck * 0.45;
	final_rgb = mix(final_rgb, honey_edge_dark.rgb, ring * outer_ring_strength);
	final_rgb = mix(final_rgb, mix(honey_mid.rgb, honey_bot.rgb, 0.56), drips * 0.72);

	float final_alpha = clamp(alpha + (ring * 0.65) + (drips * 0.40), 0.0, 1.0);
	COLOR = vec4(final_rgb * COLOR.rgb, final_alpha);
}
