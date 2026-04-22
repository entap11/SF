shader_type canvas_item;

uniform vec4 base_dark : source_color = vec4(0.11, 0.11, 0.12, 1.0);
uniform vec4 base_mid : source_color = vec4(0.18, 0.18, 0.20, 1.0);
uniform vec4 ridge_color : source_color = vec4(0.30, 0.31, 0.34, 1.0);
uniform vec4 seam_color : source_color = vec4(0.62, 0.58, 0.75, 1.0);
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.16;
uniform float alpha_scale : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float center_dist = abs(y - 0.5) * 2.0;
	float ridge_mask = smoothstep(0.92, 0.10, center_dist);
	float edge_dark = smoothstep(0.25, 1.0, center_dist);
	float bevel = smoothstep(1.0, 0.0, center_dist) * 0.55;
	float heartbeat = 0.96 + 0.04 * sin((TIME * 0.32 + x * 0.75) * 6.2831853);
	float drift = 0.97 + shimmer * 0.03 * sin((x * 3.0 - TIME * 0.12) * 6.2831853);
	float seam_mask = smoothstep(0.18, 0.0, center_dist);
	float seam_energy = seam_mask * (0.08 + heat * 0.10 + pulse * 0.22) * heartbeat * drift;
	vec3 body_rgb = mix(base_dark.rgb, base_mid.rgb, ridge_mask * 0.72);
	body_rgb = mix(body_rgb, ridge_color.rgb, bevel * 0.34);
	body_rgb *= 1.0 - edge_dark * 0.10;
	body_rgb += seam_color.rgb * seam_energy;
	float alpha = (0.96 - edge_dark * 0.06) * alpha_scale;
	COLOR = vec4(body_rgb, alpha);
}
