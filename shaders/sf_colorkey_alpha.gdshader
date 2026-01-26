shader_type canvas_item;

uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float threshold = 0.28;
uniform float softness = 0.10;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(c.rgb, key_color.rgb);
	float a = smoothstep(threshold - softness, threshold + softness, d);
	COLOR = vec4(c.rgb, c.a * a);
}
