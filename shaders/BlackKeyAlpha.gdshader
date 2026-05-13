shader_type canvas_item;
render_mode unshaded;

uniform float key_threshold : hint_range(0.0, 0.08) = 0.018;
uniform float feather : hint_range(0.0, 0.08) = 0.018;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float keyed = smoothstep(key_threshold, key_threshold + feather, max(max(tex.r, tex.g), tex.b));
	tex.a *= keyed;
	if (tex.a <= 0.001) {
		discard;
	}
	COLOR = tex;
}
