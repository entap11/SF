shader_type canvas_item;

uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float threshold = 0.28;
uniform float softness = 0.10;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_px = 1.6;
uniform float outline_strength = 1.0;
uniform float inner_outline_strength = 0.85;
uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.0, 1.0);
uniform float glow_strength = 0.0;
uniform float glow_luma_floor = 0.10;
uniform float glow_pulse_strength = 0.0;
uniform float glow_pulse_speed = 4.0;
uniform float glow_pulse_phase = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(c.rgb, key_color.rgb);
	float a = smoothstep(threshold - softness, threshold + softness, d);
	float base_alpha = c.a * a;
	vec2 texel = TEXTURE_PIXEL_SIZE * outline_px;
	float n1 = texture(TEXTURE, UV + vec2(texel.x, 0.0)).a;
	float n2 = texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a;
	float n3 = texture(TEXTURE, UV + vec2(0.0, texel.y)).a;
	float n4 = texture(TEXTURE, UV + vec2(0.0, -texel.y)).a;
	float n5 = texture(TEXTURE, UV + texel * vec2(0.71, 0.71)).a;
	float n6 = texture(TEXTURE, UV + texel * vec2(-0.71, 0.71)).a;
	float n7 = texture(TEXTURE, UV + texel * vec2(0.71, -0.71)).a;
	float n8 = texture(TEXTURE, UV + texel * vec2(-0.71, -0.71)).a;
	float neighbor_alpha = max(max(max(n1, n2), max(n3, n4)), max(max(n5, n6), max(n7, n8)));
	float inner_neighbor_alpha = min(min(min(n1, n2), min(n3, n4)), min(min(n5, n6), min(n7, n8)));
	float outline_mask = clamp((neighbor_alpha - base_alpha) * outline_strength, 0.0, 1.0);
	float inner_outline_mask = clamp((base_alpha - inner_neighbor_alpha) * inner_outline_strength, 0.0, 1.0);
	vec3 shaded_rgb = mix(c.rgb, outline_color.rgb, inner_outline_mask);
	vec3 out_rgb = mix(outline_color.rgb, shaded_rgb, base_alpha);
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float glow_mask = base_alpha * smoothstep(glow_luma_floor, 1.0, luma);
	float glow_pulse = 1.0 + ((sin((TIME * glow_pulse_speed) + glow_pulse_phase) * 0.5) + 0.5) * glow_pulse_strength;
	out_rgb += glow_color.rgb * glow_mask * glow_strength * glow_pulse;
	float out_alpha = max(base_alpha, outline_mask * outline_color.a);
	COLOR = vec4(out_rgb, out_alpha);
}
