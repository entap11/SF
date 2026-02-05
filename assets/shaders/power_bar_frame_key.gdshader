shader_type canvas_item;

uniform vec3 key_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float threshold = 0.08;
uniform float softness = 0.04;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d = distance(tex.rgb, key_color);
	float a = smoothstep(threshold, threshold + softness, d);
	COLOR = vec4(tex.rgb, tex.a * a);
}
