shader_type canvas_item;

uniform float threshold = 0.08;
uniform float softness = 0.03;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = max(tex.r, max(tex.g, tex.b));
	float k = smoothstep(threshold, threshold + softness, lum);
	COLOR = vec4(COLOR.rgb * tex.rgb, COLOR.a * tex.a * k);
}
