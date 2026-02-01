shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(0.55, 0.50, 0.70, 1.0);
uniform float hue_center = 0.15;
uniform float hue_width = 0.08;
uniform float sat_min = 0.35;
uniform float val_min = 0.35;
uniform float strength = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	float dh = abs(hsv.x - hue_center);
	dh = min(dh, 1.0 - dh);
	float mask = step(dh, hue_width) * step(sat_min, hsv.y) * step(val_min, hsv.z);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float shade = mix(lum, hsv.z, 0.6);
	vec3 recolor = target_color.rgb * shade;
	vec3 out_rgb = mix(tex.rgb, recolor, clamp(mask * strength, 0.0, 1.0));
	COLOR = vec4(out_rgb, tex.a);
}
