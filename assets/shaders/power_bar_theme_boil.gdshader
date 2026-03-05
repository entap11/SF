shader_type canvas_item;

uniform vec3 key_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float threshold = 0.08;
uniform float softness = 0.04;

uniform float fill_ratio : hint_range(0.0, 1.0) = 0.5;
uniform float fill_velocity : hint_range(0.0, 1.0) = 0.0;
uniform float share_p1 : hint_range(0.0, 1.0) = 0.5;
uniform float share_p2 : hint_range(0.0, 1.0) = 0.5;
uniform float share_p3 : hint_range(0.0, 1.0) = 0.0;
uniform float share_p4 : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_p1 : source_color = vec4(0.85, 0.72, 0.12, 1.0);
uniform vec4 color_p2 : source_color = vec4(0.95, 0.20, 0.20, 1.0);
uniform vec4 color_p3 : source_color = vec4(0.25, 0.95, 0.35, 1.0);
uniform vec4 color_p4 : source_color = vec4(0.15, 0.45, 0.95, 1.0);

uniform vec4 boil_tint : source_color = vec4(1.0, 0.92, 0.60, 0.34);
uniform float boil_speed = 1.35;
uniform float boil_scale = 30.0;
uniform float bubble_strength = 0.40;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.96;
uniform float brightness_boost : hint_range(0.6, 2.2) = 1.30;
uniform float glow_boost : hint_range(0.0, 2.5) = 1.60;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 normalize_shares(vec4 shares) {
	float total = max(0.0001, shares.x + shares.y + shares.z + shares.w);
	return shares / total;
}

vec3 seat_color_for_x(float x, vec4 ns, vec3 c1, vec3 c2, vec3 c3, vec3 c4) {
	float c12 = ns.x;
	float c23 = c12 + ns.y;
	float c34 = c23 + ns.z;
	if (x <= c12) {
		return c1;
	}
	if (x <= c23) {
		return c2;
	}
	if (x <= c34) {
		return c3;
	}
	return c4;
}

float boundary_energy(float x, vec4 ns) {
	float c12 = ns.x;
	float c23 = c12 + ns.y;
	float c34 = c23 + ns.z;
	float e = 0.0;
	if (ns.y > 0.001) {
		e += exp(-pow((x - c12) / 0.017, 2.0));
	}
	if (ns.z > 0.001) {
		e += exp(-pow((x - c23) / 0.017, 2.0));
	}
	if (ns.w > 0.001) {
		e += exp(-pow((x - c34) / 0.017, 2.0));
	}
	return e;
}

void fragment() {
	vec2 uv = UV;
	vec4 tex_base = texture(TEXTURE, uv);

	float key_dist = distance(tex_base.rgb, key_color);
	float alpha_mask = smoothstep(threshold, threshold + softness, key_dist);
	float alive = step(0.001, alpha_mask);

	float max_v = max(tex_base.r, max(tex_base.g, tex_base.b));
	float min_v = min(tex_base.r, min(tex_base.g, tex_base.b));
	float sat = max_v - min_v;
	float lane_mask = smoothstep(0.10, 0.54, sat) * smoothstep(0.07, 0.24, max_v);
	lane_mask *= smoothstep(0.30, 0.40, uv.y) * (1.0 - smoothstep(0.60, 0.72, uv.y));

	vec4 shares = vec4(share_p1, share_p2, share_p3, share_p4);
	vec4 ns = normalize_shares(shares);
	vec3 seat_color = seat_color_for_x(uv.x, ns, color_p1.rgb, color_p2.rgb, color_p3.rgb, color_p4.rgb);

	float vel_boost = mix(1.0, 2.2, fill_velocity);
	vec2 flow_uv = uv;
	flow_uv.x += TIME * 0.026 * vel_boost;
	flow_uv.y += (noise21(vec2(uv.x * 20.0, TIME * 0.65)) - 0.5) * 0.036;
	vec4 tex_flow = texture(TEXTURE, flow_uv);
	float liquid_luma = dot(tex_flow.rgb, vec3(0.2126, 0.7152, 0.0722));

	vec2 bubble_uv = vec2(uv.x * boil_scale, uv.y * boil_scale * 0.55 - TIME * boil_speed * vel_boost);
	vec2 cell = floor(bubble_uv);
	vec2 local = fract(bubble_uv) - vec2(0.5);
	float rnd = hash21(cell);
	vec2 drift = vec2(sin(TIME * 1.8 + rnd * 6.28318), cos(TIME * 1.3 + rnd * 5.137)) * 0.18;
	float radius = mix(0.06, 0.24, rnd);
	float bubble = smoothstep(radius, radius - 0.028, length(local - drift * 0.24));
	bubble *= smoothstep(0.35, 1.0, rnd);

	float turbulence = noise21(vec2(uv.x * 34.0 + TIME * 1.3, uv.y * 7.0 - TIME * 2.1 * vel_boost));
	float boil_wave = 0.5 + 0.5 * sin((uv.y + uv.x * 0.7) * boil_scale + TIME * boil_speed * 1.3 * vel_boost + turbulence * 6.28318);
	float seam = boundary_energy(uv.x, ns) * (0.40 + 0.60 * vel_boost);
	float front = exp(-pow((uv.x - fill_ratio) / 0.025, 2.0)) * (0.30 + fill_velocity * 0.70);

	vec3 lane_tint = seat_color * (0.46 + liquid_luma * 1.82 + turbulence * 0.42);
	vec3 boil_glow = boil_tint.rgb * boil_tint.a * (boil_wave * 0.6 + bubble * bubble_strength);
	vec3 foam = mix(seat_color, vec3(1.0, 0.97, 0.86), 0.72) * smoothstep(0.72, 1.0, bubble + turbulence * 0.55);

	vec3 out_rgb = tex_base.rgb;
	vec3 lane_base = mix(tex_base.rgb * 0.66, lane_tint, 0.95);
	out_rgb = mix(out_rgb, lane_base, lane_mask * tint_strength);
	out_rgb += boil_glow * lane_mask * (1.30 * glow_boost);
	out_rgb += foam * lane_mask * (0.92 * glow_boost);
	out_rgb += seat_color * lane_mask * (0.22 * glow_boost);
	out_rgb += seat_color * seam * lane_mask * (0.72 * glow_boost);
	out_rgb += mix(color_p1.rgb, color_p2.rgb, smoothstep(0.0, 1.0, uv.x)) * front * lane_mask * (0.76 * glow_boost);
	out_rgb *= brightness_boost;
	out_rgb = pow(max(out_rgb, vec3(0.0)), vec3(0.92));

	COLOR = vec4(out_rgb, tex_base.a * alpha_mask * alive);
}
