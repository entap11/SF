shader_type canvas_item;

uniform float threshold = 0.18;
uniform float softness = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float alpha = smoothstep(threshold, threshold + softness, luma);
	COLOR = vec4(tex.rgb, tex.a * alpha) * COLOR;
}
