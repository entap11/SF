shader_type canvas_item;

uniform float contrast = 1.05;
uniform float brightness = 0.90;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float gray = clamp(((luma - 0.5) * contrast + 0.5) * brightness, 0.0, 1.0);
	COLOR = vec4(vec3(gray), tex.a);
}
